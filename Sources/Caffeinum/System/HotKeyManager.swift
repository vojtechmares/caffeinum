import AppKit
import Carbon

/// A system-wide shortcut, stored as the Carbon key code and modifier mask that
/// `RegisterEventHotKey` wants.
struct HotKeyCombo: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_C),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey)
    )

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        var modifiers: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        carbonModifiers = modifiers
    }

    /// Shift alone is not enough to make a shortcut global-safe.
    var isValid: Bool {
        carbonModifiers & UInt32(controlKey | optionKey | cmdKey) != 0
    }

    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result + Self.name(for: keyCode)
    }

    private static func name(for keyCode: UInt32) -> String {
        if let named = specialKeyNames[Int(keyCode)] { return named }
        return characterKeyNames[Int(keyCode)] ?? "Key \(keyCode)"
    }

    private static let characterKeyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
        34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/", 47: ".", 50: "`",
    ]

    private static let specialKeyNames: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦",
        115: "↖", 116: "⇞", 119: "↘", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}

/// Registers a single global hot key through Carbon, which - unlike an event tap -
/// needs no Accessibility permission.
final class HotKeyManager {

    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?
    private var registered: HotKeyCombo?

    private init() {}

    /// Registers `combo`, replacing any previous one. No-op if it is already active.
    @discardableResult
    func register(_ combo: HotKeyCombo, action: @escaping () -> Void) -> Bool {
        guard combo.isValid else { return false }
        self.action = action

        if registered == combo, hotKeyRef != nil { return true }
        unregister()

        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4341_4646), id: 1) // 'CAFF'
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else {
            NSLog("Caffeinum: could not register hot key (status \(status))")
            return false
        }
        hotKeyRef = reference
        registered = combo
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        registered = nil
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.fire()
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func fire() {
        let action = self.action
        DispatchQueue.main.async { action?() }
    }
}
