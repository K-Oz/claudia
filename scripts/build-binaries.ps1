# Build Claudia for multiple platforms
# Usage: .\scripts\build-binaries.ps1 [platform]
# Platforms: linux, windows, macos, macos-arm, all

param(
    [Parameter(Position = 0)]
    [string]$Command = ""
)

# Colors for output
$ColorInfo = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"

# Logging functions
function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $ColorInfo
}

function Log-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $ColorSuccess
}

function Log-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $ColorWarning
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $ColorError
}

# Check if required tools are available
function Check-Dependencies {
    Log-Info "Checking dependencies..."
    
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        Log-Error "Rust/Cargo is not installed. Please install Rust: https://rustup.rs/"
        exit 1
    }
    
    if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
        Log-Error "Bun is not installed. Please install Bun: https://bun.sh/"
        exit 1
    }
    
    Log-Success "All dependencies are available"
}

# Install Rust target
function Install-Target {
    param([string]$Target)
    Log-Info "Installing Rust target: $Target"
    $installedTargets = rustup target list --installed
    if ($installedTargets -notcontains $Target) {
        rustup target add $Target
    } else {
        Log-Info "Target $Target is already installed"
    }
}

# Build frontend
function Build-Frontend {
    Log-Info "Building frontend..."
    bun install --frozen-lockfile
    bun run build
    Log-Success "Frontend built successfully"
}

# Build binary for a specific target
function Build-Binary {
    param(
        [string]$Target,
        [string]$PlatformName,
        [string]$BinarySuffix
    )
    
    Log-Info "Building binary for $PlatformName ($Target)..."
    
    # Install target if needed
    Install-Target $Target
    
    # Build the binary
    Push-Location src-tauri
    try {
        cargo build --release --target $Target
    } finally {
        Pop-Location
    }
    
    # Create output directory
    New-Item -ItemType Directory -Force -Path "dist\binaries" | Out-Null
    
    # Copy binary to dist directory
    $binaryName = "claudia$BinarySuffix"
    $outputName = "claudia-$PlatformName$BinarySuffix"
    $sourcePath = "src-tauri\target\$Target\release\$binaryName"
    $destPath = "dist\binaries\$outputName"
    
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $destPath
        Log-Success "Binary built: $destPath"
        
        # Show file info
        Get-Item $destPath | Format-List Name, Length, LastWriteTime
    } else {
        Log-Error "Binary not found: $sourcePath"
        throw "Build failed"
    }
}

# Build bundles using Tauri
function Build-Bundle {
    param(
        [string]$Target,
        [string]$PlatformName,
        [string]$Bundles
    )
    
    Log-Info "Building bundles for $PlatformName ($Bundles)..."
    
    # Install target if needed
    Install-Target $Target
    
    # Build with bundles
    bun run tauri build --bundles $Bundles --target $Target
    
    # List generated bundles
    $bundlePath = "src-tauri\target\$Target\release\bundle"
    if (Test-Path $bundlePath) {
        Log-Success "Bundles created in $bundlePath"
        Get-ChildItem -Path $bundlePath -Recurse -Include "*.deb", "*.dmg", "*.msi", "*.exe", "*.AppImage" | 
            Format-List Name, Length, LastWriteTime
    }
}

# Create release archive
function Create-Archive {
    param(
        [string]$PlatformName,
        [string]$BinarySuffix
    )
    
    Log-Info "Creating release archive for $PlatformName..."
    
    $archiveDir = "dist\releases\$PlatformName"
    New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
    
    # Copy binary
    Copy-Item "dist\binaries\claudia-$PlatformName$BinarySuffix" "$archiveDir\claudia$BinarySuffix"
    
    # Copy additional files
    Copy-Item "README.md" $archiveDir
    Copy-Item "LICENSE" $archiveDir
    
    # Create version info
    $version = git describe --tags --always --dirty 2>$null
    if (-not $version) { $version = "dev" }
    $versionInfo = @"
Claudia $version
Built on: $(Get-Date)
Platform: $PlatformName
Commit: $(git rev-parse HEAD 2>$null)
"@
    $versionInfo | Out-File -FilePath "$archiveDir\VERSION" -Encoding UTF8
    
    # Create archive
    Push-Location "dist\releases"
    try {
        if ($PlatformName -like "*windows*") {
            $archiveName = "claudia-$PlatformName.zip"
            Compress-Archive -Path $PlatformName -DestinationPath $archiveName -Force
            Log-Success "Archive created: dist\releases\$archiveName"
        } else {
            # Use tar if available, otherwise 7zip or built-in compression
            $archiveName = "claudia-$PlatformName.tar.gz"
            if (Get-Command tar -ErrorAction SilentlyContinue) {
                tar -czf $archiveName $PlatformName
                Log-Success "Archive created: dist\releases\$archiveName"
            } else {
                $zipName = "claudia-$PlatformName.zip"
                Compress-Archive -Path $PlatformName -DestinationPath $zipName -Force
                Log-Success "Archive created: dist\releases\$zipName (zip format used instead of tar.gz)"
            }
        }
    } finally {
        Pop-Location
    }
}

