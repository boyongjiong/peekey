import Carbon.HIToolbox
import Foundation

/// Global hotkey via Carbon `RegisterEventHotKey`. Works while any app is frontmost
/// and does NOT require Accessibility permission.
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x504B_4559 // 'PKEY'

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.onTrigger?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }

    /// Registers the combo (replacing any previous one). Returns false if the system refused it
    /// (typically because another app already owns that shortcut).
    @discardableResult
    func register(_ combo: HotKeyCombo?) -> Bool {
        unregister()
        guard let combo else { return true }
        let id = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }
}
