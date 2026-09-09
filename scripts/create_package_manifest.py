#!/usr/bin/env python3
"""Create the reproducible metadata manifest embedded in a .thor package."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: create_package_manifest.py PACKAGE_ROOT OUTPUT", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    files = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path == output:
            continue
        relative = path.relative_to(root).as_posix()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        files.append({"path": relative, "size": path.stat().st_size, "sha256": digest})

    manifest = {
        "format": "thor2d-package",
        "format_version": 1,
        "runtime": "thor2d-v0.7",
        "files": files,
    }
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
