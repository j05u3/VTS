import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @ObservedObject var appState: AppState
    @State private var animateIn = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with progress
                    OnboardingHeaderView(
                        currentStep: onboardingManager.currentStep,
                        totalSteps: OnboardingStep.allCases.count
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    // Main content area - scrollable
                    ScrollView(showsIndicators: false) {
                        ZStack {
                            ForEach(OnboardingStep.allCases, id: \.self) { step in
                                if step == onboardingManager.currentStep {
                                    stepView(for: step)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        ))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.3), value: onboardingManager.currentStep)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    
                    // Navigation buttons - always visible at bottom
                    OnboardingNavigationView(
                        currentStep: onboardingManager.currentStep,
                        appState: appState,
                        onNext: { onboardingManager.nextStep() },
                        onPrevious: { onboardingManager.previousStep() },
                        onComplete: { 
                            onboardingManager.completeOnboarding()
                        }
                    )
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .frame(width: 800, height: 600)
        .background(Color.black.opacity(0.3))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
        }
        .scaleEffect(animateIn ? 1.0 : 0.95)
        .opacity(animateIn ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            OnboardingWelcomeStep()
        case .microphone:
            OnboardingMicrophoneStep(appState: appState)
        case .apiKey:
            OnboardingAPIKeyStep(appState: appState)
        case .accessibility:
            OnboardingAccessibilityStep(appState: appState)
        case .notifications:
            OnboardingNotificationsStep(appState: appState)
        case .test:
            OnboardingTestStep(appState: appState)
        case .completion:
            OnboardingCompletionStep()
        }
    }
}

struct OnboardingHeaderView: View {
    let currentStep: OnboardingStep
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 20) {
            // App icon and name
            HStack {
                if let nsImage = NSApplication.shared.applicationIconImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "mic.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                
                Text("VTS")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("Step \(currentStep.rawValue + 1) of \(totalSteps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(currentStep.title)
                        .font(.headline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: Double(currentStep.rawValue + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2)
            }
        }
    }
}

struct OnboardingNavigationView: View {
    let currentStep: OnboardingStep
    let appState: AppState
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onComplete: () -> Void
    
    private var canProceed: Bool {
        currentStep.canProceed(with: appState)
    }
    
    private var blockerMessage: String? {
        currentStep.proceedBlockerMessage(with: appState)
    }
    
    var body: some View {
        VStack(spacing: 12) {            
            HStack {
                // Previous button
                if currentStep != .welcome {
                    Button("Previous") {
                        onPrevious()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                // Skip button for optional steps
                if currentStep.isOptional {
                    Button("Skip") {
                        onNext()
                    }
                    .buttonStyle(.bordered)
                }
                
                // Next/Complete button
                Button(currentStep == .completion ? "Complete Setup" : "Continue") {
                    if currentStep == .completion {
                        onComplete()
                    } else {
                        onNext()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!canProceed)
                .help(blockerMessage ?? "")
            }
        }
    }
}

#Preview {
    OnboardingView(appState: AppState())
}