import Foundation

public class BaseStreamingSTTProvider: StreamingSTTProvider {
    public var providerType: STTProviderType {
        fatalError("Must be implemented by subclass")
    }

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
}
