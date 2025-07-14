import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.semicolon, modifiers: [.command, .shift]))
}

@main
struct VTSApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppState: ObservableObject {
    private let statusBarController = StatusBarController()
    private let captureEngine = CaptureEngine()
    private let transcriptionService = TranscriptionService()
    private let deviceManager = DeviceManager()
    
    @Published var preferencesWindow: NSWindow?
    
    // Configuration state
    @Published var apiKey = ""
    @Published var selectedProvider: STTProviderType = .groq
    @Published var selectedModel = "whisper-large-v3"
    @Published var systemPrompt = ""
    @Published var isRecording = false
    
    init() {
        setupTranscriptionService()
        
        // Defer UI setup until after app launch
        DispatchQueue.main.async {
            self.initializeAfterLaunch()
        }
    }
    
    private func initializeAfterLaunch() {
        setupStatusBar()
        setupGlobalHotkey()
    }
    
    private func setupStatusBar() {
        // Initialize the status bar controller first
        statusBarController.initialize()
        
        statusBarController.setPopoverContent {
            ContentView()
                .environmentObject(self)
        }
        
        statusBarController.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }
        
        statusBarController.onShowPreferences = { [weak self] in
            self?.showPreferences()
        }
        
        statusBarController.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func setupGlobalHotkey() {
        print("Registering global hotkey: Cmd+Shift+;")
        
        // Register the hotkey handler using KeyboardShortcuts directly
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            print("Global hotkey pressed!")
            self?.toggleRecording()
        }
        
        print("Global hotkey registered successfully")
    }
    
    private func setupTranscriptionService() {
        updateProvider()
    }
    
    private func updateProvider() {
        switch selectedProvider {
        case .openai:
            transcriptionService.setProvider(OpenAIProvider())
        case .groq:
            transcriptionService.setProvider(GroqProvider())
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard !apiKey.isEmpty else {
            print("API key is required")
            showAlert("Error", "Please set an API key in preferences")
            return
        }
        
        guard captureEngine.permissionGranted else {
            print("Microphone permission not granted")
            showAlert("Permission Required", "Please grant microphone permission in System Preferences")
            return
        }
        
        updateProvider()
        
        do {
            print("Starting audio capture...")
            let audioStream = try captureEngine.start(deviceID: deviceManager.preferredDeviceID)
            
            let config = ProviderConfig(
                apiKey: apiKey,
                model: selectedModel,
                systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
            )
            
            print("Starting transcription service...")
            transcriptionService.startTranscription(
                audioStream: audioStream,
                config: config,
                streamPartials: true
            )
            
            isRecording = true
            statusBarController.updateRecordingState(true)
            print("Recording started successfully")
        } catch {
            print("Failed to start recording: \(error)")
            showAlert("Recording Error", error.localizedDescription)
        }
    }
    
    private func stopRecording() {
        captureEngine.stop()
        transcriptionService.stopTranscription()
        isRecording = false
        statusBarController.updateRecordingState(false)
        print("Recording stopped")
    }
    
    func showPreferences() {
        if preferencesWindow == nil {
            let preferencesView = PreferencesView()
                .environmentObject(self)
            
            let hostingController = NSHostingController(rootView: preferencesView)
            
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            preferencesWindow?.title = "VTS Preferences"
            preferencesWindow?.contentViewController = hostingController
            preferencesWindow?.center()
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}