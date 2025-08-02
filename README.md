# 🔵 VTS - Voice-Type Studio

[![Build Status](https://github.com/j05u3/VTS/workflows/Build%20and%20Release%20macOS%20App/badge.svg)](https://github.com/j05u3/VTS/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Latest Release](https://img.shields.io/github/v/release/j05u3/VTS)](https://github.com/j05u3/VTS/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-blue)](https://developer.apple.com/macos/)

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

## 📷 Screenshots

<img width="350" alt="image" src="https://github.com/user-attachments/assets/57fdf28d-120e-4bfb-9dfd-5413e7c65127" /> <img width="350" alt="image" src="https://github.com/user-attachments/assets/d165c874-9df4-41af-b49d-f4220896d699" />
 <img width="350" alt="image" src="https://github.com/user-attachments/assets/b7aacf73-842a-4292-9418-d9fb7df13eee" />

## 🎬 Longer Demo

https://github.com/user-attachments/assets/f69c365a-4f1a-42f1-b2de-66d61643fea0

Onboarding:

https://youtu.be/NTQmVCvkZQQ

## 📦 Installation

**Ready to use VTS?** Head over to our [**Releases Page**](https://github.com/j05u3/VTS/releases/latest) for:
- 📥 **One-click downloads** for macOS (Apple Silicon & Intel)
- 📋 **Complete installation instructions**
- 🔍 **System requirements** and compatibility info
- 📝 **Release notes** with latest features and fixes

### Requirements for End Users
- **macOS 14.0+** (Apple Silicon & Intel supported)
- **API key** from OpenAI or Groq (see setup below)

### API Key Setup

After installing VTS, you'll need an API key from one of these providers:

- **OpenAI**: [Get your API key here](https://platform.openai.com/api-keys)
- **Groq**: [Get your API key here](https://console.groq.com/keys)

*Only one API key is required - choose the provider you prefer!*

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


## Privacy & Security

- **No audio storage**: Audio is processed in real-time, never stored locally
- **API keys are safe**: Keys are stored in Keychain
- **TLS encryption**: All API communication uses HTTPS
- **Microphone permission**: Explicit user consent required for audio access

## 🔧 Troubleshooting

### Common Issues
- **Microphone Permission Denied**: Check System Settings > Privacy & Security > Microphone
- **No Microphones Found**: Click "Refresh" in the Microphone Priority section
- **Wrong Microphone Active**: Set your preferred priority order or check device connections
- **App Not Responding to Hotkey**: Ensure accessibility permissions are granted when prompted

---

## 🛠️ Development

*This section is for developers who want to build VTS from source or contribute to the project.*

### Development Requirements
- **macOS 14.0+** (Apple Silicon & Intel supported)
- **Xcode 15+** for building
- **API key** from OpenAI or Groq for testing

### Building from Source

1. **Clone the repository:**
```bash
git clone https://github.com/j05u3/VTS.git
cd VTS
```

2. **Open in Xcode:**
```bash
open VTSApp.xcodeproj
```

3. **Build and run:**
   - In Xcode, select the **VTSApp** scheme
   - Build and run with **⌘R**
   - Grant microphone permission when prompted

### Command Line Building

```bash
# Build via command line
xcodebuild -project VTSApp.xcodeproj -scheme VTSApp build
```

### Architecture

VTS follows a clean, modular architecture:

- **CaptureEngine**: Handles audio capture using AVAudioEngine with Core Audio device management
- **DeviceManager**: Manages microphone priority lists and automatic device selection
- **TranscriptionService**: Orchestrates streaming transcription with provider abstraction
- **STTProvider Protocol**: Clean interface allowing easy addition of new providers
- **Modern SwiftUI**: Reactive UI with proper state management and real-time updates

### Testing

Currently, VTS includes manual testing capabilities through the built-in Text Injection Test Suite accessible from the app's interface. This allows you to test text insertion functionality across different applications.

Automated unit tests are planned for future releases.

### Development Troubleshooting

#### Accessibility Permissions (Development)
- **Permission Not Updating**: During development/testing, when the app changes (rebuild, code changes), macOS treats it as a "new" app
- **Solution**: Remove the old app entry from System Settings > Privacy & Security > Accessibility, then re-grant permission
- **Why This Happens**: Each build gets a different signature, so macOS sees it as a different application
- **Quick Fix**: Check the app list in Accessibility settings and remove any old/duplicate VTS entries

#### Testing Onboarding Flow
- **Reset App State**: To test the complete onboarding flow, change the `PRODUCT_BUNDLE_IDENTIFIER` in Xcode project settings
- **Why This Works**: Changing the bundle identifier creates a "new" app from macOS perspective, resetting all permissions and app state
- **Most Reliable Method**: This is more reliable than clearing UserDefaults and ensures a clean onboarding test including all system permissions

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to VTS development.

---

## Roadmap

- [ ] **Auto-open at login**: Auto-open at login. (Maybe a checkbox in the preferences window?)
- [ ] **Auto-update System**: Seamless updates via Sparkle framework

### In a future or maybe pro version, to be decided/ordered by priority, your feedback and contributions are welcome!

- [ ] **More models/providers**: Support for more STT providers like Google, Azure, etc.
- [ ] **Safe auto-cut**: Auto-cut to maximum time if the user forgets to end (or accidentally starts).
- [ ] **Comprehensive Test Suite**: Automated unit tests covering:
  - Core transcription functionality
  - Provider validation and error handling  
  - Device management and priority logic
  - Integration flows and edge cases
- [ ] **LLM step**: Use LLM to process the transcription and improve accuracy, maybe targetted to the app you're using or context in general. (Be able to easily input emojis?). I mean apply transformations based on the app you're injecting text to.
- [ ] **Advanced Audio Processing**: Noise reduction and gain control, but also some STT providers can do this so maybe not needed?.
- [ ] **Accessibility Features**: VoiceOver support and high contrast modes

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgements

VTS wouldn't be possible without the incredible work of the open-source community. Special thanks to:

### Tools & Scripts
- [ios-icon-generator](https://github.com/smallmuou/ios-icon-generator) by @smallmuou - for the awesome icon generation script that made creating our app icons effortless
- [create-dmg](https://github.com/sindresorhus/create-dmg) by @sindresorhus - for the excellent DMG creation script that streamlines our distribution process

**Note**: This project builds upon the work of many developers and projects. If I've missed crediting someone or something I sincerely apologize! Please feel free to open an issue or PR to help me give proper recognition where it's due.

---

**Made with ❤️ for the macOS community**
