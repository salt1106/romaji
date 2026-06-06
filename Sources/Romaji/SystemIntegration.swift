import AppKit
import Carbon
import CoreGraphics

struct FocusTarget {
    let element: AXUIElement
    let clickPoint: CGPoint?
}

@MainActor
final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(shortcut: AppShortcut, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.action() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )

        let identifier = EventHotKeyID(signature: OSType(0x524F4D41), id: 1)
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }

    func stop() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
    }
}

@MainActor
enum TextInserter {
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func focusTarget() -> FocusTarget? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        let element = value as! AXUIElement
        return FocusTarget(element: element, clickPoint: center(of: element))
    }

    static func insert(
        _ text: String,
        into app: NSRunningApplication?,
        focusTarget: FocusTarget?
    ) {
        let pasteboard = NSPasteboard.general
        guard hasAccessibilityPermission else {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            app?.activate(options: .activateAllWindows)
            return
        }

        let previousItems = pasteboard.pasteboardItems?.compactMap { item -> [String: Data]? in
            var values: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    values[type.rawValue] = data
                }
            }
            return values
        }
        pendingPasteboardItems = previousItems

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        app?.activate(options: .activateAllWindows)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if let focusTarget {
                AXUIElementSetAttributeValue(
                    focusTarget.element,
                    kAXFocusedAttribute as CFString,
                    kCFBooleanTrue
                )
                if let clickPoint = focusTarget.clickPoint {
                    click(at: clickPoint)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                sendPaste(to: app?.processIdentifier)
            }
        }
    }

    private static func center(of element: AXUIElement) -> CGPoint? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
              AXUIElementCopyAttributeValue(
                element,
                kAXSizeAttribute as CFString,
                &sizeValue
              ) == .success,
              let positionValue,
              let sizeValue else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
    }

    private static func click(at point: CGPoint) {
        let source = CGEventSource(stateID: .combinedSessionState)
        CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)
        CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)
    }

    private static func sendPaste(to processIdentifier: pid_t?) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        if let processIdentifier {
            down?.postToPid(processIdentifier)
            up?.postToPid(processIdentifier)
        } else {
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            restorePendingPasteboard()
        }
    }

    private static var pendingPasteboardItems: [[String: Data]]?

    private static func restorePendingPasteboard() {
        let pasteboard = NSPasteboard.general
        let items = pendingPasteboardItems
        pendingPasteboardItems = nil
        guard let items else { return }
        let restored = items.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.clearContents()
        pasteboard.writeObjects(restored)
    }
}
