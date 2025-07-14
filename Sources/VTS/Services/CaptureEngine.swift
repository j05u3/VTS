import AVFoundation
import Foundation

@MainActor
public class CaptureEngine: ObservableObject {
    @Published public var isRecording = false
    @Published public var audioLevel: Float = 0.0
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    
    private let sampleRate: Double = 16000
    private let channelCount: UInt32 = 1
    
    public init() {}
    
    public func start(deviceID: String? = nil) throws -> AsyncThrowingStream<Data, Error> {
        guard !isRecording else {
            throw STTError.audioProcessingError("Already recording")
        }
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let inputNode = engine.inputNode
        self.inputNode = inputNode
        
        // Configure audio format for 16kHz mono
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw STTError.audioProcessingError("Failed to create audio format")
        }
        self.audioFormat = audioFormat
        
        // Create audio stream
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        self.continuation = continuation
        
        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
            }
        }
        
        // Start the engine
        try engine.start()
        isRecording = true
        
        return stream
    }
    
    public func stop() {
        guard isRecording else { return }
        
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        continuation?.finish()
        
        audioEngine = nil
        inputNode = nil
        audioFormat = nil
        continuation = nil
        isRecording = false
        audioLevel = 0.0
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.int16ChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        let data = Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
        
        // Calculate audio level for visual feedback
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        let sum = samples.reduce(0) { $0 + abs(Int32($1)) }
        let average = Float(sum) / Float(frameLength)
        audioLevel = min(average / 32767.0, 1.0)
        
        continuation?.yield(data)
    }
}