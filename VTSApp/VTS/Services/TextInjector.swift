import Foundation
import AppKit
import CoreGraphics
import CoreFoundation
import Combine

// MARK: - Logging Protocol
public protocol TextInjectorLogging: AnyObject {
    func log(_ message: String)
}

@MainActor
public class TextInjector: ObservableObject {
    @Published public private(set) var hasAccessibilityPermission = false
    public weak var loggingDelegate: TextInjectorLogging?
    
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
            print("🧪 Accessibility permission status changed - now \(hasAccessibilityPermission ? "enabled" : "disabled")")
            // Ensure UI updates by explicitly sending change notification
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    public func refreshPermissionStatus() {
        log("🧪 Checking accessibility permission status...")
        updatePermissionStatus()
    }
    
    private func log(_ message: String) {
        print(message)
        loggingDelegate?.log(message)
    }
    
    public func checkPermissionStatus() {
        log("🔍 Checking accessibility permission for text injection...")
        
        // Safe permission check without prompting
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString: false as CFBoolean
        ] as CFDictionary
        
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        log("📋 Accessibility permission status: \(hasPermission ? "✅ GRANTED - Text injection is enabled" : "❌ DENIED - Text injection is disabled")")
        
        if !hasPermission {
            log("🚫 Accessibility permission is required for automatic text insertion")
            log("📖 To enable text injection:")
            log("   1. Open System Settings")
            log("   2. Go to Privacy & Security")
            log("   3. Click on Accessibility")
            log("   4. Find 'VTS' in the list and enable it")
            log("   5. If not in the list, click the '+' button to add the app")
        } else {
            log("🎉 Text injection is ready to work! Transcribed text will be automatically inserted.")
        }
        
