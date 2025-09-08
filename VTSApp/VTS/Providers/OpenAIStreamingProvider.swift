import Foundation
import OpenAIRealtime

// Import VTS types
// Note: These are imported implicitly since they're in the same module

// MARK: - OpenAI Realtime Session Wrapper

/// Wrapper class to bridge between RealtimeSession interface and OpenAIRealtime.Conversation
private class OpenAIRealtimeSession {
    let sessionId: String
    let conversation: Conversation
    private let config: ProviderConfig
    
    // State tracking
    var isActive: Bool = false
    var isSessionConfirmed: Bool = false
    var finalTranscript: String = ""
    
    // Completion handlers
    private var sessionConfirmationContinuation: CheckedContinuation<Void, Error>?
    private var partialResultHandler: ((TranscriptionChunk) -> Void)?
    
    init(sessionId: String, conversation: Conversation, config: ProviderConfig) {
        self.sessionId = sessionId
        self.conversation = conversation
        self.config = config
    }
    
    func confirmSession() {
        isSessionConfirmed = true
        sessionConfirmationContinuation?.resume()
        sessionConfirmationContinuation = nil
    }
    
    func failSessionConfirmation(with error: Error) {
        sessionConfirmationContinuation?.resume(throwing: error)
        sessionConfirmationContinuation = nil
    }
    
    func waitForSessionConfirmation() async throws {
        if isSessionConfirmed {
            return
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            sessionConfirmationContinuation = continuation
        }
    }
    
    func yieldPartialResult(_ chunk: TranscriptionChunk) {
        partialResultHandler?(chunk)
    }
    
    func setPartialResultHandler(_ handler: @escaping (TranscriptionChunk) -> Void) {
        partialResultHandler = handler
    }
    
    func finishPartialResultsWithError(_ error: Error) {
        // Mark session as inactive
        isActive = false
    }
    
    func cleanup() async {
        isActive = false
        // The OpenAIRealtime library handles cleanup internally
    }
}

public class OpenAIStreamingProvider: BaseStreamingSTTProvider {
    public override var providerType: STTProviderType { .openai }
    
    private var activeSessions: [String: OpenAIRealtimeSession] = [:]
    
    public override init() {
        super.init()
    }
    
    public override func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession {
        // Validate configuration first
        try validateConfig(config)
        
        print("OpenAI Streaming: Creating Realtime session with model: \(config.model)")
        
        // Create OpenAI Realtime session using the library
        let conversation = Conversation(authToken: config.apiKey, model: config.model)
        
        // Create session wrapper
        let sessionId = UUID().uuidString
        let session = OpenAIRealtimeSession(sessionId: sessionId, conversation: conversation, config: config)
        session.isActive = true
        
        // Store active session
        activeSessions[sessionId] = session
        
        print("OpenAI Streaming: Created Realtime session \(sessionId)")
        
        // Wait for connection to be established with timeout
        do {
            // Create a timeout task
            let connectionTask = Task {
                await session.conversation.waitForConnection()
            }
            
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
                connectionTask.cancel()
                throw StreamingError.connectionError("Connection timeout after 10 seconds")
            }
            
            // Race between connection and timeout
            _ = try await connectionTask.value
            timeoutTask.cancel()
            
            print("OpenAI Streaming: Connection established successfully")
            session.isSessionConfirmed = true
        } catch {
            print("OpenAI Streaming: Failed to establish connection: \(error)")
            session.isActive = false
            activeSessions.removeValue(forKey: sessionId)
            
            // Provide more specific error messages
            if error.localizedDescription.contains("timeout") || error.localizedDescription.contains("not connected") {
                throw StreamingError.connectionError("Unable to connect to OpenAI Realtime API. Please check your internet connection and try again.")
            } else {
                throw StreamingError.connectionError("Failed to connect to OpenAI Realtime API: \(error.localizedDescription)")
            }
        }
        
        // Configure the session after connection is confirmed
        try await configureSession(session: session, config: config)
        
        // Start monitoring for transcription events
        startMessageListener(for: session)
        
