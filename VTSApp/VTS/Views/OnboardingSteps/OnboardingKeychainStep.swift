import SwiftUI

struct OnboardingKeychainStep: View {
    @State private var animateShield = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Header section
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .scaleEffect(animateShield ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateShield)
                }
                
                Text("Secure Storage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("VTS uses your Mac's built-in Keychain to securely store your API keys")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            // Information section
            VStack(spacing: 24) {
                SecurityInfoCard(
                    icon: "key.fill",
                    title: "API Key Protection",
                    description: "Your API keys are encrypted and stored in macOS Keychain, the same secure storage used by Safari for passwords."
                )
                
                SecurityInfoCard(
                    icon: "shield.checkered",
                    title: "System-Level Security",
                    description: "Keychain access is protected by your Mac's security system. Only VTS can access its own stored keys."
                )
                
                SecurityInfoCard(
                    icon: "eye.slash.fill",
                    title: "Never Shared",
                    description: "Your API keys stay on your Mac and are only used to communicate directly with your chosen AI provider."
                )
                
                // What to expect section
                VStack(spacing: 16) {
                    Text("What to expect next:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ExpectationRow(
                            number: "1",
                            text: "You'll choose your AI provider (OpenAI or Groq)"
                        )
                        ExpectationRow(
                            number: "2",
                            text: "When you save your API key, macOS may ask for permission to access Keychain"
                        )
                        ExpectationRow(
                            number: "3",
                            text: "Click \"Always Allow\" to let VTS securely store your key"
                        )
                    }
                    
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("This permission request is normal and ensures your API keys are stored as securely as possible.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .frame(maxWidth: 600)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .onAppear {
            animateShield = true
        }
    }
}

struct SecurityInfoCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct ExpectationRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingKeychainStep()
        .frame(width: 800, height: 600)
}
