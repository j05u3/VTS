import Foundation

// New protocol for streaming providers
public protocol StreamingSTTProvider {
    var providerType: STTProviderType { get }
    
    func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession
    func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws
    func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String
    func validateConfig(_ config: ProviderConfig) throws
}
