import SwiftUI
import AppKit

/// Bridges ClipboardHistoryManager's NotificationCenter-based updates into
/// SwiftUI's observation model so ClipboardPopoverView redraws whenever the
/// underlying history changes.
final class ClipboardPopoverViewModel: ObservableObject {
    @Published private(set) var recent: [ClipboardEntry] = []
    @Published private(set) var pinned: [ClipboardEntry] = []

    private let manager = ClipboardHistoryManager.shared
    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: .clipboardDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func reload() {
        recent = manager.visibleRecentItems()
        pinned = manager.visiblePinnedItems()
    }

    func togglePin(_ entry: ClipboardEntry) {
        manager.togglePin(for: entry)
    }
}

/// The floating clipboard-history panel shown from the status bar item -
/// minimalist, line-art rows on a frosted glass container per SwitchBoard's
/// design language.
struct ClipboardPopoverView: View {
    @ObservedObject var viewModel: ClipboardPopoverViewModel

    var onSelect: (ClipboardEntry) -> Void
    var onOpenSettings: () -> Void
    var onQuit: () -> Void
    #if DEBUG
    var onDebugTransform: (() -> Void)? = nil
    #endif

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(SBColor.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.recent.isEmpty && viewModel.pinned.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(viewModel.recent.enumerated()), id: \.element.id) { index, entry in
                            ClipboardRow(
                                entry: entry,
                                index: index,
                                isPinned: false,
                                onSelect: { onSelect(entry) },
                                onTogglePin: { viewModel.togglePin(entry) }
                            )
                        }

                        if !viewModel.pinned.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(viewModel.pinned) { entry in
                                ClipboardRow(
                                    entry: entry,
                                    index: nil,
                                    isPinned: true,
                                    onSelect: { onSelect(entry) },
                                    onTogglePin: { viewModel.togglePin(entry) }
                                )
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 360)

            Divider().overlay(SBColor.border)
            footer
        }
        .frame(width: 300)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow)
                SBColor.containerBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SBColor.border, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("SWITCHBOARD")
                .font(SBFont.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(SBColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        Text("Clipboard is empty")
            .font(SBFont.body(13))
            .foregroundColor(SBColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(SBFont.mono(10, weight: .semibold))
            .tracking(1.0)
            .foregroundColor(SBColor.textSecondary)
            .padding(.top, 8)
            .padding(.horizontal, 4)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            FooterButton(title: "Settings", action: onOpenSettings)

            #if DEBUG
            if let onDebugTransform {
                FooterButton(title: "Test Transform", action: onDebugTransform)
            }
            #endif

            Spacer()

            FooterButton(title: "Quit", action: onQuit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct FooterButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SBFont.body(12))
                .foregroundColor(isHovering ? SBColor.textPrimary : SBColor.textSecondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
        }
    }
}

/// A single clipboard-history row: keycap index on the left, content in the
/// middle, relative timestamp on the right. Hovering brightens the card
/// background to signal interactivity.
private struct ClipboardRow: View {
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
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? SBColor.cardHover : SBColor.cardRest)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
        }
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.option) {
                onTogglePin()
            } else {
                onSelect()
            }
        }
        .help("Click to paste · ⌥-click to \(isPinned ? "unpin" : "pin")")
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
                        .frame(width: 20, height: 20)
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
        guard collapsed.count > 60 else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 60)
        return String(collapsed[..<end]) + "…"
    }
}
