#!/bin/bash

# setup-sparkle.sh - Set up Sparkle auto-updater with key generation

set -e

echo "🔐 Setting up Sparkle auto-updater..."

# Check if we're in the right directory
if [[ ! -f "VTSApp.xcodeproj/project.pbxproj" ]]; then
    echo "❌ Error: Must be run from the root of the VTS project"
    exit 1
fi

# Create a temporary directory for Sparkle tools
TEMP_DIR=$(mktemp -d)
SPARKLE_VERSION="2.6.4"
SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"

echo "📥 Downloading Sparkle tools..."
curl -L -o "${TEMP_DIR}/sparkle.tar.xz" "$SPARKLE_URL"

cd "$TEMP_DIR"
tar -xf sparkle.tar.xz

echo "🔑 Generating EdDSA key pair for code signing updates..."

# Run generate_keys and capture its output
KEY_OUTPUT=$(./bin/generate_keys 2>&1)
echo "$KEY_OUTPUT"

# Extract the public key from the output
PUBLIC_KEY=$(echo "$KEY_OUTPUT" | grep -A 1 "SUPublicEDKey" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

if [[ -n "$PUBLIC_KEY" ]]; then
    echo ""
    echo "✅ Keys generated successfully!"
    echo ""
    echo "� Public key extracted from keychain:"
    echo "Public Key: $PUBLIC_KEY"
    echo ""
    echo "🔐 IMPORTANT: Private key is stored in your macOS keychain"
    echo "To get the private key for GitHub Secrets:"
    echo ""
    echo "1. Open Keychain Access app"
    echo "2. Search for 'Sparkle' or the key name"
    echo "3. Double-click the private key entry"
    echo "4. Check 'Show password' and enter your macOS password"
    echo "5. Copy the private key value to use as SPARKLE_PRIVATE_KEY secret"
    echo ""
    echo "OR use this command to extract it:"
    echo "security find-generic-password -s 'https://sparkle-project.org' -a 'ed25519' -w"
    
    # Update Info.plist with the public key
    cd - > /dev/null
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/SPARKLE_PUBLIC_KEY_PLACEHOLDER/$PUBLIC_KEY/g" VTSApp/Info.plist
    else
        # Linux/CI
        sed -i "s/SPARKLE_PUBLIC_KEY_PLACEHOLDER/$PUBLIC_KEY/g" VTSApp/Info.plist
    fi
    
    echo "✅ Updated Info.plist with public key"
    
    # Create instructions
    cat > sparkle-setup-instructions.md << EOF
# Sparkle Setup Instructions

## ✅ Completed
1. Public key has been added to Info.plist: $PUBLIC_KEY
2. Private key stored in macOS keychain
3. Appcast feed configured at: https://j05u3.github.io/VTS/appcast.xml

## 🔐 GitHub Secrets Required

Add the following secret to your GitHub repository (Settings → Secrets and Variables → Actions):

**Secret Name:** SPARKLE_PRIVATE_KEY

**How to get the Private Key:**
1. Open Keychain Access app
2. Search for 'Sparkle Private Key'
3. Double-click the private key entry
4. Check 'Show password' and enter your macOS password
5. Copy the private key value

**OR use this terminal command:**
\`\`\`bash
security find-generic-password -s "https://sparkle-project.org" -a "ed25519" -w
\`\`\`

## 📋 GitHub Pages Setup

Enable GitHub Pages for appcast hosting:
1. Go to repository Settings → Pages
2. Set Source to "GitHub Actions"
3. The workflow will automatically deploy the appcast
4. The appcast will be available at: https://j05u3.github.io/VTS/appcast.xml

## 🚀 Next Steps

1. Extract the private key from keychain and add to GitHub Secrets as SPARKLE_PRIVATE_KEY
2. Enable GitHub Pages with "GitHub Actions" as the source
3. Commit and push the changes to trigger release-please workflow
4. Create your first conventional commit PR to test the system

EOF

    echo ""
    echo "📋 Setup instructions saved to: sparkle-setup-instructions.md"
    
else
    echo "❌ Error: Failed to generate Sparkle keys"
    exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 Sparkle setup completed!"
echo "📖 See sparkle-setup-instructions.md for next steps"
