# Status Bar Icons Implementation

## Overview
This implementation replaces the emoji status bar icons (🔴, 🔵, ⚪️) with custom VTS logo icons in three states:
- **StatusIcon**: VTS logo for idle state (uses template rendering to adapt to menu bar theme)
- **StatusIconRecording**: Red circle with VTS logo for recording state
- **StatusIconProcessing**: Blue circle with VTS logo for processing state

## Implementation Details

### Code Changes
The `StatusBarController.swift` was updated to use `NSImage` instead of emoji text:

```swift
// Old implementation
button.title = "🔴"  // Red emoji
button.title = "🔵"  // Blue emoji  
button.title = "⚪️" // White emoji

// New implementation
button.image = NSImage(named: "StatusIconRecording")  // Red VTS icon
button.image = NSImage(named: "StatusIconProcessing") // Blue VTS icon
button.image = NSImage(named: "StatusIcon")           // Adaptive VTS icon
```

### Asset Structure
Added three new imagesets to `Assets.xcassets`:

```
Assets.xcassets/
├── StatusIcon.imageset/              # Idle state (template rendering)
│   ├── Contents.json
│   ├── status-idle.png              # 16x16pt
│   ├── status-idle@2x.png           # 32x32pt
│   └── status-idle@3x.png           # 48x48pt
├── StatusIconRecording.imageset/     # Recording state (red)
│   ├── Contents.json
│   ├── status-recording.png         # 16x16pt
│   ├── status-recording@2x.png      # 32x32pt
│   └── status-recording@3x.png      # 48x48pt
└── StatusIconProcessing.imageset/    # Processing state (blue)
    ├── Contents.json
    ├── status-processing.png        # 16x16pt
    ├── status-processing@2x.png     # 32x32pt
    └── status-processing@3x.png     # 48x48pt
```

### Template Rendering
- **Idle icon**: Uses template rendering (`isTemplate = true`) to automatically adapt to light/dark menu bar themes
- **Colored icons**: Preserve their specific colors (`isTemplate = false`) for recording (red) and processing (blue) states

## Design Requirements

### Size Specifications
- **1x**: 16x16pt (for standard displays)
- **2x**: 32x32pt (for Retina displays)  
- **3x**: 48x48pt (for high-DPI displays)
- **Status bar size**: Icons are rendered at 18x18pt in the status bar

### Color Scheme
- **Idle**: Monochrome VTS logo (adapts to menu bar theme via template rendering)
- **Recording**: Red circle (#FF3B30) with white VTS logo/text
- **Processing**: Blue circle (#007AFF) with white VTS logo/text

### Design Guidelines
1. **Minimalist**: Simple, clean design that works at small sizes
2. **VTS Branding**: Clear VTS logo or "VTS" text 
3. **Status Bar Optimized**: Designed specifically for macOS menu bar
4. **Theme Adaptive**: Idle state adapts to light/dark themes

## Current Status
✅ **Code implementation complete** - StatusBarController updated to use images  
✅ **Asset structure created** - All imagesets and Contents.json files added  
🔄 **Placeholder icons** - Currently using app icon as temporary placeholders  
⏳ **Final design needed** - Proper VTS status bar icons need to be designed and added

## Next Steps
1. **Design proper icons** following the specifications above
2. **Replace placeholder PNGs** in each imageset folder
3. **Test in Xcode** with both light and dark menu bar themes
4. **Verify sizing** at actual status bar resolution

## SVG Templates
SVG templates showing the desired design are included:
- `status-idle-16.svg` - White circle with dark VTS text
- `status-recording-16.svg` - Red circle with white VTS text  
- `status-processing-16.svg` - Blue circle with white VTS text

These can be used as a starting point for creating the final PNG assets.