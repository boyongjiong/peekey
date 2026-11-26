import AppKit
import Carbon.HIToolbox
import SwiftUI

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel
    private var keyMonitor: Any?
    private var hasBeenShown = false

    init(model: AppModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Peekey"
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 320, height: 360)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: LocalizedRoot { MainView() }
                .environmentObject(model)
                .environmentObject(model.store)
                .environmentObject(model.settings)
        )
        window.setFrameAutosaveName("PeekeyMainWindow")

        let controls = NSHostingView(rootView: LocalizedRoot { TitlebarControls() }.environmentObject(model).environmentObject(model.settings))
        controls.frame = NSRect(origin: .zero, size: controls.fittingSize)
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = controls
        accessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(accessory)
        super.init(window: window)
        window.delegate = self
        installKeyMonitor()
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification, object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var isFrontmost: Bool {
        guard let window else { return false }
        return window.isVisible && NSApp.isActive && window.occlusionState.contains(.visible)
    }

    func applyAlwaysOnTop(_ onTop: Bool) {
        window?.level = onTop ? .floating : .normal
    }

    /// Show if hidden / behind, hide if frontmost.
    func toggle(anchor: NSRect? = nil) {
        if isFrontmost && model.sheet == nil {
            hide()
        } else {
            show(anchor: anchor)
        }
    }

    /// - Parameter anchor: screen rect of the menu bar icon, to drop the window right below it.
    func show(anchor: NSRect? = nil) {
        guard let window else { return }
        if let anchor {
            position(below: anchor)
        } else if !hasBeenShown, !window.setFrameUsingName("PeekeyMainWindow") {
            centerOnMouseScreen()
        }
        hasBeenShown = true
        if !window.isVisible { model.search = "" }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        model.focusToken += 1
    }

    /// - Parameter deactivate: also give focus back to the previously active app.
    func hide(deactivate: Bool = true) {
        guard let window, window.isVisible else { return }
        window.orderOut(nil)
        let othersVisible = NSApp.windows.contains { $0 !== window && $0.isVisible && $0.styleMask.contains(.titled) }
        if deactivate && !othersVisible && NSApp.isActive { NSApp.hide(nil) }
    }

    private func position(below anchor: NSRect) {
        guard let window else { return }
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var frame = window.frame
        frame.origin.x = anchor.midX - frame.width / 2
        frame.origin.y = anchor.minY - frame.height - 6
        frame.origin.x = min(max(frame.origin.x, visible.minX + 8), visible.maxX - frame.width - 8)
        frame.origin.y = max(frame.origin.y, visible.minY + 8)
        window.setFrame(frame, display: false)
    }

    private func centerOnMouseScreen() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return window.center() }
        var frame = window.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2 + visible.height * 0.08
        window.setFrame(frame, display: false)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    @objc private func appDidResignActive() {
        guard model.settings.hideOnDeactivate, !model.suppressAutoHide, model.sheet == nil else { return }
        window?.orderOut(nil)
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, NSApp.keyWindow === window, self.model.sheet == nil else { return event }
            let mods = event.modifierFlags.intersection([.command, .option, .control])
            guard mods.isEmpty else { return event }
            switch Int(event.keyCode) {
            case kVK_Escape:
                if self.model.search.isEmpty { self.hide() } else { self.model.search = "" }
                return nil
            case kVK_DownArrow:
                self.model.moveSelection(1)
                return nil
            case kVK_UpArrow:
                self.model.moveSelection(-1)
                return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                self.model.copySelected()
                return nil
            default:
                return event
            }
        }
    }
}
