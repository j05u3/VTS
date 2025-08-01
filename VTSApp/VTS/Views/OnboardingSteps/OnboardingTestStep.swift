import SwiftUI
import AVFoundation
import Combine

struct OnboardingTestStep: View {
    @ObservedObject var appState: AppState
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var testResult: TestResult?
    @State private var audioLevel: Float = 0.0
    @State private var animateWaveform = false
    @State private var testPhase: TestPhase = .ready
    
    private var captureEngine: CaptureEngine { appState.captureEngineService }
    private var transcriptionService: TranscriptionService { appState.transcriptionServiceInstance }
    private var apiKeyManager: APIKeyManager { appState.apiKeyManagerService }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Header section
            VStack(spacing: 20) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .scaleEffect(animateWaveform ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animateWaveform)
                
                Text("Test Your Setup")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Let's test your voice transcription to make sure everything is working perfectly")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            // Main test interface
            VStack(spacing: 24) {
                // Test status card
                TestStatusCard(
                    phase: testPhase,
                    isRecording: isRecording,
                    isProcessing: isProcessing,
                    result: testResult
                )
                
                // Recording interface
                if testPhase != .completed || testResult?.success != true {
                    VStack(spacing: 20) {
                        // Audio level visualization
                        if isRecording {
                            VStack(spacing: 12) {
                                Text("🔴 Recording... Speak clearly into your microphone")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                AudioLevelView(audioLevel: audioLevel, isRecording: isRecording)
                                    .frame(height: 40)
                            }
                        }
                        
                        // Test instructions and controls
                        VStack(spacing: 16) {
                            if testPhase == .ready {
                                VStack(spacing: 12) {
                                    Text("Ready to test!")
                                        .font(.headline)
                                    
                                    Text("Click the button below and say something")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            
                            // Control buttons
                            HStack(spacing: 16) {
                                if isRecording {
                                    Button("Stop Recording") {
                                        stopTest()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                } else if testPhase == .ready || testPhase == .failed {
                                    Button("Start Voice Test") {
                                        startTest()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                    .disabled(!canStartTest)
                                }
                                
                                if testPhase == .completed && testResult?.success == false {
                                    Button("Try Again") {
                                        resetTest()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                                }
                            }
                            
                            if !canStartTest {
                                Text("⚠️ Please complete the previous steps (API key setup and microphone permission) before testing")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .frame(maxWidth: 600)
                }
                
                // Test result display
                if let result = testResult {
                    TestResultCard(result: result)
                        .frame(maxWidth: 600)
                }
                
                // Tips section
                TestTipsCard()
                    .frame(maxWidth: 600)
            }
            
            Spacer()
        }
        .padding(.horizontal, 60)
        .onAppear {
            animateWaveform = true
            setupAudioLevelBinding()
        }
        .onReceive(transcriptionService.$isTranscribing) { isTranscribing in
            isProcessing = isTranscribing
            if !isTranscribing && testPhase == .processing {
                handleTestCompletion()
            }
        }
    }
    
    private var canStartTest: Bool {
        captureEngine.permissionGranted && 
        apiKeyManager.hasAPIKey(for: appState.selectedProvider)
    }
    
    private func setupAudioLevelBinding() {
        // Sync audio level from capture engine
        appState.captureEngineService.$audioLevel
            .assign(to: \.audioLevel, on: self)
            .store(in: &appState.cancellables)
    }
    
    private func startTest() {
        guard canStartTest else { return }
        
        testPhase = .recording
        testResult = nil
        
        do {
            let audioStream = try captureEngine.start()
            
            guard let apiKey = try apiKeyManager.getCurrentAPIKey() else {
                handleTestError("Failed to retrieve API key")
                return
            }
            
            let config = ProviderConfig(
                apiKey: apiKey,
                model: appState.selectedModel,
                systemPrompt: "This is a test recording. Please transcribe accurately."
            )
            
            transcriptionService.startTranscription(
                audioStream: audioStream,
                config: config,
                streamPartials: false // Don't stream partials for test
            )
            
            isRecording = true
        } catch {
            handleTestError("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    private func stopTest() {
        captureEngine.stop()
        isRecording = false
        testPhase = .processing
    }
    
    private func handleTestCompletion() {
        testPhase = .completed
        
        let transcribedText = transcriptionService.lastTranscription
        
        if transcribedText.isEmpty {
            testResult = TestResult(
                success: false,
                transcribedText: "",
                errorMessage: "No transcription was produced. Please check your microphone and try speaking louder."
            )
        } else {
            testResult = TestResult(
                success: true,
                transcribedText: transcribedText,
                errorMessage: nil
            )
        }
    }
    
    private func handleTestError(_ message: String) {
        testPhase = .failed
        isRecording = false
        isProcessing = false
        testResult = TestResult(
            success: false,
            transcribedText: "",
            errorMessage: message
        )
    }
    
    private func resetTest() {
        testPhase = .ready
        testResult = nil
        isRecording = false
        isProcessing = false
    }
}

enum TestPhase {
    case ready
    case recording
    case processing
    case completed
    case failed
}

struct TestResult {
    let success: Bool
    let transcribedText: String
    let errorMessage: String?
}

struct TestStatusCard: View {
    let phase: TestPhase
    let isRecording: Bool
    let isProcessing: Bool
    let result: TestResult?
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: statusIcon)
                .font(.title)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Test Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .controlSize(.regular)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var statusIcon: String {
        switch phase {
        case .ready:
            return "play.circle"
        case .recording:
            return "record.circle.fill"
        case .processing:
            return "gearshape.2.fill"
        case .completed:
            return result?.success == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch phase {
        case .ready:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return result?.success == true ? .green : .red
        case .failed:
            return .red
        }
    }
    
    private var statusMessage: String {
        switch phase {
        case .ready:
            return "Ready to start voice transcription test"
        case .recording:
            return "Recording your voice... speak clearly"
        case .processing:
            return "Processing audio and generating transcription..."
        case .completed:
            return result?.success == true ? "Test completed successfully!" : "Test failed - see details below"
        case .failed:
            return "Test failed to start - check requirements"
        }
    }
}

struct TestResultCard: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(result.success ? .green : .red)
                
                Text(result.success ? "Test Successful!" : "Test Failed")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            if result.success {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcribed Text:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\"\(result.transcribedText)\"")
                        .font(.body)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                    
                    Text("🎉 Your voice transcription is working perfectly! You're ready to use VTS.")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Error:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(result.errorMessage ?? "Unknown error occurred")
                        .font(.body)
                        .foregroundColor(.red)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct TestTipsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for Best Results")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                TipRow(icon: "speaker.wave.2.fill", tip: "Ensure your microphone volume is adequate")
                TipRow(icon: "wifi", tip: "Check your internet connection")
                TipRow(icon: "mic.fill", tip: "Minimize background noise when possible")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct TipRow: View {
    let icon: String
    let tip: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(tip)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingTestStep(appState: AppState())
        .frame(width: 800, height: 600)
}