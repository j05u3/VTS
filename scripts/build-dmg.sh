#!/bin/bash

# VTS DMG Build Script
# ====================
# Creates a properly signed and notarized DMG for macOS distribution
# 
# Build Process:
# 1. Build universal app bundle (Intel + Apple Silicon)
# 2. Sign app bundle with Developer ID (before packaging)
# 3. Create and sign DMG container
# 4. Notarize DMG with Apple (CI only)
# 5. Generate checksums for distribution
#
# Supports both local development and CI/CD environments

set -e

# Configuration
APP_NAME="VTSApp"
BUNDLE_ID="com.voicetypestudio.app"
SCHEME="VTSApp"
PROJECT="VTSApp.xcodeproj"
APPLE_TEAM_ID="887583966J"

# Global variables
KEYCHAIN_PATH=""

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
    
    # Check for Xcode
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
                if ! brew install node; then
                    log_error "Failed to install Node.js via Homebrew"
                    exit 1
                fi
            else
                log_error "Homebrew not found. Please install Node.js manually."
                log_error "Visit: https://nodejs.org/en/download/"
                exit 1
            fi
        fi
    fi
    
    # Install or update sindresorhus/create-dmg
    if ! command -v create-dmg &> /dev/null; then
        log_info "Installing modern create-dmg (sindresorhus/create-dmg)..."
        if ! npm install --global create-dmg; then
            log_error "Failed to install create-dmg"
            exit 1
        fi
    else
        # Check if it's the modern create-dmg (Node.js version has --version flag)
        if ! create-dmg --version &> /dev/null; then
            log_info "Found old create-dmg, installing modern version..."
            if ! npm install --global create-dmg; then
                log_error "Failed to install modern create-dmg"
                exit 1
            fi
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
    if ! xcodebuild -resolvePackageDependencies -scheme "$SCHEME" -project "$PROJECT"; then
        log_error "Failed to resolve Swift Package dependencies"
        exit 1
    fi
    
    # Create archive
    log_info "Creating archive..."
    
    # Set development team
    local team_args=""
    if [ -n "$APPLE_TEAM_ID" ]; then
        team_args="DEVELOPMENT_TEAM=$APPLE_TEAM_ID"
    fi
    
    if ! xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "build/$APP_NAME.xcarchive" \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        $team_args \
        archive; then
        log_error "Failed to create archive"
        exit 1
    fi
    
    log_success "Archive created successfully"
    
    # Export app
    log_info "Exporting application..."
    if ! xcodebuild \
        -exportArchive \
        -archivePath "build/$APP_NAME.xcarchive" \
        -exportOptionsPlist scripts/ExportOptions.plist \
        -exportPath build/export \
        $team_args; then
        log_error "Failed to export application"
        exit 1
    fi
    
    # Verify the build
    local app_path="build/export/$APP_NAME.app"
    if [ ! -d "$app_path" ]; then
        log_error "Application not found at $app_path"
        exit 1
    fi
    
    # Verify universal binary
    log_info "Verifying universal binary..."
    local binary_path="$app_path/Contents/MacOS/$APP_NAME"
    if [ -f "$binary_path" ]; then
        lipo -info "$binary_path"
        if lipo -info "$binary_path" | grep -q "arm64.*x86_64\|x86_64.*arm64"; then
            log_success "Universal binary verified (Intel + Apple Silicon)"
        else
            log_warning "Binary architecture verification unclear"
        fi
    else
        log_warning "Could not verify binary architecture"
    fi
    
    log_success "Application export completed"
}

# Get code signing identity for our specific team
get_signing_identity() {
    if [ "$SKIP_SIGNING" = "true" ]; then
        return 1
    fi
    
    # Unlock keychain if in CI mode
    if [ "$CI_MODE" = "true" ] && [ -n "${KEYCHAIN_PATH:-}" ]; then
        security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" 2>/dev/null || true
    fi
    
    # Find Developer ID Application certificate for our specific team only
    if [ -z "$APPLE_TEAM_ID" ]; then
        log_error "APPLE_TEAM_ID is required for code signing"
        return 1
    fi
    
    local identity
    identity=$(security find-identity -v -p codesigning 2>/dev/null | \
               grep "Developer ID Application" | \
               grep "($APPLE_TEAM_ID)" | \
               head -n1 | \
               sed 's/.*"\(.*\)".*/\1/')
    
    if [ -n "$identity" ]; then
        log_info "Found certificate for team $APPLE_TEAM_ID: $identity"
        echo "$identity"
        return 0
    else
        log_error "No Developer ID Application certificate found for team: $APPLE_TEAM_ID"
        log_error "Available certificates:"
        security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" || log_error "  No Developer ID Application certificates found"
        return 1
    fi
}

