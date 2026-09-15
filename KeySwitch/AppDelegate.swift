import Cocoa
import HotKey
import UserNotifications
import os.log
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow?
    var statusBarController: StatusBarController!

    // Global hotkeys - the actual key/modifier combo each one uses is
    // user-configurable via Settings (SettingsManager), defaulting to
    // ⌥+V (clipboard menu) and ⌥+T (layout transform). See registerHotKeys().
    var clipboardHotKey: HotKey?
    var transformHotKey: HotKey?
    private var accessibilityPollTimer: Timer?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // CRITICAL: Set activation policy BEFORE application finishes launching
        // This prevents the app from appearing in Dock
        if !NSApp.setActivationPolicy(.accessory) {
            NSLog("❌ CRITICAL: Failed to set activation policy in applicationWillFinishLaunching!")
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Verify activation policy is set correctly
        if NSApp.activationPolicy() != .accessory {
            _ = NSApp.setActivationPolicy(.accessory)
        }

        // CRITICAL: Disable automatic termination for status bar apps -
        // without this, macOS can terminate an accessory app that has no
        // visible window shortly after launch.
        NSApp.disableRelaunchOnLogin()
        ProcessInfo.processInfo.disableAutomaticTermination("Status bar app")

        // Hide the default window that Xcode creates for Cocoa App
        if let window = NSApplication.shared.windows.first {
            self.window = window
            window.orderOut(nil)
        }

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("❌ Notification authorization error: \(error.localizedDescription)")
            }
        }

        statusBarController = StatusBarController()

        // Check Accessibility permissions on startup
        checkAccessibilityPermissionsOnStartup()

        // Register both global hotkeys from whatever combo is stored in
        // Settings (defaults: ⌥+V and ⌥+T). Also called again from the
        // Settings window whenever the user re-records a shortcut.
        registerHotKeys()

        // Suggest Launch at Login once, after everything else has settled
        // (in particular, after the Accessibility permission check above)
        // so the two prompts don't stack on top of each other right at launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.suggestLaunchAtLoginIfNeeded()
        }
    }

    /// Suggests enabling Launch at Login once, the very first time the app
    /// ever runs after install - most people don't discover this on their
    /// own in Settings, and a status-bar utility is far more useful if it's
    /// just always running. Never asks again after this first prompt,
    /// regardless of the answer.
    private func suggestLaunchAtLoginIfNeeded() {
        guard AXIsProcessTrusted() else { return }
        let key = "hasPromptedLaunchAtLoginSuggestion"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let alert = NSAlert()
        alert.messageText = "Launch KeySwitch at Login?"
        alert.informativeText = "KeySwitch works best running in the background all the time. Want it to start automatically when you log in?"
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not Now")
        alert.alertStyle = .informational

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        do {
            try SMAppService.mainApp.register()
            NSLog("✅ Launch at Login enabled from first-run prompt")
        } catch {
            NSLog("❌ Failed to enable Launch at Login from first-run prompt: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) { }

    /// (Re)registers both global hotkeys using whatever combo is currently
    /// stored in Settings. Assigning new HotKey instances to
    /// clipboardHotKey/transformHotKey releases the previous ones, which
    /// unregisters them automatically (HotKey unregisters itself in deinit).
    /// Called once at launch, and again from the Settings window every time
    /// the user records a new shortcut, so the change takes effect
    /// immediately without needing to restart the app.
    func registerHotKeys() {
        let settings = SettingsManager.shared

        if let key = Key(carbonKeyCode: settings.clipboardHotKeyCode) {
            let modifiers = NSEvent.ModifierFlags(rawValue: settings.clipboardHotKeyModifiers)
            clipboardHotKey = HotKey(key: key, modifiers: modifiers)
            clipboardHotKey?.keyDownHandler = { [weak self] in
                DispatchQueue.main.async {
                    self?.statusBarController.showMenuFromHotKey()
                }
            }
        } else {
            clipboardHotKey = nil
            NSLog("❌ Could not resolve clipboard hotkey Key from stored keyCode \(settings.clipboardHotKeyCode)")
        }

        if let key = Key(carbonKeyCode: settings.transformHotKeyCode) {
            let modifiers = NSEvent.ModifierFlags(rawValue: settings.transformHotKeyModifiers)
            transformHotKey = HotKey(key: key, modifiers: modifiers)
            transformHotKey?.keyDownHandler = { [weak self] in
                DispatchQueue.main.async {
                    self?.transformSelectedText()
                }
            }
        } else {
            transformHotKey = nil
            NSLog("❌ Could not resolve transform hotkey Key from stored keyCode \(settings.transformHotKeyCode)")
        }
    }

    /// Shows a local user notification - used to surface errors/status like
    /// "No text selected" or "Failed to replace text" without any window,
    /// since the app has no UI beyond the menu bar.
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("❌ Failed to show notification: \(error.localizedDescription)")
            }
        }
    }

    /// Transforms selected text between keyboard layouts
    func transformSelectedText() {
        let layoutManager = LayoutManager.shared
        let transformer = LayoutTransformer.shared
        let textManager = TextSelectionManager.shared

        // CRITICAL: Try to get selected text FIRST (practical test)
        // If this works, it means permissions are actually working, regardless of what AXIsProcessTrusted() says
        var selectedText: String? = textManager.getSelectedText()

        // If we couldn't get text, check if it's because of permissions or just no selection
        if selectedText == nil || selectedText?.isEmpty == true {
            // Try practical test: can we access frontmost app?
            let hasPracticalAccess = textManager.checkAccessibilityPermissions()

            if !hasPracticalAccess {
                // Permissions are definitely missing - try to prompt
                let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)

                // Re-try getting text after prompt
                selectedText = textManager.getSelectedText()

                if selectedText == nil || selectedText?.isEmpty == true {
                    showNotification(
                        title: "KeySwitch",
                        message: "Accessibility permissions required. Please enable KeySwitch in System Settings → Privacy & Security → Accessibility"
                    )

                    // Open System Settings
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    return
                }
            } else {
                // Permissions work, but no text selected
                showNotification(title: "KeySwitch", message: "No text selected. Please select some text first.")
                return
            }
        }

        // At this point, we have selectedText
        guard let text = selectedText, !text.isEmpty else {
            showNotification(title: "KeySwitch", message: "No text selected. Please select some text first.")
            return
        }

        // Get current and next layouts
        guard let currentLayout = layoutManager.getCurrentLayout() else {
            showNotification(title: "KeySwitch", message: "Could not determine current layout")
            return
        }

        guard let nextLayout = layoutManager.getNextLayout() else {
            let layouts = layoutManager.getActiveLayouts()

            if layouts.isEmpty {
                showNotification(
                    title: "KeySwitch",
                    message: "No keyboard layouts found. Please add layouts in System Settings → Keyboard → Input Sources"
                )
            } else if layouts.count == 1 {
                showNotification(
                    title: "KeySwitch",
                    message: "Only one layout available (\(layouts.first?.name ?? "unknown")). Please add another layout in System Settings → Keyboard → Input Sources"
                )
            } else {
                showNotification(
                    title: "KeySwitch",
                    message: "Could not determine next layout. Found \(layouts.count) layouts."
                )
            }
            return
        }

        // Transform and replace text
        let transformedText = transformer.transformText(text, from: currentLayout, to: nextLayout)

        if textManager.replaceSelectedText(with: transformedText) {
            _ = layoutManager.switchToLayout(nextLayout)
            NSLog("✅ Text transformed from \(currentLayout.name) to \(nextLayout.name)")
        } else {
            NSLog("❌ Failed to replace selected text")
            showNotification(title: "KeySwitch", message: "Failed to replace text. Check Accessibility permissions in System Settings → Privacy & Security → Accessibility")
        }
    }

    /// Checks Accessibility permissions on startup and shows window if needed
    private func checkAccessibilityPermissionsOnStartup() {
        let textManager = TextSelectionManager.shared

        // Check permissions using practical test
        let hasAccess = textManager.checkAccessibilityPermissions()

        if !hasAccess {
            NSLog("⚠️ Accessibility permissions are NOT granted - showing permission window")

            // Show permission window after a short delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AccessibilityPermissionWindowController.shared.showWindow()
            }

            // The permission window closes itself as soon as the user clicks
            // "Open System Settings" - before they've actually flipped the
            // toggle over there - so we can't detect the grant from that
            // window closing. Poll instead, and once permission actually
            // appears, stop and move straight on to the Launch at Login
            // suggestion.
            startAccessibilityPermissionPolling()
        }
    }

    /// Polls for Accessibility permission being granted while the user is
    /// off in System Settings, since nothing else notifies the app when
    /// that happens. Stops itself as soon as permission is detected.
    ///
    /// Uses the authoritative AXIsProcessTrusted() check here rather than
    /// TextSelectionManager's "practical test" (which probes the frontmost
    /// app's focused window) - right after launch the frontmost app can
    /// briefly be KeySwitch's own permission window, and testing against
    /// itself gave a false positive before permission was actually granted.
    private func startAccessibilityPermissionPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard AXIsProcessTrusted() else { return }

            timer.invalidate()
            self.accessibilityPollTimer = nil
            NSLog("✅ Accessibility permission detected as granted while running - closing prompt")
            AccessibilityPermissionWindowController.shared.closeWindow()
            self.suggestLaunchAtLoginIfNeeded()
        }
    }
}
