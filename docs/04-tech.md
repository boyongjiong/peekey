# 04 · 技术方案 — Peekey 瞄码

## 1. 选型

| 维度 | 选择 | 理由 |
|---|---|---|
| 语言 | Swift 6（Swift 5 语言模式） | 原生、体积小、无运行时依赖 |
| UI | SwiftUI 视图 + AppKit 窗口/状态栏管理 | SwiftUI 写卡片快；Dock/菜单栏/激活策略/窗口定位需要 AppKit 精细控制 |
| 工程 | Swift Package Manager + `scripts/build-app.sh` 打包 `.app` | 不依赖 Xcode 工程文件，命令行可完整构建；需要时也能用 Xcode 直接打开 `Package.swift` |
| 架构 | `arm64` + `x86_64` Universal | `swift build --arch arm64 --arch x86_64` |
| 最低系统 | macOS 14 | 使用 `SMAppService`、`@Observable` 前的 `ObservableObject` 足够，兼顾覆盖率 |
| 第三方依赖 | **无** | 安全类工具减少供应链风险 |

## 2. 模块划分

```
Package.swift
Sources/
  PeekeyCore/            # 纯逻辑库，可单测，无 UI
    Base32.swift         # RFC 4648 Base32 解码/编码
    TOTP.swift           # RFC 6238 TOTP（SHA1/256/512，6/7/8 位）
    OTPAuthURI.swift     # otpauth:// 解析与生成
    MigrationPayload.swift # otpauth-migration://（Google Authenticator 导出）最小 protobuf 解码
    Account.swift        # 账户模型（Codable）
  Peekey/                # App 可执行目标
    main.swift           # NSApplication 入口
    AppDelegate.swift    # 生命周期、组装各组件
    AppState.swift       # 全局状态 + 设置（UserDefaults）
    Store/
      KeychainVault.swift  # 钥匙串读写
      AccountStore.swift   # 账户增删改查 + 持久化
    System/
      VisibilityController.swift # 显示模式：Dock/菜单栏切换
      StatusItemController.swift # 菜单栏图标
      MainWindowController.swift # 主窗口显示/隐藏/定位
      SettingsWindowController.swift
      HotKey.swift               # Carbon 全局快捷键
      LaunchAtLogin.swift        # SMAppService
      Clipboard.swift            # 复制 + 延时清除
    QR/
      QRDecoder.swift        # Vision 识别二维码
      ScreenQRScanner.swift  # 调用 screencapture -i 框选
      CameraScanner.swift    # AVFoundation + Vision
    UI/
      MainView.swift, AccountCard.swift, CountdownRing.swift,
      AccountForm.swift, CameraScanView.swift, SettingsView.swift,
      HotKeyRecorder.swift, Palette.swift
Tests/PeekeyCoreTests/   # RFC 6238 测试向量、URI 解析、Base32、迁移格式
scripts/
  build-app.sh           # 编译 Universal、组装 .app、生成图标、ad-hoc 签名
  make-icon.swift        # 程序化绘制 App 图标 → .icns
```

## 3. 关键实现

### 3.1 TOTP
`counter = floor(unixTime / period)`，HMAC（CryptoKit `HMAC<Insecure.SHA1>` / `SHA256` / `SHA512`）对 8 字节大端 counter 签名，动态截断取 31 位整数，对 `10^digits` 取模，左侧补零。用 RFC 6238 附录 B 的测试向量做单测。

### 3.2 存储
- **Secret**：所有账户序列化成 JSON，作为 **一个** generic password 存入登录钥匙串（service = `app.peekey.mac.vault`）。只存一个条目，首次授权只弹一次框。
- **非敏感偏好**（显示模式、快捷键、开关项）：`UserDefaults`。
- 不使用 Data Protection Keychain：它需要带 Team ID 的 `keychain-access-groups` entitlement，ad-hoc 签名拿不到。正式分发（Developer ID 签名）后可迁移。

### 3.3 显示模式（核心需求）

