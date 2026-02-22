import Cocoa
import Carbon
import ApplicationServices
import os.log
import Darwin.C

struct KeyboardLayout {
    let id: String
    let name: String
    let source: TISInputSource
    
    init?(source: TISInputSource, getPropertyFunc: @escaping (TISInputSource, CFString) -> UnsafeMutableRawPointer?) {
        self.source = source
        
        // Get ID
        guard let idUnmanaged = getPropertyFunc(source, kTISPropertyInputSourceID) else {
            return nil
        }
        let id = Unmanaged<CFString>.fromOpaque(idUnmanaged).takeUnretainedValue() as String
        
        // Get name
        var name = id
        if let nameUnmanaged = getPropertyFunc(source, kTISPropertyLocalizedName) {
            name = Unmanaged<CFString>.fromOpaque(nameUnmanaged).takeUnretainedValue() as String
        }
        
        self.id = id
        self.name = name
    }
}

class LayoutManager {
    static let shared = LayoutManager()
    private let logger = OSLog(subsystem: "com.romank.keyswitch", category: "LayoutManager")
    private var carbonHandle: UnsafeMutableRawPointer?
    
    private init() {
        // Load Carbon framework (TIS functions are in Carbon, not ApplicationServices)
        carbonHandle = dlopen("/System/Library/Frameworks/Carbon.framework/Carbon", RTLD_LAZY)
        if carbonHandle == nil {
            os_log("⚠️ Failed to load Carbon framework", log: logger, type: .error)
            print("⚠️ Failed to load Carbon framework")
        } else {
            os_log("LayoutManager initialized", log: logger, type: .info)
        }
    }
    
    deinit {
        if let handle = carbonHandle {
            dlclose(handle)
        }
    }
    
    /// Gets TISCopyInputSourceList function
    private func getTISCopyInputSourceList() -> ((CFDictionary?, Bool) -> Unmanaged<CFArray>?)? {
        guard let handle = carbonHandle else {
            os_log("❌ Carbon handle is nil", log: logger, type: .error)
            print("❌ Carbon handle is nil")
            return nil
        }
        
        // Try to find the symbol
        guard let funcPtr = dlsym(handle, "TISCopyInputSourceList") else {
            let error = String(cString: dlerror())
            os_log("❌ Failed to find TISCopyInputSourceList symbol: %{public}@", log: logger, type: .error, error)
            print("❌ Failed to find TISCopyInputSourceList symbol: \(error)")
            
            // Try alternative: check if Carbon framework is loaded correctly
            print("🔍 Carbon handle value: \(handle)")
            os_log("🔍 Carbon handle exists", log: logger, type: .debug)
            
            return nil
        }
        
        print("✅ Found TISCopyInputSourceList symbol at \(funcPtr)")
        os_log("✅ Found TISCopyInputSourceList symbol", log: logger, type: .info)
        
        typealias TISCopyInputSourceListFunc = @convention(c) (CFDictionary?, Bool) -> Unmanaged<CFArray>?
        return unsafeBitCast(funcPtr, to: TISCopyInputSourceListFunc.self)
    }
    
    /// Gets TISCopyCurrentKeyboardInputSource function
    private func getTISCopyCurrentKeyboardInputSource() -> (() -> Unmanaged<TISInputSource>?)? {
        guard let handle = carbonHandle else { return nil }
        guard let funcPtr = dlsym(handle, "TISCopyCurrentKeyboardInputSource") else { return nil }
        typealias TISCopyCurrentKeyboardInputSourceFunc = @convention(c) () -> Unmanaged<TISInputSource>?
        return unsafeBitCast(funcPtr, to: TISCopyCurrentKeyboardInputSourceFunc.self)
    }
    
    /// Gets TISGetInputSourceProperty function
    private func getTISGetInputSourceProperty() -> ((TISInputSource, CFString) -> UnsafeMutableRawPointer?)? {
        guard let handle = carbonHandle else { return nil }
        guard let funcPtr = dlsym(handle, "TISGetInputSourceProperty") else { return nil }
        typealias TISGetInputSourcePropertyFunc = @convention(c) (TISInputSource, CFString) -> UnsafeMutableRawPointer?
        return unsafeBitCast(funcPtr, to: TISGetInputSourcePropertyFunc.self)
    }
    
    /// Gets TISSelectInputSource function
    private func getTISSelectInputSource() -> ((TISInputSource) -> OSStatus)? {
        guard let handle = carbonHandle else { return nil }
        guard let funcPtr = dlsym(handle, "TISSelectInputSource") else { return nil }
        typealias TISSelectInputSourceFunc = @convention(c) (TISInputSource) -> OSStatus
        return unsafeBitCast(funcPtr, to: TISSelectInputSourceFunc.self)
    }
    
