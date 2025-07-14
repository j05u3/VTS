import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var apiKeyManager: APIKeyManager
    
    // Access shared instances from AppState instead of creating new ones
    private var captureEngine: CaptureEngine {
        appState.captureEngineService
    }
    
    private var transcriptionService: TranscriptionService {
        appState.transcriptionServiceInstance
    }
    
    private var deviceManager: DeviceManager {
        appState.deviceManagerService
    }
    
    init(apiKeyManager: APIKeyManager) {
        self.apiKeyManager = apiKeyManager
    }
    
    // State for adding new API keys
    @State private var newAPIKey = ""
    @State private var newKeyProvider: STTProviderType = .groq
    @State private var newKeyLabel = ""
    @State private var showingAddKeySheet = false
    
    var body: some View {
        TabView {
            // API Configuration Tab
            VStack(spacing: 20) {
                Text("API Configuration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                GroupBox("Provider Settings") {
                    VStack(alignment: .leading, spacing: 15) {
                        // Provider Selection
                        HStack {
                            Text("Provider:")
                                .frame(width: 100, alignment: .leading)
                            Picker("Provider", selection: Binding(
                                get: { appState.selectedProvider },
                                set: { appState.selectedProvider = $0 }
                            )) {
                                ForEach(STTProviderType.allCases, id: \.self) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Model Selection
                        HStack {
                            Text("Model:")
                                .frame(width: 100, alignment: .leading)
                            Picker("Model", selection: Binding(
                                get: { appState.selectedModel },
                                set: { appState.selectedModel = $0 }
                            )) {
                                ForEach(appState.selectedProvider.defaultModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // System Prompt
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("System Prompt:")
                                    .frame(width: 100, alignment: .leading)
                                Spacer()
                                Text("\(appState.systemPrompt.count) characters")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            TextField("Optional system prompt to improve transcription accuracy", text: $appState.systemPrompt, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                        
                        // Help text
                        Text("System prompts help improve accuracy for domain-specific language, names, or technical terms.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                GroupBox("API Keys") {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Stored API Keys")
                                .font(.headline)
                            Spacer()
                            Button("Add Key") {
                                newAPIKey = ""
                                newKeyLabel = ""
                                newKeyProvider = .groq
                                showingAddKeySheet = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        if apiKeyManager.availableKeys.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "key.slash")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("No API keys stored")
                                    .foregroundColor(.secondary)
                                Text("Add an API key to start using voice transcription")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(apiKeyManager.availableKeys) { key in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(key.displayName)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Text("Added \(key.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Current selection indicator
                                    if key.provider == appState.selectedProvider {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                    
                                    Button("Delete") {
                                        deleteAPIKey(key)
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "key.fill")
                Text("API Keys")
            }
            
            // Microphone Tab (unchanged)
            VStack(spacing: 20) {
                Text("Microphone Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                GroupBox("Device Priority") {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Available Devices:")
                                .font(.headline)
                            Spacer()
                            Button("Refresh") {
                                deviceManager.updateAvailableDevices()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if deviceManager.availableDevices.isEmpty {
                            Text("No microphones detected")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            // Available devices list
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(deviceManager.availableDevices) { device in
                                    HStack {
                                        Image(systemName: "mic.fill")
                                            .foregroundColor(.blue)
                                        Text(device.name)
                                            .font(.body)
                                        if device.isDefault {
                                            Text("(System Default)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button("+") {
                                            deviceManager.addDeviceToPriorities(device.id)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(deviceManager.devicePriorities.contains(device.id))
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            
                            Divider()
                            
                            // Priority list
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Priority Order:")
                                    .font(.headline)
                                
                                if deviceManager.devicePriorities.isEmpty {
                                    Text("No priority set - will use system default")
                                        .foregroundColor(.secondary)
                                        .italic()
                                } else {
                                    ForEach(Array(deviceManager.devicePriorities.enumerated()), id: \.offset) { index, deviceID in
                                        HStack {
                                            Text("\(index + 1).")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Image(systemName: "line.3.horizontal")
                                                .foregroundColor(.secondary)
                                            Text(deviceManager.getDeviceName(for: deviceID))
                                                .font(.body)
                                            if deviceID == deviceManager.preferredDeviceID {
                                                Text("(Active)")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                            Spacer()
                                            Button("−") {
                                                deviceManager.removeDeviceFromPriorities(deviceID)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "mic.fill")
                Text("Microphones")
            }
            
            // Permissions Tab (unchanged)
            VStack(spacing: 20) {
                Text("Permissions & Accessibility")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                GroupBox("Required Permissions") {
                    VStack(alignment: .leading, spacing: 20) {
                        // Microphone Permission
                        HStack {
                            Image(systemName: captureEngine.permissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(captureEngine.permissionGranted ? .green : .red)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Microphone Access")
                                    .font(.headline)
                                Text(captureEngine.permissionGranted ? "Granted" : "Required for audio recording")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if !captureEngine.permissionGranted {
                                Button("Grant") {
                                    // Permission will be requested automatically
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        Divider()
                        
                        // Accessibility Permission
                        HStack {
                            Image(systemName: transcriptionService.injector.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(transcriptionService.injector.hasAccessibilityPermission ? .green : .orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Accessibility Access")
                                    .font(.headline)
                                Text(transcriptionService.injector.hasAccessibilityPermission ? "Granted - Text injection enabled" : "Required to insert text like native dictation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack {
                                if !transcriptionService.injector.hasAccessibilityPermission {
                                    Button("Grant") {
                                        transcriptionService.injector.requestAccessibilityPermission()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Button("Refresh") {
                                    transcriptionService.injector.updatePermissionStatus()
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.secondary)
                                .font(.caption)
                            }
                        }
                    }
                    .padding()
                }
                
                GroupBox("How It Works") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VTS works like native macOS dictation:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("1.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Press ⌘⇧; anywhere in macOS to start recording")
                            }
                            
                            HStack {
                                Text("2.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Speak your text while the status bar shows 🔴")
                            }
                            
                            HStack {
                                Text("3.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Press ⌘⇧; again to stop and insert text at cursor")
                            }
                        }
                        
                        Text("Accessibility permission allows VTS to type text directly into any app, just like built-in dictation.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "hand.raised.fill")
                Text("Permissions")
            }
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showingAddKeySheet) {
            AddAPIKeySheet(
                provider: $newKeyProvider,
                label: $newKeyLabel,
                apiKey: $newAPIKey,
                onSave: { provider, label, key in
                    saveNewAPIKey(provider: provider, label: label, key: key)
                }
            )
        }
    }
    
    private func deleteAPIKey(_ key: ProviderAPIKey) {
        do {
            try apiKeyManager.deleteAPIKey(withId: key.id)
        } catch {
            print("Failed to delete API key: \(error)")
        }
    }
    
    private func saveNewAPIKey(provider: STTProviderType, label: String, key: String) {
        do {
            let finalLabel = label.isEmpty ? provider.defaultLabel : label
            try apiKeyManager.storeAPIKey(key, for: provider, label: finalLabel)
            showingAddKeySheet = false
        } catch {
            print("Failed to store API key: \(error)")
        }
    }
}

struct AddAPIKeySheet: View {
    @Binding var provider: STTProviderType
    @Binding var label: String
    @Binding var apiKey: String
    let onSave: (STTProviderType, String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add API Key")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Provider:")
                        .font(.headline)
                    Picker("Provider", selection: $provider) {
                        ForEach(STTProviderType.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Label (optional):")
                        .font(.headline)
                    TextField("e.g., Personal, Work", text: $label)
                        .textFieldStyle(.roundedBorder)
                    Text("Leave empty to use default label")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key:")
                        .font(.headline)
                    SecureField("Enter your \(provider.rawValue) API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Your API key will be stored securely in your macOS keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave(provider, label, apiKey)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    PreferencesView(apiKeyManager: APIKeyManager())
        .environmentObject(AppState())
} 