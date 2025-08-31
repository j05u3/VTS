# Plan for Real-Time Transcription in VTS

## **Executive Summary**

This plan outlines the implementation of real-time transcription using OpenAI's Real-Time API with WebSocket streaming, as a beta feature alongside the existing REST API providers. The implementation will leverage the current modular architecture while introducing streaming capabilities and partial result handling.

## **1. Current Architecture Analysis**

### **Existing Components:**
- **CaptureEngine**: Handles audio capture using AVAudioEngine (16kHz, mono, Int16)
- **TranscriptionService**: Orchestrates transcription with provider abstraction
- **STTProvider Protocol**: Clean interface for provider implementations
- **BaseSTTProvider**: Shared functionality for HTTP-based providers
- **Provider Implementations**: OpenAI, Groq, Deepgram (all REST-based)
- **Modern SwiftUI**: Reactive UI with state management

### **Current Flow:**
1. User presses hotkey → Audio recording starts
2. Audio streams collected into Data chunks
3. When recording stops → Full audio sent to REST API
4. Response received → Text injected into active application

## **2. Proposed Real-Time Architecture**

### **Core Architectural Changes:**

#### **A. New Protocol for Streaming Providers**
```swift
protocol StreamingSTTProvider {
    var providerType: STTProviderType { get }
    
    func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession
    func streamAudio(_ audioData: Data, to session: RealtimeSession) async throws
    func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String
    func validateConfig(_ config: ProviderConfig) throws
}
```

#### **B. Real-Time Session Management**
```swift
class RealtimeSession {
    let sessionId: String
    let webSocket: URLSessionWebSocketTask
    let partialResultsStream: AsyncThrowingStream<TranscriptionChunk, Error>
    var isActive: Bool
}
```

#### **C. Service Architecture Refactor**
- Create separate `RestTranscriptionService` and `StreamingTranscriptionService`
- Extract common functionality to a base class or shared utilities
- Partial results handling and display in status bar popup only
- Audio buffering for connection establishment

## **3. Implementation Strategy**

### **Phase 1: Foundation (Core Infrastructure)**

#### **New Files to Create:**

1. **`StreamingSTTProvider.swift`** - New protocol for real-time providers (no inheritance from STTProvider)
2. **`RealtimeSession.swift`** - Session management for WebSocket connections
3. **`OpenAIRealtimeProvider.swift`** - OpenAI real-time implementation
4. **`StreamingTranscriptionService.swift`** - Service for real-time operations
5. **`RestTranscriptionService.swift`** - Refactored service for REST operations
6. **`AudioBuffer.swift`** - Smart buffering for connection establishment
7. **`PartialResultsManager.swift`** - Handles partial transcription display in popup

#### **Files to Modify:**

1. **TranscriptionModels.swift** - Add real-time models, rename defaultModels to restModels, add realtimeModels
```swift
public enum STTProviderType: String, CaseIterable, Codable {
    case openai = "OpenAI"
    case groq = "Groq"
    case deepgram = "Deepgram"
    
    public var restModels: [String] {
        switch self {
        case .openai:
            return ["gpt-4o-transcribe", "gpt-4o-mini-transcribe", "whisper-1"]
        case .groq:
            return ["whisper-large-v3-turbo", "whisper-large-v3"]
        case .deepgram:
            return ["nova-3", "nova-2"]
        }
    }
    
    public var realtimeModels: [String] {
        switch self {
        case .openai:
            return ["gpt-4o-transcribe", "gpt-4o-mini-transcribe"]
        case .groq, .deepgram:
            return [] // Future support
        }
    }
}
```
2. **TranscriptionService.swift** - Refactor to RestTranscriptionService or extract common functionality
3. **VTSApp.swift** - UI controls for real-time toggle and service selection
4. **ContentView.swift** - Display partial results in status bar popup only

### **Phase 2: OpenAI Real-Time Implementation**

#### **Key Components:**

**A. WebSocket Connection Management**
```swift
class OpenAIRealtimeProvider: StreamingSTTProvider {
    private let realtimeURL = "wss://api.openai.com/v1/realtime?intent=transcription"
    var providerType: STTProviderType { .openai }
    
    func startRealtimeSession(config: ProviderConfig) async throws -> RealtimeSession {
        // 1. Establish WebSocket connection
        // 2. Send initial configuration
        // 3. Wait for session confirmation
        // 4. Return active session
    }
    
    func finishAndGetTranscription(_ session: RealtimeSession) async throws -> String {
        // 1. Send completion signal
        // 2. Wait for final transcription
        // 3. Clean up session
        // 4. Return final text
    }
}
```

