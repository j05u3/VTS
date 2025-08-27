# Placeholder Text Bug Fix Test

## Test Description
This test verifies that the "Ask anything" bug in ChatGPT text injection has been fixed.

## Test Steps

1. **Build and run VTS app**
   - Open VTSApp.xcodeproj in Xcode
   - Build and run the app (⌘R)

2. **Set up Text Injection Testing**
   - Open VTS app
   - Go to Settings
   - Navigate to "Text Injection Test" view
   - Ensure accessibility permission is granted

3. **Test the ChatGPT Scenario**
   - Open Safari/Chrome and go to `chatgpt.com`
   - Click on the text input box (should show "Ask anything" placeholder)
   - Position cursor at the beginning of the text field (position 0)
   - Use VTS to transcribe some text like "Test injection without placeholder bug"

4. **Expected Results**
   - The text should be injected cleanly: "Test injection without placeholder bug"
   - The "Ask anything" placeholder should be completely replaced, not appended to
   - The final text should NOT contain "Ask anything" at the end

5. **Verification**
   - Check that the text in the ChatGPT input box is exactly what was transcribed
   - Verify no extra "Ask anything" text appears

## Code Changes Made

The fix was implemented in `/VTSApp/VTS/Services/TextInjector.swift`:

### 1. Added Placeholder Detection Logic
```swift
private func isPlaceholderText(_ text: String, cursorPosition: Int) -> Bool {
    // Only check for placeholder replacement if cursor is at the beginning
    guard cursorPosition == 0 else {
        return false
    }
    
    // Common placeholder text patterns (case-insensitive)
    let commonPlaceholders = [
        "ask anything",
        "type a message",
        "enter text",
        // ... more patterns
    ]
    
    // Check for exact matches and patterns
    // Returns true if text should be treated as placeholder
}
```

### 2. Modified Text Insertion Logic
```swift
// Check if we're dealing with placeholder text that should be replaced
let shouldReplacePlaceholder = isPlaceholderText(initialValue, cursorPosition: cursorPosition)

let newText: String
if shouldReplacePlaceholder {
    // Replace the entire placeholder text
    newText = text
    print("🔄 TextInjector: Detected placeholder text - replacing entire content")
} else {
    // Normal insertion at cursor position
    let beforeCursor = String(initialValue.prefix(insertionIndex))
    let afterCursor = String(initialValue.dropFirst(insertionIndex))
    newText = beforeCursor + text + afterCursor
}
```

## Technical Details

The bug occurred because:
1. ChatGPT's input field contains placeholder text "Ask anything"
2. Cursor was at position 0
3. Previous logic: `beforeCursor + insertedText + afterCursor` = `"" + "transcribed text" + "Ask anything"`
4. Result: `"transcribed textAsk anything"`

The fix detects common placeholder patterns and replaces the entire content instead of inserting at cursor position when:
- Cursor is at position 0
- Current text matches known placeholder patterns
- Text is short (< 50 chars) and contains invitation words

## Logs to Look For

When testing, you should see these log messages indicating the fix is working:
```
🔍 TextInjector: Detected known placeholder text: 'Ask anything'
🔄 TextInjector: Detected placeholder text - replacing entire content
📝 TextInjector: Replacing placeholder: 'Ask anything' with: 'Test injection without placeholder bug'
```
