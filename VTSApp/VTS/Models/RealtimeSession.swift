
import Foundation
import Combine

public class RealtimeSession {
    public let sessionId: String
    public let webSocket: URLSessionWebSocketTask
    public let partialResultsStream: AsyncThrowingStream<TranscriptionChunk, Error>
    private let partialResultsContinuation: AsyncThrowingStream<TranscriptionChunk, Error>.Continuation
    public var isActive: Bool
    
    public init(sessionId: String, webSocket: URLSessionWebSocketTask) {
        self.sessionId = sessionId
        self.webSocket = webSocket
        (self.partialResultsStream, self.partialResultsContinuation) = AsyncThrowingStream.makeStream(of: TranscriptionChunk.self)
        self.isActive = true
    }
    
    public func yield(_ chunk: TranscriptionChunk) {
        partialResultsContinuation.yield(chunk)
    }
    
    public func finish(throwing error: Error? = nil) {
        isActive = false
        partialResultsContinuation.finish(throwing: error)
    }
}
