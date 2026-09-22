#!/usr/bin/env python3
"""Write deterministic SHA-256 checksums for transferable source assets."""
from __future__ import annotations

import hashlib
from pathlib import Path


BOOK = Path(__file__).resolve().parents[1]
TARGETS = ("data", "notebooks", "vendor")


def main() -> None:
    files = []
    for name in TARGETS:
        root = BOOK / name
        if not root.is_dir():
            raise SystemExit(f"Missing checksum target: {root}")
        files.extend(path for path in root.rglob("*") if path.is_file())
    lines = []
    for path in sorted(files):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.relative_to(BOOK).as_posix()}")
    (BOOK / "checksums.sha256").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote checksums for {len(files)} files")


if __name__ == "__main__":
    main()

