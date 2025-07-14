import Foundation

public class OpenAIProvider: STTProvider {
    public let providerType: STTProviderType = .openai
    
    private let baseURL = "https://api.openai.com/v1"
    private let session = URLSession.shared
    
    public init() {}
    
    public func transcribe(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig
    ) async throws -> AsyncStream<TranscriptionChunk> {
        return AsyncStream<TranscriptionChunk> { continuation in
            Task {
                do {
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
                        continuation.finish()
                        return
                    }
                    
                    // Send to OpenAI
                    print("OpenAI: Sending transcription request...")
                    let result = try await sendTranscriptionRequest(audioData: audioData, config: config)
                    print("OpenAI: Received transcription result: \(result)")
                    
                    // Return final result
                    let chunk = TranscriptionChunk(text: result, isFinal: true)
                    continuation.yield(chunk)
                    continuation.finish()
                } catch {
                    print("OpenAI: Transcription error: \(error)")
                    continuation.finish()
                }
            }
        }
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
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw STTError.networkError("Bad server response")
        }
        
        struct TranscriptionResponse: Codable {
            let text: String
        }
        
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return transcriptionResponse.text
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