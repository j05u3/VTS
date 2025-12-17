import Foundation
import AppKit
import Combine

@MainActor
public class StreamingTranscriptionService: ObservableObject {
    // MARK: - Constants

    /// Inactivity timeout: auto-finalize if no new text for this duration
    private static let inactivityTimeoutSeconds: TimeInterval = 30.0

    private enum LogMessages {
        static let startingTranscription = "🎙️ StreamingTranscriptionService: Starting streaming transcription with provider:"
        static let configValidated = "🎙️ StreamingTranscriptionService: Provider config validated"
        static let sessionEstablished = "🎙️ StreamingTranscriptionService: Real-time session established"
        static let receivedPartialResult = "🎙️ StreamingTranscriptionService: Received partial result:"
        static let receivedFinalResult = "🎙️ StreamingTranscriptionService: Received final result:"
        static let injectingText = "🚀 StreamingTranscriptionService: Injecting final text..."
        static let textInjectedSuccess = "✅ StreamingTranscriptionService: Text injected successfully:"
        static let noTextToInject = "⚠️ StreamingTranscriptionService: No text to inject (empty result)"
        static let transcriptionCompleted = "🎙️ StreamingTranscriptionService: Streaming transcription completed successfully"
        static let transcriptionError = "🎙️ StreamingTranscriptionService: Error during streaming transcription:"
        static let sessionCleanedUp = "🎙️ StreamingTranscriptionService: Session cleaned up"
        static let bufferConnectionEstablished = "🎙️ StreamingTranscriptionService: Audio buffer connection established"
        static let cannotTrackAnalytics = "⚠️ Cannot track streaming analytics: missing provider or config data"
        static let bufferedChunksReleased = "✅ StreamingTranscriptionService: Session confirmed - processing queued chunks"
    }
    
    // MARK: - Published Properties
    
    @Published public var currentText = ""
    @Published public var lastTranscription = ""
    @Published public var isTranscribing = false
    @Published public var error: STTError?
    
    // Real-time specific properties
    @Published public var partialResults: PartialResultsManager
    @Published public var isStreamingActive = false
    
    private var provider: StreamingSTTProvider?
    private var transcriptionTask: Task<Void, Never>?
    private var inactivityTimeoutTask: Task<Void, Never>?
    private let textInjector = TextInjector()
    private var cancellables = Set<AnyCancellable>()

    // Overlay window for displaying live transcription
    public let overlayWindow = TranscriptionOverlayWindow()
    
    // Session management
    private var currentSession: RealtimeSession?
    private let audioStreamingQueue = AudioStreamingQueue()
    
    // For retry functionality
    private var currentConfig: ProviderConfig?
    private var currentProviderType: STTProviderType?
    
    // Reference to notification manager
    private let notificationManager = NotificationManager.shared
    
    // Analytics completion callback
    public var onTranscriptionCompleted: ((String, String, Bool, Int, Int, Bool) -> Void)?

    // Restart callback - called when user clicks clear button to restart stream
    public var onRestartRequested: (() -> Void)?

    // Timing properties for analytics
    private var processStartTime: Date?
    private var audioRecordingStartTime: Date?
    private var audioRecordingEndTime: Date?
    private var processingStartTime: Date?
    private var processingEndTime: Date?

    public init() {
        partialResults = PartialResultsManager()
        setupTextInjectorObservation()
        setupOverlayCallbacks()
    }

    private func setupOverlayCallbacks() {
        // X button - cancel transcription without injecting text
        overlayWindow.onClose = { [weak self] in
            self?.cancelTranscription()
        }

        // Clear button - clear text and restart stream
        overlayWindow.onClear = { [weak self] in
            self?.onRestartRequested?()
        }

        // Finish button - finalize and inject text (same as hotkey)
        overlayWindow.onFinish = { [weak self] in
            self?.onFinishRequested?()
        }
    }

    /// Callback for finish button - AppState should stop recording and finalize
    public var onFinishRequested: (() -> Void)?

    /// Update the hotkey string displayed in the overlay
    public func setHotkeyString(_ hotkey: String) {
        overlayWindow.hotkeyString = hotkey
    }

    /// Update the audio level displayed in the overlay
    public func updateAudioLevel(_ level: Float) {
        overlayWindow.audioLevel = level
    }

    /// Update the connection state displayed in the overlay
    public func updateConnectionState(_ state: ConnectionState) {
        overlayWindow.connectionState = state
    }

