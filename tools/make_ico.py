#!/usr/bin/env python3
"""Build a Windows .ico file from PNG images (PNG-compressed ICO entries)."""

import struct
import sys


def png_size(blob: bytes):
    if blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    return struct.unpack(">II", blob[16:24])


def main() -> int:
    output = sys.argv[1]
    images = []
    for path in sys.argv[2:]:
        with open(path, "rb") as handle:
            blob = handle.read()
        width, height = png_size(blob)
        images.append((width, height, blob))

    images.sort(key=lambda item: -item[0])
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries = b""
    payload = b""
    for width, height, blob in images:
        entries += struct.pack(
            "<BBBBHHII",
            0 if width >= 256 else width,
            0 if height >= 256 else height,
            0,
            0,
            1,
            32,
            len(blob),
            offset,
        )
        offset += len(blob)
        payload += blob

    with open(output, "wb") as handle:
        handle.write(header + entries + payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
