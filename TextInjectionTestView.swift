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
                    Text("Automatic Text Insertion Test Suite")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Test and debug automatic text insertion functionality")
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
                    GroupBox("System Permission Status") {
                        HStack {
                            Image(systemName: textInjector.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(textInjector.hasAccessibilityPermission ? .green : .orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Accessibility Access")
                                    .font(.headline)
                                Text(textInjector.hasAccessibilityPermission ? 
                                     "✅ Enabled - Automatic text insertion is ready" : 
                                     "⚠️ Required - Enable in System Settings to insert text automatically")
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
                    GroupBox("How Automatic Text Insertion Works") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Technical Methods")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Voice Transcription uses multiple text insertion methods for maximum app compatibility:")
                                    .font(.body)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Direct Text Insertion", systemImage: "1.circle.fill")
                                        .font(.caption)
                                    Text("Primary method using macOS Accessibility API to directly insert text. Most reliable for standard applications.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 20)
                                    
                                    Label("Keyboard Input Simulation", systemImage: "2.circle.fill")
                                        .font(.caption)
                                    Text("Fallback method that simulates typing. Supports international characters and works with specialized applications.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 20)
                                    
                                    Label("Basic Key Events", systemImage: "3.circle.fill")
                                        .font(.caption)
                                    Text("Final fallback using simple key simulation for maximum compatibility when other methods fail.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 20)
                                }
                            }
                            
                            Divider()
                            
                            Text("Application Compatibility")
                                .font(.headline)
                            
                            Text("Voice Transcription automatically detects applications and uses the best insertion method. Some specialized apps like code editors, terminals, and games may require specific handling.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    // Test Buttons Section
                    GroupBox("Testing Tools") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("How to Test")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("1. Click any test button below")
                                Text("2. You have 3 seconds to click on a text input field")
                                Text("3. Test text will be inserted automatically")
                                Text("4. Check the debug log below for detailed results")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Divider()
                            
                            // Basic Tests
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Basic Functionality Tests")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    TestButton(
                                        title: "Basic Test",
                                        description: "Simple text insertion test",
                                        action: {
                                            logMessages.add("🧪 Starting basic text insertion test...")
                                            textInjector.testTextInjection()
                                        }
                                    )
                                    
                                    TestButton(
                                        title: "Check System",
                                        description: "Verify permissions & system status",
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
                                        title: "Code Editor Test",
                                        description: "Optimized for code editors like Cursor",
                                        action: {
                                            logMessages.add("🧪 Starting code editor compatibility test...")
                                            textInjector.testCursorInjection()
                                        }
                                    )
                                    
                                    TestButton(
                                        title: "International Text",
                                        description: "Test Spanish characters & accents",
                                        action: {
                                            logMessages.add("🧪 Testing international character support...")
                                            textInjector.testSpanishCharacters()
                                        }
                                    )
                                }
                            }
                            
                            // Advanced Tests
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Advanced Compatibility Tests")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    TestButton(
                                        title: "Multilingual Text",
                                        description: "Test multiple languages and special characters",
                                        action: {
                                            logMessages.add("🧪 Testing multilingual text support...")
                                            textInjector.testMultilingualText()
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Debug Log Section
                    GroupBox("Test Results & Debug Log") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Test Activity Log")
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
                                        Text("No test results yet. Run a test above to see detailed diagnostic information.")
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
                                    issue: "Text not appearing in target application",
                                    solution: "Ensure the target application has focus with an active text field. Verify accessibility permission is enabled."
                                )
                                
                                TroubleshootingItem(
                                    issue: "International characters not displaying correctly",
                                    solution: "Test the international character support. Some applications may require specific input method settings."
                                )
                                
                                TroubleshootingItem(
                                    issue: "Permission repeatedly denied or reset",
                                    solution: "In System Settings > Privacy & Security > Accessibility, remove any old app entries and re-add the current version."
                                )
                                
                                TroubleshootingItem(
                                    issue: "Tests work but voice transcription doesn't insert text",
                                    solution: "Check Console.app for Voice Transcription logs. Try testing with different applications to identify compatibility issues."
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
        logMessages.add("Test session started - capturing diagnostic information")
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