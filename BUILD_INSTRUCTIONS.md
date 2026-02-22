# KeySwitch — Build instructions

## Quick start

### Option 1: DMG (recommended)

```bash
cd /path/to/KeySwitch
./build_and_package.sh
```

When done, you will have `KeySwitch.dmg` in the project folder.

### Option 2: ZIP archive

```bash
cd /path/to/KeySwitch
./build_and_zip.sh
```

When done, you will have `KeySwitch.zip` in the project folder.

## Next steps

1. **Verify the artifact**
   - Confirm that the DMG or ZIP was created successfully
   - Check file size (typically 5–15 MB)

2. **Test the installer**
   - Open the DMG or ZIP on another Mac (or another user)
   - Install the app
   - Confirm everything works

3. **Distribute**
   - Share the DMG or ZIP with testers
   - Point them to the instructions in `DISTRIBUTION.md`

## Notes

- **Code signing:** The app is currently built without signing (fine for testing).
- **Gatekeeper:** macOS may warn about an unidentified developer — normal for unsigned builds.
- **Accessibility:** Testers will need to grant Accessibility permission manually.

## If something goes wrong

1. Ensure Xcode is installed
2. Ensure dependencies are resolved (HotKey package via SPM)
3. Check the build log for errors
4. Try building manually in Xcode (Product → Build or Product → Archive)

## Production builds

For a signed app (e.g. for distribution or App Store):

1. Configure code signing in Xcode
2. Use Xcode → Product → Archive
3. Export via the Organizer
