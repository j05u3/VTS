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
    
    public func testCursorInjection() {
        log("🧪 Starting code editor compatibility test...")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            log("🧪 Code editor test will begin in 3 seconds...")
            log("🧪 Please focus on a text field in your code editor!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                // Test with mixed case and international characters
                self.injectText("Hello World! Testing VTS in code editor. Mixed CaSe TeXt: 123 ABC def. Español: ñáéíóú")
            }
        } else {
            log("🧪 Cannot test - accessibility permission required")
        }
    }
    
    public func testSpanishCharacters() {
        log("🧪 Starting international character test...")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            log("🧪 International character test will begin in 3 seconds...")
            log("🧪 Please focus on any text input field!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let spanishText = "Hola, ¿cómo estás? Me gusta el español: ñáéíóúüÑÁÉÍÓÚÜ"
                self.log("🧪 Testing international text: '\(spanishText)'")
                self.injectText(spanishText)
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
    
    public func testCursorPositionInsertion() {
        log("🧪 TextInjector: Starting cursor position insertion test...")
        checkPermissionStatus()
        
        if hasAccessibilityPermission {
            log("🧪 TextInjector: This test will help verify cursor position insertion works correctly.")
            log("🧪 TextInjector: Instructions:")
            log("   1. Focus on a text field")
            log("   2. Type some text: 'Hello World'")
            log("   3. Position cursor between 'Hello' and 'World' (middle of the text)")
            log("   4. Wait for injection in 5 seconds...")
            log("🧪 TextInjector: Expected result: Text should be inserted AT the cursor, not at the end!")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                let insertText = " INSERTED "
                self.log("🧪 TextInjector: Inserting '\(insertText)' at cursor position...")
                self.injectText(insertText)
                self.log("🧪 TextInjector: If working correctly, text should become: 'Hello INSERTED World'")
            }
        } else {
            log("🧪 TextInjector: Cannot test - no accessibility permission")
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
        
        // Get app info for method selection
        let appInfo = getCurrentAppInfo()
        
        print("📱 TextInjector: Target app: \(appInfo.name)")
        
        // Try modern Accessibility API first (best for most apps)
        if tryModernAccessibilityInsertion(text) {
            print("✅ TextInjector: Successfully injected via modern Accessibility API")
            return
        }
        
        print("⚠️ TextInjector: Accessibility method failed, trying Unicode typing simulation...")
        
        // Fallback to improved Unicode typing simulation
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
                    
                    // Check if we're dealing with placeholder text that should be replaced
                    let shouldReplacePlaceholder = isPlaceholderText(initialValue, cursorPosition: cursorPosition, element: element)
                    
                    // Enable detailed logging for placeholder detection if needed
                    if cursorPosition == 0 && !initialValue.isEmpty {
                        logPlaceholderDetection(element, text: initialValue, cursorPosition: cursorPosition)
                    }
                    
                    let newText: String
                    if shouldReplacePlaceholder {
                        // Replace the entire placeholder text
                        newText = text
                        print("🔄 TextInjector: Detected placeholder text - replacing entire content")
                        print("📝 TextInjector: Replacing placeholder: '\(initialValue)' with: '\(text)'")
                    } else {
                        // Normal insertion at cursor position
                        let beforeCursor = String(initialValue.prefix(insertionIndex))
                        let afterCursor = String(initialValue.dropFirst(insertionIndex))
                        newText = beforeCursor + text + afterCursor
                        print("📝 TextInjector: Inserting text at position \(insertionIndex)")
                        print("📝 TextInjector: Before: '\(beforeCursor)' | Insert: '\(text)' | After: '\(afterCursor)'")
                    }
                    
                    // Ensure proper UTF-8 encoding for the new text
                    let textValue = newText as CFString
                    let directResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, textValue)
                    if directResult == .success {
                        print("✅ TextInjector: Cursor position insertion reported success")
                        
                        // Set cursor after inserted text
                        let newCursorPosition = shouldReplacePlaceholder ? text.count : insertionIndex + text.count
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
    
    // MARK: - Placeholder Text Detection
    
    private func isPlaceholderText(_ text: String, cursorPosition: Int, element: AXUIElement) -> Bool {
        // Only check for placeholder replacement if cursor is at the beginning
        guard cursorPosition == 0 else {
            return false
        }
        
        // Primary method: Check accessibility API for placeholder value
        if let placeholderValue = getAccessibilityPlaceholder(from: element) {
            let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedPlaceholder = placeholderValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if normalizedText.caseInsensitiveCompare(normalizedPlaceholder) == .orderedSame {
                print("🔍 TextInjector: Detected placeholder via AX API: '\(placeholderValue)'")
                return true
            }
        }
        
        // Fallback method: Pattern-based detection for apps that don't properly expose placeholder
        return isPlaceholderTextByPattern(text, cursorPosition: cursorPosition)
    }
    
    private func getAccessibilityPlaceholder(from element: AXUIElement) -> String? {
        // Try to get the placeholder value using the accessibility API
        var placeholderValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, "AXPlaceholderValue" as CFString, &placeholderValue)
        
        if result == .success, let placeholder = placeholderValue as? String, !placeholder.isEmpty {
            return placeholder
        }
        
        // Some applications might use different attribute names or expose placeholder differently
        // Try alternative approaches if the standard attribute is not available
        return nil
    }
    
    private func isPlaceholderTextByPattern(_ text: String, cursorPosition: Int) -> Bool {
        // Only check for placeholder replacement if cursor is at the beginning
        guard cursorPosition == 0 else {
            return false
        }
        
        // Common placeholder text patterns (case-insensitive)
        let commonPlaceholders = [
            "ask anything",
            "type a message",
            "enter text",
            "start typing",
            "write something",
            "type here",
            "enter your message",
            "what can i help you with",
            "how can i help you",
            "search",
            "type your question",
            "message chatgpt",
            "send a message"
        ]
        
        let lowercaseText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for exact matches with common placeholders
        if commonPlaceholders.contains(lowercaseText) {
            print("🔍 TextInjector: Detected known placeholder text: '\(text)'")
            return true
        }
        
        // Check for patterns that suggest placeholder text
        let placeholderPatterns = [
            "ask ",
            "type ",
            "enter ",
            "write ",
            "search ",
            "message "
        ]
        
        for pattern in placeholderPatterns {
            if lowercaseText.hasPrefix(pattern) && lowercaseText.count < 50 {
                print("🔍 TextInjector: Detected placeholder pattern: '\(text)' (starts with '\(pattern)')")
                return true
            }
        }
        
        // Additional heuristics for placeholder detection
        // - Short text (< 50 chars) at cursor position 0 in text fields is often placeholder
        // - Text that contains invitation words like "ask", "type", "enter" etc.
        if lowercaseText.count < 50 && cursorPosition == 0 {
            let invitationWords = ["ask", "type", "enter", "write", "search", "message", "help", "what", "how"]
            let containsInvitation = invitationWords.contains { lowercaseText.contains($0) }
            
            if containsInvitation {
                print("🔍 TextInjector: Detected likely placeholder text (invitation word): '\(text)'")
                return true
            }
        }
        
        return false
    }
    
    private func logPlaceholderDetection(_ element: AXUIElement, text: String, cursorPosition: Int) {
        let placeholder = getAccessibilityPlaceholder(from: element)
        let role = getElementRole(element)
        let supportsPlaceholder = supportsPlaceholderAttribute(element)
        
        print("📊 TextInjector: Placeholder Detection Analysis:")
        print("   Current text: '\(text)'")
        print("   Cursor position: \(cursorPosition)")
        print("   Element role: \(role ?? "unknown")")
        print("   Supports placeholder attribute: \(supportsPlaceholder)")
        print("   AX Placeholder value: '\(placeholder ?? "none")'")
    }
    
    private func getElementRole(_ element: AXUIElement) -> String? {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            return role
        }
        return nil
    }
    
    private func supportsPlaceholderAttribute(_ element: AXUIElement) -> Bool {
        var attributes: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &attributes)
        
        if result == .success, let attributeNames = attributes as? [String] {
            return attributeNames.contains("AXPlaceholderValue")
        }
        return false
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