import SwiftUI
import AppKit

/// SwitchBoard's shared design language for the SwiftUI-hosted clipboard
/// menu rows: Swiss International Typographic Style (precision, grid
/// alignment, functional type) colors and type used via
/// ClipboardMenuRowView.
enum SBColor {
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)

    static let border = Color.white.opacity(0.12)
    static let cardHover = Color.white.opacity(0.1)

    /// Keycap badge text and outline - subtle by design, no fill, so the
    /// badge reads as a hint rather than competing with row content.
    static let keycapText = Color.white.opacity(0.5)
    static let keycapBorder = Color.white.opacity(0.2)
}

enum SBFont {
    /// SF Pro is the system default - naming it explicitly documents intent
    /// even though `.system` already resolves to it.
    static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// SF Mono for shortcut hints, key combos and monospaced snippets.
    static func mono(_ size: CGFloat = 11, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// A small keycap-styled badge (e.g. "⌘1", "⌥V") used throughout the app for
/// hotkey hints and list-item indexes.
struct KeycapBadge: View {
    let text: String
    var minWidth: CGFloat = 20

    var body: some View {
        Text(text)
            .font(SBFont.mono(11, weight: .semibold))
            .foregroundColor(SBColor.keycapText)
            .frame(minWidth: minWidth)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(SBColor.keycapBorder, lineWidth: 1)
            )
    }
}

/// Formats a Date as a short "time ago" string (e.g. "2m", "1h") for
/// secondary metadata text - deliberately terser than
/// RelativeDateTimeFormatter's full phrasing ("2 minutes ago") since it sits
/// in a narrow list row.
enum RelativeTime {
    static func short(since date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        switch seconds {
        case 0..<60: return "now"
        case 60..<3600: return "\(seconds / 60)m"
        case 3600..<86400: return "\(seconds / 3600)h"
        default: return "\(seconds / 86400)d"
        }
    }
}
