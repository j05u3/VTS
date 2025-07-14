import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var captureEngine = CaptureEngine()
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var deviceManager = DeviceManager()
    
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
                        
                        // Model Selection
                        HStack {
                            Text("Model:")
                                .frame(width: 100, alignment: .leading)
                            Picker("Model", selection: $appState.selectedModel) {
                                ForEach(appState.selectedProvider.defaultModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // API Key
                        HStack {
                            Text("API Key:")
                                .frame(width: 100, alignment: .leading)
                            SecureField("Enter your API key", text: $appState.apiKey)
                                .textFieldStyle(.roundedBorder)
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
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "key.fill")
                Text("API Keys")
            }
            
            // Microphone Tab
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
            
            // Permissions Tab
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
                            
                            if !transcriptionService.injector.hasAccessibilityPermission {
                                Button("Grant") {
                                    transcriptionService.injector.requestAccessibilityPermission()
                                }
                                .buttonStyle(.bordered)
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
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppState())
} 