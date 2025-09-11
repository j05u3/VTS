import Foundation

extension AsyncThrowingStream {
    public static func makeStream(of elementType: Element.Type = Element.self) -> (stream: AsyncThrowingStream<Element, Error>, continuation: AsyncThrowingStream<Element, Error>.Continuation) {
        var continuation: AsyncThrowingStream<Element, Error>.Continuation!
        let stream = AsyncThrowingStream<Element, Error> { cont in
            continuation = cont
        }
        return (stream, continuation)
    }
}

/// Timeout error for async operations
public struct TimeoutError: Error, LocalizedError {
    public let duration: TimeInterval
    
    public var errorDescription: String? {
        return "Operation timed out after \(duration) seconds"
    }
}

/// Execute an async operation with a timeout
/// - Parameters:
///   - timeout: The timeout duration in seconds
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: TimeoutError if the operation times out, or the error thrown by the operation
public func withTimeout<T>(
    _ timeout: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }
        
        // Add the timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError(duration: timeout)
        }
        
        // Wait for the first task to complete
        guard let result = try await group.next() else {
            throw TimeoutError(duration: timeout)
        }
        
        // Cancel remaining tasks
        group.cancelAll()
        
        return result
    }
}