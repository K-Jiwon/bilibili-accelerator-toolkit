#!/usr/bin/env python3
"""Keep the Bilibili Accelerator userscript injected in the Bilibili desktop client.

The desktop client is Electron. When it is started with
``--remote-debugging-port=9223`` we can attach over the Chrome DevTools
Protocol, run the userscript in every frame context, and keep the session
attached so that new documents, iframes and player windows are covered too.
"""

from __future__ import annotations

import argparse
import json
import socket
import time
import urllib.request

def _load_websocket():
    """Return (WebSocketTimeoutException, create_connection).

    Prefers the bundled zero-dependency implementation. The file is loaded by
    path as a fallback because the embeddable Windows Python uses a ._pth file
    and does not necessarily put the script directory on sys.path.
    """
    try:
        from wsclient import WebSocketTimeoutException, create_connection

        return WebSocketTimeoutException, create_connection
    except ImportError:
        pass

    import importlib.util
    import os

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wsclient.py")
    if os.path.exists(path):
        spec = importlib.util.spec_from_file_location("wsclient", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.WebSocketTimeoutException, module.create_connection

    import websocket  # type: ignore  # last resort: websocket-client

    return websocket.WebSocketTimeoutException, websocket.create_connection


WebSocketTimeoutException, create_connection = _load_websocket()

DEFAULT_MATCH = "bilipc.bilibili.com"

# The upstream panel uses backdrop-filter blur(18px) over the video plus a
# canvas speed graph redrawn on a timer. On weaker machines that is enough to
# make playback stutter, so we can tone it down without touching the script:
#   full  -> leave the UI alone
#   lite  -> keep the panel, drop the blur and the canvas
#   off   -> hide the UI completely (rewriting still works)
UI_PRELUDE = """(function () {
  var MODE = %s;
  var LITE_CSS = ".ba-panel{backdrop-filter:none !important;-webkit-backdrop-filter:none !important;box-shadow:none !important}.ba-spd-canvas{display:none !important}";
  function apply() {
    var host = document.getElementById("bili-accelerator-button");
    if (!host) { return false; }
    if (MODE === "off") {
      host.style.display = "none";
      host.setAttribute("aria-hidden", "true");
      return true;
    }
    var root = host.shadowRoot;
    if (!root) { return false; }
    if (!root.querySelector("style[data-bili-lite]")) {
      var style = document.createElement("style");
      style.setAttribute("data-bili-lite", "1");
      style.textContent = LITE_CSS;
      root.appendChild(style);
    }
    return true;
  }
  function start() {
    apply();
    try {
      new MutationObserver(apply).observe(document.documentElement, { childList: true, subtree: true });
    } catch (error) {}
    var tries = 0;
    var timer = setInterval(function () {
      if (apply() || ++tries > 40) { clearInterval(timer); }
    }, 250);
  }
  if (document.documentElement) { start(); } else { document.addEventListener("DOMContentLoaded", start); }
})();
"""


def acquire_singleton(port: int):
    """Keep a loopback socket so only one injector per port can run."""
    lock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        lock.bind(("127.0.0.1", port + 1))
        lock.listen(1)
    except OSError:
        lock.close()
        return None
    return lock


def http_json(port: int, path: str, timeout: float = 3.0):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=timeout) as resp:
        return json.load(resp)


