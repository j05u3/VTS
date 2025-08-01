import Foundation
import Combine

@MainActor
public class OnboardingManager: ObservableObject {
    public static let shared = OnboardingManager()
    
    @Published public var isOnboardingCompleted = false
    @Published public var currentStep: OnboardingStep = .welcome
    
    private let userDefaults = UserDefaults.standard
    private let onboardingCompletedKey = "onboardingCompleted"
    
    private init() {
        loadOnboardingState()
    }
    
    private func loadOnboardingState() {
        isOnboardingCompleted = userDefaults.bool(forKey: onboardingCompletedKey)
    }
    
    public func completeOnboarding() {
        isOnboardingCompleted = true
        userDefaults.set(true, forKey: onboardingCompletedKey)
        print("🎉 Onboarding completed successfully!")
    }
    
    public func resetOnboarding() {
        isOnboardingCompleted = false
        currentStep = .welcome
        userDefaults.removeObject(forKey: onboardingCompletedKey)
        print("🔄 Onboarding reset - will show on next app launch")
    }
    
    public func nextStep() {
        currentStep = currentStep.next()
    }
    
    public func previousStep() {
        currentStep = currentStep.previous()
    }
}

public enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case microphone = 1
    case apiKey = 2
    case accessibility = 3
    case notifications = 4
    case test = 5
    case completion = 6
    
    public func next() -> OnboardingStep {
        let allCases = OnboardingStep.allCases
        if let currentIndex = allCases.firstIndex(of: self),
           currentIndex < allCases.count - 1 {
            return allCases[currentIndex + 1]
        }
        return self
    }
    
    public func previous() -> OnboardingStep {
        let allCases = OnboardingStep.allCases
        if let currentIndex = allCases.firstIndex(of: self),
           currentIndex > 0 {
            return allCases[currentIndex - 1]
        }
        return self
    }
    
    public var title: String {
        switch self {
        case .welcome:
            return "Welcome to VTS"
        case .microphone:
            return "Microphone Access"
        case .apiKey:
            return "AI Provider Setup"
        case .accessibility:
            return "Text Insertion Access"
        case .notifications:
            return "Notifications"
        case .test:
            return "Test Your Setup"
        case .completion:
            return "All Set!"
        }
    }
    
    public var description: String {
        switch self {
        case .welcome:
            return "Your AI-powered voice transcription assistant"
        case .microphone:
            return "Required for recording audio"
        case .apiKey:
            return "Connect your AI provider for transcription"
        case .accessibility:
            return "Optional: Auto-insert text into apps"
        case .notifications:
            return "Stay informed about transcription status"
        case .test:
            return "Let's test your voice transcription"
        case .completion:
            return "You're ready to start using VTS!"
        }
    }
    
    public var isOptional: Bool {
        switch self {
        case .accessibility:
            return true
        default:
            return false
        }
    }
    
    @MainActor
    func canProceed(with appState: AppState) -> Bool {
        switch self {
        case .microphone:
            return appState.captureEngineService.permissionGranted
        case .apiKey:
            return appState.apiKeyManagerService.hasAPIKey(for: appState.selectedProvider)
        default:
            return true
        }
    }
    
    @MainActor
    func proceedBlockerMessage(with appState: AppState) -> String? {
        return canProceed(with: appState) ? nil : {
            switch self {
            case .microphone:
                return "Microphone permission is required to continue"
            case .apiKey:
                return "API key setup is required to continue"
            default:
                return nil
            }
        }()
    }
}