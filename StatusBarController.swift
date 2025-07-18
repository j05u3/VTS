import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
public class StatusBarController: ObservableObject {
    private var statusBarItem: NSStatusItem?
    private var popover: NSPopover?
    
    @Published public var isRecording = false
    @Published public var isProcessing = false
    
    public var onToggleRecording: (() -> Void)?
    public var onCopyLastTranscription: (() -> Void)?
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
        guard let transcriptionService = transcriptionService else { return "Last" }
        
        let lastTranscription = transcriptionService.lastTranscription
        
        if lastTranscription.isEmpty {
            return "Last"
        }
        
        // Take first 6 characters, but handle shorter strings gracefully
        let preview = String(lastTranscription.prefix(6))
        return preview.isEmpty ? "Last" : preview
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
        
        // Recording toggle
        let recordingTitle: String
        switch (isRecording, isProcessing) {
            case (true, _):
                recordingTitle = "⏹ Stop Recording"
            case (false, true):
                recordingTitle = "🔴 Start Recording (Processing audio...)"
            case (false, false):
                recordingTitle = "🔴 Start Voice Recording"
        }
        
        let recordingItem = NSMenuItem(
            title: recordingTitle,
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        recordingItem.target = self
        menu.addItem(recordingItem)
        
        // Copy last transcription
        let copyItem = NSMenuItem(
            title: "📋 Copy Last Text (\(hotkeyManager.currentCopyHotkeyString))",
            action: #selector(copyLastTranscription),
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
              let button = statusBarItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    @objc private func toggleRecording() {
        onToggleRecording?()
    }
    
    @objc private func copyLastTranscription() {
        onCopyLastTranscription?()
    }
    
    @objc private func showPreferences() {
        // Close popover if open
        popover?.performClose(nil)
        onShowPreferences?()
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "VTS Service"
        alert.informativeText = "Version 0.2.0\n\nA modern macOS speech-to-text application that converts your voice to text using AI-powered transcription services from OpenAI and Groq.\n\nQuick Start:\n• Press ⌘⇧; to start/stop recording\n• Set up your API keys in Settings\n• Speak naturally and watch your words appear!"
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
        
        // Priority: Recording > Processing > Idle
        if isRecording {
            button.title = "🔴"
            button.toolTip = "VTS is recording audio - Click to stop (\(hotkey))"
        } else if isProcessing {
            button.title = "🔵"
            button.toolTip = "VTS is processing audio - Click to view progress (\(hotkey))"
        } else {
            button.title = "⚪️"
            button.toolTip = "VTS is ready - Click to start recording (\(hotkey))"
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