class Injector:
    def __init__(
        self,
        port: int,
        script: str,
        log,
        match_hosts: list[str],
        check_ua: bool = True,
    ) -> None:
        self.port = port
        self.script = script
        self.log = log
        self.match_hosts = match_hosts
        self.mid = 0
        self.ready_sessions: set[str] = set()
        self.known_targets: dict[str, str] = {}
        self.session_targets: dict[str, str] = {}
        self.pending_attaches: dict[int, str] = {}
        self.attach_attempts: dict[str, float] = {}

        version = http_json(port, "/json/version")
        if check_ua:
            user_agent = f"{version.get('User-Agent', '')} {version.get('Browser', '')}".lower()
            if "bilibili" not in user_agent:
                raise RuntimeError(
                    f"port {port} is not the Bilibili client "
                    f"(Browser={version.get('Browser')!r}); "
                    "change the 'port' setting in config.json"
                )
        self.ws = create_connection(version["webSocketDebuggerUrl"], timeout=20)
        self.send("Target.setDiscoverTargets", {"discover": True})

    def matches(self, url: str) -> bool:
        return any(host in url for host in self.match_hosts)

    # ---- low level -------------------------------------------------------
    def send(self, method: str, params: dict | None = None, session_id: str | None = None,
             timeout: float | None = None) -> int:
        # Fire-and-forget: replies and events are processed by the main loop.
        # Waiting for replies here re-enters the message loop and can swallow
        # the outer command's response, which used to add ~10s of latency.
        self.mid += 1
        message = {"id": self.mid, "method": method, "params": params or {}}
        if session_id:
            message["sessionId"] = session_id
        self.ws.send(json.dumps(message))
        return self.mid

    # ---- message handling ------------------------------------------------
    def handle(self, message: dict) -> None:
        method = message.get("method")
        params = message.get("params") or {}
        session_id = message.get("sessionId")

        if method in ("Target.targetCreated", "Target.targetInfoChanged"):
            info = params.get("targetInfo") or {}
            target_id = info.get("targetId")
            url = info.get("url", "")
            if target_id and info.get("type") in ("page", "iframe"):
                self.known_targets[target_id] = url
            self.attach_if_needed(target_id, url)
        elif method == "Target.attachedToTarget":
            info = params.get("targetInfo") or {}
            sid = params.get("sessionId")
            target_id = info.get("targetId", "")
            if sid:
                self.session_targets[sid] = target_id
            if target_id:
                self.attach_attempts.pop(target_id, None)
            if sid and self.matches(info.get("url", "")):
                self.setup_session(sid)
        elif method == "Runtime.executionContextCreated":
            if session_id in self.ready_sessions:
                context = params.get("context") or {}
                if context.get("auxData", {}).get("isDefault"):
                    self.inject_context(session_id, context.get("id"))
        elif method == "Runtime.executionContextsCleared":
            pass
        elif method == "Target.detachedFromTarget":
            sid = params.get("sessionId")
            target_id = params.get("targetId") or self.session_targets.pop(sid, None)
            if sid:
                self.ready_sessions.discard(sid)
            if target_id:
                self.log(f"detached target {target_id[:8]}")
        elif method == "Target.targetDestroyed":
            target_id = params.get("targetId")
            if target_id:
                self.known_targets.pop(target_id, None)
                self.attach_attempts.pop(target_id, None)
                for sid, mapped in list(self.session_targets.items()):
                    if mapped == target_id:
                        self.session_targets.pop(sid, None)
                        self.ready_sessions.discard(sid)

    def target_has_session(self, target_id: str) -> bool:
        return any(mapped == target_id for mapped in self.session_targets.values())

    def attach_if_needed(self, target_id: str | None, url: str) -> None:
        if not target_id or not self.matches(url):
            return
        # Attachment state is derived from live sessions, so a failed
        # attachToTarget (error response, dying target, another debugger)
        # gets retried by reconcile() instead of blacklisting the target
        # until the injector restarts.
        if self.target_has_session(target_id):
            return
        now = time.time()
        if now - self.attach_attempts.get(target_id, 0.0) < 15:
            return
        self.attach_attempts[target_id] = now
        self.log(f"attach target {url[:90]}")
        message_id = self.send("Target.attachToTarget", {"targetId": target_id, "flatten": True})
        self.pending_attaches[message_id] = target_id

    def handle_response(self, message: dict) -> None:
        message_id = message.get("id")
        target_id = self.pending_attaches.pop(message_id, None)
        error = message.get("error")
        if not error:
            return
        detail = error.get("message", str(error)) if isinstance(error, dict) else str(error)
        where = f" target={target_id[:8]}" if target_id else ""
        self.log(f"command failed:{where} {detail}")

    def reconcile(self) -> None:
        """Re-attach known targets that lost their session (periodic safety net)."""
        for target_id, url in list(self.known_targets.items()):
            self.attach_if_needed(target_id, url)

    # ---- injection -------------------------------------------------------
    def setup_session(self, session_id: str) -> None:
        if session_id in self.ready_sessions:
            return
        self.ready_sessions.add(session_id)
        self.send("Page.enable", session_id=session_id)
        self.send("Runtime.enable", session_id=session_id)
        self.send(
            "Page.addScriptToEvaluateOnNewDocument",
            {"source": self.script},
            session_id=session_id,
        )
        self.log(f"session ready {session_id[:8]}")

    def inject_context(self, session_id: str, context_id) -> None:
        if context_id is None:
            return
        self.send(
            "Runtime.evaluate",
            {"expression": self.script, "contextId": context_id},
            session_id=session_id,
        )

    # ---- main loop -------------------------------------------------------
    def run(self) -> None:
        self.log("injector attached to client devtools")
        while True:
            try:
                self.ws.settimeout(10)
                message = json.loads(self.ws.recv())
            except WebSocketTimeoutException:
                self.reconcile()
                continue
            except Exception as error:
                self.log(f"devtools connection closed: {error}")
                return
            if "id" in message:
                try:
                    self.handle_response(message)
                except Exception as error:
                    self.log(f"response handling error: {error}")
                continue
            try:
                self.handle(message)
            except Exception as error:
                self.log(f"handle error: {error}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=9223)
    parser.add_argument("--script", required=True)
    parser.add_argument(
        "--match",
        default=DEFAULT_MATCH,
        help="comma separated URL substrings that identify client pages",
    )
    parser.add_argument("--logfile", default="", help="append log lines to this file")
    parser.add_argument(
        "--skip-ua-check",
        action="store_true",
        help="connect even if the devtools endpoint does not look like the Bilibili client",
    )
    parser.add_argument(
        "--ui-mode",
        choices=("full", "lite", "off"),
        default="full",
        help="full keeps the panel as-is, lite removes the blur/canvas, off hides the UI",
    )
    args = parser.parse_args()

    with open(args.script, encoding="utf-8") as handle:
        script = handle.read()
    if args.ui_mode != "full":
        script = (UI_PRELUDE % json.dumps(args.ui_mode)) + "\n" + script

    lock = acquire_singleton(args.port)
    if lock is None:
        # Another injector already owns this port; nothing to do.
        return 0

    match_hosts = [item.strip() for item in args.match.split(",") if item.strip()]
    if not match_hosts:
        match_hosts = [DEFAULT_MATCH]

    def log(text: str) -> None:
        line = f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {text}"
        print(line, flush=True)
        if args.logfile:
            try:
                with open(args.logfile, "a", encoding="utf-8") as handle:
                    handle.write(line + "\n")
            except OSError:
                pass

    last_error = None
    last_error_at = 0.0
    while True:
        try:
            injector = Injector(
                args.port,
                script,
                log,
                match_hosts,
                check_ua=not args.skip_ua_check,
            )
            injector.run()
            last_error = None
        except Exception as error:
            message = str(error)
            now = time.time()
            # Log the first failure and then at most once every 5 minutes,
            # so an idle machine does not grow the log by ~2 MB/day.
            if message != last_error or now - last_error_at >= 300:
                log(f"waiting for client devtools: {message}")
                last_error = message
                last_error_at = now
        time.sleep(2)


if __name__ == "__main__":
    raise SystemExit(main())
