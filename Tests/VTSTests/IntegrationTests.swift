import XCTest
@testable import VTS

@MainActor
final class IntegrationTests: XCTestCase {
    var captureEngine: CaptureEngine!
    var transcriptionService: TranscriptionService!
    var mockProvider: MockSTTProvider!
    
    override func setUp() async throws {
        captureEngine = CaptureEngine()
        transcriptionService = TranscriptionService()
        mockProvider = MockSTTProvider()
        transcriptionService.setProvider(mockProvider)
    }
    
    override func tearDown() async throws {
        captureEngine.stop()
        transcriptionService.stopTranscription()
        captureEngine = nil
        transcriptionService = nil
        mockProvider = nil
    }
    
    func testFullTranscriptionFlow() async throws {
        // Given
        let config = ProviderConfig(
            apiKey: "test-key",
            model: "whisper-1",
            systemPrompt: "Transcribe technical content"
        )
        
        mockProvider.shouldValidateSucceed = true
        mockProvider.transcriptionResult = [
            TranscriptionChunk(text: "Hello", isFinal: false),
            TranscriptionChunk(text: "Hello world", isFinal: false),
            TranscriptionChunk(text: "Hello world, this is a test", isFinal: true)
        ]
        
        // Create mock audio stream
        let (audioStream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        
        // When
        transcriptionService.startTranscription(
            audioStream: audioStream,
            config: config,
            streamPartials: true
        )
        
        // Simulate audio data
        let mockAudioData = createMockAudioData()
        continuation.yield(mockAudioData)
        continuation.finish()
        
        // Allow processing to complete
        try await Task.sleep(for: .milliseconds(200))
        
        // Then
        XCTAssertEqual(transcriptionService.currentText, "Hello world, this is a test")
        XCTAssertFalse(transcriptionService.isTranscribing)
        XCTAssertNil(transcriptionService.error)
    }
    
    func testTranscriptionWithError() async throws {
        // Given
        let config = ProviderConfig(apiKey: "", model: "invalid-model")
        let (audioStream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        
        mockProvider.shouldValidateSucceed = false
        mockProvider.validationError = STTError.invalidAPIKey
        
        // When
        transcriptionService.startTranscription(audioStream: audioStream, config: config)
        
        continuation.finish()
        
        // Allow processing to complete
        try await Task.sleep(for: .milliseconds(100))
        
        // Then
        XCTAssertNotNil(transcriptionService.error)
        XCTAssertFalse(transcriptionService.isTranscribing)
    }
    
    func testProviderConfigValidation() async throws {
        // Given
        let openAIProvider = OpenAIProvider()
        let groqProvider = GroqProvider()
        
        // Test OpenAI validation
        let validOpenAIConfig = ProviderConfig(apiKey: "sk-test", model: "whisper-1")
        XCTAssertNoThrow(try openAIProvider.validateConfig(validOpenAIConfig))
        
        let invalidOpenAIConfig = ProviderConfig(apiKey: "", model: "whisper-1")
        XCTAssertThrowsError(try openAIProvider.validateConfig(invalidOpenAIConfig))
        
        // Test Groq validation
        let validGroqConfig = ProviderConfig(apiKey: "gsk_test", model: "whisper-large-v3")
        XCTAssertNoThrow(try groqProvider.validateConfig(validGroqConfig))
        
        let invalidGroqConfig = ProviderConfig(apiKey: "", model: "whisper-large-v3")
        XCTAssertThrowsError(try groqProvider.validateConfig(invalidGroqConfig))
    }
    
    func testConcurrentTranscriptionRequests() async throws {
        // Given
        let config = ProviderConfig(apiKey: "test-key", model: "whisper-1")
        mockProvider.shouldValidateSucceed = true
        mockProvider.transcriptionResult = [
            TranscriptionChunk(text: "Concurrent test", isFinal: true)
        ]
        
        // When - start multiple transcription requests
        let (stream1, continuation1) = AsyncThrowingStream.makeStream(of: Data.self)
        let (stream2, continuation2) = AsyncThrowingStream.makeStream(of: Data.self)
        
        transcriptionService.startTranscription(audioStream: stream1, config: config)
        transcriptionService.startTranscription(audioStream: stream2, config: config)
        
        continuation1.finish()
        continuation2.finish()
        
        // Allow processing to complete
        try await Task.sleep(for: .milliseconds(100))
        
        // Then - should handle gracefully
        XCTAssertFalse(transcriptionService.isTranscribing)
    }
    
    private func createMockAudioData() -> Data {
        // Create 1 second of 16kHz mono PCM data (silence)
        let sampleRate = 16000
        let samples = Array(repeating: Int16(0), count: sampleRate)
        return Data(bytes: samples, count: samples.count * MemoryLayout<Int16>.size)
    }
}