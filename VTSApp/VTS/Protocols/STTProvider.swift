import Foundation

public protocol STTProvider {
    var providerType: STTProviderType { get }
    
    func transcribe(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig
    ) async throws -> String
    
    func validateConfig(_ config: ProviderConfig) throws
}

// New streaming protocol for chunked transcription with partial results
public protocol StreamingSTTProvider: STTProvider {
    func transcribeStreaming(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig,
        onPartialResult: @escaping (String) -> Void
    ) async throws -> String
}

// Voice Activity Detection for intelligent buffering
public class VoiceActivityDetector {
    private let silenceThreshold: Float = 0.01
    private let minChunkDuration: TimeInterval = 1.0 // Minimum 1 second chunks
    private let maxChunkDuration: TimeInterval = 10.0 // Maximum 10 seconds to prevent timeouts
    private let silenceTimeout: TimeInterval = 2.0 // 2 seconds of silence ends a chunk
    
    private var lastVoiceActivity: Date?
    private var chunkStartTime: Date?
    
    public init() {}
    
    public func shouldSendChunk(audioLevel: Float, chunkDuration: TimeInterval) -> ChunkDecision {
        let now = Date()
        let hasVoice = audioLevel > silenceThreshold
        
        if hasVoice {
            lastVoiceActivity = now
            if chunkStartTime == nil {
                chunkStartTime = now
            }
        }
        
        // Force send if we've reached max duration
        if chunkDuration >= maxChunkDuration {
            return .sendAndReset
        }
        
        // Send if we have enough audio and recent silence
        if let lastVoice = lastVoiceActivity,
           chunkDuration >= minChunkDuration,
           now.timeIntervalSince(lastVoice) >= silenceTimeout {
            return .sendAndReset
        }
        
        // Continue collecting
        return .continueCollecting
    }
    
    public func reset() {
        lastVoiceActivity = nil
        chunkStartTime = nil
    }
}

public enum ChunkDecision {
    case continueCollecting       // Keep collecting audio
    case sendAndReset   // Send current chunk and start new one
}

// Audio chunk for streaming
public struct AudioChunk {
    let data: Data
    let timestamp: Date
    let duration: TimeInterval
    
    public init(data: Data, timestamp: Date = Date(), duration: TimeInterval) {
        self.data = data
        self.timestamp = timestamp
        self.duration = duration
    }
}

public enum STTError: Error, LocalizedError, Equatable {
    case invalidAPIKey
    case invalidModel
    case networkError(String)
    case audioProcessingError(String)
    case transcriptionError(String)
    case chunkProcessingError(String)
    
    public static func == (lhs: STTError, rhs: STTError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAPIKey, .invalidAPIKey),
             (.invalidModel, .invalidModel):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError == rhsError
        case (.audioProcessingError(let lhsMessage), .audioProcessingError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.transcriptionError(let lhsMessage), .transcriptionError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.chunkProcessingError(let lhsMessage), .chunkProcessingError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .invalidModel:
            return "Invalid model specified"
        case .networkError(let error):
            return "Network error: \(error)"
        case .audioProcessingError(let message):
            return "Audio processing error: \(message)"
        case .transcriptionError(let message):
            return "Transcription error: \(message)"
        case .chunkProcessingError(let message):
            return "Chunk processing error: \(message)"
        }
    }
}