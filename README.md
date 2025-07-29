# 🔵 VTS - Voice-Type Studio

**The open-source macOS dictation replacement you've been waiting for!** 🚀

Transform your voice into text instantly with the power of **OpenAI** and **Groq** APIs. Say goodbye to macOS dictation limitations and hello to lightning-fast, accurate transcription with your own custom hotkeys! ⚡️

## 🎬 Demo

> **🔊 Turn on your sound!** This demo includes audio to showcase the real-time transcription experience.

https://github.com/user-attachments/assets/59563387-5d46-47eb-8f58-2607c4901135


## ✨ Why Choose VTS?

- 🤖 **AI-Powered Accuracy**: Leverage OpenAI and Groq models for superior transcription
- 🔑 **Your Keys, Your Control**: Bring your own API keys - no subscriptions, no limits
- 🔄 **Drop-in Replacement**: Works exactly like macOS dictation, but better!
- ⌨️ **Your Shortcut, Your Rules**: Fully customizable global hotkeys (default: ⌘⇧;)
- 🎯 **Smart Device Management**: Intelligent microphone priority with seamless fallback
- 💬 **Context-Aware**: Custom system prompt boosts accuracy for your specific needs  
- 🔓 **100% Open Source**: Full transparency, community-driven, modify as you wish

## 🎬 Longer Demo

https://github.com/user-attachments/assets/f69c365a-4f1a-42f1-b2de-66d61643fea0

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
4. **Start Recording**: Press the global hotkey (default: ⌘⇧;) and speak
5. **View Results**: See real-time transcription inserted into the application you're using
6. **(Optional) Copy**: Use buttons to copy the transcript

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

Currently, VTS includes manual testing capabilities through the built-in Text Injection Test Suite accessible from the app's interface. This allows you to test text insertion functionality across different applications.

Automated unit tests are planned for future releases.

## Troubleshooting

### Microphone Issues
- **Permission Denied**: Check System Settings > Privacy & Security > Microphone
- **No Devices Found**: Click "Refresh" in Microphone Priority section
- **Wrong Device Active**: Set priority order or check device connections

### Accessibility Permissions (Development)
- **Permission Not Updating**: During development/testing, when the app changes (rebuild, code changes), macOS treats it as a "new" app
- **Solution**: Remove the old app entry from System Settings > Privacy & Security > Accessibility, then re-grant permission
- **Why This Happens**: Each build gets a different signature, so macOS sees it as a different application
- **Quick Fix**: Check the app list in Accessibility settings and remove any old/duplicate VTS entries

## Roadmap

- [ ] **Onboarding**: Onboarding flow to help users get started.
- [ ] **Notarization and code signing**: Notarization and code signing are required to run the app on macOS.
- [ ] **Auto-open at login**: Auto-open at login. (Maybe a checkbox in the preferences window?)
- [ ] **Auto-update System**: Seamless updates via Sparkle framework

### In a future or maybe pro version, to be decided
- [ ] **Comprehensive Test Suite**: Automated unit tests covering:
  - Core transcription functionality
  - Provider validation and error handling  
  - Device management and priority logic
  - Integration flows and edge cases
- [ ] **LLM step**: Use LLM to process the transcription and improve accuracy, maybe targetted to the app you're using or context in general. (Be able to easily input emojis?)
- [ ] **Advanced Audio Processing**: Noise reduction and gain control, but also some STT providers can do this so maybe not needed?.
- [ ] **Accessibility Features**: VoiceOver support and high contrast modes

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Privacy & Security

- **No audio storage**: Audio is processed in real-time, never stored locally
- **API keys in memory only**: Keys are not persisted between sessions
- **TLS encryption**: All API communication uses HTTPS
- **Microphone permission**: Explicit user consent required for audio access

---

**Made with ❤️ for the macOS community**
