# Changelog

All notable changes to VTS - Voice Typing Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.4](https://github.com/j05u3/VTS/compare/v0.5.3...v0.5.4) (2025-08-17)


### 📚 Documentation

* test automated workflow after cleanup fix ([e602486](https://github.com/j05u3/VTS/commit/e6024860fccbbc800bfab3a05148c4c5f087564d))

## [0.5.3](https://github.com/j05u3/VTS/compare/v0.5.2...v0.5.3) (2025-08-17)


### 🐛 Bug Fixes

* add repository-projects read permission for release-please v4 ([84ee273](https://github.com/j05u3/VTS/commit/84ee27329afc083e10b9faecfd48e2d5f035e182))

## [0.5.2](https://github.com/j05u3/VTS/compare/v0.5.1...v0.5.2) (2025-08-17)


### 🐛 Bug Fixes

* update sign-update tool references to sign_update in build-release workflow ([8d8ab04](https://github.com/j05u3/VTS/commit/8d8ab0413d70472893bd0917c7cc244283d0e1b1))


### 📚 Documentation

* test release workflow end-to-end ([09afcaf](https://github.com/j05u3/VTS/commit/09afcaf306cb64f3a8da25a058ec3fb4ece1c668))

## [0.5.1](https://github.com/j05u3/VTS/compare/v0.5.0...v0.5.1) (2025-08-17)


### 🐛 Bug Fixes

* update sign_update tool references to sign-update in build-release workflow ([01efdfc](https://github.com/j05u3/VTS/commit/01efdfc99f6b7d9a6f00f01e4bfa453060c2139b))


### 📚 Documentation

* test release-please after fixing release synchronization ([04971ce](https://github.com/j05u3/VTS/commit/04971ce91c2125dd06a8e1c208e7881403318845))

## [0.5.0](https://github.com/j05u3/VTS/compare/v0.4.0...v0.5.0) (2025-08-17)


### ✨ Features

* add Deepgram provider support ([#36](https://github.com/j05u3/VTS/issues/36)) ([e114d48](https://github.com/j05u3/VTS/commit/e114d48f6d26a2dd2857eb1d0746728b688b1f8e))


### 🐛 Bug Fixes

* enhance error handling and logging for Sparkle tools download and signing process ([f8625b2](https://github.com/j05u3/VTS/commit/f8625b26f31539bf39cacb1d1aa5f0d62bedaaf0))
* enhance release workflow to handle merged release PRs ([6fcd60b](https://github.com/j05u3/VTS/commit/6fcd60b5708d3edfc69f80c636a7995e8245e3fe))
* improve release merge detection pattern ([2490f79](https://github.com/j05u3/VTS/commit/2490f794280ea19f92a084180dd57aac4a6ea673))
* simplify release workflow to use release-please properly ([ea7b4c2](https://github.com/j05u3/VTS/commit/ea7b4c23253f218cb6df9972731f9c37ebf097cb))


### 📚 Documentation

* add new file for testing VTS release ([cef9e56](https://github.com/j05u3/VTS/commit/cef9e5611d60d4c67a28c7691789e784fd014a98))
* add workflow testing note ([435a687](https://github.com/j05u3/VTS/commit/435a687643f0d6cc89843f51031eb0325196e96f))
* remove workflow testing note ([158b0ff](https://github.com/j05u3/VTS/commit/158b0ff377b01f023e284391e922037b06172f00))
* trigger release-please workflow ([7ed0b0c](https://github.com/j05u3/VTS/commit/7ed0b0c3d0ac5dda22d6bc3903e733a261b60d8d))


### ♻️ Code Refactoring

* separate release management from build process ([f7bd4df](https://github.com/j05u3/VTS/commit/f7bd4df36664bb703a8b0b9b96d0ca7d9c30b3d9))


### ⚙️ Continuous Integration

* added explanatory comments to release-please permissions ([4e3cc7b](https://github.com/j05u3/VTS/commit/4e3cc7b7a423835a2107783b3fa9cb690e8186a8))
* added the issues permission to the release please workflow ([b12f918](https://github.com/j05u3/VTS/commit/b12f91858527f57851eaf5e410d3506f14e5298e))
* **config:** fix build paths and update appcast logic for release handling ([#33](https://github.com/j05u3/VTS/issues/33)) ([36cdd99](https://github.com/j05u3/VTS/commit/36cdd9981f17b736a73660cc1a001372f26cfe9b))


### 🧹 Miscellaneous

* release main ([a17a409](https://github.com/j05u3/VTS/commit/a17a4096f0de53b8d8ddcfbad182e5d16e691da2))
* release main ([#34](https://github.com/j05u3/VTS/issues/34)) ([cb8a2c1](https://github.com/j05u3/VTS/commit/cb8a2c18c1f2b9db842ae12223f68de2cef9ca34))
* release main ([#38](https://github.com/j05u3/VTS/issues/38)) ([c4a3678](https://github.com/j05u3/VTS/commit/c4a3678f7de2c7241c9dc3bf01bbcc2ac25b3c1a))
* release main ([#39](https://github.com/j05u3/VTS/issues/39)) ([a73c8c0](https://github.com/j05u3/VTS/commit/a73c8c07a0e1163e860b14fb531667034a09d99d))
* release main ([#40](https://github.com/j05u3/VTS/issues/40)) ([2a4e7dc](https://github.com/j05u3/VTS/commit/2a4e7dc79f6c221ab97e187086b4dc37a542cef1))
* release main ([#99](https://github.com/j05u3/VTS/issues/99)) ([655ae51](https://github.com/j05u3/VTS/commit/655ae5164fb295150402d3a7341da09c32513408))
* remove environment configuration from deployment job ([978c66c](https://github.com/j05u3/VTS/commit/978c66c6b3d668644b0eff1c6770fef08a589b0b))

## [0.4.0](https://github.com/j05u3/VTS/compare/v0.3.1...v0.4.0) (2025-08-17)


### ✨ Features

* add Deepgram provider support ([#36](https://github.com/j05u3/VTS/issues/36)) ([e114d48](https://github.com/j05u3/VTS/commit/e114d48f6d26a2dd2857eb1d0746728b688b1f8e))


### 🐛 Bug Fixes

* enhance release workflow to handle merged release PRs ([6fcd60b](https://github.com/j05u3/VTS/commit/6fcd60b5708d3edfc69f80c636a7995e8245e3fe))
* improve release merge detection pattern ([2490f79](https://github.com/j05u3/VTS/commit/2490f794280ea19f92a084180dd57aac4a6ea673))
* simplify release workflow to use release-please properly ([ea7b4c2](https://github.com/j05u3/VTS/commit/ea7b4c23253f218cb6df9972731f9c37ebf097cb))


### 📚 Documentation

* add workflow testing note ([435a687](https://github.com/j05u3/VTS/commit/435a687643f0d6cc89843f51031eb0325196e96f))
* remove workflow testing note ([158b0ff](https://github.com/j05u3/VTS/commit/158b0ff377b01f023e284391e922037b06172f00))
* trigger release-please workflow ([7ed0b0c](https://github.com/j05u3/VTS/commit/7ed0b0c3d0ac5dda22d6bc3903e733a261b60d8d))


### ♻️ Code Refactoring

* separate release management from build process ([f7bd4df](https://github.com/j05u3/VTS/commit/f7bd4df36664bb703a8b0b9b96d0ca7d9c30b3d9))


### ⚙️ Continuous Integration

* added explanatory comments to release-please permissions ([4e3cc7b](https://github.com/j05u3/VTS/commit/4e3cc7b7a423835a2107783b3fa9cb690e8186a8))
* added the issues permission to the release please workflow ([b12f918](https://github.com/j05u3/VTS/commit/b12f91858527f57851eaf5e410d3506f14e5298e))
* **config:** fix build paths and update appcast logic for release handling ([#33](https://github.com/j05u3/VTS/issues/33)) ([36cdd99](https://github.com/j05u3/VTS/commit/36cdd9981f17b736a73660cc1a001372f26cfe9b))


### 🧹 Miscellaneous

* release main ([a17a409](https://github.com/j05u3/VTS/commit/a17a4096f0de53b8d8ddcfbad182e5d16e691da2))
* release main ([#34](https://github.com/j05u3/VTS/issues/34)) ([cb8a2c1](https://github.com/j05u3/VTS/commit/cb8a2c18c1f2b9db842ae12223f68de2cef9ca34))
* release main ([#38](https://github.com/j05u3/VTS/issues/38)) ([c4a3678](https://github.com/j05u3/VTS/commit/c4a3678f7de2c7241c9dc3bf01bbcc2ac25b3c1a))
* release main ([#39](https://github.com/j05u3/VTS/issues/39)) ([a73c8c0](https://github.com/j05u3/VTS/commit/a73c8c07a0e1163e860b14fb531667034a09d99d))
* release main ([#99](https://github.com/j05u3/VTS/issues/99)) ([655ae51](https://github.com/j05u3/VTS/commit/655ae5164fb295150402d3a7341da09c32513408))

## [0.3.1](https://github.com/j05u3/VTS/compare/v0.3.0...v0.3.1) (2025-08-17)


### 🐛 Bug Fixes

* simplify release workflow to use release-please properly ([ea7b4c2](https://github.com/j05u3/VTS/commit/ea7b4c23253f218cb6df9972731f9c37ebf097cb))


### 📚 Documentation

* remove workflow testing note ([158b0ff](https://github.com/j05u3/VTS/commit/158b0ff377b01f023e284391e922037b06172f00))

## [0.3.0](https://github.com/j05u3/VTS/compare/v0.2.2...v0.3.0) (2025-08-14)


### ✨ Features

* add Deepgram provider support ([#36](https://github.com/j05u3/VTS/issues/36)) ([e114d48](https://github.com/j05u3/VTS/commit/e114d48f6d26a2dd2857eb1d0746728b688b1f8e))

## [0.2.2](https://github.com/j05u3/VTS/compare/v0.2.1...v0.2.2) (2025-08-09)


### ⚙️ Continuous Integration

* added explanatory comments to release-please permissions ([4e3cc7b](https://github.com/j05u3/VTS/commit/4e3cc7b7a423835a2107783b3fa9cb690e8186a8))
* added the issues permission to the release please workflow ([b12f918](https://github.com/j05u3/VTS/commit/b12f91858527f57851eaf5e410d3506f14e5298e))
* **config:** fix build paths and update appcast logic for release handling ([#33](https://github.com/j05u3/VTS/issues/33)) ([36cdd99](https://github.com/j05u3/VTS/commit/36cdd9981f17b736a73660cc1a001372f26cfe9b))

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
- Automatic updates via Sparkle framework
- Enhanced CI/CD with automated releases
- Support for additional STT providers

---

For more information about each release, visit the [GitHub Releases page](https://github.com/j05u3/VTS/releases).
