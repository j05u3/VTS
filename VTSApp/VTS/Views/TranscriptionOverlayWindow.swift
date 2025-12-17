import SwiftUI
import AppKit

// MARK: - Connection State

/// Represents the current connection state of the streaming transcription
public enum ConnectionState: Equatable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int, maxAttempts: Int)
    case error(message: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// A floating, non-activating overlay window that displays live transcription
/// without stealing focus from the user's active application.
@MainActor
public class TranscriptionOverlayWindow: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published public var currentText: String = ""
    @Published public var isVisible: Bool = false
    @Published public var audioLevel: Float = 0.0
    /// Progress of inactivity timeout (1.0 = full time remaining, 0.0 = about to auto-stop)
    @Published public var inactivityTimeoutProgress: Double = 1.0
    /// Current connection state for the streaming session
    @Published public var connectionState: ConnectionState = .idle

    // MARK: - Configuration
    @Published public var hotkeyString: String = "⌘⇧;"

    // MARK: - Callbacks
    /// Called when user clicks X button to cancel transcription
    public var onClose: (() -> Void)?
    /// Called when user clicks clear button to restart stream
    public var onClear: (() -> Void)?
    /// Called when user clicks finish button to accept transcription
    public var onFinish: (() -> Void)?

    // MARK: - Private Properties
    private var panel: NSPanel?
    private let windowWidth: CGFloat = 400
    private let windowHeight: CGFloat = 160

    // UserDefaults key for per-monitor position persistence
    // Stores: [screenIdentifier: [x: Double, y: Double]]
    private let positionsKey = "TranscriptionOverlay.positions"

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    deinit {
        // Remove NotificationCenter observer to prevent memory leak
        if let panel = panel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
        }
        panel?.close()
    }

    // MARK: - Public Methods

    /// Shows the overlay window with empty text
    public func show() {
        if panel == nil {
            createPanel()
        }

        reset()  // Clear text for new session

        // Reposition on the currently active monitor each time
        if let panel = panel {
            positionPanel(panel)
        }

        isVisible = true
        panel?.orderFrontRegardless()
    }

    /// Hides the overlay window without clearing text
    /// Use reset() to explicitly clear text when starting a new session
    public func hide() {
        isVisible = false
        panel?.orderOut(nil)
    }

    /// Resets the overlay state, clearing all text
    /// Called automatically by show() for new sessions
    public func reset() {
        currentText = ""
        connectionState = .connecting  // Start in connecting state for new sessions
    }

    /// Updates the displayed transcription text
    public func updateText(_ text: String) {
        currentText = text
    }

    /// Returns the final text and hides the window
    public func finalizeAndHide() -> String {
        let finalText = currentText
        reset()  // Clear text before hiding
        hide()
        return finalText
    }

    /// Copies current text to clipboard
    public func copyToClipboard() {
        guard !currentText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentText, forType: .string)
        print("📺 TranscriptionOverlay: Text copied to clipboard")
    }

    // MARK: - Private Methods

    private func createPanel() {
        // Create a non-activating panel that floats above other windows
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel behavior
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        // Prevent the panel from becoming key or main
        panel.becomesKeyOnlyIfNeeded = true

        // Set initial position (center of screen or saved position)
        positionPanel(panel)

        // Create SwiftUI content view
        let contentView = TranscriptionOverlayView(overlay: self)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView

        // Save position when window moves
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        // Get the currently active screen (where user is focused)
        let activeScreen = getActiveScreen()
        let screenId = screenIdentifier(for: activeScreen)
        let screenFrame = activeScreen.visibleFrame

        // Try to restore saved position for this specific screen
        if let savedPosition = getSavedPosition(for: screenId) {
            // Validate position is still within this screen's bounds
            let testPoint = NSPoint(x: savedPosition.x, y: savedPosition.y)
            if screenFrame.contains(testPoint) {
                panel.setFrameOrigin(savedPosition)
                return
            }
        }

        // Default: center on the active screen
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.midY - windowHeight / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }

        // Determine which screen the panel is now on
        let panelCenter = NSPoint(
            x: panel.frame.midX,
            y: panel.frame.midY
        )

        // Find the screen containing the panel's center
        let screen = NSScreen.screens.first { $0.frame.contains(panelCenter) } ?? NSScreen.main ?? NSScreen.screens.first!
        let screenId = screenIdentifier(for: screen)

        // Save position for this screen
        savePosition(panel.frame.origin, for: screenId)
    }

    // MARK: - Screen Detection Helpers

    /// Returns the screen where the user is currently focused
    /// Priority: frontmost app's key window screen > mouse location screen > main screen
    private func getActiveScreen() -> NSScreen {
        // Try to get the screen of the frontmost application's key window
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {

            // Find windows belonging to the frontmost app
            for windowInfo in windows {
                guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                      ownerPID == frontApp.processIdentifier,
                      let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                      let windowX = boundsDict["X"],
                      let windowY = boundsDict["Y"],
                      let windowW = boundsDict["Width"],
                      let windowH = boundsDict["Height"],
                      windowW > 0 && windowH > 0 else { continue }

                // Convert to NSScreen coordinates (flip Y axis)
                let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
                let windowCenter = NSPoint(
                    x: windowX + windowW / 2,
                    y: primaryScreenHeight - (windowY + windowH / 2)
                )

                // Find screen containing this window
                if let screen = NSScreen.screens.first(where: { $0.frame.contains(windowCenter) }) {
                    return screen
                }
            }
        }

        // Fallback: use the screen containing the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen
        }

        // Last resort: main screen
        return NSScreen.main ?? NSScreen.screens.first!
    }

    /// Creates a unique identifier for a screen based on its display ID
    private func screenIdentifier(for screen: NSScreen) -> String {
        if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return "display-\(displayID)"
        }
        // Fallback: use frame description (less stable but works)
        return "screen-\(Int(screen.frame.origin.x))-\(Int(screen.frame.origin.y))"
    }

    // MARK: - Position Persistence Helpers

    private func getSavedPosition(for screenId: String) -> NSPoint? {
        guard let positions = UserDefaults.standard.dictionary(forKey: positionsKey),
              let screenPosition = positions[screenId] as? [String: Double],
              let x = screenPosition["x"],
              let y = screenPosition["y"] else {
            return nil
        }
        return NSPoint(x: x, y: y)
    }

    private func savePosition(_ position: NSPoint, for screenId: String) {
        var positions = UserDefaults.standard.dictionary(forKey: positionsKey) ?? [:]
        positions[screenId] = ["x": position.x, "y": position.y]
        UserDefaults.standard.set(positions, forKey: positionsKey)
    }
}

