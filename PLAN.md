**Speech-to-Text for macOS — Build & Spec Plan (MIT-licensed)**
*(target macOS 14+ / Apple-silicon & Intel)*

---

### 1. Product Scope & UX

| Goal                      | Behaviour                                                                                                                                              |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Instant toggle**        | ⌘ ⇧ ; starts/stops capture by default (user-configurable). Status-bar icon shows 🔴 rec / ⚪️ idle.                                                     |
| **Native-like insertion** | When capture stops (or continuously, if streaming partials) the recognised text is *typed* into the current caret location, mirroring macOS Dictation. |
| **Multi-provider STT**    | User can add any number of **Groq** or **OpenAI** API keys, pick a default key+model, and override the *system prompt/context* per key.                |
| **Mic priority list**     | Settings allow drag-ordering input devices. At toggle-on we pick the first available; fallback to system default.                                      |
| **Zero-friction**         | Single window app ⚙️ Preferences + menu-bar dropdown; no dock icon (LSUIElement = true).                                                               |

---

### 2. High-Level Architecture

```
┌─────────────────────┐        ┌────────────────────┐
| GlobalHotkeyManager |─toggle─►   CaptureEngine    │
└─────────▲───────────┘        │  (AVAudioEngine)   │
          │                    └─────────┬──────────┘
          │ registered via               │
          │ Carbon RegisterEventHotKey   ▼
┌─────────┴───────────┐        ┌────────────────────┐
|  StatusBarController|◄──────►| TranscriptionService│
└─────────▲───────────┘  events└───────┬────────────┘
          │                             │ProviderProtocol
          │ UI (SwiftUI)                │
┌─────────┴───────────┐     ┌───────────▼──────────┐
|   Preferences UI    |     |   Provider:OpenAI    |
| SwiftUI + Settings  |     |   Provider:Groq      |
└─────────┬───────────┘     └───────────┬──────────┘
          │ UserDefaults / Keychain      │
          ▼                              ▼
   JSONConfigStore              HTTPS REST streaming
```

---

### 3. Tech-Stack Choices (+ justification)

