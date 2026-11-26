import PeekeyCore
import SwiftUI

struct AccountForm: View {
    @EnvironmentObject private var model: AppModel
    @State var draft: Account
    let isNew: Bool

    @State private var secretInput = ""
    @State private var showAdvanced = false
    @State private var error: String?

    init(draft: Account, isNew: Bool) {
        _draft = State(initialValue: draft)
        _secretInput = State(initialValue: draft.secret)
        self.isNew = isNew
        _showAdvanced = State(initialValue: draft.algorithm != .sha1 || draft.digits != 6 || draft.period != 30)
    }

    private var secretValid: Bool { Base32.decode(secretInput) != nil }
    private var canSave: Bool {
        secretValid && !(draft.issuer.trimmingCharacters(in: .whitespaces).isEmpty
            && draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? L("Add Account", "添加账户") : L("Edit Account", "编辑账户")).font(.title3.bold())

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text(L("Issuer", "发行方")).gridColumnAlignment(.trailing)
                    TextField(L("e.g. GitHub", "例如 GitHub"), text: $draft.issuer)
                }
                GridRow {
                    Text(L("Account", "账户名"))
                    TextField(L("e.g. me@example.com", "例如 me@example.com"), text: $draft.name)
                }
                if isNew {
                    GridRow {
                        Text(L("Secret", "密钥"))
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(L("Base32 secret, e.g. JBSWY3DPEHPK3PXP", "Base32 密钥，如 JBSWY3DPEHPK3PXP"), text: $secretInput)
                                .font(.system(.body, design: .monospaced))
                            if !secretInput.isEmpty && !secretValid {
                                Text(L("Invalid secret: only A–Z and 2–7 are allowed", "密钥格式无效：只能包含 A–Z 和 2–7")).font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                }
                GridRow(alignment: .center) {
                    Text(L("Color", "颜色"))
                    HStack(spacing: 6) {
                        ForEach(Palette.all) { p in
                            let selected = Palette.palette(for: draft).key == p.key
                            Circle()
                                .fill(p.gradient)
                                .frame(width: 18, height: 18)
                                .overlay(Circle().strokeBorder(.primary.opacity(selected ? 0.8 : 0), lineWidth: 2).padding(-3))
                                .onTapGesture { draft.color = p.key }
                                .help(p.name)
                        }
                    }
                }
            }

            DisclosureGroup(L("Advanced", "高级"), isExpanded: $showAdvanced) {
                HStack(spacing: 16) {
                    Picker(L("Algorithm", "算法"), selection: $draft.algorithm) {
                        ForEach(OTPAlgorithm.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .fixedSize()
                    Picker(L("Digits", "位数"), selection: $draft.digits) {
                        ForEach(6...8, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .fixedSize()
                    HStack(spacing: 4) {
                        Text(L("Period", "周期"))
                        TextField("", value: $draft.period, format: .number)
                            .frame(width: 44)
                        Text(L("s", "秒"))
                    }
                }
                .padding(.top, 8)
                .disabled(!isNew)
            }

            HStack {
                Text(L("Preview", "预览")).foregroundStyle(.secondary)
                if canSave {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(AccountCard.group(previewAccount.code(at: ctx.date)))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
                Spacer()
            }

            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(L("Cancel", "取消"), role: .cancel) { model.sheet = nil }
                    .keyboardShortcut(.cancelAction)
                Button(L("Save", "保存")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(22)
        .frame(width: 420)
    }

    private var previewAccount: Account {
        var a = draft
        a.secret = Base32.normalize(secretInput)
        if a.period <= 0 { a.period = 30 }
        return a
    }

    private func save() {
        var a = previewAccount
        a.issuer = a.issuer.trimmingCharacters(in: .whitespaces)
        a.name = a.name.trimmingCharacters(in: .whitespaces)
        error = model.save(a, isNew: isNew)
    }
}
