import Foundation

class AudioBuffer {
    private var preConnectionBuffer: Data = Data()
    private let maxBufferSize: Int = 20 * 1024 * 1024 // 20MB max
    
    func bufferAudio(_ data: Data) {
        // Store audio while establishing connection
    }
    
    func flushToSession(_ session: RealtimeSession) async throws {
        // Send buffered audio once connected
    }
}
