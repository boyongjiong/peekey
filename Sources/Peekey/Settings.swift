import AppKit
import Carbon.HIToolbox
import Combine

enum DisplayMode: String, CaseIterable, Identifiable {
    case menuBar, dock, both, hidden
    var id: String { rawValue }

    var title: String {
        switch self {
        case .menuBar: return L("Menu bar", "菜单栏")
        case .dock: return "Dock"
        case .both: return L("Menu bar and Dock", "菜单栏和 Dock")
        case .hidden: return L("Neither (hotkey only)", "都不显示（仅快捷键唤醒）")
        }
    }

    var showsDock: Bool { self == .dock || self == .both }
    var showsMenuBar: Bool { self == .menuBar || self == .both }
}

struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    /// Carbon modifier mask (cmdKey | optionKey | controlKey | shiftKey).
    var modifiers: UInt32
    var key: String

    static let `default` = HotKeyCombo(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | optionKey), key: "2")

    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + key
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    static func keyName(for event: NSEvent) -> String {
        let special: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = special[Int(event.keyCode)] { return name }
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }
}

/// User preferences backed by UserDefaults. Secrets never go here.
final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var language: AppLanguage {
        didSet {
            AppLanguage.current = language
            defaults.set(language.rawValue, forKey: "language")
        }
    }
    @Published var displayMode: DisplayMode { didSet { defaults.set(displayMode.rawValue, forKey: "displayMode") } }
    @Published var hotKey: HotKeyCombo? {
        didSet {
            if let hotKey, let data = try? JSONEncoder().encode(hotKey) {
                defaults.set(data, forKey: "hotKey")
            } else {
                defaults.set(Data(), forKey: "hotKey") // empty = explicitly cleared
            }
        }
    }
    @Published var hideAfterCopy: Bool { didSet { defaults.set(hideAfterCopy, forKey: "hideAfterCopy") } }
    @Published var hideOnDeactivate: Bool { didSet { defaults.set(hideOnDeactivate, forKey: "hideOnDeactivate") } }
    @Published var alwaysOnTop: Bool { didSet { defaults.set(alwaysOnTop, forKey: "alwaysOnTop") } }
    @Published var clearClipboard: Bool { didSet { defaults.set(clearClipboard, forKey: "clearClipboard") } }
    @Published var clearClipboardSeconds: Int { didSet { defaults.set(clearClipboardSeconds, forKey: "clearClipboardSeconds") } }

    init() {
        defaults.register(defaults: [
            "language": AppLanguage.english.rawValue,
            "displayMode": DisplayMode.menuBar.rawValue,
            "hideAfterCopy": true,
            "hideOnDeactivate": true,
            "alwaysOnTop": false,
            "clearClipboard": true,
            "clearClipboardSeconds": 60,
        ])
        let lang = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .english
        AppLanguage.current = lang
        language = lang
        displayMode = DisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .menuBar
        if let data = defaults.data(forKey: "hotKey") {
            hotKey = data.isEmpty ? nil : (try? JSONDecoder().decode(HotKeyCombo.self, from: data))
        } else {
            hotKey = .default
        }
        hideAfterCopy = defaults.bool(forKey: "hideAfterCopy")
        hideOnDeactivate = defaults.bool(forKey: "hideOnDeactivate")
        alwaysOnTop = defaults.bool(forKey: "alwaysOnTop")
        clearClipboard = defaults.bool(forKey: "clearClipboard")
        clearClipboardSeconds = defaults.integer(forKey: "clearClipboardSeconds")
    }
}