// MARK: - SwiftUI Overlay View

struct TranscriptionOverlayView: View {
    @ObservedObject var overlay: TranscriptionOverlayWindow
    @State private var showCopyFeedback = false
    @State private var isCloseHovered = false
    @State private var isClearHovered = false
    @State private var isCopyHovered = false
    @State private var isFinishHovered = false
    @State private var lastTextLength = 0
    @State private var lastUpdateTime = Date()

    /// Color for the inactivity timeout progress bar - stages: gray → orange → red
    private var progressBarColor: Color {
        let progress = overlay.inactivityTimeoutProgress
        if progress > 0.3 {
            // Normal: subtle gray
            return Color.secondary.opacity(0.3)
        } else if progress > 0.1 {
            // Warning: orange
            return Color.orange.opacity(0.6)
        } else {
            // Critical: red
            return Color.red.opacity(0.7)
        }
    }

    /// Calculate scroll animation duration based on speech rate
    private func scrollDuration(for newText: String) -> Double {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)
        let charsDelta = newText.count - lastTextLength
        if elapsed > 0 && charsDelta > 0 {
            let charsPerSecond = Double(charsDelta) / elapsed
            return max(0.15, min(0.35, 0.4 - (charsPerSecond / 100)))
        }
        return 0.25
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main transcription area - text can flow up behind floating header
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(overlay.currentText.isEmpty ? " " : overlay.currentText)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.primary.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("transcriptionText")

                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: overlay.currentText) { oldValue, newValue in
                        let duration = scrollDuration(for: newValue)
                        lastTextLength = newValue.count
                        lastUpdateTime = Date()
                        withAnimation(.spring(response: duration, dampingFraction: 0.85)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }

                // Progress bar - thin line just above hint bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * overlay.inactivityTimeoutProgress, height: 2)
                        .animation(.linear(duration: 0.5), value: overlay.inactivityTimeoutProgress)
                }
                .frame(height: 2)

                // Hint bar at bottom
                HStack(spacing: 0) {
                    // Left group: Copy + Clear buttons
                    HStack(spacing: 10) {
                        // Copy button with hover state
                        Button(action: {
                            overlay.copyToClipboard()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopyFeedback = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCopyFeedback = false
                                }
                            }
                        }) {
                            Image(systemName: showCopyFeedback ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(showCopyFeedback ? .green : (isCopyHovered ? .secondary.opacity(0.9) : .secondary.opacity(0.6)))
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isCopyHovered = hovering
                            }
                        }

                        // Clear/restart button
                        Button(action: {
                            overlay.onClear?()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isClearHovered ? .secondary.opacity(0.9) : .secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .help("Clear and restart transcription")
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isClearHovered = hovering
                            }
                        }
                    }

                    Spacer()

                    // Center: Connection status or VTS branding
                    ConnectionStatusView(
                        connectionState: overlay.connectionState,
                        audioLevel: overlay.audioLevel
                    )

                    Spacer()

                    // Right: Finish button
                    Button(action: {
                        overlay.onFinish?()
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isFinishHovered ? .green.opacity(0.9) : .secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Finish and insert text (\(overlay.hotkeyString))")
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isFinishHovered = hovering
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.03))
            }

            // Floating close button (top-left only)
            VStack {
                HStack {
                    Button(action: {
                        overlay.onClose?()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(isCloseHovered ? .primary.opacity(0.7) : .secondary.opacity(0.5))
                            .padding(5)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .opacity(isCloseHovered ? 1.0 : 0.7)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Cancel transcription (discard text)")
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isCloseHovered = hovering
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)

                Spacer()
            }
        }
        .frame(width: 400, height: 160)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// MARK: - SwiftUI Preview

#Preview("Transcription Overlay") {
    let overlay = TranscriptionOverlayWindow()
    overlay.currentText = "This is a sample transcription text that demonstrates how the overlay looks with some content..."
    overlay.hotkeyString = "⌘⇧;"
    return TranscriptionOverlayView(overlay: overlay)
        .frame(width: 400, height: 160)
}

