import Foundation
import os

public class OpenAIStreamingProvider: BaseStreamingSTTProvider {
    public override var providerType: STTProviderType { .openai }

    private let logger = Logger(subsystem: "com.voicetypestudio.app", category: "OpenAIStreaming")
    
    // MARK: - Constants
    private enum Constants {
        static let realtimeURL = "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview"
        static let inputAudioFormat = "pcm16"
        static let noiseReductionType = "near_field"
        static let finalTranscriptTimeout: TimeInterval = 30.0
        static let transcriptCheckInterval: TimeInterval = 0.1
    }
    
    private var activeSessions: [String: RealtimeSession] = [:]
    private var audioChunkCounters: [String: Int] = [:] // Track audio chunks per session
    
    public override init() {
        super.init()
    }
    
    public override func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession {
        // Validate configuration first
        try validateConfig(config)

        // Create WebSocket connection using headers like the working test implementation
        let headers = [
            "Authorization": "Bearer \(config.apiKey)",
            "OpenAI-Beta": "realtime=v1"
        ]
        
        let webSocket = try await createWebSocketConnection(
            url: URL(string: Constants.realtimeURL)!,
            headers: headers,
            protocols: [], // Don't use protocols, use headers instead
            providerName: "OpenAI Streaming"
        )
        
        // Create session
        let sessionId = UUID().uuidString
        let session = RealtimeSession(sessionId: sessionId, webSocket: webSocket)
        session.isActive = true
        
        // Store active session
        activeSessions[sessionId] = session

        logger.info("Created session \(sessionId)")

        // Configure the session but DON'T start listening yet
        try await configureSession(session: session, config: config, startListening: false)
        
        return session
    }
    
    // New method to start listening after callback is set up
    public func startListening(for session: RealtimeSession) async throws {
        // Start listening for messages now that callback is set up
        startMessageListener(for: session)
        
        // Wait for session confirmation
        try await session.waitForSessionConfirmation()
        
        // Log confirmation timing after waiting completes
        if let durationMs = session.sessionConfirmationDurationMs {
            logger.debug("Total session setup time: \(durationMs) ms")
        }
    }
    
    public override func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws {
        // Validate session state first
        try validateSessionState(session, operation: "streamAudio")
        
        // Increment and log audio chunk counter
        let currentCount = (audioChunkCounters[session.sessionId] ?? 0) + 1
        audioChunkCounters[session.sessionId] = currentCount
        
        // Enhanced logging to track audio streaming calls
        logger.debug("streamAudio called with \(audioData.count) bytes for session \(session.sessionId) (chunk #\(currentCount))")
        
        // Log audio data size for debugging (similar to JS implementation)
        let audioSizeKB = Double(audioData.count) / 1024.0
        logger.debug("Streaming audio buffer: \(String(format: "%.2f", audioSizeKB)) KB")
        
        // Create audio append message
        let message = OpenAIRealtimeMessage.inputAudioBufferAppend(audioData)
        
        logger.debug("Sending audio chunk to WebSocket...")
        try await sendMessage(
            message.toDictionary(),
            through: session.webSocket,
            providerName: "OpenAI Streaming"
        )
        logger.debug("Audio chunk sent successfully")
    }
    
