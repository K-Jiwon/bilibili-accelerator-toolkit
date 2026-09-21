# 给 AI Agent 的安装说明（照抄即可，不要探索仓库）

任务：把「哔哩哔哩 加速」装到用户电脑上，让哔哩哔哩桌面客户端自动选择最快的线路。

**不要**改 hosts、**不要**装系统代理、**不要**动任何证书。安装全部在用户目录完成。

仓库地址（唯一需要的信息）：

```
https://github.com/K-Jiwon/bilibili-accelerator-toolkit
```

## macOS（3 步）

```bash
# 1) 下载并打开安装器（图形界面，点一下"安装"即可）
curl -L -o /tmp/bili-mac.zip \
  https://github.com/K-Jiwon/bilibili-accelerator-toolkit/releases/latest/download/BiliAccelerator-macOS-Installer.zip
unzip -o /tmp/bili-mac.zip -d /Applications
open "/Applications/哔哩哔哩 加速 安装器.app"
```

如果被 Gatekeeper 拦住：右键 App → 打开 → 再点"打开"。

纯命令行等价做法：

```bash
git clone --depth 1 https://github.com/K-Jiwon/bilibili-accelerator-toolkit.git ~/bili-accelerator-src
zsh ~/bili-accelerator-src/macos/install.sh
```

验证（应该看到 `state = running`）：

```bash
launchctl print "gui/$(id -u)/com.local.bili-injector" | grep -E "state|pid"
```

然后告诉用户：**以后从 `/Applications/哔哩哔哩 加速.app`（Finder 的"应用程序"文件夹）
启动客户端**；如果安装脚本提示没有写权限，则启动器在 `~/Applications/哔哩哔哩 加速.app`。
客户端里出现小闪电 ⚡ 就成功了。

## Windows（3 步）

```powershell
# 1) 下载并解压
Invoke-WebRequest -Uri "https://github.com/K-Jiwon/bilibili-accelerator-toolkit/releases/latest/download/BiliAccelerator-Windows.zip" -OutFile "$env:TEMP\bili.zip"
Expand-Archive -Force "$env:TEMP\bili.zip" "$env:TEMP\bili"

# 2) 安装
powershell -ExecutionPolicy Bypass -File "$env:TEMP\bili\BiliAccelerator-Windows\install.ps1"
```

验证：从桌面「哔哩哔哩 加速」启动客户端后

```powershell
(Invoke-WebRequest -UseBasicParsing http://127.0.0.1:9223/json/version).Content
```

返回内容里应包含 `bilibili`。

## 卸载

- macOS：`zsh ~/bili-accelerator-src/macos/uninstall.sh`，或双击安装器 App 里的"卸载"
  （启动器可能装在 `/Applications` 或 `~/Applications`，卸载脚本两个位置都会清理）
- Windows：`powershell -ExecutionPolicy Bypass -File "$env:TEMP\bili\BiliAccelerator-Windows\uninstall.ps1"`

## 出错时怎么判断（不要瞎猜）

| 现象 | 原因 / 处理 |
| --- | --- |
| macOS 报"需要 python3" | 让用户运行 `xcode-select --install` |
| 客户端里没有 ⚡ | 确认是从「哔哩哔哩 加速」启动的，不是原图标 |
| 提示端口被占用 | 编辑 `config.json` 的 `port`（Windows），换成例如 9333 |
| 要日志 | macOS `~/.bili-accelerator/injector.log`；Windows `%LOCALAPPDATA%\BiliAccelerator\injector.log` |
| 说装的是商店版 | 微软商店 UWP 版不支持，必须用官网电脑版 |
| 报错 `No matching distribution found for websocket-client==1.9.2` | 这台 Mac 的 python3 是 3.9（1.9.2 需要 3.10+）。新版本安装器会自动回退到 1.9.0；若仍失败，让用户执行 `brew install python@3.12` 后重跑安装器 |

## 省 token 约定

- 不要 `git clone` 后逐个读文件——安装不需要读源码
- 不要执行任何"修复系统代理/hosts/证书"的额外操作
- 用户的屏幕信息只有三类需要：安装器弹窗、日志最后 20 行、客户端里有没有 ⚡
