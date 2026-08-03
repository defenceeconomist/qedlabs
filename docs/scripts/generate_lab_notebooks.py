#!/usr/bin/env python3
"""Generate deterministic R Jupyter notebooks from the public lab pages."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


DOCS_DIR = Path(__file__).resolve().parents[1]
LABS_DIR = DOCS_DIR / "labs"
NOTEBOOKS_DIR = LABS_DIR / "notebooks"
SITE_BASE_URL = "https://defenceeconomist.github.io/qedlabs"

LAB_STEMS = (
    "black-politicians-lab",
    "hisp-ie-practice-lab",
    "interrupted-time-series-design-diagnostics-lab",
    "interrupted-time-series-counterfactual-validation-lab",
    "interrupted-time-series-mechanics-lab",
    "lalonde-matching-lab",
    "nsw-cps-benchmark-lab",
    "synthetic-control-augmentation-lab",
    "synthetic-control-design-lab",
    "synthetic-control-donor-pool-lab",
    "synthetic-control-mechanics-lab",
    "synthetic-control-proposition-99-lab",
)

CHUNK_START_RE = re.compile(r"^```\{r(?:[\s,][^}]*)?\}\s*$")
QMD_LINK_RE = re.compile(r"(\]\()([^\s)#]+\.qmd)(#[^)]*)?(\))")
QUARTO_LINK_ATTR_RE = re.compile(
    r"(?<=\))\{[^{}\n]*(?:download\s*=|\.cta-button)[^{}\n]*\}"
)
NOTEBOOK_DOWNLOAD_RE = re.compile(
    r"^\[Download (?:the )?R Jupyter notebook\]\(notebooks/[^)]+\.ipynb\)"
    r"(?:\{[^{}\n]*\})?\s*\n?",
    re.MULTILINE,
)
QUARTO_DIV_RE = re.compile(r"^:::\s*(?:\{[^{}\n]*\})?\s*$", re.MULTILINE)


def split_front_matter(source: str, source_path: Path) -> tuple[dict[str, str], str]:
    """Return the small metadata subset needed by notebooks and the body."""
    lines = source.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        raise ValueError(f"{source_path}: expected YAML front matter")

    try:
        end = next(i for i, line in enumerate(lines[1:], start=1) if line.strip() == "---")
    except StopIteration as exc:
        raise ValueError(f"{source_path}: unclosed YAML front matter") from exc

    metadata: dict[str, str] = {}
    for line in lines[1:end]:
        match = re.match(r"^(title|subtitle|author|date):\s*(.*?)\s*$", line)
        if not match:
            continue
        key, value = match.groups()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        metadata[key] = value

    if "title" not in metadata:
        raise ValueError(f"{source_path}: front matter must define a title")

    return metadata, "".join(lines[end + 1 :]).lstrip("\n")


def public_page_url(path: Path) -> str:
    relative = path.resolve().relative_to(DOCS_DIR.resolve()).with_suffix(".html")
    return f"{SITE_BASE_URL}/{relative.as_posix()}"


def rewrite_markdown(markdown: str, source_path: Path) -> str:
    """Make source-page links usable from a downloaded notebook."""

    def replace_qmd_link(match: re.Match[str]) -> str:
        target = (source_path.parent / match.group(2)).resolve()
        try:
            relative = target.relative_to(DOCS_DIR.resolve()).with_suffix(".html")
        except ValueError as exc:
            raise ValueError(
                f"{source_path}: QMD link points outside docs/: {match.group(2)}"
            ) from exc
        fragment = match.group(3) or ""
        return f"{match.group(1)}{SITE_BASE_URL}/{relative.as_posix()}{fragment}{match.group(4)}"

    markdown = QMD_LINK_RE.sub(replace_qmd_link, markdown)
    markdown = NOTEBOOK_DOWNLOAD_RE.sub("", markdown)
    markdown = QUARTO_LINK_ATTR_RE.sub("", markdown)
    return QUARTO_DIV_RE.sub("", markdown).strip()


def stable_cell_id(stem: str, index: int, cell_type: str, source: str) -> str:
    digest = hashlib.sha256(
        f"{stem}\0{index}\0{cell_type}\0{source}".encode("utf-8")
    ).hexdigest()
    return digest[:12]


def source_lines(source: str) -> list[str]:
    return source.splitlines(keepends=True)


def make_cell(stem: str, index: int, cell_type: str, source: str) -> dict[str, Any]:
    cell: dict[str, Any] = {
        "cell_type": cell_type,
        "id": stable_cell_id(stem, index, cell_type, source),
        "metadata": {},
        "source": source_lines(source),
    }
    if cell_type == "code":
        cell["execution_count"] = None
        cell["outputs"] = []
    return cell


def split_cells(body: str, source_path: Path) -> list[tuple[str, str]]:
    cells: list[tuple[str, str]] = []
    buffer: list[str] = []
    in_r_chunk = False

    def flush(cell_type: str) -> None:
        source = "".join(buffer).strip("\n")
        buffer.clear()
        if not source.strip():
            return
        if cell_type == "markdown":
            source = rewrite_markdown(source, source_path)
        cells.append((cell_type, source))

    for line in body.splitlines(keepends=True):
        stripped = line.rstrip("\r\n")
        if not in_r_chunk and CHUNK_START_RE.match(stripped):
            flush("markdown")
            in_r_chunk = True
            continue
        if in_r_chunk and stripped.strip() == "```":
            flush("code")
            in_r_chunk = False
            continue
        buffer.append(line)

    if in_r_chunk:
        raise ValueError(f"{source_path}: unclosed R code chunk")
    flush("markdown")
    return cells


def build_notebook(source_path: Path) -> dict[str, Any]:
    metadata, body = split_front_matter(source_path.read_text(encoding="utf-8"), source_path)
    stem = source_path.stem
    page_link = public_page_url(source_path)
    heading = f"# {metadata['title']}\n\n[View this lab on the QED Labs website]({page_link})"

    raw_cells = [("markdown", heading), *split_cells(body, source_path)]
    cells = [
        make_cell(stem, index, cell_type, source)
        for index, (cell_type, source) in enumerate(raw_cells)
    ]

    return {
        "cells": cells,
        "metadata": {
            "kernelspec": {
                "display_name": "R",
                "language": "R",
                "name": "ir",
            },
            "language_info": {
                "codemirror_mode": "r",
                "file_extension": ".r",
                "mimetype": "text/x-r-source",
                "name": "R",
                "pygments_lexer": "r",
            },
            "qedlabs": {
                "generated_from": f"labs/{source_path.name}",
                "generator": "scripts/generate_lab_notebooks.py",
            },
        },
        "nbformat": 4,
        "nbformat_minor": 5,
    }


def serialize_notebook(notebook: dict[str, Any]) -> str:
    return json.dumps(notebook, indent=1, ensure_ascii=False) + "\n"


def validate_notebook(notebook: dict[str, Any], source_path: Path) -> None:
    if notebook["metadata"]["kernelspec"]["name"] != "ir":
        raise ValueError(f"{source_path}: notebook must use the ir kernelspec")
    source_code_cells = sum(1 for cell_type, _ in split_cells(
        split_front_matter(source_path.read_text(encoding="utf-8"), source_path)[1],
        source_path,
    ) if cell_type == "code")
    notebook_code_cells = sum(
        1 for cell in notebook["cells"] if cell["cell_type"] == "code"
    )
    if source_code_cells != notebook_code_cells:
        raise ValueError(
            f"{source_path}: expected {source_code_cells} code cells, "
            f"generated {notebook_code_cells}"
        )


def generate(check: bool) -> int:
    expected_names = {f"{stem}.ipynb" for stem in LAB_STEMS}
    failures: list[str] = []

    if not check:
        NOTEBOOKS_DIR.mkdir(parents=True, exist_ok=True)

    for stem in LAB_STEMS:
        source_path = LABS_DIR / f"{stem}.qmd"
        output_path = NOTEBOOKS_DIR / f"{stem}.ipynb"
        notebook = build_notebook(source_path)
        validate_notebook(notebook, source_path)
        rendered = serialize_notebook(notebook)

        if check:
            if not output_path.exists():
                failures.append(f"missing {output_path.relative_to(DOCS_DIR)}")
            elif output_path.read_text(encoding="utf-8") != rendered:
                failures.append(f"stale {output_path.relative_to(DOCS_DIR)}")
        else:
            output_path.write_text(rendered, encoding="utf-8")
            print(f"wrote {output_path.relative_to(DOCS_DIR)}")

    if NOTEBOOKS_DIR.exists():
        unexpected = sorted(
            path.name for path in NOTEBOOKS_DIR.glob("*.ipynb")
            if path.name not in expected_names
        )
        failures.extend(f"unexpected labs/notebooks/{name}" for name in unexpected)

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        if check:
            print(
                "Run `python3 docs/scripts/generate_lab_notebooks.py` to refresh notebooks.",
                file=sys.stderr,
            )
        return 1

    if check:
        print(f"checked {len(LAB_STEMS)} generated notebooks")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if committed notebooks do not match their QMD sources",
    )
    args = parser.parse_args()
    return generate(check=args.check)


if __name__ == "__main__":
    raise SystemExit(main())
