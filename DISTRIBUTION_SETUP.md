# VTS CI/CD Setup Guide

This guide walks you through setting up automated builds, code signing, and distribution for your VTS macOS app.

## 📋 Prerequisites

### Apple Developer Account Requirements
- **Apple Developer Program membership** ($99/year)
- **Developer ID Application certificate** (for outside Mac App Store distribution)
- **App Store Connect API key** (for automated notarization)

### Development Environment
- **macOS** (for local development and testing)
- **Xcode 16.2+** 
- **Node.js 18+** (for modern DMG creation)
- **Homebrew** (recommended for installing dependencies)

## 🔐 Apple Developer Setup

### 1. Generate Developer ID Application Certificate

1. **Log in to Apple Developer Portal**
   - Go to [developer.apple.com](https://developer.apple.com)
   - Sign in with your developer account

2. **Create Certificate**
   - Navigate to **Certificates, Identifiers & Profiles**
   - Click **Certificates** → **+** (Add new)
   - Select **Developer ID Application**
   - Follow the prompts to generate a Certificate Signing Request (CSR)
   - Download the certificate (.cer file)

3. **Install Certificate**
   - Double-click the downloaded certificate
   - Add it to your **login** keychain
   - Verify it appears in Keychain Access under "My Certificates"

### 2. Export Certificate for CI/CD

1. **Open Keychain Access**
2. **Find your certificate** under "My Certificates"
3. **Right-click** → **Export**
4. **Save as .p12 file** with a strong password
5. **Convert to base64** for GitHub Secrets:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```

### 3. Create App Store Connect API Key

1. **Go to App Store Connect**
   - Visit [appstoreconnect.apple.com](https://appstoreconnect.apple.com)

2. **Generate API Key**
   - Go to **Users and Access** → **Keys**
   - Click **+** to generate new key
   - **Name**: "VTS CI/CD"
   - **Access**: **Developer** (minimum required)
   - **Download the .p8 file** (you can only download it once!)

3. **Note the details**:
   - **Key ID**: (shown after creation)
   - **Issuer ID**: (shown in the Keys section)
   - **Team ID**: (your 10-character team identifier)

## 🔧 GitHub Repository Setup

### 1. Configure GitHub Secrets

Go to your repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Description | Example/Format |
|-------------|-------------|----------------|
| `BUILD_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate | `MIIKtAIBAzCCCn4GCSqGSIb3DQEHA...` |
| `P12_PASSWORD` | Password for the .p12 certificate | `your-certificate-password` |
| `KEYCHAIN_PASSWORD` | Temporary keychain password | `temp-keychain-password` |
| `APPLE_ID` | Apple ID email for notarization | `you@example.com` |
| `APPLE_ID_PASSWORD` | App-specific password | `abcd-efgh-ijkl-mnop` |
| `APPLE_TEAM_ID` | 10-character Apple Team ID | `ABCDEF1234` |

### 2. Create App-Specific Password

For `APPLE_ID_PASSWORD`:

1. **Go to Apple ID account page**
   - Visit [appleid.apple.com](https://appleid.apple.com)

2. **Generate app-specific password**
   - Sign in → **App-Specific Passwords**
   - Click **+** → Name it "VTS CI/CD"
   - **Copy the generated password** (format: `abcd-efgh-ijkl-mnop`)

### 3. Update Bundle Identifier (if needed)

If you want to change the bundle identifier from `com.voicetypestudio.app`:

1. **Update Xcode project**:
   - Open `VTSApp.xcodeproj`
   - Select project → Target → **Signing & Capabilities**
   - Change **Bundle Identifier**

2. **Update workflow files**:
   - Edit `.github/workflows/release.yml`
   - Update `BUNDLE_ID` environment variable
   - Edit `scripts/ExportOptions.plist`
   - Update the bundle identifier in `provisioningProfiles`

## 🚀 Testing Your Setup

### 1. Local Build Test

First, test building locally:

```bash
# Make the script executable
chmod +x scripts/build-dmg.sh

# Install dependencies (if not already installed)
# Node.js (for modern DMG creation)
brew install node

# Build without signing (for testing)
SKIP_SIGNING=true ./scripts/build-dmg.sh

# Or build with signing (if certificates are set up)
./scripts/build-dmg.sh
```

The script will automatically:
- Install the modern `create-dmg` tool (sindresorhus/create-dmg)
- Create a professional-looking DMG with automatic layout
- Generate a custom DMG icon based on your app icon

### 2. CI/CD Test

Test your setup by creating a release:

**Option A (Recommended)**: Use the tag workflow
- Go to **Actions** → **Create and Push Tag**
- Enter version like `0.2.1` → Creates `v0.2.1` tag automatically

**Option B**: Manual tag creation
```bash
git tag v0.2.1 && git push origin v0.2.1
```

Monitor the build in the **Actions** tab.

## 🔍 Troubleshooting

### Common Issues

#### Certificate Issues
```
error: No signing certificate "Developer ID Application" found
```
**Solution**: Ensure your certificate is properly installed and exported.

#### Notarization Issues
```
error: Invalid credentials. Username or password is incorrect.
```
**Solution**: 
- Verify `APPLE_ID` and `APPLE_ID_PASSWORD` secrets
- Ensure app-specific password is used (not regular password)
- Check `APPLE_TEAM_ID` is correct

#### Node.js Issues
```
error: Node.js not found
```
**Solution**: Install Node.js:
```bash
# On macOS with Homebrew
brew install node

# Verify installation
node --version
npm --version
```

#### DMG Creation Issues
```
create-dmg: command not found
```
**Solution**: The script will automatically install modern create-dmg, but you can manually install:
```bash
npm install --global create-dmg
```

#### Build Architecture Issues
```
error: Building for "arm64" but attempting to link with file built for "x86_64"
```
**Solution**: Clean build directory and dependencies:
```bash
# Clean everything
rm -rf build/ .build/
# In Xcode: Product → Clean Build Folder
```

### Debug Commands

**Verify certificate installation**:
```bash
security find-identity -v -p codesigning
```

**Check app signature**:
```bash
codesign --verify --verbose YourApp.app
spctl --assess --verbose YourApp.app
```

**Test notarization status**:
```bash
xcrun stapler validate YourApp.dmg
```

**Check Node.js and create-dmg**:
```bash
node --version
npm list -g create-dmg
create-dmg --version
```

## 📁 Project Structure

Your repository should have these files for CI/CD:

```
VTS/
├── .github/
│   └── workflows/
│       ├── create-tag.yml           # Tag creation workflow
│       └── release.yml              # GitHub Actions release workflow
├── scripts/
│   ├── ExportOptions.plist          # Xcode export settings
│   └── build-dmg.sh                # Unified build script
├── VTSApp/
│   ├── Info.plist                  # App configuration
│   └── VTSApp.entitlements         # App permissions
└── DISTRIBUTION_SETUP.md                        # This guide
```

## 🔄 Version Management

Two ways to create releases:

### Tag Workflow (Recommended)
1. Go to **Actions** → **Create and Push Tag**
2. Enter version (e.g., `1.2.3`) → Auto-validates semver and adds 'v' prefix
3. Creates tag `v1.2.3` → Triggers release automatically

### Manual Tags
```bash
git tag v1.2.3 && git push origin v1.2.3
```

The release workflow extracts version from tags and uses GitHub run numbers for build numbers.

## 🛡️ Security Best Practices

1. **Never commit certificates** or private keys to git
2. **Use app-specific passwords** instead of your main Apple ID password
3. **Regularly rotate** app-specific passwords
4. **Limit API key permissions** to minimum required
5. **Monitor** GitHub Actions logs for sensitive data leaks

## 📞 Support

If you encounter issues:

1. **Check GitHub Actions logs** for detailed error messages
2. **Verify all secrets** are properly set
3. **Test locally first** with the build script
4. **Ensure Node.js is installed** (version 18 or later)
5. **Consult Apple Developer documentation** for certificate issues

---

## 🎉 Success!

Once set up, create releases easily:

**Tag Workflow**: Actions → Create and Push Tag → Enter version → Auto-release
**Manual**: `git tag v1.2.3 && git push origin v1.2.3` → Auto-release

Result: Professional DMG with code signing, notarization, and GitHub release! 🚀