# Build for Linux
function Build-Linux {
    Log-Info "Building for Linux x86_64..."
    Build-Binary "x86_64-unknown-linux-gnu" "linux-x86_64" ""
    Create-Archive "linux-x86_64" ""
}

# Build for Windows
function Build-Windows {
    Log-Info "Building for Windows x86_64..."
    Build-Binary "x86_64-pc-windows-msvc" "windows-x86_64" ".exe"
    Create-Archive "windows-x86_64" ".exe"
}

# Build for macOS Intel
function Build-macOS {
    Log-Info "Building for macOS x86_64..."
    Build-Binary "x86_64-apple-darwin" "macos-x86_64" ""
    Create-Archive "macos-x86_64" ""
}

# Build for macOS ARM
function Build-macOS-ARM {
    Log-Info "Building for macOS ARM64..."
    Build-Binary "aarch64-apple-darwin" "macos-arm64" ""
    Create-Archive "macos-arm64" ""
}

# Clean previous builds
function Clean-Builds {
    Log-Info "Cleaning previous builds..."
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "dist\binaries", "dist\releases"
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "src-tauri\target\*\release\bundle"
    Log-Success "Clean completed"
}

# Show usage
function Show-Usage {
    Write-Host "Usage: .\scripts\build-binaries.ps1 [COMMAND]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  linux           Build for Linux x86_64"
    Write-Host "  windows         Build for Windows x86_64"
    Write-Host "  macos           Build for macOS x86_64"
    Write-Host "  macos-arm       Build for macOS ARM64"
    Write-Host "  all             Build for all platforms"
    Write-Host "  bundles         Build with installer bundles"
    Write-Host "  clean           Clean previous builds"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\scripts\build-binaries.ps1 windows         # Build Windows binary"
    Write-Host "  .\scripts\build-binaries.ps1 all             # Build all platform binaries"
    Write-Host "  .\scripts\build-binaries.ps1 bundles         # Build with installer bundles"
}

# Main function
try {
    switch ($Command.ToLower()) {
        "linux" {
            Check-Dependencies
            Build-Frontend
            Build-Linux
        }
        "windows" {
            Check-Dependencies
            Build-Frontend
            Build-Windows
        }
        "macos" {
            Check-Dependencies
            Build-Frontend
            Build-macOS
        }
        "macos-arm" {
            Check-Dependencies
            Build-Frontend
            Build-macOS-ARM
        }
        "all" {
            Check-Dependencies
            Build-Frontend
            Log-Info "Building for all platforms..."
            
            # Build for Windows (native platform)
            Build-Windows
            
            # Try to build for other platforms if cross-compilation tools are available
            try {
                Build-Linux
                Log-Success "Cross-compilation to Linux successful"
            } catch {
                Log-Warning "Cross-compilation to Linux failed: $($_.Exception.Message)"
            }
            
            try {
                Build-macOS
                Log-Success "Cross-compilation to macOS successful"
            } catch {
                Log-Warning "Cross-compilation to macOS failed: $($_.Exception.Message)"
            }
            
            Log-Success "All builds completed!"
            Write-Host ""
            Write-Host "📦 Generated binaries:"
            Get-ChildItem -Path "dist\binaries" -ErrorAction SilentlyContinue | Format-Table Name, Length, LastWriteTime
            Write-Host ""
            Write-Host "📋 Generated archives:"
            Get-ChildItem -Path "dist\releases" -Include "*.zip", "*.tar.gz" -Recurse -ErrorAction SilentlyContinue | 
                Format-Table Name, Length, LastWriteTime
        }
        "bundles" {
            Check-Dependencies
            Build-Frontend
            Log-Info "Building bundles for Windows..."
            Build-Bundle "x86_64-pc-windows-msvc" "windows" "msi"
        }
        "clean" {
            Clean-Builds
        }
        { $_ -in "", "help", "--help", "-h" } {
            Show-Usage
        }
        default {
            Log-Error "Unknown command: $Command"
            Write-Host ""
            Show-Usage
            exit 1
        }
    }
} catch {
    Log-Error "Build failed: $($_.Exception.Message)"
    exit 1
}