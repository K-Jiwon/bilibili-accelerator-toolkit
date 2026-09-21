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
import time
import urllib.request

import websocket

DEFAULT_MATCH = "bilipc.bilibili.com"


def http_json(port: int, path: str, timeout: float = 3.0):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=timeout) as resp:
        return json.load(resp)


class Injector:
    def __init__(self, port: int, script: str, log, match_hosts: list[str]) -> None:
        self.port = port
        self.script = script
        self.log = log
        self.match_hosts = match_hosts
        self.mid = 0
        self.attached_targets: set[str] = set()
        self.ready_sessions: set[str] = set()

        version = http_json(port, "/json/version")
        self.ws = websocket.create_connection(version["webSocketDebuggerUrl"], timeout=20)
        self.send("Target.setDiscoverTargets", {"discover": True})

    def matches(self, url: str) -> bool:
        return any(host in url for host in self.match_hosts)

    # ---- low level -------------------------------------------------------
    def send(self, method: str, params: dict | None = None, session_id: str | None = None,
             timeout: float | None = None):
        # Fire-and-forget: replies and events are processed by the main loop.
        # Waiting for replies here re-enters the message loop and can swallow
        # the outer command's response, which used to add ~10s of latency.
        self.mid += 1
        message = {"id": self.mid, "method": method, "params": params or {}}
        if session_id:
            message["sessionId"] = session_id
        self.ws.send(json.dumps(message))

    # ---- message handling ------------------------------------------------
    def handle(self, message: dict) -> None:
        method = message.get("method")
        params = message.get("params") or {}
        session_id = message.get("sessionId")

        if method in ("Target.targetCreated", "Target.targetInfoChanged"):
            info = params.get("targetInfo") or {}
            target_id = info.get("targetId")
            url = info.get("url", "")
            if (
                target_id
                and info.get("type") in ("page", "iframe")
                and self.matches(url)
                and target_id not in self.attached_targets
            ):
                self.attached_targets.add(target_id)
                self.log(f"attach target {info.get('type')} {url[:90]}")
                self.send("Target.attachToTarget", {"targetId": target_id, "flatten": True})
        elif method == "Target.attachedToTarget":
            info = params.get("targetInfo") or {}
            sid = params.get("sessionId")
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
            if sid:
                self.ready_sessions.discard(sid)

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
            except websocket.WebSocketTimeoutException:
                continue
            except Exception as error:
                self.log(f"devtools connection closed: {error}")
                return
            if "id" in message:
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
    args = parser.parse_args()

    with open(args.script, encoding="utf-8") as handle:
        script = handle.read()

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

    while True:
        try:
            injector = Injector(args.port, script, log, match_hosts)
            injector.run()
        except Exception as error:
            log(f"waiting for client devtools: {error}")
        time.sleep(2)


if __name__ == "__main__":
    raise SystemExit(main())