    // Wrapper function to use TISGetInputSourceProperty (avoiding name conflict)
    private func getInputSourcePropertyWrapper(_ source: TISInputSource, _ key: CFString) -> UnsafeMutableRawPointer? {
        guard let getPropertyFunc = getTISGetInputSourceProperty() else { return nil }
        return getPropertyFunc(source, key)
    }
    
    /// Gets list of all active keyboard layouts
    func getActiveLayouts() -> [KeyboardLayout] {
        os_log("Getting active layouts...", log: logger, type: .info)
        print("🔍 Getting active layouts...")
        var layouts: [KeyboardLayout] = []
        
        guard let copyFunc = getTISCopyInputSourceList() else {
            os_log("❌ Failed to load TISCopyInputSourceList", log: logger, type: .error)
            print("❌ Failed to load TISCopyInputSourceList")
            return []
        }
        
        // Get all layouts (without filter)
        let filter: CFDictionary? = nil
        os_log("🔍 Calling TISCopyInputSourceList with filter=nil, includeAllInstalled=true", log: logger, type: .info)
        print("🔍 Calling TISCopyInputSourceList...")
        
        guard let inputSourceListUnmanaged = copyFunc(filter, true) else {
            os_log("❌ TISCopyInputSourceList returned nil", log: logger, type: .error)
            print("❌ TISCopyInputSourceList returned nil")
            return []
        }
        
        let inputSourceList = inputSourceListUnmanaged.takeRetainedValue()
        os_log("✅ Got input source list from TISCopyInputSourceList", log: logger, type: .info)
        print("✅ Got input source list")
        
        let list = inputSourceList
        
        let count = CFArrayGetCount(list)
        let keyboardCategory = kTISCategoryKeyboardInputSource as String
        os_log("📋 Found %d total input sources", log: logger, type: .info, count)
        os_log("🔍 Looking for keyboard layouts (category: '%{public}@')...", log: logger, type: .info, keyboardCategory)
        print("📋 Found \(count) input sources total")
        print("🔍 Looking for keyboard layouts (category: '\(keyboardCategory)')...")
        
        for i in 0..<count {
            let value = CFArrayGetValueAtIndex(list, i)
            let source = Unmanaged<TISInputSource>.fromOpaque(value!).takeUnretainedValue()
            
            // Get category
            var category: String? = nil
            if let categoryUnmanaged = getInputSourcePropertyWrapper(source, kTISPropertyInputSourceCategory) {
                category = Unmanaged<CFString>.fromOpaque(categoryUnmanaged).takeUnretainedValue() as String
                os_log("  Source %d: category = %{public}@", log: logger, type: .debug, i, category ?? "nil")
                print("  Source \(i): category = \(category ?? "nil")")
            }
            
            // Get ID for diagnostics
            var sourceID: String? = nil
            if let idUnmanaged = getInputSourcePropertyWrapper(source, kTISPropertyInputSourceID) {
                sourceID = Unmanaged<CFString>.fromOpaque(idUnmanaged).takeUnretainedValue() as String
                os_log("  Source %d: ID = %{public}@", log: logger, type: .debug, i, sourceID ?? "nil")
                print("  Source \(i): ID = \(sourceID ?? "nil")")
            }
            
            // Get name for diagnostics
            var sourceName: String? = nil
            if let nameUnmanaged = getInputSourcePropertyWrapper(source, kTISPropertyLocalizedName) {
                sourceName = Unmanaged<CFString>.fromOpaque(nameUnmanaged).takeUnretainedValue() as String
                os_log("  Source %d: name = %{public}@", log: logger, type: .debug, i, sourceName ?? "nil")
                print("  Source \(i): name = \(sourceName ?? "nil")")
            }
            
            // Check if this is a keyboard layout
            let keyboardCategory = kTISCategoryKeyboardInputSource as String
            let isKeyboardLayout = category == keyboardCategory
            os_log("  🔍 Source %d: category='%{public}@', expected='%{public}@', match=%{public}@", log: logger, type: .debug, i, category ?? "nil", keyboardCategory, String(isKeyboardLayout))
            
            // Also check if this is not an IME or other input type
            var isSelectable: Bool = false
            if let selectableUnmanaged = getInputSourcePropertyWrapper(source, kTISPropertyInputSourceIsSelectCapable) {
                let cfBool = Unmanaged<CFBoolean>.fromOpaque(selectableUnmanaged).takeUnretainedValue()
                isSelectable = CFBooleanGetValue(cfBool)
            }
            
            os_log("  Source %d: isKeyboardLayout=%{public}@, isSelectable=%{public}@", log: logger, type: .debug, i, String(isKeyboardLayout), String(isSelectable))
            print("  Source \(i): isKeyboardLayout=\(isKeyboardLayout), isSelectable=\(isSelectable)")
            
            // Add layout if it's a keyboard layout and selectable
            if isKeyboardLayout && isSelectable {
                if let layout = KeyboardLayout(source: source, getPropertyFunc: getInputSourcePropertyWrapper) {
                    os_log("  ✅ Added layout: %{public}@ (%{public}@)", log: logger, type: .info, layout.name, layout.id)
                    print("  ✅ Added layout: \(layout.name) (\(layout.id))")
                    layouts.append(layout)
                } else {
                    os_log("  ❌ Failed to create layout from source %d", log: logger, type: .error, i)
                    print("  ❌ Failed to create layout from source \(i)")
                }
            } else {
                os_log("  ⏭️  Skipped source %d (isKeyboardLayout=%{public}@, isSelectable=%{public}@)", log: logger, type: .debug, i, String(isKeyboardLayout), String(isSelectable))
                print("  ⏭️  Skipped source \(i) (isKeyboardLayout=\(isKeyboardLayout), isSelectable=\(isSelectable))")
            }
        }
        
        os_log("🎯 Total keyboard layouts found: %d", log: logger, type: .info, layouts.count)
        print("🎯 Total keyboard layouts found: \(layouts.count)")
        if layouts.isEmpty {
            os_log("⚠️ No keyboard layouts found! Check System Settings → Keyboard → Input Sources", log: logger, type: .error)
            print("⚠️ No keyboard layouts found! Check System Settings → Keyboard → Input Sources")
        }
        return layouts
    }
    
