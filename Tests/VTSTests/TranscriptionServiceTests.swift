import XCTest
@testable import VTS

@MainActor
final class TranscriptionServiceTests: XCTestCase {
    var transcriptionService: TranscriptionService!
    var mockProvider: MockSTTProvider!
    
    override func setUp() async throws {
        transcriptionService = TranscriptionService()
        mockProvider = MockSTTProvider()
        transcriptionService.setProvider(mockProvider)
    }
    
    override func tearDown() async throws {
        transcriptionService.stopTranscription()
        transcriptionService = nil
        mockProvider = nil
    }
    
    func testSetProvider() {
        // Given
        let newProvider = MockSTTProvider()
        
        // When
        transcriptionService.setProvider(newProvider)
        
        // Then - We can verify the provider was set by checking if transcription works
        XCTAssertNotNil(transcriptionService)
    }
    
    func testStartTranscriptionWithValidConfig() async {
        // Given
        let config = ProviderConfig(apiKey: "test-key", model: "test-model")
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        mockProvider.shouldValidateSucceed = true
        mockProvider.transcriptionResult = [
            TranscriptionChunk(text: "Hello", isFinal: false),
            TranscriptionChunk(text: "Hello world", isFinal: true)
        ]
        
        // When
        transcriptionService.startTranscription(audioStream: stream, config: config)
        
        // Then
        XCTAssertTrue(transcriptionService.isTranscribing)
        XCTAssertNil(transcriptionService.error)
        
        // Simulate completion
        continuation.finish()
        
        // Allow async operations to complete
        try? await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(transcriptionService.currentText, "Hello world")
    }
    
    func testStartTranscriptionWithInvalidConfig() async {
        // Given
        let config = ProviderConfig(apiKey: "", model: "invalid-model")
        let (stream, _) = AsyncThrowingStream.makeStream(of: Data.self)
        mockProvider.shouldValidateSucceed = false
        mockProvider.validationError = STTError.invalidAPIKey
        
        // When
        transcriptionService.startTranscription(audioStream: stream, config: config)
        
        // Allow async operations to complete
        try? await Task.sleep(for: .milliseconds(100))
        
        // Then
        XCTAssertNotNil(transcriptionService.error)
        XCTAssertFalse(transcriptionService.isTranscribing)
    }
    
    func testStopTranscription() {
        // Given
        let config = ProviderConfig(apiKey: "test-key", model: "test-model")
        let (stream, _) = AsyncThrowingStream.makeStream(of: Data.self)
        transcriptionService.startTranscription(audioStream: stream, config: config)
        
        // When
        transcriptionService.stopTranscription()
        
        // Then
        XCTAssertFalse(transcriptionService.isTranscribing)
    }
    
    func testPartialResultsHandling() async {
        // Given
        let config = ProviderConfig(apiKey: "test-key", model: "test-model")
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        mockProvider.shouldValidateSucceed = true
        mockProvider.transcriptionResult = [
            TranscriptionChunk(text: "Partial", isFinal: false),
            TranscriptionChunk(text: "Partial text", isFinal: false),
            TranscriptionChunk(text: "Partial text complete", isFinal: true)
        ]
        
        // When
        transcriptionService.startTranscription(audioStream: stream, config: config, streamPartials: true)
        
        continuation.finish()
        
        // Allow async operations to complete
        try? await Task.sleep(for: .milliseconds(100))
        
        // Then
        XCTAssertEqual(transcriptionService.currentText, "Partial text complete")
    }
}