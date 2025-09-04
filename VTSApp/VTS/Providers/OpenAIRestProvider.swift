import Foundation

public class OpenAIRestProvider: BaseRestSTTProvider {
    public override var providerType: STTProviderType { .openai }
    
    private let baseURL = "https://api.openai.com/v1"
    
    public override init() {
        super.init()
    }
    
    public override func transcribe(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig
    ) async throws -> String {
        var audioData = Data()
        print("OpenAI: Starting audio collection...")
        
        // Collect audio data
        for try await chunk in stream {
            audioData.append(chunk)
            print("OpenAI: Received audio chunk of \(chunk.count) bytes, total: \(audioData.count)")
        }
        
        print("OpenAI: Audio collection completed, total size: \(audioData.count) bytes")
        
        // Only send if we have enough audio data (at least 1 second worth)
        let minimumBytes = Int(16000 * 2) // 1 second of 16kHz 16-bit audio
        guard audioData.count >= minimumBytes else {
            print("OpenAI: Not enough audio data (\(audioData.count) bytes, minimum: \(minimumBytes))")
            throw STTError.audioProcessingError("Not enough audio data")
        }
        
        // Send to OpenAI and return result directly
        print("OpenAI: Sending transcription request...")
        let result = try await sendTranscriptionRequest(audioData: audioData, config: config)
        print("OpenAI: Received transcription result: \(result)")
        
        return result
    }
    
    public override func validateConfig(_ config: ProviderConfig) throws {
        guard !config.apiKey.isEmpty else {
            throw STTError.invalidAPIKey
        }
        
        guard STTProviderType.openai.restModels.contains(config.model) else {
            throw STTError.invalidModel
        }
    }
    
    private func sendTranscriptionRequest(audioData: Data, config: ProviderConfig) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(config.model)\r\n".data(using: .utf8)!)
        
        // Add prompt if provided
        if let prompt = config.systemPrompt, !prompt.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(prompt)\r\n".data(using: .utf8)!)
        }
        
        // Add language if provided
        if let language = config.language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }
        
        // Add temperature if provided
        if let temperature = config.temperature {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(temperature)\r\n".data(using: .utf8)!)
        }
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(createWAVData(from: audioData))
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Use the base class's retry logic with configurable timeout
        let (data, response) = try await performNetworkRequest(
            request: request,
            audioDataSize: audioData.count,
            providerName: "OpenAI"
        )
        
        // Enhanced error handling based on HTTP status codes
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.networkError("Invalid response format")
        }
        
        // Handle different status codes specifically
        switch httpResponse.statusCode {
        case 200...299:
            // Success - continue processing
            break
            
        case 401:
            // Authentication failed - invalid API key
            let errorDetails = parseErrorResponse(data)
            throw STTError.invalidAPIKey
            
        case 402:
            // Payment required - quota exceeded
            let errorDetails = parseErrorResponse(data)
            throw STTError.transcriptionError("Account quota exceeded. Please check your billing and usage limits.")
            
        case 429:
            // Rate limit exceeded
            let errorDetails = parseErrorResponse(data)
            throw STTError.transcriptionError("Rate limit exceeded. Please wait before trying again.")
            
        case 400:
            // Bad request - could be invalid model, malformed audio, etc.
            let errorDetails = parseErrorResponse(data)
            if errorDetails.contains("model") {
                throw STTError.invalidModel
            } else if errorDetails.contains("audio") {
                throw STTError.audioProcessingError("Invalid audio format or corrupted audio data")
            } else {
                throw STTError.transcriptionError("Bad request: \(errorDetails)")
            }
            
        case 500...599:
            // Server errors - retryable
            let errorDetails = parseErrorResponse(data)
            throw STTError.networkError("Server error (\(httpResponse.statusCode)): \(errorDetails)")
            
        default:
            // Other client errors
            let errorDetails = parseErrorResponse(data)
            throw STTError.networkError("Request failed (\(httpResponse.statusCode)): \(errorDetails)")
        }
        
        struct TranscriptionResponse: Codable {
            let text: String
        }
        
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return transcriptionResponse.text
    }
    
    // Helper method to parse error responses from OpenAI API
    private func parseErrorResponse(_ data: Data) -> String {
        // Try to parse OpenAI error response format
        struct OpenAIErrorResponse: Codable {
            let error: ErrorDetails
            
            struct ErrorDetails: Codable {
                let message: String
                let type: String?
                let code: String?
            }
        }
        
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            return errorResponse.error.message
        }
        
        // Fallback to raw response text
        if let responseText = String(data: data, encoding: .utf8), !responseText.isEmpty {
            return responseText
        }
        
        return "Unknown error"
    }
}