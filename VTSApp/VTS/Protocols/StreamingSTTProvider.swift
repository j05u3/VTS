import Foundation

public protocol StreamingSTTProvider {
    var providerType: STTProviderType { get }
    
    func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession
    func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws
    func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String
    func validateConfig(_ config: ProviderConfig) throws
}

public enum StreamingError: Error, LocalizedError, Equatable {
    case connectionFailed(String)
    case sessionError(String)
    case audioStreamError(String)
    case invalidConfiguration(String)
    case partialResultsError(String)
    
    public static func == (lhs: StreamingError, rhs: StreamingError) -> Bool {
        switch (lhs, rhs) {
        case (.connectionFailed(let lhsError), .connectionFailed(let rhsError)):
            return lhsError == rhsError
        case (.sessionError(let lhsError), .sessionError(let rhsError)):
            return lhsError == rhsError
        case (.audioStreamError(let lhsMessage), .audioStreamError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidConfiguration(let lhsMessage), .invalidConfiguration(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.partialResultsError(let lhsMessage), .partialResultsError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let error):
            return "Connection failed: \(error)"
        case .sessionError(let error):
            return "Session error: \(error)"
        case .audioStreamError(let message):
            return "Audio streaming error: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .partialResultsError(let message):
            return "Partial results error: \(message)"
        }
    }
}