#!/bin/bash

# VS Code with Wingman AI - Portable Build Script
# This script builds portable VS Code distributions with Wingman AI integrated as a native feature

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build-wingman"
DIST_DIR="$SCRIPT_DIR/dist"
DATE=$(date +%Y%m%d_%H%M%S)

# Product information
PRODUCT_NAME="VSCode-Wingman"
PRODUCT_VERSION="1.95.0-wingman"
ELECTRON_VERSION=$(grep 'target=' .npmrc | cut -d'"' -f2)

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    log_info "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Node.js version
    if ! command -v node &> /dev/null; then
        log_error "Node.js is required but not installed"
        exit 1
    fi

    NODE_VERSION=$(node --version | cut -d'v' -f2)
    log_info "Using Node.js version: $NODE_VERSION"

    # Check npm
    if ! command -v npm &> /dev/null; then
        log_error "npm is required but not installed"
        exit 1
    fi

    # Check if we're on macOS for signing (optional)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "macOS detected - checking for codesigning tools..."
        if ! command -v codesign &> /dev/null; then
            log_warning "codesign not found - builds will not be signed"
        fi
    fi
}

setup_build_environment() {
    log_info "Setting up build environment..."

    # Create build directories
    mkdir -p "$BUILD_DIR"
    mkdir -p "$DIST_DIR"

    # Install dependencies
    log_info "Installing VS Code dependencies..."
    npm install

    # Install extension dependencies
    log_info "Installing Wingman AI extension dependencies..."
    cd extensions/wingman-ai

    # Clean and reinstall to fix any corrupted dependencies
    log_info "Cleaning Wingman AI extension dependencies..."
    rm -rf node_modules
    rm -f package-lock.json

    # Install dependencies fresh
    log_info "Installing fresh dependencies..."
    npm install

    # Compile the extension
    log_info "Compiling Wingman AI extension..."
    npm run compile
    cd "$SCRIPT_DIR"
}

build_extensions() {
    log_info "Building VS Code extensions..."
    npm run gulp -- compile-extensions

    log_info "Building Wingman AI extension..."
    cd extensions/wingman-ai
    npm run vscode:prepublish
    cd "$SCRIPT_DIR"
}

build_vscode() {
    log_info "Building VS Code core..."

    # Set environment for production build
    export NODE_ENV=production
    export VSCODE_QUALITY=stable

    # Compile TypeScript
    npm run gulp -- transpile-client
    npm run gulp -- compile

    log_success "VS Code compilation completed"
}

package_for_platform() {
    local platform=$1
    local arch=$2

    log_info "Packaging for $platform-$arch..."

    local package_name="${PRODUCT_NAME}-${platform}-${arch}-${DATE}"
    local output_dir="$DIST_DIR/$package_name"

    # Create package directory
    mkdir -p "$output_dir"

    case $platform in
        "win32")
            package_windows "$arch" "$output_dir" "$package_name"
            ;;
        "darwin")
            package_macos "$arch" "$output_dir" "$package_name"
            ;;
        "linux")
            package_linux "$arch" "$output_dir" "$package_name"
            ;;
        *)
            log_error "Unknown platform: $platform"
            return 1
            ;;
    esac
}

package_windows() {
    local arch=$1
    local output_dir=$2
    local package_name=$3

    log_info "Creating Windows portable executable..."

    # Build Windows package
    npm run gulp -- "vscode-win32-${arch}-min"

    # Copy to output directory
    cp -r "../VSCode-win32-${arch}/"* "$output_dir/"

    # Create portable launcher
    cat > "$output_dir/portable.bat" << 'EOF'
@echo off
set VSCODE_PORTABLE=%~dp0data
if not exist "%VSCODE_PORTABLE%" mkdir "%VSCODE_PORTABLE%"
start "" "%~dp0Code.exe" %*
EOF

    # Create data directory for portable mode
    mkdir -p "$output_dir/data"

    # Create self-extracting archive
    if command -v 7z &> /dev/null; then
        log_info "Creating self-extracting archive..."
        cd "$DIST_DIR"
        7z a -sfx7z.sfx "${package_name}.exe" "$package_name/"
        cd "$SCRIPT_DIR"
    fi

    log_success "Windows package created: $output_dir"
}

