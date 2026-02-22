import Cocoa

class SettingsWindowController: NSWindowController {
    
    static let shared = SettingsWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeySwitch Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
        
        let viewController = SettingsViewController()
        window.contentViewController = viewController
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class SettingsViewController: NSViewController {
    
    // IBOutlets - must be strong (not weak) to prevent immediate deallocation
    // These are optional in case they're not connected in Interface Builder
    @IBOutlet var clipboardHistoryToggle: NSButton?
    @IBOutlet var historySizeLabel: NSTextField?
    @IBOutlet var historySizeSlider: NSSlider?
    @IBOutlet var resetHistoryButton: NSButton?
    @IBOutlet var clearPinnedButton: NSButton?
    @IBOutlet var doubleOptionToggle: NSButton?
    @IBOutlet var fixClipboardButton: NSButton?
    
    private var historyLimitField: NSTextField!
    private var historyLimitStepper: NSStepper!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 150))
        view.wantsLayer = true
        
        // History Limit label
        let historyLabel = NSTextField(labelWithString: "History Limit:")
        historyLabel.frame = NSRect(x: 20, y: 100, width: 120, height: 22)
        view.addSubview(historyLabel)
        
        // History Limit text field
        historyLimitField = NSTextField(frame: NSRect(x: 150, y: 100, width: 60, height: 22))
        historyLimitField.stringValue = String(SettingsManager.shared.historyLimit)
        historyLimitField.alignment = .right
        historyLimitField.target = self
        historyLimitField.action = #selector(historyLimitChanged(_:))
        view.addSubview(historyLimitField)
        
        // History Limit stepper
        historyLimitStepper = NSStepper(frame: NSRect(x: 215, y: 100, width: 19, height: 22))
        historyLimitStepper.minValue = 1
        historyLimitStepper.maxValue = 20
        historyLimitStepper.increment = 1
        historyLimitStepper.integerValue = SettingsManager.shared.historyLimit
        historyLimitStepper.target = self
        historyLimitStepper.action = #selector(historyLimitStepperChanged(_:))
        view.addSubview(historyLimitStepper)
        
        // Info label
        let infoLabel = NSTextField(labelWithString: "Maximum number of clipboard items to store (1-20)")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.frame = NSRect(x: 20, y: 70, width: 360, height: 22)
        view.addSubview(infoLabel)
        
        // Note about visible items
        let noteLabel = NSTextField(labelWithString: "Note: Up to 10 items are visible without scrolling, all 20 with scrolling")
        noteLabel.font = NSFont.systemFont(ofSize: 10)
        noteLabel.textColor = .tertiaryLabelColor
        noteLabel.frame = NSRect(x: 20, y: 40, width: 360, height: 22)
        view.addSubview(noteLabel)
    }
    
    @objc private func historyLimitChanged(_ sender: NSTextField) {
        if let value = Int(sender.stringValue), value >= 1 && value <= 20 {
            SettingsManager.shared.historyLimit = value
            historyLimitStepper.integerValue = value
        } else {
            sender.stringValue = String(SettingsManager.shared.historyLimit)
        }
    }
    
    @objc private func historyLimitStepperChanged(_ sender: NSStepper) {
        let value = sender.integerValue
        SettingsManager.shared.historyLimit = value
        historyLimitField.stringValue = String(value)
    }
}

