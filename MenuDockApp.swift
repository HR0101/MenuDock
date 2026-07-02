//
//  MenuDockApp.swift
//  MenuDock
//

import SwiftUI
import SwiftData
import Cocoa
import Carbon
import Combine

@main
struct MenuDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ShortcutApp.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        Window("MenuDockについて", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    
    var statusItem: NSStatusItem!
    var panel: NSPanel!
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "MenuDock")
            button.action = #selector(togglePanel(_:))
        }
        
        let contentView = ContentView()
            .modelContainer(MenuDockApp.sharedModelContainer)
        
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
                        styleMask: [.nonactivatingPanel, .borderless],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.contentViewController = NSHostingController(rootView: contentView)
        
        // Hide panel when clicking outside
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if self?.panel.isVisible == true {
                self?.panel.orderOut(nil)
            }
        }
        // Allow Escape key to close the panel
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.panel.orderOut(nil)
                return nil
            }
            return event
        }
        
        GlobalHotkeyManager.shared.action = { [weak self] in
            self?.togglePanel(nil)
        }
    }
    
    func updatePanelSize(_ size: CGSize) {
        let oldFrame = panel.frame
        let newHeight = size.height
        let newY = oldFrame.maxY - newHeight
        let newFrame = NSRect(x: oldFrame.minX, y: newY, width: size.width, height: newHeight)
        // Only set frame if it actually changed to prevent jitter
        if oldFrame.size != newFrame.size {
            panel.setFrame(newFrame, display: true, animate: true)
        }
    }
    
    @objc func togglePanel(_ sender: Any?) {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            if let button = statusItem.button, let window = button.window {
                let frame = window.convertToScreen(button.frame)
                let x = frame.midX - panel.frame.width / 2
                let y = frame.minY - panel.frame.height - 8
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()
    
    @Published var keyCode: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(keyCode), forKey: "customHotkey_keyCode")
            updateRegistration()
        }
    }
    
    @Published var modifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(Int(modifiers), forKey: "customHotkey_modifiers")
            updateRegistration()
        }
    }
    
    private var eventHotKeyRef: EventHotKeyRef?
    var action: (() -> Void)?
    
    init() {
        self.keyCode = UInt16(UserDefaults.standard.integer(forKey: "customHotkey_keyCode"))
        self.modifiers = UInt32(UserDefaults.standard.integer(forKey: "customHotkey_modifiers"))
        setupEventHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.updateRegistration()
        }
    }
    
    func setCustomHotkey(keyCode: UInt16, cocoaModifiers: NSEvent.ModifierFlags) {
        var carbonFlags: UInt32 = 0
        if cocoaModifiers.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if cocoaModifiers.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if cocoaModifiers.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if cocoaModifiers.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        
        self.keyCode = keyCode
        self.modifiers = carbonFlags
    }
    
    var shortcutString: String {
        if keyCode == 0 { return "未設定" }
        var str = ""
        if modifiers & UInt32(controlKey) != 0 { str += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { str += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { str += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { str += "⌘" }
        
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
            46: "M", 47: ".", 49: "Space", 50: "`", 51: "Delete", 53: "Esc"
        ]
        
        if let char = keyMap[keyCode] {
            str += char
        } else {
            str += "Key \(keyCode)"
        }
        return str
    }
    
    func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let ptr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.action?()
            }
            return noErr
        }, 1, &eventType, ptr, nil)
    }
    
    func updateRegistration() {
        if let currentRef = eventHotKeyRef {
            UnregisterEventHotKey(currentRef)
            eventHotKeyRef = nil
        }
        
        guard keyCode != 0 else { return }
        
        var hotKeyId = EventHotKeyID()
        hotKeyId.signature = OSType(FourCharCode("MDCK").rawValue)
        hotKeyId.id = 1
        
        RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyId, GetApplicationEventTarget(), 0, &eventHotKeyRef)
    }
}

extension FourCharCode {
    init(_ string: String) {
        var code: FourCharCode = 0
        for char in string.utf16 {
            code = (code << 8) + FourCharCode(char)
        }
        self = code
    }
    var rawValue: UInt32 { return self }
}