**B. Audio Buffering Strategy**
```swift
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
```

**C. Partial Results Processing**
```swift
class PartialResultsManager {
    @Published var currentPartialText: String = ""
    @Published var finalizedSegments: [String] = []
    
    func processPartialResult(_ chunk: TranscriptionChunk) {
        // Handle incremental updates for status bar popup display only
        // No injection into active applications until final result
    }
}
```

### **Phase 3: User Experience Integration**

#### **A. UI Enhancements**

**Settings Panel Addition:**
- Real-time transcription toggle (beta)
- Model selection (gpt-4o-transcribe, gpt-4o-mini-transcribe)
- Simple on/off switch with beta label

**Status Bar Popup Changes:**
- Partial results display area (in popup only)
- Show real-time transcription progress

**B. Progressive Text Display (Status Bar Popup Only)**
- Show partial results in real-time within the status bar popup
- Keep text injection simple - only inject final transcription results
- No modification of text at cursor location during transcription

### **Phase 4: Error Handling & Robustness**

#### **A. Connection Management**
- Automatic reconnection on WebSocket failures
- Connection health monitoring
- Proper session cleanup

#### **B. Audio Continuity**
- Buffer audio during connection establishment
- Handle connection drops without losing audio
- Resume streaming seamlessly

## **4. Technical Implementation Details**

### **A. WebSocket Protocol Implementation**

**Connection Setup:**
```swift
let webSocketURL = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription")!
var request = URLRequest(url: webSocketURL)
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("realtime=v1", forHTTPHeaderField: "openai-beta")

let webSocketTask = URLSession.shared.webSocketTask(with: request)
```

**Session Configuration:**
```json
{
    "type": "transcription_session.update",
    "session": {
        "model": "gpt-4o-transcribe"
    }
}
```

**Audio Streaming:**
```swift
func streamAudioChunk(_ audioData: Data) async throws {
    let audioMessage = [
        "type": "input_audio_buffer.append",
        "audio": audioData.base64EncodedString()
    ]
    let messageData = try JSONSerialization.data(withJSONObject: audioMessage)
    try await webSocketTask.send(.data(messageData))
}
```

### **B. Critical Implementation Gotchas**

#### **1. Audio Buffer Management**
**Problem**: WebSocket connection takes time to establish, but audio recording must start immediately.

**Solution**:
```swift
class RealtimeAudioManager {
    private var preConnectionBuffer = Data()
    private var isConnected = false
    private let maxBufferSize = 20 * 1024 * 1024 // 20MB max
    
    func handleAudioChunk(_ data: Data) async {
        if isConnected {
            await streamToSession(data)
        } else {
            preConnectionBuffer.append(data)
            if preConnectionBuffer.count > maxBufferSize {
                // Trim oldest data to prevent memory issues
                let excess = preConnectionBuffer.count - maxBufferSize
                preConnectionBuffer.removeFirst(excess)
            }
        }
    }
    
    func onConnectionEstablished() async {
        isConnected = true
        if !preConnectionBuffer.isEmpty {
            await streamToSession(preConnectionBuffer)
            preConnectionBuffer.removeAll()
        }
    }
}
```

#### **2. Partial Results Display**
**Problem**: Avoid jarring mid-word cutoffs and provide smooth user experience.

**Solution**:
```swift
class PartialResultsRenderer {
    private var lastFinalizedIndex = 0
    
    func updateDisplay(with chunk: TranscriptionChunk) {
        if chunk.isFinal {
            finalizeSegment(chunk.text)
        } else {
            updatePartialSegment(chunk.text)
        }
    }
    
    private func updatePartialSegment(_ text: String) {
        // Only show complete words, keep partial words in buffer
        let words = text.split(separator: " ")
        let completeWords = words.dropLast().joined(separator: " ")
        // Display complete words, buffer the last incomplete word
    }
}
```

#### **3. Connection Lifecycle Management**
**Problem**: WebSocket connections can fail, timeout, or become stale.

**Solution**:
```swift
class ConnectionManager {
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    
    func handleConnectionFailure() async {
        if reconnectAttempts < maxReconnectAttempts {
            await attemptReconnection()
        } else {
            throw STTError.networkError("Failed to establish stable connection")
        }
    }
}
```

