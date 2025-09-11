import Foundation
import AppKit
import Combine

@MainActor
public class StreamingTranscriptionService: ObservableObject {
    // MARK: - Constants
    
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
        static let bufferedChunksReleased = "� StreamingTranscriptionService: Session confirmed - processing queued chunks"
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
    private let textInjector = TextInjector()
    private var cancellables = Set<AnyCancellable>()
    
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
    
    // Timing properties for analytics
    private var processStartTime: Date?
    private var audioRecordingStartTime: Date?
    private var audioRecordingEndTime: Date?
    private var processingStartTime: Date?
    private var processingEndTime: Date?
    
    public init() {
        partialResults = PartialResultsManager()
        setupTextInjectorObservation()
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
        
        // Step 2: Set up session confirmation callback BEFORE starting message listening
        session.onSessionConfirmed = { [weak self] in
            Task {
                guard let self = self else { return }
                await self.audioStreamingQueue.confirmSession()
                print(LogMessages.bufferedChunksReleased)
            }
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
        Task { @MainActor in
            do {
                for try await partialChunk in session.partialResultsStream {
                    // Process partial result through the manager
                    partialResults.processPartialResult(partialChunk)
                    
                    if partialChunk.isFinal {
                        print("\(LogMessages.receivedFinalResult) '\(partialChunk.text)'")
                        
                        // 🚀 IMMEDIATE TEXT INJECTION: Handle text injection as soon as we get final result
                        let finalTranscript = partialResults.getFinalTranscription()
                        if !finalTranscript.isEmpty {
                            handleSuccessfulTranscription(finalTranscript)
                            
                            // Mark timing completion immediately 
                            endTranscriptionTiming()
                            
                            // 🎯 IMMEDIATE UI UPDATE: Update transcription state immediately after text injection
                            isTranscribing = false
                            isStreamingActive = false
                            
                            // 🔄 BACKGROUND CLEANUP: Start final cleanup and analytics in background
                            Task.detached { [weak self] in
                                await self?.performBackgroundCleanup(provider: self?.provider, config: self?.currentConfig)
                            }
                        }
                    } else {
                        print("\(LogMessages.receivedPartialResult) '\(partialChunk.text)'")
                    }
                    
                    // Update current text with complete transcription for display
                    currentText = partialResults.getCompleteTranscription()
                }
            } catch {
                print("StreamingTranscriptionService: Partial results processor ended: \(error)")
            }
        }
    }
    
    private func handleSuccessfulTranscription(_ finalText: String) {
        // Get the final transcript from partial results manager
        let processedFinalText = partialResults.getFinalTranscription()
        let textToInject = processedFinalText.isEmpty ? finalText.trimmingCharacters(in: .whitespaces) : processedFinalText
        
        // Update UI
        currentText = textToInject
        
        // Store as last transcription if we have content
        if !textToInject.isEmpty {
            lastTranscription = textToInject
            
            print(LogMessages.injectingText)
            
            textInjector.injectText(textToInject)
            
            print("\(LogMessages.textInjectedSuccess) '\(textToInject)'")
        } else {
            print(LogMessages.noTextToInject)
        }
    }
    
    private func handleError(_ error: STTError) {
        self.error = error
        isTranscribing = false
        isStreamingActive = false
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