# 哔哩哔哩 加速（Windows 免安装版）

把 B 站 PC 客户端里那个「Bilibili Accelerator」脚本注入到客户端内部运行，
让客户端也能用上它的自动切线路、PCDN 屏蔽、卡顿自动恢复等能力。

## 前置条件

- Windows 10 / 11
- **必须是哔哩哔哩官网下载的电脑版客户端**（Electron 内核）
- 微软商店（UWP）版本不支持，因为那不是 Chromium，无法注入

## 安装

1. 解压整个文件夹（不要只复制其中几个文件，`python` 目录是运行时）
2. **如果压缩包是从网上下载/聊天软件传过来的**：先右键压缩包 → 属性 → 勾选「解除锁定」再解压
3. 双击 **`install.cmd`**

   如果双击没反应，就按住 Shift 右键 → 「在此处打开 PowerShell 窗口」，执行：

   ```
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

安装脚本会：

- 把程序复制到 `%LOCALAPPDATA%\BiliAccelerator`
- 自动寻找客户端路径并写入 `config.json`
- 在**桌面**和**开始菜单**创建「哔哩哔哩 加速」快捷方式
- 在**启动项**里放一个注入器（开机后静默等待，不占资源）

## 使用

双击桌面上的 **「哔哩哔哩 加速」**。首次启动会自动重启客户端一次
（因为要带调试端口启动）。几秒后客户端里会出现脚本自带的 **⚡ 面板**，
可以看实时速度、切换服务器和模式。

## 配置

安装目录下的 `config.json`：

```json
{
  "clientExe": "C:\\Users\\你的用户名\\AppData\\Local\\Programs\\bilibili\\哔哩哔哩.exe",
  "port": 9223,
  "match": "bilipc.bilibili.com",
  "uiMode": "lite"
}
```

- `clientExe`：客户端完整路径，自动找不到时手动填
- `port`：DevTools 端口，冲突时可改（例如 9333）
- `match`：注入页面的地址关键字，一般不用改
- `uiMode`：脚本面板的显示方式
  - `lite`（默认）：保留面板，但去掉 `backdrop-filter` 实时模糊和速度曲线——打开面板不会再拖慢播放
  - `full`：脚本原样，面板最好看但更吃性能
  - `off`：完全隐藏面板（加速功能照常工作）

## 日志与排错

- 注入器日志：`%LOCALAPPDATA%\BiliAccelerator\injector.log`
- 启动器日志：`%LOCALAPPDATA%\BiliAccelerator\launcher.log`

常见问题：

| 现象 | 原因 |
| --- | --- |
| 提示"没有开启调试端口" | 装的是商店 UWP 版，换成官网版 |
| 面板没出现 | 从**原始图标**启动了客户端，请改用「哔哩哔哩 加速」 |
| 提示找不到客户端 | 编辑 `config.json` 里的 `clientExe` |
| 面板突然消失 | 客户端页面被刷新过；重启客户端即可 |
| 播放页黑屏 | 刷新过播放页会导致不自动续播（客户端自身行为），重启客户端即可 |

## 卸载

双击 `uninstall.cmd`，或者执行：

```
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

会删除快捷方式、开机启动项和程序目录。

## 说明

- 注入通过 Chromium 的 DevTools 协议完成，不修改客户端文件，客户端升级不受影响
- 调试端口只监听本机 `127.0.0.1`；它在你用加速快捷方式启动的**整个客户端生命周期内**都处于开启状态，退出客户端后才关闭
- 脚本源文件（`injector.py`、`bilibili-accelerator.user.js`）都打包在目录里，可自行查看

## 可能的拦截提示

因为这个工具会向客户端进程注入脚本，Windows Defender / 杀毒软件可能提示"可疑行为"，
属于预期现象（它只在本机、只对哔哩哔哩客户端生效）。如果被拦截，选择"允许"即可。
