#!/bin/zsh
# 哔哩哔哩 加速 · macOS 安装脚本
#
# 可以用两种方式运行：
#   1) 在仓库里：  ./macos/install.sh
#   2) 在安装器 App 里：由 App 自动调用（文件会放在 App 的 Resources 里）
#
# 安装内容全部在用户目录，不需要管理员密码：
#   ~/.bili-accelerator/                程序 + 日志
#   ~/Applications/哔哩哔哩 加速.app     启动器
#   ~/Library/LaunchAgents/…            开机自启的注入服务
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../injector.py" ]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT_DIR="$SCRIPT_DIR"
fi

DIR="$HOME/.bili-accelerator"
# 优先装到系统级 /Applications（Finder 侧边栏的「应用程序」就在这儿），
# 没有写权限时退回用户级 ~/Applications。
if [ -w /Applications ]; then
  APPS_DIR="/Applications"
else
  APPS_DIR="$HOME/Applications"
fi
APP="$APPS_DIR/哔哩哔哩 加速.app"
OTHER_APP="$HOME/Applications/哔哩哔哩 加速.app"
AGENT="$HOME/Library/LaunchAgents/com.local.bili-injector.plist"
BILI_APP="${BILI_APP:-/Applications/哔哩哔哩.app}"
PORT="${BILI_PORT:-9223}"
WS_VERSION="1.9.2"           # 需要 Python >= 3.10
WS_VERSION_FALLBACK="1.9.0"  # 需要 Python >= 3.9

# 优先使用较新的 python3（Homebrew），因为它能装上固定版本的依赖；
# 只有系统自带的 3.9 时也能工作，会自动回退到兼容版本。
pick_python() {
  local candidate
  for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 "$(command -v python3 2>/dev/null)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

PYTHON="${PYTHON:-$(pick_python || true)}"

say() { printf '%s\n' "$*"; }
fail() { say ""; say "❌ $*"; exit 1; }

say "=================================="
say "  哔哩哔哩 加速 · 安装 (macOS)"
say "=================================="
say ""

[ -d "$BILI_APP" ] || fail "没找到客户端：$BILI_APP （请把客户端放在 /Applications 下）"
[ -n "$PYTHON" ] || fail "缺少 python3。请在终端运行：xcode-select --install"

say "① 复制程序文件…"
mkdir -p "$DIR" "$APPS_DIR" "$HOME/Library/LaunchAgents"
cp "$ROOT_DIR/injector.py" "$DIR/injector.py"
cp "$ROOT_DIR/userscript/bilibili-accelerator.user.js" "$DIR/bilibili-accelerator.user.js"
chmod 755 "$DIR/injector.py"

PY_VER="$("$PYTHON" -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])' 2>/dev/null || echo "unknown")"
say "② 准备运行环境（Python $PY_VER，第一次需要联网，约 10 秒）…"
if [ ! -d "$DIR/venv" ]; then
  "$PYTHON" -m venv "$DIR/venv"
fi
if ! "$DIR/venv/bin/pip" install --quiet --upgrade pip "websocket-client==${WS_VERSION}" \
     >/dev/null 2>&1; then
  say "   Python $PY_VER 装不了 ${WS_VERSION}（它需要 3.10+），自动改用 ${WS_VERSION_FALLBACK}…"
  if ! "$DIR/venv/bin/pip" install --quiet --upgrade pip \
       "websocket-client==${WS_VERSION_FALLBACK}" >/dev/null 2>&1; then
    fail "依赖安装失败。可以试试安装新版 Python 后重跑：
   brew install python@3.12"
  fi
fi
if ! "$DIR/venv/bin/python" -c "import websocket" >/dev/null 2>&1; then
  fail "websocket-client 没有安装成功，请把上面的错误信息发给开发者。"
fi

say "③ 创建启动器…"
if [ -e "$APP" ]; then
  mv "$APP" "$DIR/old-launcher.$(date +%s).app"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
sed -e "s|__DIR__|$DIR|g" \
    -e "s|__BILI_APP__|$BILI_APP|g" \
    -e "s|__PORT__|$PORT|g" \
    "$ROOT_DIR/macos/launcher.sh.template" > "$APP/Contents/MacOS/launcher"
chmod 755 "$APP/Contents/MacOS/launcher"
sed -e "s|__NAME__|哔哩哔哩 加速|g" \
    "$ROOT_DIR/macos/Info.plist.template" > "$APP/Contents/Info.plist"
if [ -f "$ROOT_DIR/assets/icon.icns" ]; then
  cp "$ROOT_DIR/assets/icon.icns" "$APP/Contents/Resources/appicon.icns"
fi
/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

# 避免两个「哔哩哔哩 加速.app」同时存在造成混乱
if [ "$APPS_DIR" = "/Applications" ] && [ -f "$OTHER_APP/Contents/MacOS/launcher" ]; then
  rm -rf "$OTHER_APP"
  say "   （已清理用户级的旧副本）"
fi

say "④ 注册后台服务…"
sed -e "s|__PYTHON__|$DIR/venv/bin/python|g" \
    -e "s|__INJECTOR__|$DIR/injector.py|g" \
    -e "s|__SCRIPT__|$DIR/bilibili-accelerator.user.js|g" \
    -e "s|__PORT__|$PORT|g" \
    -e "s|__LOG__|$DIR/injector.log|g" \
    -e "s|__ERRLOG__|$DIR/injector.err.log|g" \
    "$ROOT_DIR/macos/com.local.bili-injector.plist.template" > "$AGENT"

UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/com.local.bili-injector" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$UID_NUM" "$AGENT" 2>/dev/null || true
launchctl enable "gui/$UID_NUM/com.local.bili-injector" 2>/dev/null || true
launchctl kickstart -k "gui/$UID_NUM/com.local.bili-injector" >/dev/null 2>&1 || true

say ""
say "✅ 安装完成！接下来这样做："
say ""
say "   1) 把「哔哩哔哩 加速」图标拖到 Dock（图钉）上"
say "      $APP"
say "   2) 以后都用它启动客户端（第一次会自动重启一次客户端）"
say "   3) 客户端里出现小闪电 ⚡ 就说明成功了"
say ""
say "   日志：$DIR/injector.log"
say "   卸载：双击「卸载」或运行 ./macos/uninstall.sh"
