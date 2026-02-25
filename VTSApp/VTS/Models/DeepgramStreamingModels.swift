import Foundation

// MARK: - Deepgram WebSocket Response Types

public enum DeepgramResponse: CustomStringConvertible {
    case metadata(DeepgramMetadata)
    case transcript(DeepgramTranscript)
    case error(DeepgramError)
    case unknown(String)

    public var description: String {
        switch self {
        case .metadata: return "metadata"
        case .transcript: return "transcript"
        case .error: return "error"
        case .unknown(let type): return "unknown(\(type))"
        }
    }
}

// MARK: - Response Models (Decodable)

public struct DeepgramMetadata: Decodable {
    public let requestId: String
    public let modelUUID: String?

    private enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case modelUUID = "model_uuid"
    }
}

public struct DeepgramTranscript: Decodable {
    public let isFinal: Bool
    public let speechFinal: Bool
    public let channel: DeepgramChannel
    public let start: Double
    public let duration: Double

    private enum CodingKeys: String, CodingKey {
        case isFinal = "is_final"
        case speechFinal = "speech_final"
        case channel
        case start
        case duration
    }
}

public struct DeepgramChannel: Decodable {
    public let alternatives: [DeepgramAlternative]
}

public struct DeepgramAlternative: Decodable {
    public let transcript: String
    public let confidence: Double
    public let words: [DeepgramWord]?
}

public struct DeepgramWord: Decodable {
    public let word: String
    public let start: Double
    public let end: Double
    public let confidence: Double
}

public struct DeepgramError: Decodable {
    public let type: String
    public let message: String
    public let description: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case message
        case description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? "Unknown error"
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}

// MARK: - Type Wrapper for Decoding

/// Internal wrapper to determine response type before full decoding
private struct DeepgramResponseType: Decodable {
    let type: String
}

// MARK: - Parsing

public func parseDeepgramResponse(_ data: Data) throws -> DeepgramResponse {
    let decoder = JSONDecoder()

    // First, determine the response type
    let responseType: DeepgramResponseType
    do {
        responseType = try decoder.decode(DeepgramResponseType.self, from: data)
    } catch {
        throw StreamingError.sessionError("Invalid Deepgram response format: \(error.localizedDescription)")
    }

    // Decode based on type
    switch responseType.type {
    case "Metadata":
        let metadata = try decoder.decode(DeepgramMetadata.self, from: data)
        return .metadata(metadata)

    case "Results":
        let transcript = try decoder.decode(DeepgramTranscript.self, from: data)
        return .transcript(transcript)

    case "Error":
        // Error responses may have nested "error" object or flat structure
        do {
            let errorResponse = try decoder.decode(DeepgramNestedError.self, from: data)
            return .error(errorResponse.error)
        } catch {
            let flatError = try decoder.decode(DeepgramError.self, from: data)
            return .error(flatError)
        }

    default:
        return .unknown(responseType.type)
    }
}

/// Wrapper for nested error responses
private struct DeepgramNestedError: Decodable {
    let error: DeepgramError
}
