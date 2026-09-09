#!/usr/bin/env python3
"""Validate the stable, editor-facing Thor2D project manifest shape."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_project.py PROJECT_JSON", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"invalid project manifest {path}: {exc}", file=sys.stderr)
        return 1

    required = ("schema_version", "project_id", "name", "assets", "scenes")
    if not isinstance(payload, dict) or any(key not in payload for key in required):
        print(f"project manifest missing one of: {', '.join(required)}", file=sys.stderr)
        return 1
    if not isinstance(payload["schema_version"], int) or payload["schema_version"] < 1:
        print("project schema_version must be a positive integer", file=sys.stderr)
        return 1
    if not isinstance(payload["project_id"], str) or not payload["project_id"]:
        print("project_id must be a non-empty string", file=sys.stderr)
        return 1
    if not isinstance(payload["name"], str) or not payload["name"]:
        print("name must be a non-empty string", file=sys.stderr)
        return 1
    if not isinstance(payload["assets"], list) or not isinstance(payload["scenes"], list):
        print("assets and scenes must be arrays", file=sys.stderr)
        return 1

    print(f"Project manifest valid: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
