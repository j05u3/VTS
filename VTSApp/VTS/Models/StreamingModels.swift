import Foundation

// MARK: - OpenAI Real-time API Models

/// OpenAI Real-time transcription session configuration
public struct OpenAIRealtimeSessionConfig {
    public let inputAudioFormat: String
    public let inputAudioTranscription: InputAudioTranscription
    public let turnDetection: TurnDetection?
    public let inputAudioNoiseReduction: NoiseReduction
    
    public init(
        model: String,
        prompt: String? = nil,
        language: String? = nil,
        inputAudioFormat: String = "pcm16",
        turnDetection: TurnDetection? = nil,
        noiseReductionType: String = "near_field"
    ) {
        self.inputAudioFormat = inputAudioFormat
        self.inputAudioTranscription = InputAudioTranscription(
            model: model,
            prompt: prompt,
            language: language
        )
        self.turnDetection = turnDetection
        self.inputAudioNoiseReduction = NoiseReduction(type: noiseReductionType)
    }
    
    public struct InputAudioTranscription: Codable {
        public let model: String
        public let prompt: String?
        public let language: String?
    }
    
    public struct TurnDetection: Codable {
        public let type: String
        public let threshold: Double?
        public let prefixPaddingMs: Int?
        public let silenceDurationMs: Int?
        
        enum CodingKeys: String, CodingKey {
            case type
            case threshold
            case prefixPaddingMs = "prefix_padding_ms"
            case silenceDurationMs = "silence_duration_ms"
        }
    }
    
    public struct NoiseReduction: Codable {
        public let type: String
    }
}

extension OpenAIRealtimeSessionConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case inputAudioFormat = "input_audio_format"
        case inputAudioTranscription = "input_audio_transcription"
        case turnDetection = "turn_detection"
        case inputAudioNoiseReduction = "input_audio_noise_reduction"
    }
}

// MARK: - OpenAI Real-time WebSocket Messages

/// OpenAI Real-time WebSocket message types
public enum OpenAIRealtimeMessage {
    case sessionUpdate(OpenAIRealtimeSessionConfig)
    case inputAudioBufferAppend(Data)
    case inputAudioBufferCommit
    case responseCancel
    
    public var messageType: String {
        switch self {
        case .sessionUpdate:
            return "session.update"
        case .inputAudioBufferAppend:
            return "input_audio_buffer.append"
        case .inputAudioBufferCommit:
            return "input_audio_buffer.commit"
        case .responseCancel:
            return "response.cancel"
        }
    }
    
    public func toDictionary() -> [String: Any] {
        switch self {
        case .sessionUpdate(let config):
            var dict: [String: Any] = [
                "type": messageType
            ]
            
            if let configData = try? JSONEncoder().encode(config),
               let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                dict.merge(configDict) { _, new in new }
            }
            
            return dict
            
        case .inputAudioBufferAppend(let audioData):
            return [
                "type": messageType,
                "audio": audioData.base64EncodedString()
            ]
            
        case .inputAudioBufferCommit:
            return [
                "type": messageType
            ]
            
        case .responseCancel:
            return [
                "type": messageType
            ]
        }
    }
}

// MARK: - OpenAI Real-time Response Models

/// OpenAI Real-time response event types
public enum OpenAIRealtimeEvent {
    case sessionCreated([String: Any])
    case sessionUpdated([String: Any])
    case inputAudioBufferCommitted([String: Any])
    case conversationItemInputAudioTranscriptionDelta(TranscriptionDelta)
    case conversationItemInputAudioTranscriptionCompleted(TranscriptionCompleted)
    case error(RealtimeError)
    case unknown([String: Any])
    
    public static func from(messageDict: [String: Any]) -> OpenAIRealtimeEvent {
        guard let type = messageDict["type"] as? String else {
            return .unknown(messageDict)
        }
        
        switch type {
        case "session.created":
            return .sessionCreated(messageDict)
            
        case "session.updated":
            return .sessionUpdated(messageDict)
            
        case "input_audio_buffer.committed":
            return .inputAudioBufferCommitted(messageDict)
            
        case "conversation.item.input_audio_transcription.delta":
            if let delta = TranscriptionDelta.from(messageDict) {
                return .conversationItemInputAudioTranscriptionDelta(delta)
            }
            return .unknown(messageDict)
            
        case "conversation.item.input_audio_transcription.completed":
            if let completed = TranscriptionCompleted.from(messageDict) {
                return .conversationItemInputAudioTranscriptionCompleted(completed)
            }
            return .unknown(messageDict)
            
        case "error":
            if let error = RealtimeError.from(messageDict) {
                return .error(error)
            }
            return .unknown(messageDict)
            
        default:
            return .unknown(messageDict)
        }
    }
}

public struct TranscriptionDelta {
    public let eventId: String
    public let itemId: String
    public let contentIndex: Int
    public let delta: String
    
    public static func from(_ dict: [String: Any]) -> TranscriptionDelta? {
        guard let eventId = dict["event_id"] as? String,
              let itemId = dict["item_id"] as? String,
              let contentIndex = dict["content_index"] as? Int,
              let delta = dict["delta"] as? String else {
            return nil
        }
        
        return TranscriptionDelta(
            eventId: eventId,
            itemId: itemId,
            contentIndex: contentIndex,
            delta: delta
        )
    }
}

public struct TranscriptionCompleted {
    public let eventId: String
    public let itemId: String
    public let contentIndex: Int
    public let transcript: String
    
    public static func from(_ dict: [String: Any]) -> TranscriptionCompleted? {
        guard let eventId = dict["event_id"] as? String,
              let itemId = dict["item_id"] as? String,
              let contentIndex = dict["content_index"] as? Int,
              let transcript = dict["transcript"] as? String else {
            return nil
        }
        
        return TranscriptionCompleted(
            eventId: eventId,
            itemId: itemId,
            contentIndex: contentIndex,
            transcript: transcript
        )
    }
}

public struct RealtimeError {
    public let eventId: String?
    public let type: String
    public let code: String?
    public let message: String
    public let param: String?
    
    public static func from(_ dict: [String: Any]) -> RealtimeError? {
        guard let errorDict = dict["error"] as? [String: Any],
              let type = errorDict["type"] as? String,
              let message = errorDict["message"] as? String else {
            return nil
        }
        
        return RealtimeError(
            eventId: dict["event_id"] as? String,
            type: type,
            code: errorDict["code"] as? String,
            message: message,
            param: errorDict["param"] as? String
        )
    }
}