#!/usr/bin/env python3
"""Generate the project icon (PNG / ICO / ICNS).

The artwork is generated from scratch (rounded square + lightning bolt) so the
repository does not need to redistribute any third-party logo.
"""

from __future__ import annotations

import os
import struct
import sys
import zlib

BASE = 1024
SIZES = (16, 32, 48, 64, 128, 256, 512)

BOLT = (
    (0.58, 0.09),
    (0.27, 0.56),
    (0.46, 0.56),
    (0.39, 0.93),
    (0.73, 0.44),
    (0.52, 0.44),
)


def write_png(path: str, width: int, height: int, rgba: bytearray) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw += rgba[y * stride : (y + 1) * stride]

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def render_base() -> bytearray:
    size = BASE
    pixels = bytearray(size * size * 4)
    radius = size * 0.23
    margin = size * 0.06
    left, top = margin, margin
    right, bottom = size - margin, size - margin

    def inside_round_rect(x: float, y: float) -> bool:
        if x < left or x > right or y < top or y > bottom:
            return False
        cx = min(max(x, left + radius), right - radius)
        cy = min(max(y, top + radius), bottom - radius)
        dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= radius * radius

    def inside_bolt(x: float, y: float) -> bool:
        px, py = x / size, y / size
        inside = False
        j = len(BOLT) - 1
        for i in range(len(BOLT)):
            xi, yi = BOLT[i]
            xj, yj = BOLT[j]
            if (yi > py) != (yj > py):
                if px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                    inside = not inside
            j = i
        return inside

    for y in range(size):
        ratio = y / size
        base_r = int(0x11 + (0x0A - 0x11) * ratio)
        base_g = int(0xA1 + (0x6E - 0xA1) * ratio)
        base_b = int(0xD6 + (0xC8 - 0xD6) * ratio)
        row = y * size * 4
        for x in range(size):
            offset = row + x * 4
            if not inside_round_rect(x + 0.5, y + 0.5):
                continue
            if inside_bolt(x + 0.5, y + 0.5):
                pixels[offset : offset + 4] = bytes((255, 255, 255, 255))
            else:
                pixels[offset : offset + 4] = bytes((base_r, base_g, base_b, 255))
    return pixels


def downscale(source: bytearray, source_size: int, target_size: int) -> bytearray:
    factor = source_size // target_size
    out = bytearray(target_size * target_size * 4)
    for y in range(target_size):
        for x in range(target_size):
            r = g = b = a = 0
            for dy in range(factor):
                row = ((y * factor + dy) * source_size + x * factor) * 4
                for dx in range(factor):
                    offset = row + dx * 4
                    a += source[offset + 3]
                    r += source[offset] * source[offset + 3]
                    g += source[offset + 1] * source[offset + 3]
                    b += source[offset + 2] * source[offset + 3]
            count = factor * factor
            out_offset = (y * target_size + x) * 4
            alpha = a // count
            if alpha:
                out[out_offset] = min(255, r // a)
                out[out_offset + 1] = min(255, g // a)
                out[out_offset + 2] = min(255, b // a)
            out[out_offset + 3] = alpha
    return out


def build_ico(images: list[tuple[int, str]], path: str) -> None:
    entries = []
    payload = b""
    offset = 6 + 16 * len(images)
    for size, png_path in images:
        with open(png_path, "rb") as handle:
            blob = handle.read()
        entries.append(
            struct.pack(
                "<BBBBHHII",
                0 if size >= 256 else size,
                0 if size >= 256 else size,
                0,
                0,
                1,
                32,
                len(blob),
                offset,
            )
        )
        payload += blob
        offset += len(blob)
    with open(path, "wb") as handle:
        handle.write(struct.pack("<HHH", 0, 1, len(images)) + b"".join(entries) + payload)


def build_icns(images: list[tuple[int, str]], path: str) -> None:
    type_map = {16: b"icp4", 32: b"icp5", 64: b"icp6", 128: b"ic07", 256: b"ic08", 512: b"ic09"}
    body = b""
    for size, png_path in images:
        tag = type_map.get(size)
        if not tag:
            continue
        with open(png_path, "rb") as handle:
            blob = handle.read()
        body += tag + struct.pack(">I", len(blob) + 8) + blob
    with open(path, "wb") as handle:
        handle.write(b"icns" + struct.pack(">I", len(body) + 8) + body)


def main() -> int:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "assets"
    os.makedirs(out_dir, exist_ok=True)

    base = render_base()
    rendered: list[tuple[int, str]] = []
    for size in SIZES:
        pixels = downscale(base, BASE, size)
        path = os.path.join(out_dir, f"icon-{size}.png")
        write_png(path, size, size, pixels)
        rendered.append((size, path))

    write_png(os.path.join(out_dir, "icon.png"), 512, 512, downscale(base, BASE, 512))
    build_ico([item for item in rendered if item[0] <= 256], os.path.join(out_dir, "icon.ico"))
    build_icns(rendered, os.path.join(out_dir, "icon.icns"))
    print(f"icons written to {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
