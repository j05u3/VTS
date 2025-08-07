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
./bin/generate_keys

PRIVATE_KEY_FILE="sparkle_private_key"
PUBLIC_KEY_FILE="sparkle_public_key"

if [[ -f "$PRIVATE_KEY_FILE" && -f "$PUBLIC_KEY_FILE" ]]; then
    PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")
    
    echo "✅ Keys generated successfully!"
    echo ""
    echo "🔐 IMPORTANT: Store this private key securely!"
    echo "GitHub Secret Name: SPARKLE_PRIVATE_KEY"
    echo "Private Key Content:"
    echo "----"
    cat "$PRIVATE_KEY_FILE"
    echo ""
    echo "----"
    echo ""
    echo "📝 Public key will be added to Info.plist automatically:"
    echo "Public Key: $PUBLIC_KEY"
    
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
1. Public key has been added to Info.plist
2. Appcast feed configured at: https://j05u3.github.io/VTS/appcast.xml

## 🔐 GitHub Secrets Required

Add the following secret to your GitHub repository (Settings → Secrets and Variables → Actions):

**Secret Name:** SPARKLE_PRIVATE_KEY
**Secret Value:** (copy the private key displayed above)

## 🚀 Next Steps

1. Add the SPARKLE_PRIVATE_KEY to GitHub repository secrets
2. Set up SparkleHub (optional) or GitHub Pages for appcast hosting
3. Commit and push the changes to trigger release-please workflow

## 📋 GitHub Pages Setup

Enable GitHub Pages for appcast hosting:
1. Go to repository Settings → Pages
2. Set Source to "GitHub Actions"
3. The workflow will automatically deploy the appcast
4. The appcast will be available at: https://j05u3.github.io/VTS/appcast.xml

## � Next Steps

1. Add the SPARKLE_PRIVATE_KEY to GitHub repository secrets
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
