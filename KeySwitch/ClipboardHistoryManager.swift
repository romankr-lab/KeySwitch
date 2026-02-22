import Cocoa

struct ClipboardEntry: Equatable {
    let content: String
    let date: Date
}

class ClipboardHistoryManager {

    static let shared = ClipboardHistoryManager()

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int

    // All history
    private(set) var items: [ClipboardEntry] = []

    // Pinned (stored by content)
    private(set) var pinnedContents: Set<String> = []

    // Limits
    let maxStoredItems = 20           // Maximum items to keep in history
    let maxVisiblePinned = 5          // How many pinned items to show in menu

    private init() {
        lastChangeCount = pasteboard.changeCount
        startMonitoring()
    }

    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        if let string = pasteboard.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addEntry(string)
        }
    }

    private func addEntry(_ string: String) {
        // Remove duplicate if exists
        if let existingIndex = items.firstIndex(where: { $0.content == string }) {
            items.remove(at: existingIndex)
        }

        let entry = ClipboardEntry(content: string, date: Date())
        items.insert(entry, at: 0)

        // Trim history
        if items.count > maxStoredItems {
            items.removeLast(items.count - maxStoredItems)
        }

        NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
    }

    // ====== PUBLIC METHODS FOR MENU ======

    /// Legacy method that simply returns recent items (if still called somewhere)
    func visibleItems() -> [ClipboardEntry] {
        return visibleRecentItems()
    }

    /// Items for Recent block (without pinned)
    /// Returns all items (up to 20), menu will handle scrolling automatically
    func visibleRecentItems() -> [ClipboardEntry] {
        let notPinned = items.filter { !pinnedContents.contains($0.content) }
        return Array(notPinned.prefix(maxStoredItems))
    }

    /// Items for Pinned block (only pinned items that still exist in items)
    func visiblePinnedItems() -> [ClipboardEntry] {
        let pinned = items.filter { pinnedContents.contains($0.content) }
        return Array(pinned.prefix(maxVisiblePinned))
    }

    func isPinned(_ entry: ClipboardEntry) -> Bool {
        pinnedContents.contains(entry.content)
    }

    func togglePin(for entry: ClipboardEntry) {
        if pinnedContents.contains(entry.content) {
            pinnedContents.remove(entry.content)
        } else {
            pinnedContents.insert(entry.content)
        }

        NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
    }
}

extension Notification.Name {
    static let clipboardDidUpdate = Notification.Name("clipboardDidUpdate")
}
