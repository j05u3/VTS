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
                
                // Large Recording Button
                Button(action: appState.toggleRecording) {
                    HStack {
                        Image(systemName: appState.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title)
                        Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                    }
                    .foregroundColor(appState.isRecording ? .red : .blue)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appState.apiKeyManagerService.hasAPIKey(for: appState.selectedProvider))
                .id(appState.apiKeyManagerService.keysUpdated) // Trigger UI update when keys change
                
                // Hotkey hint
                Text("Global Hotkey: ⌘⇧;")
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