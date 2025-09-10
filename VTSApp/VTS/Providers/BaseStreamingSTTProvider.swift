import Foundation

/// Base class for streaming STT providers that provides common WebSocket functionality
/// with connection management and error handling
public class BaseStreamingSTTProvider: StreamingSTTProvider {
    public var providerType: STTProviderType {
        fatalError("Must be implemented by subclass")
    }
    
    // Connection configuration
    private let connectionTimeout: TimeInterval = 10.0 // seconds
    private let maxReconnectAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0 // seconds
    
    // MARK: - StreamingSTTProvider Protocol Requirements (to be implemented by subclasses)
    
    public func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession {
        fatalError("Must be implemented by subclass")
    }
    
    public func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws {
        fatalError("Must be implemented by subclass")
    }
    
    public func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String {
        fatalError("Must be implemented by subclass")
    }
    
    public func validateConfig(_ config: ProviderConfig) throws {
        fatalError("Must be implemented by subclass")
    }
    
    // MARK: - Protected Methods for Subclasses
    
    /// Creates a WebSocket connection with timeout, authentication, and protocols
    internal func createWebSocketConnection(
        url: URL,
        headers: [String: String] = [:],
        protocols: [String] = [],
        providerName: String
    ) async throws -> URLSessionWebSocketTask {
        let webSocketTask: URLSessionWebSocketTask
        
        if !protocols.isEmpty {
            // Use protocols-based WebSocket creation (preferred for OpenAI)
            print("\(providerName): Creating WebSocket connection to \(url) with protocols: \(protocols)")
            webSocketTask = URLSession.shared.webSocketTask(with: url, protocols: protocols)
        } else {
            // Use headers-based WebSocket creation (fallback for other providers)
            var request = URLRequest(url: url)
            request.timeoutInterval = connectionTimeout
            
            // Add headers
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            print("\(providerName): Creating WebSocket connection to \(url) with headers")
            webSocketTask = URLSession.shared.webSocketTask(with: request)
        }
        
        webSocketTask.resume()
        
        // Wait for connection to be established
        try await waitForConnectionEstablishment(webSocketTask: webSocketTask, providerName: providerName)
        
        return webSocketTask
    }
    
    /// Waits for WebSocket connection to be established
    private func waitForConnectionEstablishment(
        webSocketTask: URLSessionWebSocketTask,
        providerName: String
    ) async throws {
        print("\(providerName): Waiting for WebSocket connection to establish...")
        
        // Create a timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(connectionTimeout * 1_000_000_000))
            throw StreamingError.connectionFailed("Connection timeout after \(connectionTimeout) seconds")
        }
        
        // Create a connection check task
        let connectionTask = Task {
            var attempts = 0
            let maxAttempts = Int(connectionTimeout * 10) // Check every 100ms
            
            while attempts < maxAttempts {
                if webSocketTask.state == .running {
                    print("\(providerName): WebSocket connection established successfully")
                    return
                }
                
                if webSocketTask.state == .canceling || webSocketTask.state == .completed {
                    throw StreamingError.connectionFailed("WebSocket connection failed")
                }
                
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                attempts += 1
            }
            
            throw StreamingError.connectionFailed("Connection establishment timeout")
        }
        
        // Race between timeout and connection establishment
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await timeoutTask.value }
                group.addTask { try await connectionTask.value }
                
                // Wait for the first task to complete
                try await group.next()
                
                // Cancel remaining tasks
                group.cancelAll()
            }
        } catch {
            webSocketTask.cancel(with: .abnormalClosure, reason: nil)
            throw error
        }
        
        // Clean up timeout task
        timeoutTask.cancel()
    }
    
    /// Sends a message through WebSocket with error handling
    internal func sendMessage(
        _ message: [String: Any],
        through webSocket: URLSessionWebSocketTask,
        providerName: String
    ) async throws {
        let jsonData = try JSONSerialization.data(withJSONObject: message)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "Invalid JSON"
        let message = URLSessionWebSocketTask.Message.string(jsonString) // Use string instead of data
        
        print("\(providerName): Sending WebSocket message: \(jsonString)")
        
        do {
            try await webSocket.send(message)
        } catch {
            print("\(providerName): Failed to send WebSocket message: \(error)")
            throw StreamingError.audioStreamError("Failed to send message: \(error.localizedDescription)")
        }
    }
    
    /// Receives a message from WebSocket with error handling
    internal func receiveMessage(
        from webSocket: URLSessionWebSocketTask,
        providerName: String
    ) async throws -> [String: Any] {
        do {
            let message = try await webSocket.receive()
            
            switch message {
            case .data(let data):
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw StreamingError.sessionError("Invalid JSON response")
                }
                return json
                
            case .string(let string):
                guard let data = string.data(using: .utf8),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw StreamingError.sessionError("Invalid JSON string response")
                }
                return json
                
            @unknown default:
                throw StreamingError.sessionError("Unknown message type")
            }
        } catch {
            print("\(providerName): Failed to receive WebSocket message: \(error)")
            if let streamingError = error as? StreamingError {
                throw streamingError
            } else {
                throw StreamingError.sessionError("Failed to receive message: \(error.localizedDescription)")
            }
        }
    }
    
    /// Determines if an error is retryable (connection/network errors)
    internal func isRetryableError(_ error: Error) -> Bool {
        // Check for URLError cases that are typically retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        // Check for StreamingError cases
        if let streamingError = error as? StreamingError {
            switch streamingError {
            case .connectionFailed, .audioStreamError:
                return true
            case .sessionError, .invalidConfiguration, .partialResultsError:
                return false
            }
        }
        
        return false
    }
}