# 原理与实现细节

## 1. 为什么客户端可以被注入

哔哩哔哩桌面客户端是 **Electron** 应用（实测 macOS 版为 Electron 22.3.27 /
Chromium 108，Windows 官网版同源）。它的结构是：

```
Electron 主进程（Node.js）
  ├── 窗口 / 下载 / 更新 / 本地服务
  └── 本地 HTTP 服务（57024 等端口）
        ▲
        │ Chromium 启动参数：--host-rules=MAP bilipc.bilibili.com localhost:57024
        │
  Chromium 渲染层（网页）
    · bilipc.bilibili.com/index.html    主界面
    · bilipc.bilibili.com/player.html   播放器
    · 若干 iframe
```

三个关键事实：

1. **界面和播放器都是网页**，播放逻辑由页面里的 JS 完成。
2. 客户端用 `--host-rules` 把 `bilipc.bilibili.com` 映射到本机服务，因此页面仍然
   是 bilibili.com 的 origin，Cookie / localStorage / CORS 都正常。
3. Chromium 自带 DevTools 协议（CDP）。只要启动时加上
   `--remote-debugging-port=<port>`，外部程序就能连上去查看页面、执行 JS。

所以"注入脚本"本质上是：**用一个外部程序，通过 CDP 把脚本塞进客户端的页面里**，
和浏览器里的油猴扩展是同一类做法，只是客户端不加载扩展，我们改成从外部注入。

## 2. 注入器做了什么

`injector.py` 的流程：

```
轮询 http://127.0.0.1:<port>/json/version     （等待客户端带调试端口启动）
  └── 连接 browser WebSocket
        ├── Target.setDiscoverTargets  → 发现所有页面/iframe
        ├── 命中目标（URL 含 bilipc.bilibili.com）
        │     ├── Target.attachToTarget（flatten 会话）
        │     ├── Page.enable / Runtime.enable
        │     ├── Page.addScriptToEvaluateOnNewDocument(script)   ← 之后新文档自动注入
        │     └── 对已存在的执行上下文执行 Runtime.evaluate(script)
        └── 持续监听 Runtime.executionContextCreated
              └── 新 iframe / 新窗口出现时立刻注入
```

要点：

- 用 `flatten: true` 的会话管理多个目标（主界面、播放器窗口、iframe）。
- 用 `addScriptToEvaluateOnNewDocument` 覆盖"页面脚本之前"的时机，等价于油猴的
  `@run-at document-start`。
- 会话一旦断开，注入注册就失效——所以注入器必须常驻（macOS 用 LaunchAgent，
  Windows 用启动项 + 启动器兜底）。

## 3. 脚本为什么能加速

上游脚本做的事：

1. 挂钩 `JSON.parse` / `fetch` / `XMLHttpRequest`，拦截所有播放接口响应。
2. 把媒体 URL 分类：正常 upos 镜像 / MCDN / PCDN（`szbdyd`、`mountaintoys`、
   `nexusedgeio`、`*-302*`、IP 直连、非标准端口）/ Akamai / 直播流。
3. 对慢的、P2P 的地址改写成健康镜像；MCDN 走官方代理；直播流跳过。
4. 自动模式会用真实签名片段测速，按吞吐排名挑选最快域名；卡顿时可实时换线。

之所以能直接换域名，是因为 B 站播放签名（`upsig`）只绑定**路径和参数**，不含域名。

## 4. 为什么不直接改 hosts

早期方案尝试过：

- 用 hosts 把慢域名指向快节点 IP → 失败，因为 TLS 证书只覆盖它自己的域名
  （`SSL: no alternative certificate subject name matches`）。
- 用本地反向代理（mitmproxy）+ hosts 做域名接管 → 可行，但只能处理"域名"级别的
  替换，处理不了 IP 直连的 PCDN，也无法做逐视频的自动排名和卡顿切换。
- 系统代理 → 客户端自己设置了直连策略，会绕过系统 PAC/代理。

最终采用注入方案：直接在客户端内部改写播放地址，覆盖最全，且不影响其他应用。

## 5. 其他用途

同样的机制可以扩展到：

- 播放增强：锁定清晰度/编码、自动跳过片头片尾、弹幕过滤、状态 HUD
- 数据与自动化：观看记录导出、追更提醒、弹幕/字幕分析
- 通用场景：任何 Electron 应用（VS Code、Notion、Discord 等）都可以用 CDP
  注入脚本、做 UI 自动化或调试

## 6. 风险提示

- 调试端口没有鉴权，本机任何程序都能连上并注入代码；只在使用加速启动器时开启，
  并且只监听 `127.0.0.1`
- 注入的脚本拥有该页面的登录态访问能力，只运行可信脚本
- 不要用于付费内容或 DRM 绕过
