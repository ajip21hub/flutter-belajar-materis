#!/bin/bash


# chmod +x scripts/build_production.sh

# # Build app bundle (recommended)
# ./scripts/build_production.sh appbundle

# # Build split APKs
# ./scripts/build_production.sh apk true

# # Build universal APK
# ./scripts/build_production.sh apk false



set -e

BUILD_TYPE=${1:-appbundle}  # appbundle atau apk
SPLIT_ABI=${2:-true}

echo "========================================="
echo "Flutter Production Build"
echo "========================================="
echo "Build Type: $BUILD_TYPE"
echo "Split per ABI: $SPLIT_ABI"

# Preparation
echo "Cleaning previous builds..."
flutter clean

echo "Getting dependencies..."
flutter pub get --enforce-lockfile

# Build
if [ "$BUILD_TYPE" = "appbundle" ]; then
    echo "Building App Bundle (AAB) for Play Store..."
    flutter build appbundle \
        --release \
        --obfuscate \
        --split-debug-info=./symbols
    
    OUTPUT_PATH="build/app/outputs/bundle/release/app-release.aab"
    
elif [ "$BUILD_TYPE" = "apk" ]; then
    if [ "$SPLIT_ABI" = "true" ]; then
        echo "Building split APKs per ABI..."
        flutter build apk \
            --release \
            --split-per-abi \
            --obfuscate \
            --split-debug-info=./symbols
    else
        echo "Building universal APK..."
        flutter build apk \
            --release \
            --obfuscate \
            --split-debug-info=./symbols
    fi
    
    OUTPUT_PATH="build/app/outputs/apk/release/"
fi

# Verify build
if [ -f "$OUTPUT_PATH" ] || [ -d "$OUTPUT_PATH" ]; then
    echo ""
    echo "✓ Build successful!"
    
    # Calculate size
    if [ -f "$OUTPUT_PATH" ]; then
        SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
        echo "✓ App size: $SIZE"
        
        # Generate checksum
        SHA256=$(shasum -a 256 "$OUTPUT_PATH" | awk '{print $1}')
        echo "✓ SHA256: $SHA256"
        echo "$SHA256" > "${OUTPUT_PATH}.sha256"
    fi
    
    echo "✓ Debug symbols backed up to: ./symbols"
    
else
    echo "✗ Build failed!"
    exit 1
fi

echo ""
echo "========================================="
echo "Build Complete & Ready for Upload!"
echo "========================================="
echo "Next steps:"
echo "1. Review build output: $OUTPUT_PATH"
echo "2. Upload to Google Play Console / App Store Connect"
echo "3. Set staged rollout (5% → 100%)"
echo "4. Monitor crashes in Firebase Crashlytics"
