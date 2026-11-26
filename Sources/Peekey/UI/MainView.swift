import PeekeyCore
import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: AccountStore
    @EnvironmentObject private var settings: Settings
    @FocusState private var searchFocused: Bool
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if !store.accounts.isEmpty {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
            }
            content
        }
        .frame(minWidth: 320, minHeight: 360)
        .background(Theme.background)
        .onHover { model.pointerInWindow = $0 }
        .overlay(alignment: .bottom) { toast }
        .overlay { if !store.accounts.isEmpty { dropOverlay } }
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
        .onChange(of: model.focusToken) { searchFocused = !store.accounts.isEmpty }
        .onChange(of: model.search) { model.selectedID = nil }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            TextField("搜索", text: $model.search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .accessibilityLabel("搜索账户")
            if !model.search.isEmpty {
                Button { model.search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .font(.system(size: 14))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(searchFocused ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.15), value: searchFocused)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let error = store.loadError, store.accounts.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "exclamationmark.lock").font(.system(size: 40, weight: .light)).foregroundStyle(.secondary)
                Text("无法读取钥匙串").font(.headline)
                Text(error).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("重试") { store.load() }.padding(.top, 6)
                Spacer()
            }
            .padding(.horizontal, 28)
        } else if store.accounts.isEmpty {
            EmptyStateView(dropTargeted: dropTargeted, hotKey: settings.hotKey)
        } else if model.filtered.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "magnifyingglass").font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
                Text("没有匹配“\(model.search)”的账户").font(.headline)
                Text("按 Esc 清除搜索").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    LazyVStack(spacing: 12) {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
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

/// First-run state: one obvious primary action, secondary paths as links,
/// the whole area doubles as a visible drop zone, and the global hotkey is taught up front.
private struct EmptyStateView: View {
    @EnvironmentObject private var model: AppModel
    let dropTargeted: Bool
    let hotKey: HotKeyCombo?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: dropTargeted ? "arrow.down.circle" : "qrcode.viewfinder")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                VStack(spacing: 6) {
                    Text(dropTargeted ? "松开以识别二维码" : "添加第一个验证码")
                        .font(.system(size: 17, weight: .semibold))
                    Text("框选网页上的 2FA 二维码即可添加")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Button { model.scanScreen() } label: {
                    Label("扫描屏幕二维码", systemImage: "viewfinder")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)

                HStack(spacing: 6) {
                    LinkButton("从图片导入") { model.importImageFile() }
                    Text("·").foregroundStyle(.tertiary)
                    LinkButton("手动输入") { model.newManual() }
                }
                .font(.system(size: 13))
                Spacer(minLength: 0)
                Text("也可以把二维码图片拖到这里")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(dropTargeted ? 0.08 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        dropTargeted ? Color.accentColor : Color.primary.opacity(0.12),
                        style: StrokeStyle(lineWidth: dropTargeted ? 2 : 1, dash: [6, 5])
                    )
            )
            .animation(.easeOut(duration: 0.15), value: dropTargeted)
            .padding(.horizontal, 16)
            .padding(.top, 4)

            if let hotKey {
                HStack(spacing: 6) {
                    KeyCap(hotKey.display)
                    Text("在任何地方唤醒 Peekey")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(height: 44)
            } else {
                Spacer().frame(height: 16)
            }
        }
    }
}

private struct LinkButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(Color.accentColor)
                .underline(hovering)
        }
        .buttonStyle(.plain)
        .onHover { h in
            hovering = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

private struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15))
            )
    }
}
