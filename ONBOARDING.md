# Onboarding System

## Overview

The VTS onboarding system provides a modern, user-friendly first-time setup experience that guides users through all necessary permissions and configuration steps before they start using the app.

## Architecture

### OnboardingManager
- **Purpose**: Manages onboarding state and progression
- **Location**: `VTSApp/VTS/Services/OnboardingManager.swift`
- **Key Features**:
  - Tracks completion state in UserDefaults
  - Manages step progression
  - Provides reset functionality for testing

### OnboardingView
- **Purpose**: Main container for the onboarding flow
- **Location**: `VTSApp/VTS/Views/OnboardingView.swift`
- **Key Features**:
  - Modern gradient background
  - Progress indicator
  - Smooth step transitions
  - Navigation controls

### Individual Steps
Located in `VTSApp/VTS/Views/OnboardingSteps/`:

1. **OnboardingWelcomeStep**: App introduction with feature highlights
2. **OnboardingMicrophoneStep**: Microphone permission with explanation
3. **OnboardingAPIKeyStep**: AI provider setup with key management
4. **OnboardingAccessibilityStep**: Text insertion permission (optional)
5. **OnboardingNotificationsStep**: Notification permission setup
6. **OnboardingTestStep**: Live recording and transcription test
7. **OnboardingCompletionStep**: Celebration and quick start guide

## Integration

### App Startup Flow
1. VTSApp checks `OnboardingManager.shared.isOnboardingCompleted`
2. If false: Shows OnboardingView in a window
3. If true: Initializes status bar and main app functionality
4. OnboardingView closes automatically when completed

### Permission Integration
- **Microphone**: Uses existing `CaptureEngine.permissionGranted`
- **API Keys**: Integrates with existing `APIKeyManager`
- **Accessibility**: Uses existing `TextInjector.hasAccessibilityPermission`
- **Notifications**: Uses existing `NotificationManager.shared`

### Testing Integration
- The test step actually records audio and transcribes it
- Uses the same services as the main app
- Provides real validation that the setup works

## UI/UX Features

### Modern Design
- Gradient backgrounds
- Smooth animations and transitions
- Card-based layouts
- Consistent iconography

### User Experience
- Clear explanations for each permission
- "Why we need this" explanations
- Optional steps clearly marked
- Progress indication
- Celebration on completion

### Accessibility
- Proper heading structure
- Clear navigation
- Keyboard shortcuts support
- Screen reader friendly

## Testing and Development

### Reset Onboarding
Added to Advanced Settings tab in Preferences:
- Developers can reset onboarding state
- Useful for testing the complete flow
- Calls `OnboardingManager.shared.resetOnboarding()`

### Preview Support
Each step includes SwiftUI previews for development and testing.

## File Structure

```
VTSApp/VTS/
├── Services/
│   └── OnboardingManager.swift
├── Views/
│   ├── OnboardingView.swift
│   └── OnboardingSteps/
│       ├── OnboardingWelcomeStep.swift
│       ├── OnboardingMicrophoneStep.swift
│       ├── OnboardingAPIKeyStep.swift
│       ├── OnboardingAccessibilityStep.swift
│       ├── OnboardingNotificationsStep.swift
│       ├── OnboardingTestStep.swift
│       └── OnboardingCompletionStep.swift
└── ...
```

## Future Enhancements

- Onboarding analytics (optional)
- A/B testing for different flows
- Localization support
- Video tutorials integration
- Advanced customization options