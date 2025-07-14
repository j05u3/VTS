import Foundation
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.semicolon, modifiers: [.command, .shift]))
}

@MainActor
public class SimpleHotkeyManager: ObservableObject {
    public static let shared = SimpleHotkeyManager()
    
    @Published public var isEnabled = false
    
    public var onToggleRecording: (() -> Void)?
    
    private init() {}
    
    public func registerHotkey() {
        guard !isEnabled else { return }
        
        print("Registering global hotkey: Cmd+Shift+;")
        
        // Register the hotkey handler
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            print("Global hotkey pressed!")
            self?.onToggleRecording?()
        }
        
        isEnabled = true
        print("Global hotkey registered successfully")
    }
    
    public func unregisterHotkey() {
        guard isEnabled else { return }
        
        print("Unregistering global hotkey")
        
        // KeyboardShortcuts handles cleanup automatically
        isEnabled = false
        
        print("Global hotkey unregistered successfully")
    }
} 