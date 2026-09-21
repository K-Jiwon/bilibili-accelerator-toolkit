# BiliAccelerator Toolkit

Injects the [Bilibili Accelerator](https://github.com/realzza/bilibili-accelerator)
userscript into the Bilibili **desktop client**, giving the client the same
behaviour the script provides in a browser:

- automatic CDN probing and switching to the fastest host
- filtering out slow PCDN / MCDN nodes (the main cause of buffering abroad)
- live host rotation when playback stalls
- the script's own panel inside the client (speed readout, server/mode)

The client itself is not modified, so client updates keep working.

## Platform support

| Platform | Status | Notes |
| --- | --- | --- |
| macOS | ✅ | Official `哔哩哔哩.app` (Electron based) |
| Windows | ✅ | Official desktop client (Electron based) |
| Microsoft Store (UWP) | ❌ | Not Chromium, cannot be injected |
| iOS / Android | ❌ | Native apps; see the alternatives below |

## Install (Windows)

1. Download `BiliAccelerator-Windows.zip` from
   [Releases](../../releases) — it is self-contained, no Python needed.
2. Unzip it and double-click `install.cmd`.
3. Launch the client from the new **「哔哩哔哩 加速」** shortcut.

The first launch restarts the client once so it picks up the debugging port.
Detailed notes: [windows/README.md](windows/README.md).

## Install (macOS)

```bash
git clone https://github.com/<you>/bilibili-accelerator-toolkit.git
cd bilibili-accelerator-toolkit
./macos/install.sh
```

Then launch the client from `~/Applications/哔哩哔哩 加速.app`.

Uninstall with `./macos/uninstall.sh`.

## How it works

The desktop client is Electron (Chromium + Node). When it is started with
`--remote-debugging-port=<port>`, `injector.py` attaches over the Chrome
DevTools Protocol, installs the userscript into every page/frame context, and
keeps the session attached so new documents and player windows are covered.
The userscript then rewrites the CDN host in the playurl responses.

More detail: [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) (Chinese).

## Caveats

- Only the official Electron-based client is supported; the Microsoft Store
  (UWP) build has no Chromium and cannot be injected.
- The debugging port is loopback-only (`127.0.0.1`) but stays open for the
  whole lifetime of the client — it closes when the client exits. Don't use
  the accelerated launcher if you don't want that port.
- Do not manually refresh the client's player page: the client does not
  auto-resume after a reload (reproducible without injection). Restart the
  client to recover.
- Injected scripts can read the page's login state, so only use scripts you
  trust.
- Network-optimisation only; no paid-content or DRM bypassing.

## Other platforms

- **Android**: no injection into the official app without root; options are an
  LSPosed module (e.g. BiliRoaming, which also has CDN settings), an
  open-source third-party client, or a local DNS/VPN app that pins the CDN
  domain to a faster IP (same-hostname only).
- **iOS**: not possible for the native app. Use Safari with a userscript
  extension (Userscripts / Stay) on the mobile web player.

## Credits and license

- Upstream userscript: [realzza/bilibili-accelerator](https://github.com/realzza/bilibili-accelerator) (MIT, redistributed unmodified)
- `wsclient.py` is a tiny WebSocket client implemented with the Python standard
  library only, so the installer never runs pip and works offline
- This project: MIT — see [LICENSE](LICENSE) and [NOTICE](NOTICE)
