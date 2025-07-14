import Foundation
@testable import VTS

class MockSTTProvider: STTProvider {
    let providerType: STTProviderType = .openai
    
    var shouldValidateSucceed = true
    var validationError: STTError?
    var transcriptionResult: [TranscriptionChunk] = []
    var shouldThrowError = false
    var throwError: STTError?
    
    func transcribe(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig
    ) async throws -> AsyncStream<TranscriptionChunk> {
        if shouldThrowError, let error = throwError {
            throw error
        }
        
        return AsyncStream<TranscriptionChunk> { continuation in
            Task {
                // Consume the stream (simulate processing)
                for try await _ in stream {
                    // Process audio data
                }
                
                // Return mock results
                for chunk in transcriptionResult {
                    continuation.yield(chunk)
                    try? await Task.sleep(for: .milliseconds(10))
                }
                
                continuation.finish()
            }
        }
    }
    
    func validateConfig(_ config: ProviderConfig) throws {
        if !shouldValidateSucceed {
            throw validationError ?? STTError.invalidAPIKey
        }
    }
}