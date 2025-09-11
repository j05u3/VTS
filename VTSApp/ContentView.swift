import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("VTS")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Settings") {
                    appState.showPreferences()
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // Quick Settings
            VStack(spacing: 12) {
                HStack {
                    Text("AI Provider:")
                        .frame(width: 70, alignment: .leading)
                    Picker("", selection: $appState.selectedProvider) {
                        ForEach(STTProviderType.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appState.selectedProvider) { _, newProvider in
                        appState.selectedModel = newProvider.restModels.first ?? ""
                    }
                }
                
                HStack {
                    Text("AI Model:")
                        .frame(width: 70, alignment: .leading)
                    Picker("", selection: $appState.selectedModel) {
                        ForEach(appState.selectedProvider.restModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Real-time toggle (only show for providers that support it)
                if appState.selectedProvider.supportsRealtimeStreaming {
                    HStack {
                        Text("Mode:")
                            .frame(width: 70, alignment: .leading)
                        
                        Toggle("Faster ⚡️ (Beta)", isOn: $appState.useRealtime)
                            .toggleStyle(.switch)
                    }
                }
                
                HStack {
                    Text("API Key:")
                        .frame(width: 70, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        Image(systemName: appState.selectedProvider.iconName)
                            .foregroundColor(appState.selectedProvider.color)
                        
                        if appState.apiKeyManagerService.hasAPIKey(for: appState.selectedProvider) {
                            Text("✓ Configured")
                                .foregroundColor(.green)
                        } else {
                            Text("⚠ Not Set")
                                .foregroundColor(.red)
                        }
                    }
                    .id(appState.apiKeyManagerService.keysUpdated) // Trigger UI update when keys change
                    
                    Spacer()
                    Button("Settings") {
                        appState.showPreferences()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Divider()
            
            // Recording Status & Controls
            VStack(spacing: 12) {
                HStack {
                    Text("Status:")
                    
                    // Show status based on priority: Recording > Processing > Idle
                    if appState.isRecording {
                        Text("🔴 Recording Audio")
                            .foregroundColor(.red)
                    } else if appState.isProcessing {
                        Text("🔵 Processing Speech")
                            .foregroundColor(.blue)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
                            .onAppear {
                                isAnimating = true
                            }
                            .onDisappear {
                                isAnimating = false
                            }
                    } else {
                        Text("⚪️ Ready to Record")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Audio level bar
                HStack {
                    Text("Audio Level:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    AudioLevelView(audioLevel: appState.audioLevel, isRecording: appState.isRecording)
                    Spacer()
                }
                
                // Hotkey hint
                Text("Toggle Recording: \(appState.hotkeyManagerService.currentHotkeyString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Quick Actions
            HStack {                
                Button("Show \(getTranscriptionPreview())") {
                    appState.showLastTranscription()
                }
                .buttonStyle(.bordered)
                .disabled(getLastTranscription().isEmpty)
                
                Spacer()
                
                Button("Quit App") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func getLastTranscription() -> String {
        // Get the most recent transcription from either service
        let restLast = appState.restTranscriptionServiceInstance.lastTranscription
        let streamingLast = appState.streamingTranscriptionServiceInstance.lastTranscription
        return !streamingLast.isEmpty ? streamingLast : restLast
    }
    
    private func getTranscriptionPreview() -> String {
        let lastTranscription = getLastTranscription()

        if lastTranscription.isEmpty {
            return "Last Text"
        }
        
        // Take first n characters and add ellipsis if truncated
        let n = 11
        let preview = String(lastTranscription.prefix(n))
        return "\"\(lastTranscription.count > n ? preview + "…" : preview)\""
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}