import Foundation
import AppKit
import KeyboardShortcuts
import Combine

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.semicolon, modifiers: [.command, .shift]))
    static let copyLastTranscription = Self("copyLastTranscription", default: .init(.c, modifiers: [.command, .shift, .option]))
}

@MainActor
public class SimpleHotkeyManager: ObservableObject {
    public static let shared = SimpleHotkeyManager()
    
    @Published public var isEnabled = false
    @Published public var currentHotkeyString = "⌘⇧;" // Default fallback
    @Published public var currentCopyHotkeyString = "⌥⌘⇧C" // Default fallback for copy
    
    public var onToggleRecording: (() -> Void)?
    public var onCopyLastTranscription: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        updateCurrentHotkeyString()
        updateCurrentCopyHotkeyString()
        
        // Set up a timer to periodically check for hotkey changes
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCurrentHotkeyString()
                self?.updateCurrentCopyHotkeyString()
            }
            .store(in: &cancellables)
    }
    
    /// Update the published currentHotkeyString with the current shortcut
    private func updateCurrentHotkeyString() {
        let newHotkeyString = getCurrentHotkeyDisplayString()
        if currentHotkeyString != newHotkeyString {
            currentHotkeyString = newHotkeyString
        }
    }
    
    /// Update the published currentCopyHotkeyString with the current shortcut
    private func updateCurrentCopyHotkeyString() {
        let newHotkeyString = getCurrentCopyHotkeyDisplayString()
        if currentCopyHotkeyString != newHotkeyString {
            currentCopyHotkeyString = newHotkeyString
        }
    }
    
    /// Manually refresh the hotkey strings (call when hotkeys change)
    public func refreshHotkeyString() {
        updateCurrentHotkeyString()
        updateCurrentCopyHotkeyString()
    }
    
    /// Get the current hotkey as a display string (e.g., "⌘⇧;")
    private func getCurrentHotkeyDisplayString() -> String {
        return getHotkeyDisplayString(for: .toggleRecording, fallback: "⌘⇧;")
    }
    
    /// Get the current copy hotkey as a display string (e.g., "⌥⌘⇧C")
    private func getCurrentCopyHotkeyDisplayString() -> String {
        return getHotkeyDisplayString(for: .copyLastTranscription, fallback: "⌥⌘⇧C")
    }
    
    /// Generic function to get hotkey display string for any KeyboardShortcuts.Name
    private func getHotkeyDisplayString(for name: KeyboardShortcuts.Name, fallback: String) -> String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else {
            return fallback
        }
        
        var result = ""
        
        // Add modifier symbols
        if shortcut.modifiers.contains(.control) {
            result += "⌃"
        }
        if shortcut.modifiers.contains(.option) {
            result += "⌥"
        }
        if shortcut.modifiers.contains(.shift) {
            result += "⇧"
        }
        if shortcut.modifiers.contains(.command) {
            result += "⌘"
        }
        
        // Convert key to display character using our working method
        if let key = shortcut.key {
            let keyChar = simpleKeyToDisplayString(key)
            result += keyChar
        }
        
        return result
    }
    
    private func simpleKeyToDisplayString(_ key: KeyboardShortcuts.Key) -> String {
        // Handle keys explicitly to avoid rawValue issues
        switch key {
        // Special keys
        case .space:
            return "Space"
        case .tab:
            return "Tab"
        case .return:
            return "Return"
        case .escape:
            return "Esc"
        case .delete:
            return "Delete"
        case .deleteForward:
            return "Del"
        case .leftArrow:
            return "←"
        case .rightArrow:
            return "→"
        case .upArrow:
            return "↑"
        case .downArrow:
            return "↓"
            
        // Punctuation and symbols
        case .semicolon:
            return ";"
        case .comma:
            return ","
        case .period:
            return "."
        case .slash:
            return "/"
        case .minus:
            return "-"
        case .equal:
            return "="
        case .leftBracket:
            return "["
        case .rightBracket:
            return "]"
        case .backslash:
            return "\\"
        case .quote:
            return "'"
            
        // Numbers
        case .zero:
            return "0"
        case .one:
            return "1"
        case .two:
            return "2"
        case .three:
            return "3"
        case .four:
            return "4"
        case .five:
            return "5"
        case .six:
            return "6"
        case .seven:
            return "7"
        case .eight:
            return "8"
        case .nine:
            return "9"
            
        // Letters
        case .a:
            return "A"
        case .b:
            return "B"
        case .c:
            return "C"
        case .d:
            return "D"
        case .e:
            return "E"
        case .f:
            return "F"
        case .g:
            return "G"
        case .h:
            return "H"
        case .i:
            return "I"
        case .j:
            return "J"
        case .k:
            return "K"
        case .l:
            return "L"
        case .m:
            return "M"
        case .n:
            return "N"
        case .o:
            return "O"
        case .p:
            return "P"
        case .q:
            return "Q"
        case .r:
            return "R"
        case .s:
            return "S"
        case .t:
            return "T"
        case .u:
            return "U"
        case .v:
            return "V"
        case .w:
            return "W"
        case .x:
            return "X"
        case .y:
            return "Y"
        case .z:
            return "Z"
            
        // Function keys
        case .f1:
            return "F1"
        case .f2:
            return "F2"
        case .f3:
            return "F3"
        case .f4:
            return "F4"
        case .f5:
            return "F5"
        case .f6:
            return "F6"
        case .f7:
            return "F7"
        case .f8:
            return "F8"
        case .f9:
            return "F9"
        case .f10:
            return "F10"
        case .f11:
            return "F11"
        case .f12:
            return "F12"
            
        default:
            // For any other keys we haven't explicitly handled
            return "?"
        }
    }
    
    public func registerHotkey() {
        guard !isEnabled else { return }
        
        print("Registering global hotkeys:")
        print("  Toggle Recording: \(currentHotkeyString)")
        print("  Copy Last Transcription: \(currentCopyHotkeyString)")
        
        // Register the recording toggle hotkey handler
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            print("Global recording hotkey pressed!")
            self?.onToggleRecording?()
        }
        
        // Register the copy last transcription hotkey handler
        KeyboardShortcuts.onKeyDown(for: .copyLastTranscription) { [weak self] in
            print("Global copy hotkey pressed!")
            self?.onCopyLastTranscription?()
        }
        
        isEnabled = true
        print("Global hotkeys registered successfully")
    }
    
    public func unregisterHotkey() {
        guard isEnabled else { return }
        
        print("Unregistering global hotkey")
        
        // KeyboardShortcuts handles cleanup automatically
        isEnabled = false
        
        print("Global hotkey unregistered successfully")
    }
} 