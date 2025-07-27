#!/bin/bash

# VTS DMG Build Script
# Creates a polished DMG with the same configuration as CI/CD

set -e

# Configuration
APP_NAME="VTSApp"
BUNDLE_ID="com.voicetypestudio.app"
SCHEME="VTSApp"
PROJECT="VTSApp.xcodeproj"
APPLE_TEAM_ID="887583966J"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi
    
    if ! command -v create-dmg &> /dev/null; then
        log_warning "create-dmg not found. Installing via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install create-dmg
        else
            log_error "Homebrew not found. Please install create-dmg manually."
            exit 1
        fi
    fi
    
    log_success "Dependencies verified"
}

# Get version from Info.plist
get_version() {
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" VTSApp/Info.plist)
    BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" VTSApp/Info.plist)
    
    if [ -z "$VERSION" ]; then
        log_error "Could not read version from Info.plist"
        exit 1
    fi
    
    log_info "Building version $VERSION (build $BUILD_NUMBER)"
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
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "build/$APP_NAME.xcarchive" \
        -arch arm64 -arch x86_64 \
        DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
        archive
    
    log_success "Archive created successfully"
    
    # Export app
    log_info "Exporting application..."
    xcodebuild \
        -exportArchive \
        -archivePath "build/$APP_NAME.xcarchive" \
        -exportOptionsPlist scripts/ExportOptions.plist \
        -exportPath build/export \
        DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
    
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

# Create DMG
create_dmg() {
    log_info "Creating DMG..."
    
    APP_PATH="build/export/$APP_NAME.app"
    DMG_NAME="$APP_NAME-$VERSION-Universal.dmg"
    
    # Remove old DMG if exists
    [ -f "$DMG_NAME" ] && rm "$DMG_NAME"
    
    # Check if app icon exists for volume icon
    VOLUME_ICON=""
    if [ -f "VTSApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" ]; then
        VOLUME_ICON="--volicon VTSApp/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"
    fi
    
    # Create DMG with proper layout
    create-dmg \
        --volname "$APP_NAME $VERSION" \
        $VOLUME_ICON \
        --window-pos 200 120 \
        --window-size 800 450 \
        --icon-size 128 \
        --icon "$APP_NAME.app" 200 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 600 190 \
        --background scripts/dmg-background.png \
        --disk-image-size 200 \
        --format UDZO \
        "$DMG_NAME" \
        "$APP_PATH" || {
            # Fallback without background if it doesn't exist
            log_warning "Creating DMG without custom background..."
            create-dmg \
                --volname "$APP_NAME $VERSION" \
                $VOLUME_ICON \
                --window-pos 200 120 \
                --window-size 800 450 \
                --icon-size 128 \
                --icon "$APP_NAME.app" 200 190 \
                --hide-extension "$APP_NAME.app" \
                --app-drop-link 600 190 \
                --disk-image-size 200 \
                --format UDZO \
                "$DMG_NAME" \
                "$APP_PATH"
        }
    
    if [ -f "$DMG_NAME" ]; then
        log_success "DMG created: $DMG_NAME"
        
        # Show file size
        SIZE=$(du -h "$DMG_NAME" | cut -f1)
        log_info "DMG size: $SIZE"
        
        # Generate checksum
        log_info "Generating SHA-256 checksum..."
        CHECKSUM=$(shasum -a 256 "$DMG_NAME" | cut -d' ' -f1)
        echo "$CHECKSUM  $DMG_NAME" > "$DMG_NAME.sha256"
        log_success "Checksum saved to $DMG_NAME.sha256"
        echo "SHA-256: $CHECKSUM"
    else
        log_error "DMG creation failed"
        exit 1
    fi
}

# Code signing function (optional)
code_sign() {
    if [ "$SKIP_SIGNING" = "true" ]; then
        log_info "Skipping code signing (SKIP_SIGNING=true)"
        return
    fi
    
    log_info "Checking for code signing certificate..."
    
    # Check if Developer ID certificate is available
    if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        log_info "Code signing certificate found. Signing application..."
        
        APP_PATH="build/export/$APP_NAME.app"
        DMG_NAME="$APP_NAME-$VERSION-Universal.dmg"
        
        # Sign the app
        codesign \
            --deep \
            --force \
            --options runtime \
            --timestamp \
            --sign "Developer ID Application" \
            "$APP_PATH"
        
        log_success "Application signed"
        
        # Sign the DMG
        codesign \
            --sign "Developer ID Application" \
            --timestamp \
            "$DMG_NAME"
        
        log_success "DMG signed"
        
        # Verify signatures
        codesign --verify --verbose "$APP_PATH"
        codesign --verify --verbose "$DMG_NAME"
        
        log_success "Code signing completed and verified"
    else
        log_warning "No Developer ID Application certificate found"
        log_info "DMG will be created without code signing"
        log_info "To skip this check, run with: SKIP_SIGNING=true ./scripts/build-dmg.sh"
    fi
}

# Main execution
main() {
    echo "🚀 VTS DMG Build Script"
    echo "========================"
    
    # Parse command line arguments
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
    
    check_dependencies
    get_version
    clean_build
    build_app
    create_dmg
    code_sign
    
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
    echo "See SETUP.md for details on configuring certificates."
}

# Run main function
main "$@" 