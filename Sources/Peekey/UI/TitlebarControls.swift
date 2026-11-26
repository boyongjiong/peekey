import SwiftUI

/// Lives in the window's titlebar (trailing side, opposite the traffic lights).
/// `+` is always visible; the settings gear only appears while the pointer is over the window.
struct TitlebarControls: View {
    @EnvironmentObject private var model: AppModel
    @State private var hoveringSelf = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showGear: Bool { model.pointerInWindow || hoveringSelf }

    var body: some View {
        HStack(spacing: 2) {
            TitlebarIconButton(symbol: "gearshape", label: L("Settings (⌘,)", "设置 (⌘,)")) { model.openSettings() }
                .opacity(showGear ? 1 : 0)
                .allowsHitTesting(showGear)
                .accessibilityHidden(!showGear)

            Menu {
                Button { model.scanScreen() } label: { Label(L("Scan QR Code on Screen", "扫描屏幕二维码"), systemImage: "qrcode.viewfinder") }
                Button { model.importImageFile() } label: { Label(L("Import from Image…", "从图片导入…"), systemImage: "photo") }
                Button { model.startCamera() } label: { Label(L("Scan with Camera", "使用摄像头扫描"), systemImage: "camera") }
                Divider()
                Button { model.addFromClipboard() } label: { Label(L("Add from Clipboard", "从剪贴板添加"), systemImage: "doc.on.clipboard") }
                Button { model.newManual() } label: { Label(L("Enter Manually…", "手动输入…"), systemImage: "keyboard") }
            } label: {
                TitlebarIconLabel(symbol: "plus", emphasized: true)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L("Add Account", "添加账户"))
            .accessibilityLabel(L("Add Account", "添加账户"))
        }
        .padding(.trailing, 10)
        .frame(height: 28)
        .onHover { hoveringSelf = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGear)
    }
}

struct TitlebarIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { TitlebarIconLabel(symbol: symbol) }
            .buttonStyle(.plain)
            .help(label)
            .accessibilityLabel(label)
    }
}

struct TitlebarIconLabel: View {
    let symbol: String
    var emphasized = false
    @State private var hovering = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: emphasized ? .semibold : .regular))
            .foregroundStyle(emphasized ? Color.accentColor : .secondary)
            .frame(width: 28, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0))
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}
