import SwiftUI
import KeyboardShortcuts
import KeychainAccess
import Combine

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

// MARK: - API Key Management

@MainActor
public class APIKeyManager: ObservableObject {
    private let keychain: Keychain
    private let userDefaults = UserDefaults.standard
    
    // Keys for storing which provider/model is currently selected
    private let selectedProviderKey = "selectedProvider"
    private let selectedModelKey = "selectedModel"
    
    @Published public var availableKeys: [ProviderAPIKey] = []
    
    public init() {
        // Create keychain with app-specific service identifier
        keychain = Keychain(service: "com.vts.apikeys")
            .accessibility(.whenUnlocked)
        
        loadAvailableKeys()
    }
    
    // MARK: - API Key Management
    
    public func storeAPIKey(_ key: String, for provider: STTProviderType, label: String? = nil) throws {
        let keyIdentifier = createKeyIdentifier(provider: provider, label: label)
        
        try keychain.set(key, key: keyIdentifier)
        
        // Store metadata in UserDefaults
        var existingKeys = getStoredKeyMetadata()
        let newKey = ProviderAPIKey(
            id: keyIdentifier,
            provider: provider,
            label: label ?? provider.defaultLabel,
            createdAt: Date()
        )
        
        // Remove any existing key with the same identifier
        existingKeys.removeAll { $0.id == keyIdentifier }
        existingKeys.append(newKey)
        
        saveKeyMetadata(existingKeys)
        loadAvailableKeys()
    }
    
    public func getAPIKey(for provider: STTProviderType, label: String? = nil) throws -> String? {
        let keyIdentifier = createKeyIdentifier(provider: provider, label: label)
        return try keychain.get(keyIdentifier)
    }
    
    public func deleteAPIKey(withId keyId: String) throws {
        try keychain.remove(keyId)
        
        var existingKeys = getStoredKeyMetadata()
        existingKeys.removeAll { $0.id == keyId }
        saveKeyMetadata(existingKeys)
        loadAvailableKeys()
    }
    
    public func hasAPIKey(for provider: STTProviderType) -> Bool {
        return availableKeys.contains { $0.provider == provider }
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
    
    public func getCurrentAPIKey() throws -> String? {
        // Try to get the first available key for the selected provider
        let providerKeys = availableKeys.filter { $0.provider == selectedProvider }
        
        if let firstKey = providerKeys.first {
            return try keychain.get(firstKey.id)
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func createKeyIdentifier(provider: STTProviderType, label: String?) -> String {
        let labelPart = label ?? "default"
        return "\(provider.rawValue).\(labelPart)".lowercased()
    }
    
    private func loadAvailableKeys() {
        DispatchQueue.main.async {
            self.availableKeys = self.getStoredKeyMetadata().sorted { $0.createdAt < $1.createdAt }
        }
    }
    
    private func getStoredKeyMetadata() -> [ProviderAPIKey] {
        guard let data = userDefaults.data(forKey: "apiKeyMetadata"),
              let keys = try? JSONDecoder().decode([ProviderAPIKey].self, from: data) else {
            return []
        }
        return keys
    }
    
    private func saveKeyMetadata(_ keys: [ProviderAPIKey]) {
        if let data = try? JSONEncoder().encode(keys) {
            userDefaults.set(data, forKey: "apiKeyMetadata")
        }
    }
}

// MARK: - Supporting Types

public struct ProviderAPIKey: Codable, Identifiable {
    public let id: String
    public let provider: STTProviderType
    public let label: String
    public let createdAt: Date
    
    public var displayName: String {
        return "\(provider.rawValue) - \(label)"
    }
}

extension STTProviderType {
    var defaultLabel: String {
        switch self {
        case .openai:
            return "OpenAI Key"
        case .groq:
            return "Groq Key"
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
    private var cancellables = Set<AnyCancellable>()
    
    @Published var preferencesWindow: NSWindow?
    
    // Configuration state - now using APIKeyManager
    @Published var systemPrompt = ""
    @Published var isRecording = false
    @Published var apiKeysUpdateTrigger = 0 // Triggers UI updates when API keys change
    
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
    
    init() {
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
        // Check if we have an API key for the selected provider
        guard apiKeyManager.hasAPIKey(for: selectedProvider) else {
            print("No API key found for \(selectedProvider)")
            showAlert("Error", "Please add an API key for \(selectedProvider.rawValue) in preferences")
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
            
            // Get the API key securely from keychain
            guard let apiKey = try apiKeyManager.getCurrentAPIKey() else {
                print("Failed to retrieve API key from keychain")
                showAlert("Error", "Failed to retrieve API key. Please check your keychain access.")
                return
            }
            
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
        // Don't cancel transcription - let it finish processing the collected audio
        // transcriptionService.stopTranscription()  // Removed this line
        isRecording = false
        statusBarController.updateRecordingState(false)
        print("Recording stopped - transcription will continue processing")
    }
    
    func showPreferences() {
        if preferencesWindow == nil {
                    let preferencesView = PreferencesView(apiKeyManager: apiKeyManager)
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