#!/usr/bin/env python3
"""BiliAccelerator launcher for Windows.

Runs with the bundled pythonw.exe so no console window ever appears, and it
does not need PowerShell or Windows Script Host:

  1. start the injector (it self-deduplicates)
  2. if the client already has a Bilibili devtools port, do nothing
  3. if the port belongs to another program, say so instead of failing quietly
  4. otherwise restart the client with --remote-debugging-port and wait

Errors are reported with a native message box.
"""

from __future__ import annotations

import ctypes
import json
import os
import subprocess
import sys
import time
import urllib.request

BASE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE, "config.json")
LOG_PATH = os.path.join(BASE, "launcher.log")

MB_ICONERROR = 0x10
MB_ICONWARNING = 0x30
MB_ICONINFORMATION = 0x40
CREATE_NO_WINDOW = 0x08000000 if os.name == "nt" else 0


def log(message: str) -> None:
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as handle:
            handle.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {message}\n")
    except OSError:
        pass


def message_box(text: str, icon: int = MB_ICONINFORMATION) -> None:
    text = text + "\n\n（本工具完全免费开源；如果是花钱买到的，说明上当了，请立刻申请退款。）"
    if os.name != "nt":
        print(text)
        return
    try:
        ctypes.windll.user32.MessageBoxW(None, text, "哔哩哔哩 加速", icon)
    except Exception:
        pass


def load_config() -> dict:
    if not os.path.exists(CONFIG_PATH):
        return {}
    try:
        with open(CONFIG_PATH, encoding="utf-8-sig") as handle:
            return json.load(handle)
    except Exception as error:
        log(f"config.json 读取失败: {error}")
        return {}


def devtools_info(port: int, timeout: float = 2.0):
    try:
        with urllib.request.urlopen(
            f"http://127.0.0.1:{port}/json/version", timeout=timeout
        ) as response:
            return json.load(response)
    except Exception:
        return None


def is_bilibili(info) -> bool:
    if not info:
        return False
    text = f"{info.get('User-Agent', '')} {info.get('Browser', '')}".lower()
    return "bilibili" in text


def find_client(config: dict):
    exe = config.get("clientExe")
    if exe and os.path.exists(exe):
        return exe
    local = os.environ.get("LOCALAPPDATA", "")
    program_files = os.environ.get("ProgramFiles", "")
    program_files_x86 = os.environ.get("ProgramFiles(x86)", "")
    candidates = [
        os.path.join(local, "Programs", "bilibili", "哔哩哔哩.exe"),
        os.path.join(local, "Programs", "哔哩哔哩", "哔哩哔哩.exe"),
        os.path.join(local, "bilibili", "哔哩哔哩.exe"),
        os.path.join(program_files, "bilibili", "哔哩哔哩.exe"),
        os.path.join(program_files_x86, "bilibili", "哔哩哔哩.exe"),
    ]
    for candidate in candidates:
        if candidate and os.path.exists(candidate):
            return candidate
    return None


def start_injector(config: dict, port: int) -> None:
    pythonw = os.path.join(BASE, "python", "pythonw.exe")
    python = pythonw if os.path.exists(pythonw) else os.path.join(BASE, "python", "python.exe")
    if not os.path.exists(python):
        log("找不到自带的 python.exe")
        return
    command = [
        python,
        "-X",
        "utf8",
        os.path.join(BASE, "injector.py"),
        "--port",
        str(port),
        "--script",
        os.path.join(BASE, "bilibili-accelerator.user.js"),
        "--match",
        str(config.get("match") or "bilipc.bilibili.com"),
        "--logfile",
        os.path.join(BASE, "injector.log"),
        "--ui-mode",
        str(config.get("uiMode") or "lite"),
    ]
    if config.get("skipUaCheck"):
        command.append("--skip-ua-check")
    try:
        subprocess.Popen(command, creationflags=CREATE_NO_WINDOW, close_fds=True)
        log(f"已启动注入器（uiMode={config.get('uiMode') or 'lite'}）")
    except Exception as error:
        log(f"启动注入器失败: {error}")


def kill_client(exe: str) -> None:
    name = os.path.basename(exe)
    try:
        subprocess.run(
            ["taskkill", "/IM", name, "/F"],
            creationflags=CREATE_NO_WINDOW,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        log(f"已结束旧客户端进程: {name}")
    except Exception as error:
        log(f"结束客户端进程失败: {error}")


def main() -> int:
    config = load_config()
    port = int(config.get("port") or 9223)
    inject_only = "--inject-only" in sys.argv

    start_injector(config, port)
    if inject_only:
        return 0

    exe = find_client(config)
    if not exe:
        message_box(
            "没有找到哔哩哔哩客户端。\n\n"
            "请双击桌面的「哔哩哔哩 加速 诊断」生成诊断文件，"
            "或编辑安装目录下的 config.json，把 clientExe 改成完整路径。",
            MB_ICONWARNING,
        )
        return 1

    info = devtools_info(port)
    if is_bilibili(info):
        log("客户端已经带调试端口在运行")
        return 0
    if info:
        other = info.get("Browser") or "未知程序"
        message_box(
            f"端口 {port} 被其它程序占用了（{other}）。\n\n"
            "请编辑安装目录下的 config.json，把 port 改成别的值（例如 9333），"
            "然后重新从桌面快捷方式启动。",
            MB_ICONWARNING,
        )
        return 1

    kill_client(exe)
    time.sleep(1.5)

    try:
        subprocess.Popen([exe, f"--remote-debugging-port={port}"], close_fds=True)
        log(f"已启动客户端，端口 {port}")
    except Exception as error:
        log(f"启动客户端失败: {error}")
        message_box(f"启动客户端失败：{error}", MB_ICONERROR)
        return 1

    for _ in range(40):
        info = devtools_info(port)
        if is_bilibili(info):
            log("加速已生效")
            return 0
        time.sleep(0.5)

    if devtools_info(port):
        message_box(
            f"端口 {port} 被其它程序占用了。\n\n"
            "请编辑安装目录下的 config.json，把 port 改成别的值（例如 9333）。",
            MB_ICONWARNING,
        )
    else:
        message_box(
            "客户端已启动，但没有开启调试端口。\n\n"
            "可能你安装的是微软商店（UWP）版本，那种版本不支持注入。\n"
            "请使用哔哩哔哩官网下载的电脑版客户端。\n\n"
            "如果确认是官网版本，请双击「哔哩哔哩 加速 诊断」并把结果发出来。",
            MB_ICONWARNING,
        )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
