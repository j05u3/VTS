import Foundation
import ServiceManagement
import Combine

@MainActor
public class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public var isEnabled = false
    
    private let userDefaults = UserDefaults.standard
    private let launchAtLoginKey = "launchAtLogin"
    
    private init() {
        // Load existing state without setting default to true
        // Launch at login will be enabled after onboarding completion
        loadLaunchAtLoginState()
    }
    
    private func loadLaunchAtLoginState() {
        // Load from UserDefaults and sync with actual system state
        let savedState = userDefaults.bool(forKey: launchAtLoginKey)
        isEnabled = savedState
        
        // Verify with system state and sync if needed
        syncWithSystemState()
    }
    
    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        
        isEnabled = enabled
        userDefaults.set(enabled, forKey: launchAtLoginKey)
        
        if enabled {
            registerLaunchAtLogin()
        } else {
            unregisterLaunchAtLogin()
        }
    }
    
    private func registerLaunchAtLogin() {
        do {
            // Use modern SMAppService for macOS 13+ (app requires macOS 14+)
            try SMAppService.mainApp.register()
            print("✅ Launch at login registered successfully")
        } catch {
            print("❌ Failed to register launch at login: \(error)")
            // Revert state on failure
            isEnabled = false
            userDefaults.set(false, forKey: launchAtLoginKey)
        }
    }
    
    private func unregisterLaunchAtLogin() {
        do {
            // Use modern SMAppService for macOS 13+ (app requires macOS 14+)
            try SMAppService.mainApp.unregister()
            print("✅ Launch at login unregistered successfully")
        } catch {
            print("❌ Failed to unregister launch at login: \(error)")
            // Revert state on failure to keep UI consistent with system state
            isEnabled = true
            userDefaults.set(true, forKey: launchAtLoginKey)
        }
    }
    
    private func syncWithSystemState() {
        do {
            let status = SMAppService.mainApp.status
            let systemState: Bool
            switch status {
            case .enabled:
                systemState = true
            case .requiresApproval:
                systemState = false
                print("⚠️ Launch at login requires user approval in System Settings.")
            case .notFound:
                systemState = false
                print("⚠️ Launch at login helper not found.")
            @unknown default:
                systemState = false
                print("⚠️ Unknown launch at login status: \(status)")
            }
            
            if systemState != isEnabled {
                // Sync local state with system state
                isEnabled = systemState
                userDefaults.set(systemState, forKey: launchAtLoginKey)
                print("🔄 Synced launch at login state with system: \(systemState)")
            }
        } catch {
            print("❌ Failed to check launch at login system state: \(error)")
        }
    }
    
    // MARK: - Public Interface
    
    /// Toggle the launch at login state
    public func toggle() {
        setEnabled(!isEnabled)
    }
    
    /// Enable launch at login after onboarding completion
    /// This is called when the status bar is shown for the first time
    public func enableAfterOnboarding() {
        // Only enable if not already configured by user
        if userDefaults.object(forKey: launchAtLoginKey) == nil {
            print("🚀 Enabling launch at login after onboarding completion")
            setEnabled(true)
        }
    }
    
    /// Check if launch at login is supported on this system
    /// Since this app requires macOS 14+, this will always return true
    public var isSupported: Bool {
        return true
    }
    
    /// Get a description of the current status
    public var statusDescription: String {
        return isEnabled ? "Enabled" : "Disabled"
    }
}