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
        
        print("🎵 AudioStreamingQueue: Received chunk #\(sequenceNumber) (\(data.count) bytes) - Session confirmed: \(isSessionConfirmed)")
        
        // Only start processing if not already running
        if !isProcessing {
            print("🔄 AudioStreamingQueue: Starting chunk processing...")
            isProcessing = true
            await processAllChunks()
        } else {
            print("⏳ AudioStreamingQueue: Processing already in progress, chunk queued")
        }
    }
    
    /// Marks the session as confirmed and continues processing
    func confirmSession() async {
        isSessionConfirmed = true
        print("✅ AudioStreamingQueue: Session confirmed! Pending chunks: \(pendingChunks.count)")
        
        // If we have pending chunks and not currently processing, start processing
        if !pendingChunks.isEmpty && !isProcessing {
            print("🔄 AudioStreamingQueue: Starting processing of pending chunks after session confirmation")
            isProcessing = true
            await processAllChunks()
        }
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
        
        print("🔄 AudioStreamingQueue: Starting to process \(pendingChunks.count) pending chunks (session confirmed: \(isSessionConfirmed))")
        
        while true {
            // Process all current chunks that are ready
            while !pendingChunks.isEmpty && isSessionConfirmed {
                let chunk = pendingChunks.removeFirst()
                
                print("📤 AudioStreamingQueue: Processing chunk (\(chunk.count) bytes) - \(pendingChunks.count) remaining")
                
                do {
                    try await provider.streamAudio(chunk, to: session)
                    print("✅ AudioStreamingQueue: Successfully streamed chunk (\(chunk.count) bytes) - seq: \(sequenceNumber)")
                } catch {
                    print("❌ AudioStreamingQueue: Error streaming chunk: \(error)")
                    // Continue processing other chunks even if one fails
                }
            }
            
            // Show waiting status if chunks are pending but session not confirmed
            if !pendingChunks.isEmpty && !isSessionConfirmed {
                print("⏳ AudioStreamingQueue: \(pendingChunks.count) chunks waiting for session confirmation")
            }
            
            // Double-check pattern: mark as not processing and check again
            isProcessing = false
            
            // If new chunks arrived while we were processing, or session became confirmed, restart
            if !pendingChunks.isEmpty && isSessionConfirmed {
                print("🔄 AudioStreamingQueue: Restarting processing due to new chunks or session confirmation")
                isProcessing = true
                continue  // Go back to processing loop
            }
            
            // Truly done - no new chunks arrived or session not ready
            print("✅ AudioStreamingQueue: Processing complete")
            break
        }
    }
}
