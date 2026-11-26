import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel.shared
    private var mainWindow: MainWindowController!
    private var settingsWindow: SettingsWindowController!
    private var statusItem: StatusItemController!
    private var cancellables = Set<AnyCancellable>()
    private var launchedAsLoginItem = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication,
           event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            launchedAsLoginItem = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindow = MainWindowController(model: model)
        settingsWindow = SettingsWindowController(model: model)
        statusItem = StatusItemController(model: model)
        model.mainWindow = mainWindow
        model.settingsWindow = settingsWindow
        NSApp.mainMenu = buildMainMenu()

        HotKeyManager.shared.onTrigger = { [weak self] in self?.mainWindow.toggle() }

        model.settings.$displayMode
            .removeDuplicates()
            .sink { [weak self] in self?.applyDisplayMode($0) }
            .store(in: &cancellables)
        model.settings.$hotKey
            .removeDuplicates()
            .sink { HotKeyManager.shared.register($0) }
            .store(in: &cancellables)
        model.settings.$alwaysOnTop
            .sink { [weak self] in self?.mainWindow.applyAlwaysOnTop($0) }
            .store(in: &cancellables)

        if !launchedAsLoginItem {
            DispatchQueue.main.async { [self] in
                mainWindow.show(anchor: model.settings.displayMode.showsMenuBar ? statusItem.anchorRect : nil)
                if model.settings.displayMode == .hidden, !model.store.accounts.isEmpty, let hk = model.settings.hotKey {
                    model.showToast("按 \(hk.display) 随时唤醒 Peekey")
                }
            }
        }
    }

    /// Re-opening the app from Finder / Spotlight / Dock always brings the window back —
    /// the safety net for "hidden" mode.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func applyDisplayMode(_ mode: DisplayMode) {
        let wasVisible = mainWindow.window?.isVisible == true || settingsWindow.window?.isVisible == true
        NSApp.setActivationPolicy(mode.showsDock ? .regular : .accessory)
        statusItem.setVisible(mode.showsMenuBar)
        if wasVisible {
            // Changing the activation policy can push our windows behind other apps.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Menu

    private func buildMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Peekey", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(item("设置…", #selector(openSettings), ","))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 Peekey", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出 Peekey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "账户")
        fileMenu.addItem(item("扫描屏幕二维码", #selector(scanScreen), "s", [.command, .shift]))
        fileMenu.addItem(item("从图片导入…", #selector(importImage), "o"))
        fileMenu.addItem(item("使用摄像头扫描", #selector(camera), ""))
        fileMenu.addItem(item("从剪贴板添加", #selector(fromClipboard), "v", [.command, .shift]))
        fileMenu.addItem(item("手动输入…", #selector(manual), "n"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        // Required so ⌘C / ⌘V / ⌘A work inside text fields.
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        return main
    }

    private func item(_ title: String, _ action: Selector, _ key: String, _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = mods
        i.target = self
        return i
    }

    @objc private func openSettings() { model.openSettings() }
    @objc private func scanScreen() { model.scanScreen() }
    @objc private func importImage() { model.importImageFile() }
    @objc private func camera() { model.startCamera() }
    @objc private func fromClipboard() { model.addFromClipboard() }
    @objc private func manual() { model.newManual() }
}
