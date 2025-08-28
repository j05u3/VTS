import SwiftUI

struct OnboardingAnalyticsStep: View {
    @ObservedObject var appState: AppState
    @State private var animateContent = false
    
    private var consentManager: AnalyticsConsentManager {
        appState.analyticsConsentManagerService
    }
    
    var body: some View {
        VStack(spacing: 40) {
            // Header section
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .scaleEffect(animateContent ? 1.0 : 0.8)
                    .animation(.easeOut(duration: 0.8), value: animateContent)
                
                Text("Help Improve VTS")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("This step is completely optional")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .opacity(animateContent ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: animateContent)
            }
            
            // Content section
            VStack(spacing: 24) {
                // What we collect
                AnalyticsFeatureCard(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    title: "What we collect:",
                    items: [
                        "Which features are used most",
                        "Performance and crash reports",
                        "General usage patterns"
                    ]
                )
                .opacity(animateContent ? 1.0 : 0.0)
                .offset(x: animateContent ? 0 : -20)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: animateContent)
                
                // What we don't collect
                AnalyticsFeatureCard(
                    icon: "xmark.circle.fill",
                    iconColor: .red,
                    title: "Never collected:",
                    items: [
                        "Your voice recordings",
                        "Transcription content",
                        "Personal information or API keys"
                    ]
                )
                .opacity(animateContent ? 1.0 : 0.0)
                .offset(x: animateContent ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.7), value: animateContent)
                
                // Consent toggle
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        
                        Text("Share anonymous usage data")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { consentManager.hasConsent },
                            set: { newValue in
                                if newValue {
                                    consentManager.grantConsent()
                                } else {
                                    consentManager.revokeConsent()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .scaleEffect(1.1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(consentManager.hasConsent ? Color.blue.opacity(0.5) : Color.primary.opacity(0.2), lineWidth: 1.5)
                            )
                    )
                    
                    Text("VTS works exactly the same either way. You can change this later in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(animateContent ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(0.9), value: animateContent)
            }
            .frame(maxWidth: 500)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .onAppear {
            animateContent = true
        }
    }
}

struct AnalyticsFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(item)
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
        )
    }
}

#Preview {
    OnboardingAnalyticsStep(appState: AppState())
        .frame(width: 800, height: 600)
}
