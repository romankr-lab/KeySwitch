import AppKit
import SwiftUI

/// Hosts ClipboardPopoverView in a borderless, non-activating NSPanel
/// anchored below the status bar item - a custom "floating panel" rather
/// than a genuine NSPopover, since NSPopover always draws its own chrome
/// (arrow, fixed corner radius/material) that can't be fully replaced with
/// SwitchBoard's glass design.
///
/// `.nonactivatingPanel` is what lets this become key (so hover/click work
/// normally) without making SwitchBoard the frontmost application - the app
/// the user was typing in stays frontmost the whole time, which is what
/// keeps "restore focus after paste" working correctly.
final class ClipboardPopoverWindowController: NSObject {
    private var panel: NSPanel?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    private let viewModel = ClipboardPopoverViewModel()

    var onSelect: ((ClipboardEntry) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    #if DEBUG
    var onDebugTransform: (() -> Void)?
    #endif

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(relativeTo button: NSStatusBarButton) {
        if isVisible {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton) {
        viewModel.reload()

        var view = ClipboardPopoverView(
            viewModel: viewModel,
            onSelect: { [weak self] entry in
                self?.close()
                self?.onSelect?(entry)
            },
            onOpenSettings: { [weak self] in
                self?.close()
                self?.onOpenSettings?()
            },
            onQuit: { [weak self] in
                self?.onQuit?()
            }
        )
        #if DEBUG
        view.onDebugTransform = { [weak self] in
            self?.close()
            self?.onDebugTransform?()
        }
        #endif

        let hosting = NSHostingController(rootView: view)
        hosting.view.appearance = NSAppearance(named: .darkAqua)

        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.view.fittingSize
        panel.setContentSize(size)
        position(panel, size: size, relativeTo: button)

        self.panel?.close()
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)

        startMonitors()
    }

    func close() {
        stopMonitors()
        panel?.close()
        panel = nil
    }

    private func position(_ panel: NSPanel, size: NSSize, relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonFrameInScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? buttonFrameInScreen

        var x = buttonFrameInScreen.midX - size.width / 2
        x = min(max(x, screenFrame.minX + 8), screenFrame.maxX - size.width - 8)
        let y = buttonFrameInScreen.minY - size.height - 6

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startMonitors() {
        stopMonitors()

        // Dismiss when the user clicks outside SwitchBoard entirely.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }

        // Dismiss on Escape.
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Escape
                self.close()
                return nil
            }
            return event
        }
    }

    private func stopMonitors() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }
}
