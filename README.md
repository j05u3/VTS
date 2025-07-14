# VTS - Voice to Text Service

A modern macOS speech-to-text application that supports OpenAI and Groq APIs.

## Features (v0.2)

- ✅ **Multiple STT Providers**: OpenAI Whisper and Groq support
- ✅ **Real-time Transcription**: Streaming partial results
- ✅ **Microphone Management**: Device priority lists and selection
- ✅ **Custom Prompts**: System prompt customization for better context
- ✅ **Native UI**: SwiftUI-based interface
- ✅ **Comprehensive Tests**: Unit and integration test coverage

## Requirements

- macOS 14.0+
- Swift 5.10+
- API key from OpenAI or Groq

## Quick Start

### 1. Clone and Build

```bash
git clone <your-repo-url>
cd VTS
swift build
```

### 2. Run the App

#### Option A: Using Swift Package Manager
```bash
swift run VTSApp
```

#### Option B: Create Xcode Project (Recommended for GUI)
```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open VTS.xcodeproj
```

Then in Xcode:
1. Select the `VTSApp` scheme
2. Build and run (⌘R)

### 3. Setup API Keys

Get your API key from:
- **OpenAI**: https://platform.openai.com/api-keys
- **Groq**: https://console.groq.com/keys

### 4. Grant Microphone Permission

When you first run the app, macOS will ask for microphone permission. Grant it to enable audio recording.

## Usage

1. **Configure Provider**: Choose OpenAI or Groq
2. **Select Model**: Pick from available models (whisper-1, whisper-large-v3, etc.)
3. **Enter API Key**: Paste your API key (kept secure, not stored permanently)
4. **Optional System Prompt**: Add context for better transcription
5. **Start Recording**: Click the microphone button
6. **Speak**: Talk normally, see real-time transcription
7. **Stop Recording**: Click stop, final text will appear
8. **Copy/Clear**: Use buttons to copy text or clear results

## Testing

Run the comprehensive test suite:

```bash
swift test
```

Tests cover:
- Core transcription functionality
- Provider validation
- Device management
- Error handling
- Integration flows

## Development

### Project Structure

```
VTS/
├── Sources/
│   ├── VTS/                 # Core library
│   │   ├── Models/          # Data models
│   │   ├── Protocols/       # STT provider interface
│   │   ├── Services/        # Core services
│   │   ├── Providers/       # OpenAI & Groq implementations
│   │   └── Extensions/      # Utility extensions
│   └── VTSApp/             # GUI application
│       ├── main.swift
│       ├── ContentView.swift
│       └── Info.plist
├── Tests/                   # Test suite
└── Package.swift           # Swift Package Manager config
```

### Adding New Providers

1. Implement `STTProvider` protocol
2. Add to `STTProviderType` enum
3. Update UI provider selection
4. Add tests

## Troubleshooting

### Build Issues
- Ensure you have Xcode 15+ installed
- Run `swift package clean` then `swift build`

### Microphone Issues
- Check System Preferences > Security & Privacy > Microphone
- Ensure VTS has permission enabled

### API Issues
- Verify your API key is valid
- Check your account has credits/quota
- Ensure internet connectivity

### Performance
- For better performance, use Groq (faster) vs OpenAI (higher quality)
- Shorter recordings process faster
- Good internet connection improves streaming

## Next Steps (v0.3+)

- [ ] Global hotkey support (⌘⇧;)
- [ ] Menu bar integration
- [ ] Multiple API key management
- [ ] Auto-update system
- [ ] Advanced audio preprocessing

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details.