import Foundation
import AppKit
import Combine

@MainActor
public class TranscriptionService: ObservableObject {
    @Published public var currentText = ""
    @Published public var lastTranscription = ""
    @Published public var isTranscribing = false
    @Published public var error: STTError?
    
    private var provider: STTProvider?
    private var transcriptionTask: Task<Void, Never>?
    private let textInjector = TextInjector()
    private var lastInjectedText = ""
    private var cancellables = Set<AnyCancellable>()
    
    // For retry functionality
    private var currentAudioData: Data?
    private var currentConfig: ProviderConfig?
    private var currentProviderType: STTProviderType?
    
    // Reference to notification manager
    private let notificationManager = NotificationManager.shared
    
    public init() {
        setupTextInjectorObservation()
        setupNotificationHandlers()
    }
    
    private func setupTextInjectorObservation() {
        // Bridge TextInjector changes to this ObservableObject
        textInjector.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationHandlers() {
        // Handle retry requests from notifications
        notificationManager.onRetryRequested = { [weak self] retryContext in
            Task { @MainActor in
                self?.handleRetryRequest(retryContext)
            }
        }
    }
    
    public var injector: TextInjector {
        return textInjector
    }
    
    public func setProvider(_ provider: STTProvider) {
        self.provider = provider
    }
    
    public func startTranscription(
        audioStream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig,
        streamPartials: Bool = true
    ) {
        guard let provider = provider else {
            error = STTError.transcriptionError("No provider configured")
            return
        }
        
        transcriptionTask?.cancel()
        isTranscribing = true
        error = nil
        currentText = ""
        lastInjectedText = ""
        
        // Store context for potential retry
        currentConfig = config
        currentProviderType = provider.providerType
        
        print("🎙️ TranscriptionService: Starting transcription with provider: \(provider.providerType)")
        
        transcriptionTask = Task { @MainActor in
            do {
                try provider.validateConfig(config)
                print("🎙️ TranscriptionService: Provider config validated")
                
                // Collect audio data while transcribing for potential retry
                let (collectedData, transcriptionResult) = try await collectAudioAndTranscribe(
                    stream: audioStream,
                    provider: provider,
                    config: config
                )
                
                // Store audio data for potential retry
                self.currentAudioData = collectedData
                
                print("🎙️ TranscriptionService: Received transcription result: '\(transcriptionResult)'")
                
                // Trim whitespace
                let finalText = transcriptionResult.trimmingCharacters(in: .whitespaces)
                print("🎙️ TranscriptionService: Final text after trimming: '\(finalText)'")
                
                // Update UI
                currentText = finalText
                
                // Store as last transcription if we have content
                if !finalText.isEmpty {
                    lastTranscription = finalText
                }
                
                // Inject the text if we have any
                if !finalText.isEmpty {
                    print("🚀 TranscriptionService: Injecting final text...")
                    
                    // Replace previous text if any
                    let replaceText = lastInjectedText.isEmpty ? nil : lastInjectedText
                    print("🎙️ TranscriptionService: Previous text to replace: '\(lastInjectedText)'")
                    
                    textInjector.injectText(finalText, replaceLastText: replaceText)
                    lastInjectedText = finalText
                    
                    print("✅ TranscriptionService: Text injected successfully: '\(finalText)'")
                } else {
                    print("⚠️ TranscriptionService: No text to inject (empty result)")
                }
                
                print("🎙️ TranscriptionService: Transcription completed successfully")
                
                // Clear retry context on success
                clearRetryContext()
                
            } catch {
                print("🎙️ TranscriptionService: Error during transcription: \(error)")
                let sttError = error as? STTError ?? STTError.transcriptionError(error.localizedDescription)
                handleErrorWithNotification(sttError)
            }
            
            isTranscribing = false
        }
    }
    
    public func stopTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        isTranscribing = false
    }
    
    private func handleError(_ error: STTError) {
        self.error = error
        isTranscribing = false
    }
    
    // MARK: - Audio Collection and Transcription
    
