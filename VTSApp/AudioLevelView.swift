import SwiftUI

struct AudioLevelView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    private let barCount = 12
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let barHeight: CGFloat = 16
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor(for: index))
                    .frame(width: barWidth, height: barHeight)
                    .scaleEffect(y: barScale(for: index), anchor: .bottom)
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(height: barHeight)
    }
    
    private func barScale(for index: Int) -> CGFloat {
        guard isRecording else { return 0.1 }
        
        let threshold = CGFloat(index) / CGFloat(barCount - 1)
        let adjustedLevel = min(max(CGFloat(audioLevel) * 1.5, 0.0), 1.0) // Amplify sensitivity
        
        if adjustedLevel > threshold {
            // Animated scale based on how much the level exceeds the threshold
            let excess = adjustedLevel - threshold
            return 0.3 + min(excess * 2.0, 0.7)
        } else {
            return 0.1 // Minimum scale to show the bar exists
        }
    }
    
    private func barColor(for index: Int) -> Color {
        guard isRecording else { return Color.secondary.opacity(0.3) }
        
        let threshold = CGFloat(index) / CGFloat(barCount - 1)
        let adjustedLevel = min(max(CGFloat(audioLevel) * 1.5, 0.0), 1.0)
        
        if adjustedLevel > threshold {
            // Color based on intensity - green to yellow to red
            if threshold < 0.6 {
                return .green
            } else if threshold < 0.8 {
                return .yellow
            } else {
                return .red
            }
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Not recording
        HStack {
            Text("Idle:")
            AudioLevelView(audioLevel: 0.0, isRecording: false)
        }
        
        // Low level
        HStack {
            Text("Low:")
            AudioLevelView(audioLevel: 0.2, isRecording: true)
        }
        
        // Medium level
        HStack {
            Text("Medium:")
            AudioLevelView(audioLevel: 0.5, isRecording: true)
        }
        
        // High level
        HStack {
            Text("High:")
            AudioLevelView(audioLevel: 0.8, isRecording: true)
        }
        
        // Peak level
        HStack {
            Text("Peak:")
            AudioLevelView(audioLevel: 1.0, isRecording: true)
        }
    }
    .padding()
} 