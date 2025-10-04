# Changelog

All notable changes to VTS - Voice Typing Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1](https://github.com/j05u3/VTS/compare/v1.1.0...v1.1.1) (2025-10-04)


### Bug Fixes

* update build script to use PRODUCT_NAME for app paths instead of SCHEME ([f62d503](https://github.com/j05u3/VTS/commit/f62d5037fc072580145c9d8e034706912d4a1bc8))

## [1.1.0](https://github.com/j05u3/VTS/compare/v1.0.0...v1.1.0) (2025-10-04)


### Features

* add homebrew for easier installation ([#91](https://github.com/j05u3/VTS/issues/91)) ([d3cfbf6](https://github.com/j05u3/VTS/commit/d3cfbf674a18b509b14ecc563f868e83883b109d))
* change app name from "VTSApp" to "VTS" to be cleaner ([#90](https://github.com/j05u3/VTS/issues/90)) ([989866f](https://github.com/j05u3/VTS/commit/989866f5ef72123b4a64564db304fb4a4cc6f497))

## [1.0.0](https://github.com/j05u3/VTS/compare/v0.13.0...v1.0.0) (2025-09-11)

### Features

* add optional `Faster ⚡️` option which uses OpenAI realtime API for transcription which should improve latency ([#83](https://github.com/j05u3/VTS/issues/83)) ([2080781](https://github.com/j05u3/VTS/commit/20807812c4d985b2ac678bcb53eee73c2a0fc3e6))

## [0.13.0](https://github.com/j05u3/VTS/compare/v0.12.0...v0.13.0) (2025-08-28)


### Features

* improve text injection in general by using Unicode typing simulation ([#76](https://github.com/j05u3/VTS/issues/76)) ([f931827](https://github.com/j05u3/VTS/commit/f931827f6ae6ae919720cdaf0b6fc966ff7a5d39))

## [0.12.0](https://github.com/j05u3/VTS/compare/v0.11.4...v0.12.0) (2025-08-26)


### Features

* enhance markdown processing in appcast generation for improved HTML output in updates display ([f35260e](https://github.com/j05u3/VTS/commit/f35260e8707af845cf04464410f3907c4cd1a64b))

## [0.11.4](https://github.com/j05u3/VTS/compare/v0.11.3...v0.11.4) (2025-08-26)


### Bug Fixes

* **sparkle:** align CFBundleVersion with CFBundleShortVersionString for proper update detection ([1faa73d](https://github.com/j05u3/VTS/commit/1faa73d41827db6f4e32b8f4c4de277d300c0e46))

## [0.11.3](https://github.com/j05u3/VTS/compare/v0.11.2...v0.11.3) (2025-08-26)


### Bug Fixes

* fix appcast generation with signature injection support ([b803ab3](https://github.com/j05u3/VTS/commit/b803ab3a35944f9a3ef01e493ab9df3a1b24b283))

## [0.11.2](https://github.com/j05u3/VTS/compare/v0.11.1...v0.11.2) (2025-08-26)


### Bug Fixes

* fixed emoji injection by modernizing TextInjector with UTF-16 support ([#70](https://github.com/j05u3/VTS/issues/70)) ([f3955d3](https://github.com/j05u3/VTS/commit/f3955d3299051e73fefb31b09bffba7ca860c7c8))

## [0.11.1](https://github.com/j05u3/VTS/compare/v0.11.0...v0.11.1) (2025-08-25)


### Bug Fixes

* update Sparkle public key in Info.plist for auto-update functionality ([41e8e33](https://github.com/j05u3/VTS/commit/41e8e330ba19f44b065cd600c898f69e8d77eb1c))

## [0.11.0](https://github.com/j05u3/VTS/compare/v0.10.0...v0.11.0) (2025-08-25)


### Features

* integrate basic telemetry for measuring future improvements ([404a661](https://github.com/j05u3/VTS/commit/404a661c5bbad5e0ab25b75e5419f46181335324))

## [0.10.0](https://github.com/j05u3/VTS/compare/v0.9.2...v0.10.0) (2025-08-25)


### Features

* update default STT provider to OpenAI and reorder default models ([ed13e56](https://github.com/j05u3/VTS/commit/ed13e5666b576e080c4a48ae697a0ceec43ddb1d))


### Bug Fixes

* release automation fix to avoid having the appcast in the repo (which requires more permissions and pollutes the code) and instead generate it on every release ([d25d111](https://github.com/j05u3/VTS/commit/d25d111bc218dfcd11ddda5da876ff3955e990eb))

## [0.9.2](https://github.com/j05u3/VTS/compare/v0.9.1...v0.9.2) (2025-08-24)


### Bug Fixes

* fixed and simplified the CHANGELOG.md file ([ab86ce3](https://github.com/j05u3/VTS/commit/ab86ce3fa11483c63216476118ba1f0da7e89d92))

## [0.9.1](https://github.com/j05u3/VTS/compare/v0.9.0...v0.9.1) (2025-08-24)

### Features

* add Deepgram provider support ([#36](https://github.com/j05u3/VTS/issues/36)) ([e114d48](https://github.com/j05u3/VTS/commit/e114d48f6d26a2dd2857eb1d0746728b688b1f8e))
* setting up release-please and Sparkle cast for auto-updates ([changes](https://github.com/j05u3/VTS/compare/v0.2.1...v0.9.1))


## [0.2.1](https://github.com/j05u3/VTS/tree/v0.2.1) (2025-08-02)

### ✨ Features
- Initial release of VTS (Voice Typing Studio)
- OpenAI Whisper and Groq API integration
- Custom global hotkeys for recording control
- Microphone priority management
- Launch at login functionality
- Native macOS dictation replacement experience

### 🔒 Security
- API keys stored securely in macOS Keychain
- All API communications use HTTPS/TLS encryption
- Explicit microphone and accessibility permissions required

### 📚 Documentation
- Comprehensive README with setup instructions
- Contributing guidelines and code of conduct
- Installation and usage documentation

## [Unreleased]

### 🚀 Coming Soon

- See Roadmap in the README.md for upcoming features and improvements.

---

For more information about each release, visit the [GitHub Releases page](https://github.com/j05u3/VTS/releases).
