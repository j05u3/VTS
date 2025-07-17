import Foundation

public class OpenAIProvider: StreamingSTTProvider {
    public let providerType: STTProviderType = .openai
    
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession
    
    public init() {
        // Configure URLSession with appropriate timeouts for streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0  // 30 seconds per request
        config.timeoutIntervalForResource = 300.0 // 5 minutes total
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Original batch interface (maintained for compatibility)
    public func transcribe(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig
    ) async throws -> String {
        // For backward compatibility, collect all audio and send as batch
        var audioData = Data()
        print("OpenAI: Starting audio collection...")
        
        for try await chunk in stream {
            audioData.append(chunk)
            print("OpenAI: Received audio chunk of \(chunk.count) bytes, total: \(audioData.count)")
        }
        
        print("OpenAI: Audio collection completed, total size: \(audioData.count) bytes")
        
        // Only send if we have enough audio data
        let minimumBytes = Int(16000 * 2) // 1 second of 16kHz 16-bit audio
        guard audioData.count >= minimumBytes else {
            print("OpenAI: Not enough audio data (\(audioData.count) bytes, minimum: \(minimumBytes))")
            throw STTError.audioProcessingError("Not enough audio data")
        }
        
        return try await sendTranscriptionRequest(audioData: audioData, config: config)
    }
    
    // MARK: - New streaming interface with chunked processing
    public func transcribeStreaming(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig,
        onPartialResult: @escaping (String) -> Void
    ) async throws -> String {
        print("OpenAI: Starting streaming transcription...")
        
        let vad = VoiceActivityDetector()
        var currentChunk = Data()
        var allTranscriptions: [String] = []
        var chunkStartTime = Date()
        var lastAudioLevel: Float = 0.0
        
        // Process audio stream in chunks
        for try await audioData in stream {
            currentChunk.append(audioData)
            
            // Calculate approximate audio level for VAD
            lastAudioLevel = calculateAudioLevel(from: audioData)
            let chunkDuration = Date().timeIntervalSince(chunkStartTime)
            
            // Check if we should send this chunk
            let decision = vad.shouldSendChunk(audioLevel: lastAudioLevel, chunkDuration: chunkDuration)
            
            switch decision {
            case .continueCollecting:
                // Keep collecting audio
                continue
                
            case .sendAndReset:
                // Send current chunk if it has enough data
                if currentChunk.count >= Int(16000 * 0.5 * 2) { // At least 0.5 seconds
                    print("OpenAI: Sending chunk of \(currentChunk.count) bytes after \(chunkDuration) seconds")
                    
                    do {
                        let chunkResult = try await sendTranscriptionRequest(
                            audioData: currentChunk, 
                            config: config
                        )
                        
                        if !chunkResult.trimmingCharacters(in: .whitespaces).isEmpty {
                            allTranscriptions.append(chunkResult)
                            print("OpenAI: Partial result: \(chunkResult)")
                            
                            // Send partial result to callback
                            onPartialResult(chunkResult)
                        }
                    } catch {
                        print("OpenAI: Error processing chunk: \(error)")
                        // Continue processing instead of failing completely
                    }
                }
                
                // Reset for next chunk
                currentChunk = Data()
                chunkStartTime = Date()
                vad.reset()
            }
        }
        
        // Process any remaining audio data
        if currentChunk.count >= Int(16000 * 0.5 * 2) {
            print("OpenAI: Processing final chunk of \(currentChunk.count) bytes")
            
            do {
                let finalResult = try await sendTranscriptionRequest(
                    audioData: currentChunk, 
                    config: config
                )
                
                if !finalResult.trimmingCharacters(in: .whitespaces).isEmpty {
                    allTranscriptions.append(finalResult)
                    onPartialResult(finalResult)
                }
            } catch {
                print("OpenAI: Error processing final chunk: \(error)")
            }
        }
        
        // Combine all transcription results
        let finalTranscription = allTranscriptions.joined(separator: " ")
        print("OpenAI: Final combined transcription: \(finalTranscription)")
        
        return finalTranscription.isEmpty ? "No speech detected" : finalTranscription
    }
    
    // MARK: - Helper methods
    private func calculateAudioLevel(from audioData: Data) -> Float {
        // Simple audio level calculation
        guard audioData.count >= 2 else { return 0.0 }
        
        let samples = audioData.withUnsafeBytes { bytes in
            bytes.bindMemory(to: Int16.self)
        }
        
        var sum: Float = 0.0
        for sample in samples {
            sum += abs(Float(sample))
        }
        
        let average = sum / Float(samples.count)
        return average / Float(Int16.max) // Normalize to 0-1
    }
    
    public func validateConfig(_ config: ProviderConfig) throws {
        guard !config.apiKey.isEmpty else {
            throw STTError.invalidAPIKey
        }
        
        guard STTProviderType.openai.defaultModels.contains(config.model) else {
            throw STTError.invalidModel
        }
    }
    
    private func sendTranscriptionRequest(audioData: Data, config: ProviderConfig) async throws -> String {
        // Add retry logic for better reliability
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await performTranscriptionRequest(audioData: audioData, config: config)
            } catch let error as STTError {
                lastError = error
                print("OpenAI: Attempt \(attempt)/\(maxRetries) failed: \(error)")
                
                // Don't retry on certain errors
                switch error {
                case .invalidAPIKey, .invalidModel:
                    throw error
                default:
                    if attempt < maxRetries {
                        // Exponential backoff
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    }
                }
            } catch {
                lastError = error
                print("OpenAI: Attempt \(attempt)/\(maxRetries) failed: \(error)")
                
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? STTError.transcriptionError("All retry attempts failed")
    }
    
    private func performTranscriptionRequest(audioData: Data, config: ProviderConfig) async throws -> String {
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
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.networkError("Invalid response type")
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw STTError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        struct TranscriptionResponse: Codable {
            let text: String
        }
        
        do {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return transcriptionResponse.text
        } catch {
            throw STTError.transcriptionError("Failed to decode response: \(error)")
        }
    }
    
    private func createWAVData(from pcmData: Data) -> Data {
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize
        
        var wavData = Data()
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        var fileSizeLE = fileSize.littleEndian
        wavData.append(Data(bytes: &fileSizeLE, count: 4))
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        let fmtSize: UInt32 = 16
        var fmtSizeLE = fmtSize.littleEndian
        wavData.append(Data(bytes: &fmtSizeLE, count: 4))
        let audioFormat: UInt16 = 1 // PCM
        var audioFormatLE = audioFormat.littleEndian
        wavData.append(Data(bytes: &audioFormatLE, count: 2))
        var channelsLE = channels.littleEndian
        wavData.append(Data(bytes: &channelsLE, count: 2))
        var sampleRateLE = sampleRate.littleEndian
        wavData.append(Data(bytes: &sampleRateLE, count: 4))
        var byteRateLE = byteRate.littleEndian
        wavData.append(Data(bytes: &byteRateLE, count: 4))
        var blockAlignLE = blockAlign.littleEndian
        wavData.append(Data(bytes: &blockAlignLE, count: 2))
        var bitsPerSampleLE = bitsPerSample.littleEndian
        wavData.append(Data(bytes: &bitsPerSampleLE, count: 2))
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        var dataSizeLE = dataSize.littleEndian
        wavData.append(Data(bytes: &dataSizeLE, count: 4))
        wavData.append(pcmData)
        
        return wavData
    }
}