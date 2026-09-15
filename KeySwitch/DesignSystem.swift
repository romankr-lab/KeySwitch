import SwiftUI
import AppKit

/// SwitchBoard's shared design language: a hybrid of native macOS
/// glassmorphism (frosted materials) and Swiss International Typographic
/// Style (precision, grid alignment, functional type). Every custom SwiftUI
/// surface in the app (clipboard popover, layout-correction HUD) pulls its
/// colors, type and chrome from here so they read as one system.
enum SBColor {
    static let textPrimary = Color.white
    /// #8B949E
    static let textSecondary = Color(red: 0x8B / 255.0, green: 0x94 / 255.0, blue: 0x96 / 255.0)

    /// rgba(20, 20, 24, 0.75) - the dark tinted glass laid over the native
    /// blurred material, per the design spec.
    static let containerBackground = Color(red: 20 / 255.0, green: 20 / 255.0, blue: 24 / 255.0).opacity(0.75)

    static let border = Color.white.opacity(0.1)

    static let cardRest = Color.white.opacity(0.03)
    static let cardHover = Color.white.opacity(0.08)
    static let accentHover = Color.blue.opacity(0.15)

    static let keycapFill = Color.white.opacity(0.06)
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

/// Wraps NSVisualEffectView so SwiftUI content can sit on the same native
/// frosted material the rest of macOS uses, forced to dark appearance to
/// match the design spec regardless of the user's system-wide setting.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
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
            .foregroundColor(SBColor.textPrimary)
            .frame(minWidth: minWidth)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(SBColor.keycapFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(SBColor.border, lineWidth: 1)
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
