import Foundation

public class DeepgramProvider: BaseSTTProvider {
    public override var providerType: STTProviderType { .deepgram }
    
    private let baseURL = "https://api.deepgram.com/v1/listen"
    
    public override init() {
        super.init()
    }
    
    public override func transcribe(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig
    ) async throws -> String {
        var audioData = Data()
        print("Deepgram: Starting audio collection...")
        
        // Collect audio data
        for try await chunk in stream {
            audioData.append(chunk)
            print("Deepgram: Received audio chunk of \(chunk.count) bytes, total: \(audioData.count)")
        }
        
        print("Deepgram: Audio collection completed, total size: \(audioData.count) bytes")
        
        // Only send if we have enough audio data (at least 1 second worth)
        let minimumBytes = Int(16000 * 2) // 1 second of 16kHz 16-bit audio
        guard audioData.count >= minimumBytes else {
            print("Deepgram: Not enough audio data (\(audioData.count) bytes, minimum: \(minimumBytes))")
            throw STTError.audioProcessingError("Not enough audio data")
        }
        
        // Send to Deepgram and return result directly
        print("Deepgram: Sending transcription request...")
        let result = try await sendTranscriptionRequest(audioData: audioData, config: config)
        print("Deepgram: Received transcription result: \(result)")
        
        return result
    }
    
    public override func validateConfig(_ config: ProviderConfig) throws {
        guard !config.apiKey.isEmpty else {
            throw STTError.invalidAPIKey
        }
        
        guard STTProviderType.deepgram.defaultModels.contains(config.model) else {
            throw STTError.invalidModel
        }
    }
    
    private func sendTranscriptionRequest(audioData: Data, config: ProviderConfig) async throws -> String {
        // Build URL with query parameters
        var urlComponents = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        
        // Add model parameter
        queryItems.append(URLQueryItem(name: "model", value: config.model))
        
        // Add language if provided
        queryItems.append(URLQueryItem(name: "language", value: "multi"))
        
        // Deepgram-specific parameters
        queryItems.append(URLQueryItem(name: "punctuate", value: "true"))
        queryItems.append(URLQueryItem(name: "smart_format", value: "true"))
        queryItems.append(URLQueryItem(name: "numerals", value: "true"))
        queryItems.append(URLQueryItem(name: "paragraphs", value: "true"))
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw STTError.transcriptionError("Failed to construct request URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        
        // Set the WAV audio data as body
        request.httpBody = createWAVData(from: audioData)
        
        // Use the base class's retry logic with configurable timeout
        let (data, response) = try await performNetworkRequest(
            request: request,
            audioDataSize: audioData.count,
            providerName: "Deepgram"
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
            print("Deepgram: Bad request error - \(errorDetails)")
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
        
        // Parse Deepgram response
        struct DeepgramResponse: Codable {
            let results: Results
            
            struct Results: Codable {
                let channels: [Channel]
                
                struct Channel: Codable {
                    let alternatives: [Alternative]
                    
                    struct Alternative: Codable {
                        let transcript: String
                        let confidence: Double?
                    }
                }
            }
        }
        
        let deepgramResponse = try JSONDecoder().decode(DeepgramResponse.self, from: data)
        
        // Extract transcript from the first channel and alternative
        guard let firstChannel = deepgramResponse.results.channels.first,
              let firstAlternative = firstChannel.alternatives.first else {
            throw STTError.transcriptionError("No transcription results returned")
        }
        
        return firstAlternative.transcript
    }
    
    // Helper method to parse error responses from Deepgram API
    private func parseErrorResponse(_ data: Data) -> String {
        // Try to parse Deepgram error response format
        struct DeepgramErrorResponse: Codable {
            let error: String?
            let message: String?
            let type: String?
        }
        
        if let errorResponse = try? JSONDecoder().decode(DeepgramErrorResponse.self, from: data) {
            return errorResponse.error ?? errorResponse.message ?? "Unknown error"
        }
        
        // Fallback to raw response text
        if let responseText = String(data: data, encoding: .utf8), !responseText.isEmpty {
            return responseText
        }
        
        return "Unknown error"
    }
}