### **C. Simple Session Management**
```swift
// Minimal session configuration without VAD
let sessionConfig = [
    "type": "transcription_session.update",
    "session": ["model": config.model]
]
```

## **5. File Organization Structure**

```
VTSApp/VTS/
├── Protocols/
│   ├── STTProvider.swift (modify)
│   └── StreamingSTTProvider.swift (new)
├── Models/
│   ├── TranscriptionModels.swift (modify)
│   ├── RealtimeSession.swift (new)
│   └── StreamingModels.swift (new)
├── Providers/
│   ├── BaseSTTProvider.swift (existing)
│   ├── OpenAIProvider.swift (existing REST)
│   ├── OpenAIRealtimeProvider.swift (new)
│   └── BaseStreamingProvider.swift (new)
├── Services/
│   ├── RestTranscriptionService.swift (refactored from TranscriptionService)
│   ├── StreamingTranscriptionService.swift (new)
│   ├── AudioBuffer.swift (new)
│   └── PartialResultsManager.swift (new)
├── Utils/
│   ├── WebSocketManager.swift (new)
│   └── ConnectionHealthMonitor.swift (new)
└── Views/
    ├── ContentView.swift (modify)
    ├── PartialResultsView.swift (new)
    └── RealtimeStatusView.swift (new)
```

## **6. UX/UI Changes (Minimal)**

### **A. Settings Panel**
- **Toggle**: "Enable Real-time Transcription (Beta)" - Simple checkbox
- **Model Selection**: Dropdown with `gpt-4o-transcribe` and `gpt-4o-mini-transcribe`
- **Info Text**: "Real-time mode improves latency and may consume more API usage"

### **B. Status Bar Icon**
- **Keep existing behavior**: Red icon for recording, blue for processing final transcription
- **No additional status indicators**: Maintain current familiar UX

### **C. No Onboarding Changes**
- Feature discoverable through settings
- Graceful fallback ensures existing workflow unaffected
- Beta label sets appropriate expectations

## **7. Extensibility for Future APIs**

### **A. Google Live API Preparation**
```swift
// Structure allows easy addition of Google Live API
class GoogleLiveProvider: BaseStreamingProvider {
    // Similar pattern, different WebSocket endpoint and protocol
}
```

### **B. Provider Factory Pattern**
```swift
enum StreamingProviderType {
    case openaiRealtime
    case googleLive  // Future
    case deepgramStreaming  // Future
}

class StreamingProviderFactory {
    static func createProvider(_ type: StreamingProviderType) -> StreamingSTTProvider {
        switch type {
        case .openaiRealtime:
            return OpenAIRealtimeProvider()
        case .googleLive:
            return GoogleLiveProvider()  // Future implementation
        case .deepgramStreaming:
            return DeepgramStreamingProvider()  // Future implementation
        }
    }
}
```

## **8. Performance & Resource Considerations**

### **A. Memory Management**
- Limit audio buffer size (20MB max)
- Implement circular buffers for long sessions
- Clean up WebSocket resources properly

### **B. Network Efficiency**
- Chunked audio transmission (1024-byte chunks)
- Connection pooling where possible
- Exponential backoff for reconnections

### **C. Battery Optimization**
- Use efficient WebSocket implementations
- Minimize unnecessary processing
- Proper connection lifecycle management

## **9. Testing Strategy**

### **A. Core Tests (using `swift test`)**
- Audio buffering logic
- Connection state management
- Session lifecycle

### **B. Integration Tests**
- End-to-end real-time transcription
- Connection failure scenarios
- Audio continuity during reconnection

### **C. Manual Testing**
- Network interruption handling
- Long session stability
- Audio quality with various microphones
- Multiple rapid start/stop cycles

## **10. Success Metrics**

### **A. Performance Metrics (same as current REST APIs)**
- **Audio Recording Time**: Time from recording start to recording end (milliseconds)
- **Processing Time**: Time from recording end to final transcription received (milliseconds)
- **Analytics Integration**: Use existing analytics service with same parameters

### **B. User Experience Metrics**
- Session completion rate
- User preference (real-time vs traditional)
- Error recovery effectiveness

This comprehensive plan provides a clear roadmap for implementing real-time transcription while maintaining VTS's current reliability and expanding its capabilities for future streaming APIs.