#!/bin/bash
set -e

BUILD_CONFIG="./build.config"
if [ -f "$BUILD_CONFIG" ]; then
    # shellcheck source=/dev/null
    source "$BUILD_CONFIG"
fi

: "${DKST_VERSION_DISPLAY:=2.0(beta4)}"
: "${DKST_BUNDLE_SHORT_VERSION:=2.0}"
: "${DKST_BUNDLE_VERSION:=2.0.0.4}"
: "${DKST_PREFS_VERSION:=2.0.0}"

set_plist_string() {
    local plist_path="$1"
    local key="$2"
    local value="$3"

    /usr/bin/plutil -replace "$key" -string "$value" "$plist_path"
}

# Interactive build mode selection
echo "=========================================="
echo "    DKST macOS 한글입력기 빌드 도우미"
echo "    빌드 버젼: ${DKST_VERSION_DISPLAY}"
echo "=========================================="
echo "1. Debug 빌드 (개발용)"
echo "2. Release 빌드 (배포용)"
echo "=========================================="
read -p "빌드 모드를 선택하세요 [1-2]: " BUILD_CHOICE

case $BUILD_CHOICE in
    1)
        echo ""
        echo "� Building DEBUG version..."
        BUILD_MODE="debug"
        OPTIMIZATION="-O0"
        DEBUG_FLAGS="-DDEBUG"
        ;;
    2)
        echo ""
        echo "� Building RELEASE version..."
        BUILD_MODE="release"
        OPTIMIZATION="-O2"
        DEBUG_FLAGS="-DNDEBUG"
        ;;
    *)
        echo "잘못된 선택입니다. 1 또는 2를 입력하세요."
        exit 1
        ;;
