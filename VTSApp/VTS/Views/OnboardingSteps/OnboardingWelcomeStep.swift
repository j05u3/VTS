import SwiftUI

struct OnboardingWelcomeStep: View {
    @State private var animateFeatures = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Hero section
            VStack(spacing: 20) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .scaleEffect(animateFeatures ? 1.0 : 0.8)
                    .animation(.easeOut(duration: 0.8).delay(0.2), value: animateFeatures)
                
                Text("Welcome to VTS")
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                
                Text("Transform your voice into text instantly with AI-powered transcription")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            // Features grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                FeatureCard(
                    icon: "brain.head.profile",
                    title: "AI-Powered",
                    description: "OpenAI & Groq integration for superior accuracy",
                    color: .green
                )
                .opacity(animateFeatures ? 1.0 : 0.0)
                .offset(y: animateFeatures ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: animateFeatures)
                
                FeatureCard(
                    icon: "key.fill",
                    title: "Your Keys",
                    description: "Bring your own API keys - no subscriptions",
                    color: .orange
                )
                .opacity(animateFeatures ? 1.0 : 0.0)
                .offset(y: animateFeatures ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: animateFeatures)
                
                FeatureCard(
                    icon: "keyboard",
                    title: "Smart Hotkeys",
                    description: "Customizable global shortcuts for instant access",
                    color: .purple
                )
                .opacity(animateFeatures ? 1.0 : 0.0)
                .offset(y: animateFeatures ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: animateFeatures)
                
                FeatureCard(
                    icon: "text.insert",
                    title: "Auto-Insert",
                    description: "Direct text insertion into any application",
                    color: .blue
                )
                .opacity(animateFeatures ? 1.0 : 0.0)
                .offset(y: animateFeatures ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.7), value: animateFeatures)
            }
            .frame(maxWidth: 600)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .onAppear {
            animateFeatures = true
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

#Preview {
    OnboardingWelcomeStep()
        .frame(width: 800, height: 600)
}