import Foundation

/// Base class for streaming STT providers that provides common WebSocket functionality
/// with connection management and error handling
public class BaseStreamingSTTProvider: StreamingSTTProvider {
    public var providerType: STTProviderType {
        fatalError("Must be implemented by subclass")
    }

    /// Default to false - subclasses override if they support live overlay
    public var supportsLiveOverlay: Bool {
        return false
    }

    // Connection configuration
    private let connectionTimeout: TimeInterval = 10.0 // seconds
    private let maxReconnectAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0 // seconds

    /// Callback for connection state changes - set by StreamingTranscriptionService
    public var onConnectionStateChanged: ((ConnectionState) -> Void)?
    
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
    
    /// Waits for WebSocket connection to be established using event-driven approach
    private func waitForConnectionEstablishment(
        webSocketTask: URLSessionWebSocketTask,
        providerName: String
    ) async throws {
        print("\(providerName): Waiting for WebSocket connection to establish...")
        
        return try await withCheckedThrowingContinuation { continuation in
            // Set up timeout
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(connectionTimeout))
                continuation.resume(throwing: StreamingError.connectionFailed("Connection timeout after \(connectionTimeout) seconds"))
            }
            
            // Check initial state
            let initialState = webSocketTask.state
            switch initialState {
            case .running:
                print("\(providerName): WebSocket connection already established")
                timeoutTask.cancel()
                continuation.resume()
                return
            case .canceling, .completed:
                timeoutTask.cancel()
                continuation.resume(throwing: StreamingError.connectionFailed("WebSocket connection failed"))
                return
            default:
                break
            }
            
            // Use a more efficient state monitoring approach
            let stateMonitor = Task {
                // Monitor state changes with minimal overhead
                var hasResumed = false
                
                while !hasResumed && !Task.isCancelled {
                    let currentState = webSocketTask.state
                    
                    switch currentState {
                    case .running:
                        print("\(providerName): WebSocket connection established successfully")
                        if !hasResumed {
                            hasResumed = true
                            timeoutTask.cancel()
                            continuation.resume()
                        }
                        return
                    case .canceling, .completed:
                        if !hasResumed {
                            hasResumed = true
                            timeoutTask.cancel()
                            continuation.resume(throwing: StreamingError.connectionFailed("WebSocket connection failed"))
                        }
                        return
                    case .suspended:
                        // Use yield instead of sleep for better performance
                        await Task.yield()
                    @unknown default:
                        if !hasResumed {
                            hasResumed = true
                            timeoutTask.cancel()
                            continuation.resume(throwing: StreamingError.connectionFailed("Unknown WebSocket state"))
                        }
                        return
                    }
                }
            }
            
            // Clean up when done
            Task {
                await stateMonitor.value
                timeoutTask.cancel()
            }
        }
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