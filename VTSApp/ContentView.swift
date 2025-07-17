import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("VTS")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Preferences") {
                    appState.showPreferences()
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // Quick Settings
            VStack(spacing: 12) {
                HStack {
                    Text("Provider:")
                        .frame(width: 70, alignment: .leading)
                    Picker("Provider", selection: $appState.selectedProvider) {
                        ForEach(STTProviderType.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appState.selectedProvider) { _, newProvider in
                        appState.selectedModel = newProvider.defaultModels.first ?? ""
                    }
                }
                
                HStack {
                    Text("Model:")
                        .frame(width: 70, alignment: .leading)
                    Picker("Model", selection: $appState.selectedModel) {
                        ForEach(appState.selectedProvider.defaultModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                HStack {
                    Text("API Keys:")
                        .frame(width: 70, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        Image(systemName: appState.selectedProvider.iconName)
                            .foregroundColor(appState.selectedProvider == .openai ? .green : .orange)
                        
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
                    Text(appState.isRecording ? "🔴 Recording" : "⚪️ Idle")
                        .foregroundColor(appState.isRecording ? .red : .secondary)
                    Spacer()
                }
                
                // Audio level bar
                HStack {
                    Text("Level:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    AudioLevelView(audioLevel: appState.audioLevel, isRecording: appState.isRecording)
                    Spacer()
                }
                
                // Hotkey hint
                Text("Global Hotkey: \(appState.hotkeyManagerService.currentHotkeyString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Quick Actions
            HStack {
                Button("Preferences") {
                    appState.showPreferences()
                }
                .buttonStyle(.bordered)
                
                Button("Copy \(getTranscriptionPreview()) (\(appState.hotkeyManagerService.currentCopyHotkeyString == "None" ? "No hotkey set" : appState.hotkeyManagerService.currentCopyHotkeyString))") {
                    appState.copyLastTranscription()
                }
                .buttonStyle(.bordered)
                .disabled(appState.transcriptionServiceInstance.lastTranscription.isEmpty)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func getTranscriptionPreview() -> String {
        let lastTranscription = appState.transcriptionServiceInstance.lastTranscription

        if lastTranscription.isEmpty {
            return "Last"
        }
        
        // Take first 6 characters and add ellipsis if truncated
        let preview = String(lastTranscription.prefix(6))
        return "\"\(lastTranscription.count > 6 ? preview + "…" : preview)\""
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}