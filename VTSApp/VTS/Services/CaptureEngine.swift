import AVFoundation
import Foundation
import CoreAudio

@MainActor
public class CaptureEngine: ObservableObject {
    @Published public var isRecording = false
    @Published public var audioLevel: Float = 0.0
    @Published public var permissionGranted = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var mixerNode: AVAudioMixerNode?
    private var audioFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    
    private let sampleRate: Double = 16000
    private let channelCount: UInt32 = 1
    
    // Throttling variables for reducing log frequency
    private var audioDataLogCounter = 0
    private var audioLevelLogCounter = 0
    private let audioDataLogInterval = 50  // Log every 50th audio data yield
    private let audioLevelLogInterval = 50  // Log every 50th audio level update
    
    public init() {
        checkMicrophonePermission()
    }
    
    private func checkMicrophonePermission() {
        // On macOS, we check microphone permissions differently
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            permissionGranted = true
        case .denied, .restricted:
            permissionGranted = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionGranted = granted
                }
            }
        @unknown default:
            permissionGranted = false
        }
    }
    
    public func start(deviceID: String? = nil) throws -> AsyncThrowingStream<Data, Error> {
        guard permissionGranted else {
            throw STTError.audioProcessingError("Microphone permission not granted")
        }
        
        guard !isRecording else {
            throw STTError.audioProcessingError("Already recording")
        }
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        // Set the preferred input device if specified
        if let deviceID = deviceID, deviceID != "default" {
            try setAudioInputDevice(deviceID: deviceID)
        }
        
        let inputNode = engine.inputNode
        self.inputNode = inputNode
        
        // Create a mixer node for built-in level monitoring
        let mixerNode = AVAudioMixerNode()
        self.mixerNode = mixerNode
        engine.attach(mixerNode)
        
        // Get the actual input format from the microphone
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("Input format: \(inputFormat)")
        
        // Configure our desired output format for 16kHz mono Int16
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw STTError.audioProcessingError("Failed to create output audio format")
        }
        self.audioFormat = outputFormat
        
        // Create converter if formats don't match
        if !inputFormat.isEqual(outputFormat) {
            guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
                throw STTError.audioProcessingError("Failed to create audio converter")
            }
            self.converter = converter
            print("Created audio converter: \(inputFormat) -> \(outputFormat)")
        } else {
            print("Audio formats match, no conversion needed")
        }
        
        // Connect input -> mixer for level monitoring
        engine.connect(inputNode, to: mixerNode, format: inputFormat)
        
        // Create audio stream
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Data.self)
        self.continuation = continuation
        
        // Install audio tap on the mixer node instead of input node
        mixerNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
            }
        }
        
        // Start level monitoring timer using built-in capabilities
        startLevelMonitoring()
        
        // Start the engine
        try engine.start()
        isRecording = true
        
        return stream
    }
    
    public func stop() {
        guard isRecording else { return }
        
        audioEngine?.stop()
        mixerNode?.removeTap(onBus: 0)
        continuation?.finish()
        
        audioEngine = nil
        inputNode = nil
        mixerNode = nil
        audioFormat = nil
        continuation = nil
        isRecording = false
        audioLevel = 0.0
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate audio level from the input buffer (for visual feedback)
        updateAudioLevel(from: buffer)
        
        // Convert audio data to the format we need for STT
        let outputData: Data
        
        if let converter = converter, let audioFormat = audioFormat {
            // Convert to our desired format
            let outputFrameCapacity = AVAudioFrameCount((Double(buffer.frameLength) * audioFormat.sampleRate) / buffer.format.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: audioFormat,
                frameCapacity: outputFrameCapacity
            ) else { 
                print("Failed to create converted buffer")
                return 
            }
            
            var error: NSError?
            var finished = false
            
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                if finished {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                finished = true
                outStatus.pointee = .haveData
                return buffer
            }
            
            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
            
            if status == .error {
                print("Audio conversion error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if convertedBuffer.frameLength == 0 {
                print("Converted buffer is empty")
                return
            }
            
            // Extract Int16 data
            guard let channelData = convertedBuffer.int16ChannelData?[0] else {
                print("Failed to get int16 channel data from converted buffer")
                return
            }
            
            let frameLength = Int(convertedBuffer.frameLength)
            outputData = Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
            
        } else {
            // No conversion needed, try to extract data directly
            if let int16Data = buffer.int16ChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                outputData = Data(bytes: int16Data, count: frameLength * MemoryLayout<Int16>.size)
            } else if let floatData = buffer.floatChannelData?[0] {
                // Convert Float32 to Int16 manually
                let frameLength = Int(buffer.frameLength)
                var int16Array = [Int16]()
                int16Array.reserveCapacity(frameLength)
                
                for i in 0..<frameLength {
                    let floatSample = floatData[i]
                    let clampedSample = max(-1.0, min(1.0, floatSample))
                    let int16Sample = Int16(clampedSample * Float(Int16.max))
                    int16Array.append(int16Sample)
                }
                
                outputData = Data(bytes: int16Array, count: frameLength * MemoryLayout<Int16>.size)
            } else {
                print("Unable to extract audio data from buffer")
                return
            }
        }
        
        // Throttle audio data logging to reduce console spam
        audioDataLogCounter += 1
        if audioDataLogCounter % audioDataLogInterval == 1 {
            print("Yielding audio data: \(outputData.count) bytes (logged every \(audioDataLogInterval) yields)")
        }
        continuation?.yield(outputData)
    }
    
    private func startLevelMonitoring() {
        // Level monitoring is now handled directly in the audio tap
        // No need for a separate timer - the tap provides real-time updates
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        // Simplified audio level calculation - just get peak amplitude
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        var peak: Float = 0.0
        
        if let floatData = buffer.floatChannelData?[0] {
            // Float format - find peak value
            for i in 0..<frameLength {
                peak = max(peak, abs(floatData[i]))
            }
            // Apply gentle scaling to match macOS levels better
            peak = min(peak * 3.0, 1.0)
        }
        
        // Update audioLevel on main thread for UI
        Task { @MainActor in
            self.audioLevel = peak
            // Throttle audio level logging to reduce console spam
            if peak > 0.01 {
                self.audioLevelLogCounter += 1
                if self.audioLevelLogCounter % self.audioLevelLogInterval == 1 {
                    print("Audio level: \(peak) (logged every \(self.audioLevelLogInterval) updates)")
                }
            }
        }
    }
    
    private func setAudioInputDevice(deviceID: String) throws {
        guard let audioDeviceID = AudioDeviceID(deviceID) else {
            throw STTError.audioProcessingError("Invalid device ID")
        }
        
        var mutableDeviceID = audioDeviceID
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            propertySize,
            &mutableDeviceID
        )
        
        guard status == noErr else {
            throw STTError.audioProcessingError("Failed to set audio input device")
        }
    }
}