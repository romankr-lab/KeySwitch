#!/bin/bash

# Script to build KeySwitch and create a DMG installer with custom background and icon layout
# Usage: ./build_and_package.sh

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# SCHEME/PROJECT_NAME is the Xcode project & scheme name, unchanged since
# the SwitchBoard rebrand to avoid renaming the .xcodeproj/target. APP_NAME
# is the actual product name (PRODUCT_NAME build setting) - the two now
# differ on purpose.
PROJECT_NAME="KeySwitch"
SCHEME="KeySwitch"
APP_NAME_BASE="SwitchBoard"
CONFIGURATION="Release"
BUILD_DIR="build"
DMG_NAME="${APP_NAME_BASE}.dmg"
APP_NAME="${APP_NAME_BASE}.app"
DMG_TEMP="dmg_temp"
DMG_RW="dmg_rw.dmg"
VOLUME_NAME="${APP_NAME_BASE}"
BACKGROUND_IMG="packaging/dmg_background.png"

echo "🔨 Building ${APP_NAME_BASE} in ${CONFIGURATION} configuration..."

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "${BUILD_DIR}"
rm -f "${DMG_NAME}"
rm -f "${DMG_RW}"

# Build the project
#
# IMPORTANT: this signs with the "SwitchBoard Release Signing" self-signed
# certificate (see the SIGNING comment in .github/workflows/release.yml for
# the full story) - NOT ad-hoc (CODE_SIGN_IDENTITY="-"), and NOT whatever
# Xcode's "Automatically manage signing" + your free Apple ID Personal Team
# would produce ("Sign to Run Locally" / an Apple Development certificate).
#
# Gatekeeper treats this self-signed cert exactly like ad-hoc: an ordinary
# "unidentified developer" app, openable via right-click → Open on any Mac
# (unlike a free-Personal-Team Development certificate, which Gatekeeper
# flatly BLOCKS on any Mac other than the one that built it, no override).
# The difference from ad-hoc only matters for Sparkle auto-update: ad-hoc's
# implicit signing identity is pinned to that exact build's content hash,
# so no two separate ad-hoc builds can ever pass Sparkle's "same
# certificate as the currently-running app" check - auto-update always
# fails. This certificate is the same across every build (imported once
# into this Mac's keychain), so a DMG built here and a release built by CI
# both present the same signing identity to Sparkle.
#
# This certificate must already be in this machine's keychain (imported
# once via `security import`, then trusted via `security add-trusted-cert
# -p codeSign`) - if CODE_SIGN_IDENTITY below can't be found, this build
# will fail rather than silently falling back to ad-hoc.
echo "📦 Building project (signed with SwitchBoard Release Signing cert)..."
#
# -destination 'generic/platform=macOS' matters just as much: without it,
# `xcodebuild build` only builds for the Mac actually running the build
# (arm64-only on Apple Silicon), silently producing a non-universal binary
# that won't launch on Intel Macs despite this script's own instructions
# below claiming "Universal". The generic destination is what makes
# xcodebuild emit both arm64 and x86_64 slices the way an Archive would.
xcodebuild \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "${BUILD_DIR}" \
    clean build \
    CODE_SIGN_IDENTITY="SwitchBoard Release Signing" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM=""

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
    exit 1
fi

echo "✅ Found app at: ${APP_PATH}"

# Verify the app is signed with our self-signed cert as expected (this is
# the correct/desired outcome for a no-paid-account distributable build
# that still needs to be Sparkle-update-compatible - see the note above).
echo ""
echo "🔏 Verifying code signature..."
SIGNATURE_INFO=$(codesign -dv "${APP_PATH}" 2>&1)
if echo "$SIGNATURE_INFO" | grep -q "Authority=SwitchBoard Release Signing"; then
    echo "✅ Signed with SwitchBoard Release Signing, as expected."
elif echo "$SIGNATURE_INFO" | grep -q "Signature=adhoc"; then
    echo "⚠️  Signed ad-hoc, not with the SwitchBoard Release Signing cert."
    echo "    This build can launch fine but will NOT be able to Sparkle-update"
    echo "    to/from any cert-signed release. Check that the cert is imported"
    echo "    and trusted in this machine's keychain (security find-identity -v"
    echo "    -p codesigning should list \"SwitchBoard Release Signing\")."
elif echo "$SIGNATURE_INFO" | grep -q "not signed"; then
    echo "❌ App is NOT signed at all - something's wrong."
    echo "    Check the xcodebuild output above for signing errors."
else
    TEAM_ID=$(echo "$SIGNATURE_INFO" | grep "^TeamIdentifier=" | cut -d= -f2)
    echo "⚠️  Signed with a real Team Identifier (${TEAM_ID:-unknown}), not our cert."
    echo "    If that's your free Personal Team's Development certificate, this"
    echo "    build will likely be BLOCKED by Gatekeeper on any Mac other than"
    echo "    this one. If you now have a real paid Developer ID certificate,"
    echo "    this is expected and fine."
fi
echo ""

# Confirm universal (Intel + Apple Silicon) binary
echo "🏗  Verifying architectures..."
lipo -info "${APP_PATH}/Contents/MacOS/${APP_NAME_BASE}" || true
echo ""

# ----- DMG layout -----
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

echo "📋 Copying app to DMG directory..."
cp -R "${APP_PATH}" "${DMG_TEMP}/"

echo "🔗 Creating Applications symlink..."
ln -s /Applications "${DMG_TEMP}/Applications"

