# Peekey 瞄码

> 一键唤醒，瞄一眼验证码。—— macOS 原生 2FA（TOTP）验证器

- 卡片式展示所有 2FA 验证码，点击即复制
- 扫码添加：框选屏幕二维码 / 图片（选择、拖拽、粘贴）/ 摄像头 / Google Authenticator 批量导出
- **显示模式**：仅菜单栏 / 仅 Dock / 两者 / 都不显示
- **全局快捷键**（默认 `⌥⌘2`）一键显示 / 隐藏，不需要辅助功能权限
- 密钥只存在 macOS 钥匙串，不联网
- Universal：Apple Silicon + Intel，macOS 14+

## 构建

```bash
swift test                 # 核心库单测（RFC 6238 测试向量等）
./scripts/build-app.sh     # → build/Peekey.app（Universal，ad-hoc 签名）
open build/Peekey.app
```

UI 调试可用演示数据（不读写钥匙串）：

```bash
PEEKEY_DEMO=1 build/Peekey.app/Contents/MacOS/Peekey
```

正式分发：`SIGN_IDENTITY="Developer ID Application: …" ./scripts/build-app.sh`，然后 notarize。

## 快捷键

| 键 | 作用 |
|---|---|
| `⌥⌘2`（可改） | 全局显示 / 隐藏 |
| `↑` `↓` / `↩` | 选择 / 复制 |
| `Esc` | 清空搜索 / 隐藏 |
| `⇧⌘S` | 扫描屏幕二维码 |
| `⌘O` | 从图片导入 |
| `⇧⌘V` | 从剪贴板添加 |
| `⌘N` | 手动添加 |
| `⌘,` | 设置 |

## 文档

1. [命名](docs/01-naming.md)
2. [PRD](docs/02-PRD.md)
3. [设计稿](docs/03-design.md)
4. [技术方案](docs/04-tech.md)