    private func setupTextInjectorObservation() {
        // Bridge TextInjector changes to this ObservableObject
        textInjector.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    public var injector: TextInjector {
        return textInjector
    }
    
    public func setProvider(_ provider: StreamingSTTProvider) {
        self.provider = provider

        // Wire up connection state callback only for providers that support live overlay
        if provider.supportsLiveOverlay, let baseProvider = provider as? BaseStreamingSTTProvider {
            baseProvider.onConnectionStateChanged = { [weak self] state in
                Task { @MainActor in
                    self?.updateConnectionState(state)
                }
            }
        }
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
        config: ProviderConfig
    ) {
        guard let provider = provider else {
            error = STTError.transcriptionError("No streaming provider configured")
            return
        }
        
        transcriptionTask?.cancel()
        isTranscribing = true
        isStreamingActive = true
        error = nil
        currentText = ""

        // Store context for potential retry
        currentConfig = config
        currentProviderType = provider.providerType

        // Only show overlay and timeout for providers that support live overlay
        if provider.supportsLiveOverlay {
            overlayWindow.show()
            resetInactivityTimeout()
        }

        print("\(LogMessages.startingTranscription) \(provider.providerType)")
        
        transcriptionTask = Task { @MainActor in
            do {
                // Reset components for new session
                partialResults.reset()
                await audioStreamingQueue.reset()
                
                try provider.validateConfig(config)
                print(LogMessages.configValidated)
                
                // Mark when we start the actual transcription process
                startTranscriptionTiming()
                
                // Start the streaming transcription process
                try await processStreamingTranscription(
                    audioStream: audioStream,
                    provider: provider,
                    config: config
                )
                
                print(LogMessages.transcriptionCompleted)
                
            } catch {
                // Check if this was a cancellation (e.g., during restart) - don't treat as error
                if Task.isCancelled || error is CancellationError {
                    print("🎙️ StreamingTranscriptionService: Task was cancelled (likely restart)")
                    return
                }

                print("\(LogMessages.transcriptionError) \(error)")

                // Mark when transcription failed
                endTranscriptionTiming()

                let sttError = convertToSTTError(error)

                // Track analytics
                trackAnalytics(provider: provider, config: config, success: false)

                handleError(sttError)
            }
            
            // Note: UI state (isTranscribing, isStreamingActive) is updated immediately 
            // in startPartialResultsProcessor when final result is received
        }
    }
    
    public func stopTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        isTranscribing = false
        isStreamingActive = false

        // Only handle overlay cleanup if provider supports it
        if provider?.supportsLiveOverlay ?? false {
            cancelInactivityTimeout()
            overlayWindow.connectionState = .idle
            overlayWindow.hide()
        }

        // Cleanup current session if active
        if let session = currentSession {
            Task {
                await session.cleanup()
            }
            currentSession = nil
        }
    }
    
    // MARK: - Streaming Transcription Process
    
    private func processStreamingTranscription(
        audioStream: AsyncThrowingStream<Data, Error>,
        provider: StreamingSTTProvider,
        config: ProviderConfig
    ) async throws {
        
        // Step 1: Establish real-time session (without starting message listening yet)
        print("🎙️ StreamingTranscriptionService: Establishing real-time session...")
        let session = try await provider.startRealtimeSession(config: config)
        currentSession = session
        
        // Step 2: Set up session confirmation callback for providers that confirm asynchronously
        session.onSessionConfirmed = { [weak self] in
            Task {
                guard let self = self else { return }
                await self.audioStreamingQueue.confirmSession()
                print(LogMessages.bufferedChunksReleased)
            }
        }

        // Step 2b: For providers like Deepgram that confirm synchronously during startRealtimeSession,
        // the callback wasn't set yet when confirmSession() ran, so check and confirm now
        if session.isSessionConfirmed {
            print("🎙️ StreamingTranscriptionService: Session already confirmed, notifying audio queue")
            await audioStreamingQueue.confirmSession()
            print(LogMessages.bufferedChunksReleased)
        }

        // Step 3: Now start message listening with callback in place
        if let openAIProvider = provider as? OpenAIStreamingProvider {
            try await openAIProvider.startListening(for: session)
        }
        
        print(LogMessages.sessionEstablished)
        
        // Step 4: Configure the streaming queue with provider and session
        await audioStreamingQueue.configure(provider: provider, session: session)
        
        // Step 5: Start processing partial results
        startPartialResultsProcessor(session: session)
        
        // Step 6: Process audio stream through the sequential queue
        print("🎵 StreamingTranscriptionService: About to start processing audio stream...")
        try await processAudioStreamWithSequentialQueue(audioStream: audioStream)
        print("🎵 StreamingTranscriptionService: Audio stream processing completed")
        
        // Step 7: Finish transcription and trigger cleanup (text injection already handled by partial results)
        // Note: UI state and text injection are handled immediately in startPartialResultsProcessor
        // This just ensures cleanup happens for any remaining provider state
        
        print("🎙️ StreamingTranscriptionService: Main flow completing...")
        
        // Don't await this - cleanup happens in background from partial results processor
        let _ = try await provider.finishAndGetTranscription(session)
        
        print("🎙️ StreamingTranscriptionService: Main flow completed")
    }
    
