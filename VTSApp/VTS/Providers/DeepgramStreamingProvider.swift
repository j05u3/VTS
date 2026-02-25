import Foundation
import os

private let logger = Logger(subsystem: "com.voicetypestudio.app", category: "DeepgramStreaming")

public class DeepgramStreamingProvider: BaseStreamingSTTProvider {
    public override var providerType: STTProviderType { .deepgram }

    /// Deepgram supports live overlay with real-time partial results
    public override var supportsLiveOverlay: Bool { true }

    // MARK: - Constants
    private enum Constants {
        static let baseURL = "wss://api.deepgram.com/v1/listen"
        static let finalTranscriptTimeout: TimeInterval = 30.0
        static let transcriptCheckInterval: TimeInterval = 0.1
        // Reconnection settings
        static let maxReconnectAttempts = 3
        static let initialReconnectDelay: TimeInterval = 0.5
        static let maxReconnectDelay: TimeInterval = 4.0
    }

    private struct SessionState {
        let session: RealtimeSession
        var audioChunkCounter: Int = 0
        var urlSession: URLSession
        let config: ProviderConfig
        var reconnectAttempts: Int = 0
        var isReconnecting: Bool = false
    }

    private var sessions: [String: SessionState] = [:]

    public override init() {
        super.init()
    }

    // MARK: - StreamingSTTProvider Implementation

    public override func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession {
        try validateConfig(config)

        // Notify that we're connecting
        onConnectionStateChanged?(.connecting)

        // Build WebSocket URL with query parameters
        let url = try buildWebSocketURL(config: config)

        let sessionId = UUID().uuidString

        logger.info("Starting realtime session \(sessionId)")
        logger.debug("URL (token redacted) = \(url.absoluteString)")
        logger.debug("API Key length = \(config.apiKey.count)")

        // Create WebSocket with custom URLSession that has auth header in configuration
        let (webSocket, urlSession) = try await createDeepgramWebSocket(url: url, apiKey: config.apiKey)
        let session = RealtimeSession(sessionId: sessionId, webSocket: webSocket)
        session.isActive = true

        sessions[sessionId] = SessionState(
            session: session,
            urlSession: urlSession,
            config: config
        )

        // Start the background listener for metadata and transcripts BEFORE confirming
        // This ensures we're ready to receive responses before audio starts flowing
        startMessageListener(for: session)

        // Deepgram is ready to receive audio immediately after WebSocket connects
        // Unlike OpenAI, we don't need to wait for metadata before streaming
        // Confirm session so audio can start flowing
        session.confirmSession()
        logger.debug("Session confirmed (Deepgram accepts audio immediately)")

        // Notify that we're connected
        onConnectionStateChanged?(.connected)

        logger.info("Session \(sessionId) established")
        return session
    }

    public override func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws {
        try validateSessionState(session, operation: "streamAudio")

        // Check if we're currently reconnecting - buffer or fail
        if sessions[session.sessionId]?.isReconnecting == true {
            throw StreamingError.audioStreamError("Cannot stream audio while reconnecting")
        }

        // Deepgram accepts raw PCM16 audio directly (no JSON wrapping)
        // Send as binary WebSocket message
        let message = URLSessionWebSocketTask.Message.data(audioData)
        try await session.webSocket.send(message)

        sessions[session.sessionId]?.audioChunkCounter += 1
        let currentCount = sessions[session.sessionId]?.audioChunkCounter ?? 0

        if currentCount % 50 == 0 {
            logger.debug("Sent audio chunk #\(currentCount) (\(audioData.count) bytes)")
        }
    }

    public override func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String {
        try validateSessionState(session, operation: "finishAndGetTranscription")

        logger.info("Finishing transcription, sending CloseStream")

        // Send close-stream message to signal end of audio
        let closeMessage = URLSessionWebSocketTask.Message.string("{\"type\": \"CloseStream\"}")
        try await session.webSocket.send(closeMessage)

        // Wait for final transcript
        let finalTranscript = try await waitForFinalTranscript(session: session)

        logger.info("Final transcript received: '\(finalTranscript)'")

        // Cleanup in background
        Task {
            await cleanupSession(session)
        }

        return finalTranscript
    }

