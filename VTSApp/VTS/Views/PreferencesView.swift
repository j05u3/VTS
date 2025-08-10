import SwiftUI
import AppKit
import KeyboardShortcuts

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var apiKeyManager: APIKeyManager

    // Global Hotkeys Tab
    let hotkeysTabTitle = "Hotkeys"
    
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
    
    // State for API key editing
    @State private var editingAPIKeys: [STTProviderType: String] = [:]
    @State private var showingTestInjectionView = false
    
    var body: some View {
        TabView {
            // API Configuration Tab
            VStack(spacing: 20) {
                Text("Speech Recognition Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                GroupBox("AI Provider Configuration") {
                    VStack(alignment: .leading, spacing: 15) {
                        // Provider Selection
                        HStack {
                            Text("AI Provider:")
                                .frame(width: 120, alignment: .leading)
                            Picker("", selection: Binding(
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
                            Text("AI Model:")
                                .frame(width: 120, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { appState.selectedModel },
                                set: { appState.selectedModel = $0 }
                            )) {
                                ForEach(appState.selectedProvider.defaultModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Custom Instructions / Keywords based on provider
                        if appState.selectedProvider == .deepgram {
                            // Deepgram Keywords Management
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Keywords:")
                                        .frame(width: 240, alignment: .leading)
                                    Spacer()
                                    Text("\(appState.deepgramKeywords.count) keywords")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                KeywordManagementView(keywords: $appState.deepgramKeywords)
                            }
                            
                            // Help text for keywords
                            Text("Add keywords to boost recognition accuracy for specific terms, names, or domain-specific vocabulary.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            // System Prompt for OpenAI/Groq
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Custom Instructions:")
                                        .frame(width: 240, alignment: .leading)
                                    Spacer()
                                    Text("\(appState.systemPrompt.count) characters")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                ZStack(alignment: .topLeading) {
                                    // Background with border similar to TextField
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(NSColor.textBackgroundColor))
                                        )
                                    
                                    // Auto-scrolling TextEditor that keeps cursor visible
                                    AutoScrollingTextEditor(text: $appState.systemPrompt)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                    
                                    // Placeholder text when empty
                                    if appState.systemPrompt.isEmpty {
                                        Text("Add custom instructions to improve transcription accuracy for specific domains, names, or technical terms")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                            
                            // Help text for custom instructions
                            Text("Custom instructions help the AI understand your specific context, vocabulary, or domain expertise for better transcription accuracy.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                
                GroupBox("API Authentication") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("API Key Management")
                            .font(.headline)
                        
                        Text("Enter your API keys for speech recognition services. Keys are stored securely in your macOS keychain and never shared.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(STTProviderType.allCases, id: \.self) { provider in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: provider.iconName)
                                        .foregroundColor(provider.color)
                                        .frame(width: 20)
                                    
                                    Text(provider.displayName)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    // Status indicator
                                    if apiKeyManager.hasAPIKey(for: provider) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .help("API key configured")
                                    } else {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.orange)
                                            .help("API key required")
                                    }
                                }
                                
                                HStack {
                                    if editingAPIKeys[provider] != nil {
                                        // Editing mode
                                        SecureField("Paste your \(provider.displayName) API key here", text: Binding(
                                            get: { editingAPIKeys[provider] ?? "" },
                                            set: { editingAPIKeys[provider] = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        
                                        Button("Save") {
                                            saveAPIKey(for: provider)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(editingAPIKeys[provider]?.isEmpty != false)
                                        
                                        Button("Cancel") {
                                            editingAPIKeys[provider] = nil
                                        }
                                        .buttonStyle(.bordered)
                                    } else {
                                        // Display mode
                                        HStack {
                                            if apiKeyManager.hasAPIKey(for: provider) {
                                                Text("API key configured ••••••••••••••••")
                                                    .font(.system(.body, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                            } else {
                                                Text("No API key configured")
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                            }
                                            
                                            Spacer()
                                            
                                            if apiKeyManager.hasAPIKey(for: provider) {
                                                Button("Edit") {
                                                    editingAPIKeys[provider] = ""
                                                }
                                                .buttonStyle(.bordered)
                                                
                                                Button("Remove") {
                                                    removeAPIKey(for: provider)
                                                }
                                                .buttonStyle(.bordered)
                                                .foregroundColor(.red)
                                            } else {
                                                Button("Add Key") {
                                                    editingAPIKeys[provider] = ""
                                                }
                                                .buttonStyle(.borderedProminent)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "waveform")
                Text("Speech")
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
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Priority Order:")
                                        .font(.headline)
                                    Spacer()
                                    if !deviceManager.devicePriorities.isEmpty {
                                        Text("Drag to reorder")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if deviceManager.devicePriorities.isEmpty {
                                    Text("No priority set - will use system default")
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .frame(height: 40)
                                } else {
                                    List {
                                        ForEach(deviceManager.devicePriorities, id: \.self) { deviceID in
                                            HStack(spacing: 12) {
                                                // Priority number
                                                Text("\(deviceManager.devicePriorities.firstIndex(of: deviceID)! + 1).")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 20, alignment: .trailing)
                                                
                                                // Drag handle
                                                Image(systemName: "line.3.horizontal")
                                                    .foregroundColor(.secondary)
                                                    .imageScale(.medium)
                                                
                                                // Device name
                                                Text(deviceManager.getDeviceName(for: deviceID))
                                                    .font(.body)
                                                
                                                // Active indicator
                                                if deviceID == deviceManager.preferredDeviceID {
                                                    Text("(Active)")
                                                        .font(.caption)
                                                        .foregroundColor(.green)
                                                        .fontWeight(.medium)
                                                }
                                                
                                                Spacer()
                                                
                                                // Remove button
                                                Button("−") {
                                                    deviceManager.removeDeviceFromPriorities(deviceID)
                                                }
                                                .buttonStyle(.bordered)
                                                .foregroundColor(.red)
                                            }
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                        }
                                        .onMove(perform: { source, destination in
                                            deviceManager.moveDevice(from: IndexSet(source), to: destination)
                                        })
                                    }
                                    .listStyle(.plain)
                                    .frame(height: CGFloat(deviceManager.devicePriorities.count * 40))
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
                Text("Permissions")
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
                                    // Explicitly request permission
                                    captureEngine.requestMicrophonePermissionExplicitly()
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
                                HStack {
                                    Text("Accessibility Access")
                                        .font(.headline)
                                    
                                    if transcriptionService.injector.hasAccessibilityPermission {
                                        Button("Debug") {
                                            showingTestInjectionView = true
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }
                                }
                                
                                Text(transcriptionService.injector.hasAccessibilityPermission ? "Granted - Text injection enabled" : "Required to insert text like native dictation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 4) {
                                if !transcriptionService.injector.hasAccessibilityPermission {
                                    Button("Grant") {
                                        transcriptionService.injector.requestAccessibilityPermission()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                GroupBox("How It Works") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VTS works like native macOS dictation:")
                            .font(.headline)
                        
                        if appState.hotkeyManagerService.currentHotkeyString == SimpleHotkeyManager.NO_HOTKEY_SET {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No keyboard shortcut is currently set.")
                                    .foregroundColor(.secondary)
                                
                                Text("To get started:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("1.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Go to the '\(hotkeysTabTitle)' tab")
                                }
                                
                                HStack {
                                    Text("2.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Click in the 'Toggle Recording' field and press your desired shortcut")
                                }
                                
                                HStack {
                                    Text("3.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("The shortcut will work system-wide to start/stop recording")
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("1.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Press \(appState.hotkeyManagerService.currentHotkeyString) anywhere in macOS to start recording")
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
                                    Text("Press \(appState.hotkeyManagerService.currentHotkeyString) again to stop and insert text at cursor")
                                }
                            }
                        }
                        
                        Text("Accessibility permission allows VTS to insert text directly into any application, just like built-in dictation.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                GroupBox("Launch Settings") {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: appState.launchAtLoginManagerService.isEnabled ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(appState.launchAtLoginManagerService.isEnabled ? .green : .secondary)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Launch at Login")
                                    .font(.headline)
                                Text(appState.launchAtLoginManagerService.isEnabled ? "VTS will start automatically when you log in" : "Start VTS manually")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { appState.launchAtLoginManagerService.isEnabled },
                                set: { appState.launchAtLoginManagerService.setEnabled($0) }
                            ))
                            .toggleStyle(.switch)
                        }
                    }
                    .padding()
                }
                
                GroupBox("Auto-Update Settings") {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Automatic Updates")
                                    .font(.headline)
                                Text("Keep VTS up to date with the latest features and security improvements")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 8) {
                                Button(appState.sparkleUpdaterManagerService.isCheckingForUpdates ? "Checking..." : "Check Now") {
                                    appState.sparkleUpdaterManagerService.checkForUpdates()
                                }
                                .buttonStyle(.bordered)
                                .disabled(appState.sparkleUpdaterManagerService.isCheckingForUpdates)
                                
                                if appState.sparkleUpdaterManagerService.isCheckingForUpdates {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Update Behavior:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(UpdatePreference.allCases, id: \.self) { preference in
                                    HStack {
                                        Button(action: {
                                            appState.sparkleUpdaterManagerService.updatePreference = preference
                                        }) {
                                            HStack {
                                                Image(systemName: appState.sparkleUpdaterManagerService.updatePreference == preference ? "largecircle.fill.circle" : "circle")
                                                    .foregroundColor(appState.sparkleUpdaterManagerService.updatePreference == preference ? .accentColor : .secondary)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(preference.title)
                                                        .font(.body)
                                                        .foregroundColor(.primary)
                                                    Text(preference.description)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        if !appState.sparkleUpdaterManagerService.canAutoUpdate {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Auto-updates unavailable")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("This app was installed from the Mac App Store or in a sandboxed environment")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        
                        HStack {
                            Text("Current version: \(appState.sparkleUpdaterManagerService.currentVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
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
            
            
            VStack(spacing: 20) {
                Text("Global Hotkeys")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                GroupBox("Recording Hotkey") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Configure the global keyboard shortcut to toggle recording on/off.")
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Toggle Recording:")
                                .frame(width: 140, alignment: .leading)
                            
                            KeyboardShortcuts.Recorder(for: .toggleRecording)
                            
                            Spacer()
                            
                            Button("Reset to Default") {
                                KeyboardShortcuts.reset(.toggleRecording)
                                // The hotkey string will update automatically
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• The shortcut works system-wide, even when VTS is not the active application")
                            Text("• Current shortcut: \(appState.hotkeyManagerService.currentHotkeyString)")
                            Text("• Click in the recorder above to set a new shortcut")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                GroupBox("Copy Last Transcription Hotkey") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Configure the global keyboard shortcut to copy the last completed transcription.")
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Copy Last Transcription:")
                                .frame(width: 140, alignment: .leading)
                            
                            KeyboardShortcuts.Recorder(for: .copyLastTranscription)
                            
                            Spacer()
                            
                            Button("Reset to Default") {
                                KeyboardShortcuts.reset(.copyLastTranscription)
                                // The hotkey string will update automatically
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Copies the last completed transcription to the clipboard")
                            Text("• Current shortcut: \(appState.hotkeyManagerService.currentCopyHotkeyString)")
                            Text("• Works system-wide after completing at least one transcription")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "keyboard")
                Text(hotkeysTabTitle)
            }
            
            // Advanced Settings Tab
            VStack(spacing: 20) {
                Text("Advanced Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                GroupBox("Onboarding") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reset the first-time setup experience")
                            .font(.headline)
                        
                        Text("This will reset the onboarding flow and show the welcome screen when you restart the app. Useful for testing or if you want to review the setup process.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Reset Onboarding") {
                            OnboardingManager.shared.resetOnboarding()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "gearshape.2")
                Text("Advanced")
            }
        }
        .frame(width: 600, height: 750)
        .sheet(isPresented: $showingTestInjectionView) {
            TextInjectionTestView(isPresented: $showingTestInjectionView)
                .environmentObject(appState)
        }

    }
    
    private func saveAPIKey(for provider: STTProviderType) {
        guard let key = editingAPIKeys[provider], !key.isEmpty else { return }
        
        do {
            try apiKeyManager.storeAPIKey(key, for: provider)
            editingAPIKeys[provider] = nil
        } catch {
            print("Failed to store API key: \(error)")
        }
    }
    
    private func removeAPIKey(for provider: STTProviderType) {
        do {
            try apiKeyManager.deleteAPIKey(for: provider)
        } catch {
            print("Failed to delete API key: \(error)")
        }
    }
}

// MARK: - Keyword Management View

struct KeywordManagementView: View {
    @Binding var keywords: [String]
    @State private var newKeyword: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Add new keyword section
            HStack {
                TextField("Enter keyword or phrase", text: $newKeyword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addKeyword()
                    }
                
                Button("Add") {
                    addKeyword()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Keywords list
            if keywords.isEmpty {
                HStack {
                    Image(systemName: "text.magnifyingglass")
                        .foregroundColor(.secondary)
                    Text("No keywords added yet")
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(keywords.enumerated()), id: \.offset) { index, keyword in
                            HStack {
                                Text(keyword)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                
                                Spacer()
                                
                                Button(action: {
                                    removeKeyword(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.textBackgroundColor))
                )
        )
    }
    
    private func addKeyword() {
        let trimmedKeyword = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty, !keywords.contains(trimmedKeyword) else { return }
        
        keywords.append(trimmedKeyword)
        newKeyword = ""
    }
    
    private func removeKeyword(at index: Int) {
        guard index < keywords.count else { return }
        keywords.remove(at: index)
    }
}



#Preview {
    PreferencesView(apiKeyManager: APIKeyManager())
        .environmentObject(AppState())
} 