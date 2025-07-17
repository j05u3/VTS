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
                    
                    // Show status based on priority: Recording > Processing > Idle
                    if appState.isRecording {
                        Text("🔴 Recording")
                            .foregroundColor(.red)
                    } else if appState.transcriptionServiceInstance.isTranscribing {
                        Text("🔵 Processing")
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
                        Text("⚪️ Idle")
                            .foregroundColor(.secondary)
                    }
                    
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
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}