        // Update our internal state
        hasAccessibilityPermission = hasPermission
    }
    
    public func testTextInjection() {
        log("🧪 Starting text injection test...")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            log("🧪 Test will begin in 3 seconds - please focus on a text field now!")
            log("🧪 Test text will be injected automatically...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.injectText("Hello from VTS!")
            }
        } else {
            log("🧪 Cannot test - accessibility permission required")
        }
    }
    
    public func testEmojiCharacters() {
        log("🧪 Starting emoji injection test...")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            log("🧪 Emoji injection test will begin in 3 seconds...")
            log("🧪 Please focus on any text input field!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let emojiText = "Hello! 😀😃😄😁😆😅😂🤣😊😇🙂👹👺🤡💩👽👾🤖🎃🙀😿😾"
                self.log("🧪 Testing emoji text: '\(emojiText)'")
                self.injectText(emojiText)
            }
        } else {
            log("🧪 Cannot test - accessibility permission required")
        }
    }
    
    public func testMultilingualText() {
        log("🧪 Starting multilingual compatibility test...")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            log("🧪 Multilingual test will begin in 3 seconds...")
            log("🧪 Please focus on any text input field!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let multilingualText = """
                English: Hello World!
                Español: ¡Hola Mundo! ñáéíóú
                Français: Bonjour le monde! àèéêëîïôöùûüÿç
                Deutsch: Hallo Welt! äöüß
                Português: Olá Mundo! ãõáéíóúâêôç
                """
                self.log("🧪 Testing multilingual text support")
                self.injectText(multilingualText)
            }
        } else {
            log("🧪 Cannot test - accessibility permission required")
        }
    }
    
    public func testAccessibilityOnlyInjection() {
        log("🧪 TextInjector: Starting ACCESSIBILITY API ONLY test...")
        log("🔬 TextInjector: This test will ONLY use the Accessibility API, no fallback to typing simulation")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            log("🧪 TextInjector: Accessibility-only test will begin in 3 seconds...")
            log("🧪 TextInjector: Please focus on a text field now!")
            log("🔬 TextInjector: This test helps diagnose if Accessibility API works in specific apps")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let testText = "ACCESSIBILITY-ONLY: Hello from VTS!"
                self.log("🔬 TextInjector: Testing ONLY Accessibility API with: '\(testText)'")
                
                if self.tryModernAccessibilityInsertion(testText) {
                    self.log("✅ TextInjector: Accessibility API test SUCCEEDED")
                } else {
                    self.log("❌ TextInjector: Accessibility API test FAILED - this app may have broken accessibility support")
                }
            }
        } else {
            log("🧪 TextInjector: Cannot test - accessibility permission required")
        }
    }
    
    public func testUnicodeTypingOnlyInjection() {
        log("🧪 TextInjector: Starting UNICODE TYPING ONLY test...")
        log("🔬 TextInjector: This test will ONLY use Unicode typing simulation, no Accessibility API")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            log("🧪 TextInjector: Unicode typing-only test will begin in 3 seconds...")
            log("🧪 TextInjector: Please focus on a text field now!")
            log("🔬 TextInjector: This test helps verify if typing simulation works when Accessibility API fails")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let testText = "TYPING-ONLY: Hello from VTS!"
                self.log("🔬 TextInjector: Testing ONLY Unicode typing simulation with: '\(testText)'")
                
                if self.simulateModernUnicodeTyping(testText) {
                    self.log("✅ TextInjector: Unicode typing test SUCCEEDED")
                } else {
                    self.log("❌ TextInjector: Unicode typing test FAILED")
                }
            }
        } else {
            log("🧪 TextInjector: Cannot test - accessibility permission required")
        }
    }
    
    public func requestAccessibilityPermission() {
        print("Requesting accessibility permission for text insertion...")
        
        // Check current status
        updatePermissionStatus()
        if hasAccessibilityPermission {
            print("Accessibility permission already granted")
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
            print("🧪 Opened System Settings (new format)")
        } else if NSWorkspace.shared.open(oldSettingsURL) {
            print("🧪 Opened System Preferences (legacy format)")
        } else {
            print("🧪 Failed to open System Settings")
        }
    }
    

    

    
    private func startMonitoring() {
        print("🧪 Starting permission monitoring...")
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor in
                self.updatePermissionStatus()
                
                if self.hasAccessibilityPermission {
                    print("🧪 Permission granted!")
                    timer.invalidate()
                }
            }
        }
    }
    
    public func injectText(_ text: String, replaceLastText: String? = nil) {
        guard hasAccessibilityPermission else {
            print("❌ TextInjector: No accessibility permission - cannot inject text")
            print("📋 TextInjector: VTS requires accessibility permission for text injection functionality")
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
        
        // Get app info for logging
        let appInfo = getCurrentAppInfo()
        print("📱 TextInjector: Target app: \(appInfo.name)")
        
        // Use Unicode typing simulation as the primary method
        if simulateModernUnicodeTyping(text) {
            print("✅ TextInjector: Successfully injected via Unicode typing")
            return
        }
        
        print("❌ TextInjector: All injection methods failed")
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
    
    private func deleteTextViaKeyboard(count: Int) {
        guard count > 0 else { return }
        
        print("🗑️ TextInjector: Deleting \(count) characters via keyboard simulation...")
        
        for _ in 0..<count {
            let deleteEvent = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: true)
            deleteEvent?.post(tap: .cghidEventTap)
            let deleteUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: false)
            deleteUpEvent?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.01)
        }
        print("✅ TextInjector: Deletion completed via keyboard simulation")
    }
    
    // MARK: - Legacy Accessibility Methods (kept for testing and future use)
    
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
        deleteTextViaKeyboard(count: count)
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
        guard elementResult == .success, 
              let focusedElementRef = focusedElement,
              CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else { 
            print("❌ TextInjector: Could not get focused element (error: \(elementResult.rawValue))")
            return false
        }
        let element = focusedElementRef as! AXUIElement
        print("✅ TextInjector: Found focused element")
        
        // Get current value and remove last 'count' characters
        var currentValue: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)
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
        let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue)
        
        if setResult == .success {
            print("✅ TextInjector: Successfully deleted text via accessibility API")
            return true
        } else {
            print("❌ TextInjector: Failed to set new value (error: \(setResult.rawValue))")
            return false
        }
    }
    
    private func tryModernAccessibilityInsertion(_ text: String) -> Bool {
        print("🔍 TextInjector: Starting modern accessibility insertion process...")
        
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
        guard elementResult == .success, 
              let focusedElementRef = focusedElement,
              CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else { 
            print("❌ TextInjector: Could not get focused element (error: \(elementResult.rawValue))")
            return false
        }
        let element = focusedElementRef as! AXUIElement
        print("✅ TextInjector: Found focused element")
        
        // Get element info for debugging
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            print("📋 TextInjector: Focused element role: \(role)")
        }
        
        // Get current value before insertion
        var initialValueRef: CFTypeRef?
        let initialValue: String
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &initialValueRef) == .success,
           let currentValue = initialValueRef as? String {
            initialValue = currentValue
            print("📝 TextInjector: Current element value: '\(currentValue)'")
        } else {
            initialValue = ""
            print("📝 TextInjector: Could not read current value, assuming empty")
        }
        
        // Check if there's selected text first
        var selectedRange: CFTypeRef?
        var selectedText: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        let selectedTextResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        
        if rangeResult == .success && selectedTextResult == .success,
           let selectedTextString = selectedText as? String,
           !selectedTextString.isEmpty {
            // There's selected text - replace it
            print("🎯 TextInjector: Found selected text: '\(selectedTextString)' - replacing it...")
            
            // Ensure text is properly encoded as UTF-8
            let textValue = text as CFString
            let selectedResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, textValue)
            if selectedResult == .success {
                print("✅ TextInjector: Selected text replacement reported success")
                
                // Verify this method worked
                if verifyTextInsertion(element: element, expectedText: text, originalText: initialValue) {
                    print("✅ TextInjector: Verification passed - selected text replacement worked")
                    return true
                } else {
                    print("⚠️ TextInjector: Selected text replacement succeeded but verification failed")
                }
            } else {
                print("❌ TextInjector: Selected text replacement failed (error: \(selectedResult.rawValue))")
            }
        } else {
            // No selected text - insert at cursor position or append
            print("🎯 TextInjector: No selected text found - inserting at cursor position...")
            
            if rangeResult == .success, let range = selectedRange {
                // We have cursor position information - insert at the cursor
                if let cursorPosition = extractCursorPosition(from: range) {
                    print("📍 TextInjector: Found cursor position: \(cursorPosition)")
                    
                    let insertionIndex = min(cursorPosition, initialValue.count)
                    let beforeCursor = String(initialValue.prefix(insertionIndex))
                    let afterCursor = String(initialValue.dropFirst(insertionIndex))
                    let newText = beforeCursor + text + afterCursor
                    
                    print("📝 TextInjector: Inserting text at position \(insertionIndex)")
                    print("📝 TextInjector: Before: '\(beforeCursor)' | Insert: '\(text)' | After: '\(afterCursor)'")
                    
                    // Ensure proper UTF-8 encoding for the new text
                    let textValue = newText as CFString
                    let directResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, textValue)
                    if directResult == .success {
                        print("✅ TextInjector: Cursor position insertion reported success")
                        
                        // Set cursor after inserted text
                        let newCursorPosition = insertionIndex + text.count
                        if setCursorPosition(element: element, position: newCursorPosition) {
                            print("✅ TextInjector: Cursor repositioned to \(newCursorPosition)")
                        }
                        
                        // Verify the change actually took effect
                        if verifyTextInsertion(element: element, expectedText: text, originalText: initialValue) {
                            print("✅ TextInjector: Verification passed - text inserted at cursor position")
                            return true
                        } else {
                            print("⚠️ TextInjector: Verification failed - accessibility API succeeded but text didn't change as expected")
                        }
                    } else {
                        print("❌ TextInjector: Cursor position insertion failed (error: \(directResult.rawValue))")
                    }
                } else {
                    print("⚠️ TextInjector: Could not extract cursor position from range, falling back to append")
                }
            } else {
                print("⚠️ TextInjector: Could not get cursor position, falling back to append")
            }
            
            // Fallback: append to existing content
            print("🔄 TextInjector: Falling back to append mode...")
            let combinedText = initialValue + text
            let textValue = combinedText as CFString
            let directResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, textValue)
            if directResult == .success {
                print("✅ TextInjector: Accessibility API reported success (fallback mode)")
                
                // Verify the change actually took effect
                if verifyTextInsertion(element: element, expectedText: text, originalText: initialValue) {
                    print("✅ TextInjector: Verification passed - text appended successfully")
                    return true
                } else {
                    print("⚠️ TextInjector: Verification failed - accessibility API succeeded but text didn't change")
                    print("🔄 TextInjector: App may be ignoring accessibility changes")
                }
            } else {
                print("❌ TextInjector: Direct value setting failed (error: \(directResult.rawValue))")
            }
        }
        
        print("❌ TextInjector: All accessibility insertion methods failed or were ignored")
        return false
    }
    
    private func simulateModernUnicodeTyping(_ text: String) -> Bool {
        print("🌐 TextInjector: Starting modern Unicode-aware typing simulation...")
        
        let source = CGEventSource(stateID: .hidSystemState)
        guard let source = source else {
            print("❌ TextInjector: Failed to create CGEventSource")
            return false
        }
        
        // Process text in smaller chunks to handle complex Unicode properly
        let maxChunkSize = 50 // Smaller chunks for better compatibility
        let chunks = text.chunked(maxSize: maxChunkSize)
        
        for (chunkIndex, chunk) in chunks.enumerated() {
            if !chunk.isEmpty {
                if !insertUnicodeChunk(chunk, using: source) {
                    print("❌ TextInjector: Failed to insert Unicode chunk: '\(chunk)'")
                    return false
                }
                
                // Small delay between chunks for stability
                Thread.sleep(forTimeInterval: 0.08)
            }
            
            // Progress logging for large texts
            if chunks.count > 1 {
                print("📝 TextInjector: Processed chunk \(chunkIndex + 1)/\(chunks.count)")
            }
        }
        
        print("✅ TextInjector: Modern Unicode typing completed successfully")
        return true
    }
    
    private func insertUnicodeChunk(_ chunk: String, using source: CGEventSource) -> Bool {
        // Create a keyboard event for Unicode text input
        guard let keyboardEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            print("❌ TextInjector: Failed to create keyboard event for chunk")
            return false
        }
        
        // Convert text to UTF-16 representation which CGEvent can handle
        let utf16Array = Array(chunk.utf16)
        
        // Set the Unicode string for this event (handles emojis and complex Unicode)
        keyboardEvent.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
        
        // Post the event
        keyboardEvent.post(tap: .cghidEventTap)
        
        print("✅ TextInjector: Posted Unicode chunk: '\(chunk)' (\(utf16Array.count) UTF-16 units)")
        return true
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
    
    // MARK: - Cursor Position Helper Methods
    
    private func extractCursorPosition(from range: CFTypeRef) -> Int? {
        // Try to extract as AXValue containing CFRange
        guard CFGetTypeID(range) == AXValueGetTypeID() else {
            print("❌ TextInjector: Range is not an AXValue")
            return nil
        }
        
        var cfRange = CFRange()
        let success = AXValueGetValue(range as! AXValue, .cfRange, &cfRange)
        
        if success {
            print("📍 TextInjector: Extracted cursor position: \(cfRange.location), length: \(cfRange.length)")
            
            // Validate the cursor position
            if cfRange.location >= 0 {
                return cfRange.location
            } else {
                print("❌ TextInjector: Invalid cursor position (negative): \(cfRange.location)")
                return nil
            }
        } else {
            print("❌ TextInjector: Failed to extract CFRange from AXValue")
            return nil
        }
    }
    
    private func setCursorPosition(element: AXUIElement, position: Int) -> Bool {
        // Validate position
        guard position >= 0 else {
            print("❌ TextInjector: Invalid cursor position (negative): \(position)")
            return false
        }
        
        // Create a CFRange for the new cursor position (length 0 means just cursor, no selection)
        var newRange = CFRange(location: position, length: 0)
        
        // Create AXValue from CFRange
        let axValue = AXValueCreate(.cfRange, &newRange)
        guard let axValue = axValue else {
            print("❌ TextInjector: Failed to create AXValue for cursor position")
            return false
        }
        
        // Set the new cursor position
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axValue)
        
        if result == .success {
            print("✅ TextInjector: Successfully set cursor position to \(position)")
            return true
        } else {
            print("❌ TextInjector: Failed to set cursor position (error: \(result.rawValue))")
            return false
        }
    }
}

// MARK: - String Extension for Text Chunking

extension String {
    func chunked(maxSize: Int) -> [String] {
        if isEmpty { return [] }
        guard maxSize > 0 else { return [self] }
        
        var chunks: [String] = []
        var currentIndex = startIndex
        
        while currentIndex < endIndex {
            let chunkEndIndex = self.index(currentIndex, offsetBy: maxSize, limitedBy: self.endIndex) ?? self.endIndex
            let chunk = String(self[currentIndex..<chunkEndIndex])
            chunks.append(chunk)
            currentIndex = chunkEndIndex
        }
        
        return chunks
    }
}