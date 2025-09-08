import Foundation

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
    public let webSocket: URLSessionWebSocketTask
    public let partialResultsStream: AsyncThrowingStream<TranscriptionChunk, Error>
    private let partialResultsContinuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation
    
    public var isActive: Bool = false
    public var finalTranscript: String = ""
    public var isSessionConfirmed: Bool = false
    private var sessionConfirmationContinuation: CheckedContinuation<Void, Error>?
    
    // Callback for when session is confirmed
    public var onSessionConfirmed: (() -> Void)?
    
    public init(sessionId: String, webSocket: URLSessionWebSocketTask) {
        self.sessionId = sessionId
        self.webSocket = webSocket
        
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
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add confirmation waiting task
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    self.sessionConfirmationContinuation = continuation
                }
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw SessionError.confirmationTimeout(timeout)
            }
            
            // Wait for the first task to complete
            try await group.next()
            
            // Cancel remaining tasks
            group.cancelAll()
        }
    }
    
    public func confirmSession() {
        isSessionConfirmed = true
        sessionConfirmationContinuation?.resume()
        sessionConfirmationContinuation = nil
        
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