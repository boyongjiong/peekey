import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: Settings
    @State private var modeError: String?
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    private var modeBinding: Binding<DisplayMode> {
        Binding(
            get: { settings.displayMode },
            set: { newValue in
                if newValue == .hidden && settings.hotKey == nil {
                    modeError = "请先设置唤醒快捷键，否则隐藏后将无法唤醒 Peekey。"
                    return
                }
                modeError = nil
                settings.displayMode = newValue
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("显示位置", selection: modeBinding) {
                    ForEach(DisplayMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
                if let modeError {
                    Text(modeError).font(.callout).foregroundStyle(.red)
                } else if settings.displayMode == .hidden {
                    Text("Peekey 不会出现在 Dock 和菜单栏。按 \(settings.hotKey?.display ?? "快捷键") 唤醒，或在 Finder / 聚焦搜索中再次打开 Peekey。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("唤醒快捷键") {
                    HStack {
                        HotKeyRecorder(combo: $settings.hotKey)
                        Button("清除") { settings.hotKey = nil }
                            .disabled(settings.hotKey == nil || settings.displayMode == .hidden)
                            .help(settings.displayMode == .hidden ? "隐身模式下必须保留快捷键" : "")
                    }
                }
            } footer: {
                Text("在任何应用中按下快捷键即可显示 / 隐藏 Peekey。").font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("开机时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            try LaunchAtLogin.set(on)
                            launchError = nil
                        } catch {
                            launchError = "设置失败：\(error.localizedDescription)（请将 Peekey 移到“应用程序”文件夹后重试）"
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if let launchError { Text(launchError).font(.caption).foregroundStyle(.red) }
                Toggle("复制后隐藏窗口", isOn: $settings.hideAfterCopy)
                Toggle("切换到其他应用时自动隐藏", isOn: $settings.hideOnDeactivate)
                Toggle("窗口置顶", isOn: $settings.alwaysOnTop)
                HStack {
                    Toggle("复制后自动清除剪贴板", isOn: $settings.clearClipboard)
                    Spacer()
                    Picker("", selection: $settings.clearClipboardSeconds) {
                        ForEach([15, 30, 60, 120], id: \.self) { Text("\($0) 秒").tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!settings.clearClipboard)
                }
            }

            Section {
                LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                LabeledContent("数据存储", value: "macOS 钥匙串（本机，不联网）")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct HotKeyRecorder: View {
    @Binding var combo: HotKeyCombo?
    @State private var recording = false
    @State private var monitor: Any?
    @State private var warning: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button { recording ? stop() : start() } label: {
                Text(recording ? "按下快捷键…" : (combo?.display ?? "点击录制"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .tint(recording ? .accentColor : nil)
            if let warning {
                Text(warning).font(.caption).foregroundStyle(.orange)
            }
        }
        .onDisappear { if recording { stop() } }
    }

    private func start() {
        recording = true
        warning = nil
        HotKeyManager.shared.unregister() // don't let the old hotkey fire while recording
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stop()
                return nil
            }
            let mods = HotKeyCombo.carbonModifiers(from: event.modifierFlags)
            guard mods & UInt32(cmdKey | optionKey | controlKey) != 0 else {
                NSSound.beep()
                warning = "需要包含 ⌘、⌥ 或 ⌃"
                return nil
            }
            let new = HotKeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods, key: HotKeyCombo.keyName(for: event))
            combo = new
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if !HotKeyManager.shared.register(combo) {
            warning = "该快捷键可能已被其他应用占用，请换一个"
        }
    }
}
