import PeekeyCore
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: AccountStore
    @FocusState private var searchFocused: Bool
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 10)
            content
        }
        .frame(minWidth: 320, minHeight: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { toast }
        .overlay { dropOverlay }
        .onDrop(of: [.fileURL, .image], isTargeted: $dropTargeted) { model.handleDrop($0) }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .form(let account, let isNew):
                AccountForm(draft: account, isNew: isNew)
                    .environmentObject(model)
            case .camera:
                CameraScanView()
                    .environmentObject(model)
            }
        }
        .alert(item: $model.alert) { info in
            if info.showsScreenRecordingSettings {
                return Alert(
                    title: Text(info.title), message: Text(info.message),
                    primaryButton: .default(Text("打开系统设置")) { model.openScreenRecordingSettings() },
                    secondaryButton: .cancel(Text("稍后"))
                )
            }
            return Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text("好")))
        }
        .confirmationDialog(
            "删除 \(model.pendingDelete?.displayTitle ?? "")？",
            isPresented: Binding(get: { model.pendingDelete != nil }, set: { if !$0 { model.pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) { model.confirmDelete() }
            Button("取消", role: .cancel) { model.pendingDelete = nil }
        } message: {
            Text("删除后将无法再生成该账户的验证码。请确认你已在对应网站关闭两步验证或有其他备份。")
        }
        .onChange(of: model.focusToken) { searchFocused = true }
        .onChange(of: model.search) { model.selectedID = nil }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索", text: $model.search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !model.search.isEmpty {
                    Button { model.search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 14))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1))
            )

            Menu {
                Button { model.scanScreen() } label: { Label("扫描屏幕二维码", systemImage: "qrcode.viewfinder") }
                Button { model.importImageFile() } label: { Label("从图片导入…", systemImage: "photo") }
                Button { model.startCamera() } label: { Label("使用摄像头扫描", systemImage: "camera") }
                Divider()
                Button { model.addFromClipboard() } label: { Label("从剪贴板添加（链接/图片）", systemImage: "doc.on.clipboard") }
                Button { model.newManual() } label: { Label("手动输入…", systemImage: "keyboard") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("添加账户")

            Button { model.openSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 30)
            }
            .buttonStyle(.plain)
            .help("设置")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let error = store.loadError, store.accounts.isEmpty {
            placeholder(icon: "exclamationmark.lock", title: "无法读取钥匙串", detail: error) {
                Button("重试") { store.load() }
            }
        } else if store.accounts.isEmpty {
            placeholder(icon: "key.viewfinder", title: "还没有账户", detail: "扫描网页上的 2FA 二维码，或手动输入密钥") {
                VStack(spacing: 8) {
                    Button { model.scanScreen() } label: {
                        Label("扫描屏幕二维码", systemImage: "qrcode.viewfinder").frame(width: 160)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { model.newManual() } label: { Text("手动添加").frame(width: 160) }
                }
                .controlSize(.large)
            }
        } else if model.filtered.isEmpty {
            placeholder(icon: "magnifyingglass", title: "没有匹配“\(model.search)”的账户", detail: nil) { EmptyView() }
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    LazyVStack(spacing: 14) {
                        ForEach(model.filtered) { account in
                            AccountCard(
                                account: account,
                                date: ctx.date,
                                isSelected: model.selectedID == account.id,
                                isCopied: model.copiedID == account.id
                            )
                            .id(account.id)
                            .onTapGesture { model.copy(account) }
                            .contextMenu { contextMenu(for: account) }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.never)
            .onChange(of: model.selectedID) { _, id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for account: Account) -> some View {
        Button("复制验证码") { model.copy(account) }
        Button("编辑…") { model.edit(account) }
        Menu("颜色") {
            Button("自动") { model.setColor(nil, for: account) }
            Divider()
            ForEach(Palette.all) { p in
                Button(p.name) { model.setColor(p.key, for: account) }
            }
        }
        Divider()
        Button("上移") { model.store.move(account.id, by: -1) }
            .disabled(model.store.accounts.first?.id == account.id)
        Button("下移") { model.store.move(account.id, by: 1) }
            .disabled(model.store.accounts.last?.id == account.id)
        Divider()
        Button("复制 otpauth 链接（含密钥）") { model.copyLink(account) }
        Divider()
        Button("删除…", role: .destructive) { model.pendingDelete = account }
    }

    private func placeholder<Actions: View>(icon: String, title: String, detail: String?, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            actions().padding(.top, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var toast: some View {
        if let text = model.toast {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if dropTargeted {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(Label("松开以识别二维码", systemImage: "qrcode.viewfinder").font(.headline))
                .padding(10)
                .allowsHitTesting(false)
        }
    }
}
