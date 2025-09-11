import SwiftUI

struct OnboardingAccessibilityStep: View {
    @ObservedObject var appState: AppState
    @State private var hasPermission = false
    @State private var animateIcon = false
    
    private var textInjector: TextInjector {
        appState.restTranscriptionServiceInstance.injector
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Header section
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(accessibilityColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "text.insert")
                        .font(.system(size: 50))
                        .foregroundColor(accessibilityColor)
                        .rotationEffect(.degrees(animateIcon ? 360 : 0))
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false), value: animateIcon)
                }
                
                HStack {
                    Text("Text Insertion Access")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Text("Enable automatic text insertion to seamlessly add transcribed text into any application")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            // Main content
            VStack(spacing: 24) {
                // Permission status
                AccessibilityPermissionCard(
                    hasPermission: hasPermission,
                    title: "Accessibility Permission",
                    grantedMessage: "✅ Accessibility access granted! Text will be automatically inserted into applications.",
                    deniedMessage: "⚠️ Accessibility access not enabled. You can still copy transcriptions manually.",
                    color: accessibilityColor
                )
                
                // Benefits explanation
                VStack(alignment: .leading, spacing: 16) {
                    Text("How automatic text insertion works:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        BenefitRow(
                            icon: "1.circle.fill",
                            title: "Record your voice",
                            description: "Press your global hotkey and speak"
                        )
                        BenefitRow(
                            icon: "2.circle.fill",
                            title: "AI transcribes instantly",
                            description: "Your speech is converted to text in real-time"
                        )
                        BenefitRow(
                            icon: "3.circle.fill",
                            title: "Text appears automatically",
                            description: "Transcribed text is inserted directly where you're typing"
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                
                // Action buttons
                VStack(spacing: 12) {
                    if !hasPermission {
                        Button(action: requestAccessibilityPermission) {
                            Label("Grant Accessibility Access", systemImage: "text.insert")
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
                        
                        Text("This will open System Settings where you can enable VTS in Privacy & Security > Accessibility")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Without accessibility access:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• You can still use VTS for voice transcription\n• Transcribed text can be copied to clipboard\n• You'll need to paste manually with ⌘V")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .frame(maxWidth: 600)
            
            Spacer()
        }
        .padding(.horizontal, 60)
        .onAppear {
            updatePermissionStatus()
            animateIcon = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            updatePermissionStatus()
        }
    }
    
    private var accessibilityColor: Color {
        hasPermission ? .green : .blue
    }
    
    private func updatePermissionStatus() {
        textInjector.updatePermissionStatus()
        hasPermission = textInjector.hasAccessibilityPermission
    }
    
    private func requestAccessibilityPermission() {
        textInjector.requestAccessibilityPermission()
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// Reusable permission status card for accessibility
struct AccessibilityPermissionCard: View {
    let hasPermission: Bool
    let title: String
    let grantedMessage: String
    let deniedMessage: String
    let color: Color
    
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
        hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
    
    private var statusColor: Color {
        hasPermission ? .green : color
    }
    
    private var statusMessage: String {
        hasPermission ? grantedMessage : deniedMessage
    }
}

#Preview {
    OnboardingAccessibilityStep(appState: AppState())
        .frame(width: 800, height: 600)
}