# Research: More Robust Placeholder Text Detection Methods

## Current Approach vs. Better Alternatives

### Current Implementation (Pattern-Based Detection)
Our current fix uses heuristic-based pattern matching to detect placeholder text:
- Checks for common placeholder phrases ("ask anything", "type a message", etc.)
- Only triggers when cursor is at position 0
- Uses content analysis and length limits

**Pros:**
- Simple to implement
- Works across different applications
- No additional API calls needed

**Cons:**
- Not future-proof (new placeholder patterns need manual addition)
- Language-dependent
- May have false positives/negatives
- Doesn't use proper accessibility semantics

## 1. macOS Accessibility API: AXPlaceholderValue Attribute

### The Robust Solution: `kAXPlaceholderValueAttribute`

The macOS Accessibility API provides a dedicated attribute for placeholder text detection:

```swift
let kAXPlaceholderValueAttribute = "AXPlaceholderValue" as CFString
```

This attribute is specifically designed to expose placeholder text to assistive technologies and should be the definitive way to detect placeholder content.

### Implementation Approach

```swift
private func getPlaceholderText(from element: AXUIElement) -> String? {
    var placeholderValue: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute as CFString, &placeholderValue)
    
    if result == .success, let placeholder = placeholderValue as? String {
        return placeholder
    }
    return nil
}

private func hasPlaceholderText(_ element: AXUIElement, currentText: String, cursorPosition: Int) -> Bool {
    // Only check when cursor is at beginning
    guard cursorPosition == 0 else { return false }
    
    // Check if there's a placeholder attribute
    if let placeholder = getPlaceholderText(from: element) {
        // Compare current text with actual placeholder value
        let normalizedCurrent = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPlaceholder = placeholder.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return normalizedCurrent.caseInsensitiveCompare(normalizedPlaceholder) == .orderedSame
    }
    
    return false
}
```

### Why This is Better

1. **Semantic Accuracy**: Uses the actual placeholder value from the element
2. **Future-Proof**: Works with any placeholder text, regardless of language or content
3. **Standards-Compliant**: Uses proper accessibility semantics
4. **Cross-Application**: Works consistently across all applications that properly implement accessibility

## 2. Enhanced Hybrid Approach

### Combining API Detection with Fallback Patterns

```swift
private func isPlaceholderText(_ text: String, cursorPosition: Int, element: AXUIElement) -> Bool {
    // Only check for placeholder replacement if cursor is at the beginning
    guard cursorPosition == 0 else {
        return false
    }
    
    // Primary method: Check accessibility API for placeholder
    if let placeholderValue = getPlaceholderText(from: element) {
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

private func getPlaceholderText(from element: AXUIElement) -> String? {
    var placeholderValue: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, "AXPlaceholderValue" as CFString, &placeholderValue)
    
    if result == .success, let placeholder = placeholderValue as? String, !placeholder.isEmpty {
        return placeholder
    }
    return nil
}

private func isPlaceholderTextByPattern(_ text: String, cursorPosition: Int) -> Bool {
    // Existing pattern-based logic as fallback
    // ... (current implementation)
}
```

## 3. Additional Accessibility Attributes for Context

### Other Relevant Attributes

```swift
// Check if element has placeholder support
private func supportsPlaceholder(_ element: AXUIElement) -> Bool {
    var attributes: CFArray?
    let result = AXUIElementCopyAttributeNames(element, &attributes)
    
    if result == .success, let attributeNames = attributes as? [String] {
        return attributeNames.contains("AXPlaceholderValue")
    }
    return false
}

// Get element's role to understand context better
private func getElementRole(_ element: AXUIElement) -> String? {
    var roleRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
       let role = roleRef as? String {
        return role
    }
    return nil
}

// Check if element is a text input field
private func isTextInputElement(_ element: AXUIElement) -> Bool {
    guard let role = getElementRole(element) else { return false }
    
    let textInputRoles = [
        "AXTextField",
        "AXTextArea", 
        "AXSearchField",
        "AXSecureTextField"
    ]
    
    return textInputRoles.contains(role)
}
```

## 4. Browser-Specific Considerations

### Web Applications (Chrome, Safari, Firefox)

For web applications like ChatGPT, the placeholder detection can be enhanced:

```swift
private func isWebApplicationPlaceholder(_ text: String, appInfo: AppInfo, element: AXUIElement) -> Bool {
    // Check if we're in a web browser
    let webBrowsers = ["Safari", "Chrome", "Firefox", "Edge"]
    guard webBrowsers.contains(appInfo.name) else { return false }
    
    // For web apps, check both AX placeholder and common web patterns
    if let placeholder = getPlaceholderText(from: element) {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(placeholder.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }
    
    // Web-specific placeholder patterns
    let webPlaceholderPatterns = [
        "ask anything",           // ChatGPT
        "message chatgpt",        // ChatGPT alternative
        "search google",          // Google Search
        "search or type url",     // Browser address bar
        "type a message",         // Various chat apps
        "what's on your mind",    // Social media
        "start typing",           // Generic web inputs
    ]
    
    let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return webPlaceholderPatterns.contains(normalizedText)
}
```

## 5. Implementation Strategy

### Recommended Approach

1. **Primary**: Use `kAXPlaceholderValueAttribute` for accurate placeholder detection
2. **Secondary**: Fall back to enhanced pattern matching for applications that don't properly expose placeholder values
3. **Tertiary**: Use context clues (element role, app type, cursor position, text length)

### Benefits of This Approach

- **Robust**: Uses proper accessibility semantics when available
- **Compatible**: Falls back gracefully for applications with poor accessibility implementation
- **Maintainable**: Reduces need for manual pattern updates
- **Future-Proof**: Adapts to new applications automatically

## 6. Testing Considerations

### Verification Methods

```swift
private func logPlaceholderDetection(_ element: AXUIElement, text: String, cursorPosition: Int) {
    let placeholder = getPlaceholderText(from: element)
    let role = getElementRole(element)
    let supportsPlaceholder = supportsPlaceholder(element)
    
    print("📊 Placeholder Detection Analysis:")
    print("   Current text: '\(text)'")
    print("   Cursor position: \(cursorPosition)")
    print("   Element role: \(role ?? "unknown")")
    print("   Supports placeholder: \(supportsPlaceholder)")
    print("   AX Placeholder value: '\(placeholder ?? "none")'")
}
```

## 7. Conclusion

The most robust approach would be to implement the `kAXPlaceholderValueAttribute`-based detection as the primary method, with our current pattern-based approach as a fallback. This provides:

1. **Accuracy**: Uses semantic information when available
2. **Compatibility**: Works with applications that have poor accessibility implementation
3. **Maintainability**: Reduces manual pattern maintenance
4. **Standards Compliance**: Follows accessibility best practices

This approach would significantly improve the reliability of placeholder detection while maintaining backward compatibility with our current solution.
