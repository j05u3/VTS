import Foundation
import AppKit
import CoreGraphics

@MainActor
public class TextInjector: ObservableObject {
    @Published public var hasAccessibilityPermission = false
    
    public init() {
        checkAccessibilityPermission()
    }
    
    public func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary)
    }
    
    public func insertText(_ text: String, replaceLastText: String? = nil) {
        guard !text.isEmpty else { return }
        
        print("TextInjector: Attempting to insert text: '\(text)'")
        
        // If we need to replace previous text, delete it first
        if let lastText = replaceLastText, !lastText.isEmpty {
            deleteText(count: lastText.count)
        }
        
        // Try accessibility-based insertion first (most reliable)
        if hasAccessibilityPermission && tryAccessibilityInsertion(text) {
            print("TextInjector: Successfully inserted via accessibility")
            return
        }
        
        // Fallback to CGEvent keyboard simulation
        if tryCGEventInsertion(text) {
            print("TextInjector: Successfully inserted via CGEvent")
            return
        }
        
        // Final fallback to pasteboard + Cmd+V
        tryPasteboardInsertion(text)
        print("TextInjector: Used pasteboard fallback")
    }
    
    private func deleteText(count: Int) {
        guard count > 0 else { return }
        
        print("TextInjector: Deleting \(count) characters")
        
        // Try to select the last characters by using Shift+Left Arrow
        for _ in 0..<count {
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 123, keyDown: true) // Left arrow
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 123, keyDown: false)
            
            keyDown?.flags = .maskShift // Hold shift to select
            keyUp?.flags = .maskShift
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
            usleep(1000) // Small delay between key presses
        }
        
        // Now delete the selected text
        let deleteKeyDown = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: true) // Delete key
        let deleteKeyUp = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: false)
        
        deleteKeyDown?.post(tap: .cghidEventTap)
        deleteKeyUp?.post(tap: .cghidEventTap)
    }
    
    private func tryAccessibilityInsertion(_ text: String) -> Bool {
        guard hasAccessibilityPermission else { return false }
        
        // Get the focused element
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        var focusedElement: CFTypeRef?
        
        let appResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        
        guard appResult == .success,
              let app = focusedApp else { return false }
        
        let elementResult = AXUIElementCopyAttributeValue(
            app as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard elementResult == .success,
              let element = focusedElement else { return false }
        
        // Try to insert text directly
        let insertResult = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        
        return insertResult == .success
    }
    
    private func tryCGEventInsertion(_ text: String) -> Bool {
        // Convert text to UTF-16 for CGEvent
        let utf16Text = Array(text.utf16)
        
        for codeUnit in utf16Text {
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            
            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [codeUnit])
            keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [codeUnit])
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
            // Small delay between characters to prevent issues
            usleep(5000) // 5ms delay
        }
        
        return true
    }
    
    private func tryPasteboardInsertion(_ text: String) {
        // Save current pasteboard content
        let pasteboard = NSPasteboard.general
        let currentContents = pasteboard.string(forType: .string)
        
        // Set our text to pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V
        let vKeyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true) // V key
        let vKeyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        
        vKeyDown?.flags = .maskCommand
        vKeyUp?.flags = .maskCommand
        
        vKeyDown?.post(tap: .cghidEventTap)
        vKeyUp?.post(tap: .cghidEventTap)
        
        // Restore previous pasteboard content after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previousContent = currentContents {
                pasteboard.clearContents()
                pasteboard.setString(previousContent, forType: .string)
            }
        }
    }
    
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        // Check again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAccessibilityPermission()
        }
    }
} 