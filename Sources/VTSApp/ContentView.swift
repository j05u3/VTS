import SwiftUI
import VTS

struct ContentView: View {
    @StateObject private var captureEngine = CaptureEngine()
    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var deviceManager = DeviceManager()
    
    @State private var apiKey = ""
    @State private var selectedProvider: STTProviderType = .openai
    @State private var selectedModel = "whisper-1"
    @State private var systemPrompt = ""
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("VTS - Voice to Text Service")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Configuration Section
            GroupBox("Configuration") {
                VStack(alignment: .leading, spacing: 10) {
                    // Provider Selection
                    HStack {
                        Text("Provider:")
                            .frame(width: 80, alignment: .leading)
                        Picker("Provider", selection: $selectedProvider) {
                            ForEach(STTProviderType.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedProvider) { newProvider in
                            selectedModel = newProvider.defaultModels.first ?? ""
                        }
                    }
                    
                    // Model Selection
                    HStack {
                        Text("Model:")
                            .frame(width: 80, alignment: .leading)
                        Picker("Model", selection: $selectedModel) {
                            ForEach(selectedProvider.defaultModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // API Key
                    HStack {
                        Text("API Key:")
                            .frame(width: 80, alignment: .leading)
                        SecureField("Enter your API key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // System Prompt
                    HStack(alignment: .top) {
                        Text("Prompt:")
                            .frame(width: 80, alignment: .leading)
                        TextField("Optional system prompt", text: $systemPrompt, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }
                }
                .padding()
            }
            
            // Recording Section
            GroupBox("Recording") {
                VStack(spacing: 15) {
                    // Audio Level Indicator
                    HStack {
                        Text("Audio Level:")
                        ProgressView(value: captureEngine.audioLevel)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 10)
                    }
                    
                    // Record Button
                    Button(action: toggleRecording) {
                        HStack {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title2)
                            Text(isRecording ? "Stop Recording" : "Start Recording")
                        }
                        .foregroundColor(isRecording ? .red : .blue)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty)
                }
                .padding()
            }
            
            // Transcription Results
            GroupBox("Transcription") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Status:")
                        Text(transcriptionService.isTranscribing ? "Transcribing..." : "Idle")
                            .foregroundColor(transcriptionService.isTranscribing ? .green : .secondary)
                    }
                    
                    if let error = transcriptionService.error {
                        Text("Error: \(error.localizedDescription)")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    ScrollView {
                        Text(transcriptionService.currentText.isEmpty ? "Transcribed text will appear here..." : transcriptionService.currentText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                    }
                    .frame(height: 120)
                    
                    HStack {
                        Button("Clear") {
                            transcriptionService.currentText = ""
                        }
                        .disabled(transcriptionService.currentText.isEmpty)
                        
                        Spacer()
                        
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(transcriptionService.currentText, forType: .string)
                        }
                        .disabled(transcriptionService.currentText.isEmpty)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 600)
        .onAppear {
            setupTranscriptionService()
        }
    }
    
    private func setupTranscriptionService() {
        // Set up the provider based on selection
        updateProvider()
    }
    
    private func updateProvider() {
        switch selectedProvider {
        case .openai:
            transcriptionService.setProvider(OpenAIProvider())
        case .groq:
            transcriptionService.setProvider(GroqProvider())
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard !apiKey.isEmpty else { return }
        
        updateProvider()
        
        do {
            let audioStream = try captureEngine.start()
            
            let config = ProviderConfig(
                apiKey: apiKey,
                model: selectedModel,
                systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
            )
            
            transcriptionService.startTranscription(
                audioStream: audioStream,
                config: config,
                streamPartials: true
            )
            
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        captureEngine.stop()
        transcriptionService.stopTranscription()
        isRecording = false
    }
}

#Preview {
    ContentView()
}