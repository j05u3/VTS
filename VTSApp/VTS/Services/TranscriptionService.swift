import Foundation
import AppKit
import Combine

@MainActor
public class TranscriptionService: ObservableObject {
    @Published public var currentText = ""
    @Published public var lastTranscription = ""
    @Published public var isTranscribing = false
    @Published public var error: STTError?
    @Published public var partialResults: [String] = [] // New: for streaming partial results
    
    private var provider: (any STTProvider)?
    private var transcriptionTask: Task<Void, Never>?
    private let textInjector = TextInjector()
    private var lastInjectedText = ""
    private var cancellables = Set<AnyCancellable>()
    
    // Streaming configuration
    private var useStreamingMode = true
    private var partialResultsEnabled = true
    
    public init() {
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
    
    public func setProvider(_ provider: any STTProvider) {
        self.provider = provider
    }
    
    public func enableStreamingMode(_ enabled: Bool) {
        useStreamingMode = enabled
    }
    
    public func enablePartialResults(_ enabled: Bool) {
        partialResultsEnabled = enabled
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
        partialResults = []
        
        print("🎙️ TranscriptionService: Starting transcription with provider: \(provider.providerType)")
        
        transcriptionTask = Task { @MainActor in
            do {
                try provider.validateConfig(config)
                print("🎙️ TranscriptionService: Provider config validated")
                
                let finalResult: String
                
                // Use streaming if provider supports it and streaming is enabled
                if useStreamingMode, let streamingProvider = provider as? StreamingSTTProvider {
                    print("🎙️ TranscriptionService: Using streaming transcription...")
                    
                    finalResult = try await streamingProvider.transcribeStreaming(
                        stream: audioStream,
                        config: config,
                        onPartialResult: { [weak self] partialText in
                            Task { @MainActor in
                                self?.handlePartialResult(partialText)
                            }
                        }
                    )
                } else {
                    print("🎙️ TranscriptionService: Using batch transcription...")
                    finalResult = try await provider.transcribe(stream: audioStream, config: config)
                }
                
                print("🎙️ TranscriptionService: Received final result: '\(finalResult)'")
                
                // Process final result
                await handleFinalResult(finalResult)
                
            } catch {
                print("🎙️ TranscriptionService: Error during transcription: \(error)")
                handleError(STTError.transcriptionError(error.localizedDescription))
            }
            
            isTranscribing = false
        }
    }
    
    private func handlePartialResult(_ partialText: String) {
        guard partialResultsEnabled else { return }
        
        let trimmedText = partialText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        
        print("📝 TranscriptionService: Partial result: '\(trimmedText)'")
        
        // Update UI with partial results
        partialResults.append(trimmedText)
        currentText = partialResults.joined(separator: " ")
        
        // NOTE: Partial text injection is disabled to prevent text interference
        // Only final results will be injected to avoid messy partial updates
        print("📝 TranscriptionService: Partial result stored in memory only")
    }
    
    private func handleFinalResult(_ finalText: String) {
        let trimmedFinalText = finalText.trimmingCharacters(in: .whitespaces)
        print("🎙️ TranscriptionService: Final text after trimming: '\(trimmedFinalText)'")
        
        // Update UI with final result
        currentText = trimmedFinalText
        
        // Store as last transcription if we have content
        if !trimmedFinalText.isEmpty {
            lastTranscription = trimmedFinalText
        }
        
        // Inject the final text (partial results are not injected, so no replacement needed)
        if !trimmedFinalText.isEmpty {
            print("🚀 TranscriptionService: Injecting final text...")
            
            textInjector.injectText(trimmedFinalText, replaceLastText: nil)
            lastInjectedText = trimmedFinalText
            
            print("✅ TranscriptionService: Text injected successfully: '\(trimmedFinalText)'")
        } else {
            print("⚠️ TranscriptionService: No text to inject (empty result)")
        }
        
        // Clear partial results now that we have final result
        partialResults = []
        
        print("🎙️ TranscriptionService: Transcription completed successfully")
    }
    
    public func stopTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        isTranscribing = false
        partialResults = []
    }
    
    private func handleError(_ error: STTError) {
        self.error = error
        isTranscribing = false
        partialResults = []
        
        // Show user-friendly error messages
        switch error {
        case .networkError(let message):
            if message.contains("timed out") || message.contains("timeout") {
                print("💡 TranscriptionService: Network timeout detected - consider using shorter recordings or checking internet connection")
            }
        default:
            break
        }
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
    
    // MARK: - Configuration Getters
    public var isStreamingModeEnabled: Bool {
        return useStreamingMode
    }
    
    public var isPartialResultsEnabled: Bool {
        return partialResultsEnabled
    }
    
    public var hasStreamingCapability: Bool {
        return provider is StreamingSTTProvider
    }
}