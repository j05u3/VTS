import SwiftUI
import UserNotifications

struct OnboardingNotificationsStep: View {
    @ObservedObject var appState: AppState
    @State private var permissionGranted = false
    @State private var animateBell = false
    
    private var notificationManager: NotificationManager {
        NotificationManager.shared
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Header section
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(notificationColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 50))
                        .foregroundColor(notificationColor)
                        .rotationEffect(.degrees(animateBell ? -20 : 20))
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateBell)
                }
                
                Text("Notifications")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Stay informed about transcription status and any issues that may occur")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            // Main content
            VStack(spacing: 24) {
                // Permission status
                NotificationPermissionCard(
                    hasPermission: permissionGranted,
                    title: "Notification Permission",
                    grantedMessage: "✅ Notifications enabled! You'll be informed about transcription status and errors.",
                    deniedMessage: "⚠️ Notifications disabled. You might miss important status updates.",
                    color: notificationColor
                )
                
                // Benefits explanation
                VStack(alignment: .leading, spacing: 16) {
                    Text("What notifications help with:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        NotificationBenefitRow(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .orange,
                            title: "Error alerts",
                            description: "Get notified if transcription fails due to API issues or connectivity problems"
                        )
                        NotificationBenefitRow(
                            icon: "key.fill",
                            iconColor: .red,
                            title: "API key issues",
                            description: "Alerts when your API key is invalid, expired, or rate limited"
                        )
                        NotificationBenefitRow(
                            icon: "arrow.clockwise",
                            iconColor: .blue,
                            title: "Retry suggestions",
                            description: "Actionable notifications with retry options when issues occur"
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
                    if !permissionGranted {
                        Button(action: requestNotificationPermission) {
                            Label("Enable Notifications", systemImage: "bell.fill")
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
                    } else {
                        Button(action: showTestNotification) {
                            Label("Send Test Notification", systemImage: "bell.badge")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.green)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Privacy & Control")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Notifications are only sent for important events\n• You can disable them anytime in System Settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
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
            .frame(maxWidth: 600)
            
            Spacer()
        }
        .padding(.horizontal, 60)
        .onAppear {
            updatePermissionStatus()
            animateBell = true
        }
    }
    
    private var notificationColor: Color {
        permissionGranted ? .green : .blue
    }
    
    private func updatePermissionStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                permissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            await notificationManager.requestPermission()
            updatePermissionStatus()
        }
    }
    
    private func showTestNotification() {
        Task {
            await notificationManager.showTestNotification()
        }
    }
}

struct NotificationBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
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

struct NotificationPermissionCard: View {
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
        hasPermission ? "checkmark.circle.fill" : "bell.slash.fill"
    }
    
    private var statusColor: Color {
        hasPermission ? .green : color
    }
    
    private var statusMessage: String {
        hasPermission ? grantedMessage : deniedMessage
    }
}

// Extension to NotificationManager for test notification
extension NotificationManager {
    func showTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "VTS Test Notification"
        content.body = "🎉 Notifications are working perfectly! You'll be notified about transcription events."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "vts.test.notification",
            content: content,
            trigger: nil // Immediate delivery
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Test notification sent successfully")
        } catch {
            print("🔔 Failed to send test notification: \(error)")
        }
    }
}

#Preview {
    OnboardingNotificationsStep(appState: AppState())
        .frame(width: 800, height: 600)
}