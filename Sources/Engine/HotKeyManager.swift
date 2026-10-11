import Foundation
import Carbon

public final class HotKeyManager: ObservableObject {
    public static let shared = HotKeyManager()

    @Published public private(set) var currentConfig: HotKeyConfiguration
    @Published public private(set) var registrationError: String? = nil

    public var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeySignature: OSType = 0x4155544F // 'AUTO'
    private let hotKeyId: UInt32 = 1

    private static weak var activeManager: HotKeyManager?

    private static let carbonCallback: EventHandlerUPP = { (_, inEvent, _) -> OSStatus in
        guard let inEvent = inEvent else { return noErr }
        var hkID = EventHotKeyID()
        let status = GetEventParameter(
            inEvent,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hkID
        )
        if status == noErr, hkID.signature == 0x4155544F {
            DispatchQueue.main.async {
                HotKeyManager.activeManager?.onTrigger?()
            }
        }
        return noErr
    }

    private init() {
        let loaded = PreferencesManager.shared.loadHotKeyConfiguration()
        self.currentConfig = loaded
        HotKeyManager.activeManager = self
        installCarbonHandler()
        _ = register(config: loaded)
    }

    private func installCarbonHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            HotKeyManager.carbonCallback,
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )
    }

    @discardableResult
    public func register(config: HotKeyConfiguration) -> Bool {
        unregister()

        self.currentConfig = config
        PreferencesManager.shared.saveHotKeyConfiguration(config)

        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: hotKeySignature, id: hotKeyId)

        let status = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            self.hotKeyRef = ref
            DispatchQueue.main.async {
                self.registrationError = nil
            }
            return true
        } else {
            let errorMsg: String
            if status == OSStatus(eventHotKeyExistsErr) {
                errorMsg = "Shortcut conflict: \(config.displayString) is in use by another app."
            } else {
                errorMsg = "Failed to register shortcut \(config.displayString) (Status: \(status))."
            }
            DispatchQueue.main.async {
                self.registrationError = errorMsg
            }
            return false
        }
    }

    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit {
        unregister()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
    }
}
