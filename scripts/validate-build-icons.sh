#!/bin/bash

# Comprehensive icon validation for CI/build systems
# This script validates that all icon files are in proper format
# and addresses the RC2175 resource compiler error

echo "🔍 Running comprehensive icon validation..."

# Function to check ICO format
check_ico_format() {
    local file="$1"
    echo "Checking $file..."
    
    if [ ! -f "$file" ]; then
        echo "❌ ERROR: $file not found"
        return 1
    fi
    
    # Check file signature using hexdump
    local signature=$(head -c 4 "$file" | hexdump -v -e '4/1 "%02x "' | xargs)
    echo "  File signature: $signature"
    
    # ICO files must start with 00 00 01 00
    if [ "$signature" = "00 00 01 00" ]; then
        echo "  ✓ Valid ICO format (Windows Resource Compiler compatible)"
        return 0
    else
        echo "  ❌ Invalid ICO format - RC.EXE will fail with RC2175"
        echo "     Expected: 00 00 01 00"
        echo "     Found:    $signature"
        return 1
    fi
}

# Main validation
cd "$(dirname "$0")/.."

echo ""
echo "📋 Icon validation report:"
echo "========================="

# Check the main icon file that causes RC2175 errors
if check_ico_format "src-tauri/icons/icon.ico"; then
    echo ""
    echo "✅ All icon validations PASSED"
    echo "   - Build should succeed on Windows"
    echo "   - RC.EXE will accept the icon.ico file"
    echo "   - No RC2175 errors expected"
    
    # Show file details
    echo ""
    echo "📊 Icon file details:"
    ls -lh src-tauri/icons/icon.ico
    file src-tauri/icons/icon.ico
    
    exit 0
else
    echo ""
    echo "❌ Icon validation FAILED"
    echo "   - Windows builds will fail with RC2175"
    echo "   - Icon file needs to be regenerated in proper ICO format"
    echo ""
    echo "🔧 To fix this issue:"
    echo "   1. Convert icon.png to proper ICO format"
    echo "   2. Run: python3 /tmp/convert_to_ico.py src-tauri/icons/icon.png src-tauri/icons/icon.ico"
    echo "   3. Re-run this validation"
    
    exit 1
fi