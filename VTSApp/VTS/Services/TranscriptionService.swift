import Foundation
import Combine

@MainActor
public class TranscriptionService: ObservableObject {
    @Published public var currentText = ""
    @Published public var isTranscribing = false
    @Published public var error: STTError?
    
    private var provider: STTProvider?
    private var transcriptionTask: Task<Void, Never>?
    private let textInjector = TextInjector()
    private var lastInjectedText = ""
    private var cancellables = Set<AnyCancellable>()
    
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
        
        print("🎙️ TranscriptionService: Starting transcription with provider: \(provider.providerType)")
        
        transcriptionTask = Task { @MainActor in
            do {
                try provider.validateConfig(config)
                print("🎙️ TranscriptionService: Provider config validated")
                
                // Simplified: get the transcription result directly
                print("🎙️ TranscriptionService: Calling provider.transcribe()...")
                let transcriptionResult = try await provider.transcribe(stream: audioStream, config: config)
                print("🎙️ TranscriptionService: Received transcription result: '\(transcriptionResult)'")
                
                // Trim whitespace
                let finalText = transcriptionResult.trimmingCharacters(in: .whitespaces)
                print("🎙️ TranscriptionService: Final text after trimming: '\(finalText)'")
                
                // Update UI
                currentText = finalText
                
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
            } catch {
                print("🎙️ TranscriptionService: Error during transcription: \(error)")
                handleError(STTError.transcriptionError(error.localizedDescription))
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
}