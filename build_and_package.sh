#!/bin/bash

# Script to build KeySwitch and create a DMG installer
# Usage: ./build_and_package.sh

set -e  # Exit on error

PROJECT_NAME="KeySwitch"
SCHEME="KeySwitch"
CONFIGURATION="Release"
BUILD_DIR="build"
DMG_NAME="${PROJECT_NAME}.dmg"
APP_NAME="${PROJECT_NAME}.app"

echo "🔨 Building ${PROJECT_NAME} in ${CONFIGURATION} configuration..."

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "${BUILD_DIR}"
rm -f "${DMG_NAME}"

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
# Try multiple possible locations
APP_PATH=$(find "${BUILD_DIR}" -name "${APP_NAME}" -type d 2>/dev/null | head -n 1)

# Alternative: check Build/Products/Release
if [ -z "$APP_PATH" ]; then
    ALT_PATH="${BUILD_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}"
    if [ -d "$ALT_PATH" ]; then
        APP_PATH="$ALT_PATH"
    fi
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Could not find built app"
    echo "   Searched in: ${BUILD_DIR}"
    echo "   Please check the build output above for errors"
    exit 1
fi

echo "✅ Found app at: ${APP_PATH}"

# Create DMG directory structure
DMG_TEMP="dmg_temp"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# Copy app to DMG directory
echo "📋 Copying app to DMG directory..."
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Create Applications symlink (for easier installation)
echo "🔗 Creating Applications symlink..."
ln -s /Applications "${DMG_TEMP}/Applications"

# Set DMG background and layout (optional - requires .DS_Store)
# For now, we'll create a simple DMG

# Create DMG
echo "💿 Creating DMG..."
hdiutil create -volname "${PROJECT_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_NAME}"

# Clean up
rm -rf "${DMG_TEMP}"

echo "✅ DMG created successfully: ${DMG_NAME}"
echo "📦 File size: $(du -h "${DMG_NAME}" | cut -f1)"
echo ""
echo "🎉 Done! You can now distribute ${DMG_NAME} to testers."
echo ""
echo "📝 Instructions for testers:"
echo "   1. Double-click ${DMG_NAME} to mount it"
echo "   2. Drag ${APP_NAME} to Applications folder"
echo "   3. Open Applications and launch ${APP_NAME}"
echo "   4. Grant Accessibility permissions when prompted"
echo "   5. The app will appear in the menu bar"