# Add background image for DMG window (hidden folder)
if [ -f "${BACKGROUND_IMG}" ]; then
    echo "🖼 Adding DMG background..."
    mkdir -p "${DMG_TEMP}/.background"
    cp "${BACKGROUND_IMG}" "${DMG_TEMP}/.background/dmg_background.png"
fi

# Create read-write DMG (large enough for app + padding)
DMG_SIZE=150
echo "💿 Creating temporary DMG (${DMG_SIZE}MB)..."
hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${DMG_TEMP}" \
    -ov -format UDRW -size "${DMG_SIZE}m" "${DMG_RW}"

rm -rf "${DMG_TEMP}"

# Mount and apply layout
echo "📐 Applying window layout and background..."
MOUNT_POINT="/Volumes/${VOLUME_NAME}"
hdiutil attach "${DMG_RW}" -noverify -mountpoint "${MOUNT_POINT}" 2>/dev/null || true

# Wait for volume to be ready
for i in {1..10}; do
    [ -d "${MOUNT_POINT}" ] && break
    sleep 1
done

if [ ! -d "${MOUNT_POINT}" ]; then
    echo "⚠️ Could not mount DMG for layout; creating simple DMG without custom background."
    rm -f "${DMG_RW}"
    mkdir -p "${DMG_TEMP}"
    cp -R "${APP_PATH}" "${DMG_TEMP}/"
    ln -s /Applications "${DMG_TEMP}/Applications"
    hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${DMG_TEMP}" \
        -ov -format UDZO -imagekey zlib-level=9 "${DMG_NAME}"
    rm -rf "${DMG_TEMP}"
else
    # Give the mounted DMG volume itself a custom icon (matches the app's
    # own icon) so it doesn't show the generic blank disk icon in Finder
    # once the DMG is opened.
    if [ -f "${APP_PATH}/Contents/Resources/AppIcon.icns" ]; then
        echo "🎨 Setting custom volume icon..."
        cp "${APP_PATH}/Contents/Resources/AppIcon.icns" "${MOUNT_POINT}/.VolumeIcon.icns"
        SetFile -c icnC "${MOUNT_POINT}/.VolumeIcon.icns"
        SetFile -a C "${MOUNT_POINT}"
    fi

    # AppleScript: set icon view, background, icon positions
    if [ -f "${MOUNT_POINT}/.background/dmg_background.png" ]; then
        BG_POSIX="${MOUNT_POINT}/.background/dmg_background.png"
        osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {120, 100, 780, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:dmg_background.png"
        set position of item "${APP_NAME}" of container window to {140, 200}
        set position of item "Applications" of container window to {420, 200}
        close
    end tell
end tell
EOF
    fi

    hdiutil detach "${MOUNT_POINT}" -quiet 2>/dev/null || hdiutil detach "${MOUNT_POINT}" -force -quiet 2>/dev/null || true

    echo "💿 Compressing final DMG..."
    hdiutil convert "${DMG_RW}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"
    rm -f "${DMG_RW}"
fi

# Give the .dmg FILE ITSELF (as seen in Finder before it's even opened) a
# custom icon - separate from the mounted volume's icon set above, since
# these are two independent Finder-level attributes. Uses NSWorkspace's
# public icon-setting API via a throwaway Swift script rather than the
# older Rez/DeRez resource tools, which may not be present.
if [ -f "${APP_PATH}/Contents/Resources/AppIcon.icns" ]; then
    echo "🎨 Setting custom icon on the .dmg file itself..."
    cat > /tmp/seticon.swift <<'SWIFT_EOF'
import Cocoa
let args = CommandLine.arguments
guard args.count >= 3, let icon = NSImage(contentsOfFile: args[1]) else {
    exit(1)
}
let success = NSWorkspace.shared.setIcon(icon, forFile: args[2], options: [])
exit(success ? 0 : 1)
SWIFT_EOF
    swift /tmp/seticon.swift "${APP_PATH}/Contents/Resources/AppIcon.icns" "$(pwd)/${DMG_NAME}"
    rm -f /tmp/seticon.swift
fi

echo "✅ DMG created successfully: ${DMG_NAME}"
echo "📦 File size: $(du -h "${DMG_NAME}" | cut -f1)"
echo ""
echo "🎉 Done!"
echo ""
echo "📝 Instructions for people installing it (no paid Developer ID yet, so"
echo "   Gatekeeper will flag it as from an unidentified developer):"
echo "   1. Double-click ${DMG_NAME} to mount it"
echo "   2. Drag ${APP_NAME} to Applications folder"
echo "   3. In Applications, RIGHT-CLICK ${APP_NAME} → Open (not double-click) the"
echo "      first time - this is what lets Gatekeeper allow an app that isn't"
echo "      from a paid Developer ID / notarized"
echo "   4. Grant Accessibility permissions when prompted"
echo "   5. The app will appear in the menu bar"
echo ""
echo "☑️  One thing to make sure of in Xcode before running this script:"
echo "   - Release configuration's 'Code Signing Entitlements' build setting"
echo "     points at KeySwitch-Release.entitlements, not the Debug one"
echo ""
echo "   (Signing & Capabilities' 'Automatically manage signing' / Personal"
echo "   Team setting is what Xcode uses when YOU run/debug the app locally -"
echo "   this script overrides that with the SwitchBoard Release Signing"
echo "   cert for the distributable build on purpose, since a Personal"
echo "   Team's Development certificate would be blocked entirely on any"
echo "   Mac but this one.)"
