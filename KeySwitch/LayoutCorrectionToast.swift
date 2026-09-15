import Foundation
import UserNotifications

/// Shows a brief confirmation after a successful layout auto-correction.
///
/// This used to be a custom HUD "pill" drawn in a borderless NSPanel. On
/// this macOS version, a background/accessory app's own custom NSPanel
/// never actually got composited by WindowServer - os_log showed
/// isVisible=true and a valid on-screen frame, but occlusionState never
/// included .visible, meaning WindowServer itself wasn't drawing it,
/// regardless of window level or activation-policy flags. NSMenu (used for
/// the clipboard list) renders fine because it goes through a dedicated
/// system compositing path that doesn't depend on the owning app's
/// activation state; a plain NSWindow/NSPanel apparently does. A system
/// notification sidesteps the problem entirely - it's drawn by
/// Notification Center, not by SwitchBoard's own WindowServer client - at
/// the cost of the custom strikethrough/arrow pill design.
enum LayoutCorrectionToast {
    static func show(original: String, corrected: String) {
        let content = UNMutableNotificationContent()
        content.title = "Layout corrected"
        content.body = "\(singleLine(original)) → \(singleLine(corrected))"
        content.sound = nil // this fires often enough that a sound would be noisy

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("❌ Failed to show layout-correction notification: \(error.localizedDescription)")
            }
        }
    }

    // A whole selected paragraph would make an unreadable notification body,
    // so clip to a single short line.
    private static func singleLine(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > 40 else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: 40)
        return String(collapsed[..<end]) + "…"
    }
}
