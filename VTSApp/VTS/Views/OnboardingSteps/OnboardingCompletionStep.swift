import SwiftUI

struct OnboardingCompletionStep: View {
    @State private var animateSuccess = false
    @State private var showConfetti = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Success animation section
            VStack(spacing: 30) {
                ZStack {
                    // Confetti background
                    if showConfetti {
                        ConfettiView()
                    }
                    
                    // Success icon with animation
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.green, .blue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .scaleEffect(animateSuccess ? 1.0 : 0.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0).delay(0.2), value: animateSuccess)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(animateSuccess ? 1.0 : 0.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0).delay(0.4), value: animateSuccess)
                    }
                }
                
                VStack(spacing: 16) {
                    Text("🎉 Congratulations!")
                        .font(.system(size: 40, weight: .bold, design: .default))
                        .opacity(animateSuccess ? 1.0 : 0.0)
                        .offset(y: animateSuccess ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: animateSuccess)
                    
                    Text("VTS is now ready to transform your voice into text!")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(animateSuccess ? 1.0 : 0.0)
                        .offset(y: animateSuccess ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.8), value: animateSuccess)
                }
            }
            
            // Quick start guide
            VStack(spacing: 20) {
                Text("Quick Start Guide")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .opacity(animateSuccess ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(1.0), value: animateSuccess)
                
                VStack(spacing: 16) {
                    QuickStartStep(
                        step: "1",
                        title: "Use your global hotkey",
                        description: "Press ⌘⇧; (or your custom hotkey) to start recording",
                        icon: "keyboard",
                        color: .blue
                    )
                    .opacity(animateSuccess ? 1.0 : 0.0)
                    .offset(x: animateSuccess ? 0 : -30)
                    .animation(.easeOut(duration: 0.6).delay(1.2), value: animateSuccess)
                    
                    QuickStartStep(
                        step: "2",
                        title: "Speak clearly",
                        description: "Talk naturally - your voice will be transcribed in real-time",
                        icon: "mic.fill",
                        color: .green
                    )
                    .opacity(animateSuccess ? 1.0 : 0.0)
                    .offset(x: animateSuccess ? 0 : -30)
                    .animation(.easeOut(duration: 0.6).delay(1.4), value: animateSuccess)
                    
                    QuickStartStep(
                        step: "3",
                        title: "Text appears automatically",
                        description: "Transcribed text is inserted where you're typing (if accessibility is enabled)",
                        icon: "text.insert",
                        color: .purple
                    )
                    .opacity(animateSuccess ? 1.0 : 0.0)
                    .offset(x: animateSuccess ? 0 : -30)
                    .animation(.easeOut(duration: 0.6).delay(1.6), value: animateSuccess)
                    
                    QuickStartStep(
                        step: "4",
                        title: "Access via menu bar",
                        description: "Click the VTS icon in your menu bar for settings and controls",
                        icon: "menubar.rectangle",
                        color: .orange
                    )
                    .opacity(animateSuccess ? 1.0 : 0.0)
                    .offset(x: animateSuccess ? 0 : -30)
                    .animation(.easeOut(duration: 0.6).delay(1.8), value: animateSuccess)
                }
                .frame(maxWidth: 600)
            }
            
            // Additional resources
            VStack(spacing: 16) {
                Text("Need Help?")
                    .font(.headline)
                    .opacity(animateSuccess ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(2.0), value: animateSuccess)
                
                HStack(spacing: 20) {
                    ResourceButton(
                        title: "Documentation",
                        icon: "book.fill",
                        action: { openGitHubReadme() }
                    )
                    .opacity(animateSuccess ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(2.2), value: animateSuccess)
                    
                    ResourceButton(
                        title: "Report Issues",
                        icon: "exclamationmark.triangle.fill",
                        action: { openGitHubIssues() }
                    )
                    .opacity(animateSuccess ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(2.4), value: animateSuccess)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 60)
        .onAppear {
            withAnimation {
                animateSuccess = true
            }
            
            // Trigger confetti after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showConfetti = true
            }
        }
    }
    
    private func openGitHubReadme() {
        if let url = URL(string: "https://github.com/j05u3/VTS#readme") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openGitHubIssues() {
        if let url = URL(string: "https://github.com/j05u3/VTS/issues") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct QuickStartStep: View {
    let step: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                
                Text(step)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ResourceButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ConfettiView: View {
    @State private var confettiItems: [ConfettiItem] = []
    
    var body: some View {
        ZStack {
            ForEach(confettiItems, id: \.id) { item in
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.color)
                    .frame(width: 8, height: 8)
                    .position(x: item.x, y: item.y)
                    .opacity(item.opacity)
            }
        }
        .onAppear {
            createConfetti()
        }
    }
    
    private func createConfetti() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]
        
        for _ in 0..<50 {
            let item = ConfettiItem(
                id: UUID(),
                x: Double.random(in: 100...700),
                y: Double.random(in: 100...500),
                color: colors.randomElement()!,
                opacity: Double.random(in: 0.6...1.0)
            )
            confettiItems.append(item)
        }
        
        // Animate confetti falling
        withAnimation(.easeOut(duration: 2.0)) {
            for i in confettiItems.indices {
                confettiItems[i].y += Double.random(in: 200...400)
                confettiItems[i].opacity = 0
            }
        }
        
        // Clear confetti after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            confettiItems.removeAll()
        }
    }
}

struct ConfettiItem {
    let id: UUID
    var x: Double
    var y: Double
    let color: Color
    var opacity: Double
}

#Preview {
    OnboardingCompletionStep()
        .frame(width: 800, height: 600)
}