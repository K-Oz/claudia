# Icon Format Fix for RC2175 Build Error

## Problem
The build was failing during the custom build command for Claudia in src-tauri with the error:
```
RC2175: resource file ...\icons\icon.ico is not in 3.00 format
```

This error occurs when the Windows Resource Compiler (RC.EXE) tries to process an icon file that is not in proper Windows ICO format.

## Root Cause
The `src-tauri/icons/icon.ico` file was actually a PNG image (33,181 bytes) rather than a proper Windows ICO file. While it had the `.ico` extension, the file format was PNG, which RC.EXE cannot process.

## Solution Implemented

### 1. Fixed the Icon File
- **Before**: icon.ico was a PNG file (33,181 bytes) with PNG signature `89 50 4e 47`
- **After**: icon.ico is a proper Windows ICO file (616 bytes) with ICO signature `00 00 01 00`

### 2. Added Validation Scripts
- **`validate_ico.rs`**: Rust validation script as suggested in the issue
- **`scripts/validate-build-icons.sh`**: Comprehensive validation with detailed reporting
- **`scripts/validate-icons.sh`**: Simple validation wrapper

### 3. Integrated into Build Pipeline
Updated `scripts/build-binaries.sh` to run icon validation before every build:
```bash
validate_icons()  # Called before build_frontend() in all build commands
```

## Verification
The fix can be verified by running:
```bash
# Quick validation
./scripts/validate-build-icons.sh

# Rust validator
rustc validate_ico.rs -o /tmp/validate_ico && /tmp/validate_ico

# Check file format
file src-tauri/icons/icon.ico
hexdump -C src-tauri/icons/icon.ico | head -1
```

## Prevention
To prevent this issue in the future:

1. **Always validate icon files** before committing:
   ```bash
   ./scripts/validate-build-icons.sh
   ```

2. **Use proper ICO generation** when creating new icons:
   ```python
   # Python example with Pillow
   from PIL import Image
   img = Image.open('icon.png')
   img.save('icon.ico', format='ICO', sizes=[(16,16), (32,32), (48,48), (256,256)])
   ```

3. **CI Integration**: The validation is now integrated into the build process and will catch invalid icons automatically.

## Technical Details
- **ICO Format**: Windows ICO files must start with the signature `00 00 01 00`
- **Multi-resolution**: Proper ICO files can contain multiple resolutions in a single file
- **RC.EXE Compatibility**: Only proper ICO format files work with Windows Resource Compiler

This fix ensures cognitive coherence in the build pathway and prevents RC2175 resource compiler failures.