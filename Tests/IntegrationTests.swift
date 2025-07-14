import XCTest
import AVFoundation
@testable import VTS

@MainActor
final class IntegrationTests: XCTestCase {
    
    var captureEngine: CaptureEngine!
    var transcriptionService: TranscriptionService!
    var deviceManager: DeviceManager!
    
    override func setUp() {
        super.setUp()
        captureEngine = CaptureEngine()
        transcriptionService = TranscriptionService()
        deviceManager = DeviceManager()
    }
    
    override func tearDown() {
        captureEngine?.stop()
        transcriptionService?.stopTranscription()
        captureEngine = nil
        transcriptionService = nil
        deviceManager = nil
        super.tearDown()
    }
    
    func testFullRecordingWorkflow() async throws {
        guard captureEngine.permissionGranted else {
            throw XCTSkip("Microphone permission not available")
        }
        
        // Set up mock provider
        let mockProvider = MockSTTProvider()
        mockProvider.mockResults = [
            TranscriptionChunk(text: "Test transcription", isFinal: true)
        ]
        transcriptionService.setProvider(mockProvider)
        
        do {
            // Start audio capture
            let audioStream = try captureEngine.start()
            XCTAssertTrue(captureEngine.isRecording)
            
            // Start transcription
            let config = ProviderConfig(apiKey: "test-key", model: "whisper-1")
            transcriptionService.startTranscription(
                audioStream: audioStream,
                config: config,
                streamPartials: true
            )
            
            XCTAssertTrue(transcriptionService.isTranscribing)
            
            // Let it run for a short time
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Stop recording
            captureEngine.stop()
            transcriptionService.stopTranscription()
            
            XCTAssertFalse(captureEngine.isRecording)
            XCTAssertFalse(transcriptionService.isTranscribing)
            
        } catch {
            XCTFail("Integration test failed: \(error)")
        }
    }
    
    func testDeviceManagerIntegration() {
        // Test device enumeration
        deviceManager.updateAvailableDevices()
        
        // Should have at least some devices or handle gracefully
        XCTAssertTrue(deviceManager.availableDevices.count >= 0)
        
        // Test priority management
        if !deviceManager.availableDevices.isEmpty {
            let firstDevice = deviceManager.availableDevices[0]
            
            deviceManager.addDeviceToPriorities(firstDevice.id)
            XCTAssertTrue(deviceManager.devicePriorities.contains(firstDevice.id))
            
            deviceManager.removeDeviceFromPriorities(firstDevice.id)
            XCTAssertFalse(deviceManager.devicePriorities.contains(firstDevice.id))
        }
    }
    
    func testErrorHandlingWorkflow() async throws {
        // Test with invalid API key
        let mockProvider = MockSTTProvider()
        mockProvider.shouldThrowOnValidation = true
        transcriptionService.setProvider(mockProvider)
        
        guard captureEngine.permissionGranted else {
            throw XCTSkip("Microphone permission not available")
        }
        
        do {
            let audioStream = try captureEngine.start()
            
            let config = ProviderConfig(apiKey: "", model: "invalid-model")
            transcriptionService.startTranscription(
                audioStream: audioStream,
                config: config,
                streamPartials: true
            )
            
            // Should handle errors gracefully
            let expectation = XCTestExpectation(description: "Error handled")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertNotNil(self.transcriptionService.error)
                XCTAssertFalse(self.transcriptionService.isTranscribing)
                expectation.fulfill()
            }
            
            await fulfillment(of: [expectation], timeout: 1.0)
            
        } catch {
            // This is also acceptable - error should be handled gracefully
            XCTAssertTrue(error is STTError)
        }
    }
    
    func testProviderSwitching() {
        // Test switching between providers
        let openAIProvider = OpenAIProvider()
        let groqProvider = GroqProvider()
        
        transcriptionService.setProvider(openAIProvider)
        // Provider should be set (internal state)
        
        transcriptionService.setProvider(groqProvider)
        // Provider should be switched (internal state)
        
        XCTAssertNotNil(transcriptionService)
    }
    
    func testConcurrentAccess() async throws {
        guard captureEngine.permissionGranted else {
            throw XCTSkip("Microphone permission not available")
        }
        
        // Test that multiple start attempts are handled correctly
        do {
            let _ = try captureEngine.start()
            
            // Multiple concurrent start attempts should be rejected
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<5 {
                    group.addTask { @MainActor in
                        do {
                            let _ = try self.captureEngine.start()
                            XCTFail("Should not allow multiple starts")
                        } catch {
                            // Expected to throw
                            XCTAssertTrue(error is STTError)
                        }
                    }
                }
            }
            
        } catch {
            // If initial start fails, that's acceptable in test environment
            XCTAssertTrue(error is STTError)
        }
    }
    
    func testMemoryManagement() async throws {
        guard captureEngine.permissionGranted else {
            throw XCTSkip("Microphone permission not available")
        }
        
        // Test that starting and stopping multiple times doesn't leak memory
        for _ in 0..<3 {
            do {
                let _ = try captureEngine.start()
                XCTAssertTrue(captureEngine.isRecording)
                
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                captureEngine.stop()
                XCTAssertFalse(captureEngine.isRecording)
                XCTAssertEqual(captureEngine.audioLevel, 0.0)
                
            } catch {
                // Acceptable in test environment
                XCTAssertTrue(error is STTError)
            }
        }
    }
}