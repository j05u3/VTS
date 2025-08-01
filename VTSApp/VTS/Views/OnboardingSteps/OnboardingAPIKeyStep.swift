import SwiftUI

struct OnboardingAPIKeyStep: View {
    @ObservedObject var appState: AppState
    @State private var selectedProvider: STTProviderType = .groq
    @State private var apiKey: String = ""
    @State private var showingAPIKey = false
    @State private var isSaving = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    private var apiKeyManager: APIKeyManager {
        appState.apiKeyManagerService
    }
    
    var body: some View {
        VStack(spacing: 40) {
            // Header section
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("AI Provider Setup")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Connect your AI provider to enable voice transcription. Your API key will be stored securely in Keychain.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            // Provider selection and setup
            VStack(spacing: 24) {
                // Provider selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your AI provider:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        ForEach(STTProviderType.allCases, id: \.self) { provider in
                            ProviderCard(
                                provider: provider,
                                isSelected: selectedProvider == provider,
                                onSelect: { selectedProvider = provider }
                            )
                        }
                    }
                }
                
                // API Key input
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("API Key:")
                            .font(.headline)
                        
                        Spacer()
                        
                        if apiKeyManager.hasAPIKey(for: selectedProvider) {
                            Label("Configured", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        }
                    }
                    
                    HStack {
                        Group {
                            if showingAPIKey {
                                TextField("Enter your \(selectedProvider.rawValue) API key", text: $apiKey)
                            } else {
                                SecureField("Enter your \(selectedProvider.rawValue) API key", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            saveAPIKey()
                        }
                        
                        Button(action: { showingAPIKey.toggle() }) {
                            Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    HStack {
                        Button(action: saveAPIKey) {
                            if isSaving {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Saving...")
                                }
                            } else {
                                Text("Save API Key")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.isEmpty || isSaving)
                        
                        if apiKeyManager.hasAPIKey(for: selectedProvider) {
                            Button("Remove") {
                                removeAPIKey()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                        
                        Button("Get API Key") {
                            openProviderWebsite()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // Provider information
                ProviderInfoCard(provider: selectedProvider)
            }
            .frame(maxWidth: 600)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .alert("Success!", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("API key saved successfully!")
        }
        .onAppear {
            loadExistingAPIKey()
        }
        .onChange(of: selectedProvider) { _, newProvider in
            loadExistingAPIKey()
        }
    }
    
    private func loadExistingAPIKey() {
        do {
            if let existingKey = try apiKeyManager.getAPIKey(for: selectedProvider) {
                apiKey = existingKey
            } else {
                apiKey = ""
            }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load existing API key: \(error.localizedDescription)"
        }
    }
    
    private func saveAPIKey() {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a valid API key"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            try apiKeyManager.storeAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: selectedProvider)
            appState.selectedProvider = selectedProvider
            showingSuccess = true
            isSaving = false
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)\n\nIf you see a keychain permission dialog, please click \"Allow\" to securely store your API key."
            isSaving = false
        }
    }
    
    private func removeAPIKey() {
        do {
            try apiKeyManager.deleteAPIKey(for: selectedProvider)
            apiKey = ""
            errorMessage = nil
        } catch {
            errorMessage = "Failed to remove API key: \(error.localizedDescription)"
        }
    }
    
    private func openProviderWebsite() {
        let url: URL?
        switch selectedProvider {
        case .openai:
            url = URL(string: "https://platform.openai.com/api-keys")
        case .groq:
            url = URL(string: "https://console.groq.com/keys")
        }
        
        if let url = url {
            NSWorkspace.shared.open(url)
        }
    }
}

struct ProviderCard: View {
    let provider: STTProviderType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: provider.iconName)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : provider.color)
                
                Text(provider.rawValue)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(provider.description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? provider.color : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? provider.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderInfoCard: View {
    let provider: STTProviderType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About \(provider.rawValue)")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "dollarsign.circle", text: provider.pricingInfo)
                InfoRow(icon: "speedometer", text: provider.speedInfo)
                InfoRow(icon: "checkmark.circle", text: provider.qualityInfo)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(provider.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(provider.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// Extensions for provider information
extension STTProviderType {
    var color: Color {
        switch self {
        case .openai:
            return .green
        case .groq:
            return .orange
        }
    }
    
    var description: String {
        switch self {
        case .openai:
            return "Industry-leading AI models with high accuracy"
        case .groq:
            return "Ultra-fast inference with competitive accuracy"
        }
    }
    
    var pricingInfo: String {
        switch self {
        case .openai:
            return "Pay-per-use pricing, typically $0.006/minute"
        case .groq:
            return "Free tier available, very cost-effective"
        }
    }
    
    var speedInfo: String {
        switch self {
        case .openai:
            return "Standard processing speed, reliable quality"
        case .groq:
            return "Lightning-fast processing, near real-time"
        }
    }
    
    var qualityInfo: String {
        switch self {
        case .openai:
            return "Excellent accuracy across all languages"
        case .groq:
            return "High accuracy with superior speed"
        }
    }
}

#Preview {
    OnboardingAPIKeyStep(appState: AppState())
        .frame(width: 800, height: 600)
}