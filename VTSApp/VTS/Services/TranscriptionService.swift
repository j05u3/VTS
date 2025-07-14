import Foundation
import Combine

@MainActor
public class TranscriptionService: ObservableObject {
    @Published public var currentText = ""
    @Published public var isTranscribing = false
    @Published public var error: STTError?
    
    private var provider: STTProvider?
    private var transcriptionTask: Task<Void, Never>?
    private var partialResults: [TranscriptionChunk] = []
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
        partialResults = []
        lastInjectedText = ""
        
        transcriptionTask = Task { @MainActor in
            do {
                try provider.validateConfig(config)
                let transcriptionStream = try await provider.transcribe(stream: audioStream, config: config)
                
                for await chunk in transcriptionStream {
                    handleTranscriptionChunk(chunk, streamPartials: streamPartials)
                }
            } catch {
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
    
    private func handleTranscriptionChunk(_ chunk: TranscriptionChunk, streamPartials: Bool) {
        print("Received transcription chunk: '\(chunk.text)', isFinal: \(chunk.isFinal)")
        
        if chunk.isFinal {
            // Replace partial results with final text
            let finalText = mergeFinalChunk(chunk)
            currentText = finalText
            partialResults.removeAll()
            print("Updated current text to: '\(finalText)'")
            
            // Inject the new text at cursor location
            let newText = chunk.text.trimmingCharacters(in: .whitespaces)
            if !newText.isEmpty {
                // If we have previous injected text, replace it
                let replaceText = lastInjectedText.isEmpty ? nil : lastInjectedText
                textInjector.injectText(newText, replaceLastText: replaceText)
                lastInjectedText = newText
                print("Injected text: '\(newText)'")
            }
        } else if streamPartials {
            // Update partial results
            partialResults.append(chunk)
            currentText = mergePartialResults()
            print("Updated partial text to: '\(currentText)'")
        }
    }
    
    private func mergeFinalChunk(_ finalChunk: TranscriptionChunk) -> String {
        let existingFinalText = currentText.trimmingCharacters(in: .whitespaces)
        let newText = finalChunk.text.trimmingCharacters(in: .whitespaces)
        
        if existingFinalText.isEmpty {
            return newText
        } else {
            return existingFinalText + " " + newText
        }
    }
    
    private func mergePartialResults() -> String {
        let partialText = partialResults
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        
        let existingFinalText = currentText.trimmingCharacters(in: .whitespaces)
        
        if existingFinalText.isEmpty {
            return partialText
        } else {
            return existingFinalText + " " + partialText
        }
    }
    
    private func handleError(_ error: STTError) {
        self.error = error
        isTranscribing = false
    }
}