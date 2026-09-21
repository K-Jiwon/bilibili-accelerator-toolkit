"""Minimal RFC 6455 WebSocket client built on the Python standard library.

Only what the Chrome DevTools Protocol needs: ws:// (no TLS), client-side
masking, text frames, fragmentation, ping/pong and close handling. Keeping it
dependency-free means the installer never has to run pip and therefore works
offline and on any Python >= 3.8 (including the 3.9 that ships with the macOS
command line tools).
"""

from __future__ import annotations

import base64
import os
import socket
import ssl
import struct
import urllib.parse

OP_CONT = 0x0
OP_TEXT = 0x1
OP_BINARY = 0x2
OP_CLOSE = 0x8
OP_PING = 0x9
OP_PONG = 0xA


class WebSocketException(Exception):
    """Raised when the connection breaks or the handshake fails."""


class WebSocketTimeoutException(WebSocketException):
    """Raised by recv() when no complete frame arrives in time."""


class WebSocket:
    def __init__(self, sock: socket.socket, timeout: float | None = None) -> None:
        self.sock = sock
        self.timeout = timeout
        self._in = bytearray()
        self._message = bytearray()
        self._message_opcode: int | None = None
        sock.settimeout(timeout)

    # -- public API compatible with the parts of websocket-client we use ----
    def settimeout(self, value: float | None) -> None:
        self.timeout = value
        self.sock.settimeout(value)

    def gettimeout(self):
        return self.timeout

    def send(self, text: str) -> None:
        if isinstance(text, bytes):
            self._send_frame(OP_BINARY, text)
        else:
            self._send_frame(OP_TEXT, text.encode("utf-8"))

    def recv(self) -> str:
        while True:
            frame = self._parse_frame()
            if frame is None:
                self._fill()
                continue
            fin, opcode, payload = frame
            if opcode == OP_PING:
                self._send_frame(OP_PONG, payload)
                continue
            if opcode == OP_PONG:
                continue
            if opcode == OP_CLOSE:
                raise WebSocketException("connection closed by peer")
            if opcode in (OP_TEXT, OP_BINARY):
                self._message = bytearray(payload)
                self._message_opcode = opcode
            elif opcode == OP_CONT:
                self._message += payload
            else:
                continue
            if fin:
                data = bytes(self._message)
                self._message = bytearray()
                self._message_opcode = None
                return data.decode("utf-8", "replace")

    def close(self) -> None:
        try:
            self._send_frame(OP_CLOSE, struct.pack(">H", 1000))
        except Exception:
            pass
        try:
            self.sock.close()
        except Exception:
            pass

    # -- internals ---------------------------------------------------------
    def _send_frame(self, opcode: int, payload: bytes) -> None:
        header = bytearray()
        header.append(0x80 | opcode)
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", length)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", length)
        mask = os.urandom(4)
        header += mask
        if payload:
            payload = bytes(byte ^ mask[index & 3] for index, byte in enumerate(payload))
        self.sock.sendall(bytes(header) + payload)

    def _fill(self) -> None:
        try:
            chunk = self.sock.recv(65536)
        except socket.timeout:
            # Any bytes already buffered stay buffered, so a timeout in the
            # middle of a frame does not corrupt the stream.
            raise WebSocketTimeoutException("timed out")
        except OSError as error:
            raise WebSocketException(str(error))
        if not chunk:
            raise WebSocketException("connection closed")
        self._in += chunk

    def _parse_frame(self):
        buffer = self._in
        if len(buffer) < 2:
            return None
        first, second = buffer[0], buffer[1]
        fin = bool(first & 0x80)
        opcode = first & 0x0F
        masked = bool(second & 0x80)
        length = second & 0x7F
        offset = 2
        if length == 126:
            if len(buffer) < 4:
                return None
            length = struct.unpack(">H", bytes(buffer[2:4]))[0]
            offset = 4
        elif length == 127:
            if len(buffer) < 10:
                return None
            length = struct.unpack(">Q", bytes(buffer[2:10]))[0]
            offset = 10
        if masked:
            if len(buffer) < offset + 4:
                return None
            offset += 4
        if len(buffer) < offset + length:
            return None
        payload = bytes(buffer[offset : offset + length])
        if masked:
            mask = bytes(buffer[offset - 4 : offset])
            payload = bytes(byte ^ mask[index & 3] for index, byte in enumerate(payload))
        del buffer[: offset + length]
        return fin, opcode, payload


def create_connection(url: str, timeout: float | None = None, **_ignored) -> WebSocket:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in ("ws", "wss"):
        raise WebSocketException(f"unsupported scheme: {parsed.scheme}")

    host = parsed.hostname
    if not host:
        raise WebSocketException(f"invalid websocket url: {url}")
    port = parsed.port or (443 if parsed.scheme == "wss" else 80)
    path = parsed.path or "/"
    if parsed.query:
        path += "?" + parsed.query

    sock = socket.create_connection((host, port), timeout=timeout)
    if parsed.scheme == "wss":
        sock = ssl.create_default_context().wrap_socket(sock, server_hostname=host)

    key = base64.b64encode(os.urandom(16)).decode("ascii")
    request = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    )
    sock.sendall(request.encode("ascii"))

    raw = b""
    while b"\r\n\r\n" not in raw:
        try:
            chunk = sock.recv(4096)
        except socket.timeout:
            raise WebSocketTimeoutException("handshake timed out")
        if not chunk:
            raise WebSocketException("handshake failed: connection closed")
        raw += chunk

    head, _, extra = raw.partition(b"\r\n\r\n")
    status_line = head.split(b"\r\n", 1)[0]
    if b" 101 " not in status_line + b" ":
        raise WebSocketException(f"handshake rejected: {status_line.decode('latin-1')}")

    websocket = WebSocket(sock, timeout=timeout)
    if extra:
        websocket._in += extra
    return websocket
