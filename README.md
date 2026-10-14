# Codex Accounts

macOS codex多账号启动器，为每个账号打开独立的官方 ChatGPT / Codex 桌面窗口，各自登录，也可以同时使用。

![界面预览](Design/preview.png)

- 添加账号后自动打开并前置独立窗口，在官方应用中完成登录。
- 为账号命名、添加备注、选择图标和颜色、标记常用。
- 搜索账号、查看运行状态、切换到已有窗口，菜单栏也能快速打开。
- 支持简体中文和英语，跟随 macOS 的语言与深色模式设置。

## 下载并使用

需要 **macOS 14 或更高版本**，并先安装与本机兼容、支持 Codex 的官方 `ChatGPT.app` 或 `Codex.app`。管理器仅接受应用标识为 `com.openai.codex` 的桌面应用。

1. 打开 [Releases 下载页](https://github.com/ZehuaLiuY/codex-multi-account-for-mac/releases)，选择已发布版本的 `.dmg` 或 `.zip` 附件。
2. 使用 DMG：双击打开，把 `Codex Accounts.app` 拖到 `Applications`。使用 ZIP：解压后把 App 拖到“应用程序”。
3. 打开 `Codex Accounts`，点击“添加账号”，填写便于辨认的名称，再点击“添加并登录 / Add and Sign In”。
4. 在自动打开的官方窗口中登录。继续添加其他账号，即可同时使用多个独立窗口。

若未检测到官方应用，在管理器的“设置 / Settings”中手动选择。添加后启动失败时，账号信息会保留，可以修正应用位置后点击“打开 / Open”重试。

下载页需要维护者先上传安装包。GitHub 的 **Code → Download ZIP** 和 Release 自动附带的 **Source code** 都是源码，使用方式见下方“从源码运行”。

当前构建使用 ad hoc 签名，尚未进行 Developer ID 签名和 Apple 公证。下载后如果 macOS 提示无法验证开发者，请先确认下载来源，再按照 [Apple 官方说明](https://support.apple.com/en-au/102445)在“系统设置 → 隐私与安全性”中允许打开这个 App。面向公众提供默认可打开的下载版，需要维护者另行完成 Developer ID 签名和公证。

## 从源码运行

需要 Xcode 或 Xcode Command Line Tools。没有 Swift 编译工具时，先在终端运行 `xcode-select --install`，完成安装后继续：

```sh
git clone https://github.com/ZehuaLiuY/codex-multi-account-for-mac.git
cd codex-multi-account-for-mac
./scripts/build.sh
open "dist/Codex Accounts.app"
```

也可以通过 GitHub 的 Code → Download ZIP 下载源码，解压后在项目目录运行最后两条命令。或者用 Xcode 打开 `Package.swift`，运行 `CodexAccounts`。

默认构建当前 Mac 架构的 App，不依赖第三方 Swift 包。

## 打包下载版

在项目目录运行：

```sh
./scripts/package.sh
```

默认为管理器构建包含 `arm64` 和 `x86_64` 的 Universal App，再生成安装镜像、压缩包和校验文件。实际使用仍需安装与本机兼容的官方桌面应用。文件名中的版本号来自 `Resources/Info.plist`，例如：

```text
dist/
├── Codex Accounts.app
├── Codex-Accounts-0.2.0-macOS-universal.dmg
├── Codex-Accounts-0.2.0-macOS-universal.zip
└── Codex-Accounts-0.2.0-macOS-universal.sha256
```

只为指定架构打包，或只构建 Universal App：

```sh
./scripts/package.sh --arch arm64
./scripts/package.sh --arch x86_64
./scripts/build.sh --universal
```

校验下载文件时，把 `.sha256` 与对应的 ZIP、DMG 放在同一目录，再运行 `shasum -a 256 -c Codex-Accounts-0.2.0-macOS-universal.sha256`。


## 本地数据

每个账号使用独立的 `CODEX_HOME` 和桌面应用数据目录。名称、活动和账号空间保存在 `~/Library/Application Support/Codex Accounts/`。管理器不读取、复制或展示登录令牌；登录由官方应用完成。安装包只包含管理器 App，不包含本机账号数据或官方 ChatGPT 应用。

从列表移除账号会保留本地目录，已打开的独立窗口继续运行。退出管理器也不会关闭账号窗口。

```sh
./scripts/test.sh
```

27 项测试覆盖添加后自动启动、启动失败保留账号、保存失败不启动、编辑行为、目录与环境隔离、持久化、窗口恢复和双语文案。启动测试使用本地测试应用。

桌面数据目录的隔离参数包含官方应用的内部接口，官方应用更新后可能需要验证兼容性。
