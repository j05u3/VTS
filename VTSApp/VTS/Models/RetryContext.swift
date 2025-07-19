import Foundation

/// Context information needed to retry a failed transcription
public struct RetryContext {
    /// Audio data to be transcribed
    public let audioData: Data
    
    /// Provider configuration (API key, model, etc.)
    public let config: ProviderConfig
    
    /// The error that caused the failure
    public let originalError: STTError
    
    /// Provider type that should handle the retry
    public let providerType: STTProviderType
    
    /// Timestamp when the original attempt was made
    public let timestamp: Date
    
    public init(
        audioData: Data,
        config: ProviderConfig,
        originalError: STTError,
        providerType: STTProviderType,
        timestamp: Date = Date()
    ) {
        self.audioData = audioData
        self.config = config
        self.originalError = originalError
        self.providerType = providerType
        self.timestamp = timestamp
    }
}

// MARK: - Convenience Extensions

extension RetryContext {
    /// Check if this retry context is still valid (not too old)
    public var isValid: Bool {
        let maxAge: TimeInterval = 300 // 5 minutes
        return Date().timeIntervalSince(timestamp) < maxAge
    }
    
    /// Get a description of the retry context for logging
    public var description: String {
        let sizeKB = audioData.count / 1024
        return "RetryContext(provider: \(providerType.rawValue), audioSize: \(sizeKB)KB, error: \(ErrorTranslator.getShortDescription(originalError)))"
    }
}
