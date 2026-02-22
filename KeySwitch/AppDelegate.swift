import Cocoa
import HotKey
import UserNotifications
import os.log
import ApplicationServices

// Extension to execute code when module is loaded
extension AppDelegate {
    private static let _moduleInit: Void = {
        fputs("🔥 AppDelegate.swift module loaded\n", stderr)
        NSLog("🔥 AppDelegate.swift module loaded")
        
        // Disable Automatic Termination IMMEDIATELY when module loads
        ProcessInfo.processInfo.disableAutomaticTermination("Status bar app")
        fputs("✅ Automatic termination disabled in module initializer\n", stderr)
        NSLog("✅ Automatic termination disabled in module initializer")
    }()
}

class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow?
    var statusBarController: StatusBarController!

    // Global hotkey: Option + V for clipboard menu
    var clipboardHotKey: HotKey?
    
    // Global hotkey: Control + T for layout transformation
    var transformHotKey: HotKey?
    
    override init() {
        super.init()
        fputs("🎯 AppDelegate init() called\n", stderr)
        NSLog("🎯 AppDelegate init() called")
        
        // CRITICAL: Disable automatic termination IMMEDIATELY in init()
        // to prevent macOS from terminating the app before applicationDidFinishLaunching
        ProcessInfo.processInfo.disableAutomaticTermination("Status bar app")
        fputs("✅ Automatic termination disabled in init()\n", stderr)
        NSLog("🎯 AppDelegate init() - Automatic termination disabled")
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        fputs("🚀 0. applicationWillFinishLaunching called\n", stderr)
        NSLog("🚀 0. applicationWillFinishLaunching called")
        
        // CRITICAL: Set activation policy BEFORE application finishes launching
        // This prevents the app from appearing in Dock
        if NSApp.setActivationPolicy(.accessory) {
            fputs("✅ Activation policy set to .accessory in applicationWillFinishLaunching\n", stderr)
            NSLog("✅ Activation policy set to .accessory in applicationWillFinishLaunching")
        } else {
            fputs("❌ CRITICAL: Failed to set activation policy in applicationWillFinishLaunching!\n", stderr)
            NSLog("❌ CRITICAL: Failed to set activation policy in applicationWillFinishLaunching!")
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        fputs("🚀 1. APPLICATION STARTED - applicationDidFinishLaunching called\n", stderr)
        NSLog("🚀 1. APPLICATION STARTED - applicationDidFinishLaunching called")
        
        // Verify activation policy is set correctly
        let currentPolicy = NSApp.activationPolicy()
        if currentPolicy == .accessory {
            fputs("✅ Activation policy is .accessory\n", stderr)
            NSLog("✅ Activation policy is .accessory")
        } else {
            fputs("⚠️ Activation policy is \(currentPolicy.rawValue), attempting to set to .accessory\n", stderr)
            NSLog("⚠️ Activation policy is \(currentPolicy.rawValue), attempting to set to .accessory")
            if NSApp.setActivationPolicy(.accessory) {
                fputs("✅ Activation policy set to .accessory in applicationDidFinishLaunching\n", stderr)
                NSLog("✅ Activation policy set to .accessory in applicationDidFinishLaunching")
            } else {
                fputs("❌ CRITICAL: Failed to set activation policy!\n", stderr)
                NSLog("❌ CRITICAL: Failed to set activation policy!")
            }
        }
        
        // CRITICAL: Disable automatic termination for status bar apps
        NSApp.disableRelaunchOnLogin()
        ProcessInfo.processInfo.disableAutomaticTermination("Status bar app")
        fputs("✅ 2. Automatic termination disabled\n", stderr)
        NSLog("✅ 2. Automatic termination disabled")
        
        // Hide the default window that Xcode creates for Cocoa App
        if let window = NSApplication.shared.windows.first {
            self.window = window
            window.orderOut(nil)
            fputs("✅ 3. Hidden default window\n", stderr)
            NSLog("✅ 3. Hidden default window")
        } else {
            fputs("⚠️ 3. No default window found\n", stderr)
            NSLog("⚠️ 3. No default window found")
        }

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("❌ Notification authorization error: \(error.localizedDescription)")
            } else {
                NSLog("✅ Notification authorization granted: \(granted)")
            }
        }
        fputs("✅ 4. Notification authorization requested\n", stderr)
        NSLog("✅ 4. Notification authorization requested")

        fputs("📍 5. Creating StatusBarController...\n", stderr)
        NSLog("📍 5. Creating StatusBarController...")
        statusBarController = StatusBarController()
        fputs("✅ 6. StatusBarController created!\n", stderr)
        NSLog("✅ 6. StatusBarController created!")
        
        // Check Accessibility permissions on startup
        fputs("📍 6.5. Checking Accessibility permissions...\n", stderr)
        NSLog("📍 6.5. Checking Accessibility permissions...")
        checkAccessibilityPermissionsOnStartup()
        
        // Initialize and handle ⌥ + V hotkey
        fputs("📍 7. Registering clipboard hotkey (⌥+V)...\n", stderr)
        NSLog("📍 7. Registering clipboard hotkey (⌥+V)...")
        clipboardHotKey = HotKey(key: .v, modifiers: [.option])
        clipboardHotKey?.keyDownHandler = { [weak self] in
            NSLog("⌥+V pressed")
            DispatchQueue.main.async {
                self?.statusBarController.showMenuFromHotKey()
            }
        }
        fputs("✅ 8. Clipboard hotkey registered\n", stderr)
        NSLog("✅ 8. Clipboard hotkey registered")
        
        // Handle ⌃ + T hotkey for layout transformation
        fputs("📍 9. Registering transform hotkey (⌃+T)...\n", stderr)
        NSLog("📍 9. Registering transform hotkey (⌃+T)...")
        transformHotKey = HotKey(key: .t, modifiers: [.control])
        transformHotKey?.keyDownHandler = { [weak self] in
            NSLog("⌃+T pressed")
            DispatchQueue.main.async {
                self?.transformSelectedText()
            }
        }
        fputs("✅ 10. Transform hotkey registered\n", stderr)
        NSLog("✅ 10. Transform hotkey registered")
        
        fputs("🎉 11. ALL INITIALIZATION COMPLETED SUCCESSFULLY!\n", stderr)
        NSLog("🎉 11. ALL INITIALIZATION COMPLETED SUCCESSFULLY!")
    }

    func applicationWillTerminate(_ aNotification: Notification) { }
    
    /// Transforms selected text between keyboard layouts
    func transformSelectedText() {
        NSLog("🔄 transformSelectedText() called")
        
        let layoutManager = LayoutManager.shared
        let transformer = LayoutTransformer.shared
        let textManager = TextSelectionManager.shared
        
        // CRITICAL: Try to get selected text FIRST (practical test)
        // If this works, it means permissions are actually working, regardless of what AXIsProcessTrusted() says
        NSLog("📋 Attempting to get selected text (practical test)...")
        var selectedText: String? = textManager.getSelectedText()
        
        // If we couldn't get text, check if it's because of permissions or just no selection
        if selectedText == nil || selectedText?.isEmpty == true {
            NSLog("⚠️ Could not get selected text. Checking if this is a permissions issue...")
            
            // Try practical test: can we access frontmost app?
            let hasPracticalAccess = textManager.checkAccessibilityPermissions()
            NSLog("🔍 Practical accessibility test: \(hasPracticalAccess)")
            
            if !hasPracticalAccess {
                // Permissions are definitely missing - try to prompt
                NSLog("⚠️ Accessibility permissions appear to be missing. Attempting to prompt...")
                
                let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                let isTrustedWithPrompt = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
                NSLog("🔍 AXIsProcessTrustedWithOptions (with prompt): \(isTrustedWithPrompt)")
                
                // Re-try getting text after prompt
                selectedText = textManager.getSelectedText()
                
                if selectedText == nil || selectedText?.isEmpty == true {
                    NSLog("❌ Still cannot get text after prompt")
                    showNotification(
                        title: "KeySwitch",
                        message: "Accessibility permissions required. Please enable KeySwitch in System Settings → Privacy & Security → Accessibility"
                    )
                    
                    // Open System Settings
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    return
                }
            } else {
                // Permissions work, but no text selected
                NSLog("✅ Permissions are working, but no text is selected")
                showNotification(title: "KeySwitch", message: "No text selected. Please select some text first.")
                return
            }
        }
        
        // At this point, we have selectedText
        guard let text = selectedText, !text.isEmpty else {
            NSLog("❌ No text selected")
            showNotification(title: "KeySwitch", message: "No text selected. Please select some text first.")
            return
        }
        
        NSLog("✅ Successfully got selected text: length=\(text.count)")
        NSLog("✅ Accessibility permissions are working (practical test passed)")
        
        // Get current and next layouts
        NSLog("⌨️ Getting current layout...")
        guard let currentLayout = layoutManager.getCurrentLayout() else {
            NSLog("❌ Could not determine current layout")
            showNotification(title: "KeySwitch", message: "Could not determine current layout")
            return
        }
        
        NSLog("✅ Current layout: \(currentLayout.name) (\(currentLayout.id))")
        
        NSLog("⌨️ Getting next layout...")
        guard let nextLayout = layoutManager.getNextLayout() else {
            let layouts = layoutManager.getActiveLayouts()
            NSLog("❌ No next layout available. Found \(layouts.count) layout(s)")
            
            if layouts.isEmpty {
                showNotification(
                    title: "KeySwitch",
                    message: "No keyboard layouts found. Please add layouts in System Settings → Keyboard → Input Sources"
                )
            } else if layouts.count == 1 {
                showNotification(
                    title: "KeySwitch",
                    message: "Only one layout available (\(layouts.first?.name ?? "unknown")). Please add another layout in System Settings → Keyboard → Input Sources"
                )
            } else {
                showNotification(
                    title: "KeySwitch",
                    message: "Could not determine next layout. Found \(layouts.count) layouts."
                )
            }
            return
        }
        
        NSLog("✅ Next layout: \(nextLayout.name) (\(nextLayout.id))")
        
        // Transform and replace text
        NSLog("🔄 Transforming text from \(currentLayout.name) to \(nextLayout.name)...")
        let transformedText = transformer.transformText(text, from: currentLayout, to: nextLayout)
        NSLog("✅ Transformed text: length=\(transformedText.count)")
        
        NSLog("✏️ Attempting to replace selected text...")
        if textManager.replaceSelectedText(with: transformedText) {
            NSLog("⌨️ Switching to layout: \(nextLayout.name)")
            _ = layoutManager.switchToLayout(nextLayout)
            NSLog("✅ Success! Text transformed from \(currentLayout.name) to \(nextLayout.name)")
        } else {
            NSLog("❌ Failed to replace selected text")
            showNotification(title: "KeySwitch", message: "Failed to replace text. Check Accessibility permissions in System Settings → Privacy & Security → Accessibility")
        }
    }
    
    /// Checks Accessibility permissions on startup and shows window if needed
    private func checkAccessibilityPermissionsOnStartup() {
        let textManager = TextSelectionManager.shared
        
        // Check permissions using practical test
        let hasAccess = textManager.checkAccessibilityPermissions()
        
        if hasAccess {
            NSLog("✅ Accessibility permissions are granted - app can proceed normally")
            fputs("✅ Accessibility permissions are granted\n", stderr)
        } else {
            NSLog("⚠️ Accessibility permissions are NOT granted - showing permission window")
            fputs("⚠️ Accessibility permissions are NOT granted - showing permission window\n", stderr)
            
            // Show permission window after a short delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AccessibilityPermissionWindowController.shared.showWindow()
            }
        }
    }
    
    /// Shows a notification
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = nil
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
