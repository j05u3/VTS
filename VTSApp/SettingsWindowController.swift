import SwiftUI
import AppKit

@MainActor
class SettingsWindowController: NSWindowController {
    private var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        super.init(window: nil)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let preferencesView = PreferencesView(apiKeyManager: appState.apiKeyManagerService)
            .environmentObject(appState)
        
        let hostingController = NSHostingController(rootView: preferencesView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "VTS Settings"
        newWindow.contentViewController = hostingController
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        
        // Set minimum size to prevent UI issues
        newWindow.minSize = NSSize(width: 500, height: 400)
        
        // Set the window using the inherited property
        self.window = newWindow
    }
    
    func showWindow() {
        if window == nil {
            setupWindow()
        }
        
        // Ensure the window is visible and brought to front
        window?.makeKeyAndOrderFront(nil)
        
        // Make sure the window is not minimized
        if window?.isMiniaturized == true {
            window?.deminiaturize(nil)
        }
        
        // Bring the window to the front of all windows
        window?.orderFrontRegardless()
        
        // Activate the app and make it the frontmost application
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeWindow() {
        window?.close()
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }
    
    deinit {
        window?.delegate = nil
    }
}

// MARK: - NSWindowDelegate
extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Clean up when window closes
        window?.delegate = nil
        
        // Notify AppState to clean up its reference
        appState.settingsWindowDidClose()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure window is properly focused when it becomes key
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Handle when window loses focus if needed
    }
} 