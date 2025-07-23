import SwiftUI
import KeyboardShortcuts
import KeychainAccess
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
    private let keychain: Keychain
    private let userDefaults = UserDefaults.standard
    
    // Keys for storing which provider/model is currently selected
    private let selectedProviderKey = "selectedProvider"
    private let selectedModelKey = "selectedModel"
    private let hasCompletedFirstRunKey = "hasCompletedFirstRun"
    private let keychainPermissionExplainedKey = "keychainPermissionExplained"
    
    // Published property to trigger UI updates when keys change
    @Published public var keysUpdated = 0
    
    // Track keychain access states
    @Published public var hasCompletedFirstRun: Bool
    @Published public var keychainPermissionExplained: Bool
    @Published public var hasShownPopover: Bool = false
    
    // UI-safe API key status (doesn't trigger keychain access)
    @Published public var apiKeyStatusForUI: [STTProviderType: Bool] = [:]
    
    public init() {
        // Create keychain with app-specific service identifier
        keychain = Keychain(service: "com.vts.apikeys")
            .accessibility(.whenUnlocked)
        
        // Initialize first run state
        hasCompletedFirstRun = userDefaults.bool(forKey: hasCompletedFirstRunKey)
        keychainPermissionExplained = userDefaults.bool(forKey: keychainPermissionExplainedKey)
        
        // Debug logging
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        print("🔑 APIKeyManager init: Bundle ID = \(bundleId)")
        print("🔑 APIKeyManager init: UserDefaults suite = \(userDefaults.dictionaryRepresentation().keys.contains(hasCompletedFirstRunKey))")
        print("🔑 APIKeyManager init: Raw hasCompletedFirstRun value = \(userDefaults.object(forKey: hasCompletedFirstRunKey) ?? "nil")")
        print("🔑 APIKeyManager init: Raw keychainPermissionExplained value = \(userDefaults.object(forKey: keychainPermissionExplainedKey) ?? "nil")")
        print("🔑 APIKeyManager init: hasCompletedFirstRun = \(hasCompletedFirstRun)")
        print("🔑 APIKeyManager init: keychainPermissionExplained = \(keychainPermissionExplained)")
        
        // TEMPORARY: Force reset for debugging if needed
        print("🔑 APIKeyManager init: FORCING RESET FOR TESTING")
        resetFirstRunState() // TEMPORARILY ENABLED FOR TESTING
    }
    
    // MARK: - API Key Management
    
    /// Store an API key for a provider (replaces any existing key for that provider)
    public func storeAPIKey(_ key: String, for provider: STTProviderType) throws {
        let keyIdentifier = provider.rawValue.lowercased()
        try keychain.set(key, key: keyIdentifier)
        
        // Update UI
        DispatchQueue.main.async {
            self.keysUpdated += 1
            self.apiKeyStatusForUI[provider] = true
        }
    }
    
    /// Get the API key for a provider
    public func getAPIKey(for provider: STTProviderType) throws -> String? {
        print("🚨 KEYCHAIN ACCESS: getAPIKey called for \(provider.rawValue)")
        print("🚨 KEYCHAIN ACCESS: hasCompletedFirstRun = \(hasCompletedFirstRun)")
        print("🚨 KEYCHAIN ACCESS: Call stack:")
        Thread.callStackSymbols.prefix(10).forEach { print("🚨   \($0)") }
        
        let keyIdentifier = provider.rawValue.lowercased()
        return try keychain.get(keyIdentifier)
    }
    
    /// Delete the API key for a provider
    public func deleteAPIKey(for provider: STTProviderType) throws {
        let keyIdentifier = provider.rawValue.lowercased()
        try keychain.remove(keyIdentifier)
        
        // Update UI
        DispatchQueue.main.async {
            self.keysUpdated += 1
            self.apiKeyStatusForUI[provider] = false
        }
    }
    
    /// Check if a provider has an API key configured
    public func hasAPIKey(for provider: STTProviderType) -> Bool {
        do {
            return try getAPIKey(for: provider) != nil
        } catch {
            return false
        }
    }
    
    /// Get the current API key for the selected provider
    public func getCurrentAPIKey() throws -> String? {
        return try getAPIKey(for: selectedProvider)
    }
    
    /// Get all providers that have API keys configured
    public var configuredProviders: [STTProviderType] {
        return STTProviderType.allCases.filter { hasAPIKeySafe(for: $0) }
    }
    
    // MARK: - First Run and Safe Keychain Access
    
    /// Mark that the first run has been completed
    public func markFirstRunCompleted() {
        print("🔑 APIKeyManager: markFirstRunCompleted called")
        hasCompletedFirstRun = true
        userDefaults.set(true, forKey: hasCompletedFirstRunKey)
        print("🔑 APIKeyManager: First run marked as completed, hasCompletedFirstRun = \(hasCompletedFirstRun)")
    }
    
    /// Mark that keychain permission has been explained to user
    public func markKeychainPermissionExplained() {
        keychainPermissionExplained = true
        userDefaults.set(true, forKey: keychainPermissionExplainedKey)
    }
    
    /// Reset first run state for testing
    public func resetFirstRunState() {
        print("🔑 APIKeyManager: Resetting first run state")
        print("🔑 APIKeyManager: Before reset - hasCompletedFirstRun = \(hasCompletedFirstRun)")
        print("🔑 APIKeyManager: Before reset - keychainPermissionExplained = \(keychainPermissionExplained)")
        print("🔑 APIKeyManager: Before reset - hasShownPopover = \(hasShownPopover)")
        
        hasCompletedFirstRun = false
        keychainPermissionExplained = false
        hasShownPopover = false
        apiKeyStatusForUI = [:] // Reset UI status
        userDefaults.removeObject(forKey: hasCompletedFirstRunKey)
        userDefaults.removeObject(forKey: keychainPermissionExplainedKey)
        userDefaults.synchronize() // Force write to disk
        
        print("🔑 APIKeyManager: After reset - hasCompletedFirstRun = \(hasCompletedFirstRun)")
        print("🔑 APIKeyManager: After reset - keychainPermissionExplained = \(keychainPermissionExplained)")
        print("🔑 APIKeyManager: After reset - hasShownPopover = \(hasShownPopover)")
        print("🔑 APIKeyManager: Reset complete")
    }
    
    /// Update UI status for a provider (safe method that doesn't trigger keychain access during first run)
    public func updateUIStatus(for provider: STTProviderType) {
        // Only check keychain if we've completed first run setup
        guard hasCompletedFirstRun else {
            apiKeyStatusForUI[provider] = false
            return
        }
        
        apiKeyStatusForUI[provider] = hasAPIKey(for: provider)
    }
    
    /// Get UI-safe API key status (doesn't trigger keychain access)
    public func hasAPIKeyForUI(for provider: STTProviderType) -> Bool {
        return apiKeyStatusForUI[provider] ?? false
    }
    
    /// Check if provider has API key without triggering keychain dialog on first run
    public func hasAPIKeySafe(for provider: STTProviderType) -> Bool {
        // On first run before popover is shown, assume no keys to avoid keychain dialog
        guard hasShownPopover else {
            return false
        }
        
        return hasAPIKey(for: provider)
    }
    
    /// Get API key with user explanation if needed
    public func getAPIKeyWithExplanation(for provider: STTProviderType, completion: @escaping (String?) -> Void) {
        // If we haven't explained keychain access yet, show explanation first
        guard keychainPermissionExplained else {
            showKeychainExplanationDialog { [weak self] userApproved in
                guard userApproved else {
                    completion(nil)
                    return
                }
                
                self?.markKeychainPermissionExplained()
                
                // Now actually get the API key
                do {
                    let key = try self?.getAPIKey(for: provider)
                    completion(key)
                } catch {
                    print("Failed to get API key after explanation: \(error)")
                    completion(nil)
                }
            }
            return
        }
        
        // If explanation already shown, directly access keychain
        do {
            let key = try getAPIKey(for: provider)
            completion(key)
        } catch {
            print("Failed to get API key: \(error)")
            completion(nil)
        }
    }
    
    /// Show explanation dialog before keychain access
    private func showKeychainExplanationDialog(completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Keychain Access Required"
        alert.informativeText = """
        VTS needs to securely store your API keys in your macOS Keychain.
        
        This is the same secure storage used by Safari, Mail, and other macOS apps for sensitive information.
        
        When prompted, we recommend clicking "Always Allow" so you won't see this dialog every time you use the app.
        
        Your API keys will be encrypted and only accessible to VTS.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        completion(response == .alertFirstButtonReturn)
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
        
        statusBarController.onFirstPopoverShown = { [weak self] in
            print("🔑 AppState: onFirstPopoverShown callback called")
            // Mark popover as shown but delay first run completion
            if let apiKeyManager = self?.apiKeyManager, !apiKeyManager.hasCompletedFirstRun {
                print("🔑 AppState: First popover show detected")
                apiKeyManager.hasShownPopover = true
                print("🔑 AppState: Delaying first run completion to allow UI to render")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔑 AppState: Now marking first run as completed after delay")
                    apiKeyManager.markFirstRunCompleted()
                    
                    // Update UI status for all providers now that first run is complete
                    print("🔑 AppState: Updating UI status for all providers")
                    for provider in STTProviderType.allCases {
                        apiKeyManager.updateUIStatus(for: provider)
                    }
                }
            } else {
                print("🔑 AppState: Not first run or apiKeyManager is nil")
            }
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
        guard apiKeyManager.hasAPIKeySafe(for: selectedProvider) else {
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
        
        // Get API key with explanation if needed
        apiKeyManager.getAPIKeyWithExplanation(for: selectedProvider) { [weak self] apiKey in
            guard let self = self, let apiKey = apiKey else {
                print("Failed to retrieve API key from keychain or user cancelled")
                return
            }
            
            do {
                print("Starting audio capture...")
                let audioStream = try self.captureEngine.start(deviceID: self.deviceManager.preferredDeviceID)
                
                let config = ProviderConfig(
                    apiKey: apiKey,
                    model: self.selectedModel,
                    systemPrompt: self.systemPrompt.isEmpty ? nil : self.systemPrompt
                )
                
                print("Starting transcription with \(self.selectedProvider.rawValue) using model \(self.selectedModel)")
                self.transcriptionService.startTranscription(
                    audioStream: audioStream,
                    config: config,
                    streamPartials: true
                )
                
                self.isRecording = true
                self.statusBarController.updateRecordingState(true)
                print("Voice recording started successfully")
            } catch {
                print("Failed to start recording: \(error)")
                self.showAlert("Recording Failed", "Unable to start voice recording: \(error.localizedDescription)")
            }
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