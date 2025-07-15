import SwiftUI

struct TextInjectionTestView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var logMessages = LogMessages()
    @Binding var isPresented: Bool
    
    private var textInjector: TextInjector {
        appState.transcriptionServiceInstance.injector
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Text Injection Test Suite")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Debug and test text injection functionality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Permission Status Section
                    GroupBox("Permission Status") {
                        HStack {
                            Image(systemName: textInjector.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(textInjector.hasAccessibilityPermission ? .green : .orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Accessibility Access")
                                    .font(.headline)
                                Text(textInjector.hasAccessibilityPermission ? 
                                     "✅ Granted - Text injection enabled" : 
                                     "⚠️ Required to inject text into applications")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if !textInjector.hasAccessibilityPermission {
                                Button("Grant Permission") {
                                    textInjector.requestAccessibilityPermission()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                    }
                    
                    // Documentation Section
                    GroupBox("How Text Injection Works") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Technical Overview")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("VTS uses multiple text injection methods for maximum compatibility:")
                                    .font(.body)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Accessibility API", systemImage: "1.circle.fill")
                                        .font(.caption)
                                    Text("Primary method using macOS Accessibility API to directly set text field values. Most reliable for standard UI elements.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 20)
                                    
                                    Label("Unicode Typing Simulation", systemImage: "2.circle.fill")
                                        .font(.caption)
                                    Text("Fallback method that simulates keyboard input using CGEvents. Supports international characters and complex layouts.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 20)
                                    
                                    Label("Legacy Typing", systemImage: "3.circle.fill")
                                        .font(.caption)
                                    Text("Final fallback using basic key simulation. Used when other methods fail.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 20)
                                }
                            }
                            
                            Divider()
                            
                            Text("Smart App Detection")
                                .font(.headline)
                            
                            Text("VTS automatically detects the target application and chooses the best injection method. Some apps like Cursor, terminal applications, and games may require specific handling.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Test Buttons Section
                    GroupBox("Test Functions") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Usage Instructions")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("1. Click any test button below")
                                Text("2. You have 3 seconds to focus on a text input field")
                                Text("3. The test text will be injected automatically")
                                Text("4. Watch the debug log below for detailed information")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Divider()
                            
                            // Basic Tests
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Basic Tests")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    TestButton(
                                        title: "Test Injection",
                                        description: "Basic 'Hello from VTS!' test",
                                        action: {
                                            logMessages.add("🧪 Starting basic text injection test...")
                                            textInjector.testTextInjection()
                                        }
                                    )
                                    
                                    TestButton(
                                        title: "Check Status",
                                        description: "Verify permission & system status",
                                        action: {
                                            logMessages.add("🔍 Checking system status...")
                                            textInjector.checkPermissionStatus()
                                        }
                                    )
                                }
                            }
                            
                            // Application-Specific Tests
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Application-Specific Tests")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    TestButton(
                                        title: "Test Cursor",
                                        description: "Optimized for Cursor IDE",
                                        action: {
                                            logMessages.add("🧪 Starting Cursor-specific test...")
                                            textInjector.testCursorInjection()
                                        }
                                    )
                                    
                                    TestButton(
                                        title: "Test Spanish",
                                        description: "Spanish characters & accents",
                                        action: {
                                            logMessages.add("🧪 Testing Spanish character support...")
                                            textInjector.testSpanishCharacters()
                                        }
                                    )
                                }
                            }
                            
                            // Advanced Tests
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Advanced Tests")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    TestButton(
                                        title: "Test Multilingual",
                                        description: "Multiple languages with special characters",
                                        action: {
                                            logMessages.add("🧪 Testing multilingual support...")
                                            textInjector.testMultilingualText()
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Debug Log Section
                    GroupBox("Debug Log") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Activity")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button("Clear Log") {
                                    logMessages.clear()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    if logMessages.messages.isEmpty {
                                        Text("No debug messages yet. Run a test to see detailed logging.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    } else {
                                        ForEach(logMessages.messages.reversed(), id: \.id) { message in
                                            HStack(alignment: .top, spacing: 8) {
                                                Text(message.timestamp)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 60, alignment: .leading)
                                                
                                                Text(message.content)
                                                    .font(.caption)
                                                    .textSelection(.enabled)
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 1)
                                        }
                                    }
                                }
                            }
                            .frame(height: 200)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding()
                    }
                    
                    // Troubleshooting Section
                    GroupBox("Troubleshooting") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Common Issues")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TroubleshootingItem(
                                    issue: "Text not appearing",
                                    solution: "Ensure the target application has focus and an active text field. Check accessibility permission."
                                )
                                
                                TroubleshootingItem(
                                    issue: "Special characters not working",
                                    solution: "Try the Unicode typing test. Some apps may require specific input methods."
                                )
                                
                                TroubleshootingItem(
                                    issue: "Permission keeps getting denied",
                                    solution: "During development, remove old VTS entries from System Settings > Privacy & Security > Accessibility."
                                )
                                
                                TroubleshootingItem(
                                    issue: "Test works but actual dictation doesn't",
                                    solution: "Check the main app logs in Console.app for VTS process. Test different applications."
                                )
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .frame(width: 700, height: 800)
        .onAppear {
            // Set up log capture
            setupLogCapture()
        }
        .onDisappear {
            // Remove logging delegate when view disappears
            textInjector.loggingDelegate = nil
        }
    }
    
    private func setupLogCapture() {
        // Set this view as the logging delegate to capture TextInjector messages
        textInjector.loggingDelegate = logMessages
        logMessages.add("Debug session started - capturing TextInjector logs")
    }
}

// MARK: - Helper Views

struct TestButton: View {
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

struct TroubleshootingItem: View {
    let issue: String
    let solution: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("• \(issue)")
                .font(.caption)
                .fontWeight(.medium)
            
            Text(solution)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
        }
    }
}

// MARK: - Debug Log System

class LogMessages: ObservableObject, TextInjectorLogging {
    @Published var messages: [LogMessage] = []
    
    func add(_ content: String) {
        let message = LogMessage(content: content)
        DispatchQueue.main.async {
            self.messages.append(message)
            // Keep only last 100 messages
            if self.messages.count > 100 {
                self.messages.removeFirst()
            }
        }
    }
    
    func clear() {
        messages.removeAll()
    }
    
    // MARK: - TextInjectorLogging
    func log(_ message: String) {
        add(message)
    }
}

struct LogMessage: Identifiable {
    let id = UUID()
    let content: String
    let timestamp: String
    
    init(content: String) {
        self.content = content
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        self.timestamp = formatter.string(from: Date())
    }
}

#Preview {
    TextInjectionTestView(isPresented: .constant(true))
        .environmentObject(AppState())
} 