import Foundation

/// Actor that ensures audio chunks are streamed in the correct order
/// while respecting session confirmation requirements
actor AudioStreamingQueue {
    
    // MARK: - Private Properties
    
    private var pendingChunks: [Data] = []
    private var isSessionConfirmed = false
    private var isProcessing = false
    private var sequenceNumber = 0
    
    // Provider and session for streaming
    private var provider: StreamingSTTProvider?
    private weak var session: RealtimeSession?
    
    // MARK: - Public Interface
    
    /// Sets up the streaming dependencies
    func configure(provider: StreamingSTTProvider, session: RealtimeSession) {
        self.provider = provider
        self.session = session
    }
    
    /// Streams an audio chunk through the sequential queue
    /// - Parameter data: The audio data chunk
    func streamChunk(_ data: Data) async throws {
        pendingChunks.append(data)
        sequenceNumber += 1
        
        // Only start processing if not already running
        if !isProcessing {
            isProcessing = true
            await processAllChunks()
        }
    }
    
    /// Marks the session as confirmed and continues processing
    func confirmSession() {
        isSessionConfirmed = true
        // Processing will automatically continue when the next chunk arrives
        // or if chunks are already pending, they'll be processed immediately
    }
    
    /// Resets the queue for a new session
    func reset() {
        pendingChunks.removeAll()
        isSessionConfirmed = false
        isProcessing = false
        sequenceNumber = 0
        provider = nil
        session = nil
    }
    
    /// Returns current queue statistics for debugging
    func getStats() -> (pendingCount: Int, sequenceNumber: Int, isConfirmed: Bool) {
        return (pendingChunks.count, sequenceNumber, isSessionConfirmed)
    }
    
    // MARK: - Private Processing
    
    /// Processes all pending chunks with double-check pattern to avoid race conditions
    private func processAllChunks() async {
        guard let provider = provider, let session = session else {
            print("⚠️ AudioStreamingQueue: Cannot process - missing provider or session")
            isProcessing = false
            return
        }
        
        while true {
            // Process all current chunks that are ready
            while !pendingChunks.isEmpty && isSessionConfirmed {
                let chunk = pendingChunks.removeFirst()
                
                do {
                    try await provider.streamAudio(chunk, to: session)
                    print("📡 AudioStreamingQueue: Streamed chunk (\(chunk.count) bytes) - seq: \(sequenceNumber)")
                } catch {
                    print("🎙️ AudioStreamingQueue: Error streaming chunk: \(error)")
                    // Continue processing other chunks even if one fails
                }
            }
            
            // Double-check pattern: mark as not processing and check again
            isProcessing = false
            
            // If new chunks arrived while we were processing, or session became confirmed, restart
            if !pendingChunks.isEmpty && isSessionConfirmed {
                isProcessing = true
                continue  // Go back to processing loop
            }
            
            // Truly done - no new chunks arrived or session not ready
            break
        }
    }
}
