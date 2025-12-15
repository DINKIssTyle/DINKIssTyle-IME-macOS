#!/bin/bash
set -e

# Auto-detect Xcode if currently using CommandLineTools (needed for ibtool)
if [ -z "$DEVELOPER_DIR" ] && xcode-select -p | grep -q "CommandLineTools"; then
    if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        echo "Temporarily switching to Xcode toolchain for build..."
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    fi
fi

# Setup directories
rm -rf build
mkdir -p build/DKST.app/Contents/MacOS
mkdir -p build/DKST.app/Contents/Resources/Base.lproj

# Compile Sources (Manual Reference Counting)
echo "Compiling Sources..."
clang -framework Cocoa -framework InputMethodKit \
    -o build/DKST.app/Contents/MacOS/DKST \
    Sources/*.m

# Process Info.plist
echo "Processing Info.plist..."
sed -e 's/${PRODUCT_NAME}/DKST/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.dinkisstyle.inputmethod.DKST/g' \
    Resources/Info.plist > build/DKST.app/Contents/Info.plist

# Compile XIB
echo "Compiling XIB..."
if command -v ibtool &> /dev/null; then
    ibtool --compile build/DKST.app/Contents/Resources/Base.lproj/MainMenu.nib Resources/Base.lproj/MainMenu.xib
else
    echo "Warning: ibtool not found. Copying xib as is (might not work)."
    cp Resources/Base.lproj/MainMenu.xib build/DKST.app/Contents/Resources/Base.lproj/
fi

# Copy Resources
echo "Copying Resources..."
cp Resources/*.tiff build/DKST.app/Contents/Resources/ 2>/dev/null || :
cp Resources/*.icns build/DKST.app/Contents/Resources/ 2>/dev/null || :
cp Resources/*.pdf build/DKST.app/Contents/Resources/ 2>/dev/null || :
cp -r Resources/en.lproj build/DKST.app/Contents/Resources/
cp -r Resources/ko.lproj build/DKST.app/Contents/Resources/

# Create PkgInfo
echo "APPL????" > build/DKST.app/Contents/PkgInfo

echo "Build Complete: build/DKST.app"