    // MARK: - Background Cleanup
    
    private func performBackgroundCleanup(provider: StreamingSTTProvider?, config: ProviderConfig?) async {
        print("🧹 StreamingTranscriptionService: Starting background cleanup...")
        
        // Track analytics (using the partial results final transcript)
        await MainActor.run {
            trackAnalytics(provider: provider, config: config, success: true)
        }
        
        // Cleanup session
        await MainActor.run {
            currentSession = nil
        }
        
        print("🧹 StreamingTranscriptionService: Background cleanup completed")
    }
    
    private func processAudioStreamWithSequentialQueue(
        audioStream: AsyncThrowingStream<Data, Error>
    ) async throws {
        
        print("🎵 StreamingTranscriptionService: Starting to process audio stream...")
        var chunkCount = 0
        
        for try await audioChunk in audioStream {
            chunkCount += 1
            print("🎵 StreamingTranscriptionService: Processing audio chunk #\(chunkCount) (\(audioChunk.count) bytes)")
            
            // All chunks go through the actor-based sequential queue
            // The queue handles session confirmation and ordering automatically
            try await audioStreamingQueue.streamChunk(audioChunk)
        }
        
        print("🎵 StreamingTranscriptionService: Finished processing audio stream. Total chunks: \(chunkCount)")
    }
    
    private func startPartialResultsProcessor(session: RealtimeSession) {
        let usesOverlay = provider?.supportsLiveOverlay ?? false

        Task { @MainActor in
            do {
                for try await partialChunk in session.partialResultsStream {
                    // Process partial result through the manager
                    partialResults.processPartialResult(partialChunk)

                    if partialChunk.isFinal {
                        print("\(LogMessages.receivedFinalResult) '\(partialChunk.text)'")

                        // For non-overlay providers, inject text immediately on final result
                        if !usesOverlay {
                            let finalText = partialResults.getFinalTranscription()
                            if !finalText.isEmpty {
                                lastTranscription = finalText
                                print(LogMessages.injectingText)
                                textInjector.injectText(finalText)
                                print("\(LogMessages.textInjectedSuccess) '\(finalText)'")
                            }
                        }
                    } else {
                        print("\(LogMessages.receivedPartialResult) '\(partialChunk.text)'")
                    }

                    // Update overlay with current transcription (only if using overlay)
                    if usesOverlay {
                        let completeText = partialResults.getCompleteTranscription()
                        currentText = completeText
                        overlayWindow.updateText(completeText)

                        // Reset inactivity timeout whenever we receive new text
                        if !partialChunk.text.isEmpty {
                            resetInactivityTimeout()
                        }
                    }
                }

                // Stream ended
                if usesOverlay {
                    cancelInactivityTimeout()
                    print("🎙️ StreamingTranscriptionService: Partial results stream ended, waiting for user to finalize...")
                }
                endTranscriptionTiming()
                isTranscribing = false
                isStreamingActive = false

                // 🔄 BACKGROUND CLEANUP
                Task.detached { [weak self] in
                    await self?.performBackgroundCleanup(provider: self?.provider, config: self?.currentConfig)
                }
            } catch {
                print("StreamingTranscriptionService: Partial results processor ended with error: \(error)")
                // Handle the error properly - this prevents the overlay from getting stuck
                endTranscriptionTiming()
                isTranscribing = false
                isStreamingActive = false

                // Convert and handle the error to show notification and hide overlay
                let sttError = convertToSTTError(error)
                handleError(sttError)
            }
        }
    }

    /// Called when user presses hotkey to finalize transcription
    /// Hides overlay and injects text at cursor position
    public func finalizeTranscription() {
        let finalText = overlayWindow.finalizeAndHide()

        if !finalText.isEmpty {
            lastTranscription = finalText
            print(LogMessages.injectingText)
            textInjector.injectText(finalText)
            print("\(LogMessages.textInjectedSuccess) '\(finalText)'")
        } else {
            print(LogMessages.noTextToInject)
        }
    }

    /// Cancels transcription without injecting text
    public func cancelTranscription() {
        // stopTranscription handles overlay hiding
        stopTranscription()
    }

    // MARK: - Inactivity Timeout

    /// Configurable timeout duration (can be set from AppState/settings)
    public var inactivityTimeout: TimeInterval = StreamingTranscriptionService.inactivityTimeoutSeconds

