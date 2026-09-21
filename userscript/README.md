# userscript

`bilibili-accelerator.user.js` 来自上游项目 **Bilibili Accelerator**：

- 仓库：https://github.com/realzza/bilibili-accelerator
- GreasyFork：https://greasyfork.org/scripts/582026
- 作者：realzza
- 许可证：MIT

本仓库**原样分发**该脚本（未做修改），所有权利归原作者所有。

## 更新脚本

1. 从上面对应的仓库/GreasyFork 下载最新版
2. 覆盖 `userscript/bilibili-accelerator.user.js`
3. 重启注入器使新脚本生效：

   - macOS：

     ```bash
     launchctl kickstart -k "gui/$(id -u)/com.local.bili-injector"
     ```

   - Windows：重启电脑，或从「哔哩哔哩 加速」重新启动客户端

## 修改脚本（可选）

如果你想在这个脚本基础上做自己的改动，建议：

1. Fork 上游仓库，在自己的 fork 里改
2. 在本仓库里替换为你的版本，并在 `NOTICE` 中保留原始署名
3. 注意保持 MIT 许可证声明完整
