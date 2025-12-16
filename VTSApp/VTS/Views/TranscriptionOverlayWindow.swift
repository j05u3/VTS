import SwiftUI
import AppKit

/// A floating, non-activating overlay window that displays live transcription
/// without stealing focus from the user's active application.
@MainActor
public class TranscriptionOverlayWindow: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published public var currentText: String = ""
    @Published public var isVisible: Bool = false

    // MARK: - Configuration
    @Published public var hotkeyString: String = "⌘⇧;"

    // MARK: - Private Properties
    private var panel: NSPanel?
    private let windowWidth: CGFloat = 400
    private let windowHeight: CGFloat = 160

    // UserDefaults keys for position persistence
    private let positionXKey = "TranscriptionOverlay.positionX"
    private let positionYKey = "TranscriptionOverlay.positionY"

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
        // Try to restore saved position
        let savedX = UserDefaults.standard.double(forKey: positionXKey)
        let savedY = UserDefaults.standard.double(forKey: positionYKey)

        if savedX != 0 || savedY != 0 {
            // Validate that position is still on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                if screenFrame.contains(NSPoint(x: savedX, y: savedY)) {
                    panel.setFrameOrigin(NSPoint(x: savedX, y: savedY))
                    return
                }
            }
        }

        // Default: center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.midY - windowHeight / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: positionXKey)
        UserDefaults.standard.set(origin.y, forKey: positionYKey)
    }
}

// MARK: - SwiftUI Overlay View

struct TranscriptionOverlayView: View {
    @ObservedObject var overlay: TranscriptionOverlayWindow
    @State private var showCopyFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            // Main transcription area
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(overlay.currentText.isEmpty ? " " : overlay.currentText)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.primary.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("transcriptionText")

                        // Invisible anchor at bottom for auto-scroll
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .onChange(of: overlay.currentText) { _, _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Hint bar at bottom
            HStack {
                // Copy button on left with feedback
                Button(action: {
                    overlay.copyToClipboard()
                    // Show checkmark feedback
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopyFeedback = true
                    }
                    // Reset after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopyFeedback = false
                        }
                    }
                }) {
                    Image(systemName: showCopyFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(showCopyFeedback ? .green : .secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")

                Spacer()

                // Hotkey hint on right
                HStack(spacing: 4) {
                    Text(overlay.hotkeyString)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text("to finish")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.03))
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
