#!/bin/bash

# VTS DMG Build Script
# Creates a polished DMG with the same configuration as CI/CD
# Supports both local development and CI/CD environments

set -e

# Configuration
APP_NAME="VTSApp"
BUNDLE_ID="com.voicetypestudio.app"
SCHEME="VTSApp"
PROJECT="VTSApp.xcodeproj"
APPLE_TEAM_ID="887583966J"

# CI/CD Detection
CI_MODE=${CI:-false}
if [ "$GITHUB_ACTIONS" = "true" ]; then
    CI_MODE=true
fi

# Colors for output (disabled in CI)
if [ "$CI_MODE" = "true" ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Set GitHub Actions output (if in CI)
set_github_output() {
    if [ "$CI_MODE" = "true" ] && [ -n "$GITHUB_OUTPUT" ]; then
        echo "$1=$2" >> "$GITHUB_OUTPUT"
    fi
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi
    
    # Check for Node.js and install create-dmg
    if ! command -v node &> /dev/null; then
        if [ "$CI_MODE" = "true" ]; then
            log_error "Node.js not found in CI. This should be installed by the workflow."
            exit 1
        else
            log_warning "Node.js not found. Please install Node.js to use modern create-dmg."
            if command -v brew &> /dev/null; then
                log_info "Installing Node.js via Homebrew..."
                brew install node
            else
                log_error "Homebrew not found. Please install Node.js manually."
                exit 1
            fi
        fi
    fi
    
    # Install or update sindresorhus/create-dmg
    if ! command -v create-dmg &> /dev/null || ! create-dmg --version &> /dev/null; then
        log_info "Installing modern create-dmg (sindresorhus/create-dmg)..."
        npm install --global create-dmg
    else
        # Check if it's the right create-dmg (Node.js version has --version flag)
        if ! create-dmg --version &> /dev/null; then
            log_info "Found old create-dmg, installing modern version..."
            npm install --global create-dmg
        fi
    fi
    
    log_success "Dependencies verified"
}

# Get/set version
handle_version() {
    if [ "$CI_MODE" = "true" ]; then
        # In CI: Use version from GitHub workflow
        if [ -n "$INPUT_VERSION" ]; then
            # Manual workflow dispatch
            VERSION_WITH_V="$INPUT_VERSION"
        else
            # Tag-based release
            VERSION_WITH_V=${GITHUB_REF#refs/tags/}
        fi
        VERSION=${VERSION_WITH_V#v}  # Remove 'v' prefix
        
        # Update Info.plist with CI version
        log_info "Updating version in Info.plist to $VERSION (build $GITHUB_RUN_NUMBER)"
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" VTSApp/Info.plist
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $GITHUB_RUN_NUMBER" VTSApp/Info.plist
        
        # Set GitHub output
        set_github_output "version" "$VERSION_WITH_V"
        set_github_output "version_number" "$VERSION"
    else
        # Local: Read from Info.plist
        VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" VTSApp/Info.plist)
        BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" VTSApp/Info.plist)
        
        if [ -z "$VERSION" ]; then
            log_error "Could not read version from Info.plist"
            exit 1
        fi
    fi
    
    log_info "Building version $VERSION"
}

# Setup code signing keychain (CI only)
setup_keychain() {
    if [ "$CI_MODE" != "true" ]; then
        return
    fi
    
    log_info "Setting up temporary keychain for CI..."
    
    # Create temporary keychain
    KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
    
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    
    # Import certificate
    printf '%s' "$BUILD_CERTIFICATE_BASE64" | base64 --decode > certificate.p12
    security import certificate.p12 -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
    security list-keychain -d user -s "$KEYCHAIN_PATH"
    
    # Verify certificate
    security find-identity -v -p codesigning "$KEYCHAIN_PATH"
    
    log_success "Keychain setup completed"
}

# Clean previous builds
clean_build() {
    log_info "Cleaning previous builds..."
    rm -rf build/
    mkdir -p build
    log_success "Build directory cleaned"
}

# Build the application
build_app() {
    log_info "Building universal binary..."
    
    # Resolve dependencies first
    log_info "Resolving Swift Package dependencies..."
    xcodebuild -resolvePackageDependencies -scheme "$SCHEME" -project "$PROJECT"
    
    # Create archive
    log_info "Creating archive..."
    
    # Set development team
    TEAM_ARG=""
    if [ -n "$APPLE_TEAM_ID" ]; then
        TEAM_ARG="DEVELOPMENT_TEAM=$APPLE_TEAM_ID"
    fi
    
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "build/$APP_NAME.xcarchive" \
        -arch arm64 -arch x86_64 \
        $TEAM_ARG \
        archive
    
    log_success "Archive created successfully"
    
    # Export app
    log_info "Exporting application..."
    xcodebuild \
        -exportArchive \
        -archivePath "build/$APP_NAME.xcarchive" \
        -exportOptionsPlist scripts/ExportOptions.plist \
        -exportPath build/export \
        $TEAM_ARG
    
    # Verify the build
    APP_PATH="build/export/$APP_NAME.app"
    if [ ! -d "$APP_PATH" ]; then
        log_error "Application not found at $APP_PATH"
        exit 1
    fi
    
    # Verify universal binary
    log_info "Verifying universal binary..."
    BINARY_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
    if [ -f "$BINARY_PATH" ]; then
        lipo -info "$BINARY_PATH"
        if lipo -info "$BINARY_PATH" | grep -q "arm64.*x86_64\|x86_64.*arm64"; then
            log_success "Universal binary verified (Intel + Apple Silicon)"
        else
            log_warning "Binary architecture verification unclear"
        fi
    else
        log_warning "Could not verify binary architecture"
    fi
    
    log_success "Application export completed"
}

# Create DMG using modern sindresorhus/create-dmg
create_dmg() {
    log_info "Creating DMG with modern create-dmg..."
    
    APP_PATH="build/export/$APP_NAME.app"
    DMG_NAME="$APP_NAME-$VERSION-Universal.dmg"
    
    # Remove old DMG if exists
    [ -f "$DMG_NAME" ] && rm "$DMG_NAME"
    
    # The modern create-dmg is much simpler and more opinionated
    # It automatically creates a beautiful DMG with proper layout
    log_info "Using sindresorhus/create-dmg for professional DMG creation..."
    
    # Options for create-dmg:
    # --overwrite: Replace existing DMG
    # --dmg-title: Custom title (will use app name by default)
    CREATE_DMG_ARGS="--overwrite"
    
    # Set custom title if needed
    if [ ${#APP_NAME} -le 27 ]; then
        CREATE_DMG_ARGS="$CREATE_DMG_ARGS --dmg-title=\"$APP_NAME $VERSION\""
    fi
    
    # Create the DMG
    if eval create-dmg $CREATE_DMG_ARGS "\"$APP_PATH\"" 2>/dev/null; then
        # Find the created DMG (create-dmg creates it with app name and version)
        CREATED_DMG=$(find . -name "*$APP_NAME*.dmg" -type f -newer "$APP_PATH" | head -n1)
        
        if [ -n "$CREATED_DMG" ] && [ -f "$CREATED_DMG" ]; then
            # Rename to our expected name if different
            if [ "$CREATED_DMG" != "./$DMG_NAME" ]; then
                mv "$CREATED_DMG" "$DMG_NAME"
            fi
            
            log_success "DMG created: $DMG_NAME"
            
            # Show file size
            SIZE=$(du -h "$DMG_NAME" | cut -f1)
            log_info "DMG size: $SIZE"
            
            # Store DMG name for later steps
            echo "$DMG_NAME" > dmg_name.txt
        else
            log_error "Could not find created DMG file"
            exit 1
        fi
    else
        log_error "DMG creation failed"
        exit 1
    fi
}

# Code signing function
code_sign() {
    if [ "$SKIP_SIGNING" = "true" ]; then
        log_info "Skipping code signing (SKIP_SIGNING=true)"
        return
    fi
    
    log_info "Code signing application and DMG..."
    
    APP_PATH="build/export/$APP_NAME.app"
    DMG_NAME=$(cat dmg_name.txt)
    
    # Check if Developer ID certificate is available
    if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        log_info "Code signing certificate found. Signing application..."
        
        # Unlock keychain if in CI mode
        if [ "$CI_MODE" = "true" ]; then
            KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
            security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
        fi
        
        # Sign the app
        codesign \
            --deep \
            --force \
            --options runtime \
            --timestamp \
            --sign "Developer ID Application" \
            "$APP_PATH"
        
        log_success "Application signed"
        
        # Verify signatures
        codesign --verify --verbose "$APP_PATH"
        codesign --verify --verbose "$DMG_NAME"
        
        log_success "Code signing completed and verified"
    else
        if [ "$CI_MODE" = "true" ]; then
            log_error "No Developer ID Application certificate found in CI"
            exit 1
        else
            log_warning "No Developer ID Application certificate found"
            log_info "DMG will be created without code signing"
            log_info "To skip this check, run with: SKIP_SIGNING=true ./scripts/build-dmg.sh"
        fi
    fi
}

# Notarization (CI only)
notarize_dmg() {
    if [ "$CI_MODE" != "true" ]; then
        log_info "Skipping notarization (not in CI mode)"
        return
    fi
    
    if [ "$SKIP_SIGNING" = "true" ]; then
        log_info "Skipping notarization (SKIP_SIGNING=true)"
        return
    fi
    
    log_info "Starting notarization process..."
    
    DMG_NAME=$(cat dmg_name.txt)
    
    # Submit for notarization
    log_info "Submitting DMG for notarization..."
    xcrun notarytool submit "$DMG_NAME" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait \
        --timeout 30m \
        --verbose
    
    # Staple the notarization ticket
    log_info "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_NAME"
    
    # Verify notarization
    log_info "Verifying notarization..."
    xcrun stapler validate "$DMG_NAME"
    
    log_success "Notarization completed successfully"
}

# Generate checksums
generate_checksums() {
    log_info "Generating checksums..."
    
    DMG_NAME=$(cat dmg_name.txt)
    
    # Generate checksums
    shasum -a 256 "$DMG_NAME" > checksums.txt
    shasum -a 512 "$DMG_NAME" >> checksums.txt
    
    log_info "Checksums generated:"
    cat checksums.txt
    
    if [ "$CI_MODE" != "true" ]; then
        # For local builds, also create individual checksum file
        CHECKSUM=$(shasum -a 256 "$DMG_NAME" | cut -d' ' -f1)
        echo "$CHECKSUM  $DMG_NAME" > "$DMG_NAME.sha256"
        log_success "Checksum saved to $DMG_NAME.sha256"
        echo "SHA-256: $CHECKSUM"
    fi
}

# Clean up keychain (CI only)
cleanup_keychain() {
    if [ "$CI_MODE" != "true" ]; then
        return
    fi
    
    log_info "Cleaning up temporary keychain..."
    KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
    if [ -f "$KEYCHAIN_PATH" ]; then
        security delete-keychain "$KEYCHAIN_PATH"
    fi
    rm -f certificate.p12
    log_success "Keychain cleanup completed"
}

# Main execution
main() {
    if [ "$CI_MODE" != "true" ]; then
        echo "🚀 VTS DMG Build Script"
        echo "========================"
    fi
    
    # Parse command line arguments (local mode only)
    if [ "$CI_MODE" != "true" ]; then
        while [[ $# -gt 0 ]]; do
            case $1 in
                --skip-signing)
                    SKIP_SIGNING=true
                    shift
                    ;;
                --clean)
                    CLEAN_ONLY=true
                    shift
                    ;;
                --help|-h)
                    echo "Usage: $0 [OPTIONS]"
                    echo ""
                    echo "Options:"
                    echo "  --skip-signing    Skip code signing step"
                    echo "  --clean          Only clean build directory"
                    echo "  --help, -h       Show this help message"
                    echo ""
                    echo "Environment variables:"
                    echo "  SKIP_SIGNING=true  Skip code signing"
                    echo "  CI=true           Run in CI mode"
                    echo ""
                    echo "Dependencies:"
                    echo "  - Xcode (required)"
                    echo "  - Node.js (required for modern create-dmg)"
                    echo "  - Homebrew (recommended for dependency installation)"
                    exit 0
                    ;;
                *)
                    log_error "Unknown option: $1"
                    echo "Use --help for usage information"
                    exit 1
                    ;;
            esac
        done
        
        if [ "$CLEAN_ONLY" = "true" ]; then
            clean_build
            log_success "Clean completed"
            exit 0
        fi
    fi
    
    # Main build process
    check_dependencies
    handle_version
    setup_keychain  # CI only
    clean_build
    build_app
    create_dmg
    code_sign
    notarize_dmg    # CI only
    generate_checksums
    
    # Cleanup
    cleanup_keychain  # CI only
    rm -f dmg_name.txt
    
    if [ "$CI_MODE" != "true" ]; then
        echo ""
        log_success "Build completed successfully!"
        echo ""
        echo "📦 Your DMG is ready: $APP_NAME-$VERSION-Universal.dmg"
        echo ""
        echo "To test the DMG:"
        echo "1. Double-click to mount it"
        echo "2. Try dragging the app to Applications"
        echo "3. Launch the app from Applications"
        echo ""
        echo "For distribution, consider code signing and notarization."
        echo "See DISTRIBUTION_SETUP.md for details on configuring certificates."
    else
        log_success "CI build completed successfully!"
        DMG_NAME=$(cat dmg_name.txt 2>/dev/null || echo "$APP_NAME-$VERSION-Universal.dmg")
        echo "DMG_NAME=$DMG_NAME" >> "$GITHUB_ENV"
    fi
}

# Run main function
main "$@" 