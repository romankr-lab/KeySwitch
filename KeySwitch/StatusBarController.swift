import Cocoa
import SwiftUI

class StatusBarController {

    private var statusItem: NSStatusItem
    private let clipboardManager = ClipboardHistoryManager.shared

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
        } else {
            NSLog("❌ CRITICAL: Failed to create status bar button!")
        }

        // Menu for clicking on the icon in the menu bar. A plain NSMenu -
        // not a custom floating panel - since NSMenu's own show/position/
        // dismiss machinery is what actually renders reliably on this OS;
        // see ClipboardMenuRowView.swift for why the panel approach was
        // dropped. Individual clipboard rows still get the SwiftUI/keycap
        // styling via NSMenuItem.view.
        statusItem.menu = makeMenu()

        // Rebuild the menu whenever clipboard history changes, so it's
        // always current the next time it's opened.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadMenu),
            name: .clipboardDidUpdate,
            object: nil
        )
    }

    @objc private func reloadMenu() {
        statusItem.menu = makeMenu()
    }

    /// Called from AppDelegate on ⌥+V - shows the menu at the cursor location.
    func showMenuFromHotKey() {
        let menu = makeMenu()
        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }

    /// Builds menu (Recent + Pinned + Settings + system items)
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 280
        menu.autoenablesItems = false

        let recent = clipboardManager.visibleRecentItems()
        let pinned = clipboardManager.visiblePinnedItems()

        // ====== RECENT ======
        if recent.isEmpty && pinned.isEmpty {
            let emptyItem = NSMenuItem(
                title: "Clipboard is empty",
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, entry) in recent.enumerated() {
                menu.addItem(makeRowItem(for: entry, index: index, isPinned: false, in: menu))
            }
        }

        // ====== PINNED ======
        if !pinned.isEmpty {
            menu.addItem(NSMenuItem.separator())

            let pinnedHeader = NSMenuItem(title: "Pinned", action: nil, keyEquivalent: "")
            pinnedHeader.isEnabled = false
            menu.addItem(pinnedHeader)

            for entry in pinned {
                menu.addItem(makeRowItem(for: entry, index: nil, isPinned: true, in: menu))
            }
        }

        // ====== Check for Updates / Settings ======
        menu.addItem(NSMenuItem.separator())

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        checkForUpdatesItem.isEnabled = UpdaterManager.shared.canCheckForUpdates
        menu.addItem(checkForUpdatesItem)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        #if DEBUG
        let transformItem = NSMenuItem(
            title: "Transform Text (⌃+T)",
            action: #selector(testTransformText),
            keyEquivalent: ""
        )
        transformItem.target = self
        menu.addItem(transformItem)
        #endif

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    /// Builds an NSMenuItem hosting a SwiftUI ClipboardMenuRowView for one
    /// clipboard entry. `menu` is captured weakly so the row's own tap
    /// handler can close the menu on select, the same way the plain-title
    /// version used to via `sender.menu?.cancelTracking()`.
    private func makeRowItem(for entry: ClipboardEntry, index: Int?, isPinned: Bool, in menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.isEnabled = true

        item.view = ClipboardMenuRow.makeHostingView(
            entry: entry,
            index: index,
            isPinned: isPinned,
            onSelect: { [weak self, weak menu] in
                menu?.cancelTracking()
                self?.copyEntryToClipboard(entry)
            },
            onTogglePin: { [weak self] in
                self?.clipboardManager.togglePin(for: entry)
                // reloadMenu() (via the .clipboardDidUpdate notification
                // togglePin posts) rebuilds statusItem.menu in place - the
                // same pattern the original menu-based implementation used.
            }
        )
        return item
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func checkForUpdates() {
        UpdaterManager.shared.checkForUpdates()
    }

    #if DEBUG
    @objc private func testTransformText() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.transformSelectedText()
        }
    }
    #endif

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusBarController {
    func copyEntryToClipboard(_ entry: ClipboardEntry, restoreFocusTo frontmostApp: NSRunningApplication? = nil) {
        let pb = NSPasteboard.general
        pb.clearContents()

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
        if let app = frontmostApp {
            NSLog("🔧 Restoring focus to: \(app.localizedName ?? "unknown")")
            app.activate(options: [])
        }

        // Longer delay to ensure clipboard is ready, menu is closed, and focus is restored
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard let source = CGEventSource(stateID: .hidSystemState) else {
                NSLog("❌ Failed to create event source for paste")
                return
            }

            let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vKeyDown?.flags = .maskCommand
            vKeyDown?.post(tap: .cghidEventTap)

            usleep(10000) // 10ms

            let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vKeyUp?.flags = .maskCommand
            vKeyUp?.post(tap: .cghidEventTap)

            NSLog("✅ Paste command (⌘+V) simulated")
        }
    }
}
