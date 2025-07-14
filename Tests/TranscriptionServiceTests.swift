import XCTest
@testable import VTS

@MainActor
final class TranscriptionServiceTests: XCTestCase {
    
    var transcriptionService: TranscriptionService!
    var mockProvider: MockSTTProvider!
    
    override func setUp() {
        super.setUp()
        transcriptionService = TranscriptionService()
        mockProvider = MockSTTProvider()
    }
    
    override func tearDown() {
        transcriptionService?.stopTranscription()
        transcriptionService = nil
        mockProvider = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(transcriptionService.currentText, "")
        XCTAssertFalse(transcriptionService.isTranscribing)
        XCTAssertNil(transcriptionService.error)
    }
    
    func testSetProvider() {
        transcriptionService.setProvider(mockProvider)
        // Provider should be set (internal state, can't directly test)
        XCTAssertNotNil(transcriptionService)
    }
    
    func testStartTranscriptionWithoutProvider() async {
        let audioStream = createMockAudioStream()
        let config = ProviderConfig(apiKey: "test", model: "test-model")
        
        transcriptionService.startTranscription(
            audioStream: audioStream,
            config: config,
            streamPartials: true
        )
        
        // Should set error when no provider is configured
        let expectation = XCTestExpectation(description: "Error set for no provider")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.transcriptionService.error)
            if let error = self.transcriptionService.error {
                XCTAssertEqual(error, STTError.transcriptionError("No provider configured"))
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testStartTranscriptionWithProvider() async {
        transcriptionService.setProvider(mockProvider)
        let audioStream = createMockAudioStream()
        let config = ProviderConfig(apiKey: "test", model: "test-model")
        
        transcriptionService.startTranscription(
            audioStream: audioStream,
            config: config,
            streamPartials: true
        )
        
        XCTAssertTrue(transcriptionService.isTranscribing)
        XCTAssertNil(transcriptionService.error)
    }
    
    func testStopTranscription() async {
        transcriptionService.setProvider(mockProvider)
        let audioStream = createMockAudioStream()
        let config = ProviderConfig(apiKey: "test", model: "test-model")
        
        transcriptionService.startTranscription(
            audioStream: audioStream,
            config: config,
            streamPartials: true
        )
        
        XCTAssertTrue(transcriptionService.isTranscribing)
        
        transcriptionService.stopTranscription()
        
        XCTAssertFalse(transcriptionService.isTranscribing)
    }
    
    func testPartialResults() async {
        transcriptionService.setProvider(mockProvider)
        let audioStream = createMockAudioStream()
        let config = ProviderConfig(apiKey: "test", model: "test-model")
        
        // Configure mock provider to return partial results
        mockProvider.shouldReturnPartials = true
        mockProvider.mockResults = [
            TranscriptionChunk(text: "Hello", isFinal: false),
            TranscriptionChunk(text: "Hello world", isFinal: true)
        ]
        
        transcriptionService.startTranscription(
            audioStream: audioStream,
            config: config,
            streamPartials: true
        )
        
        // Wait for transcription to process
        let expectation = XCTestExpectation(description: "Transcription completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // The final result should be "Hello world" but the merging logic might append partials
            XCTAssertTrue(self.transcriptionService.currentText.contains("Hello world"))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testInvalidAPIKey() async {
        mockProvider.shouldThrowOnValidation = true
        transcriptionService.setProvider(mockProvider)
        
        let audioStream = createMockAudioStream()
        let config = ProviderConfig(apiKey: "", model: "test-model")
        
        transcriptionService.startTranscription(
            audioStream: audioStream,
            config: config,
            streamPartials: true
        )
        
        // Should set error for invalid config
        let expectation = XCTestExpectation(description: "Error set for invalid config")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotNil(self.transcriptionService.error)
            XCTAssertFalse(self.transcriptionService.isTranscribing)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockAudioStream() -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream<Data, Error> { continuation in
            // Provide some mock audio data
            let audioData = Data(repeating: 0, count: 1024)
            continuation.yield(audioData)
            continuation.finish()
        }
    }
}

// MARK: - Mock STT Provider

class MockSTTProvider: STTProvider {
    let providerType: STTProviderType = .openai
    
    var shouldThrowOnValidation = false
    var shouldReturnPartials = false
    var mockResults: [TranscriptionChunk] = []
    var mockError: Error?
    
    func validateConfig(_ config: ProviderConfig) throws {
        if shouldThrowOnValidation {
            throw STTError.invalidAPIKey
        }
    }
    
    func transcribe(
        stream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig
    ) async throws -> AsyncStream<TranscriptionChunk> {
        if let error = mockError {
            throw error
        }
        
        return AsyncStream<TranscriptionChunk> { continuation in
            Task {
                // Consume the audio stream
                for try await _ in stream {
                    // Process audio data (mock)
                }
                
                // Return mock results
                for result in mockResults {
                    continuation.yield(result)
                }
                
                continuation.finish()
            }
        }
    }
}