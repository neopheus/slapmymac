import Carbon
import Foundation

/// Registers a system-wide keyboard shortcut using Carbon's RegisterEventHotKey.
/// Supports re-registration with a new key/modifier combination.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private static var callback: (() -> Void)?
    private var handlerInstalled = false

    func register(
        keyCode: UInt32 = 1,
        modifiers: UInt32 = UInt32(cmdKey | shiftKey),
        action: @escaping () -> Void
    ) {
        // Unregister previous hotkey if any
        unregister()

        Self.callback = action

        if !handlerInstalled {
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
            handlerInstalled = true
        }

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
            print("[SlapMyMac] Global hotkey registered: keyCode=\(keyCode) modifiers=\(modifiers)")
        } else {
            print("[SlapMyMac] Failed to register global hotkey: \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit {
        unregister()
        Self.callback = nil
    }
}
