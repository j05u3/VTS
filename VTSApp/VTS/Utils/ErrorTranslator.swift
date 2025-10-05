import Foundation

/// Translates technical errors into user-friendly messages
public struct ErrorTranslator {
    
    /// User-friendly error information
    public struct ErrorTranslation {
        public let message: String
        public let hint: String
        public let canRetry: Bool
        public let needsSettings: Bool
        
        public init(message: String, hint: String, canRetry: Bool = false, needsSettings: Bool = false) {
            self.message = message
            self.hint = hint
            self.canRetry = canRetry
            self.needsSettings = needsSettings
        }
    }
    
    /// Convert STTError to user-friendly message
    public static func translate(_ error: STTError) -> ErrorTranslation {
        switch error {
        case .invalidAPIKey:
            return ErrorTranslation(
                message: "Invalid API key",
                hint: "Please check your API key in Settings",
                canRetry: false,
                needsSettings: true
            )
            
        case .invalidModel:
            return ErrorTranslation(
                message: "Invalid model selected",
                hint: "Please select a different model in Settings",
                canRetry: false,
                needsSettings: true
            )
            
        case .networkError(let details):
            // Parse network error details to provide specific guidance
            if details.contains("timed out") || details.contains("timeout") {
                return ErrorTranslation(
                    message: "Request timed out",
                    hint: "Check your internet connection and try again",
                    canRetry: true,
                    needsSettings: false
                )
            } else if details.contains("rate limit") || details.contains("429") {
                return ErrorTranslation(
                    message: "Rate limit reached",
                    hint: "Too many requests. Please wait a moment before trying again",
                    canRetry: true,
                    needsSettings: false
                )
            } else if details.contains("Bad server response") || details.contains("500") || details.contains("502") || details.contains("503") {
                return ErrorTranslation(
                    message: "Server temporarily unavailable",
                    hint: "The service is having issues. Please try again later",
                    canRetry: true,
                    needsSettings: false
                )
            } else if details.contains("cannot connect") || details.contains("network") {
                return ErrorTranslation(
                    message: "Network connection failed",
                    hint: "Check your internet connection and try again",
                    canRetry: true,
                    needsSettings: false
                )
            } else {
                return ErrorTranslation(
                    message: "Network error occurred",
                    hint: "Check your internet connection and try again",
                    canRetry: true,
                    needsSettings: false
                )
            }
            
        case .audioProcessingError(let details):
            if details.contains("Not enough audio data") {
                return ErrorTranslation(
                    message: "Recording too short",
                    hint: "Try recording for a longer duration",
                    canRetry: true,
                    needsSettings: false
                )
            } else if details.contains("permission") {
                return ErrorTranslation(
                    message: "Microphone permission required",
                    hint: "Grant microphone access in System Preferences",
                    canRetry: false,
                    needsSettings: true
                )
            } else {
                return ErrorTranslation(
                    message: "Audio processing failed",
                    hint: "Try recording again or check your microphone",
                    canRetry: true,
                    needsSettings: false
                )
            }
            
        case .transcriptionError(let details):
            // Handle various transcription-specific errors
            if details.contains("API key") {
                return ErrorTranslation(
                    message: "API authentication failed",
                    hint: "Please check your API key in Settings",
                    canRetry: false,
                    needsSettings: true
                )
            } else if details == "System prompt too long" {
                return ErrorTranslation(
                    message: "System prompt too long",
                    hint: "Your custom prompt exceeds the maximum character limit. Please shorten it in Settings",
                    canRetry: false,
                    needsSettings: true
                )
            } else if details.contains("quota") || details.contains("billing") {
                return ErrorTranslation(
                    message: "Account quota exceeded",
                    hint: "Check your account billing and usage limits",
                    canRetry: false,
                    needsSettings: true
                )
            } else if details.contains("timeout") || details.contains("timed out") {
                return ErrorTranslation(
                    message: "Transcription timed out",
                    hint: "This can happen with longer audio. Try again?",
                    canRetry: true,
                    needsSettings: false
                )
            } else if details.contains("retry") || details.contains("attempts") {
                return ErrorTranslation(
                    message: "Multiple attempts failed",
                    hint: "Service may be temporarily unavailable. Try again later",
                    canRetry: true,
                    needsSettings: false
                )
            } else {
                return ErrorTranslation(
                    message: "Transcription failed",
                    hint: "Please try recording again",
                    canRetry: true,
                    needsSettings: false
                )
            }
        }
    }
    
    /// Get a short description suitable for logging
    public static func getShortDescription(_ error: STTError) -> String {
        switch error {
        case .invalidAPIKey:
            return "Invalid API key"
        case .invalidModel:
            return "Invalid model"
        case .networkError:
            return "Network error"
        case .audioProcessingError:
            return "Audio processing error"
        case .transcriptionError:
            return "Transcription error"
        }
    }
}
