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
    
    public init() {}
    
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
        
        transcriptionTask = Task {
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
        if chunk.isFinal {
            // Replace partial results with final text
            let finalText = mergeFinalChunk(chunk)
            currentText = finalText
            partialResults.removeAll()
        } else if streamPartials {
            // Update partial results
            partialResults.append(chunk)
            currentText = mergePartialResults()
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