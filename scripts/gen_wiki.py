#!/usr/bin/env python3
"""Validate that every public Thor2D proc is covered by docs/wiki.

Usage:
  python3 scripts/gen_wiki.py --check   fail when a public proc is missing
  python3 scripts/gen_wiki.py --gen     regenerate docs/wiki/Api_Reference.md
Parity-check runs --check.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "thor2d"
WIKI = ROOT / "docs" / "wiki"

PROC_RE = re.compile(r"^([A-Za-z][A-Za-z0-9_]*)\s*::\s*proc", re.MULTILINE)

SKIP_FILES = {"internal"}


def public_procs() -> set[str]:
    names: set[str] = set()
    for path in sorted(SRC.glob("*.odin")):
        text = path.read_text()
        for match in PROC_RE.finditer(text):
            name = match.group(1)
            if not name[:1].isupper():
                continue
            if name.startswith("_") or name.startswith("find_") or name.startswith("physics_"):
                continue
            names.add(name)
    return names


def wiki_text() -> str:
    chunks = []
    for path in sorted(WIKI.rglob("*.md")):
        chunks.append(path.read_text())
    return "\n".join(chunks)


def main() -> int:
    if "--gen" in sys.argv:
        generate_reference()
        return 0
    check_only = "--check" in sys.argv or len(sys.argv) == 1
    procs = public_procs()
    text = wiki_text()
    missing = sorted(name for name in procs if name not in text)
    print(f"Public procs: {len(procs)}, missing from wiki: {len(missing)}")
    for name in missing:
        print(f"  MISSING {name}")
    if check_only and missing:
        return 1
    return 0


def generate_reference() -> None:
    ref = WIKI / "Api_Reference.md"
    lines = [
        "# API Reference (v0.10)",
        "",
        "Auto-generated index of every public `thor2d` procedure by source file",
        "(`python3 scripts/gen_wiki.py --gen`). Curated module pages add LOVE",
        "mapping and examples.",
        "",
    ]
    count = 0
    for path in sorted(SRC.glob("*.odin")):
        entries = []
        for match in PROC_RE.finditer(path.read_text()):
            name = match.group(1)
            if not name[:1].isupper():
                continue
            sig = match.group(0).strip()
            entries.append((name, sig if len(sig) <= 160 else sig[:157] + "..."))
        if not entries:
            continue
        lines.append(f"## {path.name}")
        lines.append("")
        for name, sig in entries:
            lines.append(f"- `{name}` — `{sig}`")
            count += 1
        lines.append("")
    ref.write_text("\n".join(lines))
    print(f"wrote {ref} with {count} entries")


if __name__ == "__main__":
    raise SystemExit(main())