# Create DMG using modern sindresorhus/create-dmg
create_dmg() {
    log_info "Creating DMG with modern create-dmg..."
    
    APP_PATH="build/export/$APP_NAME.app"
    DMG_NAME="$APP_NAME-$VERSION-Universal.dmg"
    
    # Remove old DMG if exists
    [ -f "$DMG_NAME" ] && rm "$DMG_NAME"
    
    # Verify the app bundle exists and is signed (if signing is enabled)
    if [ ! -d "$APP_PATH" ]; then
        log_error "Application bundle not found at $APP_PATH"
        exit 1
    fi
    
    if [ "$SKIP_SIGNING" != "true" ]; then
        log_info "Verifying app bundle signature before packaging..."
        if ! codesign --verify --verbose "$APP_PATH" 2>/dev/null; then
            log_error "App bundle is not properly signed. Cannot create DMG."
            exit 1
        fi
        log_info "App bundle signature verified"
    fi
    
    log_info "Using sindresorhus/create-dmg for professional DMG creation..."
    
    # Options for create-dmg
    CREATE_DMG_ARGS=("--overwrite")
    
    # Set custom title if needed
    if [ ${#APP_NAME} -le 27 ]; then
        CREATE_DMG_ARGS+=("--dmg-title" "$APP_NAME $VERSION")
    fi
    
    # Add DMG signing identity if available (this signs the DMG container, not the app)
    local signing_identity
    if [ "$SKIP_SIGNING" != "true" ] && signing_identity=$(get_signing_identity); then
        log_info "Will sign DMG container with: $signing_identity"
        CREATE_DMG_ARGS+=("--identity" "$signing_identity")
    fi
    
    # Create the DMG
    if create-dmg "${CREATE_DMG_ARGS[@]}" "$APP_PATH"; then
        # Find the created DMG
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
            
            # Verify DMG signature if signing was enabled
            if [ "$SKIP_SIGNING" != "true" ]; then
                log_info "Verifying DMG signature..."
                if codesign --verify --verbose "$DMG_NAME" 2>/dev/null; then
                    log_success "DMG signature verified"
                else
                    log_error "DMG signature verification failed"
                    exit 1
                fi
            fi
        else
            log_error "Could not find created DMG file"
            exit 1
        fi
    else
        log_error "DMG creation failed"
        exit 1
    fi
}

# Sign the application bundle
sign_app_bundle() {
    if [ "$SKIP_SIGNING" = "true" ]; then
        log_info "Skipping app bundle signing (SKIP_SIGNING=true)"
        return
    fi
    
    log_info "Signing application bundle..."
    
    APP_PATH="build/export/$APP_NAME.app"
    
    # Get signing identity
    local signing_identity
    if signing_identity=$(get_signing_identity); then
        log_info "Using code signing certificate: $signing_identity"
        
        # Sign the app bundle with hardened runtime
        log_info "Signing application with hardened runtime..."
        codesign \
            --deep \
            --force \
            --options runtime \
            --timestamp \
            --sign "$signing_identity" \
            "$APP_PATH"
        
        # Verify the signature
        log_info "Verifying app signature..."
        codesign --verify --verbose "$APP_PATH"
        
        log_success "Application bundle signed and verified"
    else
        log_error "No Developer ID Application certificate found, but signing is required"
        log_error "Either provide a valid certificate or use --skip-signing / SKIP_SIGNING=true"
        exit 1
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

# Validate the final build
validate_build() {
    log_info "Performing final build validation..."
    
    local dmg_name
    dmg_name=$(cat dmg_name.txt 2>/dev/null || echo "$APP_NAME-$VERSION-Universal.dmg")
    
    # Check if DMG exists
    if [ ! -f "$dmg_name" ]; then
        log_error "DMG file not found: $dmg_name"
        return 1
    fi
    
    # Check DMG size (should be reasonable)
    local size_bytes
    size_bytes=$(stat -f%z "$dmg_name" 2>/dev/null || echo "0")
    if [ "$size_bytes" -lt 1000000 ]; then  # Less than 1MB is suspicious
        log_warning "DMG file seems unusually small: $(du -h "$dmg_name" | cut -f1)"
    fi
    
    # Validate signatures if not skipping
    if [ "$SKIP_SIGNING" != "true" ]; then
        # Check app bundle signature
        local app_path="build/export/$APP_NAME.app"
        if [ -d "$app_path" ]; then
            if codesign --verify --deep --strict "$app_path" 2>/dev/null; then
                log_success "App bundle signature is valid"
            else
                log_error "App bundle signature validation failed"
                return 1
            fi
        fi
        
        # Check DMG signature
        if codesign --verify --verbose "$dmg_name" 2>/dev/null; then
            log_success "DMG signature is valid"
        else
            log_warning "DMG signature validation failed"
        fi
    fi
    
    log_success "Build validation completed"
    return 0
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
    
    if [ -n "${KEYCHAIN_PATH:-}" ] && [ -f "$KEYCHAIN_PATH" ]; then
        security delete-keychain "$KEYCHAIN_PATH"
    fi
    
    # Clean up certificate file
    [ -f certificate.p12 ] && rm -f certificate.p12
    
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
                    echo "Creates a signed, notarized DMG for distribution."
                    echo ""
                    echo "Usage: $0 [OPTIONS]"
                    echo ""
                    echo "Options:"
                    echo "  --skip-signing       Skip code signing (for development only)"
                    echo "  --clean             Clean build directory and exit"
                    echo "  --help, -h          Show this help message"
                    echo ""
                    echo "Environment variables:"
                    echo "  SKIP_SIGNING=true   Skip code signing"
                    echo "  CI=true            Run in CI mode (automatic)"
                    echo ""
                    echo "Dependencies:"
                    echo "  - Xcode (required)"
                    echo "  - Node.js (required for sindresorhus/create-dmg)"
                    echo "  - Developer ID certificate (for signing)"
                    echo ""
                    echo "Build process:"
                    echo "  1. Build universal app bundle"
                    echo "  2. Sign app bundle (if certificates available)"
                    echo "  3. Create and sign DMG"
                    echo "  4. Notarize DMG (CI only)"
                    echo "  5. Generate checksums"
                    echo ""
                    echo "For setup instructions, see DISTRIBUTION_SETUP.md"
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
    sign_app_bundle  # Sign app BEFORE creating DMG
    create_dmg
    notarize_dmg    # CI only
    validate_build
    generate_checksums
    
    # Cleanup
    cleanup_keychain  # CI only
    
    if [ "$CI_MODE" != "true" ]; then
        echo ""
        log_success "Build completed successfully!"
        echo ""
        echo "📦 Your DMG is ready: $APP_NAME-$VERSION-Universal.dmg"
        echo ""
        
        # Show what was accomplished
        if [ "$SKIP_SIGNING" = "true" ]; then
            echo "⚠️  Note: App bundle and DMG are UNSIGNED (development build)"
            echo "   This build is suitable for testing only."
        else
            echo "✅ App bundle is signed and ready for distribution"
            echo "✅ DMG is signed and ready for distribution"
        fi
        
        echo ""
        echo "Testing instructions:"
        echo "1. Double-click to mount the DMG"
        echo "2. Drag the app to Applications folder"
        echo "3. Launch the app from Applications"
        echo ""
        
        if [ "$SKIP_SIGNING" != "true" ]; then
            echo "Distribution checklist:"
            echo "✅ App bundle signed with Developer ID"
            echo "✅ DMG signed with Developer ID"
            if [ "$CI_MODE" = "true" ]; then
                echo "✅ DMG notarized by Apple"
            else
                echo "⚠️  DMG not notarized (use CI/CD for notarization)"
            fi
            echo ""
        fi
        
        echo "For distribution setup, see DISTRIBUTION_SETUP.md"
    else
        log_success "CI build completed successfully!"
        DMG_NAME=$(cat dmg_name.txt 2>/dev/null || echo "$APP_NAME-$VERSION-Universal.dmg")
        echo "DMG_NAME=$DMG_NAME" >> "$GITHUB_ENV"
    fi
    
    rm -f dmg_name.txt
}

# Run main function
main "$@" 