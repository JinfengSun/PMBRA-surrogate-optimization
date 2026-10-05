#!/usr/bin/env python3
"""Generate deterministic SHA-256 checksums for release files."""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "checksums.txt"
EXCLUDED_PARTS = {".git", "__pycache__", ".pytest_cache", ".venv", "venv"}


def main() -> None:
    lines = []
    for path in sorted(ROOT.rglob("*"), key=lambda item: item.as_posix().lower()):
        if not path.is_file() or path == OUTPUT or any(part in EXCLUDED_PARTS for part in path.parts):
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.relative_to(ROOT).as_posix()}")
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {len(lines)} entries to {OUTPUT}")


if __name__ == "__main__":
    main()