    /// Gets current active layout
    func getCurrentLayout() -> KeyboardLayout? {
        os_log("🔍 Getting current keyboard layout...", log: logger, type: .info)
        print("🔍 Getting current keyboard layout...")
        
        guard let copyCurrentFunc = getTISCopyCurrentKeyboardInputSource() else {
            os_log("❌ Failed to load TISCopyCurrentKeyboardInputSource", log: logger, type: .error)
            print("❌ Failed to load TISCopyCurrentKeyboardInputSource")
            return nil
        }
        
        guard let currentSourceUnmanaged = copyCurrentFunc() else {
            os_log("❌ TISCopyCurrentKeyboardInputSource returned nil", log: logger, type: .error)
            print("❌ TISCopyCurrentKeyboardInputSource returned nil")
            return nil
        }
        
        let currentSource = currentSourceUnmanaged.takeRetainedValue()
        os_log("✅ Got current source from TISCopyCurrentKeyboardInputSource", log: logger, type: .info)
        print("✅ Got current source")
        
        guard let layout = KeyboardLayout(source: currentSource, getPropertyFunc: getInputSourcePropertyWrapper) else {
            os_log("❌ Failed to create KeyboardLayout from source", log: logger, type: .error)
            print("❌ Failed to create KeyboardLayout from source")
            return nil
        }
        
        os_log("✅ Current layout: %{public}@ (%{public}@)", log: logger, type: .info, layout.name, layout.id)
        print("✅ Current layout: \(layout.name) (\(layout.id))")
        return layout
    }
    
    /// Determines next layout for switching
    func getNextLayout() -> KeyboardLayout? {
        let layouts = getActiveLayouts()
        guard !layouts.isEmpty else { return nil }
        
        guard let current = getCurrentLayout() else {
            // If we can't determine current, return first one
            return layouts.first
        }
        
        // Find index of current layout
        guard let currentIndex = layouts.firstIndex(where: { $0.id == current.id }) else {
            return layouts.first
        }
        
        // If only one layout
        if layouts.count == 1 {
            return nil
        }
        
        // If two layouts - switch to opposite
        if layouts.count == 2 {
            return layouts[1 - currentIndex]
        }
        
        // If more than two - switch to next in cycle
        let nextIndex = (currentIndex + 1) % layouts.count
        return layouts[nextIndex]
    }
    
    /// Switches to specified layout
    func switchToLayout(_ layout: KeyboardLayout) -> Bool {
        guard let selectFunc = getTISSelectInputSource() else {
            return false
        }
        let status = selectFunc(layout.source)
        return status == noErr
    }
    
    /// Switches to next layout
    @discardableResult
    func switchToNextLayout() -> Bool {
        guard let nextLayout = getNextLayout() else { return false }
        return switchToLayout(nextLayout)
    }
}

