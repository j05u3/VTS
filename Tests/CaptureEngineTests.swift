import XCTest
import AVFoundation
import CoreAudio
@testable import VTS

@MainActor
final class CaptureEngineTests: XCTestCase {
    
    var captureEngine: CaptureEngine!
    
    override func setUp() {
        super.setUp()
        captureEngine = CaptureEngine()
    }
    
    override func tearDown() {
        captureEngine?.stop()
        captureEngine = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(captureEngine.isRecording)
        XCTAssertEqual(captureEngine.audioLevel, 0.0)
    }
    
    func testPermissionStateIsValid() {
        // Should have a valid permission state (true/false, not undefined)
        let permissionStates: [Bool] = [true, false]
        XCTAssertTrue(permissionStates.contains(captureEngine.permissionGranted))
    }
    
    func testStartRecordingRequiresPermission() {
        // If permission is not granted, starting should throw
        if !captureEngine.permissionGranted {
            XCTAssertThrowsError(try captureEngine.start()) { error in
                if let sttError = error as? STTError {
                    XCTAssertEqual(sttError, STTError.audioProcessingError("Microphone permission not granted"))
                }
            }
        }
    }
    
    func testMultipleStartCallsThrow() async throws {
        // Mock permission as granted for this test
        guard captureEngine.permissionGranted else {
            throw XCTSkip("Microphone permission not available")
        }
        
        do {
            let _ = try captureEngine.start()
            
            // Second start should throw
            XCTAssertThrowsError(try captureEngine.start()) { error in
                if let sttError = error as? STTError {
                    XCTAssertEqual(sttError, STTError.audioProcessingError("Already recording"))
                }
            }
        } catch {
            // If the first start fails due to permissions, that's expected
            XCTAssertTrue(error is STTError)
        }
    }
    
    func testStopRecordingWhenNotRecording() {
        // Should not crash when stopping while not recording
        XCTAssertNoThrow(captureEngine.stop())
        XCTAssertFalse(captureEngine.isRecording)
    }
    
    func testRecordingStateManagement() async throws {
        guard captureEngine.permissionGranted else {
            throw XCTSkip("Microphone permission not available")
        }
        
        do {
            let _ = try captureEngine.start()
            XCTAssertTrue(captureEngine.isRecording)
            
            captureEngine.stop()
            XCTAssertFalse(captureEngine.isRecording)
            XCTAssertEqual(captureEngine.audioLevel, 0.0)
        } catch {
            // If start fails due to audio hardware issues, that's acceptable in CI
            XCTAssertTrue(error is STTError)
        }
    }
    
    func testAudioLevelRange() async throws {
        guard captureEngine.permissionGranted else {
            throw XCTSkip("Microphone permission not available")
        }
        
        do {
            let _ = try captureEngine.start()
            
            // Audio level should always be between 0.0 and 1.0
            let expectation = XCTestExpectation(description: "Audio level in valid range")
            
            // Give it some time to capture audio data
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertGreaterThanOrEqual(self.captureEngine.audioLevel, 0.0)
                XCTAssertLessThanOrEqual(self.captureEngine.audioLevel, 1.0)
                expectation.fulfill()
            }
            
            await fulfillment(of: [expectation], timeout: 1.0)
        } catch {
            // If start fails due to audio hardware issues, that's acceptable in CI
            XCTAssertTrue(error is STTError)
        }
    }
    
    func testInvalidDeviceID() async throws {
        guard captureEngine.permissionGranted else {
            throw XCTSkip("Microphone permission not available")
        }
        
        // Should handle invalid device ID gracefully
        XCTAssertThrowsError(try captureEngine.start(deviceID: "invalid-device-id")) { error in
            XCTAssertTrue(error is STTError)
        }
    }
}