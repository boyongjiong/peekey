import AppKit
import PeekeyCore
import SwiftUI
import UniformTypeIdentifiers

struct AlertInfo: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var showsScreenRecordingSettings = false
}

/// Central controller shared by all views and AppKit controllers.
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Sheet: Identifiable {
        case form(Account, isNew: Bool)
        case camera
        var id: String {
            switch self {
            case .form(let a, let isNew): return "form-\(a.id)-\(isNew)"
            case .camera: return "camera"
            }
        }
    }

    let settings = Settings()
    let store = AccountStore()

    @Published var search = ""
    @Published var selectedID: UUID?
    @Published var copiedID: UUID?
    @Published var toast: String?
    @Published var sheet: Sheet?
    @Published var alert: AlertInfo?
    @Published var pendingDelete: Account?
    /// Bumped whenever the main window is shown so the search field grabs focus.
    @Published var focusToken = 0

    /// True while the screen-capture UI is up or a modal is running, so we don't auto-hide.
    var suppressAutoHide = false

    weak var mainWindow: MainWindowController?
    weak var settingsWindow: SettingsWindowController?

    private var toastWork: DispatchWorkItem?

    var filtered: [Account] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.accounts }
        return store.accounts.filter { $0.issuer.lowercased().contains(q) || $0.name.lowercased().contains(q) }
    }

    // MARK: - Copy

    func copy(_ account: Account) {
        Clipboard.copy(account.code(), clearAfter: settings.clearClipboard ? settings.clearClipboardSeconds : nil)
        selectedID = account.id
        withAnimation(.easeOut(duration: 0.15)) { copiedID = account.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.copiedID == account.id { withAnimation { self?.copiedID = nil } }
        }
        if settings.hideAfterCopy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in self?.mainWindow?.hide() }
        }
    }

    func copySelected() {
        let list = filtered
        if let id = selectedID, let a = list.first(where: { $0.id == id }) {
            copy(a)
        } else if let first = list.first {
            copy(first)
        }
    }

    func moveSelection(_ delta: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == selectedID } ?? (delta > 0 ? -1 : list.count)
        selectedID = list[min(max(current + delta, 0), list.count - 1)].id
    }

    // MARK: - Toast

    func showToast(_ text: String) {
        toastWork?.cancel()
        withAnimation(.spring(duration: 0.3)) { toast = text }
        let work = DispatchWorkItem { [weak self] in withAnimation { self?.toast = nil } }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }

    // MARK: - Adding accounts

    func newManual() {
        mainWindow?.show()
        sheet = .form(Account(issuer: "", name: "", secret: ""), isNew: true)
    }

    func startCamera() {
        mainWindow?.show()
        sheet = .camera
    }

    func scanScreen() {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            mainWindow?.show()
            alert = AlertInfo(
                title: "需要屏幕录制权限",
                message: "扫描屏幕二维码需要「屏幕录制」权限。请在 系统设置 → 隐私与安全性 → 屏幕与系统录音 中允许 Peekey，然后重新打开 Peekey。",
                showsScreenRecordingSettings: true
            )
            return
        }
        suppressAutoHide = true
        mainWindow?.hide(deactivate: false)
        ScreenQRScanner.scan { [weak self] result in
            guard let self else { return }
            self.suppressAutoHide = false
            self.mainWindow?.show()
            switch result {
            case .cancelled: break
            case .found(let codes): self.handlePayloads(codes)
            case .notFound:
                self.alert = AlertInfo(title: "未识别到二维码", message: "所选区域内没有找到二维码，请把二维码完整框选后重试。")
            case .failed(let msg):
                self.alert = AlertInfo(title: "截图失败", message: msg)
            }
        }
    }

    func importImageFile() {
        mainWindow?.show()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.message = "选择包含 2FA 二维码的图片"
        suppressAutoHide = true
        defer { suppressAutoHide = false }
        guard panel.runModal() == .OK else { return }
        handleImages(panel.urls.compactMap { NSImage(contentsOf: $0) })
    }

    func addFromClipboard() {
        mainWindow?.show()
        let pb = NSPasteboard.general
        if let s = pb.string(forType: .string), s.lowercased().contains("otpauth") {
            handlePayloads(s.components(separatedBy: .whitespacesAndNewlines).filter { $0.lowercased().hasPrefix("otpauth") })
        } else if let images = pb.readObjects(forClasses: [NSImage.self]) as? [NSImage], !images.isEmpty {
            handleImages(images)
        } else {
            alert = AlertInfo(title: "剪贴板中没有可用内容", message: "请先复制 otpauth:// 链接或二维码图片。")
        }
    }

    func handleImages(_ images: [NSImage]) {
        let codes = images.flatMap { QRDecoder.decode(image: $0) }
        guard !codes.isEmpty else {
            alert = AlertInfo(title: "未识别到二维码", message: "图片中没有找到二维码。")
            return
        }
        handlePayloads(codes)
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for p in providers {
            if p.canLoadObject(ofClass: URL.self) {
                handled = true
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, let img = NSImage(contentsOf: url) else { return }
                    DispatchQueue.main.async { self.handleImages([img]) }
                }
            } else if p.canLoadObject(ofClass: NSImage.self) {
                handled = true
                _ = p.loadObject(ofClass: NSImage.self) { img, _ in
                    guard let img = img as? NSImage else { return }
                    DispatchQueue.main.async { self.handleImages([img]) }
                }
            }
        }
        return handled
    }

    func handlePayloads(_ payloads: [String]) {
        var accounts: [Account] = []
        var firstError: Error?
        for p in payloads {
            do { accounts += try OTPAuthURI.parseAny(p) } catch { firstError = firstError ?? error }
        }
        guard !accounts.isEmpty else {
            alert = AlertInfo(title: "无法添加", message: firstError?.localizedDescription ?? "未识别到 2FA 信息")
            return
        }
        if accounts.count == 1 {
            sheet = .form(accounts[0], isNew: true)
        } else {
            let added = store.add(accounts)
            let skipped = accounts.count - added
            showToast(skipped > 0 ? "已导入 \(added) 个账户，跳过 \(skipped) 个重复" : "已导入 \(added) 个账户")
        }
    }

    /// Returns an error message, or nil on success.
    func save(_ account: Account, isNew: Bool) -> String? {
        if isNew {
            if store.add([account]) == 0 { return "该账户已存在" }
            selectedID = account.id
            showToast("已添加 \(account.displayTitle)")
        } else {
            store.update(account)
        }
        sheet = nil
        return nil
    }

    func edit(_ account: Account) { sheet = .form(account, isNew: false) }

    func setColor(_ key: String?, for account: Account) {
        var a = account
        a.color = key
        store.update(a)
    }

    func copyLink(_ account: Account) {
        Clipboard.copy(OTPAuthURI.build(account), clearAfter: 60)
        showToast("已复制 otpauth 链接（60 秒后清除）")
    }

    func confirmDelete() {
        guard let a = pendingDelete else { return }
        store.delete(a.id)
        pendingDelete = nil
        showToast("已删除 \(a.displayTitle)")
    }

    // MARK: - Windows

    func openSettings() { settingsWindow?.show() }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
