#!/usr/bin/env python3
"""Ensure every PowerShell script is UTF-8 *with* BOM.

Windows PowerShell 5.1 decodes BOM-less script files using the system ANSI
code page (936 on Chinese Windows). Any non-ASCII text then corrupts string
literals and the parser fails with "The string is missing the terminator".
Adding a UTF-8 BOM makes 5.1 decode the file as UTF-8 regardless of the
system code page.
"""

from __future__ import annotations

import pathlib
import sys

BOM = b"\xef\xbb\xbf"


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    added = 0
    for path in sorted(root.rglob("*.ps1")):
        data = path.read_bytes()
        if data.startswith(BOM):
            print(f"ok      {path}")
            continue
        path.write_bytes(BOM + data)
        added += 1
        print(f"added   {path}")
    print(f"\n{added} file(s) updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
