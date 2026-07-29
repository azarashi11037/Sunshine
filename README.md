<div align="center">
  <img src="sunshine.png" width="128" alt="Sunshine icon">
  <h1>Sunshine macOS HDR / 120 FPS</h1>
  <p>Unofficial experimental fork for high-refresh-rate HDR streaming on macOS.</p>
</div>

> [!IMPORTANT]
> **简中：** 这是非官方实验修改版，请勿向 Sunshine 上游项目寻求本分支支持。<br>
> **繁中：** 這是非官方實驗修改版，請勿向 Sunshine 上游專案尋求本分支支援。<br>
> **English:** This is an unofficial experimental fork. Do not request support for it from the upstream Sunshine project.<br>
> **日本語：** 本リポジトリは非公式の実験的フォークです。本フォークについて上流の Sunshine に問い合わせないでください。

[简体中文](#简体中文) · [繁體中文](#繁體中文) · [English](#english) · [日本語](#日本語)

| 项目 / 項目 / Item / 項目 | 信息 / 資訊 / Information / 情報 |
|---|---|
| Upstream | [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) |
| Base | `v2026.516.143833` (`14ffa6fd`) + [upstream macOS fix #5186](https://github.com/LizardByte/Sunshine/pull/5186) |
| Fork release | [`macos-hdr-v0.1.0`](https://github.com/azarashi11037/Sunshine/releases/tag/macos-hdr-v0.1.0) |
| Binary | Apple Silicon (`arm64`), deployment target macOS 15.0+ |
| Tested | M2 Pro, macOS 27.0 beta, 2732×2048, 120 Hz, HEVC Main10 HDR |
| Signing | Ad-hoc signed; **not Apple-notarized** |
| License | [GPL-3.0-only](https://github.com/azarashi11037/Sunshine/blob/macos-hdr-v0.1.0/LICENSE) |

## 简体中文

这是基于 [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) 的非官方 macOS 实验修改版，由 `azarashi11037` 于 2026-07-29 修改。目标是在 Apple Silicon Mac 上改善 Moonlight 兼容客户端的 HDR 与 120 FPS 串流；已使用 BetterDisplay 虚拟显示器和 iPad 客户端进行测试。

主要修改：

- ScreenCaptureKit 以 P010、BT.2020、PQ 采集 HDR，并交给 VideoToolbox HEVC Main10。
- 允许 VideoToolbox 并行编码，以四帧上限约束异步队列并保留正确时间戳。
- 支持使用 macOS 显示器 UUID，避免 BetterDisplay 重连后数字显示器 ID 改变。
- 回移[上游 #5186](https://github.com/LizardByte/Sunshine/pull/5186)，补充本地网络用途说明以改善 Bonjour 注册。

安装与限制：

1. 从 [Releases](https://github.com/azarashi11037/Sunshine/releases) 下载 `arm64` DMG，并先核对随附的 SHA-256。
2. 将 `Sunshine.app` 拖入“应用程序”。此版本未经过 Apple 公证；仅在校验值正确且你信任本仓库时，使用“系统设置 → 隐私与安全性 → 仍要打开”。
3. 授予屏幕录制、本地网络及系统音频权限。使用虚拟显示器时，建议先启用显示器，再启动 Sunshine。
4. HDR 采集要求 macOS 15+、Apple Silicon、HDR 显示器模式及 HEVC Main10 HDR 客户端。当前仅在上述测试环境验证，其他系统版本不作保证。

本分支不会自动包含上游后续更新。问题请提交到[本仓库 Issues](https://github.com/azarashi11037/Sunshine/issues)，不要提交到上游。发布包不包含任何账户、密码、配对信息、日志或本机配置。

## 繁體中文

這是基於 [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) 的非官方 macOS 實驗修改版，由 `azarashi11037` 於 2026-07-29 修改。目標是在 Apple Silicon Mac 上改善 Moonlight 相容用戶端的 HDR 與 120 FPS 串流；已使用 BetterDisplay 虛擬顯示器及 iPad 用戶端測試。

主要修改：

- ScreenCaptureKit 以 P010、BT.2020、PQ 擷取 HDR，再交由 VideoToolbox HEVC Main10 編碼。
- 允許 VideoToolbox 平行編碼，以四幀上限限制非同步佇列並保留正確時間戳。
- 支援使用 macOS 顯示器 UUID，避免 BetterDisplay 重新連線後數字顯示器 ID 改變。
- 回移[上游 #5186](https://github.com/LizardByte/Sunshine/pull/5186)，補上本機網路用途說明以改善 Bonjour 註冊。

安裝與限制：

1. 從 [Releases](https://github.com/azarashi11037/Sunshine/releases) 下載 `arm64` DMG，並先核對隨附的 SHA-256。
2. 將 `Sunshine.app` 拖入「應用程式」。此版本未經 Apple 公證；僅在校驗值正確且你信任本倉庫時，使用「系統設定 → 隱私權與安全性 → 仍要打開」。
3. 授予螢幕錄製、本機網路及系統音訊權限。使用虛擬顯示器時，建議先啟用顯示器，再啟動 Sunshine。
4. HDR 擷取需要 macOS 15+、Apple Silicon、HDR 顯示器模式及 HEVC Main10 HDR 用戶端。目前僅於上述測試環境驗證，不保證其他系統版本。

本分支不會自動包含上游後續更新。問題請提交至[本倉庫 Issues](https://github.com/azarashi11037/Sunshine/issues)，請勿提交至上游。發布包不包含任何帳戶、密碼、配對資訊、日誌或本機設定。

## English

This is an unofficial experimental macOS fork of [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine), modified by `azarashi11037` on 2026-07-29. It targets HDR and 120 FPS streaming from Apple Silicon Macs to Moonlight-compatible clients. Testing used a BetterDisplay virtual display and an iPad client.

Key changes:

- Capture HDR through ScreenCaptureKit as P010, BT.2020, PQ for VideoToolbox HEVC Main10.
- Allow parallel VideoToolbox encoding, bound its asynchronous queue to four frames, and preserve frame timestamps.
- Resolve displays by macOS display UUID so BetterDisplay reconnects do not break selection when numeric IDs change.
- Backport [upstream #5186](https://github.com/LizardByte/Sunshine/pull/5186), adding the Local Network usage description needed for Bonjour registration.

Installation and limitations:

1. Download the `arm64` DMG from [Releases](https://github.com/azarashi11037/Sunshine/releases) and verify the accompanying SHA-256 first.
2. Drag `Sunshine.app` to Applications. The build is not Apple-notarized; use **System Settings → Privacy & Security → Open Anyway** only after verifying the checksum and trusting this repository.
3. Grant Screen Recording, Local Network, and System Audio permissions. For a virtual display, enable the display before starting Sunshine.
4. HDR capture requires macOS 15+, Apple Silicon, an HDR display mode, and an HEVC Main10 HDR client. Only the environment listed above has been tested.

This branch does not automatically receive later upstream updates. Report problems to [this fork's Issues](https://github.com/azarashi11037/Sunshine/issues), not upstream. Release artifacts contain no account, password, pairing, log, or local configuration data.

## 日本語

これは [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) を基に、`azarashi11037` が 2026-07-29 に変更した非公式の macOS 向け実験的フォークです。Apple Silicon Mac から Moonlight 互換クライアントへの HDR・120 FPS 配信を目的とし、BetterDisplay の仮想ディスプレイと iPad クライアントでテストしています。

主な変更：

- ScreenCaptureKit で HDR を P010・BT.2020・PQ として取得し、VideoToolbox の HEVC Main10 に渡します。
- VideoToolbox の並列エンコードを有効にし、非同期キューを最大 4 フレームに制限しながら正しいタイムスタンプを保持します。
- macOS のディスプレイ UUID による選択に対応し、BetterDisplay 再接続後に数値 ID が変わっても同じディスプレイを解決します。
- Bonjour 登録に必要なローカルネットワーク用途説明を追加する[上流 #5186](https://github.com/LizardByte/Sunshine/pull/5186) をバックポートしました。

インストールと制限：

1. [Releases](https://github.com/azarashi11037/Sunshine/releases) から `arm64` DMG を取得し、同梱の SHA-256 を先に確認してください。
2. `Sunshine.app` を「アプリケーション」へ移動します。このビルドは Apple の公証を受けていません。チェックサムを確認し、本リポジトリを信頼できる場合に限り、「システム設定 → プライバシーとセキュリティ → このまま開く」を使用してください。
3. 画面収録、ローカルネットワーク、システムオーディオの権限を許可してください。仮想ディスプレイを使う場合は、先にディスプレイを有効にしてから Sunshine を起動することを推奨します。
4. HDR キャプチャには macOS 15 以降、Apple Silicon、HDR ディスプレイモード、HEVC Main10 HDR 対応クライアントが必要です。上記以外の環境は未検証です。

本ブランチには上流の更新が自動では取り込まれません。不具合は上流ではなく[本フォークの Issues](https://github.com/azarashi11037/Sunshine/issues)へ報告してください。配布物にアカウント、パスワード、ペアリング情報、ログ、ローカル設定は含まれません。

## Source, attribution, and license

This repository retains the upstream copyright, license, and notice files. Fork modifications are distributed under `GPL-3.0-only`, without warranty. The binary release is accompanied by the corresponding tagged source in this repository; clone it with submodules using:

```bash
git clone --recursive --branch macos-hdr-v0.1.0 https://github.com/azarashi11037/Sunshine.git
```

See [FORK_NOTICE.md](https://github.com/azarashi11037/Sunshine/blob/macos-hdr-v0.1.0/FORK_NOTICE.md),
[LICENSE](https://github.com/azarashi11037/Sunshine/blob/macos-hdr-v0.1.0/LICENSE), and
[NOTICE](https://github.com/azarashi11037/Sunshine/blob/macos-hdr-v0.1.0/NOTICE).
Sunshine and LizardByte names remain associated with their respective owners;
this fork is not affiliated with or endorsed by LizardByte.
