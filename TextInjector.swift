import Foundation
import AppKit
import CoreGraphics
import Combine

@MainActor
public class TextInjector: ObservableObject {
    @Published public private(set) var hasAccessibilityPermission = false
    
    public init() {
        updatePermissionStatus()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePermissionStatus()
            }
        }
    }
    
    public func updatePermissionStatus() {
        let wasGranted = hasAccessibilityPermission
        
        // Safe permission check without prompting
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: false as CFBoolean
        ] as CFDictionary
        
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
        
        if hasAccessibilityPermission != wasGranted {
            print("TextInjector: Permission status changed to: \(hasAccessibilityPermission)")
            // Ensure UI updates by explicitly sending change notification
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    public func refreshPermissionStatus() {
        print("TextInjector: Manually refreshing permission status...")
        updatePermissionStatus()
    }
    
    public func requestAccessibilityPermission() {
        print("TextInjector: Requesting accessibility permission...")
        
        // Check current status
        updatePermissionStatus()
        if hasAccessibilityPermission {
            print("TextInjector: Already have permission")
            return
        }
        
        // Request permission with system prompt (dialog)
        let promptOptions = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: true as CFBoolean
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(promptOptions)
        
        // Start monitoring for permission changes
        startMonitoring()
    }
    


    private func openSystemSettings() {
        // Try the new System Settings first (macOS 13+)
        let newSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        
        // Also try the old System Preferences format as fallback
        let oldSettingsURL = URL(string: "x-apple.systempreferences:com.apple.SystemProfiler.AboutProfiler")!
        
        if NSWorkspace.shared.open(newSettingsURL) {
            print("TextInjector: Opened System Settings (new format)")
        } else if NSWorkspace.shared.open(oldSettingsURL) {
            print("TextInjector: Opened System Preferences (legacy format)")
        } else {
            print("TextInjector: Failed to open System Settings")
        }
    }
    

    

    
    private func startMonitoring() {
        print("TextInjector: Starting permission monitoring...")
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                self.updatePermissionStatus()
                
                if self.hasAccessibilityPermission {
                    print("TextInjector: Permission granted!")
                    timer.invalidate()
                }
            }
        }
    }
    
    public func injectText(_ text: String, replaceLastText: String? = nil) {
        guard hasAccessibilityPermission else {
            print("TextInjector: No accessibility permission - cannot inject text")
            return
        }
        
        print("TextInjector: Injecting text: '\(text)'" + (replaceLastText != nil ? " (replacing: '\(replaceLastText!)')" : ""))
        
        // Delete previous text if needed
        if let lastText = replaceLastText, !lastText.isEmpty {
            deleteText(count: lastText.count)
        }
        
        // Try accessibility API first
        if tryAccessibilityInsertion(text) {
            print("TextInjector: Successfully injected via Accessibility API")
            return
        }
        
        // Fallback to clipboard method
        print("TextInjector: Using clipboard fallback")
        useClipboardFallback(text)
    }
    
    private func deleteText(count: Int) {
        guard count > 0 else { return }
        
        print("TextInjector: Deleting \(count) characters")
        
        // Try accessibility deletion first
        if tryAccessibilityDeletion(count: count) {
            return
        }
        
        // Fallback to keyboard simulation
        for _ in 0..<count {
            let deleteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: true)
            deleteEvent?.post(tap: .cghidEventTap)
            let deleteUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: false)
            deleteUpEvent?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
    
    private func tryAccessibilityDeletion(count: Int) -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let app = focusedApp else { return false }
        
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else { return false }
        
        // Get current value and remove last 'count' characters
        var currentValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &currentValue) == .success,
              let currentText = currentValue as? String,
              currentText.count >= count else { return false }
        
        let newText = String(currentText.dropLast(count))
        let newValue = newText as CFString
        return AXUIElementSetAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, newValue) == .success
    }
    
    private func tryAccessibilityInsertion(_ text: String) -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let app = focusedApp else { return false }
        
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else { return false }
        
        // Try to set the value directly
        let textValue = text as CFString
        if AXUIElementSetAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, textValue) == .success {
            return true
        }
        
        // Try to set selected text
        var selectedRange: CFTypeRef?
        if AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success {
            return AXUIElementSetAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, textValue) == .success
        }
        
        return false
    }
    
    private func useClipboardFallback(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        
        // Set our text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        cmdVDown?.flags = .maskCommand
        cmdVUp?.flags = .maskCommand
        
        cmdVDown?.post(tap: .cghidEventTap)
        cmdVUp?.post(tap: .cghidEventTap)
        
        // Restore clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}