    public override func validateConfig(_ config: ProviderConfig) throws {
        guard !config.apiKey.isEmpty else {
            throw StreamingError.invalidConfiguration("API key is empty")
        }

        guard STTProviderType.deepgram.realtimeModels.contains(config.model) else {
            throw StreamingError.invalidConfiguration("Invalid model: \(config.model). Valid models: \(STTProviderType.deepgram.realtimeModels)")
        }
    }

    // MARK: - Private Methods

    /// Creates a WebSocket connection to Deepgram with proper authentication
    /// URLSessionWebSocketTask doesn't properly send custom headers, so we use a delegate-based approach
    private func createDeepgramWebSocket(url: URL, apiKey: String) async throws -> (URLSessionWebSocketTask, URLSession) {
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0

        // Create a custom URLSession configuration
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Authorization": "Token \(apiKey)"]

        let urlSession = URLSession(configuration: config)

        let webSocket = urlSession.webSocketTask(with: request)

        logger.debug("Created WebSocket task with auth header")
        webSocket.resume()

        // Wait for connection using event-driven approach
        logger.debug("Waiting for connection...")
        try await waitForWebSocketConnection(webSocket: webSocket)

        logger.info("WebSocket connected successfully")
        return (webSocket, urlSession)
    }

    /// Waits for WebSocket connection using event-driven polling instead of fixed sleep
    private func waitForWebSocketConnection(webSocket: URLSessionWebSocketTask, timeout: TimeInterval = 10.0) async throws {
        let startTime = Date()

        while true {
            let elapsed = Date().timeIntervalSince(startTime)

            if elapsed >= timeout {
                throw StreamingError.connectionFailed("WebSocket connection timeout after \(timeout) seconds")
            }

            switch webSocket.state {
            case .running:
                return  // Connected successfully
            case .completed, .canceling:
                throw StreamingError.connectionFailed("WebSocket connection failed - state: \(webSocket.state)")
            case .suspended:
                // Still connecting, yield to allow state updates
                await Task.yield()
            @unknown default:
                throw StreamingError.connectionFailed("Unknown WebSocket state: \(webSocket.state)")
            }
        }
    }

    private func buildWebSocketURL(config: ProviderConfig) throws -> URL {
        var components = URLComponents(string: Constants.baseURL)!
        var queryItems: [URLQueryItem] = []

        // Model
        queryItems.append(URLQueryItem(name: "model", value: config.model))

        // Language (default to multi-language)
        let language = config.language?.isEmpty == false ? config.language! : "multi"
        queryItems.append(URLQueryItem(name: "language", value: language))

        // Enable interim results for live transcription
        queryItems.append(URLQueryItem(name: "interim_results", value: "true"))

        // Audio encoding: linear16 (PCM16) at 24kHz mono (matches CaptureEngine output)
        queryItems.append(URLQueryItem(name: "encoding", value: "linear16"))
        queryItems.append(URLQueryItem(name: "sample_rate", value: "24000"))
        queryItems.append(URLQueryItem(name: "channels", value: "1"))

        // Quality features
        queryItems.append(URLQueryItem(name: "punctuate", value: "true"))
        queryItems.append(URLQueryItem(name: "smart_format", value: "true"))

        // Endpointing for utterance detection (300ms silence)
        queryItems.append(URLQueryItem(name: "endpointing", value: "300"))

        // Keywords if provided (not for nova-3 which uses different mechanism)
        if let keywords = config.keywords, !keywords.isEmpty, config.model != "nova-3" {
            for keyword in keywords {
                queryItems.append(URLQueryItem(name: "keywords", value: keyword))
            }
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw StreamingError.invalidConfiguration("Failed to construct WebSocket URL")
        }

        return url
    }

