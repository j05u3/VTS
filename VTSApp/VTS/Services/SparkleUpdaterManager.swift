import Foundation
import Sparkle

/// Manages automatic updates using Sparkle framework
public class SparkleUpdaterManager: NSObject, ObservableObject {
    static let shared = SparkleUpdaterManager()
    
    private lazy var updaterController: SPUStandardUpdaterController = {
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()
    
    /// Update preferences stored in UserDefaults
    @Published var updatePreference: UpdatePreference {
        didSet {
            saveUpdatePreference()
            configureUpdateBehavior()
        }
    }
    
    /// Whether a check for updates is currently in progress
    @Published var isCheckingForUpdates = false
    
    /// Keys for UserDefaults storage
    private let updatePreferenceKey = "updatePreference"
    
    private override init() {
        // Initialize update preference first
        if let savedRawValue = UserDefaults.standard.object(forKey: "updatePreference") as? Int,
           let savedPreference = UpdatePreference(rawValue: savedRawValue) {
            self.updatePreference = savedPreference
        } else {
            // Default to auto-install
            self.updatePreference = .autoInstall
        }
        
        super.init()
        
        // Configure initial behavior (lazy property will be initialized when first accessed)
        configureUpdateBehavior()
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
    
    /// Manually check for updates
    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        
        isCheckingForUpdates = true
        updaterController.checkForUpdates(nil)
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

// MARK: - SPUUpdaterDelegate

extension SparkleUpdaterManager: SPUUpdaterDelegate {
    
    public func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
        }
    }
    
    public func updater(_ updater: SPUUpdater, didFindValidUpdate update: SUAppcastItem) {
        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
        }
    }
    
    public func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        DispatchQueue.main.async {
            self.isCheckingForUpdates = false
        }
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
