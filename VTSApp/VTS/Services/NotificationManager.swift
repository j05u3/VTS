import Foundation
import UserNotifications
import SwiftUI

@MainActor
public class NotificationManager: NSObject, ObservableObject {
    public static let shared = NotificationManager()
    
    @Published public var permissionGranted = false
    
    // Notification identifiers
    private enum NotificationIdentifier {
        static let transcriptionError = "vts.transcription.error"
    }
    
    // Notification actions
    private enum NotificationAction {
        static let retry = "RETRY_ACTION"
        static let openSettings = "SETTINGS_ACTION"
        static let dismiss = "DISMISS_ACTION"
    }
    
    // Callback for retry action
    public var onRetryRequested: ((RetryContext) -> Void)?
    public var onSettingsRequested: (() -> Void)?
    
    // Store retry context for notifications
    private var currentRetryContext: RetryContext?
    
    private override init() {
        super.init()
        setupNotificationCategories()
        checkPermissionStatus()
    }
    
    // MARK: - Permission Management
    
    public func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.permissionGranted = granted
            }
            print("🔔 Notification permission granted: \(granted)")
        } catch {
            print("🔔 Failed to request notification permission: \(error)")
            await MainActor.run {
                self.permissionGranted = false
            }
        }
    }
    
    private func checkPermissionStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.permissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Categories
    
    private func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        // Retry action for network/timeout errors
        let retryAction = UNNotificationAction(
            identifier: NotificationAction.retry,
            title: "Retry",
            options: [.foreground]
        )
        
        // Settings action for configuration errors
        let settingsAction = UNNotificationAction(
            identifier: NotificationAction.openSettings,
            title: "Open Settings",
            options: [.foreground]
        )
        
        // Dismiss action
        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss,
            title: "Dismiss",
            options: []
        )
        
        // Category with retry option
        let retryCategory = UNNotificationCategory(
            identifier: "TRANSCRIPTION_ERROR_RETRY",
            actions: [retryAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Category with settings option
        let settingsCategory = UNNotificationCategory(
            identifier: "TRANSCRIPTION_ERROR_SETTINGS",
            actions: [settingsAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([retryCategory, settingsCategory])
        center.delegate = self
    }
    
    // MARK: - Show Error Notifications
    
    public func showTranscriptionError(
        _ error: STTError,
        retryContext: RetryContext? = nil
    ) {
        guard permissionGranted else {
            print("🔔 Cannot show notification - permission not granted")
            return
        }
        
        let translation = ErrorTranslator.translate(error)
        self.currentRetryContext = retryContext
        
        let content = UNMutableNotificationContent()
        content.title = "Transcription Failed"
        content.body = "\(translation.message)\n\(translation.hint)"
        content.sound = .default
        
        // Choose category based on whether we can retry
        if translation.canRetry && retryContext != nil {
            content.categoryIdentifier = "TRANSCRIPTION_ERROR_RETRY"
        } else if translation.needsSettings {
            content.categoryIdentifier = "TRANSCRIPTION_ERROR_SETTINGS"
        } else {
            // Just a dismissible notification
            content.categoryIdentifier = ""
        }
        
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.transcriptionError,
            content: content,
            trigger: nil // Show immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 Failed to show notification: \(error)")
            } else {
                print("🔔 Notification shown: \(translation.message)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        
        switch actionIdentifier {
        case NotificationAction.retry:
            Task { @MainActor in
                if let context = self.currentRetryContext {
                    print("🔔 User tapped retry from notification")
                    self.onRetryRequested?(context)
                }
            }
            
        case NotificationAction.openSettings:
            print("🔔 User tapped settings from notification")
            Task { @MainActor in
                self.onSettingsRequested?()
            }
            
        case NotificationAction.dismiss,
             UNNotificationDefaultActionIdentifier:
            print("🔔 User dismissed notification")
            
        default:
            break
        }
        
        // Clear retry context after handling
        Task { @MainActor in
            self.currentRetryContext = nil
        }
        completionHandler()
    }
    
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}