| 模式 | `NSApp.activationPolicy` | 菜单栏 `NSStatusItem` |
|---|---|---|
| 仅菜单栏 | `.accessory` | 显示 |
| 仅 Dock | `.regular` | 移除 |
| 菜单栏 + Dock | `.regular` | 显示 |
| 都不显示 | `.accessory` | 移除 |

- `Info.plist` 设 `LSUIElement = YES`，启动时不在 Dock 闪一下，再按设置切到 `.regular`。
- 运行时切换策略后调用 `NSApp.activate()`，保证窗口仍在前台。
- **兜底唤醒**：
  1. 全局快捷键（Carbon `RegisterEventHotKey`，**不需要辅助功能权限**）；
  2. `applicationShouldHandleReopen`：从 Finder / Spotlight / Launchpad 再次打开 App 时显示窗口；
  3. 设置「都不显示」时强制要求已有快捷键。

### 3.4 一键显示 / 隐藏
`MainWindowController.toggle(source:)`：
- 窗口可见且 App 在前台 → `orderOut` 隐藏（菜单栏/隐身模式下调用 `NSApp.hide` 把焦点还给上一个 App）
- 否则 → 定位（菜单栏来源则对齐图标）→ `NSApp.activate()` → `makeKeyAndOrderFront` → 搜索框获取焦点
- 失焦自动隐藏：监听 `NSWindow.didResignKeyNotification`（弹 sheet / 扫码时暂停）

窗口：`NSWindow`（titled + closable + miniaturizable + resizable + fullSizeContentView，透明标题栏），关闭按钮只隐藏不退出；`collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]`，在全屏 App 上方也能弹出。

### 3.5 扫码
- **屏幕框选**：执行 `/usr/sbin/screencapture -i -x <tmp.png>`，复用系统框选 UI，再用 Vision `VNDetectBarcodesRequest(symbologies: [.qr])` 识别。首次使用系统会请求「屏幕录制」权限。
- **图片 / 拖拽 / 剪贴板**：`NSImage` → `CGImage` → Vision。
- **摄像头**：`AVCaptureSession` + `AVCaptureVideoDataOutput`，每 ~0.3s 抽一帧交给 Vision，识别到 `otpauth` 即停止。需要 `NSCameraUsageDescription` 和 `com.apple.security.device.camera`（如果开启沙盒）。
- 解析结果：`otpauth://totp/...` → 单个账户（弹表单确认）；`otpauth-migration://offline?data=...` → 批量导入。

### 3.6 全局快捷键
Carbon `RegisterEventHotKey` + `InstallEventHandler`。快捷键以 `(keyCode, carbonModifiers)` 存 UserDefaults；录制器用 `NSEvent.addLocalMonitorForEvents(.keyDown)` 捕获，要求至少包含 ⌘/⌥/⌃ 之一。

### 3.7 剪贴板清除
复制后记录 `NSPasteboard.changeCount`，N 秒后若 `changeCount` 未变（用户没复制别的）才清空。

### 3.8 开机自启
`SMAppService.mainApp.register()/unregister()`。需要 App 位于 `/Applications` 或已签名的 bundle 中才生效。

## 4. 安全

- 不联网：不申请网络权限，代码中不包含任何网络请求
- Secret 不写日志、不落普通文件；截图临时文件识别后立即删除
- 删除账户需要二次确认

## 5. 构建与发布

```bash
swift test                    # 跑核心库单测
./scripts/build-app.sh        # 生成 build/Peekey.app（Universal，ad-hoc 签名）
open build/Peekey.app
```

正式分发：Developer ID 签名 + Hardened Runtime + `notarytool` 公证 + DMG（后续）。

> ad-hoc 签名每次重新构建签名都会变，钥匙串会再次询问「是否允许访问」，选「始终允许」即可。正式签名后不会有这个问题。

## 6. 测试计划

| 层 | 内容 |
|---|---|
| 单元测试 | RFC 6238 SHA1/256/512 向量；Base32 带/不带补位、小写、空格；otpauth URI 各字段与 URL 编码；迁移 payload 解码 |
| 手工测试 | 四种显示模式切换；快捷键在其他 App 前台时唤醒/隐藏；全屏 Space 上唤醒；三种扫码方式；钥匙串重启后数据仍在 |
