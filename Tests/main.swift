import Foundation

// Function to send test audio data (simulating saying "hello")
func sendTestAudio(task: URLSessionWebSocketTask) async {
    print("🎤 Sending test audio chunks (simulating 'hello')...")
    
    // Generate simple PCM16 audio data (simulate a short "hello" sound)
    // This is just test data - in real usage you'd have actual audio
    let sampleRate = 24000
    let duration = 1.0 // 1 second
    let samples = Int(Double(sampleRate) * duration)
    
    // Generate a simple sine wave as test audio (440 Hz tone)
    var audioData = Data()
    for i in 0..<samples {
        let t = Double(i) / Double(sampleRate)
        let frequency = 440.0 // A4 note
        let amplitude: Int16 = Int16(32767 * 0.1 * sin(2.0 * Double.pi * frequency * t))
        withUnsafeBytes(of: amplitude.littleEndian) { bytes in
            audioData.append(contentsOf: bytes)
        }
    }
    
    // Split into chunks (like the TypeScript version does)
    let chunkSize = 4096 // 4KB chunks
    let totalChunks = (audioData.count + chunkSize - 1) / chunkSize
    
    for i in 0..<totalChunks {
        let start = i * chunkSize
        let end = min(start + chunkSize, audioData.count)
        let chunk = audioData.subdata(in: start..<end)
        let base64Audio = chunk.base64EncodedString()
        
        let audioMessage = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: audioMessage)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            try await task.send(.string(jsonString))
            print("📤 Sent audio chunk \(i + 1)/\(totalChunks) (\(chunk.count) bytes)")
            
            // Small delay between chunks
            try await Task.sleep(for: .milliseconds(50))
        } catch {
            print("❌ Error sending audio chunk: \(error)")
            return
        }
    }
    
    // Commit the audio buffer (like TypeScript version)
    let commitMessage = ["type": "input_audio_buffer.commit"]
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: commitMessage)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        try await task.send(.string(jsonString))
        print("✅ Audio buffer committed - waiting for transcription...")
    } catch {
        print("❌ Error committing audio: \(error)")
    }
}

// Entry point that allows top-level code execution
func main() async {
    await testSessionUpdate()
}

func testSessionUpdate() async {
    print("🚀 Testing session.update with gpt-4o-mini-transcribe model...")
    
    let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    guard !apiKey.isEmpty else {
        print("❌ Error: OPENAI_API_KEY environment variable not set")
        return
    }
    
    let urlString = "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview"
    guard let url = URL(string: urlString) else {
        print("❌ Error: Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    
    print("⏳ Connecting to: \(urlString)")
    
    let task = URLSession.shared.webSocketTask(with: request)
    task.resume()
    
    print("✅ Connection established, waiting for session.created...")
    
    // Listen for session.created
    Task {
        while true {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    print("📨 Received: \(text)")
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String {
                        
                        // Check for transcription events (expected)
                        if type.contains("transcription") {
                            print("🎯 Transcription event detected: \(type)")
                            if type == "conversation.item.input_audio_transcription.delta" {
                                if let delta = json["delta"] as? String {
                                    print("📝 Transcription delta: \(delta)")
                                }
                            } else if type == "conversation.item.input_audio_transcription.completed" {
                                if let transcript = json["transcript"] as? String {
                                    print("✅ Transcription completed: \(transcript)")
                                }
                            }
                        }
                        
                        // Check for unwanted response events (should not happen)
                        else if type.contains("response") {
                            print("❌ UNEXPECTED: Received response event: \(type)")
                        }
                        
                        // Handle session creation
                        else if type == "session.created" {
                            print("✅ Session created! Sending session.update...")
                            
                            // Send session.update configured like TypeScript version (transcription-only, no server VAD)
                            let sessionUpdate = [
                                "type": "session.update",
                                "session": [
                                    "input_audio_format": "pcm16",
                                    "input_audio_noise_reduction": [
                                        "type": "near_field"
                                    ],
                                    "input_audio_transcription": [
                                        "model": "gpt-4o-mini-transcribe"
                                    ],
                                    "turn_detection": NSNull()  // Disable VAD completely (null in TypeScript)
                                ]
                            ] as [String : Any]
                            
                            let jsonData = try JSONSerialization.data(withJSONObject: sessionUpdate)
                            let jsonString = String(data: jsonData, encoding: .utf8)!
                            print("📤 Sending: \(jsonString)")
                            
                            try await task.send(.string(jsonString))
                            print("✅ Session update sent")
                            
                            // Wait a moment for session to be updated, then send audio
                            try await Task.sleep(for: .milliseconds(500))
                            await sendTestAudio(task: task)
                        }
                    }
                case .data(let data):
                    print("📨 Received data: \(data)")
                @unknown default:
                    print("❓ Unknown message type")
                }
            } catch {
                print("❌ Error receiving message: \(error)")
                break
            }
        }
    }
    
    // Keep running for 10 seconds then finish
    let secondsTimeout = 20 
    do {
        try await Task.sleep(for: .seconds(secondsTimeout))
    } catch {
        print("⚠️ Sleep interrupted: \(error)")
    }
    task.cancel()
    print("🏁 Test completed after secondsTimeout seconds")
}

// Run the main function
await main()
