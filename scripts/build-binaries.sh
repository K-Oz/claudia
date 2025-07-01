#!/bin/bash

# Build Claudia for multiple platforms
# Usage: ./scripts/build-binaries.sh [platform]
# Platforms: linux, windows, macos, macos-arm, all

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if required tools are available
check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v cargo &> /dev/null; then
        log_error "Rust/Cargo is not installed. Please install Rust: https://rustup.rs/"
        exit 1
    fi
    
    if ! command -v bun &> /dev/null; then
        log_error "Bun is not installed. Please install Bun: https://bun.sh/"
        exit 1
    fi
    
    log_success "All dependencies are available"
}

# Install Rust target
install_target() {
    local target=$1
    log_info "Installing Rust target: $target"
    if ! rustup target list --installed | grep -q "$target"; then
        rustup target add "$target"
    else
        log_info "Target $target is already installed"
    fi
}

# Validate icon files to prevent RC2175 errors
validate_icons() {
    log_info "Validating icon files to prevent build errors..."
    if [ -f "scripts/validate-build-icons.sh" ]; then
        ./scripts/validate-build-icons.sh
    else
        log_warning "Icon validation script not found, skipping validation"
    fi
}

# Build frontend
build_frontend() {
    log_info "Building frontend..."
    bun install --frozen-lockfile
    bun run build
    log_success "Frontend built successfully"
}

# Build binary for a specific target
build_binary() {
    local target=$1
    local platform_name=$2
    local binary_suffix=$3
    
    log_info "Building binary for $platform_name ($target)..."
    
    # Install target if needed
    install_target "$target"
    
    # Build the binary
    cd src-tauri
    cargo build --release --target "$target"
    cd ..
    
    # Create output directory
    mkdir -p "dist/binaries"
    
    # Copy binary to dist directory
    local binary_name="claudia$binary_suffix"
    local output_name="claudia-$platform_name$binary_suffix"
    
    if [ -f "src-tauri/target/$target/release/$binary_name" ]; then
        cp "src-tauri/target/$target/release/$binary_name" "dist/binaries/$output_name"
        log_success "Binary built: dist/binaries/$output_name"
        
        # Show file info
        file "dist/binaries/$output_name" || true
        ls -lh "dist/binaries/$output_name"
    else
        log_error "Binary not found: src-tauri/target/$target/release/$binary_name"
        return 1
    fi
}

# Build bundles using Tauri
build_bundle() {
    local target=$1
    local platform_name=$2
    local bundles=$3
    
    log_info "Building bundles for $platform_name ($bundles)..."
    
    # Install target if needed
    install_target "$target"
    
    # Build with bundles
    bun run tauri build --bundles "$bundles" --target "$target"
    
    # List generated bundles
    if [ -d "src-tauri/target/$target/release/bundle" ]; then
        log_success "Bundles created in src-tauri/target/$target/release/bundle/"
        find "src-tauri/target/$target/release/bundle" -type f \( -name "*.deb" -o -name "*.dmg" -o -name "*.msi" -o -name "*.exe" -o -name "*.AppImage" \) -exec ls -lh {} \;
    fi
}

# Create release archive
create_archive() {
    local platform_name=$1
    local binary_suffix=$2
    
    log_info "Creating release archive for $platform_name..."
    
    local archive_dir="dist/releases/$platform_name"
    mkdir -p "$archive_dir"
    
    # Copy binary
    cp "dist/binaries/claudia-$platform_name$binary_suffix" "$archive_dir/claudia$binary_suffix"
    
    # Copy additional files
    cp README.md "$archive_dir/"
    cp LICENSE "$archive_dir/"
    
    # Create version info
    {
        echo "Claudia $(git describe --tags --always --dirty)"
        echo "Built on: $(date)"
        echo "Platform: $platform_name"
        echo "Commit: $(git rev-parse HEAD)"
    } > "$archive_dir/VERSION"
    
    # Create archive
    cd "dist/releases"
    if [[ "$platform_name" == *"windows"* ]]; then
        if command -v zip &> /dev/null; then
            zip -r "claudia-$platform_name.zip" "$platform_name/"
            log_success "Archive created: dist/releases/claudia-$platform_name.zip"
        else
            log_warning "zip command not found, skipping archive creation"
        fi
    else
        tar -czf "claudia-$platform_name.tar.gz" "$platform_name/"
        log_success "Archive created: dist/releases/claudia-$platform_name.tar.gz"
    fi
    cd "../.."
}

