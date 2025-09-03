import Foundation

class OpenAIStreamingProvider: BaseStreamingSTTProvider {
    private let realtimeURL = "wss://api.openai.com/v1/realtime"
    override var providerType: STTProviderType { .openai }

    // MARK: - WebSocket Message Structures

    private struct SessionConfig: Codable {
        let type = "transcription_session.update"
        let input_audio_format = "pcm16"
        let input_audio_transcription: TranscriptionConfig
        let turn_detection: TurnDetection? = nil
        let input_audio_noise_reduction: NoiseReduction
    }

    private struct TranscriptionConfig: Codable {
        let model: String
        let prompt: String?
    }

    private struct TurnDetection: Codable {
        let type = "server_vad"
    }
    
    private struct NoiseReduction: Codable {
        let type = "near_field"
    }

    private struct AudioMessage: Codable {
        let type = "input_audio_buffer.append"
        let audio: String
    }
    
    private struct SessionBeginsMessage: Decodable {
        let session_id: String
        let expires_in: Int
    }
    
    private struct TranscriptionDelta: Decodable {
        let event_id: String
        let type: String
        let item_id: String
        let content_index: Int
        let delta: String
    }
    
    private struct TranscriptionCompleted: Decodable {
        let event_id: String
        let type: String
        let item_id: String
        let content_index: Int
        let transcript: String
    }


    override func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession {
        guard let url = URL(string: realtimeURL) else {
            throw STTError.networkError("Invalid WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let webSocketTask = URLSession.shared.webSocketTask(with: request)
        
        let sessionConfig = SessionConfig(
            input_audio_transcription: TranscriptionConfig(model: config.model, prompt: config.systemPrompt),
            input_audio_noise_reduction: NoiseReduction()
        )

        let encoder = JSONEncoder()
        let configData = try encoder.encode(sessionConfig)
        
        webSocketTask.resume() 
        
        try await webSocketTask.send(.data(configData))

        // Wait for session begins message
        let message = try await webSocketTask.receive() 
        
        switch message {
        case .data(let data):
            let decoder = JSONDecoder()
            let sessionBegins = try decoder.decode(SessionBeginsMessage.self, from: data)
            let session = RealtimeSession(sessionId: sessionBegins.session_id, webSocket: webSocketTask)
            
            // Start listening for messages in the background
            listenForMessages(on: session)
            
            return session
        case .string(let text):
            throw STTError.networkError("Unexpected string message from server: \(text)")
        @unknown default:
            fatalError()
        }
    }
    
    private func listenForMessages(on session: RealtimeSession) {
        Task {
            do {
                while session.isActive {
                    let message = try await session.webSocket.receive() 
                    switch message {
                    case .data(let data):
                        // Handle incoming transcription data
                        if let delta = try? JSONDecoder().decode(TranscriptionDelta.self, from: data) {
                            session.yield(TranscriptionChunk(text: delta.delta, isFinal: false))
                        } else if let completed = try? JSONDecoder().decode(TranscriptionCompleted.self, from: data) {
                            session.yield(TranscriptionChunk(text: completed.transcript, isFinal: true))
                        }
                    case .string(let text):
                        print("Received string: \(text)")
                    @unknown default:
                        fatalError()
                    }
                }
            } catch {
                session.finish(throwing: error)
            }
        }
    }

    override func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws {
        let message = AudioMessage(audio: audioData.base64EncodedString())
        let data = try JSONEncoder().encode(message)
        try await session.webSocket.send(.data(data))
    }

    override func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String {
        // Signal end of audio
        try await session.webSocket.send(.string("{\"type\": \"input_audio_buffer.commit\"}"))

        var finalTranscription = ""
        for try await chunk in session.partialResultsStream {
            if chunk.isFinal {
                finalTranscription = chunk.text
                break
            }
        }
        
        session.finish()
        session.webSocket.cancel(with: .goingAway, reason: nil)
        
        return finalTranscription
    }

    override func validateConfig(_ config: ProviderConfig) throws {
        guard !config.apiKey.isEmpty else {
            throw STTError.invalidAPIKey
        }

        guard providerType.realtimeModels.contains(config.model) else {
            throw STTError.invalidModel
        }
    }
}