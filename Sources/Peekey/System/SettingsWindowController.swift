import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(model: AppModel) {
        let hosting = NSHostingController(
            rootView: LocalizedRoot { SettingsView() }
                .environmentObject(model)
                .environmentObject(model.settings)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = L("Peekey Settings", "Peekey 设置")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func applyLanguage() {
        window?.title = L("Peekey Settings", "Peekey 设置")
    }

    func show() {
        guard let window else { return }
        if !window.isVisible { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
