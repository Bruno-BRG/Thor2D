#!/usr/bin/env python3
"""Validate a Thor2D .thor archive before it is executed or unpacked."""

from __future__ import annotations

import hashlib
import json
import sys
import zipfile
from pathlib import PurePosixPath


def safe_name(name: str) -> bool:
    path = PurePosixPath(name)
    return not name.startswith("/") and ".." not in path.parts and "\\" not in name


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_package.py PACKAGE.thor", file=sys.stderr)
        return 2

    archive = sys.argv[1]
    try:
        with zipfile.ZipFile(archive) as package:
            names = set(package.namelist())
            if "thor2d-manifest.json" not in names:
                raise ValueError("thor2d-manifest.json is missing")
            if any(not safe_name(name) for name in names):
                raise ValueError("archive contains a path outside the package sandbox")
            manifest = json.loads(package.read("thor2d-manifest.json"))
            if manifest.get("format") != "thor2d-package" or manifest.get("format_version") != 1:
                raise ValueError("unsupported Thor2D package manifest")
            runtime = manifest.get("runtime")
            if not isinstance(runtime, str) or not runtime.startswith("thor2d-v0."):
                raise ValueError("missing or unsupported Thor2D runtime version")
            files = manifest.get("files")
            if not isinstance(files, list):
                raise ValueError("manifest files must be an array")
            listed_paths = set()
            for record in files:
                path = record.get("path")
                if not isinstance(path, str) or not safe_name(path) or path not in names:
                    raise ValueError(f"manifest entry is missing: {path!r}")
                if path in listed_paths:
                    raise ValueError(f"duplicate manifest entry: {path}")
                listed_paths.add(path)
                payload = package.read(path)
                if len(payload) != record.get("size"):
                    raise ValueError(f"size mismatch: {path}")
                digest = hashlib.sha256(payload).hexdigest()
                if digest != record.get("sha256"):
                    raise ValueError(f"hash mismatch: {path}")
            for info in package.infolist():
                if not info.is_dir() and info.filename != "thor2d-manifest.json" and info.filename not in listed_paths:
                    raise ValueError(f"unlisted package file: {info.filename}")
            if "project.json" not in names:
                raise ValueError("project.json is missing")
    except (OSError, zipfile.BadZipFile, KeyError, json.JSONDecodeError, TypeError, AttributeError, ValueError) as exc:
        print(f"invalid Thor2D package {archive}: {exc}", file=sys.stderr)
        return 1

    print(f"Package valid: {archive}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