# Build for Linux
build_linux() {
    log_info "Building for Linux x86_64..."
    build_binary "x86_64-unknown-linux-gnu" "linux-x86_64" ""
    create_archive "linux-x86_64" ""
}

# Build for Windows
build_windows() {
    log_info "Building for Windows x86_64..."
    build_binary "x86_64-pc-windows-msvc" "windows-x86_64" ".exe"
    create_archive "windows-x86_64" ".exe"
}

# Build for macOS Intel
build_macos() {
    log_info "Building for macOS x86_64..."
    build_binary "x86_64-apple-darwin" "macos-x86_64" ""
    create_archive "macos-x86_64" ""
}

# Build for macOS ARM
build_macos_arm() {
    log_info "Building for macOS ARM64..."
    build_binary "aarch64-apple-darwin" "macos-arm64" ""
    create_archive "macos-arm64" ""
}

# Build universal macOS binary
build_macos_universal() {
    log_info "Building universal macOS binary..."
    
    # Build both architectures first
    build_binary "x86_64-apple-darwin" "macos-x86_64" ""
    build_binary "aarch64-apple-darwin" "macos-arm64" ""
    
    # Create universal binary using lipo
    if command -v lipo &> /dev/null; then
        log_info "Creating universal binary..."
        lipo -create \
            "dist/binaries/claudia-macos-x86_64" \
            "dist/binaries/claudia-macos-arm64" \
            -output "dist/binaries/claudia-macos-universal"
        
        log_success "Universal binary created: dist/binaries/claudia-macos-universal"
        lipo -info "dist/binaries/claudia-macos-universal"
        
        create_archive "macos-universal" ""
    else
        log_warning "lipo command not found, skipping universal binary creation"
    fi
}

# Clean previous builds
clean() {
    log_info "Cleaning previous builds..."
    rm -rf dist/binaries dist/releases
    rm -rf src-tauri/target/*/release/bundle
    log_success "Clean completed"
}

# Show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  linux           Build for Linux x86_64"
    echo "  windows         Build for Windows x86_64"
    echo "  macos           Build for macOS x86_64"
    echo "  macos-arm       Build for macOS ARM64"
    echo "  macos-universal Build universal macOS binary (Intel + ARM)"
    echo "  all             Build for all platforms"
    echo "  bundles         Build with installer bundles"
    echo "  clean           Clean previous builds"
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 linux                   # Build Linux binary"
    echo "  $0 all                     # Build all platform binaries"
    echo "  $0 bundles                 # Build with installer bundles"
    echo "  $0 clean && $0 all         # Clean and build all"
}

# Main function
main() {
    local command=${1:-""}
    
    case "$command" in
        "linux")
            check_dependencies
            validate_icons
            build_frontend
            build_linux
            ;;
        "windows")
            check_dependencies
            validate_icons
            build_frontend
            build_windows
            ;;
        "macos")
            check_dependencies
            validate_icons
            build_frontend
            build_macos
            ;;
        "macos-arm")
            check_dependencies
            validate_icons
            build_frontend
            build_macos_arm
            ;;
        "macos-universal")
            check_dependencies
            validate_icons
            build_frontend
            build_macos_universal
            ;;
        "all")
            check_dependencies
            validate_icons
            build_frontend
            log_info "Building for all platforms..."
            
            # Build for current platform's available targets
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                build_linux
                build_windows  # Cross-compile to Windows if possible
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                build_macos
                build_macos_arm
                build_macos_universal
            elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
                build_windows
            else
                log_warning "Unknown platform, attempting Linux build..."
                build_linux
            fi
            
            log_success "All builds completed!"
            echo ""
            echo "📦 Generated binaries:"
            find dist/binaries -type f -exec ls -lh {} \; 2>/dev/null || true
            echo ""
            echo "📋 Generated archives:"
            find dist/releases -type f \( -name "*.tar.gz" -o -name "*.zip" \) -exec ls -lh {} \; 2>/dev/null || true
            ;;
        "bundles")
            check_dependencies
            validate_icons
            build_frontend
            log_info "Building bundles for current platform..."
            
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                build_bundle "x86_64-unknown-linux-gnu" "linux" "deb,appimage"
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                build_bundle "x86_64-apple-darwin" "macos" "dmg"
            elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
                build_bundle "x86_64-pc-windows-msvc" "windows" "msi"
            else
                log_error "Unsupported platform for bundling: $OSTYPE"
                exit 1
            fi
            ;;
        "clean")
            clean
            ;;
        "--help"|"-h"|"help"|"")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"