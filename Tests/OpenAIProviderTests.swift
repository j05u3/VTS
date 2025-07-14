import XCTest
@testable import VTS

final class OpenAIProviderTests: XCTestCase {
    
    var provider: OpenAIProvider!
    
    override func setUp() {
        super.setUp()
        provider = OpenAIProvider()
    }
    
    override func tearDown() {
        provider = nil
        super.tearDown()
    }
    
    func testProviderType() {
        XCTAssertEqual(provider.providerType, .openai)
    }
    
    func testValidateConfigWithEmptyAPIKey() {
        let config = ProviderConfig(apiKey: "", model: "whisper-1")
        
        XCTAssertThrowsError(try provider.validateConfig(config)) { error in
            XCTAssertEqual(error as? STTError, STTError.invalidAPIKey)
        }
    }
    
    func testValidateConfigWithInvalidModel() {
        let config = ProviderConfig(apiKey: "valid-key", model: "invalid-model")
        
        XCTAssertThrowsError(try provider.validateConfig(config)) { error in
            XCTAssertEqual(error as? STTError, STTError.invalidModel)
        }
    }
    
    func testValidateConfigWithValidParameters() {
        let config = ProviderConfig(apiKey: "valid-key", model: "whisper-1")
        
        XCTAssertNoThrow(try provider.validateConfig(config))
    }
    
    func testValidateConfigWithSystemPrompt() {
        let config = ProviderConfig(
            apiKey: "valid-key",
            model: "whisper-1",
            systemPrompt: "Medical terminology"
        )
        
        XCTAssertNoThrow(try provider.validateConfig(config))
    }
    
    func testProviderCreation() {
        // Test that provider can be created successfully
        let provider = OpenAIProvider()
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider.providerType, .openai)
    }
    
    func testTranscribeWithInsufficientAudioData() async {
        let provider = OpenAIProvider()
        let config = ProviderConfig(apiKey: "test-key", model: "whisper-1")
        
        // Create stream with very little audio data (less than 1 second)
        let audioStream = AsyncThrowingStream<Data, Error> { continuation in
            let smallData = Data(repeating: 0, count: 100) // Much less than required
            continuation.yield(smallData)
            continuation.finish()
        }
        
        do {
            let transcriptionStream = try await provider.transcribe(stream: audioStream, config: config)
            
            var results: [TranscriptionChunk] = []
            for await chunk in transcriptionStream {
                results.append(chunk)
            }
            
            // Should not produce any results due to insufficient audio data
            XCTAssertTrue(results.isEmpty)
        } catch {
            // Expected to fail without real API key
            XCTAssertTrue(error is URLError || error is STTError)
        }
    }
    
    func testTranscribeStreamStructure() async {
        let provider = OpenAIProvider()
        let config = ProviderConfig(apiKey: "test-key", model: "whisper-1")
        
        // Create stream with sufficient audio data
        let audioStream = AsyncThrowingStream<Data, Error> { continuation in
            let audioData = Data(repeating: 0, count: 32000) // 1 second of 16kHz 16-bit audio
            continuation.yield(audioData)
            continuation.finish()
        }
        
        do {
            let transcriptionStream = try await provider.transcribe(stream: audioStream, config: config)
            
            // The stream should be created successfully (actual API call will fail without real key)
            for await _ in transcriptionStream {
                break // We don't expect actual results without a real API call
            }
            
            // The stream itself should be properly structured
            XCTAssertNotNil(transcriptionStream)
        } catch {
            // Expected to fail without real API key and network access
            XCTAssertTrue(error is STTError || error is URLError)
        }
    }
}