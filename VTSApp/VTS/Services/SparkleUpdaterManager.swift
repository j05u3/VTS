import Foundation
import Sparkle

/// Manager for handling automatic updates using Sparkle
class SparkleUpdaterManager: ObservableObject {
    static let shared = SparkleUpdaterManager()
    
    private let updaterController: SPUStandardUpdaterController
    
    /// Update preferences stored in UserDefaults
    @Published var updatePreference: UpdatePreference {
        didSet {
            saveUpdatePreference()
            configureUpdateBehavior()
        }
    }
    
    /// Whether a check for updates is currently in progress
    @Published var isCheckingForUpdates = false
    
    /// Current update information if available
    // @Published var availableUpdate: SPUUpdateItem?
    @Published var availableUpdate: String? // Placeholder until Sparkle is added
    
    /// Keys for UserDefaults storage
    private let updatePreferenceKey = "updatePreference"
    
    private init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Load saved preference
        if let savedRawValue = UserDefaults.standard.object(forKey: updatePreferenceKey) as? Int,
           let savedPreference = UpdatePreference(rawValue: savedRawValue) {
            self.updatePreference = savedPreference
        } else {
            // Default to auto-check but manual install
            self.updatePreference = .autoCheck
        }
        
        // Configure initial behavior
        configureUpdateBehavior()
        
        // Set up updater delegate to receive callbacks
        setupUpdaterCallbacks()
    }
    
    /// Configure Sparkle's automatic update behavior based on user preference
    private func configureUpdateBehavior() {
        let updater = updaterController.updater
        
        switch updatePreference {
        case .autoInstall:
            updater.automaticallyChecksForUpdates = true
            updater.automaticallyDownloadsUpdates = true
        case .autoCheck:
            updater.automaticallyChecksForUpdates = true
            updater.automaticallyDownloadsUpdates = false
        case .disabled:
            updater.automaticallyChecksForUpdates = false
            updater.automaticallyDownloadsUpdates = false
        }
        
        print("Update preference set to: \(updatePreference.title)")
    }
    
    /// Set up callbacks to monitor update status
    private func setupUpdaterCallbacks() {
      // Sparkle handles most UI automatically, but you can implement SPUUpdaterDelegate
      // for custom behavior. For basic functionality, this can remain minimal.
      
      // Optional: Set up delegate for more control
      // updaterController.updater.delegate = self
    }
    
    /// Manually check for updates
    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        
        isCheckingForUpdates = true
        
        updaterController.checkForUpdates(nil)
        
        // Simulate check for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isCheckingForUpdates = false
            print("Checked for updates (simulated)")
        }
    }
    
    /// Save the update preference to UserDefaults
    private func saveUpdatePreference() {
        UserDefaults.standard.set(updatePreference.rawValue, forKey: updatePreferenceKey)
    }
    
    /// Get the current version of the app
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// Check if automatic updates are possible (based on app distribution method)
    var canAutoUpdate: Bool {
        // Auto-updates work for apps distributed outside the Mac App Store
        return Bundle.main.appStoreReceiptURL?.lastPathComponent != "sandboxReceipt"
    }
}

/// User preference for how updates should be handled
enum UpdatePreference: Int, CaseIterable {
    case autoInstall = 0
    case autoCheck = 1
    case disabled = 2
    
    var title: String {
        switch self {
        case .autoInstall:
            return "Auto-install updates"
        case .autoCheck:
            return "Check for updates, ask before installing"
        case .disabled:
            return "Do not check for updates"
        }
    }
    
    var description: String {
        switch self {
        case .autoInstall:
            return "Automatically download and install updates in the background"
        case .autoCheck:
            return "Check for updates automatically but ask before installing"
        case .disabled:
            return "Never check for updates automatically"
        }
    }
}
