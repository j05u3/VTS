import Foundation
import Combine

@MainActor
public class StreamingTranscriptionService: ObservableObject {
    @Published public var partialTranscript = ""
    @Published public var isTranscribing = false
    @Published public var error: STTError?

    private var streamingTask: Task<Void, Never>?
    private var provider: StreamingSTTProvider?
    private var session: RealtimeSession?

    public func setProvider(_ provider: StreamingSTTProvider) {
        self.provider = provider
    }

    public func startTranscription(config: ProviderConfig, audioStream: AsyncThrowingStream<Data, Error>) {
        guard let provider = provider else {
            self.error = .transcriptionError("No provider configured")
            return
        }

        stopTranscription()
        isTranscribing = true
        error = nil
        partialTranscript = ""

        streamingTask = Task {
            do {
                let session = try await provider.startRealtimeSession(config: config)
                self.session = session

                // Task to stream audio
                let streamAudioTask = Task {
                    for try await audioData in audioStream {
                        try await provider.streamAudio(audioData, to: session)
                    }
                }

                // Task to handle results
                for try await chunk in session.partialResultsStream {
                    if chunk.isFinal {
                        partialTranscript = chunk.text
                    } else {
                        partialTranscript += chunk.text
                    }
                }
                
                // Wait for audio streaming to finish
                try await streamAudioTask.value

                // Get final transcription
                let finalTranscript = try await provider.finishAndGetTranscription(session)
                self.partialTranscript = finalTranscript
                
            } catch {
                self.error = error as? STTError ?? .transcriptionError(error.localizedDescription)
            }
            isTranscribing = false
        }
    }

    public func stopTranscription() {
        streamingTask?.cancel()
        session?.finish()
        session?.webSocket.cancel(with: .goingAway, reason: nil)
        isTranscribing = false
    }
}