    private func startMessageListener(for session: RealtimeSession) {
        Task {
            logger.debug("Message listener started, waiting for messages...")
            do {
                while session.isActive {
                    logger.debug("Waiting to receive message...")
                    let message = try await session.webSocket.receive()
                    logger.debug("Received message from WebSocket")
                    try await handleIncomingMessage(message, session: session)
                }
            } catch {
                logger.error("Message listener ended with error: \(error)")
                logger.debug("Error details - \(String(describing: error))")

                // Check if this is a connection error we can recover from
                let isConnectionError = isRecoverableConnectionError(error)
                let currentAttempts = sessions[session.sessionId]?.reconnectAttempts ?? 0
                let alreadyReconnecting = sessions[session.sessionId]?.isReconnecting ?? false

                if isConnectionError && currentAttempts < Constants.maxReconnectAttempts && !alreadyReconnecting && session.isActive {
                    logger.warning("Connection lost, attempting reconnect (\(currentAttempts + 1)/\(Constants.maxReconnectAttempts))...")
                    await attemptReconnect(session: session)
                } else {
                    // Can't recover - fail the session
                    if !session.isSessionConfirmed {
                        logger.warning("Session was not confirmed, failing confirmation")
                        session.failSessionConfirmation(with: error)
                    }
                    session.finishPartialResultsWithError(error)
                    await cleanupSession(session)
                }
            }
        }
    }

    private func isRecoverableConnectionError(_ error: Error) -> Bool {
        let errorString = String(describing: error).lowercased()
        // Check for common WebSocket/network disconnect errors
        return errorString.contains("connection") ||
               errorString.contains("socket") ||
               errorString.contains("network") ||
               errorString.contains("timed out") ||
               errorString.contains("eof") ||
               (error as NSError).domain == NSURLErrorDomain
    }

    private func attemptReconnect(session: RealtimeSession) async {
        let sessionId = session.sessionId
        guard sessions[sessionId] != nil else {
            logger.error("Cannot reconnect - no stored state for session \(sessionId)")
            return
        }

        let config = sessions[sessionId]!.config
        sessions[sessionId]!.isReconnecting = true
        // Increment attempt counter (initialized to 0 in SessionState, so first call yields 1)
        sessions[sessionId]!.reconnectAttempts += 1
        let currentAttempt = sessions[sessionId]!.reconnectAttempts

        // Notify about reconnection attempt
        onConnectionStateChanged?(.reconnecting(attempt: currentAttempt, maxAttempts: Constants.maxReconnectAttempts))

        // Calculate exponential backoff delay
        let delay = min(
            Constants.initialReconnectDelay * pow(2.0, Double(currentAttempt - 1)),
            Constants.maxReconnectDelay
        )
        logger.info("Waiting \(delay)s before reconnect attempt \(currentAttempt)...")

        do {
            try await Task.sleep(for: .seconds(delay))

            // Clean up old WebSocket
            session.webSocket.cancel(with: .goingAway, reason: nil)

            // Create new WebSocket connection
            let url = try buildWebSocketURL(config: config)
            let (newWebSocket, newURLSession) = try await createDeepgramWebSocket(url: url, apiKey: config.apiKey)

            // Update session with new WebSocket and URLSession
            session.webSocket = newWebSocket
            sessions[sessionId]?.urlSession = newURLSession
            logger.info("Reconnected successfully (attempt \(currentAttempt))")

            // Reset reconnect state on success
            sessions[sessionId]?.reconnectAttempts = 0
            sessions[sessionId]?.isReconnecting = false

            // Notify that we're connected again
            onConnectionStateChanged?(.connected)

            // Restart message listener for the new connection
            startMessageListener(for: session)

        } catch {
            logger.error("Reconnect attempt \(currentAttempt) failed: \(error)")
            sessions[sessionId]?.isReconnecting = false

            if currentAttempt >= Constants.maxReconnectAttempts {
                logger.error("Max reconnect attempts reached, giving up")
                // Notify about connection failure
                onConnectionStateChanged?(.error(message: "Connection lost"))
                session.finishPartialResultsWithError(StreamingError.connectionFailed("Connection lost after \(currentAttempt) reconnect attempts"))
                await cleanupSession(session)
            }
            // If not at max attempts, the next receive() error will trigger another attempt
        }
    }