package_macos() {
    local arch=$1
    local output_dir=$2
    local package_name=$3

    log_info "Creating macOS application bundle..."

    # Build macOS package
    npm run gulp -- "vscode-darwin-${arch}-min"

    local app_name="VSCode-Wingman.app"
    local source_app="../VSCode-darwin-${arch}/Code - OSS.app"
    local target_app="$output_dir/$app_name"

    # Copy and rename app bundle
    cp -r "$source_app" "$target_app"

    # Update Info.plist
    if [[ "$OSTYPE" == "darwin"* ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleName VSCode-Wingman" "$target_app/Contents/Info.plist"
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName VSCode-Wingman" "$target_app/Contents/Info.plist"
        /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.wingman.vscode" "$target_app/Contents/Info.plist"
    fi

    # Sign the application (if on macOS and certificates available)
    if [[ "$OSTYPE" == "darwin"* ]] && command -v codesign &> /dev/null; then
        log_info "Attempting to sign macOS application..."
        # Remove any existing signatures first
        codesign --remove-signature "$target_app" 2>/dev/null || true

        # Sign with ad-hoc signature for local development
        if codesign --force --deep --sign - --options runtime "$target_app" 2>/dev/null; then
            log_success "Application signed successfully"
        else
            log_warning "Code signing failed - app may still work for local testing"
        fi
    fi

    # Create DMG
    if [[ "$OSTYPE" == "darwin"* ]] && command -v hdiutil &> /dev/null; then
        log_info "Creating DMG installer..."
        local dmg_name="${package_name}.dmg"
        local temp_dmg="$BUILD_DIR/temp.dmg"

        # Create temporary DMG with proper size
        hdiutil create -megabytes 800 -format UDRW -volname "VSCode-Wingman" "$temp_dmg"

        # Mount and copy files
        local mount_point="/Volumes/VSCode-Wingman"
        hdiutil attach "$temp_dmg"
        cp -r "$target_app" "$mount_point/"

        # Create Applications symlink
        ln -s /Applications "$mount_point/Applications"

        # Unmount and convert to final DMG
        hdiutil detach "$mount_point"
        hdiutil convert "$temp_dmg" -format UDZO -o "$DIST_DIR/$dmg_name"

        rm "$temp_dmg"
        log_success "DMG created: $DIST_DIR/$dmg_name"
    fi

    log_success "macOS package created: $output_dir"
}

package_linux() {
    local arch=$1
    local output_dir=$2
    local package_name=$3

    log_info "Creating Linux portable package..."

    # Build Linux package
    npm run gulp -- "vscode-linux-${arch}-min"

    # Copy to output directory
    cp -r "../VSCode-linux-${arch}/"* "$output_dir/"

    # Create portable launcher script
    cat > "$output_dir/vscode-wingman" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VSCODE_PORTABLE="$SCRIPT_DIR/data"
mkdir -p "$VSCODE_PORTABLE"
exec "$SCRIPT_DIR/code" "$@"
EOF

    chmod +x "$output_dir/vscode-wingman"

    # Create data directory for portable mode
    mkdir -p "$output_dir/data"

    # Create tarball
    cd "$DIST_DIR"
    tar -czf "${package_name}.tar.gz" "$package_name/"
    cd "$SCRIPT_DIR"

    log_success "Linux package created: $output_dir"
}

generate_documentation() {
    log_info "Generating documentation..."

    cat > "$DIST_DIR/README.md" << EOF
# VSCode with Wingman AI - Portable Edition

This is a portable distribution of Visual Studio Code with Wingman AI integrated as a native feature.

## What's Included

- **Visual Studio Code**: The popular open-source code editor
- **Wingman AI**: Integrated AI coding assistant with support for:
  - Anthropic Claude
  - OpenAI GPT models
  - Azure OpenAI
  - Ollama (local models)

## Features

- **Seamless Integration**: Wingman AI loads automatically and appears as a native VS Code feature
- **Hidden from Extensions**: Wingman AI doesn't appear in the Extensions marketplace or panel
- **Portable**: All settings and data stored locally, no installation required
- **Full Functionality**: All standard VS Code features remain unchanged

## Platform-Specific Instructions

### Windows
1. Extract the archive or run the self-extracting executable
2. Run \`portable.bat\` or \`Code.exe\` directly
3. Settings and extensions will be stored in the \`data\` folder

### macOS
1. Open the DMG file and drag VSCode-Wingman.app to Applications (or anywhere)
2. Launch the application
3. If you see a security warning, go to System Preferences > Security & Privacy and allow the app

### Linux
1. Extract the tar.gz archive
2. Run \`./vscode-wingman\` or \`./code\` directly
3. Settings and extensions will be stored in the \`data\` folder

## Using Wingman AI

Wingman AI is automatically available in the sidebar and through the following shortcuts:
- \`Ctrl+Shift+Space\` (Windows/Linux) or \`Cmd+Shift+Space\` (macOS): Code completion
- \`Ctrl+I\` (Windows/Linux) or \`Cmd+I\` (macOS): Open composer

## Upgrading

To upgrade this distribution:
1. Backup your \`data\` folder (contains all settings and extensions)
2. Download the new version
3. Extract to a new folder
4. Copy your \`data\` folder to the new installation
5. Delete the old version

## Build Information

- Build Date: $(date)
- VS Code Version: $PRODUCT_VERSION
- Electron Version: $ELECTRON_VERSION
- Wingman AI Version: $(cd extensions/wingman-ai && node -p "require('./package.json').version")

## Troubleshooting

If you encounter issues:
1. Delete the \`data\` folder to reset to defaults
2. Check the developer console (Help > Toggle Developer Tools)
3. Refer to the VS Code documentation for general issues

## License

This distribution combines:
- VS Code: MIT License (Microsoft)
- Wingman AI: MIT License (Russell Canfield)

See individual license files for details.
EOF

    cat > "$DIST_DIR/UPGRADE_GUIDE.md" << EOF
# Upgrade Guide

This guide explains how to maintain and upgrade your VSCode-Wingman distribution.

## Tracking Upstream Changes

### VS Code Updates

1. **Monitor VS Code releases**: https://github.com/microsoft/vscode/releases
2. **Update base code**:
   \`\`\`bash
   git remote add upstream https://github.com/microsoft/vscode.git
   git fetch upstream
   git checkout main
   git merge upstream/main
   \`\`\`

3. **Resolve conflicts**: Pay special attention to:
   - \`src/vs/platform/extensionManagement/common/extensionsScannerService.ts\`
   - \`src/vs/workbench/contrib/extensions/browser/extensionsViews.ts\`
   - \`extensions/wingman-ai/package.json\`

### Wingman AI Updates

1. **Monitor Wingman AI releases**: https://github.com/RussellCanfield/wingman-ai/releases
2. **Update extension**:
   \`\`\`bash
   cd extensions/wingman-ai
   git remote add upstream https://github.com/RussellCanfield/wingman-ai.git
   git fetch upstream
   git merge upstream/main
   \`\`\`

3. **Restore integration changes**:
   - Ensure \`"publisher": "vscode-builtin"\` in package.json
   - Ensure \`"builtin": true\` in package.json
   - Rebuild: \`npm run vscode:prepublish\`

## Build Process

1. **Update dependencies**:
   \`\`\`bash
   npm install
   cd extensions/wingman-ai && npm install && cd ../..
   \`\`\`

2. **Run build script**:
   \`\`\`bash
   ./build-wingman-vscode.sh
   \`\`\`

3. **Test integration**:
   - Verify Wingman AI loads automatically
   - Confirm it's hidden from Extensions panel
   - Test all standard VS Code functionality

## Key Integration Points

### Extension Scanner
- **File**: \`src/vs/platform/extensionManagement/common/extensionsScannerService.ts\`
- **Change**: Added check for \`(manifest as any).builtin\` in isBuiltin determination

### Extensions View
- **File**: \`src/vs/workbench/contrib/extensions/browser/extensionsViews.ts\`
- **Changes**:
  - Hide Wingman AI from installed extensions filter
  - Hide from builtin extensions unless specifically searched

### Extension Package
- **File**: \`extensions/wingman-ai/package.json\`
- **Changes**:
  - Publisher changed to \`vscode-builtin\`
  - Added \`"builtin": true\` flag

## Testing Checklist

- [ ] VS Code launches successfully
- [ ] Wingman AI is available in sidebar
- [ ] Wingman AI shortcuts work (Ctrl+I, Ctrl+Shift+Space)
- [ ] Wingman AI is NOT visible in Extensions panel
- [ ] Wingman AI is NOT visible in @builtin search (unless searched by name)
- [ ] All standard VS Code features work
- [ ] Extension can connect to AI providers
- [ ] Settings are properly saved

## Automation

Consider setting up CI/CD to:
1. Monitor upstream repositories for changes
2. Automatically test integration points
3. Build and test releases
4. Create release packages

## Notes

- Always test on all target platforms (Windows, macOS, Linux)
- Keep integration changes minimal to ease future merges
- Document any new integration points added
- Maintain backward compatibility when possible
EOF

    log_success "Documentation generated in $DIST_DIR"
}

show_help() {
    cat << EOF
VSCode with Wingman AI - Build Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -c, --clean         Clean build directory before building
    -p, --platform      Target platform (win32|darwin|linux|all) [default: current]
    -a, --arch          Target architecture (x64|arm64|all) [default: current]
    --skip-deps         Skip dependency installation
    --skip-compile      Skip compilation step
    --docs-only         Generate documentation only

Examples:
    $0                          # Build for current platform and architecture
    $0 -p all -a all           # Build for all platforms and architectures
    $0 -p win32 -a x64         # Build Windows x64 only
    $0 --clean                 # Clean and build
    $0 --docs-only             # Generate documentation only

EOF
}

main() {
    local platform=""
    local arch=""
    local clean=false
    local skip_deps=false
    local skip_compile=false
    local docs_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                clean=true
                shift
                ;;
            -p|--platform)
                platform="$2"
                shift 2
                ;;
            -a|--arch)
                arch="$2"
                shift 2
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --skip-compile)
                skip_compile=true
                shift
                ;;
            --docs-only)
                docs_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Set defaults
    if [[ -z "$platform" ]]; then
        case "$OSTYPE" in
            darwin*) platform="darwin" ;;
            linux*) platform="linux" ;;
            msys*|cygwin*|win32*) platform="win32" ;;
            *) platform="linux" ;;
        esac
    fi

    if [[ -z "$arch" ]]; then
        arch=$(uname -m)
        case "$arch" in
            x86_64) arch="x64" ;;
            aarch64|arm64) arch="arm64" ;;
            *) arch="x64" ;;
        esac
    fi

    log_info "Starting VSCode-Wingman build process..."
    log_info "Target platform: $platform"
    log_info "Target architecture: $arch"

    # Clean if requested
    if [[ "$clean" == true ]]; then
        cleanup
    fi

    # Generate docs only if requested
    if [[ "$docs_only" == true ]]; then
        generate_documentation
        exit 0
    fi

    # Build process
    check_prerequisites

    if [[ "$skip_deps" != true ]]; then
        setup_build_environment
    fi

    if [[ "$skip_compile" != true ]]; then
        build_extensions
        build_vscode
    fi

    # Package for requested platforms
    if [[ "$platform" == "all" ]]; then
        platforms=("win32" "darwin" "linux")
    else
        platforms=("$platform")
    fi

    if [[ "$arch" == "all" ]]; then
        architectures=("x64" "arm64")
    else
        architectures=("$arch")
    fi

    for p in "${platforms[@]}"; do
        for a in "${architectures[@]}"; do
            # Skip invalid combinations
            if [[ "$p" == "win32" && "$a" == "arm64" ]]; then
                log_warning "Skipping win32-arm64 (not commonly supported)"
                continue
            fi

            package_for_platform "$p" "$a"
        done
    done

    generate_documentation

    log_success "Build completed successfully!"
    log_info "Output directory: $DIST_DIR"
    log_info "Available packages:"
    ls -la "$DIST_DIR"
}

# Trap cleanup function
trap cleanup EXIT

# Run main function
main "$@"
