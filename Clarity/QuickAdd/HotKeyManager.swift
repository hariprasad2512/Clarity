import AppKit
import Carbon

/// Global hotkey: Cmd+Shift+T toggles the Spotlight-style quick-add bar.
/// Uses Carbon RegisterEventHotKey (zero dependencies, no Accessibility
/// permission prompt, sandbox-safe) instead of CGEventTap.
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onToggle: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var isRegistered = false

    private init() {}

    /// keyCode 17 = "T". modifiers = cmdKey | shiftKey.
    func register() {
        guard !isRegistered else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.onToggle?() }
            return noErr
        }
        // Retain the UPP for the app lifetime (leak is intentional, one-time).
        let upp = handler as EventHandlerUPP
        InstallEventHandler(
            GetApplicationEventTarget(),
            upp,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        var ref: EventHotKeyRef?
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let status = RegisterEventHotKey(
            17, // kVK_ANSI_T
            modifiers,
            EventHotKeyID(signature: OSType(0x434C5254), id: 1), // 'CLRT'
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
            isRegistered = true
            print("HotKeyManager: registered Cmd+Shift+T")
        } else {
            print("HotKeyManager: RegisterEventHotKey failed: \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
        isRegistered = false
    }
}
