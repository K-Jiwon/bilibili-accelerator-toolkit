# BiliAccelerator Toolkit

把 [Bilibili Accelerator](https://github.com/realzza/bilibili-accelerator) 这个油猴脚本
注入到哔哩哔哩**桌面客户端**里运行，让客户端也能用上它的能力：

- 自动测速并切换到更快的 CDN 线路
- 屏蔽 PCDN / MCDN 之类的低质量节点
- 卡顿时自动换线恢复
- 客户端内置脚本面板（实时速度、服务器/模式切换）

支持 macOS 和 Windows。**不修改客户端文件**，客户端升级不受影响。

> ### 完全免费声明
>
> 本工具**完全免费、开源**。所有代码都在这个仓库里，任何人都可以自由使用和分发。
> **如果你是花钱买到的，那说明你上当了，请立刻申请退款**（也欢迎把卖家信息发出来）。

## 最简单的方式（推荐）

**macOS**

1. 下载 [BiliAccelerator-macOS-Installer.zip](../../releases/latest/download/BiliAccelerator-macOS-Installer.zip)，解压
2. 双击「哔哩哔哩 加速 安装器」→ 点「**安装**」
3. 以后从「**哔哩哔哩 加速**」图标启动客户端（在「应用程序」文件夹里，也可用 `⌘ + 空格` 搜"哔哩哔哩 加速"）；客户端里出现 ⚡ 就成功了

不想用了：再双击安装器 → 点「**卸载**」即可。

**Windows**

1. 下载 [BiliAccelerator-Windows.zip](../../releases/latest/download/BiliAccelerator-Windows.zip)，解压
2. 双击「**install.cmd**」
3. 以后从「**哔哩哔哩 加速**」图标启动客户端

不想用了：双击「**uninstall.cmd**」。

> 让 AI 帮你装（省 token）：[docs/ai-install.md](docs/ai-install.md)
> 一步一步、最通俗的说明：[docs/simple-guide.md](docs/simple-guide.md)

## 支持的平台

| 平台 | 支持情况 | 说明 |
| --- | --- | --- |
| macOS | ✅ | 官网下载的 `哔哩哔哩.app`（Electron 内核） |
| Windows | ✅ | 官网下载的电脑版客户端（Electron 内核） |
| Windows 商店版 | ❌ | 微软商店的 UWP 版本不是 Chromium，无法注入 |
| iOS / Android | ❌ | 原生 App，无注入入口；可参考文末替代方案 |

## 原理

哔哩哔哩桌面客户端是 Electron 应用（Chromium + Node.js）：

```
Electron 主进程
  └── 本地 HTTP 服务（--host-rules: bilipc.bilibili.com → 127.0.0.1:xxx）
        └── Chromium 渲染层：index.html / player.html / iframe
              └── JS 调用 playurl 接口拿媒体地址 → 交给 <video> 播放
```

因为我们能在启动时加上 `--remote-debugging-port=<port>`，外部程序就能通过
Chrome DevTools 协议（CDP）连进这些页面，把脚本注入到每个页面/frame 的上下文里。
脚本再通过挂钩 `JSON.parse` / `fetch` / `XMLHttpRequest`，改写播放地址的 CDN 域名，
从而让客户端使用更快的线路。

详细说明见 [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)。

## 安装

### macOS

**方式 A（推荐，图形界面）**：从 Releases 下载
`BiliAccelerator-macOS-Installer.zip`，解压后双击「哔哩哔哩 加速 安装器」，
点「安装」；卸载就在同一个窗口点「卸载」。

**方式 B（命令行）**：

```bash
git clone https://github.com/<你的用户名>/bilibili-accelerator-toolkit.git
cd bilibili-accelerator-toolkit
./macos/install.sh
```

安装脚本做的事（全部在用户目录，不需要管理员密码）：

1. 把注入器安装到 `~/.bili-accelerator/`（只用 Python 标准库，不需要 pip、不需要联网）
2. 在 `/Applications`（Finder 里的「应用程序」）生成「哔哩哔哩 加速.app」启动器；
   如果该目录没有写权限，会自动退回 `~/Applications/`
3. 注册开机自启的 LaunchAgent（`com.local.bili-injector`）

然后从「哔哩哔哩 加速」启动客户端即可（首次会自动重启一次客户端以带上调试端口）。

卸载：

```bash
./macos/uninstall.sh
```

（也可以直接双击仓库里的 `macos/install.command` / `macos/uninstall.command`。）

### Windows

从 [Releases](../../releases) 下载 `BiliAccelerator-Windows.zip`（自带 Python 运行时，
免安装），解压后双击 `install.cmd`。详见 [windows/README.md](windows/README.md)。

也可以自己构建：

```bash
bash tools/build_windows_release.sh
# 产物: dist/BiliAccelerator-Windows.zip
```

macOS 安装器 App 也可以自己构建：

```bash
bash macos/installer/build_installer.sh
# 产物: dist/BiliAccelerator-macOS-Installer.zip
```

## 目录结构

```
injector.py                     跨平台注入器（CDP）
userscript/                     上游油猴脚本（MIT，见 NOTICE）
macos/                          macOS 安装/卸载/启动器模板
windows/                        Windows 安装/启动脚本
tools/                          图标生成、Windows 发布包构建
docs/HOW-IT-WORKS.md            原理与实现细节
.github/workflows/              CI：自动构建 Windows 发布包
```

## 配置

Windows：安装目录下的 `config.json`

```json
{
  "clientExe": "C:\\path\\to\\哔哩哔哩.exe",
  "port": 9223,
  "match": "bilipc.bilibili.com"
}
```

macOS：修改 `~/Applications/哔哩哔哩 加速.app/Contents/MacOS/launcher` 里的 `PORT` /
`BILI_APP` 即可。

## 常见问题

**面板（小闪电）没出现？**
确认是从「哔哩哔哩 加速」启动的，而不是原客户端图标；并从日志确认注入成功：

- macOS：`~/.bili-accelerator/injector.log`
- Windows：`%LOCALAPPDATA%\BiliAccelerator\injector.log`

**启动后提示没有调试端口？**
说明装的是商店 UWP 版，或者客户端不是 Electron 版本。

**杀毒软件报警？**
工具会向客户端进程注入脚本，属于预期行为；只在**本机**、只对哔哩哔哩客户端生效。

**调试端口会一直开着吗？**
通过加速启动器启动后，调试端口在整个客户端运行期间都开着（只监听 `127.0.0.1`，
退出客户端即关闭）。不用加速启动器就不会带这个端口。

**提示 "需要 python3"？**
说明这台 Mac 还没装命令行工具。运行一次下面的命令即可（会弹出安装窗口）：

```bash
xcode-select --install
```

**播放页黑屏 / 面板消失？**
不要手动刷新客户端的播放页——被刷新后客户端不会自动续播（不注入脚本也一样）。
重启客户端即可恢复。其他实测结论见 [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)。

**打开脚本面板后视频变卡？**
面板原本带实时高斯模糊和速度曲线，低配机器会掉帧。Windows 安装后默认使用
`uiMode: "lite"`（保留面板、去掉模糊和曲线），可在 `config.json` 里改成：

- `"uiMode": "full"`：脚本原样（最好看，最吃性能）
- `"uiMode": "off"`：完全不显示面板（加速照常工作）

macOS 想换模式：重装时带上环境变量，例如 `BILI_UI_MODE=lite ./macos/install.sh`。

## 其他平台有没有办法

- **Android**：官方 App 无法注入。可用 root + LSPosed 模块（如 BiliRoaming，
  含 CDN/线路相关选项），或使用开源第三方客户端，或用支持自定义 DNS 重写的
  VPN 类应用做「同域换 IP」。
- **iOS**：原生 App 无解。可用 Safari + 油猴扩展（Userscripts / Stay）跑网页版。

## 免责声明

- 本项目只做**网络线路优化和播放体验增强**，不涉及任何付费内容或 DRM 绕过。
- 使用第三方脚本/自动化工具存在账号风控风险，请自行评估。
- 注入的脚本运行在客户端页面里，能访问该域名的登录态，请只使用你信任的脚本。
- 哔哩哔哩客户端更新可能导致内部页面结构变化，需要相应调整。

## 致谢

- [realzza/bilibili-accelerator](https://github.com/realzza/bilibili-accelerator)：核心加速脚本（MIT）
- [mitmproxy](https://mitmproxy.org/)：早期网络层方案的验证工具
- `wsclient.py`：自己实现的极简 WebSocket 客户端（只用 Python 标准库，所以安装时不用 pip、不用联网）

## License

MIT，见 [LICENSE](LICENSE)。上游脚本的授权与署名见 [NOTICE](NOTICE)。
