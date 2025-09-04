import Foundation
import AppKit
import Combine

@MainActor
public class RestTranscriptionService: ObservableObject {
    // MARK: - Constants
    
    private enum LogMessages {
        static let startingTranscription = "🎙️ RestTranscriptionService: Starting transcription with provider:"
        static let configValidated = "🎙️ RestTranscriptionService: Provider config validated"
        static let receivedResult = "🎙️ RestTranscriptionService: Received transcription result:"
        static let finalTextTrimmed = "🎙️ RestTranscriptionService: Final text after trimming:"
        static let injectingText = "🚀 RestTranscriptionService: Injecting final text..."
        static let previousTextToReplace = "🎙️ RestTranscriptionService: Previous text to replace:"
        static let textInjectedSuccess = "✅ RestTranscriptionService: Text injected successfully:"
        static let noTextToInject = "⚠️ RestTranscriptionService: No text to inject (empty result)"
        static let transcriptionCompleted = "🎙️ RestTranscriptionService: Transcription completed successfully"
        static let transcriptionError = "🎙️ RestTranscriptionService: Error during transcription:"
        static let callingProvider = "🎙️ RestTranscriptionService: Calling provider.transcribe()..."
        static let retrySuccess = "✅ Retry transcription successful:"
        static let retryEmpty = "⚠️ Retry transcription returned empty result"
        static let retryFailed = "🔔 Retry transcription failed:"
        static let retryStarting = "🔔 Starting retry transcription with"
        static let cannotTrackAnalytics = "⚠️ Cannot track analytics: missing provider or config data"
    }
    
    // MARK: - Published Properties
    
    @Published public var currentText = ""
    @Published public var lastTranscription = ""
    @Published public var isTranscribing = false
    @Published public var error: STTError?
    
    private var provider: RestSTTProvider?
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
    
    // Analytics completion callback
    public var onTranscriptionCompleted: ((String, String, Bool, Int, Int) -> Void)?
    
    // Timing properties for analytics
    private var processStartTime: Date?           // When user first presses record button
    private var audioRecordingStartTime: Date?    // When audio recording actually starts
    private var audioRecordingEndTime: Date?      // When audio recording stops
    private var processingStartTime: Date?        // When processing starts (after audio recording ends)
    private var processingEndTime: Date?          // When we receive final result
    
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
    
    public func setProvider(_ provider: RestSTTProvider) {
        self.provider = provider
    }
    
