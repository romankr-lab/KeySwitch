import Cocoa
import ObjectiveC
import ApplicationServices

class StatusBarController {

    private var statusItem: NSStatusItem
    private let clipboardManager = ClipboardHistoryManager.shared

    init() {
        NSLog("🎯 StatusBarController init started")
        
        NSLog("📍 Creating NSStatusItem...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSLog("✅ NSStatusItem created")

        if let button = statusItem.button {
            // Text "icon" in the menu bar
            button.title = "⌘"
            NSLog("✅ Status bar button created with title: ⌘")
        } else {
            NSLog("❌ CRITICAL: Failed to create status bar button!")
        }

        NSLog("📍 Creating menu...")
        // Menu for clicking on the icon in the menu bar
        statusItem.menu = makeMenu()
        NSLog("✅ Menu created and assigned")

        // Update menu when clipboard history changes
        NSLog("📍 Setting up NotificationCenter observer...")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadMenu),
            name: .clipboardDidUpdate,
            object: nil
        )
        NSLog("✅ NotificationCenter observer set up")
        NSLog("🎉 StatusBarController init COMPLETED successfully!")
    }

    @objc private func reloadMenu() {
        statusItem.menu = makeMenu()
    }

    /// Called from AppDelegate on ⌥+V — shows menu at cursor location
    func showMenuFromHotKey() {
        let menu = makeMenu()
        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }

    /// Builds menu (Recent + Pinned + Settings + system items)
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 200
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
            // Add all items - menu will automatically add scrolling if > 10
            for (index, entry) in recent.enumerated() {
                menu.addItem(makeMenuItem(for: entry, index: index))
            }
        }

        // ====== PINNED ======
        if !pinned.isEmpty {
            menu.addItem(NSMenuItem.separator())

            let pinnedHeader = NSMenuItem(title: "Pinned", action: nil, keyEquivalent: "")
            pinnedHeader.isEnabled = false
            menu.addItem(pinnedHeader)

            for entry in pinned {
                let item = makeMenuItem(for: entry, index: nil, isPinnedSection: true)
                menu.addItem(item)
            }
        }

        // ====== Settings ======
        menu.addItem(NSMenuItem.separator())

        // Settings…
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Debug Accessibility
        let debugItem = NSMenuItem(
            title: "Debug Accessibility…",
            action: #selector(runAccessibilityDiagnostic),
            keyEquivalent: ""
        )
        debugItem.target = self
        menu.addItem(debugItem)
        
        // Transform Text (for testing)
        let transformItem = NSMenuItem(
            title: "Transform Text (⌃+T)",
            action: #selector(testTransformText),
            keyEquivalent: ""
        )
        transformItem.target = self
        menu.addItem(transformItem)

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    /// Creates NSMenuItem for clipboard entry
    private func makeMenuItem(for entry: ClipboardEntry,
                              index: Int?,
                              isPinnedSection: Bool = false) -> NSMenuItem {

        var title = entry.content.replacingOccurrences(of: "\n", with: " ")
        if title.count > 60 {
            let end = title.index(title.startIndex, offsetBy: 60)
            title = String(title[..<end]) + "…"
        }

        let isPinned = clipboardManager.isPinned(entry)
        let displayTitle = isPinned ? "★ " + title : title

        let keyEq: String
        if let idx = index, idx < 9 {
            keyEq = String(idx + 1)       // Shortcuts 1–9 only for recent items
        } else {
            keyEq = ""
        }

        let item = NSMenuItem(
            title: displayTitle,
            action: #selector(didSelectClipboardItem(_:)),
            keyEquivalent: keyEq
        )
        item.target = self
        item.representedObject = entry
        return item
    }

    // Click on history item → copy text to clipboard
    @objc private func didSelectClipboardItem(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? ClipboardEntry else { return }
        
        // Check if Option key is pressed (for pin/unpin)
        let event = NSApp.currentEvent
        if let event = event, event.modifierFlags.contains(.option) {
            // Option+Click - toggle pin/unpin
            clipboardManager.togglePin(for: entry)
            reloadMenu()
        } else {
            // Normal click - copy to clipboard and paste
            // Store the frontmost app before closing menu
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            
            sender.menu?.cancelTracking()
            
            // Small delay to ensure menu is fully closed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.copyEntryToClipboard(entry, restoreFocusTo: frontmostApp)
            }
        }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }
    
    @objc private func runAccessibilityDiagnostic() {
        AccessibilityDebugHelper.shared.performDetailedCheck()
        AccessibilityDebugHelper.shared.showDiagnosticAlert()
    }
    
    @objc private func testTransformText() {
        print("🧪 Test Transform Text menu item clicked")
        // Call method from AppDelegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.transformSelectedText()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}



extension StatusBarController {
    func copyEntryToClipboard(_ entry: ClipboardEntry, restoreFocusTo frontmostApp: NSRunningApplication? = nil) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.content, forType: .string)
        NSLog("📋 Selected from history: \(entry.content.prefix(50))...")
        print("📋 Selected from history: \(entry.content.prefix(50))...")
        
        // Automatically paste the text using ⌘+V simulation
        pasteTextFromClipboard(restoreFocusTo: frontmostApp)
    }
    
    /// Simulates ⌘+V to paste text from clipboard
    private func pasteTextFromClipboard(restoreFocusTo frontmostApp: NSRunningApplication? = nil) {
        NSLog("🔧 Starting paste operation...")
        print("🔧 Starting paste operation...")
        
        // Restore focus to the previous app if needed
        if let app = frontmostApp {
            NSLog("🔧 Restoring focus to: \(app.localizedName ?? "unknown")")
            print("🔧 Restoring focus to: \(app.localizedName ?? "unknown")")
            app.activate(options: [])
        }
        
        // Longer delay to ensure clipboard is ready, menu is closed, and focus is restored
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSLog("🔧 Creating event source for paste...")
            print("🔧 Creating event source for paste...")
            
            guard let source = CGEventSource(stateID: .hidSystemState) else {
                NSLog("❌ Failed to create event source for paste")
                print("❌ Failed to create event source for paste")
                return
            }
            
            // Simulate ⌘+V (V key = 0x09)
            NSLog("🔧 Simulating ⌘+V key down...")
            print("🔧 Simulating ⌘+V key down...")
            
            let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vKeyDown?.flags = .maskCommand
            vKeyDown?.post(tap: .cghidEventTap)
            NSLog("🔧 Key down posted")
            print("🔧 Key down posted")
            
            // Small delay between key down and key up
            usleep(10000) // 10ms
            
            NSLog("🔧 Simulating ⌘+V key up...")
            print("🔧 Simulating ⌘+V key up...")
            
            let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vKeyUp?.flags = .maskCommand
            vKeyUp?.post(tap: .cghidEventTap)
            NSLog("🔧 Key up posted")
            print("🔧 Key up posted")
            
            NSLog("✅ Paste command (⌘+V) simulated")
            print("✅ Paste command (⌘+V) simulated")
        }
    }
}

