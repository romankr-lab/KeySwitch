import SwiftUI
import AppKit

/// A single clipboard-history row, hosted inside an NSMenuItem via
/// NSHostingView. The container is a plain NSMenu (see
/// StatusBarController.makeMenu()) - NSMenu already handles positioning,
/// dismissal and scrolling reliably, which a hand-rolled floating NSPanel
/// (the first version of this UI) turned out not to on this macOS version:
/// status items are hosted out-of-process by Control Center, and a custom
/// borderless/nonactivating NSPanel could report itself as on-screen and
/// visible while never actually compositing any pixels. NSMenuItem.view
/// gets us the same keycap/hover styling without touching that machinery.
struct ClipboardMenuRowView: View {
    let entry: ClipboardEntry
    let index: Int?
    let isPinned: Bool
    let onSelect: () -> Void
    let onTogglePin: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            leadingBadge

            contentView
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(RelativeTime.short(since: entry.date))
                .font(SBFont.body(11))
                .foregroundColor(SBColor.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 280, height: 28)
        .background(isHovering ? SBColor.cardHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.option) {
                onTogglePin()
            } else {
                onSelect()
            }
        }
        .help("Click to paste · ⌥-click to \(isPinned ? "unpin" : "pin")")
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var leadingBadge: some View {
        if isPinned {
            KeycapBadge(text: "★")
        } else if let index, index < 9 {
            KeycapBadge(text: "⌘\(index + 1)")
        } else {
            KeycapBadge(text: "•")
        }
    }

    @ViewBuilder private var contentView: some View {
        switch entry.content {
        case .text(let text):
            Text(Self.singleLine(text))
                .font(SBFont.body(13))
                .foregroundColor(SBColor.textPrimary)
        case .image(let data):
            let nsImage = NSImage(data: data)
            HStack(spacing: 6) {
                if let nsImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                if let size = nsImage?.size {
                    Text("Image (\(Int(size.width))×\(Int(size.height)))")
                        .font(SBFont.body(13))
                        .foregroundColor(SBColor.textPrimary)
                } else {
                    Text("Image")
                        .font(SBFont.body(13))
                        .foregroundColor(SBColor.textPrimary)
                }
            }
        }
    }

    private static func singleLine(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ")
        guard collapsed.count > 40 else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 40)
        return String(collapsed[..<end]) + "…"
    }
}

/// Wraps a ClipboardMenuRowView in an NSHostingView sized for use as an
/// NSMenuItem's custom view.
enum ClipboardMenuRow {
    static func makeHostingView(
        entry: ClipboardEntry,
        index: Int?,
        isPinned: Bool,
        onSelect: @escaping () -> Void,
        onTogglePin: @escaping () -> Void
    ) -> NSView {
        let row = ClipboardMenuRowView(
            entry: entry,
            index: index,
            isPinned: isPinned,
            onSelect: onSelect,
            onTogglePin: onTogglePin
        )
        let hosting = NSHostingView(rootView: row)
        hosting.frame = NSRect(x: 0, y: 0, width: 280, height: 28)
        return hosting
    }
}
