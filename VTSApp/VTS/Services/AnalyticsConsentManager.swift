import Foundation
import Combine

/// Manages user consent for anonymous analytics data collection
@MainActor
public class AnalyticsConsentManager: ObservableObject {
    public static let shared = AnalyticsConsentManager()
    
    @Published public private(set) var hasConsent: Bool {
        didSet {
            UserDefaults.standard.set(hasConsent, forKey: consentKey)
            syncWithAnalytics()
        }
    }
    
    private let consentKey = "analytics_consent_granted"
    
    private init() {
        // Default to false for GDPR compliance (explicit opt-in required)
        hasConsent = UserDefaults.standard.bool(forKey: consentKey)
        syncWithAnalytics()
    }
    
    /// Grant consent and enable analytics collection
    public func grantConsent() {
        hasConsent = true
        // Log consent granted (now that we have consent)
        AnalyticsService.shared.trackConsentGranted()
        print("🔒 Analytics consent granted")
    }
    
    /// Revoke consent and disable analytics collection
    public func revokeConsent() {
        // Log consent revocation BEFORE disabling analytics
        AnalyticsService.shared.trackConsentRevoked()
        hasConsent = false
        print("🔒 Analytics consent revoked")
    }
    
    /// Sync consent state with Firebase Analytics
    private func syncWithAnalytics() {
        AnalyticsService.shared.setCollectionEnabled(enabled: hasConsent)
        print("📊 Analytics collection \(hasConsent ? "enabled" : "disabled")")
    }
}
