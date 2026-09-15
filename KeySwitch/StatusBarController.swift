import Cocoa
import SwiftUI

class StatusBarController {

    private var statusItem: NSStatusItem
    private let clipboardManager = ClipboardHistoryManager.shared
    private let popover = ClipboardPopoverWindowController()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // "SB" monogram badge - a brand mark rather than a function mark
            // (same move CleanShot/Bartender make), drawn as a vector
            // template PDF in Assets.xcassets/StatusBarIcon so it stays
            // crisp at any menu bar scale. Template rendering lets macOS
            // tint it correctly for the light/dark menu bar and the
            // highlighted state.
            if let icon = NSImage(named: "StatusBarIcon") {
                icon.isTemplate = true
                icon.accessibilityDescription = "SwitchBoard"
                button.image = icon
                button.title = ""
            } else {
                // Never leave the status item blank if the asset is ever
                // missing from the bundle.
                button.title = "SB"
            }
            button.action = #selector(statusItemClicked)
            button.target = self
        } else {
            NSLog("❌ CRITICAL: Failed to create status bar button!")
        }

        popover.onSelect = { [weak self] entry in
            self?.copyEntryToClipboard(entry)
        }
        popover.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        popover.onQuit = {
            NSApp.terminate(nil)
        }
        #if DEBUG
        popover.onDebugTransform = {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.transformSelectedText()
            }
        }
        #endif
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        popover.toggle(relativeTo: button)
    }

    /// Called from AppDelegate on ⌥+V - shows the same panel as clicking the
    /// status item.
    func showPopoverFromHotKey() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button)
    }

    private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }
}

extension StatusBarController {
    func copyEntryToClipboard(_ entry: ClipboardEntry, restoreFocusTo frontmostApp: NSRunningApplication? = nil) {
        let pb = NSPasteboard.general
        pb.clearContents()

        // Capture the frontmost app before we do anything else - the panel
        // is a non-activating NSPanel so it never becomes frontmost itself,
        // but capture defensively in case that ever changes.
        let target = frontmostApp ?? NSWorkspace.shared.frontmostApplication

        switch entry.content {
        case .text(let text):
            pb.setString(text, forType: .string)
            NSLog("📋 Selected from history (text, length=\(text.count))")
        case .image(let data):
            pb.setData(data, forType: .png)
            NSLog("📋 Selected from history (image, \(data.count) bytes)")
        }

        // Automatically paste using ⌘+V simulation (works for both text and images)
        pasteTextFromClipboard(restoreFocusTo: target)
    }

    /// Simulates ⌘+V to paste text from clipboard
    private func pasteTextFromClipboard(restoreFocusTo frontmostApp: NSRunningApplication? = nil) {
        // Restore focus to the previous app if needed
        if let app = frontmostApp {
            NSLog("🔧 Restoring focus to: \(app.localizedName ?? "unknown")")
            app.activate(options: [])
        }

        // Longer delay to ensure clipboard is ready, panel is closed, and focus is restored
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let source = CGEventSource(stateID: .hidSystemState) else {
                NSLog("❌ Failed to create event source for paste")
                return
            }

            // Simulate ⌘+V (V key = 0x09)
            let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vKeyDown?.flags = .maskCommand
            vKeyDown?.post(tap: .cghidEventTap)

            // Small delay between key down and key up
            usleep(10000) // 10ms

            let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vKeyUp?.flags = .maskCommand
            vKeyUp?.post(tap: .cghidEventTap)

            NSLog("✅ Paste command (⌘+V) simulated")
        }
    }
}
