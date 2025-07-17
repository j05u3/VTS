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
    
    // Store content until popover is ready
    private var pendingPopoverContent: NSHostingController<AnyView>?
    
    public init() {
        // Don't setup status bar in init - will be called later when app is ready
    }
    
    public func initialize() {
        print("🚀 StatusBarController: Starting initialization...")
        
        setupStatusBar()
        setupPopover()
        setupHotkeyObservation()
        
        // Validate initialization
        validateInitialization()
        
        print("✅ StatusBarController: Initialization completed successfully")
    }
    
    private func validateInitialization() {
        var issues: [String] = []
        
        if statusBarItem == nil {
            issues.append("Status bar item not created")
        }
        
        if popover == nil {
            issues.append("Popover not created")
        } else if popover?.contentViewController == nil {
            if pendingPopoverContent != nil {
                issues.append("Pending popover content was not applied - check applyPendingContent() logic")
            } else {
                issues.append("Popover contentViewController not set - call setPopoverContent() first")
            }
        }
        
        if !issues.isEmpty {
            print("⚠️ StatusBarController: Initialization issues detected:")
            for issue in issues {
                print("  - \(issue)")
            }
        } else {
            print("✅ StatusBarController: All components properly initialized")
        }
    }
    
    public func setTranscriptionService(_ service: TranscriptionService) {
        transcriptionService = service
        print("📝 StatusBarController: Transcription service configured")
    }
    
    /// Modern configuration method that ensures proper initialization order
    /// Call this method with all dependencies before calling initialize()
    public func configure<Content: View>(
        transcriptionService: TranscriptionService,
        @ViewBuilder popoverContent: () -> Content
    ) {
        print("⚙️ StatusBarController: Starting configuration...")
        
        // Set dependencies - order doesn't matter now with deferred content application
        setTranscriptionService(transcriptionService)
        setPopoverContent(content: popoverContent)
        
        print("✅ StatusBarController: Configuration completed - content will be applied during initialization")
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
        print("🎯 StatusBarController: Setting up status bar...")
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusBarItem = statusBarItem else { 
            print("❌ StatusBarController: Failed to create status bar item")
            return 
        }
        
        guard let button = statusBarItem.button else {
            print("❌ StatusBarController: Status bar item has no button")
            return
        }
        
        // Configure button with modern patterns
        button.action = #selector(statusBarButtonClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Set initial state
        updateStatusBarIcon()
        
        print("✅ StatusBarController: Status bar configured successfully")
    }
    
    private func setupPopover() {
        print("📱 StatusBarController: Setting up popover...")
        
        popover = NSPopover()
        
        guard let popover = popover else {
            print("❌ StatusBarController: Failed to create popover")
            return
        }
        
        // Configure popover with modern macOS guidelines
        popover.contentSize = NSSize(width: 500, height: 600)
        popover.behavior = .transient  // Closes when clicking outside
        popover.animates = true
        
        // Modern macOS appearance
        if #available(macOS 10.14, *) {
            popover.appearance = NSAppearance(named: .aqua)
        }
        
        // Apply any pending content now that popover is ready
        if pendingPopoverContent != nil {
            applyPendingContent()
        }
        
        print("✅ StatusBarController: Popover configured successfully")
    }
    
    public func setPopoverContent<Content: View>(@ViewBuilder content: () -> Content) {
        // Create hosting controller immediately (avoids escaping closure issue)
        let hostingController = NSHostingController(rootView: AnyView(content()))
        pendingPopoverContent = hostingController
        
        // If popover exists, apply content immediately
        if let popover = popover {
            applyPendingContent()
        } else {
            print("📝 StatusBarController: Popover content stored for later application")
        }
    }
    
    private func applyPendingContent() {
        guard let popover = popover,
              let hostingController = pendingPopoverContent else {
            print("⚠️ StatusBarController: Cannot apply content - missing popover or content")
            return
        }
        
        hostingController.view.setFrameSize(popover.contentSize)
        popover.contentViewController = hostingController
        
        // Clear pending content after successful application
        pendingPopoverContent = nil
        
        print("✅ StatusBarController: Popover content applied successfully")
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
                recordingTitle = "Stop Recording"
            case (false, true):
                recordingTitle = "Start Recording (Processing...)"
            case (false, false):
                recordingTitle = "Start Recording"
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
            title: "Copy \(getTranscriptionPreview()) (\(hotkeyManager.currentCopyHotkeyString))",
            action: #selector(copyLastTranscription),
            keyEquivalent: ""
        )
        copyItem.target = self
        menu.addItem(copyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Preferences
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About
        let aboutItem = NSMenuItem(
            title: "About VTS",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit VTS",
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
              let button = statusBarItem?.button else { 
            print("⚠️ StatusBarController: Cannot toggle popover - missing popover or button")
            return 
        }
        
        if popover.isShown {
            print("📱 StatusBarController: Closing popover")
            popover.performClose(nil)
        } else {
            // Verify contentViewController is set before showing
            guard popover.contentViewController != nil else {
                print("❌ StatusBarController: Cannot show popover - contentViewController is nil")
                print("💡 Hint: Ensure setPopoverContent() was called before initialize()")
                return
            }
            
            print("📱 StatusBarController: Showing popover")
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
        alert.messageText = "VTS - Voice to Text Service"
        alert.informativeText = "v0.2.0\n\nA modern macOS speech-to-text application that provides real-time transcription using OpenAI and Groq APIs.\n\nGlobal Hotkey: ⌘⇧;"
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
            button.toolTip = "VTS is recording - Click to stop (\(hotkey))"
        } else if isProcessing {
            button.title = "🔵"
            button.toolTip = "VTS is processing audio - Click to view (\(hotkey))"
        } else {
            button.title = "⚪️"
            button.toolTip = "VTS is idle - Click to start recording (\(hotkey))"
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
