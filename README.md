# VTS - Voice to Text Service

A modern macOS speech-to-text application that provides real-time transcription using OpenAI and Groq APIs.

## Features (v0.2)

- ✅ **Multiple STT Providers**: OpenAI Whisper and Groq support
- ✅ **Real-time Transcription**: Streaming partial results with live updates
- ✅ **Microphone Priority Management**: Full device priority lists with automatic fallback
- ✅ **Custom System Prompts**: Improve transcription accuracy with context
- ✅ **Native macOS UI**: Modern SwiftUI interface optimized for macOS
- ✅ **Comprehensive Device Support**: Real-time device detection and switching

## Requirements

- **macOS 14.0+** (Apple Silicon & Intel supported)
- **Xcode 15+** for building
- **API key** from OpenAI or Groq

## Quick Start

### 1. Get API Keys

Sign up and get your API key:
- **OpenAI**: https://platform.openai.com/api-keys
- **Groq**: https://console.groq.com/keys

### 2. Clone and Build

```bash
git clone <your-repo-url>
cd VTS
open VTSApp.xcodeproj
```

### 3. Run the App

1. In Xcode, select the **VTSApp** scheme
2. Build and run with **⌘R**
3. Grant microphone permission when prompted

## Usage

### Basic Transcription
1. **Choose Provider**: Select OpenAI or Groq from the dropdown
2. **Select Model**: Pick whisper-1, whisper-large-v3, or other available models
3. **Enter API Key**: Paste your API key in the secure field
4. **Start Recording**: Click the microphone button and speak
5. **View Results**: See real-time transcription with streaming updates
6. **Copy/Clear**: Use buttons to copy text or clear the transcript

### Advanced Features

#### Microphone Priority Management
- **View Available Devices**: See all connected microphones with system default indicators
- **Set Priority Order**: Add devices to priority list with + buttons
- **Automatic Fallback**: App automatically uses highest-priority available device
- **Real-time Switching**: Seamlessly switches when preferred devices connect/disconnect
- **Remove from Priority**: Use − buttons to remove devices from priority list

#### Custom System Prompts
- Add context-specific prompts to improve transcription accuracy
- Examples: "Medical terminology", "Technical jargon", "Names: John, Sarah, Mike"
- Prompts help the AI better understand domain-specific language

#### Responsive Interface
- **Resizable Window**: Drag corners to adjust size for your workflow
- **Adaptive Layout**: UI elements scale appropriately with window size
- **Minimum Size**: Ensures all controls remain accessible

## Project Structure

```
VTS/
├── VTSApp.xcodeproj/          # Xcode project (main entry point)
├── VTSApp/                    # SwiftUI application
│   ├── VTSApp.swift          # App entry point (@main)
│   ├── ContentView.swift     # Main UI with all features
│   ├── Assets.xcassets       # App icons and resources
│   ├── Info.plist           # App configuration & permissions
│   ├── VTSApp.entitlements  # Microphone & network permissions
│   └── VTS/                 # Embedded core library
│       ├── Services/        # Core services
│       │   ├── CaptureEngine.swift      # Audio capture & device management
│       │   ├── DeviceManager.swift      # Microphone priority & enumeration
│       │   └── TranscriptionService.swift # STT orchestration
│       ├── Providers/       # STT provider implementations
│       │   ├── OpenAIProvider.swift     # OpenAI Whisper integration
│       │   └── GroqProvider.swift       # Groq integration
│       ├── Protocols/       # Provider abstraction
│       │   └── STTProvider.swift        # Common STT interface
│       ├── Models/          # Data models
│       │   └── TranscriptionModels.swift # Configuration & response models
│       └── Extensions/      # Utility extensions
│           └── AsyncExtensions.swift    # Async/await helpers
├── Sources/VTS/              # Swift Package library (for SPM compatibility)
├── Tests/                    # Comprehensive test suite
├── Package.swift            # Swift Package Manager configuration
├── OBJECTIVE.md             # Project goals and requirements
├── PLAN.md                  # Detailed technical specification
└── README.md               # This file
```

## Architecture

VTS follows a clean, modular architecture:

- **CaptureEngine**: Handles audio capture using AVAudioEngine with Core Audio device management
- **DeviceManager**: Manages microphone priority lists and automatic device selection
- **TranscriptionService**: Orchestrates streaming transcription with provider abstraction
- **STTProvider Protocol**: Clean interface allowing easy addition of new providers
- **Modern SwiftUI**: Reactive UI with proper state management and real-time updates

## Development

### Building

```bash
# Open in Xcode (recommended)
open VTSApp.xcodeproj

# Or build via command line
xcodebuild -project VTSApp.xcodeproj -scheme VTSApp build
```

### Testing

```bash
# Run comprehensive test suite
swift test

# Tests cover:
# - Core transcription functionality
# - Provider validation and error handling
# - Device management and priority logic
# - Integration flows and edge cases
```

### Adding New STT Providers

1. **Implement STTProvider protocol** in `Providers/`
2. **Add to STTProviderType enum** in `TranscriptionModels.swift`
3. **Update provider selection** in `ContentView.swift`
4. **Add comprehensive tests** in `Tests/`

## Troubleshooting

### Microphone Issues
- **Permission Denied**: Check System Settings > Privacy & Security > Microphone
- **No Devices Found**: Click "Refresh" in Microphone Priority section
- **Wrong Device Active**: Set priority order or check device connections

### API Issues
- **Invalid Key**: Verify API key format and account status
- **Rate Limits**: Check your account quotas and billing
- **Network Errors**: Ensure stable internet connection

### Accessibility Permissions (Development)
- **Permission Not Updating**: During development/testing, when the app changes (rebuild, code changes), macOS treats it as a "new" app
- **Solution**: Remove the old app entry from System Settings > Privacy & Security > Accessibility, then re-grant permission
- **Why This Happens**: Each build gets a different signature, so macOS sees it as a different application
- **Quick Fix**: Check the app list in Accessibility settings and remove any old/duplicate VTS entries

### Performance Tips
- **Groq**: Faster streaming, good for real-time use
- **OpenAI**: Higher quality, better for accuracy-critical applications
- **Shorter Sessions**: Process faster and use less quota
- **Good Internet**: Improves streaming performance significantly

## Roadmap

### v0.3 (Next)
- [ ] **Global Hotkey Support**: ⌘⇧; toggle recording system-wide
- [ ] **Menu Bar Integration**: Lightweight menu bar interface
- [ ] **Multiple API Key Management**: Store and switch between multiple keys
- [ ] **Status Bar Indicators**: Visual recording state in menu bar

### v1.0 (Future)
- [ ] **Dictation Replacement**: Full macOS dictation system integration
- [ ] **Auto-update System**: Seamless updates via Sparkle framework
- [ ] **Advanced Audio Processing**: Noise reduction and gain control
- [ ] **Accessibility Features**: VoiceOver support and high contrast modes

## Contributing

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Add tests** for new functionality
4. **Ensure** all tests pass (`swift test`)
5. **Commit** changes (`git commit -m 'Add amazing feature'`)
6. **Push** to branch (`git push origin feature/amazing-feature`)
7. **Open** a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Privacy & Security

- **No audio storage**: Audio is processed in real-time, never stored locally
- **Local API key storage**: Keys are stored locally in app preferences, sandboxed to the app
- **TLS encryption**: All API communication uses HTTPS
- **Microphone permission**: Explicit user consent required for audio access

---

**Made with ❤️ for the macOS community**