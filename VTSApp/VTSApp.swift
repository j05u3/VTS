import SwiftUI
import KeyboardShortcuts
import Combine

@main
struct VTSApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - API Key Management

@MainActor
public class APIKeyManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    
    // Keys for storing which provider/model is currently selected
    private let selectedProviderKey = "selectedProvider"
    private let selectedModelKey = "selectedModel"
    
    // Key prefix for storing API keys
    private let apiKeyPrefix = "apiKey_"
    
    // Published property to trigger UI updates when keys change
    @Published public var keysUpdated = 0
    
    public init() {
        // No initialization needed for UserDefaults
    }
    
    // MARK: - API Key Management
    
    /// Store an API key for a provider (replaces any existing key for that provider)
    public func storeAPIKey(_ key: String, for provider: STTProviderType) {
        let keyIdentifier = apiKeyPrefix + provider.dbKey
        userDefaults.set(key, forKey: keyIdentifier)
        
        // Update UI
        DispatchQueue.main.async {
            self.keysUpdated += 1
        }
    }
    
    /// Get the API key for a provider
    public func getAPIKey(for provider: STTProviderType) -> String? {
        let keyIdentifier = apiKeyPrefix + provider.dbKey
        return userDefaults.string(forKey: keyIdentifier)
    }
    
    /// Delete the API key for a provider
    public func deleteAPIKey(for provider: STTProviderType) {
        let keyIdentifier = apiKeyPrefix + provider.dbKey
        userDefaults.removeObject(forKey: keyIdentifier)
        
        // Update UI
        DispatchQueue.main.async {
            self.keysUpdated += 1
        }
    }
    
    /// Check if a provider has an API key configured
    public func hasAPIKey(for provider: STTProviderType) -> Bool {
        return getAPIKey(for: provider) != nil && !getAPIKey(for: provider)!.isEmpty
    }
    
    /// Get the current API key for the selected provider
    public func getCurrentAPIKey() -> String? {
        return getAPIKey(for: selectedProvider)
    }
    
    /// Get all providers that have API keys configured
    public var configuredProviders: [STTProviderType] {
        return STTProviderType.allCases.filter { hasAPIKey(for: $0) }
    }
    
    // MARK: - Current Selection Management
    
    public var selectedProvider: STTProviderType {
        get {
            if let rawValue = userDefaults.string(forKey: selectedProviderKey),
               let provider = STTProviderType(rawValue: rawValue) {
                return provider
            }
            return .groq // Default
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: selectedProviderKey)
        }
    }
    
    public var selectedModel: String {
        get {
            return userDefaults.string(forKey: selectedModelKey) ?? selectedProvider.defaultModels.first ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: selectedModelKey)
        }
    }
}

// MARK: - Supporting Types

extension STTProviderType {
    /// Display name for the provider
    var displayName: String {
        return rawValue
    }
    
