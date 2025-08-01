import SwiftUI

/// A modern SwiftUI text editor that automatically scrolls to keep the cursor visible.
/// 
/// Uses TextEditor which properly handles Enter key as newline insertion
/// and provides built-in scrolling functionality for multi-line text input.
struct AutoScrollingTextEditor: View {
    @Binding var text: String
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 13))
            .frame(minHeight: 48, maxHeight: 120)
            .scrollContentBackground(.hidden) // Hide default background
            .background(Color.clear) // Use transparent background so parent styling shows through
    }
}
