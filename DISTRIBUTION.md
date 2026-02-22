# KeySwitch — Distribution Guide

## For developers: Creating the installer

### Quick start

1. Open a terminal in the project folder:
   ```bash
   cd /path/to/KeySwitch
   ```

2. Run the build script:
   ```bash
   ./build_and_package.sh
   ```

3. When finished, you will get `KeySwitch.dmg` in the project root.

### What the script does

- Cleans previous builds
- Builds the project in Release configuration
- Creates a DMG with the app
- Adds a symlink to Applications for easy install

### File size

The DMG is typically about 5–15 MB (depending on dependencies).

---

## For testers: Installation and usage

**Currently working:** Clipboard (⌥+V), click-to-copy-and-paste, pin entries, settings.  
**In development:** Text transformation between layouts (⌃+T) — not yet reliable in all apps.

### Installation

1. **Open the DMG**
   - Double-click `KeySwitch.dmg`
   - The image will mount as a disk

2. **Install the app**
   - Drag `KeySwitch.app` into the `Applications` folder
   - Or copy it manually

3. **Launch the app**
   - Open Applications (⌘+Shift+A)
   - Find KeySwitch and launch it
   - **Note:** On first launch, macOS may ask for confirmation

4. **Grant permissions**
   - After launch you may be asked for **Accessibility** access
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Turn on the switch for **KeySwitch**
   - If KeySwitch is not in the list, add it manually (the "+" button)

### Usage

#### Clipboard (⌥+V) — works
- Press **Option + V** to open the clipboard menu
- Click an entry to copy it to the clipboard and **paste it immediately** into the active window (no extra ⌘+V needed)
- Pinned entries (★) always appear at the top

#### Text transformation (⌃+T) — in development
- Intended: select text → **Control + T** → convert between layouts (e.g. US ↔ Ukrainian) and switch layout
- This feature is not yet stable in many apps; expect updates

### Settings

- Click the KeySwitch icon in the menu bar
- Choose **Settings…**
- Configure:
  - Maximum number of entries (default: 20)
  - Enable or disable clipboard history

### Uninstall

1. Quit KeySwitch (click icon → Quit)
2. Remove `KeySwitch.app` from Applications
3. Remove preferences (optional):
   ```bash
   rm -rf ~/Library/Preferences/Roman-K.KeySwitch.plist
   ```

---

## Troubleshooting

### App does not launch

- Check that your macOS version meets requirements (macOS 14.0+)
- Check that the app is not blocked in Security & Privacy
- Try launching from the terminal:
  ```bash
  /Applications/KeySwitch.app/Contents/MacOS/KeySwitch
  ```

### Hotkeys do not work

- Ensure Accessibility permission is granted
- Restart the app after granting permission
- Check that hotkeys do not conflict with other apps

### Selected text not found

- Ensure text is actually selected
- Some apps may not support the Accessibility API
- Try in built-in apps (Notes, TextEdit)

### Keyboard layouts not found

- Ensure you have at least two keyboard layouts added
- Go to **System Settings → Keyboard → Input Sources**
- Add the layouts you need (e.g. US and Ukrainian)

---

## Technical details

- **Minimum macOS:** 14.0
- **Architecture:** Universal (Intel + Apple Silicon)
- **App size:** ~5–15 MB
- **Permissions:** Accessibility (required)

---

## Support

If you run into issues or have questions, open an issue on GitHub or contact the maintainer.