    private func collectAudioAndTranscribe(
        stream: AsyncThrowingStream<Data, Error>,
        provider: STTProvider,
        config: ProviderConfig
    ) async throws -> (Data, String) {
        var audioData = Data()
        
        // Create a new stream that collects data while passing it through
        let (collectingStream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        
        // Collect audio data in background task
        let collectionTask = Task {
            for try await chunk in stream {
                audioData.append(chunk)
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        
        // Perform transcription with the collecting stream
        print("🎙️ TranscriptionService: Calling provider.transcribe()...")
        let result = try await provider.transcribe(stream: collectingStream, config: config)
        
        // Wait for collection to complete
        try await collectionTask.value
        
        return (audioData, result)
    }
    
    // MARK: - Error Handling with Notifications
    
    private func handleErrorWithNotification(_ error: STTError) {
        self.error = error
        isTranscribing = false
        
        // Create retry context if we have the necessary data
        var retryContext: RetryContext? = nil
        if let audioData = currentAudioData,
           let config = currentConfig,
           let providerType = currentProviderType {
            retryContext = RetryContext(
                audioData: audioData,
                config: config,
                originalError: error,
                providerType: providerType
            )
            print("🔔 Created retry context: \(retryContext!.description)")
        } else {
            print("🔔 Cannot create retry context - missing data")
        }
        
        // Show notification
        notificationManager.showTranscriptionError(error, retryContext: retryContext)
    }
    
    // MARK: - Retry Functionality
    
    private func handleRetryRequest(_ retryContext: RetryContext) {
        guard retryContext.isValid else {
            print("🔔 Retry context is too old, ignoring retry request")
            return
        }
        
        guard !isTranscribing else {
            print("🔔 Already transcribing, ignoring retry request")
            return
        }
        
        print("🔔 Handling retry request: \(retryContext.description)")
        
        // Create audio stream from stored data
        let audioStream = createStreamFromData(retryContext.audioData)
        
        // Retry transcription
        startTranscriptionFromRetry(
            audioStream: audioStream,
            config: retryContext.config,
            providerType: retryContext.providerType
        )
    }
    
    private func startTranscriptionFromRetry(
        audioStream: AsyncThrowingStream<Data, Error>,
        config: ProviderConfig,
        providerType: STTProviderType
    ) {
        // Find the provider for the retry
        guard let provider = provider, provider.providerType == providerType else {
            print("🔔 Provider mismatch for retry, ignoring")
            return
        }
        
        print("🔔 Starting retry transcription with \(providerType.rawValue)")
        
        // Store context
        currentConfig = config
        currentProviderType = providerType
        
        transcriptionTask?.cancel()
        isTranscribing = true
        error = nil
        currentText = ""
        
        transcriptionTask = Task { @MainActor in
            do {
                try provider.validateConfig(config)
                let transcriptionResult = try await provider.transcribe(stream: audioStream, config: config)
                
                let finalText = transcriptionResult.trimmingCharacters(in: .whitespaces)
                currentText = finalText
                
                if !finalText.isEmpty {
                    lastTranscription = finalText
                    
                    let replaceText = lastInjectedText.isEmpty ? nil : lastInjectedText
                    textInjector.injectText(finalText, replaceLastText: replaceText)
                    lastInjectedText = finalText
                    
                    print("✅ Retry transcription successful: '\(finalText)'")
                } else {
                    print("⚠️ Retry transcription returned empty result")
                }
                
                clearRetryContext()
                
            } catch {
                print("🔔 Retry transcription failed: \(error)")
                let sttError = error as? STTError ?? STTError.transcriptionError(error.localizedDescription)
                handleErrorWithNotification(sttError)
            }
            
            isTranscribing = false
        }
    }
    
    private func createStreamFromData(_ data: Data) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield(data)
            continuation.finish()
        }
    }
    
    private func clearRetryContext() {
        currentAudioData = nil
        currentConfig = nil
        currentProviderType = nil
    }
    
    public func copyLastTranscriptionToClipboard() -> Bool {
        guard !lastTranscription.isEmpty else {
            return false
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastTranscription, forType: .string)
        return true
    }
}