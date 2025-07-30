import Foundation

public struct TranscriptionChunk {
    public let text: String
    public let isFinal: Bool
    public let timestamp: Date
    
    public init(text: String, isFinal: Bool = false, timestamp: Date = Date()) {
        self.text = text
        self.isFinal = isFinal
        self.timestamp = timestamp
    }
}

public struct ProviderConfig {
    public let apiKey: String
    public let model: String
    public let systemPrompt: String?
    public let language: String?
    public let temperature: Float?
    
    public init(apiKey: String, model: String, systemPrompt: String? = nil, language: String? = nil, temperature: Float? = nil) {
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
        self.language = language
        self.temperature = temperature
    }
}

public enum STTProviderType: String, CaseIterable, Codable {
    case openai = "OpenAI"
    case groq = "Groq"
    
    public var defaultModels: [String] {
        switch self {
        case .openai:
            return ["whisper-1", "gpt-4o-transcribe", "gpt-4o-mini-transcribe"]
        case .groq:
            return ["whisper-large-v3-turbo", "whisper-large-v3"]
        }
    }
}