        // Create a bridge RealtimeSession that wraps our OpenAIRealtimeSession
        return createRealtimeSessionBridge(session)
    }
    
    public override func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws {
        guard let wrappedSession = getWrappedSession(session) else {
            throw StreamingError.sessionError("Invalid session type")
        }
        
        guard wrappedSession.isActive else {
            throw StreamingError.sessionError("Session is not active")
        }
        
        // Ensure session is confirmed before streaming audio data
        guard wrappedSession.isSessionConfirmed else {
            throw StreamingError.sessionError("Session not yet confirmed - cannot stream audio")
        }
        
        // Use OpenAIRealtime library to send audio data with error handling
        do {
            try await wrappedSession.conversation.send(audioDelta: audioData, commit: false)
        } catch {
            print("OpenAI Streaming: Error sending audio data: \(error)")
            // Don't throw immediately - retry once in case of transient network issue
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            try await wrappedSession.conversation.send(audioDelta: audioData, commit: false)
        }
    }
    
    public override func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String {
        guard let wrappedSession = getWrappedSession(session) else {
            throw StreamingError.sessionError("Invalid session type")
        }
        
        guard wrappedSession.isActive else {
            throw StreamingError.sessionError("Session is not active")
        }
        
        print("OpenAI Streaming: Finishing session \(wrappedSession.sessionId)")
        
        // Commit the audio buffer to trigger final transcription using OpenAIRealtime library
        do {
            try await wrappedSession.conversation.send(audioDelta: Data(), commit: true)
        } catch {
            print("OpenAI Streaming: Error committing audio buffer: \(error)")
            // Try to get any existing transcription before failing
            if !wrappedSession.finalTranscript.isEmpty {
                print("OpenAI Streaming: Using existing partial transcript due to commit error")
                await cleanupSession(wrappedSession)
                return wrappedSession.finalTranscript
            }
            throw StreamingError.transcriptionError("Failed to commit audio for transcription: \(error.localizedDescription)")
        }
        
        // Wait for final transcript or timeout
        let finalTranscript = try await waitForFinalTranscript(session: wrappedSession)
        
        // Clean up session
        await cleanupSession(wrappedSession)
        
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
    
    private func createRealtimeSessionBridge(_ wrappedSession: OpenAIRealtimeSession) -> RealtimeSession {
        // Create a bridge RealtimeSession using a dummy URL since we're managing connection through OpenAIRealtime
        let dummyRequest = URLRequest(url: URL(string: "wss://api.openai.com/v1/realtime")!)
        let dummyWebSocket = URLSession.shared.webSocketTask(with: dummyRequest)
        
        let bridgeSession = RealtimeSession(sessionId: wrappedSession.sessionId, webSocket: dummyWebSocket)
        bridgeSession.isActive = wrappedSession.isActive
        bridgeSession.isSessionConfirmed = wrappedSession.isSessionConfirmed
        
        // Store reference to wrapped session using sessionId as key
        // This allows us to retrieve it later in other methods
        
        return bridgeSession
    }
    
    private func getWrappedSession(_ bridgeSession: RealtimeSession) -> OpenAIRealtimeSession? {
        return activeSessions[bridgeSession.sessionId]
    }
    
    private func configureSession(session: OpenAIRealtimeSession, config: ProviderConfig) async throws {
        print("OpenAI Streaming: Configuring session with model: \(config.model)")
        
        // Configure the session using OpenAIRealtime library with retry logic
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                try await session.conversation.whenConnected {
                    try await session.conversation.updateSession { sessionConfig in
                        // Configure session for transcription
                        sessionConfig.instructions = config.systemPrompt ?? "You are a transcription assistant."
                        
                        // Map model to OpenAI Realtime TranscriptionModel
                        let transcriptionModel = mapToTranscriptionModel(config.model)
                        
                        // Configure input audio transcription with proper model, prompt, and language
                        var inputTranscription = Session.InputAudioTranscription(model: transcriptionModel)
                        
                        // Set transcription prompt - use system prompt or keywords as guidance
                        if let systemPrompt = config.systemPrompt, !systemPrompt.isEmpty {
                            inputTranscription.prompt = systemPrompt
                        } else if let keywords = config.keywords, !keywords.isEmpty {
                            // For Whisper models, use keywords as prompt
                            inputTranscription.prompt = keywords.joined(separator: ", ")
                        }
                        
                        // Set language if provided
                        if let language = config.language, !language.isEmpty {
                            inputTranscription.language = language
                        }
                        
                        sessionConfig.inputAudioTranscription = inputTranscription
                        
                        // Configure noise reduction based on config or default to near_field
                        let noiseReductionType: Session.InputAudioNoiseReduction.NoiseReductionType
                        if let configuredType = config.noiseReductionType {
                            switch configuredType.lowercased() {
                            case "far_field":
                                noiseReductionType = .farField
                            case "near_field":
                                noiseReductionType = .nearField
                            default:
                                print("OpenAI Streaming: Unknown noise reduction type '\(configuredType)', defaulting to near_field")
                                noiseReductionType = .nearField
                            }
                        } else {
                            noiseReductionType = .nearField // Default for desktop microphones
                        }
                        
                        sessionConfig.inputAudioNoiseReduction = Session.InputAudioNoiseReduction(
                            type: noiseReductionType
                        )
                        
                        // Configure turn detection for manual mode (we control when to send audio)
                        sessionConfig.turnDetection = Session.TurnDetection(type: .none)
                        
                        // Set audio format to 24kHz 16-bit PCM mono (OpenAI Realtime standard)
                        sessionConfig.inputAudioFormat = .pcm16
                        sessionConfig.outputAudioFormat = .pcm16
                    }
                }
                
                print("OpenAI Streaming: Session configured successfully on attempt \(attempt)")
                return // Success, exit the retry loop
                
            } catch {
                lastError = error
                print("OpenAI Streaming: Configuration attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    print("OpenAI Streaming: Retrying configuration in 1 second...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                }
            }
        }
        
        // If we get here, all retries failed
        throw StreamingError.configurationError("Failed to configure session after \(maxRetries) attempts: \(lastError?.localizedDescription ?? "Unknown error")")
    }
    
    private func mapToTranscriptionModel(_ model: String) -> Session.InputAudioTranscription.TranscriptionModel {
        switch model {
        case "whisper-1":
            return .whisper
        case "gpt-4o-transcribe":
            return .gpt4o
        case "gpt-4o-mini-transcribe":
            return .gpt4oMini
        default:
            print("OpenAI Streaming: Unknown model '\(model)', defaulting to whisper-1")
            return .whisper
        }
    }
    
    private func startMessageListener(for session: OpenAIRealtimeSession) {
        // Listen to the conversation's entries for transcription updates
        Task { [weak session] in
            guard let session = session else { return }
            
            // Monitor conversation entries for user input_audio messages with transcripts
            var lastEntryCount = 0
            
            while session.isActive {
                await Task.yield() // Allow other tasks to run
                
                let currentEntries = await session.conversation.entries
                if currentEntries.count > lastEntryCount {
                    // Process new entries
                    let newEntries = Array(currentEntries.suffix(currentEntries.count - lastEntryCount))
                    
                    for entry in newEntries {
                        await self.handleConversationEntry(entry, for: session)
                    }
                    
                    lastEntryCount = currentEntries.count
                }
                
                // Brief pause before checking again
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
    
    private func handleConversationEntry(_ entry: Item, for session: OpenAIRealtimeSession) async {
        // Look for user input_audio messages with transcription content
        guard case .message(let message) = entry,
              message.role == .user else { return }
        
        for content in message.content {
            if case .input_audio(let audioContent) = content,
               let transcript = audioContent.transcript {
                
                print("OpenAI Streaming: Transcription completed: '\(transcript)'")
                
                session.finalTranscript = transcript
                
                let chunk = TranscriptionChunk(
                    text: transcript,
                    isFinal: true,
                    timestamp: Date()
                )
                
                session.yieldPartialResult(chunk)
            }
        }
    }
    
    private func waitForFinalTranscript(session: OpenAIRealtimeSession) async throws -> String {
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
    
    private func cleanupSession(_ session: OpenAIRealtimeSession) async {
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