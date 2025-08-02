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
        loadLaunchAtLoginState()
        // Set default to enabled for new installations
        if userDefaults.object(forKey: launchAtLoginKey) == nil {
            setEnabled(true)
        }
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
            if #available(macOS 13.0, *) {
                // Use modern SMAppService for macOS 13+
                try SMAppService.mainApp.register()
                print("✅ Launch at login registered successfully")
            } else {
                // Fallback for older macOS versions
                registerLaunchAtLoginLegacy()
            }
        } catch {
            print("❌ Failed to register launch at login: \(error)")
            // Revert state on failure
            isEnabled = false
            userDefaults.set(false, forKey: launchAtLoginKey)
        }
    }
    
    private func unregisterLaunchAtLogin() {
        do {
            if #available(macOS 13.0, *) {
                // Use modern SMAppService for macOS 13+
                try SMAppService.mainApp.unregister()
                print("✅ Launch at login unregistered successfully")
            } else {
                // Fallback for older macOS versions
                unregisterLaunchAtLoginLegacy()
            }
        } catch {
            print("❌ Failed to unregister launch at login: \(error)")
        }
    }
    
    private func syncWithSystemState() {
        if #available(macOS 13.0, *) {
            // Check actual system state
            let systemState = SMAppService.mainApp.status == .enabled
            if systemState != isEnabled {
                // Sync local state with system state
                isEnabled = systemState
                userDefaults.set(systemState, forKey: launchAtLoginKey)
                print("🔄 Synced launch at login state with system: \(systemState)")
            }
        }
    }
    
    // MARK: - Legacy Support for macOS 12 and earlier
    
    @available(macOS, deprecated: 13.0, message: "Use SMAppService.mainApp instead")
    private func registerLaunchAtLoginLegacy() {
        // For older macOS versions, we would use LSSharedFileList APIs
        // Since this app targets macOS 14+, this is primarily for completeness
        print("⚠️ Legacy launch at login registration not implemented - requires macOS 13+")
    }
    
    @available(macOS, deprecated: 13.0, message: "Use SMAppService.mainApp instead")
    private func unregisterLaunchAtLoginLegacy() {
        // For older macOS versions, we would use LSSharedFileList APIs
        // Since this app targets macOS 14+, this is primarily for completeness
        print("⚠️ Legacy launch at login unregistration not implemented - requires macOS 13+")
    }
    
    // MARK: - Public Interface
    
    /// Toggle the launch at login state
    public func toggle() {
        setEnabled(!isEnabled)
    }
    
    /// Check if launch at login is supported on this system
    public var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
    
    /// Get a description of the current status
    public var statusDescription: String {
        if !isSupported {
            return "Not supported on this macOS version"
        }
        return isEnabled ? "Enabled" : "Disabled"
    }
}