    /// Starts or restarts the inactivity timeout timer
    /// Called whenever new text is received to reset the countdown
    private func resetInactivityTimeout() {
        // Cancel existing timeout
        inactivityTimeoutTask?.cancel()

        // Don't start timeout if not actively streaming or if timeout is disabled
        guard isStreamingActive, inactivityTimeout > 0 else {
            overlayWindow.inactivityTimeoutProgress = 1.0
            return
        }

        // Reset progress to full
        overlayWindow.inactivityTimeoutProgress = 1.0

        // Start new timeout with progress tracking
        let timeoutDuration = inactivityTimeout
        let updateInterval: TimeInterval = 0.5 // Update progress every 500ms
        let startTime = Date()

        inactivityTimeoutTask = Task { @MainActor [weak self] in
            do {
                while true {
                    try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))

                    guard let self = self, self.isStreamingActive else { return }

                    let elapsed = Date().timeIntervalSince(startTime)
                    let remaining = timeoutDuration - elapsed
                    let progress = max(0, remaining / timeoutDuration)

                    self.overlayWindow.inactivityTimeoutProgress = progress

                    if remaining <= 0 {
                        // Set progress to exactly 0
                        self.overlayWindow.inactivityTimeoutProgress = 0

                        // Audio-aware grace period: wait until we're confident there's no active speech
                        // Check audio level every 50ms - only auto-stop if audio stays quiet
                        let audioThreshold: Float = 0.02  // Above this = speech detected
                        let quietDurationRequired: TimeInterval = 0.8  // Need 800ms of quiet to confirm no speech
                        var quietDuration: TimeInterval = 0
                        let checkInterval: TimeInterval = 0.05  // 50ms

                        while quietDuration < quietDurationRequired {
                            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))

                            // Check if still active (task may have been cancelled by new speech)
                            guard self.isStreamingActive else { return }

                            let currentAudioLevel = self.overlayWindow.audioLevel
                            if currentAudioLevel > audioThreshold {
                                // Speech detected - reset quiet duration and keep waiting
                                quietDuration = 0
                                print("⏰ Audio detected during grace period (level: \(currentAudioLevel)), waiting for transcription...")
                            } else {
                                quietDuration += checkInterval
                            }
                        }

                        // Confirmed quiet for required duration - safe to auto-stop
                        guard self.isStreamingActive else { return }

                        print("⏰ StreamingTranscriptionService: Inactivity timeout (\(timeoutDuration)s) - auto-finalizing (confirmed quiet)")
                        self.onAutoStopRequested?()
                        return
                    }
                }
            } catch {
                // Task was cancelled - this is expected when text is received
            }
        }
    }

    /// Cancels the inactivity timeout (called when streaming stops)
    private func cancelInactivityTimeout() {
        inactivityTimeoutTask?.cancel()
        inactivityTimeoutTask = nil
        overlayWindow.inactivityTimeoutProgress = 1.0
    }

    /// Callback for auto-stop due to inactivity - AppState should stop recording
    public var onAutoStopRequested: (() -> Void)?

    private func handleError(_ error: STTError) {
        self.error = error
        isTranscribing = false
        isStreamingActive = false

        // Hide overlay window on error
        overlayWindow.hide()

        // Stop terminal dictation monitoring
        textInjector.stopDictationSession()

        // Show notification for the error
        notificationManager.showTranscriptionError(error)
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
    
    private func trackAnalytics(provider: StreamingSTTProvider?, config: ProviderConfig?, success: Bool, providerType: STTProviderType? = nil) {
        guard let onCompletion = onTranscriptionCompleted, let config = config else { return }

        guard let providerName = provider?.providerType.rawValue ?? providerType?.rawValue else {
            print(LogMessages.cannotTrackAnalytics)
            return
        }

        let processingTimeMs = calculateProcessingTime()
        let audioDurationMs = calculateAudioDuration()

        // Keep provider name clean, use isRealtime parameter to differentiate
        onCompletion(
            providerName,
            config.model,
            success,
            audioDurationMs,
            processingTimeMs,
            true  // isRealtime = true for streaming service
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
    
    // MARK: - Error Conversion Helper
    
    private func convertToSTTError(_ error: Error) -> STTError {
        if let sttError = error as? STTError {
            return sttError
        }
        
        if let streamingError = error as? StreamingError {
            switch streamingError {
            case .connectionFailed(let message):
                return STTError.networkError(message)
            case .sessionError(let message):
                // Check for specific OpenAI prompt length error
                if message.contains("string too long") && message.contains("prompt") {
                    return STTError.transcriptionError("System prompt too long")
                }
                return STTError.transcriptionError(message)
            case .audioStreamError(let message):
                return STTError.audioProcessingError(message)
            case .invalidConfiguration(let message):
                return STTError.invalidModel
            case .partialResultsError(let message):
                return STTError.transcriptionError(message)
            }
        }
        
        return STTError.transcriptionError(error.localizedDescription)
    }
}