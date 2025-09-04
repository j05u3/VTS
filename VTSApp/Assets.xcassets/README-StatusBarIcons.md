# Status Bar Icons - Design Guidelines

## Overview
This directory contains the status bar icons for VTS with three states:
- **StatusIcon**: White circle with VTS logo (idle state)
- **StatusIconRecording**: Red circle with VTS logo (recording state) 
- **StatusIconProcessing**: Blue circle with VTS logo (processing state)

## Current Status
The placeholder images are currently using the app icon. These need to be replaced with proper status bar icons designed specifically for the macOS status bar.

## Design Requirements

### Size Specifications
- **1x**: 16x16px (for standard displays)
- **2x**: 32x32px (for Retina displays)  
- **3x**: 48x48px (for high-DPI displays)

### Design Guidelines
1. **Simple and Clean**: Icons should be minimal and easily recognizable at small sizes
2. **VTS Logo**: Each icon should contain the VTS logo or "VTS" text inside a circle
3. **Color Scheme**:
   - Idle: White circle with dark gray VTS logo/text
   - Recording: Red circle (#FF3B30) with white VTS logo/text
   - Processing: Blue circle (#007AFF) with white VTS logo/text
4. **Status Bar Optimized**: Icons should look good against both light and dark menu bars

### File Format
- PNG format with transparency
- High quality, crisp edges
- Properly sized for each resolution

## Implementation
The icons are loaded in `StatusBarController.swift` using:
- `NSImage(named: "StatusIcon")` - Idle state
- `NSImage(named: "StatusIconRecording")` - Recording state  
- `NSImage(named: "StatusIconProcessing")` - Processing state

## To Complete This Implementation
1. Design proper VTS status bar icons following the guidelines above
2. Replace the placeholder PNG files in each imageset folder
3. Test the icons in both light and dark menu bar themes
4. Ensure icons are clear and recognizable at actual status bar size