    public func setTimingData(processStart: Date?, audioStart: Date?, audioEnd: Date?) {
        processStartTime = processStart
        audioRecordingStartTime = audioStart
        audioRecordingEndTime = audioEnd
        
        // Start processing timing when audio recording ends
        if let audioEnd = audioEnd {
            processingStartTime = audioEnd
        }
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
        
        print("\(LogMessages.startingTranscription) \(provider.providerType)")
        
        transcriptionTask = Task { @MainActor in
            do {
                try provider.validateConfig(config)
                print(LogMessages.configValidated)
                
                // Mark when we start the actual transcription process
                startTranscriptionTiming()
                
                // Collect audio data while transcribing for potential retry
                let (collectedData, transcriptionResult) = try await collectAudioAndTranscribe(
                    stream: audioStream,
                    provider: provider,
                    config: config
                )
                
                // Mark when transcription is complete
                endTranscriptionTiming()
                
                // Store audio data for potential retry
                self.currentAudioData = collectedData
                
                print("\(LogMessages.receivedResult) '\(transcriptionResult)'")
                
                // Trim whitespace
                let finalText = transcriptionResult.trimmingCharacters(in: .whitespaces)
                print("\(LogMessages.finalTextTrimmed) '\(finalText)'")
                
                // Update UI and inject text
                handleSuccessfulTranscription(finalText)
                
                print(LogMessages.transcriptionCompleted)
                
                // Track analytics
                trackAnalytics(provider: provider, config: config, success: true)
                
                // Clear retry context on success
                clearRetryContext()
                
            } catch {
                print("\(LogMessages.transcriptionError) \(error)")
                
                // Mark when transcription failed (for timing)
                endTranscriptionTiming()
                
                let sttError = error as? STTError ?? STTError.transcriptionError(error.localizedDescription)
                
                // Track analytics
                trackAnalytics(provider: provider, config: config, success: false)
                
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
    
    // MARK: - Helper Methods
    
    private func handleSuccessfulTranscription(_ finalText: String) {
        // Update UI
        currentText = finalText
        
        // Store as last transcription if we have content
        if !finalText.isEmpty {
            lastTranscription = finalText
            
            print(LogMessages.injectingText)
            
            // Replace previous text if any
            let replaceText = lastInjectedText.isEmpty ? nil : lastInjectedText
            print("\(LogMessages.previousTextToReplace) '\(lastInjectedText)'")
            
            textInjector.injectText(finalText, replaceLastText: replaceText)
            lastInjectedText = finalText
            
            print("\(LogMessages.textInjectedSuccess) '\(finalText)'")
        } else {
            print(LogMessages.noTextToInject)
        }
    }
    
    // MARK: - Audio Collection and Transcription
    
    private func collectAudioAndTranscribe(
        stream: AsyncThrowingStream<Data, Error>,
        provider: RestSTTProvider,
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
        print(LogMessages.callingProvider)
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
        
        print("\(LogMessages.retryStarting) \(providerType.rawValue)")
        
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
                
                // Mark when we start the retry transcription process
                startTranscriptionTiming()
                
                let transcriptionResult = try await provider.transcribe(stream: audioStream, config: config)
                
                // Mark when retry transcription is complete
                endTranscriptionTiming()
                
                let finalText = transcriptionResult.trimmingCharacters(in: .whitespaces)
                
                // Handle the successful transcription
                handleSuccessfulTranscription(finalText)
                
                let success = !finalText.isEmpty
                if success {
                    print("\(LogMessages.retrySuccess) '\(finalText)'")
                } else {
                    print(LogMessages.retryEmpty)
                }
                
                // Track analytics
                trackAnalytics(provider: nil, config: config, success: success, providerType: providerType)
                
                clearRetryContext()
                
            } catch {
                print("\(LogMessages.retryFailed) \(error)")
                
                // Mark when retry transcription failed (for timing)
                endTranscriptionTiming()
                
                // Track analytics
                trackAnalytics(provider: nil, config: config, success: false, providerType: providerType)
                
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
    
    // MARK: - Analytics Helper Methods
    
    private func startTranscriptionTiming() {
        // Processing timing is set when audio recording ends in setTimingData
        // This method is kept for compatibility but doesn't override processingStartTime
        if processingStartTime == nil {
            processingStartTime = Date()
        }
    }
    
    private func endTranscriptionTiming() {
        processingEndTime = Date()
    }
    
    private func trackAnalytics(provider: RestSTTProvider?, config: ProviderConfig?, success: Bool, providerType: STTProviderType? = nil) {
        guard let onCompletion = onTranscriptionCompleted, let config = config else { return }

        guard let providerName = provider?.providerType.rawValue ?? providerType?.rawValue else {
            print(LogMessages.cannotTrackAnalytics)
            return
        }

        let processingTimeMs = calculateProcessingTime()
        let audioDurationMs = calculateAudioDuration()

        onCompletion(
            providerName,
            config.model,
            success,
            audioDurationMs,
            processingTimeMs
        )
    }
    
    private func calculateProcessingTime() -> Int {
        guard let startTime = processingStartTime else { return 0 }
        let endTime = processingEndTime ?? Date()
        let timeInterval = endTime.timeIntervalSince(startTime)
        return Int(timeInterval * 1000) // Convert to milliseconds
    }
    
    private func calculateAudioDuration() -> Int {
        guard let startTime = audioRecordingStartTime,
              let endTime = audioRecordingEndTime else { return 0 }
        let timeInterval = endTime.timeIntervalSince(startTime)
        return Int(timeInterval * 1000) // Convert to milliseconds
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