    private func handleIncomingMessage(_ message: URLSessionWebSocketTask.Message, session: RealtimeSession) async throws {
        let jsonData: Data
        switch message {
        case .data(let data):
            logger.debug("Received binary data message (\(data.count) bytes)")
            jsonData = data
        case .string(let string):
            logger.debug("Received string message: \(String(string.prefix(500)))")
            guard let data = string.data(using: .utf8) else {
                logger.warning("Invalid string message encoding")
                return
            }
            jsonData = data
        @unknown default:
            logger.warning("Unknown message type")
            return
        }

        let response = try parseDeepgramResponse(jsonData)
        logger.debug("Parsed response type: \(response)")

        switch response {
        case .metadata(let metadata):
            logger.info("Received metadata - request_id: \(metadata.requestId)")
            session.confirmSession()

        case .transcript(let transcript):
            handleTranscript(transcript, session: session)

        case .error(let error):
            logger.error("Error - \(error.type): \(error.message)")
            let streamingError = StreamingError.sessionError("Deepgram error: \(error.message)")
            if !session.isSessionConfirmed {
                session.failSessionConfirmation(with: streamingError)
            }
            session.finishPartialResultsWithError(streamingError)
            session.isActive = false

        case .unknown(let type):
            logger.warning("Unknown message type: \(type)")
        }
    }

    private func handleTranscript(_ transcript: DeepgramTranscript, session: RealtimeSession) {
        guard let text = transcript.channel.alternatives.first?.transcript else {
            return
        }

        // Skip empty transcripts
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let chunk = TranscriptionChunk(
            text: text,
            isFinal: transcript.isFinal,
            timestamp: Date()
        )

        if transcript.isFinal {
            logger.info("Final transcript: '\(text)'")
            // Append to final transcript (there may be multiple final segments)
            if session.finalTranscript.isEmpty {
                session.finalTranscript = text
            } else {
                session.finalTranscript += " " + text
            }
        } else {
            logger.debug("Interim transcript: '\(text)'")
        }

        session.yieldPartialResult(chunk)
    }

    private func waitForFinalTranscript(session: RealtimeSession, timeout: TimeInterval = Constants.finalTranscriptTimeout) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                // Wait until we have a final transcript and session is no longer receiving
                var lastTranscript = ""
                var stableCount = 0

                while true {
                    try await Task.sleep(for: .seconds(Constants.transcriptCheckInterval))

                    let currentTranscript = session.finalTranscript
                    if !currentTranscript.isEmpty {
                        if currentTranscript == lastTranscript {
                            stableCount += 1
                            // Consider stable after 5 checks (500ms) without changes
                            if stableCount >= 5 {
                                return currentTranscript
                            }
                        } else {
                            lastTranscript = currentTranscript
                            stableCount = 0
                        }
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw StreamingError.sessionError("Final transcript timeout after \(timeout) seconds")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func cleanupSession(_ session: RealtimeSession) async {
        sessions.removeValue(forKey: session.sessionId)
        await session.cleanup()
        logger.info("Session \(session.sessionId) cleaned up")
    }

    private func validateSessionState(_ session: RealtimeSession, operation: String) throws {
        guard session.isActive else {
            throw StreamingError.sessionError("Session is not active for \(operation)")
        }
        guard sessions[session.sessionId] != nil else {
            throw StreamingError.sessionError("Session \(session.sessionId) not found")
        }
    }
}
