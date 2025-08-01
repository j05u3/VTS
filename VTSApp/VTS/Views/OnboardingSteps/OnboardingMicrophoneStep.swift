import SwiftUI
import AVFoundation

struct OnboardingMicrophoneStep: View {
    @ObservedObject var appState: AppState
    @State private var showingPermissionAlert = false
    @State private var animateIcon = false
    
    private var captureEngine: CaptureEngine {
        appState.captureEngineService
    }
    
    var body: some View {
        VStack(spacing: 40) {
            // Header section
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(microphoneColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 50))
                        .foregroundColor(microphoneColor)
                        .scaleEffect(animateIcon ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animateIcon)
                }
                
                Text("Microphone Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("VTS needs access to your microphone to record audio for speech-to-text transcription")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            // Status and explanation
            VStack(spacing: 20) {
                MicrophonePermissionCard(
                    status: captureEngine.permissionStatus,
                    title: "Microphone Permission",
                    grantedMessage: "✅ Microphone access granted! VTS can now record audio for transcription.",
                    deniedMessage: "❌ Microphone access denied. VTS cannot function without microphone permission.",
                    notDeterminedMessage: "⏳ Microphone permission not yet requested."
                )
                
                if captureEngine.permissionStatus != .authorized {
                    VStack(spacing: 16) {
                        Text("Why VTS needs microphone access:")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            PermissionReasonRow(
                                icon: "waveform",
                                text: "Record your voice for AI transcription"
                            )
                            PermissionReasonRow(
                                icon: "shield.fill",
                                text: "Audio is processed in real-time, never stored"
                            )
                            PermissionReasonRow(
                                icon: "network",
                                text: "Secure transmission to AI providers via HTTPS"
                            )
                        }
                        
                        if captureEngine.permissionStatus == .notDetermined {
                            Button(action: requestMicrophonePermission) {
                                Label("Grant Microphone Access", systemImage: "mic.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.blue)
                                    )
                            }
                            .buttonStyle(.plain)
                        } else if captureEngine.permissionStatus == .denied {
                            Button(action: openSystemPreferences) {
                                Label("Open System Settings", systemImage: "gear")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.orange)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .frame(maxWidth: 600)
                }
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .onAppear {
            captureEngine.updatePermissionStatus()
            animateIcon = true
            
            // Set up a timer to periodically check permission status
            // in case user grants it through System Settings
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                let oldStatus = captureEngine.permissionStatus
                captureEngine.updatePermissionStatus()
                
                // If status changed, update the UI
                if oldStatus != captureEngine.permissionStatus {
                    DispatchQueue.main.async {
                        appState.objectWillChange.send()
                    }
                }
                
                // Stop timer if permission is granted
                if captureEngine.permissionGranted {
                    timer.invalidate()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            captureEngine.updatePermissionStatus()
            // Force a UI update to refresh the navigation state
            DispatchQueue.main.async {
                appState.objectWillChange.send()
            }
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") { openSystemPreferences() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To enable microphone access, please go to System Settings > Privacy & Security > Microphone and enable VTS.")
        }
    }
    
    private var microphoneColor: Color {
        switch captureEngine.permissionStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .blue
        @unknown default:
            return .gray
        }
    }
    
    private func requestMicrophonePermission() {
        captureEngine.requestMicrophonePermission { granted in
            if !granted {
                showingPermissionAlert = true
            }
            // Force a UI update to refresh the navigation state
            DispatchQueue.main.async {
                // This will trigger a re-evaluation of the navigation state
                appState.objectWillChange.send()
            }
        }
    }
    
    private func openSystemPreferences() {
        captureEngine.openMicrophoneSettings()
    }
}

struct MicrophonePermissionCard: View {
    let status: AVAuthorizationStatus
    let title: String
    let grantedMessage: String
    let deniedMessage: String
    let notDeterminedMessage: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: statusIcon)
                .font(.title)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
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
        switch status {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "exclamationmark.triangle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .blue
        @unknown default:
            return .gray
        }
    }
    
    private var statusMessage: String {
        switch status {
        case .authorized:
            return grantedMessage
        case .denied, .restricted:
            return deniedMessage
        case .notDetermined:
            return notDeterminedMessage
        @unknown default:
            return "Unknown permission status"
        }
    }
}

struct PermissionReasonRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingMicrophoneStep(appState: AppState())
        .frame(width: 800, height: 600)
}