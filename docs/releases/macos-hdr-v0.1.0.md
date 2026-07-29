# Sunshine macOS HDR Experimental v0.1.0

> **Unofficial pre-release / 非官方预发布版 / 非官方預發布版 / 非公式プレリリース**<br>
> This fork is not affiliated with or endorsed by LizardByte. The macOS
> application is ad-hoc signed and is not Apple-notarized.

## 简体中文

这是基于 Sunshine `v2026.516.143833` 的首个 macOS HDR 实验预发布版。

- 新增 ScreenCaptureKit P010、BT.2020、PQ HDR 采集和 HEVC Main10 编码。
- 修复 VideoToolbox 串行编码造成的约 60–68 FPS 限制，并以四帧上限约束异步队列。
- 支持稳定显示器 UUID，避免 BetterDisplay 重连后数字 ID 改变。
- 回移[上游 #5186](https://github.com/LizardByte/Sunshine/pull/5186)，补充本地网络用途说明以改善 Bonjour 注册。
- 发行包仅支持 Apple Silicon (`arm64`)，部署目标为 macOS 15.0+。
- 当前仅在 M2 Pro、macOS 27.0 beta、2732×2048、120 Hz 环境完成实测。

请下载 DMG 与对应的 `.sha256` 文件，先验证校验值，再安装。此版本未经 Apple 公证；只应在你信任本仓库时通过“系统设置 → 隐私与安全性 → 仍要打开”。问题请提交到本 fork，不要提交给上游。

## 繁體中文

這是基於 Sunshine `v2026.516.143833` 的首個 macOS HDR 實驗預發布版。

- 新增 ScreenCaptureKit P010、BT.2020、PQ HDR 擷取及 HEVC Main10 編碼。
- 修正 VideoToolbox 串行編碼造成的約 60–68 FPS 限制，並以四幀上限限制非同步佇列。
- 支援穩定顯示器 UUID，避免 BetterDisplay 重新連線後數字 ID 改變。
- 回移[上游 #5186](https://github.com/LizardByte/Sunshine/pull/5186)，補上本機網路用途說明以改善 Bonjour 註冊。
- 發布包僅支援 Apple Silicon (`arm64`)，部署目標為 macOS 15.0+。
- 目前僅於 M2 Pro、macOS 27.0 beta、2732×2048、120 Hz 環境完成實測。

請下載 DMG 與對應的 `.sha256` 檔案，先驗證校驗值，再安裝。此版本未經 Apple 公證；僅應在你信任本倉庫時透過「系統設定 → 隱私權與安全性 → 仍要打開」。問題請提交至本 fork，請勿提交至上游。

## English

This is the first experimental macOS HDR pre-release based on Sunshine
`v2026.516.143833`.

- Adds ScreenCaptureKit P010, BT.2020, PQ HDR capture and HEVC Main10 encoding.
- Removes the roughly 60–68 FPS serialization bottleneck in VideoToolbox and bounds its asynchronous queue to four frames.
- Adds stable display UUID selection for BetterDisplay reconnects that change numeric IDs.
- Backports [upstream #5186](https://github.com/LizardByte/Sunshine/pull/5186), adding the Local Network usage description needed for Bonjour registration.
- The distributed build is Apple Silicon (`arm64`) only and targets macOS 15.0+.
- Live testing is limited to an M2 Pro on macOS 27.0 beta at 2732×2048, 120 Hz.

Download both the DMG and its `.sha256` file, then verify the checksum before installation. This build is not Apple-notarized; use **System Settings → Privacy & Security → Open Anyway** only if you trust this repository. Report fork-specific issues here, not upstream.

## 日本語

Sunshine `v2026.516.143833` を基にした、初回の macOS HDR 実験的プレリリースです。

- ScreenCaptureKit による P010・BT.2020・PQ の HDR キャプチャと HEVC Main10 エンコードを追加しました。
- VideoToolbox の直列化による約 60–68 FPS の制限を解消し、非同期キューを最大 4 フレームに制限しました。
- BetterDisplay の再接続で数値 ID が変わる場合に備え、安定したディスプレイ UUID 選択を追加しました。
- Bonjour 登録に必要なローカルネットワーク用途説明を追加する[上流 #5186](https://github.com/LizardByte/Sunshine/pull/5186) をバックポートしました。
- 配布ビルドは Apple Silicon (`arm64`) 専用で、macOS 15.0 以降を対象とします。
- 実機テストは M2 Pro、macOS 27.0 beta、2732×2048、120 Hz の環境に限られます。

DMG と対応する `.sha256` を両方ダウンロードし、インストール前にチェックサムを確認してください。このビルドは Apple の公証を受けていません。本リポジトリを信頼できる場合に限り、「システム設定 → プライバシーとセキュリティ → このまま開く」を使用してください。本フォーク固有の問題は上流ではなく本リポジトリへ報告してください。

## Artifacts, source, and license

- Binary: `Sunshine-macOS-HDR-v0.1.0-arm64-adhoc.dmg`
- Checksum: `Sunshine-macOS-HDR-v0.1.0-arm64-adhoc.dmg.sha256`
- Corresponding source: tag `macos-hdr-v0.1.0`, including pinned submodule revisions
- License: `GPL-3.0-only`
- Notices included in the app bundle: `LICENSE`, `NOTICE`, `FORK_NOTICE.md`

No Sunshine account, password, pairing data, log, display UUID, or local
configuration is included in the release artifact.