    /// Icon name for the provider
    var iconName: String {
        switch self {
        case .openai:
            return "brain.head.profile"
        case .groq:
            return "bolt.fill"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    private let statusBarController = StatusBarController()
    private let captureEngine = CaptureEngine()
    private let transcriptionService = TranscriptionService()
    private let deviceManager = DeviceManager()
    private let apiKeyManager = APIKeyManager()
    private let hotkeyManager = SimpleHotkeyManager.shared
    private let notificationManager = NotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var settingsWindowController: SettingsWindowController?
    
    // Keys for UserDefaults storage
    private let systemPromptKey = "systemPrompt"
    
    // Configuration state - now using APIKeyManager
    @Published var systemPrompt = "" {
        didSet {
            saveSystemPrompt()
        }
    }
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var audioLevel: Float = 0.0
    
    // Computed properties that delegate to APIKeyManager with proper change notifications
    var selectedProvider: STTProviderType {
        get { apiKeyManager.selectedProvider }
        set { 
            objectWillChange.send()
            apiKeyManager.selectedProvider = newValue
            // Update model to default when provider changes
            apiKeyManager.selectedModel = newValue.defaultModels.first ?? ""
        }
    }
    
    var selectedModel: String {
        get { apiKeyManager.selectedModel }
        set { 
            objectWillChange.send()
            apiKeyManager.selectedModel = newValue 
        }
    }
    
    // Public access to services for PreferencesView
    var captureEngineService: CaptureEngine {
        return captureEngine
    }
    
    var transcriptionServiceInstance: TranscriptionService {
        return transcriptionService
    }
    
    var deviceManagerService: DeviceManager {
        return deviceManager
    }
    
    var apiKeyManagerService: APIKeyManager {
        return apiKeyManager
    }
    
    var hotkeyManagerService: SimpleHotkeyManager {
        return hotkeyManager
    }
    
    init() {
        loadSystemPrompt()
        setupTranscriptionService()
        setupObservableObjectBindings()
        
        // Defer UI setup until after app launch
        DispatchQueue.main.async {
            self.initializeAfterLaunch()
        }
    }
    
    private func setupObservableObjectBindings() {
        // Propagate changes from nested ObservableObjects to this AppState
        apiKeyManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        deviceManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        transcriptionService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        captureEngine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Sync audio level from capture engine
        captureEngine.$audioLevel
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        // Sync processing state from transcription service to AppState
        transcriptionService.$isTranscribing
            .sink { [weak self] isTranscribing in
                self?.isProcessing = isTranscribing
            }
            .store(in: &cancellables)
        
        // Observe AppState isProcessing changes to update status bar
        $isProcessing
            .sink { [weak self] isProcessing in
                self?.statusBarController.updateProcessingState(isProcessing)
            }
            .store(in: &cancellables)
        
        hotkeyManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func initializeAfterLaunch() {
        setupStatusBar()
        setupGlobalHotkey()
        setupNotifications()
    }
    
    private func setupStatusBar() {
        // Initialize the status bar controller first
        statusBarController.initialize()
        
        // Pass the transcription service for context menu previews
        statusBarController.setTranscriptionService(transcriptionService)
        
        statusBarController.setPopoverContent {
            ContentView()
                .environmentObject(self)
        }
        
        statusBarController.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }
        
        statusBarController.onCopyLastTranscription = { [weak self] in
            self?.copyLastTranscription()
        }
        
        statusBarController.onShowPreferences = { [weak self] in
            self?.showPreferences()
        }
        
        statusBarController.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func setupGlobalHotkey() {
        // Set up the hotkey handlers
        hotkeyManager.onToggleRecording = { [weak self] in
            self?.toggleRecording()
        }
        
        hotkeyManager.onCopyLastTranscription = { [weak self] in
            self?.copyLastTranscription()
        }
        
        // Register the hotkeys
        hotkeyManager.registerHotkey()
    }
    
    private func setupNotifications() {
        // Request notification permissions
        Task {
            await notificationManager.requestPermission()
            print("🔔 Notification permissions requested")
        }
        
        // Setup notification action handlers
        notificationManager.onSettingsRequested = { [weak self] in
            Task { @MainActor in
                self?.showPreferences()
            }
        }
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
        // Check if we have an API key for the selected provider
        guard apiKeyManager.hasAPIKey(for: selectedProvider) else {
            print("No API key configured for \(selectedProvider)")
            showAlert("API Key Required", "Please add an API key for \(selectedProvider.rawValue) in Settings to enable speech transcription.")
            return
        }
        
        guard captureEngine.permissionGranted else {
            print("Microphone permission not granted")
            showAlert("Microphone Access Required", "Please grant microphone permission in System Preferences > Privacy & Security > Microphone to use VTS.")
            return
        }
        
        updateProvider()
        
        do {
            print("Starting audio capture...")
            let audioStream = try captureEngine.start(deviceID: deviceManager.preferredDeviceID)
            
            // Get the API key from local storage
            guard let apiKey = apiKeyManager.getCurrentAPIKey() else {
                print("Failed to retrieve API key from storage")
                showAlert("API Key Error", "Unable to retrieve your API key. Please check your API key configuration in Settings.")
                return
            }
            
            let config = ProviderConfig(
                apiKey: apiKey,
                model: selectedModel,
                systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
            )
            
            print("Starting transcription with \(selectedProvider.rawValue) using model \(selectedModel)")
            transcriptionService.startTranscription(
                audioStream: audioStream,
                config: config,
                streamPartials: true
            )
            
            isRecording = true
            statusBarController.updateRecordingState(true)
            print("Voice recording started successfully")
        } catch {
            print("Failed to start recording: \(error)")
            showAlert("Recording Failed", "Unable to start voice recording: \(error.localizedDescription)")
        }
    }
    
    private func stopRecording() {
        captureEngine.stop()
        // Don't cancel transcription - let it finish processing the collected audio
        // transcriptionService.stopTranscription()  // Removed this line
        isRecording = false
        statusBarController.updateRecordingState(false)
        print("Voice recording stopped - processing audio for transcription")
    }
    
    func showPreferences() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(appState: self)
        }
        
        settingsWindowController?.showWindow()
    }
    
    func settingsWindowDidClose() {
        settingsWindowController = nil
    }
    
    func copyLastTranscription() {
        if transcriptionService.copyLastTranscriptionToClipboard() {
            print("Transcribed text copied to clipboard: '\(transcriptionService.lastTranscription)'")
        } else {
            print("No transcription available to copy")
            showAlert("No Text Available", "There is no completed transcription to copy. Please record some speech first.")
        }
    }
    
    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    // MARK: - System Prompt Persistence
    
    private func saveSystemPrompt() {
        UserDefaults.standard.set(systemPrompt, forKey: systemPromptKey)
    }
    
    private func loadSystemPrompt() {
        systemPrompt = UserDefaults.standard.string(forKey: systemPromptKey) ?? ""
    }
}