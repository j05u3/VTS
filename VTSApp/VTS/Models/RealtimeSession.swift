import Foundation

public class RealtimeSession {
    public let sessionId: String
    public let webSocket: URLSessionWebSocketTask
    public let partialResultsStream: AsyncThrowingStream<TranscriptionChunk, Error>
    private let partialResultsContinuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation
    
    public var isActive: Bool = false
    public var finalTranscript: String = ""
    
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
    
    public func finishWithError(_ error: Error) {
        partialResultsContinuation.finish(throwing: error)
    }
    
    public func cleanup() async {
        isActive = false
        webSocket.cancel(with: .goingAway, reason: nil)
        finishPartialResults()
    }
}