# Adding Sparkle to VTS Xcode Project

Since VTS uses an Xcode project (not pure Swift Package Manager), Sparkle needs to be added through Xcode's Package Manager interface.

## 📋 Steps to Add Sparkle

### 1. Open Xcode Project
```bash
open VTSApp.xcodeproj
```

### 2. Add Package Dependency
1. In Xcode, select the **VTSApp** project in the navigator
2. Select the **VTSApp** target
3. Go to the **Package Dependencies** tab
4. Click the **+** button
5. Enter the repository URL: `https://github.com/sparkle-project/Sparkle`
6. Click **Add Package**
7. In the package options:
   - **Dependency Rule**: Up to Next Major Version
   - **Version**: 2.6.0 (or latest)
8. Click **Add Package**
9. Select **Sparkle** framework and click **Add Package**

### 3. Verify Integration
- Check that Sparkle appears in the Package Dependencies section
- Build the project to ensure no errors: **⌘+B**

### 4. Enable Sparkle Code
After successfully adding Sparkle to Xcode:

1. **Uncomment Sparkle imports:**
   ```swift
   // In SparkleUpdaterManager.swift, change:
   // import Sparkle // TODO: Add Sparkle package dependency through Xcode
   // To:
   import Sparkle
   ```

2. **Uncomment Sparkle implementation:**
   - Uncomment all the TODO-marked code sections in `SparkleUpdaterManager.swift`
   - Replace placeholder implementations with actual Sparkle calls

### 5. Generate Sparkle Keys
```bash
./scripts/setup-sparkle.sh
```

### 6. Set up GitHub Pages
1. Go to repository Settings → Pages
2. Set Source to "GitHub Actions"
3. The Pages workflow will automatically deploy your appcast
4. Verify at: `https://j05u3.github.io/VTS/appcast.xml`

### 7. Add GitHub Secrets
Add `SPARKLE_PRIVATE_KEY` secret with the private key from step 5.

### 8. Test the Integration
1. Build and run the app
2. Go to Preferences → Permissions tab
3. Verify the Auto-Update Settings section appears
4. Test the "Check Now" button

## 🔧 Alternative: Manual Framework Addition

If package manager doesn't work, you can add Sparkle manually:

### Option A: Download and Add Framework
1. Download Sparkle from [releases page](https://github.com/sparkle-project/Sparkle/releases)
2. Extract and add `Sparkle.framework` to your project
3. Embed the framework in your app bundle

### Option B: CocoaPods (if preferred)
Add to `Podfile`:
```ruby
pod 'Sparkle', '~> 2.6'
```

## 📡 GitHub Pages Appcast

The appcast is automatically generated from GitHub Releases:
- **Template**: `docs/appcast.xml` (Jekyll template)
- **Generated URL**: `https://j05u3.github.io/VTS/appcast.xml`
- **Updates**: Automatically when new releases are published
- **Features**: 
  - Rich HTML descriptions with changelog
  - Download links with file sizes
  - Proper Sparkle XML attributes
  - Security-signed downloads

## ✅ Verification Checklist

After adding Sparkle:
- [ ] Project builds without errors
- [ ] SparkleUpdaterManager compiles fully
- [ ] Auto-update preferences visible in app
- [ ] "Check Now" button functional
- [ ] GitHub Pages site loads at `https://j05u3.github.io/VTS/`
- [ ] Appcast XML is valid and accessible
- [ ] No runtime crashes when accessing Sparkle features

## 🐛 Common Issues

### "No such module 'Sparkle'"
- Ensure Sparkle is added to the correct target
- Clean and rebuild the project (**⌘+Shift+K**, then **⌘+B**)
- Check Package Dependencies tab shows Sparkle

### GitHub Pages Not Working
- Check that Pages is enabled in repository settings
- Verify the Pages workflow ran successfully
- Check `docs/_config.yml` configuration
- Ensure repository is public (required for free GitHub Pages)

### Runtime Crashes
- Verify Info.plist contains required Sparkle keys
- Check appcast URL is accessible
- Ensure public key is properly formatted and matches private key

### Updates Not Working
- Test appcast URL in browser: `https://j05u3.github.io/VTS/appcast.xml`
- Verify code signing matches private key in GitHub Secrets
- Check app console for Sparkle error messages
- Ensure release workflow completed successfully

## 🚀 Release Workflow

Once everything is set up, the workflow is:

1. **Developer creates PR** with conventional commit title
2. **Semantic validation** ensures proper format
3. **Merge PR** → release-please analyzes commits
4. **Review release PR** with auto-generated changelog
5. **Merge release PR** → triggers build, sign, notarize, publish
6. **GitHub Pages updates** appcast automatically
7. **Users receive update notification** via Sparkle

## 🔒 Security Notes

- Private key stored securely in GitHub Secrets
- Public key embedded in app's Info.plist
- All downloads served over HTTPS from GitHub
- DMG files are notarized by Apple
- Sparkle verifies signatures before installing updates

The placeholder implementation ensures the app works without Sparkle, but full auto-update functionality requires the actual Sparkle framework.