// MARK: - Visual Effect Blur (NSVisualEffectView wrapper)

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Connection Status View

/// Shows connection state or VTS branding when connected
struct ConnectionStatusView: View {
    let connectionState: ConnectionState
    let audioLevel: Float

    @State private var isPulsing = false

    var body: some View {
        Group {
            switch connectionState {
            case .idle:
                // Shouldn't normally be visible, but show branding
                vtsBranding

            case .connecting:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Connecting...")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }

            case .connected:
                vtsBranding

            case .reconnecting(let attempt, let maxAttempts):
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Reconnecting (\(attempt)/\(maxAttempts))...")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.orange.opacity(0.8))
                }

            case .error(let message):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.8))
                    Text(message)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.red.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: connectionState)
    }

    private var vtsBranding: some View {
        HStack(spacing: 5) {
            OverlayAudioWaveform(audioLevel: audioLevel)
            Text("VTS")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.5))
        }
    }
}

// MARK: - Overlay Audio Waveform

/// A minimal, ghost-style audio level indicator for the overlay header
struct OverlayAudioWaveform: View {
    let audioLevel: Float

    private let barCount = 5
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 1.5
    private let maxBarHeight: CGFloat = 10

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: barWidth, height: maxBarHeight)
                    .scaleEffect(y: barScale(for: index), anchor: .center)
                    .animation(.easeInOut(duration: 0.08), value: audioLevel)
            }
        }
        .frame(height: maxBarHeight)
    }

    private func barScale(for index: Int) -> CGFloat {
        // Create a wave pattern where middle bars are taller
        let middleIndex = CGFloat(barCount - 1) / 2.0
        let distanceFromMiddle = abs(CGFloat(index) - middleIndex)
        let baseScale = 1.0 - (distanceFromMiddle / middleIndex) * 0.4

        // Scale based on audio level
        let adjustedLevel = min(max(CGFloat(audioLevel) * 1.8, 0.0), 1.0)

        if adjustedLevel > 0.01 {
            // Active: animate based on level with wave pattern
            let levelScale = 0.25 + (adjustedLevel * 0.75 * baseScale)
            return levelScale
        } else {
            // Idle: show minimal bars
            return 0.15
        }
    }

    private func barColor(for index: Int) -> Color {
        let adjustedLevel = min(max(CGFloat(audioLevel) * 1.8, 0.0), 1.0)

        if adjustedLevel > 0.01 {
            // Active: subtle white/gray that gets brighter with level
            let opacity = 0.35 + (adjustedLevel * 0.45)
            return Color.secondary.opacity(opacity)
        } else {
            // Idle: very subtle gray
            return Color.secondary.opacity(0.2)
        }
    }
}
