# Build Scripts

This directory contains scripts for building Claudia binaries across different platforms.

## Scripts

### `build-binaries.sh` (Linux/macOS)
Cross-platform binary generation script for Unix-like systems.

**Usage:**
```bash
./scripts/build-binaries.sh [command]
```

**Commands:**
- `linux` - Build for Linux x86_64
- `windows` - Build for Windows x86_64 (cross-compilation)
- `macos` - Build for macOS x86_64
- `macos-arm` - Build for macOS ARM64
- `macos-universal` - Build universal macOS binary (Intel + ARM)
- `all` - Build for all available platforms
- `bundles` - Build with installer packages for current platform
- `clean` - Clean previous builds

### `build-binaries.ps1` (Windows)
Cross-platform binary generation script for Windows PowerShell.

**Usage:**
```powershell
.\scripts\build-binaries.ps1 [command]
```

**Commands:**
- `windows` - Build for Windows x86_64
- `linux` - Build for Linux x86_64 (cross-compilation)
- `macos` - Build for macOS x86_64 (cross-compilation)
- `all` - Build for all available platforms
- `bundles` - Build with installer packages
- `clean` - Clean previous builds

## Output

### Binary Directory
Built binaries are placed in `dist/binaries/`:
- `claudia-linux-x86_64`
- `claudia-windows-x86_64.exe`
- `claudia-macos-x86_64`
- `claudia-macos-arm64`

### Release Archives
Release-ready archives are created in `dist/releases/`:
- `claudia-linux-x86_64.tar.gz`
- `claudia-windows-x86_64.zip`
- `claudia-macos-x86_64.tar.gz`
- `claudia-macos-arm64.tar.gz`

Each archive contains:
- The executable binary
- README.md
- LICENSE
- VERSION file with build information

## Requirements

### All Platforms
- Rust (1.70.0 or later)
- Bun (latest version)
- Git

### Linux
- System dependencies (see main README.md)
- GCC build tools

### macOS
- Xcode Command Line Tools
- Optional: Homebrew for additional dependencies

### Windows
- Microsoft C++ Build Tools
- WebView2 (usually pre-installed on Windows 11)

## Cross-Compilation

Cross-compilation support varies by host platform:

- **Linux**: Can build for Linux and potentially Windows (with additional setup)
- **macOS**: Can build for macOS (both Intel and ARM), Linux, and potentially Windows
- **Windows**: Can build for Windows and potentially Linux/macOS (with additional setup)

## Examples

```bash
# Build for current platform
./scripts/build-binaries.sh

# Build Linux binary specifically
./scripts/build-binaries.sh linux

# Build all available platforms
./scripts/build-binaries.sh all

# Build with installer packages
./scripts/build-binaries.sh bundles

# Clean and rebuild everything
./scripts/build-binaries.sh clean && ./scripts/build-binaries.sh all
```

## Integration with npm/bun

These scripts are integrated with the package.json scripts:

```bash
bun run build:binary           # Current platform
bun run build:binary:linux     # Linux binary
bun run build:binary:windows   # Windows binary
bun run build:binary:macos     # macOS binary
bun run build:binary:all       # All platforms
bun run build:bundles          # Installer packages
bun run build:clean            # Clean builds
```

## Automated Builds

The GitHub Actions workflow (`.github/workflows/release.yml`) automatically runs these builds for all platforms when:
- A new tag is pushed
- A release is created
- The workflow is manually triggered

This ensures consistent, automated binary generation for releases.