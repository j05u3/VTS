import SwiftUI
import KeyboardShortcuts
import KeychainAccess
import Combine
import FirebaseCore

@main
struct VTSApp: App {
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Initialize analytics consent manager (handles setCollectionEnabled automatically)
        _ = AnalyticsConsentManager.shared
        
        // Track app launch (will only fire if consent is granted)
        AnalyticsService.shared.trackAppLaunch()
    }
    @StateObject private var appState = AppState()
    @StateObject private var onboardingManager = OnboardingManager.shared
    
    var body: some Scene {
        WindowGroup {
            if !onboardingManager.isOnboardingCompleted {
                OnboardingView(appState: appState)
                    .environmentObject(onboardingManager)
                    .onReceive(onboardingManager.$isOnboardingCompleted) { completed in
                        if completed {
                            // Initialize the main app after onboarding
                            appState.initializeMainApp()
                            
                            // Close the onboarding window
                            NSApplication.shared.windows.first?.close()
                        }
                    }
            } else {
                // Show empty view since main app runs in status bar
                EmptyView()
                    .frame(width: 0, height: 0)
                    .onAppear {
                        appState.initializeMainApp()
                        // Close the main window immediately when onboarding is done
                        NSApplication.shared.windows.first?.close()
                    }
            }
        }
        .windowResizability(.contentSize)
        
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
    
    // Published property to trigger UI updates when keys change
    @Published public var keysUpdated = 0
    
    public init() {
        // Create keychain with bundle-specific service identifier
        // This ensures debug and production builds use separate keychains
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.vts.app"
        let serviceIdentifier = "\(bundleIdentifier).apikeys"
        
        keychain = Keychain(service: serviceIdentifier)
            .accessibility(.whenUnlocked)
    }
    
    // MARK: - API Key Management
    
    /// Store an API key for a provider (replaces any existing key for that provider)
    public func storeAPIKey(_ key: String, for provider: STTProviderType) throws {
        let keyIdentifier = provider.rawValue.lowercased()
        try keychain.set(key, key: keyIdentifier)
        
        // Update UI
        DispatchQueue.main.async {
            self.keysUpdated += 1
        }
    }
    
    /// Get the API key for a provider
    public func getAPIKey(for provider: STTProviderType) throws -> String? {
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
        return STTProviderType.allCases.filter { hasAPIKey(for: $0) }
    }
    
    // MARK: - Current Selection Management
    
    public var selectedProvider: STTProviderType {
        get {
            if let rawValue = userDefaults.string(forKey: selectedProviderKey),
               let provider = STTProviderType(rawValue: rawValue) {
                return provider
            }
            return .openai // Default
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
        case .deepgram:
            return "waveform.circle.fill"
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
    private let launchAtLoginManager = LaunchAtLoginManager.shared
    private let sparkleUpdaterManager = SparkleUpdaterManager.shared
    private let analyticsConsentManager = AnalyticsConsentManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var settingsWindowController: SettingsWindowController?
    private var isMainAppInitialized = false
    
    // Keys for UserDefaults storage
    private let systemPromptKey = "systemPrompt"
    private let deepgramKeywordsKey = "deepgramKeywords"
    
    // Configuration state - now using APIKeyManager
    @Published var systemPrompt = "" {
        didSet {
            saveSystemPrompt()
        }
    }
    @Published var deepgramKeywords: [String] = [] {
        didSet {
            saveDeepgramKeywords()
        }
    }
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var audioLevel: Float = 0.0
    
    // Analytics tracking properties
    private var processStartTime: Date?        // When user first presses record button
    private var audioRecordingStartTime: Date? // When audio recording actually starts  
    private var audioRecordingEndTime: Date?   // When audio recording stops
    
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
    
    var launchAtLoginManagerService: LaunchAtLoginManager {
        return launchAtLoginManager
    }
    
    var sparkleUpdaterManagerService: SparkleUpdaterManager {
        return sparkleUpdaterManager
    }
    
    var analyticsConsentManagerService: AnalyticsConsentManager {
        return analyticsConsentManager
    }
    
    init() {
        loadSystemPrompt()
        loadDeepgramKeywords()
        setupTranscriptionService()
        setupObservableObjectBindings()
        
        // Only initialize main app if onboarding is completed
        if OnboardingManager.shared.isOnboardingCompleted {
            initializeMainApp()
        }
    }
    
    func initializeMainApp() {
        guard !isMainAppInitialized else { return }
        isMainAppInitialized = true
        
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
        
        launchAtLoginManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        sparkleUpdaterManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        analyticsConsentManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func initializeAfterLaunch() {
        setupStatusBar()
        setupGlobalHotkey()
        setupNotifications()
        
        // Enable launch at login after completing onboarding and showing status bar
        // This ensures the app is fully configured before auto-launching
        launchAtLoginManager.enableAfterOnboarding()
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
        
        statusBarController.onShowLastTranscription = { [weak self] in
            self?.showLastTranscription()
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
        
        // Set up analytics callback
        transcriptionService.onTranscriptionCompleted = { [weak self] provider, model, success, audioDurationMs, processingTimeMs in
            AnalyticsService.shared.trackTranscriptionCompleted(
                provider: provider,
                model: model,
                success: success,
                audioDurationMs: audioDurationMs,
                processingTimeMs: processingTimeMs
            )
        }
    }
    
    private func updateProvider() {
        switch selectedProvider {
        case .openai:
            transcriptionService.setProvider(OpenAIProvider())
        case .groq:
            transcriptionService.setProvider(GroqProvider())
        case .deepgram:
            transcriptionService.setProvider(DeepgramProvider())
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
        
        // Record process start time (when user pressed the hotkey)
        processStartTime = Date()
        
        do {
            print("Starting audio capture...")
            
            // Record when audio recording actually starts
            audioRecordingStartTime = Date()
            
            let audioStream = try captureEngine.start(deviceID: deviceManager.preferredDeviceID)
            
            // Get the API key securely from keychain
            guard let apiKey = try apiKeyManager.getCurrentAPIKey() else {
                print("Failed to retrieve API key from keychain")
                showAlert("API Key Error", "Unable to retrieve your API key. Please check your keychain access or re-enter your API key in Settings.")
                return
            }
            
            // Configure provider-specific settings
            let providerSystemPrompt = (selectedProvider != .deepgram && !systemPrompt.isEmpty) ? systemPrompt : nil
            let providerKeywords = (selectedProvider == .deepgram && selectedModel != "nova-3" && !deepgramKeywords.isEmpty) ? deepgramKeywords : nil
            
            let config = ProviderConfig(
                apiKey: apiKey,
                model: selectedModel,
                systemPrompt: providerSystemPrompt,
                keywords: providerKeywords
            )
            
            print("Starting transcription with \(selectedProvider.rawValue) using model \(selectedModel)")
            
            // Pass timing data to transcription service for analytics
            transcriptionService.setTimingData(
                processStart: processStartTime,
                audioStart: audioRecordingStartTime,
                audioEnd: nil // Will be set in stopRecording
            )
            
            transcriptionService.startTranscription(
                audioStream: audioStream,
                config: config,
                streamPartials: true
            )
            
            isRecording = true
            statusBarController.updateRecordingState(true)
            
            // Track analytics event for start recording
            AnalyticsService.shared.trackStartRecording()
            
            print("Voice recording started successfully")
        } catch {
            print("Failed to start recording: \(error)")
            showAlert("Recording Failed", "Unable to start voice recording: \(error.localizedDescription)")
        }
    }
    
    private func stopRecording() {
        // Record when audio recording stops
        audioRecordingEndTime = Date()
        
        // Update timing data in transcription service
        transcriptionService.setTimingData(
            processStart: processStartTime,
            audioStart: audioRecordingStartTime,
            audioEnd: audioRecordingEndTime
        )
        
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
    
    func showLastTranscription() {
        if !transcriptionService.lastTranscription.isEmpty {
            print("Last transcription: '\(transcriptionService.lastTranscription)'")
            showTranscriptionAlert(transcriptionService.lastTranscription)
        } else {
            print("No transcription available")
            showAlert("No Text Available", "There is no completed transcription available. Please record some speech first.")
        }
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
    
    private func showTranscriptionAlert(_ transcription: String) {
        let alert = NSAlert()
        alert.messageText = "Last Transcription"
        
        // Create the informative text with hotkey information
        let hotkeyInfo = hotkeyManager.currentCopyHotkeyString == SimpleHotkeyManager.NO_HOTKEY_SET 
            ? "No shortcut set" 
            : hotkeyManager.currentCopyHotkeyString
        
        alert.informativeText = "\"\(transcription)\"\n\nTip: You can also copy transcriptions using the hotkey: \(hotkeyInfo)"
        alert.alertStyle = .informational
        
        // Add Copy button
        alert.addButton(withTitle: "Copy")
        
        // Add OK button
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        
        // Handle the response
        switch response {
        case .alertFirstButtonReturn: // Copy button
            if transcriptionService.copyLastTranscriptionToClipboard() {
                print("Transcribed text copied to clipboard via dialog: '\(transcription)'")
            }
        case .alertSecondButtonReturn: // OK button
            // Do nothing, just close the dialog
            break
        default:
            break
        }
    }
    
    // MARK: - Configuration Persistence
    
    private func saveSystemPrompt() {
        UserDefaults.standard.set(systemPrompt, forKey: systemPromptKey)
    }
    
    private func loadSystemPrompt() {
        systemPrompt = UserDefaults.standard.string(forKey: systemPromptKey) ?? ""
    }
    
    private func saveDeepgramKeywords() {
        let keywordData = try? JSONEncoder().encode(deepgramKeywords)
        UserDefaults.standard.set(keywordData, forKey: deepgramKeywordsKey)
    }
    
    private func loadDeepgramKeywords() {
        guard let keywordData = UserDefaults.standard.data(forKey: deepgramKeywordsKey),
              let keywords = try? JSONDecoder().decode([String].self, from: keywordData) else {
            deepgramKeywords = []
            return
        }
        deepgramKeywords = keywords
    }
}