esac

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
# -mmacosx-version-min ensures the binary runs on macOS 10.15+
# even when built on newer macOS (e.g., macOS 26 beta)
echo "Compiling Sources..."
clang -arch x86_64 -arch arm64 -mmacosx-version-min=10.15 \
    $OPTIMIZATION $DEBUG_FLAGS \
    -framework Cocoa -framework InputMethodKit -framework Carbon \
    -o build/DKST.app/Contents/MacOS/DKST \
    Sources/*.m

# Process Info.plist
echo "Processing Info.plist..."
sed -e 's/${PRODUCT_NAME}/DKST/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.dinkisstyle.inputmethod.DKST/g' \
    Resources/Info.plist > build/DKST.app/Contents/Info.plist
set_plist_string build/DKST.app/Contents/Info.plist CFBundleShortVersionString "$DKST_BUNDLE_SHORT_VERSION"
set_plist_string build/DKST.app/Contents/Info.plist CFBundleVersion "$DKST_BUNDLE_VERSION"
set_plist_string build/DKST.app/Contents/Info.plist DKSTVersionDisplay "$DKST_VERSION_DISPLAY"

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
cp Resources/hanja.txt build/DKST.app/Contents/Resources/ 2>/dev/null || :
cp -r Resources/en.lproj build/DKST.app/Contents/Resources/
cp -r Resources/ko.lproj build/DKST.app/Contents/Resources/

# Create PkgInfo
echo "APPL????" > build/DKST.app/Contents/PkgInfo

# Build DKSTSettings.app (Integrated Preferences & Dictionary Editor)
echo "Compiling DKSTSettings..."
mkdir -p build/DKSTSettings.app/Contents/MacOS
mkdir -p build/DKSTSettings.app/Contents/Resources

clang -arch x86_64 -arch arm64 -mmacosx-version-min=10.15 \
    $OPTIMIZATION $DEBUG_FLAGS \
    -DDKST_PREFS_VERSION=\"$DKST_PREFS_VERSION\" \
    -o build/DKSTSettings.app/Contents/MacOS/DKSTSettings \
    Sources/PreferencesApp/main.m \
    Sources/DKSTSettingsWindowController.m \
    Sources/DKSTSettingsViewControllers.m \
    Sources/DKSTConstants.m \
    Sources/DKSTKeyMap.m \
    Sources/DKSTShortcutRecorder.m \
    -framework Cocoa -framework Carbon -I Sources

# Create simple Info.plist for Settings
cat > build/DKSTSettings.app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DKSTSettings</string>
    <key>CFBundleIdentifier</key>
    <string>com.dinkisstyle.inputmethod.DKST.settings</string>
    <key>CFBundleName</key>
    <string>DKST macOS용 한글입력기</string>
    <key>CFBundleDisplayName</key>
    <string>DKST macOS용 한글입력기</string>
    <key>CFBundleIconFile</key>
    <string>DKST_pref</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
set_plist_string build/DKSTSettings.app/Contents/Info.plist CFBundleShortVersionString "$DKST_BUNDLE_SHORT_VERSION"
set_plist_string build/DKSTSettings.app/Contents/Info.plist CFBundleVersion "$DKST_BUNDLE_VERSION"

# Copy Icon
cp Resources/DKST_pref.icns build/DKSTSettings.app/Contents/Resources/
cp Resources/SettingsIcons/*.pdf build/DKSTSettings.app/Contents/Resources/
cp Resources/SettingsIcons/icon.png build/DKSTSettings.app/Contents/Resources/
cp Resources/hanja.txt build/DKSTSettings.app/Contents/Resources/
cp dictup.sh build/DKSTSettings.app/Contents/Resources/

# Copy Settings app into Input Method Resources
rm -rf build/DKST.app/Contents/Resources/DKSTSettings.app
cp -r build/DKSTSettings.app build/DKST.app/Contents/Resources/

# Codesign the built apps. Release builds use Developer ID; Debug builds use
# Apple Development. Public contributors without a matching certificate keep
# the existing ad-hoc signing behavior.
echo "Cleaning resource forks and extended attributes..."
xattr -cr build/DKST.app
xattr -cr build/DKSTSettings.app

AVAILABLE_IDENTITIES="$(security find-identity -v -p codesigning 2>&1 || true)"
SIGNING_IDENTITY="${DKST_CODESIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"
SIGNING_LABEL=""

if [ -z "$SIGNING_IDENTITY" ]; then
    if [ "$BUILD_MODE" = "release" ]; then
        IDENTITY_KINDS="Developer ID Application:"
    else
        IDENTITY_KINDS="Apple Development:|Mac Developer:"
    fi

    OLD_IFS="$IFS"
    IFS='|'
    for IDENTITY_KIND in $IDENTITY_KINDS; do
        SIGNING_IDENTITY="$(
            printf '%s\n' "$AVAILABLE_IDENTITIES" |
                awk -v kind="$IDENTITY_KIND" \
                    'index($0, "\"" kind) { print $2; exit }'
        )"
        if [ -n "$SIGNING_IDENTITY" ]; then
            break
        fi
    done
    IFS="$OLD_IFS"
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    SIGNING_LABEL="$(
        printf '%s\n' "$AVAILABLE_IDENTITIES" |
            awk -v identity="$SIGNING_IDENTITY" '
                $2 == identity {
                    line = $0
                    sub(/^[[:space:]]*[0-9]+\)[[:space:]]+[[:xdigit:]]+[[:space:]]+/, "", line)
                    print line
                    exit
                }
            '
    )"
    if [ -z "$SIGNING_LABEL" ]; then
        SIGNING_LABEL="$SIGNING_IDENTITY"
    fi

    if [ "$BUILD_MODE" = "release" ]; then
        case "$SIGNING_LABEL $SIGNING_IDENTITY" in
            *"Developer ID Application:"*) ;;
            *)
                echo "Warning: Release distribution requires a Developer ID Application certificate."
                ;;
        esac
    fi

    echo "Codesigning with Apple identity: $SIGNING_LABEL"
    CODESIGN_ARGS=(--force --sign "$SIGNING_IDENTITY" --options runtime)
    case "$SIGNING_LABEL $SIGNING_IDENTITY" in
        *"Developer ID Application:"*)
            CODESIGN_ARGS+=(--timestamp)
            ;;
    esac

    codesign "${CODESIGN_ARGS[@]}" build/DKSTSettings.app
    codesign "${CODESIGN_ARGS[@]}" build/DKST.app/Contents/Resources/DKSTSettings.app
    codesign "${CODESIGN_ARGS[@]}" build/DKST.app
else
    if [ "$BUILD_MODE" = "release" ]; then
        echo "Warning: No Developer ID Application identity found; this build is not ready for distribution."
    else
        echo "No Apple development signing identity found; using ad-hoc signatures."
    fi
    codesign --force --sign - --requirements '=designated => identifier "com.dinkisstyle.inputmethod.DKST.settings"' build/DKSTSettings.app
    codesign --force --sign - --requirements '=designated => identifier "com.dinkisstyle.inputmethod.DKST.settings"' build/DKST.app/Contents/Resources/DKSTSettings.app
    codesign --force --sign - --requirements '=designated => identifier "com.dinkisstyle.inputmethod.DKST"' build/DKST.app
fi

echo "Verifying code signatures..."
codesign --verify --strict --verbose=2 build/DKSTSettings.app
codesign --verify --deep --strict --verbose=2 build/DKST.app

# (DKSTDictEditor is now integrated into DKSTSettings)