| Component                | Choice                                                                                                                                                      | Why simple & modern                                     |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| **Language/UI**          | **Swift 5.10 + SwiftUI**                                                                                                                                    | Native look, reactive bindings, single-target binary.   |
| **Audio capture**        | **AVAudioEngine**                                                                                                                                           | Minimal boilerplate, Core Audio-class sample access.    |
| **Global hotkey**        | **Carbon RegisterEventHotKey** via [PTHotKey](https://github.com/kulpreetchilana/pthotkey)-style wrapper (or MASShortcut)                                   | Works outside sandbox; macOS-stable since 10.6.         |
| **Provider abstraction** | Simple `protocol STTProvider { func start(bufferStream: AsyncThrowingStream<Data,Error>, config:ProviderConfig) async -> AsyncStream<TranscriptionChunk> }` | Allows adding local Whisper later without refactor.     |
| **HTTP client**          | **URLSession WebSocket / streaming multipart**                                                                                                              | No 3rd-party dependency; Combine or async await.        |
| **Config persistence**   | `AppStorage` + **KeychainAccess** (keys encrypted at rest)                                                                                                  | Lightweight, MIT-compatible library.                    |
| **Input insertion**      | **CGEventKeyboard** injection fallback to `NSPasteboard`+⌘V when needed                                                                                     | Matches Dictation behaviour even in secure text fields. |
| **Testing**              | **XCTest** + mock provider returning canned JSON                                                                                                            | CI friendly.                                            |
| **Distribution**         | Codesigned `.app` + Homebrew cask + MAS optional                                                                                                            | Clear upgrade path.                                     |

---

### 4. Core Modules & Key APIs

| Module                   | Responsibility                                                                                                                                     | Important APIs                                                 |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **CaptureEngine**        | Create `AVAudioEngine`, set `inputNode.volume = 1`, install tap at 16 kHz mono PCM; convert to Opus/FLAC as provider requires.                     | `AVAudioPCMBuffer`, `AVAudioConverter`                         |
| **TranscriptionService** | Back-pressure aware buffer → provider; merge `TranscriptionChunk`s, expose `CurrentValueSubject<String, Never>` or async sequence.                 | `URLSession.shared.bytes(for:)`                                |
| **Provider-OpenAI**      | POST `/v1/audio/transcriptions` (non-stream) or `/v1/audio/speech` if streaming is released; include `model`, `prompt`, `language`, `temperature`. | Bearer header.                                                 |
| **Provider-Groq**        | Streaming: `POST /openai/audio/transcriptions` with `stream=true`; parse `data:` SSE chunks.                                                       | Same request envelope as OpenAI.                               |
| **HotkeyManager**        | Register/unregister; handle collisions; expose `@Published var isRecording`.                                                                       | `RegisterEventHotKey`, `EventHotKeyID`, `InstallEventHandler`. |
| **DeviceManager**        | Enumerate with `AVCaptureDevice.devices(for: .audio)`, store `[String]` of UID priorities; detect removal.                                         | NotificationCenter observers.                                  |
| **TextInjector**         | On each partial/final → compare diff with last inserted; update using deletions/insertions to minimise flicker.                                    | `CGEventCreateKeyboardEvent`.                                  |

---

### 5. User-Facing Settings (SwiftUI `Settings{}`)

1. **API Keys**

   * Add ➕ / Delete ✖️ keys
   * Provider (Groq/OpenAI)
   * Default Model (dropdown populated from provider list, e.g. `whisper-large-v3`)
   * Optional *System Prompt* text-field (+ live token count)

2. **Microphone Priority**

   * Drag-reorder table of device names + icons
   * “Auto-gain” switch (use `AVAudioSessionModeMeasurement` if implemented later)

3. **Hotkey**

   * Record new shortcut (use [KeyboardShortcuts](https://github.com/apple/swift-shortcuts) helper)
   * Checkbox “Start at login” (SMAppService)

4. **Advanced**

   * Stream partials vs. only final
   * Insert newline after sentence.
   * Keep transcript history (days) — stored in `~/Library/Application Support/<bundleID>/Transcripts/`.

---

### 6. Security & Privacy Notes

* **No audio stored** unless history enabled; temp buffers kept in RAM.
* **TLS 1.3** enforced for outgoing traffic.
* **Keychain** item class `kSecClassGenericPassword`, access group limited to app.
* Show *Privacy > Microphone* usage description; request on first record.

---

### 7. Testing Matrix

| Test            | Details                                                                               |
| --------------- | ------------------------------------------------------------------------------------- |
| **Unit**        | Provider parsing, diff-injection, device fallback logic.                              |
| **Integration** | Record 30 s sample → stub HTTP server returning known transcript → compare output.    |
| **UI**          | SwiftUI previews + XCT UI test to verify hotkey toggles and insertion.                |
| **Performance** | Cold start < 150 ms; latency < 500 ms for 5-second utterance with 50 Mbps downstream. |

---

### 8. Project Setup & CI

1. `swift package init --type=executable` → Xcode project.
2. Dependencies via SPM: **KeychainAccess**, **KeyboardShortcuts**.
3. **GitHub Actions**:

   * Build & run tests on `macos-14` matrix (Release, Debug).
   * Notarize & attach `.zip` artifact on tag via `apple/tonbeller/notarize` action.
4. **SwiftLint** + `pre-commit` hook.

---

### 9. Road-Map (MVP → v1.0)

1. **MVP**

   * Single provider, manual API key, hotkey, single mic, final-only transcription.
2. **v0.2**

   * Streaming partials, mic priority list, prompt customisation.
3. **v0.3**

   * Multiple keys & models, status-bar preferences.
4. **v1.0**

   * Accessibility “dictation replacement” polish, auto-update (Sparkle).

---

### 10. Open-Source Checklist

| Item                | Action                                                                  |
| ------------------- | ----------------------------------------------------------------------- |
| **License**         | `LICENSE` MIT.                                                          |
| **README**          | Screenshots/GIF, quick-start, provider signup links, privacy statement. |
| **CONTRIBUTING.md** | Style-guide, issue labels, PR flow.                                     |
| **CODEOWNERS**      | `@you` for all paths.                                                   |
| **Examples**        | Scripts to post-process transcript to Markdown.                         |

---

### 11. Sample Snippets (for Claude-Code kick-off)

```swift
// MARK: - Toggle action
@MainActor
func toggleRecording() {
    if recording {
        try? captureEngine.stop()
    } else {
        try? captureEngine.start(device: deviceManager.preferredDevice)
    }
    recording.toggle()
}

// MARK: - Provider Protocol
protocol STTProvider {
    func transcribe(stream: AsyncThrowingStream<Data, Error>,
                    config: ProviderConfig) async throws -> AsyncStream<TranscriptionChunk>
}
```

---

### 12. Risks & Mitigations

| Risk                                              | Mitigation                                                     |
| ------------------------------------------------- | -------------------------------------------------------------- |
| Provider rate-limits / outages                    | Exponential back-off + fallback to second key (if configured). |
| Keyboard event insertion blocked in secure fields | Detect `AXTextFieldProtected` and use NSPasteboard + alert.    |
| High latency on slow links                        | Compress to OPUS 16 kbps; show live timer tooltip.             |

---

> **Summary**: The plan keeps the stack pure-Swift, leans on built-in macOS frameworks, and isolates each concern behind a protocol so additional STT engines or offline modes can drop in without UI changes. Copy this spec into Claude for code generation and you should get a clean, MIT-friendly project scaffold you can grow into a full Dictation replacement. Happy hacking!
