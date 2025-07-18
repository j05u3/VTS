import Foundation
import AppKit
import CoreGraphics
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
            print("❌ 🧪 TextInjector: No accessibility permission - cannot inject text")
            print("📋 🧪 TextInjector: Please grant accessibility permission in System Settings > Privacy & Security > Accessibility")
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
            print("⚠️ TextInjector: Accessibility method failed, trying Unicode typing simulation...")
            if simulateUnicodeTyping(text) {
                print("✅ TextInjector: Successfully injected via Unicode typing")
                return
            }
            print("⚠️ TextInjector: Unicode typing failed, trying legacy typing simulation...")
            simulateLegacyTyping(text)
            
        case .unicodeTyping:
            print("🌐 TextInjector: Using Unicode typing simulation for this app...")
            if simulateUnicodeTyping(text) {
                print("✅ TextInjector: Successfully injected via Unicode typing")
                return
            }
            print("⚠️ TextInjector: Unicode typing failed, trying legacy typing simulation...")
            simulateLegacyTyping(text)
            
        case .typing:
            print("⌨️ TextInjector: Using traditional typing simulation for this app...")
            simulateLegacyTyping(text)
            
        case .clipboard:
            print("📋 TextInjector: Using clipboard method for this app...")
            useClipboardFallback(text)
        }
    }
    
    private enum InjectionMethod {
        case accessibility
        case typing
        case unicodeTyping
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
        
        // Apps that work best with Unicode typing simulation
        let unicodeTypingPreferredApps = [
            "cursor", "visual studio code", "vscode", "code",
            "discord", "slack", "telegram", "whatsapp",
            "notion", "obsidian", "bear", "ulysses",
            "spotify", "music", "xcode"
        ]
        
        // Apps that work best with traditional typing simulation
        let typingPreferredApps = [
            "terminal", "iterm", "hyper"
        ]
        
        // Apps that work best with clipboard
        let clipboardPreferredApps = [
            "photoshop", "illustrator", "figma", "sketch"
        ]
        
        // Check for Electron apps (often need Unicode typing simulation)
        if bundleId.contains("electron") || 
           bundleId.contains("discord") || 
           bundleId.contains("slack") || 
           bundleId.contains("notion") ||
           bundleId.contains("cursor") {
            print("🔍 TextInjector: Detected Electron-based app, preferring Unicode typing simulation")
            return .unicodeTyping
        }
        
        // Check app name patterns for Unicode typing
        for preferredApp in unicodeTypingPreferredApps {
            if appName.contains(preferredApp) {
                print("🔍 TextInjector: App known to work better with Unicode typing simulation")
                return .unicodeTyping
            }
        }
        
        // Check app name patterns for traditional typing
        for preferredApp in typingPreferredApps {
            if appName.contains(preferredApp) {
                print("🔍 TextInjector: App known to work better with traditional typing simulation")
                return .typing
            }
        }
        
        // Check app name patterns for clipboard
        for preferredApp in clipboardPreferredApps {
            if appName.contains(preferredApp) {
                print("🔍 TextInjector: App known to work better with clipboard method")
                return .clipboard
            }
        }
        
        // Default to accessibility API first, with Unicode typing as fallback
        print("🔍 TextInjector: Using default method (accessibility with Unicode typing fallback)")
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
        
        // Check if there's selected text first
        var selectedRange: CFTypeRef?
        var selectedText: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        let selectedTextResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
        
        if rangeResult == .success && selectedTextResult == .success,
           let selectedTextString = selectedText as? String,
           !selectedTextString.isEmpty {
            // There's selected text - replace it
            print("🎯 TextInjector: Found selected text: '\(selectedTextString)' - replacing it...")
            let textValue = text as CFString
            let selectedResult = AXUIElementSetAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, textValue)
            if selectedResult == .success {
                print("✅ TextInjector: Selected text replacement reported success")
                
                // Verify this method worked
                if verifyTextInsertion(element: element as! AXUIElement, expectedText: text, originalText: initialValue) {
                    print("✅ TextInjector: Verification passed - selected text replacement worked")
                    return true
                } else {
                    print("⚠️ TextInjector: Selected text replacement succeeded but verification failed")
                }
            } else {
                print("❌ TextInjector: Selected text replacement failed (error: \(selectedResult.rawValue))")
            }
        } else {
            // No selected text - append to existing content
            print("🎯 TextInjector: No selected text found - appending to existing content...")
            let combinedText = initialValue + " " + text
            let textValue = combinedText as CFString
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
        
        // Set our text to clipboard with proper Unicode handling
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        
        if !success {
            print("❌ TextInjector: Failed to set text to clipboard")
            // Try alternative Unicode-safe clipboard method
            if !setClipboardUnicodeSafe(text) {
                print("❌ TextInjector: All clipboard methods failed")
                return
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
                print("✅ TextInjector: Clipboard restored")
            } else {
                print("📋 TextInjector: No previous clipboard content to restore")
            }
        }
    }
    
    private func setClipboardUnicodeSafe(_ text: String) -> Bool {
        print("🌐 TextInjector: Attempting Unicode-safe clipboard setting...")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Try setting with explicit UTF-8 encoding
        guard let utf8Data = text.data(using: .utf8) else {
            print("❌ TextInjector: Failed to encode text as UTF-8")
            return false
        }
        
        let success = pasteboard.setData(utf8Data, forType: .string)
        if success {
            print("✅ TextInjector: Successfully set Unicode text to clipboard")
            return true
        }
        
        print("❌ TextInjector: Unicode-safe clipboard setting failed")
        return false
    }
    
    // Alternative Unicode input method using Unicode Hex Input
    private func simulateUnicodeHexInput(_ text: String) -> Bool {
        print("🔢 TextInjector: Attempting Unicode Hex Input method...")
        
        let source = CGEventSource(stateID: .hidSystemState)
        guard let source = source else {
            print("❌ TextInjector: Failed to create CGEventSource for hex input")
            return false
        }
        
        // Check if Unicode Hex Input is available (this is best-effort)
        print("🔢 TextInjector: Using Unicode Hex Input method for international characters...")
        
        for character in text {
            let unicodeValue = character.unicodeScalars.first?.value ?? 0
            
            // For basic ASCII, use regular typing
            if unicodeValue < 128 {
                if let keyCode = getKeyCode(for: character) {
                    let (_, needsShift) = keyCode
                    
                    if needsShift {
                        // Press Option+Shift+hex for uppercase/special chars
                        simulateHexInput(unicodeValue, withShift: true, source: source)
                    } else {
                        simulateHexInput(unicodeValue, withShift: false, source: source)
                    }
                } else {
                    simulateHexInput(unicodeValue, withShift: false, source: source)
                }
            } else {
                // For non-ASCII characters, use Unicode hex input
                simulateHexInput(unicodeValue, withShift: false, source: source)
            }
            
            Thread.sleep(forTimeInterval: 0.02)
        }
        
        return true
    }
    
    private func simulateHexInput(_ unicodeValue: UInt32, withShift: Bool, source: CGEventSource) {
        let hexString = String(format: "%04X", unicodeValue)
        print("🔢 TextInjector: Inputting Unicode U+\(hexString)")
        
        // Hold Option key
        let optionDown = CGEvent(keyboardEventSource: source, virtualKey: 0x3A, keyDown: true) // Option key
        optionDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.01)
        
        // Type each hex digit
        for hexChar in hexString {
            if let keyCode = getHexKeyCode(for: hexChar) {
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
                
                keyDown?.flags = .maskAlternate
                keyUp?.flags = .maskAlternate
                
                keyDown?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.01)
                keyUp?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        
        // Release Option key
        let optionUp = CGEvent(keyboardEventSource: source, virtualKey: 0x3A, keyDown: false)
        optionUp?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.02)
    }
    
    private func getHexKeyCode(for hexChar: Character) -> CGKeyCode? {
        switch hexChar.lowercased().first {
        case "0": return 0x1D
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "5": return 0x17
        case "6": return 0x16
        case "7": return 0x1A
        case "8": return 0x1C
        case "9": return 0x19
        case "a": return 0x00
        case "b": return 0x0B
        case "c": return 0x08
        case "d": return 0x02
        case "e": return 0x0E
        case "f": return 0x03
        default: return nil
        }
    }
    
    private func simulateTyping(_ text: String) {
        print("⌨️ TextInjector: Starting character-by-character typing simulation...")
        print("⌨️ TextInjector: Will type: '\(text)'")
        
        // Try Unicode-aware typing first (modern approach)
        if simulateUnicodeTyping(text) {
            print("✅ TextInjector: Unicode typing completed successfully")
            return
        }
        
        // Fallback to legacy character-by-character method
        print("⚠️ TextInjector: Unicode typing failed, falling back to legacy method...")
        simulateLegacyTyping(text)
    }
    
    private func simulateUnicodeTyping(_ text: String) -> Bool {
        print("🌐 TextInjector: Starting Unicode-aware typing simulation...")
        
        let source = CGEventSource(stateID: .hidSystemState)
        guard let source = source else {
            print("❌ TextInjector: Failed to create CGEventSource")
            return false
        }
        
        // Split text into chunks to handle it properly
        let chunks = text.components(separatedBy: .newlines)
        
        for (chunkIndex, chunk) in chunks.enumerated() {
            if !chunk.isEmpty {
                // Create a keyboard event with Unicode string
                guard let keyboardEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                    print("❌ TextInjector: Failed to create keyboard event")
                    return false
                }
                
                // Convert Unicode scalars to UInt16 array (UniChar)
                let unicodeString = Array(chunk.unicodeScalars.compactMap { scalar in
                    // CGEvent expects UniChar (UInt16), so we need to handle larger Unicode values
                    if scalar.value <= UInt32(UInt16.max) {
                        return UInt16(scalar.value)
                    } else {
                        // For larger Unicode values, we might need to split into surrogate pairs
                        // For now, we'll skip them and log
                        print("⚠️ TextInjector: Skipping Unicode scalar U+\(String(format: "%04X", scalar.value)) - too large for UniChar")
                        return nil
                    }
                })
                
                // Set the Unicode string for this event
                keyboardEvent.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
                
                // Post the event
                keyboardEvent.post(tap: .cghidEventTap)
                
                print("✅ TextInjector: Posted Unicode chunk: '\(chunk)'")
                
                // Small delay between chunks for stability
                Thread.sleep(forTimeInterval: 0.05)
            }
            
            // Add newline if not the last chunk
            if chunkIndex < chunks.count - 1 {
                let enterEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
                enterEvent?.post(tap: .cghidEventTap)
                let enterUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
                enterUpEvent?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
        
        return true
    }
    
    private func simulateLegacyTyping(_ text: String) {
        print("⌨️ TextInjector: Starting legacy character-by-character typing simulation...")
        
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
                print("⚠️ TextInjector: Could not map character '\(character)' to key code, trying Unicode fallback...")
                
                // Try to inject this single character using Unicode method
                if !simulateUnicodeTyping(String(character)) {
                    print("❌ TextInjector: Unicode fallback also failed for character '\(character)', skipping")
                }
            }
        }
        
        // Ensure all modifier keys are released at the end
        let finalShiftUp = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false)
        finalShiftUp?.post(tap: .cghidEventTap)
        
        print("✅ TextInjector: Finished legacy typing simulation")
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