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
    
    public func checkPermissionStatus() {
        print("🔍 TextInjector: Checking accessibility permission status...")
        
        // Safe permission check without prompting
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: false as CFBoolean
        ] as CFDictionary
        
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        print("📋 TextInjector: Current permission status: \(hasPermission ? "✅ GRANTED" : "❌ DENIED")")
        
        if !hasPermission {
            print("🚫 TextInjector: Accessibility permission is required for text injection")
            print("📖 TextInjector: To grant permission:")
            print("   1. Open System Settings")
            print("   2. Go to Privacy & Security")
            print("   3. Click on Accessibility")
            print("   4. Find 'VTS' in the list and enable it")
            print("   5. If VTS is not in the list, click the '+' button to add it")
        } else {
            print("🎉 TextInjector: Accessibility permission is properly configured!")
        }
        
        // Update our internal state
        hasAccessibilityPermission = hasPermission
    }
    
    public func testTextInjection() {
        print("🧪 TextInjector: Starting test injection...")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            print("🧪 TextInjector: Attempting test injection in 3 seconds...")
            print("🧪 TextInjector: Please focus on a text field now!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.injectText("Hello from VTS!")
            }
        } else {
            print("🧪 TextInjector: Cannot test - no accessibility permission")
        }
    }
    
    public func testCursorInjection() {
        print("🧪 TextInjector: Starting Cursor-specific test injection...")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            print("🧪 TextInjector: Attempting Cursor test injection in 3 seconds...")
            print("🧪 TextInjector: Please focus on Cursor chat input now!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                // Force typing simulation for this test with mixed case
                self.simulateTyping("Hello World! Testing VTS typing in Cursor. Mixed CaSe TeXt: 123 ABC def.")
            }
        } else {
            print("🧪 TextInjector: Cannot test - no accessibility permission")
        }
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
            print("❌ TextInjector: No accessibility permission - cannot inject text")
            print("📋 TextInjector: Please grant accessibility permission in System Settings > Privacy & Security > Accessibility")
            return
        }
        
        print("🔄 TextInjector: Starting text injection process...")
        print("📝 TextInjector: Text to inject: '\(text)'")
        if let lastText = replaceLastText {
            print("🔄 TextInjector: Will replace previous text: '\(lastText)'")
        }
        
        // Delete previous text if needed
        if let lastText = replaceLastText, !lastText.isEmpty {
            print("🗑️ TextInjector: Attempting to delete \(lastText.count) characters...")
            deleteText(count: lastText.count)
        }
        
        // Get app info for smart method selection
        let appInfo = getCurrentAppInfo()
        let preferredMethod = getPreferredInjectionMethod(for: appInfo)
        
        print("📱 TextInjector: Target app: \(appInfo.name)")
        print("🎯 TextInjector: Preferred method: \(preferredMethod)")
        
        // Try methods in order of preference
        switch preferredMethod {
        case .accessibility:
            if tryAccessibilityInsertion(text) {
                print("✅ TextInjector: Successfully injected via Accessibility API")
                return
            }
            print("⚠️ TextInjector: Accessibility method failed, trying typing simulation...")
            simulateTyping(text)
            
        case .typing:
            print("⌨️ TextInjector: Using typing simulation for this app...")
            simulateTyping(text)
            
        case .clipboard:
            print("📋 TextInjector: Using clipboard method for this app...")
            useClipboardFallback(text)
        }
    }
    
    private enum InjectionMethod {
        case accessibility
        case typing
        case clipboard
    }
    
    private struct AppInfo {
        let name: String
        let bundleIdentifier: String?
    }
    
    private func getCurrentAppInfo() -> AppInfo {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let app = focusedApp else {
            return AppInfo(name: "Unknown", bundleIdentifier: nil)
        }
        
        // Get app name
        var appNameRef: CFTypeRef?
        let appName: String
        if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXTitleAttribute as CFString, &appNameRef) == .success,
           let name = appNameRef as? String {
            appName = name
        } else {
            appName = "Unknown"
        }
        
        // Try to get bundle identifier
        var bundleIdRef: CFTypeRef?
        let bundleId: String?
        if AXUIElementCopyAttributeValue(app as! AXUIElement, "AXBundleIdentifier" as CFString, &bundleIdRef) == .success,
           let id = bundleIdRef as? String {
            bundleId = id
        } else {
            bundleId = nil
        }
        
        return AppInfo(name: appName, bundleIdentifier: bundleId)
    }
    
    private func getPreferredInjectionMethod(for appInfo: AppInfo) -> InjectionMethod {
        let appName = appInfo.name.lowercased()
        let bundleId = appInfo.bundleIdentifier?.lowercased() ?? ""
        
        // Apps that work best with typing simulation
        let typingPreferredApps = [
            "cursor", "visual studio code", "vscode", "code",
            "discord", "slack", "telegram", "whatsapp",
            "notion", "obsidian", "bear", "ulysses",
            "spotify", "music"
        ]
        
        // Apps that work best with clipboard
        let clipboardPreferredApps = [
            "photoshop", "illustrator", "figma", "sketch",
            "terminal", "iterm", "hyper"
        ]
        
        // Check for Electron apps (often need typing simulation)
        if bundleId.contains("electron") || 
           bundleId.contains("discord") || 
           bundleId.contains("slack") || 
           bundleId.contains("notion") ||
           bundleId.contains("cursor") {
            print("🔍 TextInjector: Detected Electron-based app, preferring typing simulation")
            return .typing
        }
        
        // Check app name patterns
        for preferredApp in typingPreferredApps {
            if appName.contains(preferredApp) {
                print("🔍 TextInjector: App known to work better with typing simulation")
                return .typing
            }
        }
        
        for preferredApp in clipboardPreferredApps {
            if appName.contains(preferredApp) {
                print("🔍 TextInjector: App known to work better with clipboard method")
                return .clipboard
            }
        }
        
        // Default to accessibility API first
        print("🔍 TextInjector: Using default method (accessibility with typing fallback)")
        return .accessibility
    }
    
    private func deleteText(count: Int) {
        guard count > 0 else { return }
        
        print("🗑️ TextInjector: Deleting \(count) characters")
        
        // Try accessibility deletion first
        print("🎯 TextInjector: Attempting accessibility deletion...")
        if tryAccessibilityDeletion(count: count) {
            print("✅ TextInjector: Successfully deleted via Accessibility API")
            return
        }
        
        // Fallback to keyboard simulation
        print("⚠️ TextInjector: Accessibility deletion failed, using keyboard simulation...")
        for _ in 0..<count {
            let deleteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: true)
            deleteEvent?.post(tap: .cghidEventTap)
            let deleteUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: false)
            deleteUpEvent?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.01)
        }
        print("✅ TextInjector: Deletion completed via keyboard simulation")
    }
    
    private func tryAccessibilityDeletion(count: Int) -> Bool {
        print("🔍 TextInjector: Starting accessibility deletion process...")
        
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success, let app = focusedApp else { 
            print("❌ TextInjector: Could not get focused application (error: \(appResult.rawValue))")
            return false
        }
        print("✅ TextInjector: Found focused application")
        
        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard elementResult == .success, let element = focusedElement else { 
            print("❌ TextInjector: Could not get focused element (error: \(elementResult.rawValue))")
            return false
        }
        print("✅ TextInjector: Found focused element")
        
        // Get current value and remove last 'count' characters
        var currentValue: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &currentValue)
        guard valueResult == .success, let currentText = currentValue as? String else {
            print("❌ TextInjector: Could not get current text value (error: \(valueResult.rawValue))")
            return false
        }
        
        print("📝 TextInjector: Current text: '\(currentText)' (length: \(currentText.count))")
        
        guard currentText.count >= count else {
            print("❌ TextInjector: Not enough text to delete (\(currentText.count) < \(count))")
            return false
        }
        
        let newText = String(currentText.dropLast(count))
        print("📝 TextInjector: New text after deletion: '\(newText)'")
        
        let newValue = newText as CFString
        let setResult = AXUIElementSetAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, newValue)
        
        if setResult == .success {
            print("✅ TextInjector: Successfully deleted text via accessibility API")
            return true
        } else {
            print("❌ TextInjector: Failed to set new value (error: \(setResult.rawValue))")
            return false
        }
    }
    
    private func tryAccessibilityInsertion(_ text: String) -> Bool {
        print("🔍 TextInjector: Starting accessibility insertion process...")
        
        let systemWideElement = AXUIElementCreateSystemWide()
        
        // Get focused application
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success, let app = focusedApp else { 
            print("❌ TextInjector: Could not get focused application (error: \(appResult.rawValue))")
            return false
        }
        print("✅ TextInjector: Found focused application")
        
        // Get app name for debugging
        var appNameRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXTitleAttribute as CFString, &appNameRef) == .success,
           let appName = appNameRef as? String {
            print("📱 TextInjector: Application: \(appName)")
        }
        
        // Get focused element
        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard elementResult == .success, let element = focusedElement else { 
            print("❌ TextInjector: Could not get focused element (error: \(elementResult.rawValue))")
            return false
        }
        print("✅ TextInjector: Found focused element")
        
        // Get element info for debugging
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            print("📋 TextInjector: Focused element role: \(role)")
        }
        
        // Get current value before insertion
        var initialValueRef: CFTypeRef?
        let initialValue: String
        if AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &initialValueRef) == .success,
           let currentValue = initialValueRef as? String {
            initialValue = currentValue
            print("📝 TextInjector: Current element value: '\(currentValue)'")
        } else {
            initialValue = ""
            print("📝 TextInjector: Could not read current value, assuming empty")
        }
        
        // Try to set the value directly
        print("🎯 TextInjector: Attempting direct value setting...")
        let textValue = text as CFString
        let directResult = AXUIElementSetAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, textValue)
        if directResult == .success {
            print("✅ TextInjector: Accessibility API reported success")
            
            // Verify the change actually took effect
            if verifyTextInsertion(element: element as! AXUIElement, expectedText: text, originalText: initialValue) {
                print("✅ TextInjector: Verification passed - text actually inserted")
                return true
            } else {
                print("⚠️ TextInjector: Verification failed - accessibility API succeeded but text didn't change")
                print("🔄 TextInjector: App may be ignoring accessibility changes, will try alternative methods")
            }
        } else {
            print("❌ TextInjector: Direct value setting failed (error: \(directResult.rawValue))")
        }
        
        // Try to set selected text
        print("🎯 TextInjector: Attempting selected text replacement...")
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        if rangeResult == .success {
            print("✅ TextInjector: Found selected text range")
            let selectedResult = AXUIElementSetAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, textValue)
            if selectedResult == .success {
                print("✅ TextInjector: Selected text API reported success")
                
                // Verify this method worked
                if verifyTextInsertion(element: element as! AXUIElement, expectedText: text, originalText: initialValue) {
                    print("✅ TextInjector: Verification passed - selected text insertion worked")
                    return true
                } else {
                    print("⚠️ TextInjector: Selected text API succeeded but verification failed")
                }
            } else {
                print("❌ TextInjector: Selected text setting failed (error: \(selectedResult.rawValue))")
            }
        } else {
            print("❌ TextInjector: Could not get selected text range (error: \(rangeResult.rawValue))")
        }
        
        print("❌ TextInjector: All accessibility insertion methods failed or were ignored")
        return false
    }
    
    private func verifyTextInsertion(element: AXUIElement, expectedText: String, originalText: String) -> Bool {
        // Small delay to allow UI to update
        Thread.sleep(forTimeInterval: 0.1)
        
        var currentValueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValueRef) == .success,
              let currentValue = currentValueRef as? String else {
            print("❌ TextInjector: Could not read value for verification")
            return false
        }
        
        print("🔍 TextInjector: Verification - Original: '\(originalText)'")
        print("🔍 TextInjector: Verification - Expected: '\(expectedText)'")
        print("🔍 TextInjector: Verification - Actual: '\(currentValue)'")
        
        // Check if the text was inserted (either replaced completely or appended)
        let textWasInserted = currentValue.contains(expectedText) && currentValue != originalText
        
        if textWasInserted {
            print("✅ TextInjector: Text insertion verified successfully")
            return true
        } else {
            print("❌ TextInjector: Text insertion verification failed")
            return false
        }
    }
    
    private func useClipboardFallback(_ text: String) {
        print("📋 TextInjector: Starting clipboard fallback method...")
        
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        print("📋 TextInjector: Saved previous clipboard contents")
        
        // Set our text to clipboard
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        
        if !success {
            print("❌ TextInjector: Failed to set text to clipboard")
            return
        }
        
        print("✅ TextInjector: Text set to clipboard, simulating Cmd+V...")
        
        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        cmdVDown?.flags = .maskCommand
        cmdVUp?.flags = .maskCommand
        
        cmdVDown?.post(tap: .cghidEventTap)
        cmdVUp?.post(tap: .cghidEventTap)
        
        print("✅ TextInjector: Cmd+V sent, scheduling clipboard restoration...")
        
        // Restore clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
                print("✅ TextInjector: Clipboard restored")
            } else {
                print("📋 TextInjector: No previous clipboard content to restore")
            }
        }
    }
    
    private func simulateTyping(_ text: String) {
        print("⌨️ TextInjector: Starting character-by-character typing simulation...")
        print("⌨️ TextInjector: Will type: '\(text)'")
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        for (index, character) in text.enumerated() {
            print("⌨️ TextInjector: Typing character \(index + 1)/\(text.count): '\(character)' (uppercase: \(character.isUppercase))")
            
            if let keyCode = getKeyCode(for: character) {
                // Handle special characters that need modifiers
                let (virtualKey, needsShift) = keyCode
                
                print("⌨️ TextInjector: Key code: \(virtualKey), needs shift: \(needsShift)")
                
                if needsShift {
                    // For uppercase letters or special characters, we need to handle shift properly
                    
                    // First, press shift down
                    let shiftDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: true) // Left shift
                    shiftDownEvent?.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.01) // Small delay
                    
                    // Then press the key with shift held
                    let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
                    let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
                    
                    keyDownEvent?.flags = .maskShift
                    keyUpEvent?.flags = .maskShift
                    
                    keyDownEvent?.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.01)
                    keyUpEvent?.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.01)
                    
                    // Finally, release shift
                    let shiftUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false) // Left shift
                    shiftUpEvent?.post(tap: .cghidEventTap)
                    
                } else {
                    // For normal characters, just send the key without modifiers
                    let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
                    let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
                    
                    // Explicitly clear any flags to ensure no modifiers
                    keyDownEvent?.flags = []
                    keyUpEvent?.flags = []
                    
                    keyDownEvent?.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.01)
                    keyUpEvent?.post(tap: .cghidEventTap)
                }
                
                // Slightly longer delay between characters to ensure clean typing
                Thread.sleep(forTimeInterval: 0.03)
            } else {
                print("⚠️ TextInjector: Could not map character '\(character)' to key code, skipping")
            }
        }
        
        // Ensure all modifier keys are released at the end
        let finalShiftUp = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false)
        finalShiftUp?.post(tap: .cghidEventTap)
        
        print("✅ TextInjector: Finished typing simulation")
    }
    
    private func getKeyCode(for character: Character) -> (CGKeyCode, Bool)? {
        let char = character.lowercased().first!
        
        // Handle special characters first
        if character == "\n" || character == "\r" {
            return (0x24, false) // Return/Enter key
        }
        if character == "\t" {
            return (0x30, false) // Tab key
        }
        
        switch char {
        // Letters
        case "a": return (0x00, character.isUppercase)
        case "b": return (0x0B, character.isUppercase)
        case "c": return (0x08, character.isUppercase)
        case "d": return (0x02, character.isUppercase)
        case "e": return (0x0E, character.isUppercase)
        case "f": return (0x03, character.isUppercase)
        case "g": return (0x05, character.isUppercase)
        case "h": return (0x04, character.isUppercase)
        case "i": return (0x22, character.isUppercase)
        case "j": return (0x26, character.isUppercase)
        case "k": return (0x28, character.isUppercase)
        case "l": return (0x25, character.isUppercase)
        case "m": return (0x2E, character.isUppercase)
        case "n": return (0x2D, character.isUppercase)
        case "o": return (0x1F, character.isUppercase)
        case "p": return (0x23, character.isUppercase)
        case "q": return (0x0C, character.isUppercase)
        case "r": return (0x0F, character.isUppercase)
        case "s": return (0x01, character.isUppercase)
        case "t": return (0x11, character.isUppercase)
        case "u": return (0x20, character.isUppercase)
        case "v": return (0x09, character.isUppercase)
        case "w": return (0x0D, character.isUppercase)
        case "x": return (0x07, character.isUppercase)
        case "y": return (0x10, character.isUppercase)
        case "z": return (0x06, character.isUppercase)
        
        // Numbers
        case "0": return (0x1D, false)
        case "1": return (0x12, false)
        case "2": return (0x13, false)
        case "3": return (0x14, false)
        case "4": return (0x15, false)
        case "5": return (0x17, false)
        case "6": return (0x16, false)
        case "7": return (0x1A, false)
        case "8": return (0x1C, false)
        case "9": return (0x19, false)
        
        // Common punctuation
        case " ": return (0x31, false) // Space
        case ".": return (0x2F, false) // Period
        case ",": return (0x2B, false) // Comma
        case "!": return (0x12, true)  // Exclamation (shift+1)
        case "?": return (0x2C, true)  // Question (shift+/)
        case ":": return (0x29, true)  // Colon (shift+;)
        case ";": return (0x29, false) // Semicolon
        case "'": return (0x27, false) // Apostrophe
        case "\"": return (0x27, true) // Quote (shift+')
        case "-": return (0x1B, false) // Hyphen
        case "_": return (0x1B, true)  // Underscore (shift+-)
        case "(": return (0x19, true)  // Left paren (shift+9)
        case ")": return (0x1D, true)  // Right paren (shift+0)
        case "@": return (0x13, true)  // At symbol (shift+2)
        case "#": return (0x14, true)  // Hash (shift+3)
        case "$": return (0x15, true)  // Dollar (shift+4)
        case "%": return (0x17, true)  // Percent (shift+5)
        case "&": return (0x1A, true)  // Ampersand (shift+7)
        case "*": return (0x1C, true)  // Asterisk (shift+8)
        case "+": return (0x18, true)  // Plus (shift+=)
        case "=": return (0x18, false) // Equals
        case "/": return (0x2C, false) // Forward slash
        case "\\": return (0x2A, false) // Backslash
        case "[": return (0x21, false) // Left bracket
        case "]": return (0x1E, false) // Right bracket
        case "{": return (0x21, true)  // Left brace (shift+[)
        case "}": return (0x1E, true)  // Right brace (shift+])
        case "|": return (0x2A, true)  // Pipe (shift+\)
        case "`": return (0x32, false) // Backtick
        case "~": return (0x32, true)  // Tilde (shift+`)
        case "^": return (0x16, true)  // Caret (shift+6)
        case "<": return (0x2B, true)  // Less than (shift+,)
        case ">": return (0x2F, true)  // Greater than (shift+.)
        
        default:
            return nil
        }
    }
}