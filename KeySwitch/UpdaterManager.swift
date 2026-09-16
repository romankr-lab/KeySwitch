import AppKit
import Combine
import Sparkle

/// Thin wrapper around Sparkle's `SPUStandardUpdaterController`, so the rest
/// of the app (StatusBarController's "Check for Updates…" item, and any
/// future SwiftUI settings UI) depends on this type instead of importing
/// Sparkle directly.
///
/// `startingUpdater: true` starts Sparkle's own schedule immediately on
/// construction: an update check on launch, then a periodic background
/// check per `SUScheduledCheckInterval` in Info.plist. We use Sparkle's
/// stock alerts/UI (`userDriverDelegate` conformance below is intentionally
/// a no-op - all methods on SPUStandardUserDriverDelegate are optional) so
/// there's no custom update UI to maintain.
final class UpdaterManager: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    static let shared = UpdaterManager()

    // `lazy` (rather than set from init) because SPUStandardUpdaterController
    // needs `self` as its userDriverDelegate, and `self` isn't usable as a
    // value until after super.init() completes.
    private lazy var updaterController: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }()

    private override init() {
        super.init()
    }

    /// Forces Sparkle's updater to actually start - its on-launch check and
    /// the periodic background schedule - since `updaterController` is
    /// otherwise only created on first access. Call once at app launch.
    func start() {
        _ = updaterController
    }

    /// Whether Sparkle is currently able to check (false while a check or
    /// install is already in progress) - use to enable/disable the "Check
    /// for Updates…" menu item.
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    /// Triggers an explicit, user-initiated update check. Wired to the
    /// "Check for Updates…" menu item; `nil` sender matches Sparkle's own
    /// documented call site since it doesn't use the sender.
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
