import SwiftUI
import OpenAIRealtime

// Example of how to use the OpenAI Realtime library in your VTS app
struct OpenAIRealtimeExample: View {
    @State private var conversation: Conversation?
    @State private var isConnected = false
    
    private let openAIAPIKey = "your-openai-api-key-here"
    
    var body: some View {
        VStack {
            Text(isConnected ? "Connected to OpenAI Realtime" : "Not connected")
                .foregroundColor(isConnected ? .green : .red)
            
            Button("Start Conversation") {
                startRealtimeConversation()
            }
            .disabled(conversation != nil)
            
            Button("Stop Conversation") {
                stopRealtimeConversation()
            }
            .disabled(conversation == nil)
        }
        .padding()
    }
    
    private func startRealtimeConversation() {
        conversation = Conversation(authToken: openAIAPIKey)
        
        // Start listening to user's voice and playing back responses
        Task {
            do {
                try await conversation?.startListening()
                await MainActor.run {
                    isConnected = true
                }
            } catch {
                print("Failed to start conversation: \(error)")
            }
        }
    }
    
    private func stopRealtimeConversation() {
        conversation?.stopHandlingVoice()
        conversation = nil
        isConnected = false
    }
}

// Example of sending a text message
extension OpenAIRealtimeExample {
    private func sendTextMessage(_ text: String) {
        Task {
            do {
                try await conversation?.send(from: .user, text: text)
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
}
