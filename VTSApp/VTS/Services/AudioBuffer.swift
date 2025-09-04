import Foundation

public class AudioBuffer {
    private var preConnectionBuffer: Data = Data()
    private let maxBufferSize: Int = 20 * 1024 * 1024 // 20MB max
    private var isConnected: Bool = false
    private let bufferLock = NSLock()
    
    public init() {}
    
    /// Buffers audio data if connection is not established, or passes it through if connected
    public func handleAudioChunk(_ data: Data) -> Data? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        if isConnected {
            // Connection is established, return data for immediate streaming
            return data
        } else {
            // Buffer the data while waiting for connection
            preConnectionBuffer.append(data)
            
            // Trim buffer if it exceeds maximum size
            if preConnectionBuffer.count > maxBufferSize {
                let excess = preConnectionBuffer.count - maxBufferSize
                preConnectionBuffer.removeFirst(excess)
                print("AudioBuffer: Trimmed \(excess) bytes from buffer to stay within \(maxBufferSize) byte limit")
            }
            
            // Return nil to indicate data was buffered
            return nil
        }
    }
    
    /// Marks connection as established and returns all buffered data
    public func onConnectionEstablished() -> Data {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        isConnected = true
        let bufferedData = preConnectionBuffer
        preConnectionBuffer.removeAll()
        
        print("AudioBuffer: Connection established, returning \(bufferedData.count) bytes of buffered audio")
        return bufferedData
    }
    
    /// Resets the buffer for a new session
    public func reset() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        isConnected = false
        preConnectionBuffer.removeAll()
        print("AudioBuffer: Reset for new session")
    }
    
    /// Returns current buffer size for monitoring
    public var currentBufferSize: Int {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return preConnectionBuffer.count
    }
    
    /// Returns connection status
    public var connectionEstablished: Bool {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return isConnected
    }
    
    /// Splits large data into smaller chunks suitable for streaming
    public static func chunkAudioData(_ data: Data, chunkSize: Int = 1024) -> [Data] {
        guard !data.isEmpty else { return [] }
        
        var chunks: [Data] = []
        var offset = 0
        
        while offset < data.count {
            let remainingBytes = data.count - offset
            let currentChunkSize = min(chunkSize, remainingBytes)
            
            let chunk = data.subdata(in: offset..<(offset + currentChunkSize))
            chunks.append(chunk)
            offset += currentChunkSize
        }
        
        return chunks
    }
}