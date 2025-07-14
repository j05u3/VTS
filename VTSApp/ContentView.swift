import SwiftUI

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
                .padding(.top, 10)
            
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
                        .pickerStyle(.segmented)
                        .onChange(of: selectedProvider) { _, newProvider in
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
                        .pickerStyle(.menu)
                    }
                    
                    // API Key
                    HStack {
                        Text("API Key:")
                            .frame(width: 80, alignment: .leading)
                        SecureField("Enter your API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // System Prompt
                    HStack(alignment: .top) {
                        Text("Prompt:")
                            .frame(width: 80, alignment: .leading)
                        TextField("Optional system prompt", text: $systemPrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                }
                .padding()
            }
            
            // Microphone Priority Section
            GroupBox("Microphone Priority") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Available Devices:")
                            .font(.headline)
                        Spacer()
                        Button("Refresh") {
                            deviceManager.updateAvailableDevices()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if deviceManager.availableDevices.isEmpty {
                        Text("No microphones detected")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        // Available devices list
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(deviceManager.availableDevices) { device in
                                HStack {
                                    Text(device.name)
                                        .font(.body)
                                    if device.isDefault {
                                        Text("(System Default)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("+") {
                                        deviceManager.addDeviceToPriorities(device.id)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(deviceManager.devicePriorities.contains(device.id))
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        Divider()
                        
                        // Priority list
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Priority Order:")
                                .font(.headline)
                            
                            if deviceManager.devicePriorities.isEmpty {
                                Text("No priority set - will use system default")
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                ForEach(Array(deviceManager.devicePriorities.enumerated()), id: \.offset) { index, deviceID in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(deviceManager.getDeviceName(for: deviceID))
                                            .font(.body)
                                        if deviceID == deviceManager.preferredDeviceID {
                                            Text("(Active)")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        Spacer()
                                        Button("−") {
                                            deviceManager.removeDeviceFromPriorities(deviceID)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            
            // Recording Section
            GroupBox("Recording") {
                VStack(spacing: 15) {
                    // Permission Status
                    if !captureEngine.permissionGranted {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Microphone permission required")
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 5)
                    }
                    
                    // Audio Level Indicator
                    HStack {
                        Text("Audio Level:")
                        ProgressView(value: captureEngine.audioLevel)
                            .progressViewStyle(.linear)
                            .frame(height: 10)
                            .tint(captureEngine.audioLevel > 0.1 ? .green : .gray)
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
                    .disabled(apiKey.isEmpty || !captureEngine.permissionGranted)
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
                    .frame(minHeight: 120, maxHeight: .infinity)
                    
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
        .frame(minWidth: 500, maxWidth: .infinity, minHeight: 800, maxHeight: .infinity)
        .onAppear {
            setupTranscriptionService()
        }
    }
    
    private func setupTranscriptionService() {
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
        guard !apiKey.isEmpty else {
            print("API key is required")
            return
        }
        
        guard captureEngine.permissionGranted else {
            print("Microphone permission not granted")
            return
        }
        
        updateProvider()
        
        do {
            print("Starting audio capture...")
            let audioStream = try captureEngine.start(deviceID: deviceManager.preferredDeviceID)
            
            let config = ProviderConfig(
                apiKey: apiKey,
                model: selectedModel,
                systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
            )
            
            print("Starting transcription service...")
            transcriptionService.startTranscription(
                audioStream: audioStream,
                config: config,
                streamPartials: true
            )
            
            isRecording = true
            print("Recording started successfully")
        } catch {
            print("Failed to start recording: \(error)")
            // Make sure to show the error in the UI
            transcriptionService.error = error as? STTError ?? STTError.audioProcessingError(error.localizedDescription)
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