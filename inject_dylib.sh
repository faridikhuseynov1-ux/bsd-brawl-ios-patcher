#!/bin/bash
# inject_dylib.sh - Build and inject BSD Mod Menu dylib into Brawl Stars IPA
# Run this on macOS with Xcode installed
#
# Usage:
#   chmod +x inject_dylib.sh
#   ./inject_dylib.sh BrawlStars_67.264_iOS_MODDED.ipa

set -e

IPA_PATH="${1:-BrawlStars_67.264_iOS_MODDED.ipa}"
DYLIB_NAME="ModMenu.dylib"
APP_BINARY="laser"
APP_DIR="Payload/laser.app"
WORK_DIR="$(mktemp -d)"

echo "=================================="
echo "  BSD iOS Mod Menu Injector"
echo "=================================="
echo "IPA: $IPA_PATH"
echo ""

# Check dependencies
for cmd in clang insert_dylib codesign zip unzip; do
    if ! command -v $cmd &>/dev/null; then
        echo "ERROR: '$cmd' not found."
        if [ "$cmd" = "insert_dylib" ]; then
            echo "  Install: brew install insert_dylib"
            echo "  Or build from: https://github.com/Tyilo/insert_dylib"
        fi
        exit 1
    fi
done

# Step 1: Compile dylib
echo "[1/5] Compiling ModMenu.dylib..."
clang -shared -o "$DYLIB_NAME" ModMenu.m \
    -framework UIKit \
    -framework Foundation \
    -install_name "@rpath/$DYLIB_NAME" \
    -arch arm64 \
    -miphoneos-version-min=14.0 \
    -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)"
echo "  Compiled: $DYLIB_NAME ($(du -sh $DYLIB_NAME | cut -f1))"

# Step 2: Extract IPA
echo ""
echo "[2/5] Extracting IPA..."
cp "$IPA_PATH" "$WORK_DIR/app.ipa"
cd "$WORK_DIR"
unzip -q app.ipa
echo "  Extracted to: $WORK_DIR"

# Step 3: Copy dylib into app bundle
echo ""
echo "[3/5] Copying dylib into app bundle..."
cp "$OLDPWD/$DYLIB_NAME" "$APP_DIR/$DYLIB_NAME"
echo "  Copied: $APP_DIR/$DYLIB_NAME"

# Step 4: Inject dylib into binary
echo ""
echo "[4/5] Injecting dylib into binary..."
insert_dylib --strip-codesig --inplace \
    "@rpath/$DYLIB_NAME" \
    "$APP_DIR/$APP_BINARY"
echo "  Injected into: $APP_DIR/$APP_BINARY"

# Step 5: Repack IPA
echo ""
echo "[5/5] Repacking IPA..."
OUTPUT_IPA="$OLDPWD/BrawlStars_MODDED_MENU.ipa"
zip -qr "$OUTPUT_IPA" Payload
echo "  Output: $OUTPUT_IPA"

# Cleanup
cd "$OLDPWD"
rm -rf "$WORK_DIR"

echo ""
echo "=================================="
echo "  DONE!"
echo "=================================="
echo ""
echo "Next steps:"
echo "  1. Sign the IPA with your Apple ID using Sideloadly"
echo "  2. Install on your iPhone"
echo "  3. In-game: triple-tap with 2 fingers to open mod menu"
echo ""
echo "Note: Re-sign every 7 days with free Apple ID."
