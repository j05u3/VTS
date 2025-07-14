import XCTest
@testable import VTS

final class ProviderTests: XCTestCase {
    
    func testOpenAIProviderValidation() {
        // Given
        let provider = OpenAIProvider()
        
        // Test valid config
        let validConfig = ProviderConfig(apiKey: "test-key", model: "whisper-1")
        XCTAssertNoThrow(try provider.validateConfig(validConfig))
        
        // Test invalid API key
        let invalidKeyConfig = ProviderConfig(apiKey: "", model: "whisper-1")
        XCTAssertThrowsError(try provider.validateConfig(invalidKeyConfig)) { error in
            XCTAssertEqual(error as? STTError, STTError.invalidAPIKey)
        }
        
        // Test invalid model
        let invalidModelConfig = ProviderConfig(apiKey: "test-key", model: "invalid-model")
        XCTAssertThrowsError(try provider.validateConfig(invalidModelConfig)) { error in
            XCTAssertEqual(error as? STTError, STTError.invalidModel)
        }
    }
    
    func testGroqProviderValidation() {
        // Given
        let provider = GroqProvider()
        
        // Test valid config
        let validConfig = ProviderConfig(apiKey: "test-key", model: "whisper-large-v3")
        XCTAssertNoThrow(try provider.validateConfig(validConfig))
        
        // Test invalid API key
        let invalidKeyConfig = ProviderConfig(apiKey: "", model: "whisper-large-v3")
        XCTAssertThrowsError(try provider.validateConfig(invalidKeyConfig)) { error in
            XCTAssertEqual(error as? STTError, STTError.invalidAPIKey)
        }
        
        // Test invalid model
        let invalidModelConfig = ProviderConfig(apiKey: "test-key", model: "invalid-model")
        XCTAssertThrowsError(try provider.validateConfig(invalidModelConfig)) { error in
            XCTAssertEqual(error as? STTError, STTError.invalidModel)
        }
    }
    
    func testTranscriptionChunk() {
        // Given
        let text = "Hello world"
        let isFinal = true
        
        // When
        let chunk = TranscriptionChunk(text: text, isFinal: isFinal)
        
        // Then
        XCTAssertEqual(chunk.text, text)
        XCTAssertEqual(chunk.isFinal, isFinal)
        XCTAssertNotNil(chunk.timestamp)
    }
    
    func testProviderConfig() {
        // Given
        let apiKey = "test-key"
        let model = "whisper-1"
        let systemPrompt = "Test prompt"
        let language = "en"
        let temperature: Float = 0.5
        
        // When
        let config = ProviderConfig(
            apiKey: apiKey,
            model: model,
            systemPrompt: systemPrompt,
            language: language,
            temperature: temperature
        )
        
        // Then
        XCTAssertEqual(config.apiKey, apiKey)
        XCTAssertEqual(config.model, model)
        XCTAssertEqual(config.systemPrompt, systemPrompt)
        XCTAssertEqual(config.language, language)
        XCTAssertEqual(config.temperature, temperature)
    }
    
    func testSTTProviderTypeDefaultModels() {
        // Test OpenAI default models
        XCTAssertEqual(STTProviderType.openai.defaultModels, ["whisper-1"])
        
        // Test Groq default models
        XCTAssertEqual(STTProviderType.groq.defaultModels, ["whisper-large-v3", "whisper-large-v3-turbo"])
    }
}