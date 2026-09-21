#!/usr/bin/env python3
"""Assemble .ico and .icns files from PNG images.

No image decoding is needed (sizes come from the PNG header), so this works on
any platform with Python 3.8+.

    pack_icons.py --ico out.ico --icns out.icns icon-16.png icon-32.png ...
"""

from __future__ import annotations

import argparse
import struct
import sys

ICNS_TYPES = {
    16: b"icp4",
    32: b"icp5",
    64: b"icp6",
    128: b"ic07",
    256: b"ic08",
    512: b"ic09",
    1024: b"ic10",
}


def png_size(blob: bytes):
    if blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG file")
    return struct.unpack(">II", blob[16:24])


def load(paths):
    images = []
    for path in paths:
        with open(path, "rb") as handle:
            blob = handle.read()
        width, height = png_size(blob)
        images.append((width, height, blob))
    images.sort(key=lambda item: -item[0])
    return images


def build_ico(images, path: str) -> None:
    # The ICO format stores 256 as "0"; anything larger is not standard, so
    # keep the classic range and let icns carry the big sizes.
    images = [item for item in images if item[0] <= 256]
    entries = b""
    payload = b""
    offset = 6 + 16 * len(images)
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
        payload += blob
        offset += len(blob)
    with open(path, "wb") as handle:
        handle.write(struct.pack("<HHH", 0, 1, len(images)) + entries + payload)


def build_icns(images, path: str) -> None:
    body = b""
    for width, _height, blob in images:
        tag = ICNS_TYPES.get(width)
        if not tag:
            continue
        body += tag + struct.pack(">I", len(blob) + 8) + blob
    if not body:
        raise ValueError("no usable icon sizes for icns")
    with open(path, "wb") as handle:
        handle.write(b"icns" + struct.pack(">I", len(body) + 8) + body)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("png", nargs="+")
    parser.add_argument("--ico")
    parser.add_argument("--icns")
    args = parser.parse_args()

    images = load(args.png)
    if args.ico:
        build_ico(images, args.ico)
        print(f"wrote {args.ico}")
    if args.icns:
        build_icns(images, args.icns)
        print(f"wrote {args.icns}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
