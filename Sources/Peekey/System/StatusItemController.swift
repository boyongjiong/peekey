import AppKit

final class StatusItemController: NSObject {
    private var item: NSStatusItem?
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    func setVisible(_ visible: Bool) {
        if visible, item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = item.button {
                let image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "Peekey")
                image?.isTemplate = true
                button.image = image
                button.target = self
                button.action = #selector(clicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.toolTip = "Peekey"
            }
            self.item = item
        } else if !visible, let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    var anchorRect: NSRect? { item?.button?.window?.frame }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            model.mainWindow?.toggle(anchor: anchorRect)
        }
    }

    private func showMenu() {
        guard let item else { return }
        let menu = NSMenu()
        let open = NSMenuItem(title: L("Open Peekey", "打开 Peekey"), action: #selector(openMain), keyEquivalent: "")
        if let hk = model.settings.hotKey { open.title = L("Open Peekey    \(hk.display)", "打开 Peekey    \(hk.display)") }
        open.target = self
        menu.addItem(open)
        let scan = NSMenuItem(title: L("Scan QR Code on Screen", "扫描屏幕二维码"), action: #selector(scan), keyEquivalent: "")
        scan.target = self
        menu.addItem(scan)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: L("Settings…", "设置…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: L("Quit Peekey", "退出 Peekey"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil // restore left-click behavior
    }

    @objc private func openMain() { model.mainWindow?.show(anchor: anchorRect) }
    @objc private func scan() { model.scanScreen() }
    @objc private func openSettings() { model.openSettings() }
}
