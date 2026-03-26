import Carbon
import Foundation

/// Registers a system-wide keyboard shortcut using Carbon's RegisterEventHotKey.
/// Default: Cmd+Shift+S (key code 1) to toggle slap detection from any app.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private static var callback: (() -> Void)?

    func register(
        keyCode: UInt32 = 1,  // 'S'
        modifiers: UInt32 = UInt32(cmdKey | shiftKey),
        action: @escaping () -> Void
    ) {
        Self.callback = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                GlobalHotKey.callback?()
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x534C4150),  // "SLAP"
            id: 1
        )

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            print("[SlapMyMac] Global hotkey registered: Cmd+Shift+S")
        } else {
            print("[SlapMyMac] Failed to register global hotkey: \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        Self.callback = nil
    }

    deinit {
        unregister()
    }
}
