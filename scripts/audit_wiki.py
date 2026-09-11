#!/usr/bin/env python3
"""Report API signatures that do not have curated explanatory documentation.

The API reference is intentionally excluded: a signature index is useful, but
it is not a substitute for semantics, errors, examples, and LOVE differences.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "thor2d"
WIKI = ROOT / "docs" / "wiki"
PROC_RE = re.compile(r"^([A-Z][A-Za-z0-9_]*)\s*::\s*proc", re.MULTILINE)

PAGES = {
    "audio": ["modules/Audio.md", "modules/Sound.md"],
    "capabilities": ["guides/Capabilities.md"],
    "context": ["thor2d.md", "modules/Event.md", "modules/Timer.md"],
    "data": ["modules/Data.md"],
    "ecs": ["modules/ECS.md"],
    "effects": ["modules/Graphics.md"],
    "filesystem": ["modules/Filesystem.md"],
    "filesystem_extra": ["modules/Filesystem.md"],
    "graphics": ["modules/Graphics.md", "modules/Font.md"],
    "graphics_state": ["modules/Graphics.md", "modules/Font.md"],
    "image": ["modules/Image.md"],
    "imagefont": ["modules/Font.md"],
    "input": ["modules/Keyboard.md", "modules/Mouse.md", "modules/Joystick.md", "modules/Touch.md"],
    "input_extra": ["modules/Keyboard.md", "modules/Mouse.md", "modules/Joystick.md", "modules/Touch.md"],
    "love_gaps": ["modules/Audio.md", "modules/Graphics.md", "modules/Math.md", "modules/System.md"],
    "math": ["modules/Math.md"],
    "net": ["modules/Net.md"],
    "physics": ["modules/Physics.md"],
    "physics_box2d": ["modules/Physics.md"],
    "physics_extra": ["modules/Physics.md"],
    "project": ["guides/Packaging.md", "modules/Project.md"],
    "random": ["modules/Math.md"],
    "system": ["modules/System.md"],
    "threads": ["modules/Thread.md"],
    "transforms": ["modules/Math.md", "modules/Transforms.md"],
    "types": ["thor2d.md"],
    "video": ["modules/Video.md"],
    "window": ["modules/Window.md"],
}

def main() -> int:
    total = curated = 0
    print("Thor2D wiki coverage (Api_Reference.md excluded)\n")
    for source in sorted(SRC.glob("*.odin")):
        names = PROC_RE.findall(source.read_text())
        if not names:
            continue
        pages = [WIKI / p for p in PAGES.get(source.stem, [])]
        text = "\n".join(p.read_text() for p in pages if p.exists())
        covered = [n for n in names if re.search(rf"\b{re.escape(n)}\b", text)]
        total += len(names); curated += len(covered)
        print(f"{source.name:25} {len(covered):3}/{len(names):3} curated")
        missing = [n for n in names if n not in covered]
        if missing:
            print("  missing:", ", ".join(missing))
    print(f"\nCurated coverage: {curated}/{total} ({curated / total:.1%})")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
