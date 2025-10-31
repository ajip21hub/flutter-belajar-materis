#!/bin/bash

# chmod +x scripts/post_build_verify.sh

# # Verify app bundle
# ./scripts/post_build_verify.sh build/app/outputs/bundle/release/app-release.aab

# # Verify APK
# ./scripts/post_build_verify.sh build/app/outputs/apk/release/app-release.apk


BUILD_FILE=${1:-"build/app/outputs/bundle/release/app-release.aab"}

echo "========================================="
echo "Post-Build Verification"
echo "========================================="

if [ ! -f "$BUILD_FILE" ]; then
    echo "Error: Build file not found: $BUILD_FILE"
    exit 1
fi

# 1. File size
echo ""
echo "1️⃣  Checking file size..."
SIZE=$(du -h "$BUILD_FILE" | cut -f1)
SIZE_BYTES=$(stat -f%z "$BUILD_FILE" 2>/dev/null || stat -c%s "$BUILD_FILE" 2>/dev/null)
echo "   File: $BUILD_FILE"
echo "   Size: $SIZE ($SIZE_BYTES bytes)"

if [ "$SIZE_BYTES" -gt 104857600 ]; then
    echo "   ⚠️  Warning: File > 100 MB"
fi

# 2. SHA256 Checksum
echo ""
echo "2️⃣  Calculating SHA256..."
SHA256=$(shasum -a 256 "$BUILD_FILE" | awk '{print $1}')
echo "   $SHA256"
echo "$SHA256" > "${BUILD_FILE}.sha256"
echo "   ✓ Saved to: ${BUILD_FILE}.sha256"

# 3. Symbol files
echo ""
echo "3️⃣  Checking symbol files..."
if [ -d "./symbols" ]; then
    SYMBOL_COUNT=$(find ./symbols -type f | wc -l)
    echo "   ✓ Symbol files backed up: $SYMBOL_COUNT files"
    echo "   Keep these for debugging obfuscated crashes!"
else
    echo "   ⚠️  No symbol files found"
fi

# 4. Build metadata
echo ""
echo "4️⃣  Build metadata:"
echo "   Type: $(file $BUILD_FILE | cut -d: -f2)"

if [[ "$BUILD_FILE" == *.aab ]]; then
    echo "   Format: Android App Bundle (AAB)"
    echo "   ✓ Preferred format for Play Store"
    echo "   ✓ Automatically splits by device config"
elif [[ "$BUILD_FILE" == *.apk ]]; then
    echo "   Format: APK"
    echo "   ✓ Can be installed directly"
fi

# 5. Version check
echo ""
echo "5️⃣  Version information:"
VERSION=$(grep "^version:" pubspec.yaml | head -1 | awk '{print $2}')
echo "   App version: $VERSION"

echo ""
echo "========================================="
echo "✓ Verification Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Upload to Play Store / App Store Connect"
echo "2. Review release notes and metadata"
echo "3. Set up staged rollout (5%, 10%, 25%, 50%, 100%)"
echo "4. Monitor Crashlytics and Analytics"
echo "5. Keep symbols backup for debugging"
