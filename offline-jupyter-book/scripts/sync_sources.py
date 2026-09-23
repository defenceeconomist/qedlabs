#!/usr/bin/env python3
"""Refresh standalone notebook and data snapshots from the canonical docs tree."""
from __future__ import annotations

import json
from pathlib import Path
import re
import shutil


BOOK = Path(__file__).resolve().parents[1]
REPOSITORY = BOOK.parent
SOURCE_NOTEBOOKS = REPOSITORY / "docs" / "labs" / "notebooks"
SOURCE_DATA = REPOSITORY / "docs" / "labs" / "data"
SITE_LAB = re.compile(
    r"https://defenceeconomist\.github\.io/qedlabs/labs/"
    r"([a-z0-9-]+)\.html(#[^)\s]+)?"
)


def localize_notebook(path: Path, known: set[str]) -> None:
    notebook = json.loads(path.read_text(encoding="utf-8"))
    for cell in notebook.get("cells", []):
        source = "".join(cell.get("source", []))

        def replace(match: re.Match[str]) -> str:
            stem, fragment = match.group(1), match.group(2) or ""
            if stem in known:
                return f"{stem}.ipynb{fragment}"
            if stem == "data":
                return "../data.md"
            return match.group(0)

        source = SITE_LAB.sub(replace, source)
        source = re.sub(
            r"\[Website\]\([^)]*\)",
            "[Book home](../index.md)",
            source,
            count=1,
        )
        # Quarto emits fenced blocks tagged ``math``. MyST interprets that tag
        # as a Pygments language, so use portable display-math delimiters.
        source = re.sub(r"``` math\n\n(.*?)\n```", r"$$\n\1\n$$", source, flags=re.S)
        cell["source"] = source.splitlines(keepends=True)
    path.write_text(json.dumps(notebook, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


def write_data_page() -> None:
    manifest = json.loads((BOOK / "data" / "manifest.json").read_text(encoding="utf-8"))
    lines = [
        "# Bundled data and provenance",
        "",
        "All notebook execution uses the local files listed below. `manifest.json` records",
        "source metadata, variables, dimensions, and expected hashes. `load-data.R` verifies",
        "each dataset before returning it.",
        "",
        "[Download the complete machine-readable manifest](data/manifest.json).",
        "",
        "| Dataset | File | Rows | Origin |",
        "|---|---|---:|---|",
    ]
    for name, item in manifest.items():
        source = " ".join(str(item.get("source", "Bundled source")).split())
        lines.append(
            f"| `{name}` | [Download](data/{item['file']}) | {item['rows']:,} | {source} |"
        )
    lines.extend(
        [
            "",
            "## Integrity and licences",
            "",
            "Run `./verify.sh` to verify the book-level `checksums.sha256` file and the",
            "dataset hashes embedded in `data/manifest.json`. Redistribution notices and",
            "upstream licences are retained in the bundled `data/provenance/` directory.",
            "",
            "The HISP snapshot also retains its original Stata file and replication script",
            "for provenance. The notebooks execute the R lab and do not run that script.",
            "",
        ]
    )
    (BOOK / "data.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    if not SOURCE_NOTEBOOKS.is_dir() or not SOURCE_DATA.is_dir():
        raise SystemExit("Canonical docs/labs sources are unavailable")
    destination_notebooks = BOOK / "notebooks"
    destination_data = BOOK / "data"
    if destination_notebooks.exists():
        shutil.rmtree(destination_notebooks)
    if destination_data.exists():
        shutil.rmtree(destination_data)
    shutil.copytree(SOURCE_NOTEBOOKS, destination_notebooks)
    shutil.copytree(SOURCE_DATA, destination_data)
    notebooks = sorted(destination_notebooks.glob("*.ipynb"))
    known = {path.stem for path in notebooks}
    for path in notebooks:
        localize_notebook(path, known)
    if len(notebooks) != 23:
        raise SystemExit(f"Expected 23 notebooks, found {len(notebooks)}")
    write_data_page()
    print(f"Copied and localized {len(notebooks)} notebooks and bundled data")


if __name__ == "__main__":
    main()
