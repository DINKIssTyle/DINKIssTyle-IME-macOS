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
clang -arch x86_64 -arch arm64 -framework Cocoa -framework InputMethodKit \
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

# Build DKSTPreferences.app
echo "Compiling DKSTPreferences..."
mkdir -p build/DKSTPreferences.app/Contents/MacOS
mkdir -p build/DKSTPreferences.app/Contents/Resources

clang -arch x86_64 -arch arm64 -o build/DKSTPreferences.app/Contents/MacOS/DKSTPreferences \
    Sources/PreferencesApp/main.m \
    Sources/PreferencesController.m \
    Sources/DKSTConstants.m \
    -framework Cocoa -I Sources

# Create simple Info.plist for Prefs
cat > build/DKSTPreferences.app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DKSTPreferences</string>
    <key>CFBundleIdentifier</key>
    <string>com.dinkisstyle.inputmethod.DKST.preferences</string>
    <key>CFBundleName</key>
    <string>DKST Preferences</string>
    <key>CFBundleIconFile</key>
    <string>DKST</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Copy Icon
cp Resources/DKST.icns build/DKSTPreferences.app/Contents/Resources/

# Copy Prefs app into Input Method Resources
rm -rf build/DKST.app/Contents/Resources/DKSTPreferences.app
cp -r build/DKSTPreferences.app build/DKST.app/Contents/Resources/
