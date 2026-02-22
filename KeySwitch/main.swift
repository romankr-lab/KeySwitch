import Cocoa

// CRITICAL: Set activation policy BEFORE AppDelegate is created
// This must happen as early as possible in the application lifecycle
let app = NSApplication.shared
_ = app.setActivationPolicy(.accessory)

// Disable automatic termination immediately
ProcessInfo.processInfo.disableAutomaticTermination("Status bar app")

// Create and set delegate
// Use MainActor.assumeIsolated to satisfy Swift concurrency requirements
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    app.delegate = delegate
}

// Run the app
app.run()

