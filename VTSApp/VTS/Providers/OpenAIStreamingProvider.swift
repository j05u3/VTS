import Foundation

public class OpenAIStreamingProvider: BaseStreamingSTTProvider {
    public override var providerType: STTProviderType { .openai }
    
    private let realtimeURL = "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview"
    private var activeSessions: [String: RealtimeSession] = [:]
    
    public override init() {
        super.init()
    }
    
    public override func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession {
        // Validate configuration first
        try validateConfig(config)
        
        // Create WebSocket connection using protocols as per Node.js implementation
        let protocols = [
            "realtime",
            "openai-insecure-api-key.\(config.apiKey)",
            "openai-beta.realtime-v1"
        ]
        
        let webSocket = try await createWebSocketConnection(
            url: URL(string: realtimeURL)!,
            protocols: protocols,
            providerName: "OpenAI Streaming"
        )
        
        // Create session
        let sessionId = UUID().uuidString
        let session = RealtimeSession(sessionId: sessionId, webSocket: webSocket)
        session.isActive = true
        
        // Store active session
        activeSessions[sessionId] = session
        
        print("OpenAI Streaming: Created session \(sessionId)")
        
        // Configure the session
        try await configureSession(session: session, config: config)
        
        return session
    }
    
    public override func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws {
        guard session.isActive else {
            throw StreamingError.sessionError("Session is not active")
        }
        
        // Ensure session is confirmed before streaming audio data
        guard session.isSessionConfirmed else {
            throw StreamingError.sessionError("Session not yet confirmed - cannot stream audio")
        }
        
        // Log audio data size for debugging (similar to JS implementation)
        let audioSizeKB = Double(audioData.count) / 1024.0
        print("OpenAI Streaming: Streaming audio buffer: \(String(format: "%.2f", audioSizeKB)) KB")
        
        // Create audio append message
        let message = OpenAIRealtimeMessage.inputAudioBufferAppend(audioData)
        
        try await sendMessage(
            message.toDictionary(),
            through: session.webSocket,
            providerName: "OpenAI Streaming"
        )
    }
    
    public override func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String {
        guard session.isActive else {
            throw StreamingError.sessionError("Session is not active")
        }
        
        print("OpenAI Streaming: Finishing session \(session.sessionId)")
        
        // Commit the audio buffer to trigger final transcription
        let commitMessage = OpenAIRealtimeMessage.inputAudioBufferCommit
        try await sendMessage(
            commitMessage.toDictionary(),
            through: session.webSocket,
            providerName: "OpenAI Streaming"
        )
        
        // Wait for final transcript or timeout
        let finalTranscript = try await waitForFinalTranscript(session: session)
        
        // Clean up session
        await cleanupSession(session)
        
        return finalTranscript
    }
    
    public override func validateConfig(_ config: ProviderConfig) throws {
        guard !config.apiKey.isEmpty else {
            throw StreamingError.invalidConfiguration("API key is empty")
        }
        
        guard STTProviderType.openai.realtimeModels.contains(config.model) else {
            throw StreamingError.invalidConfiguration("Invalid model: \(config.model)")
        }
    }
    
    // MARK: - Private Methods
    
    private func configureSession(session: RealtimeSession, config: ProviderConfig) async throws {
        print("OpenAI Streaming: Configuring session with model: \(config.model)")
        
        // Create session configuration that matches the working JS implementation
        let sessionConfig = OpenAIRealtimeSessionConfig(
            model: config.model,
            prompt: config.systemPrompt,
            language: config.language,
            inputAudioFormat: "pcm16",
            turnDetection: nil, // Disable VAD - we control audio manually (must be null, not a TurnDetection object)
            noiseReductionType: "near_field"
        )
        
        // Send session update message
        let message = OpenAIRealtimeMessage.sessionUpdate(sessionConfig)
        try await sendMessage(
            message.toDictionary(),
            through: session.webSocket,
            providerName: "OpenAI Streaming"
        )
        
        // Start listening for messages immediately to catch session confirmation
        startMessageListener(for: session)
        
        // Wait for session confirmation
        try await session.waitForSessionConfirmation()
    }
    
