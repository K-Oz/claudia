#!/bin/bash

# Pre-build validation script to check icon format
# This prevents build failures due to invalid icon files

set -e

echo "🔍 Validating icon files before build..."

# Check if the ICO validation script exists, if not compile it
if [ ! -f "/tmp/validate_ico" ]; then
    echo "Compiling ICO validator..."
    rustc validate_ico.rs -o /tmp/validate_ico
fi

# Run the validation
echo "Checking src-tauri/icons/icon.ico..."
/tmp/validate_ico

echo "✅ All icon validations passed!"
echo "Proceeding with build..."