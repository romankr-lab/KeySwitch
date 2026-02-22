#!/bin/bash

# Alternative script to build KeySwitch and create a ZIP archive
# Usage: ./build_and_zip.sh

set -e  # Exit on error

PROJECT_NAME="KeySwitch"
SCHEME="KeySwitch"
CONFIGURATION="Release"
BUILD_DIR="build"
ZIP_NAME="${PROJECT_NAME}.zip"
APP_NAME="${PROJECT_NAME}.app"

echo "🔨 Building ${PROJECT_NAME} in ${CONFIGURATION} configuration..."

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "${BUILD_DIR}"
rm -f "${ZIP_NAME}"

# Build the project
echo "📦 Building project..."
xcodebuild \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${BUILD_DIR}" \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Find the built app
APP_PATH=$(find "${BUILD_DIR}" -name "${APP_NAME}" -type d 2>/dev/null | head -n 1)

if [ -z "$APP_PATH" ]; then
    ALT_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}"
    if [ -d "$ALT_PATH" ]; then
        APP_PATH="$ALT_PATH"
    fi
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Could not find built app"
    echo "   Searched in: ${BUILD_DIR}"
    exit 1
fi

echo "✅ Found app at: ${APP_PATH}"

# Create ZIP
echo "📦 Creating ZIP archive..."
cd "$(dirname "$APP_PATH")"
zip -r -q "$(pwd)/../../${ZIP_NAME}" "${APP_NAME}"
cd - > /dev/null

echo "✅ ZIP created successfully: ${ZIP_NAME}"
echo "📦 File size: $(du -h "${ZIP_NAME}" | cut -f1)"
echo ""
echo "🎉 Done! You can now distribute ${ZIP_NAME} to testers."
echo ""
echo "📝 Instructions for testers:"
echo "   1. Extract ${ZIP_NAME}"
echo "   2. Move ${APP_NAME} to Applications folder"
echo "   3. Open Applications and launch ${APP_NAME}"
echo "   4. Grant Accessibility permissions when prompted"

