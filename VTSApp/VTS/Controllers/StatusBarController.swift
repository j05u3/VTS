import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
public class StatusBarController: ObservableObject {
    private var statusBarItem: NSStatusItem?
    private var popover: NSPopover?

    @Published public var isRecording = false
    @Published public var isProcessing = false

    public var onToggleRecording: (() -> Void)?
    public var onShowLastTranscription: (() -> Void)?
    public var onShowPreferences: (() -> Void)?
    public var onQuit: (() -> Void)?

    // Reference to hotkey manager for dynamic tooltips
    private let hotkeyManager = SimpleHotkeyManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Reference to transcription service for context menu
    private weak var transcriptionService: TranscriptionService?

    public init() {
        // Don't setup status bar in init - will be called later when app is ready
    }

    public func initialize() {
        setupStatusBar()
        setupPopover()
        setupHotkeyObservation()
    }

    public func setTranscriptionService(_ service: TranscriptionService) {
        transcriptionService = service
    }

    private func getTranscriptionPreview() -> String {
        let lastTranscription = transcriptionService?.lastTranscription ?? ""

        if lastTranscription.isEmpty {
            return "Last Text"
        }

        // Take first n characters and add ellipsis if truncated
        let n = 11
        let preview = String(lastTranscription.prefix(n))
        return "\"\(lastTranscription.count > n ? preview + "…" : preview)\""
    }

    private func setupHotkeyObservation() {
        // Update status bar tooltips when hotkey changes
        hotkeyManager.$currentHotkeyString
            .sink { [weak self] _ in
                self?.updateStatusBarIcon()
            }
            .store(in: &cancellables)
    }

    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusBarItem = statusBarItem else { return }

        if let button = statusBarItem.button {
            updateStatusBarIcon()
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 500, height: 600)
        popover?.behavior = .transient
        popover?.animates = true
    }

    public func setPopoverContent<Content: View>(@ViewBuilder content: () -> Content) {
        let hostingController = NSHostingController(rootView: content())
        popover?.contentViewController = hostingController
    }

    @objc private func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        // Copy last transcription
        let copyItem = NSMenuItem(
            title: "📋 Show \(getTranscriptionPreview())",
            action: #selector(showLastTranscription),
            keyEquivalent: ""
        )
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let preferencesItem = NSMenuItem(
            title: "⚙️ Settings...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(
            title: "ℹ️ About VTS",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(
            title: "🚪 Quit VTS",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusBarItem?.menu = menu
        statusBarItem?.button?.performClick(nil)
        statusBarItem?.menu = nil
    }

    private func togglePopover() {
        guard let popover = popover,
            let button = statusBarItem?.button
        else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func toggleRecording() {
        onToggleRecording?()
    }

    @objc private func showLastTranscription() {
        onShowLastTranscription?()
    }

    @objc private func showPreferences() {
        // Close popover if open
        popover?.performClose(nil)
        onShowPreferences?()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "VTS"

        // Get version from Bundle
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        // Get current hotkey from manager
        let hotkeyString = hotkeyManager.currentHotkeyString

        alert.informativeText =
            "Version \(version)\n\nA modern macOS speech-to-text application that converts your voice to text using AI-powered transcription services from OpenAI, Groq, and Deepgram.\n\nQuick Start:\n• Press \(hotkeyString) to start/stop recording\n• Set up your API keys in Settings\n• Speak naturally and watch your words appear!"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quit() {
        onQuit?()
    }

    public func updateRecordingState(_ recording: Bool) {
        isRecording = recording
        updateStatusBarIcon()
    }

    public func updateProcessingState(_ processing: Bool) {
        isProcessing = processing
        updateStatusBarIcon()
    }

    private func updateStatusBarIcon() {
        guard let button = statusBarItem?.button else { return }

        let hotkey = hotkeyManager.currentHotkeyString

        // Clear any existing title text
        button.title = ""

        // Priority: Recording > Processing > Idle
        if isRecording {
            button.image = NSImage(named: "StatusIconRecording")
            button.toolTip = "VTS is recording audio - Press \(hotkey) to stop"
        } else if isProcessing {
            button.image = NSImage(named: "StatusIconProcessing")
            button.toolTip = "VTS is processing audio"
        } else {
            button.image = NSImage(named: "StatusIcon")
            button.toolTip = "VTS is ready - Press \(hotkey) to start recording"
        }
        
        // Ensure the image is properly sized for the status bar
        if let image = button.image {
            // Use template rendering for idle state to adapt to menu bar theme,
            // but not for colored states to preserve their specific colors
            image.isTemplate = !isRecording && !isProcessing
            image.size = NSSize(width: 18, height: 18)
        }
    }

    public func hidePopover() {
        popover?.performClose(nil)
    }

    deinit {
        if let statusBarItem = statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItem)
        }
    }
}