    private func startMessageListener(for session: RealtimeSession) {
        Task {
            do {
                while session.isActive {
                    let messageDict = try await receiveMessage(
                        from: session.webSocket,
                        providerName: "OpenAI Streaming"
                    )
                    
                    try await handleIncomingMessage(messageDict, session: session)
                }
            } catch {
                print("OpenAI Streaming: Message listener ended with error: \(error)")
                
                // If session is not yet confirmed, fail the confirmation
                if !session.isSessionConfirmed {
                    session.failSessionConfirmation(with: error)
                }
                
                session.finishPartialResultsWithError(error)
                await cleanupSession(session)
            }
        }
    }
    
    private func handleIncomingMessage(_ messageDict: [String: Any], session: RealtimeSession) async throws {
        // Log the raw message for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: messageDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("OpenAI Streaming: Raw message received: \(jsonString)")
        }
        
        let event = OpenAIRealtimeEvent.from(messageDict: messageDict)
        
        switch event {
        case .sessionCreated(let details):
            print("OpenAI Streaming: Session created: \(details)")
            
        case .sessionUpdated(let details):
            print("OpenAI Streaming: Session updated: \(details)")
            // Confirm the session when we receive session.updated
            session.confirmSession()
            
        case .inputAudioBufferCommitted(let details):
            print("OpenAI Streaming: Audio buffer committed: \(details)")
            
        case .conversationItemInputAudioTranscriptionDelta(let delta):
            print("OpenAI Streaming: Transcription delta: '\(delta.delta)'")
            
            // Create partial transcription chunk
            let chunk = TranscriptionChunk(
                text: delta.delta,
                isFinal: false,
                timestamp: Date()
            )
            
            session.yieldPartialResult(chunk)
            
        case .conversationItemInputAudioTranscriptionCompleted(let completed):
            print("OpenAI Streaming: Transcription completed: '\(completed.transcript)'")
            
            // Store final transcript
            session.finalTranscript = completed.transcript
            
            // Create final transcription chunk
            let chunk = TranscriptionChunk(
                text: completed.transcript,
                isFinal: true,
                timestamp: Date()
            )
            
            session.yieldPartialResult(chunk)
            
        case .error(let error):
            print("OpenAI Streaming: Received error: \(error.message)")
            
            let streamingError = StreamingError.sessionError("OpenAI API error: \(error.message)")
            
            // If session is not yet confirmed, fail the confirmation
            if !session.isSessionConfirmed {
                session.failSessionConfirmation(with: streamingError)
            }
            
            session.finishPartialResultsWithError(streamingError)
            // Mark session as inactive to stop the message listener loop
            session.isActive = false
            
        case .unknown(let details):
            if let type = details["type"] as? String {
                print("OpenAI Streaming: Unknown message type '\(type)': \(details)")
            } else {
                print("OpenAI Streaming: Unknown message (no type): \(details)")
            }
        }
    }
    
    private func waitForFinalTranscript(session: RealtimeSession) async throws -> String {
        print("OpenAI Streaming: Waiting for final transcript...")
        
        // Create timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            throw StreamingError.sessionError("Final transcript timeout")
        }
        
        // Create transcript wait task
        let transcriptTask = Task {
            var attempts = 0
            let maxAttempts = 300 // 30 seconds at 100ms intervals
            
            while attempts < maxAttempts {
                if !session.finalTranscript.isEmpty {
                    return session.finalTranscript
                }
                
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                attempts += 1
            }
            
            throw StreamingError.sessionError("No final transcript received")
        }
        
        // Race between timeout and transcript
        do {
            return try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { 
                    try await timeoutTask.value
                    return ""
                }
                group.addTask { 
                    return try await transcriptTask.value
                }
                
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch {
            throw error
        }
    }
    
    private func cleanupSession(_ session: RealtimeSession) async {
        print("OpenAI Streaming: Cleaning up session \(session.sessionId)")
        
        // Remove from active sessions
        activeSessions.removeValue(forKey: session.sessionId)
        
        // Clean up the session
        await session.cleanup()
    }
    
    // MARK: - Public Utilities
    
    /// Returns the number of active sessions
    public var activeSessionCount: Int {
        return activeSessions.count
    }
    
    /// Cleans up all active sessions
    public func cleanupAllSessions() async {
        for session in activeSessions.values {
            await cleanupSession(session)
        }
        activeSessions.removeAll()
    }
}