    public override func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String {
        // Validate session state first
        try validateSessionState(session, operation: "finishAndGetTranscription")
        
        let totalChunks = audioChunkCounters[session.sessionId] ?? 0
        logger.info("Finishing session \(session.sessionId)")
        logger.debug("Session summary - Total audio chunks sent: \(totalChunks)")
        
        // Commit the audio buffer to trigger final transcription
        let commitMessage = OpenAIRealtimeMessage.inputAudioBufferCommit
        logger.debug("Sending commit message to finalize audio buffer...")
        try await sendMessage(
            commitMessage.toDictionary(),
            through: session.webSocket,
            providerName: "OpenAI Streaming"
        )
        
        // Wait for final transcript with structured timeout handling
        let finalTranscript = try await waitForFinalTranscript(session: session)
        
        // Clean up session asynchronously in the background to avoid blocking text injection
        Task {
            await cleanupSession(session)
        }
        
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
    
    private func configureSession(session: RealtimeSession, config: ProviderConfig, startListening: Bool = true) async throws {
        logger.info("Configuring session with model: \(config.model)")
        
        // Create session configuration that matches the working JS implementation
        let sessionConfig = OpenAIRealtimeSessionConfig(
            model: config.model,
            prompt: config.systemPrompt,
            language: config.language,
            inputAudioFormat: Constants.inputAudioFormat,
            turnDetection: nil, // Disable VAD - we control audio manually (must be null, not a TurnDetection object)
            noiseReductionType: Constants.noiseReductionType
        )
        
        // Send session update message
        let message = OpenAIRealtimeMessage.sessionUpdate(sessionConfig)
        try await sendMessage(
            message.toDictionary(),
            through: session.webSocket,
            providerName: "OpenAI Streaming"
        )
        
        if startListening {
            // Start listening for messages immediately to catch session confirmation
            startMessageListener(for: session)
            
            // Wait for session confirmation
            try await session.waitForSessionConfirmation()
        }
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
                logger.error("Message listener ended with error: \(error)")
                
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
            logger.debug("Raw message received: \(jsonString)")
        }
        
        let event = OpenAIRealtimeEvent.from(messageDict: messageDict)
        
        switch event {
        case .sessionCreated:
            logger.info("Session created")
            
        case .sessionUpdated:
            logger.info("Session updated")
            session.confirmSession()
            logger.info("Session confirmed! Ready to receive audio chunks.")
            
        case .inputAudioBufferCommitted(let details):
            logger.debug("Audio buffer committed: \(details)")
            
        case .conversationItemInputAudioTranscriptionDelta(let delta):
            let chunk = TranscriptionChunk(text: delta.delta, isFinal: false, timestamp: Date())
            session.yieldPartialResult(chunk)

        case .conversationItemInputAudioTranscriptionCompleted(let completed):
            logger.info("Transcription completed: '\(completed.transcript)'")
            session.finalTranscript = completed.transcript
            let chunk = TranscriptionChunk(text: completed.transcript, isFinal: true, timestamp: Date())
            session.yieldPartialResult(chunk)
            
        case .error(let error):
            logger.error("Received error: \(error.message)")
            let streamingError = StreamingError.sessionError("OpenAI API error: \(error.message)")

            if !session.isSessionConfirmed {
                session.failSessionConfirmation(with: streamingError)
            }
            session.finishPartialResultsWithError(streamingError)
            session.isActive = false
            
        case .unknown(let details):
            if let type = details["type"] as? String {
                logger.debug("Unknown message type '\(type)': \(details)")
            } else {
                logger.debug("Unknown message (no type): \(details)")
            }
        }
    }
    
    private func waitForFinalTranscript(session: RealtimeSession, timeout: TimeInterval = Constants.finalTranscriptTimeout) async throws -> String {
        logger.debug("Waiting for final transcript...")
        
        // Use TaskGroup for cleaner timeout handling
        return try await withThrowingTaskGroup(of: String.self) { group in
            // Add transcript monitoring task
            group.addTask {
                while session.finalTranscript.isEmpty {
                    try await Task.sleep(for: .seconds(Constants.transcriptCheckInterval))
                }
                return session.finalTranscript
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw StreamingError.sessionError("Final transcript timeout after \(timeout) seconds")
            }
            
            // Return first completed result and cancel others
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func cleanupSession(_ session: RealtimeSession) async {
        logger.info("Cleaning up session \(session.sessionId)")
        
        // Remove from active sessions and cleanup counter
        activeSessions.removeValue(forKey: session.sessionId)
        audioChunkCounters.removeValue(forKey: session.sessionId)
        
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
        logger.info("Cleaning up \(activeSessions.count) active sessions")
        for session in activeSessions.values {
            await cleanupSession(session)
        }
        activeSessions.removeAll()
        audioChunkCounters.removeAll()
    }
}

// MARK: - Session State Management
extension OpenAIStreamingProvider {
    
    /// Validates session state before operations
    private func validateSessionState(_ session: RealtimeSession, operation: String) throws {
        guard session.isActive else {
            throw StreamingError.sessionError("Session is not active for \(operation)")
        }
        
        guard activeSessions[session.sessionId] != nil else {
            throw StreamingError.sessionError("Session \(session.sessionId) not found in active sessions")
        }
    }
}