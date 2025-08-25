import Foundation
import FirebaseAnalytics

/// Service for tracking user events and app usage analytics
@MainActor
public class AnalyticsService: ObservableObject {
    public static let shared = AnalyticsService()
    
    private init() {}
    
    public func setCollectionEnabled(enabled: Bool) {        
        // Enable Firebase Analytics data collection
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }
    
    /// Track when user starts recording voice
    public func trackStartRecording() {
        Analytics.logEvent("start_recording", parameters: [
            "platform": "macos"
        ])
        print("📊 Analytics: Tracked start_recording event")
    }
    
    
    /// Track transcription completion
    public func trackTranscriptionCompleted(provider: String, model: String, success: Bool) {
        Analytics.logEvent("transcription_completed", parameters: [
            "provider": provider,
            "model": model,
            "success": success,
            "platform": "macos"
        ])
        print("📊 Analytics: Tracked transcription_completed event - Provider: \(provider), Success: \(success)")
    }
    
    /// Track app launch
    public func trackAppLaunch() {
        Analytics.logEvent("app_launch", parameters: [
            "platform": "macos"
        ])
        print("📊 Analytics: Tracked app_launch event")
    }
}
