import SwiftUI
import AppKit
import Combine

/// Drives the opacity+scale show/dismiss animation of the toast. Owned by
/// the controller so it can trigger the "animate out, then close the window"
/// two-phase sequence from outside the SwiftUI view.
private final class ToastAnimationState: ObservableObject {
    @Published var visible = false
}

/// Pill-shaped HUD shown briefly after a successful layout auto-correction:
/// "[ V ]  ghbdtn → привіт". Purely presentational - all state lives in
/// LayoutCorrectionToastController.
private struct LayoutCorrectionToastView: View {
    let original: String
    let corrected: String
    @ObservedObject fileprivate var animState: ToastAnimationState

    var body: some View {
        HStack(spacing: 10) {
            KeycapBadge(text: "V")

            HStack(spacing: 6) {
                Text(original)
                    .strikethrough(true, pattern: .solid, color: SBColor.textSecondary)
                    .foregroundColor(SBColor.textSecondary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SBColor.textSecondary)

                Text(corrected)
                    .fontWeight(.bold)
                    .foregroundColor(SBColor.textPrimary)
            }
            .font(SBFont.mono(13))
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow)
                SBColor.containerBackground
            }
        )
        .clipShape(Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(SBColor.border, lineWidth: 1))
        .scaleEffect(animState.visible ? 1 : 0.85)
        .opacity(animState.visible ? 1 : 0)
        .preferredColorScheme(.dark)
    }
}

/// Shows the layout-correction HUD as a borderless, non-activating floating
/// panel - it must never steal keyboard focus from whatever app the user was
/// typing in, or take over as the frontmost application.
final class LayoutCorrectionToastController {
    static let shared = LayoutCorrectionToastController()

    private var panel: NSPanel?
    private var animState: ToastAnimationState?
    private var dismissWorkItem: DispatchWorkItem?

    private let displayDuration: TimeInterval = 1.2
    private let showAnimation = Animation.spring(response: 0.32, dampingFraction: 0.72)
    private let hideAnimation = Animation.easeIn(duration: 0.18)
    private let hideAnimationDuration: TimeInterval = 0.18

    private init() {}

    private static func singleLine(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 40 else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 40)
        return String(collapsed[..<end]) + "…"
    }

    /// - Parameters:
    ///   - original: the mistyped text as it was before correction.
    ///   - corrected: the text after transforming to the right layout.
    func show(original: String, corrected: String) {
        dismissWorkItem?.cancel()

        let state = ToastAnimationState()
        animState = state

        // A whole selected paragraph would stretch the pill across the
        // screen - this is a glanceable HUD, not a text viewer, so clip to
        // a single short line.
        let view = LayoutCorrectionToastView(
            original: Self.singleLine(original),
            corrected: Self.singleLine(corrected),
            animState: state
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.appearance = NSAppearance(named: .darkAqua)

        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.view.fittingSize
        panel.setContentSize(size)
        position(panel, size: size)

        self.panel?.close()
        self.panel = panel
        panel.orderFrontRegardless()

        withAnimation(showAnimation) {
            state.visible = true
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
    }

    /// Bottom-center of the screen containing the mouse cursor - falls back
    /// to the main screen if that can't be determined - with enough margin
    /// to clear the Dock on typical setups.
    private func position(_ panel: NSPanel, size: NSSize) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let x = visibleFrame.midX - size.width / 2
        let y = visibleFrame.minY + 72
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func dismiss() {
        guard let panel, let animState else { return }

        withAnimation(hideAnimation) {
            animState.visible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + hideAnimationDuration) { [weak self] in
            guard let self, self.panel === panel else { return }
            panel.close()
            self.panel = nil
            self.animState = nil
        }
    }
}
