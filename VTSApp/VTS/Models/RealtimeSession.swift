import Foundation
import os

private let logger = Logger(subsystem: "com.voicetypestudio.app", category: "RealtimeSession")

// Local error types for RealtimeSession
public enum SessionError: Error, LocalizedError {
    case confirmationTimeout(TimeInterval)
    case cleanedUp
    
    public var errorDescription: String? {
        switch self {
        case .confirmationTimeout(let timeout):
            return "Session confirmation timeout after \(timeout) seconds"
        case .cleanedUp:
            return "Session was cleaned up"
        }
    }
}

public class RealtimeSession {
    public let sessionId: String
    public var webSocket: URLSessionWebSocketTask  // var to allow reassignment during reconnection
    public let partialResultsStream: AsyncThrowingStream<TranscriptionChunk, Error>
    private let partialResultsContinuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation
    
    public var isActive: Bool = false
    public var finalTranscript: String = ""
    public var isSessionConfirmed: Bool = false
    private var sessionConfirmationContinuation: CheckedContinuation<Void, Error>?
    
    // Timing tracking
    public let sessionStartTime: Date
    public var sessionConfirmedTime: Date?
    
    // Callback for when session is confirmed
    public var onSessionConfirmed: (() -> Void)?
    
    /// Returns the time in milliseconds from session start to confirmation
    public var sessionConfirmationDurationMs: Int? {
        guard let confirmedTime = sessionConfirmedTime else { return nil }
        return Int((confirmedTime.timeIntervalSince(sessionStartTime)) * 1000)
    }
    
    public init(sessionId: String, webSocket: URLSessionWebSocketTask) {
        self.sessionId = sessionId
        self.webSocket = webSocket
        self.sessionStartTime = Date()
        
        // Create the async stream for partial results
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: TranscriptionChunk.self)
        self.partialResultsStream = stream
        self.partialResultsContinuation = continuation
    }
    
    public func yieldPartialResult(_ chunk: TranscriptionChunk) {
        partialResultsContinuation.yield(chunk)
    }
    
    public func finishPartialResults() {
        partialResultsContinuation.finish()
    }
    
    public func finishPartialResultsWithError(_ error: Error) {
        partialResultsContinuation.finish(throwing: error)
    }
    
    public func waitForSessionConfirmation(timeout: TimeInterval = 10.0) async throws {
        logger.debug("waitForSessionConfirmation() called, isSessionConfirmed=\(self.isSessionConfirmed)")

        // If already confirmed (race condition - metadata arrived before we started waiting), return immediately
        if isSessionConfirmed {
            logger.debug("Session already confirmed, returning immediately")
            return
        }

        do {
            try await withTimeout(timeout) {
                try await withCheckedThrowingContinuation { continuation in
                    logger.debug("Setting up continuation, isSessionConfirmed=\(self.isSessionConfirmed)")
                    // Double-check after setting continuation (another race condition guard)
                    if self.isSessionConfirmed {
                        logger.debug("Already confirmed inside continuation setup, resuming")
                        continuation.resume()
                        return
                    }
                    self.sessionConfirmationContinuation = continuation
                    logger.debug("Continuation set, waiting for confirmSession()")
                }
            }
            logger.debug("Confirmation received successfully")
        } catch is TimeoutError {
            logger.warning("Timeout waiting for confirmation")
            throw SessionError.confirmationTimeout(timeout)
        }
    }
    
    public func confirmSession() {
        logger.debug("confirmSession() called, continuation is \(self.sessionConfirmationContinuation == nil ? "nil" : "set")")
        isSessionConfirmed = true
        sessionConfirmedTime = Date()
        if let continuation = sessionConfirmationContinuation {
            logger.debug("Resuming continuation")
            continuation.resume()
            sessionConfirmationContinuation = nil
        } else {
            logger.debug("No continuation to resume (will be caught by isSessionConfirmed check)")
        }

        // Notify callback that session is confirmed
        onSessionConfirmed?()
    }
    
    public func failSessionConfirmation(with error: Error) {
        sessionConfirmationContinuation?.resume(throwing: error)
        sessionConfirmationContinuation = nil
    }
    
    public func cleanup() async {
        isActive = false
        webSocket.cancel(with: .goingAway, reason: nil)
        finishPartialResults()
        
        // Clean up any pending session confirmation
        sessionConfirmationContinuation?.resume(throwing: SessionError.cleanedUp)
        sessionConfirmationContinuation = nil
    }
}