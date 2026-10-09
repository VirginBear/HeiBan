import AppKit
import Carbon

/// Register only these shortcuts; no keyboard event tap or Input Monitoring grant.
final class ScreenAnnotationHotKeys {
    private var keys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var perform: ((UInt32) -> Void)?

    func register() -> Bool {
        guard handler == nil else { return !keys.isEmpty }
        var specification = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard status == noErr, key.signature == 0x4842494E else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<ScreenAnnotationHotKeys>.fromOpaque(userData).takeUnretainedValue()
            owner.perform?(key.id)
            return noErr
        }, 1, &specification, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else { return false }
        let codes = [kVK_ANSI_D, kVK_ANSI_S, kVK_ANSI_X]
        for (index, code) in codes.enumerated() {
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: 0x4842494E, id: UInt32(index + 1))
            let status = RegisterEventHotKey(UInt32(code), UInt32(cmdKey | optionKey | shiftKey), id,
                                            GetApplicationEventTarget(), 0, &reference)
            guard status == noErr, let reference else {
                keys.forEach { UnregisterEventHotKey($0) }
                keys.removeAll()
                return false
            }
            keys.append(reference)
        }
        return true
    }

    deinit {
        keys.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}
