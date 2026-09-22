#!/usr/bin/env python3
"""Check the shared bibliography and Pandoc citations without executing labs."""

from __future__ import annotations

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import yaml

from extract_link_graph import bibliography_paths, iter_qmd_files, parse_front_matter


DOCS_DIR = Path(__file__).resolve().parents[1]
RETIRED_KEYS = {
    "AbadieGard03": "abadie2003economic",
    "AbadieDiamondHainmueller10": "abadie2010synthetic",
    "Abadie_Using_Synthetic_Controls_2021": "abadie2021using",
    "BenMichael_Feller_Rothstein_2021_AugmentedSCM": "benmichael2021augmented",
}
CROSSREF_PREFIXES = (
    "fig-", "tbl-", "lst-", "eq-", "sec-", "thm-", "lem-", "cor-",
    "prp-", "cnj-", "def-", "exm-", "exr-", "sol-", "rem-", "nte-", "tip-", "wrn-", "imp-", "cau-",
)


def pandoc_command() -> list[str]:
    if executable := os.environ.get("PANDOC"):
        return [executable]
    if quarto := shutil.which("quarto"):
        return [quarto, "pandoc"]
    if executable := shutil.which("pandoc"):
        return [executable]
    return ["quarto", "pandoc"]


def parse_with_pandoc(text: str, source_format: str, target_format: str) -> object:
    result = subprocess.run(
        [*pandoc_command(), "--from", source_format, "--to", target_format],
        input=text, text=True, capture_output=True, check=True,
    )
    return json.loads(result.stdout)


def citation_keys(node: object) -> set[str]:
    keys: set[str] = set()
    if isinstance(node, dict):
        if node.get("t") == "Cite":
            keys.update(citation["citationId"] for citation in node["c"][0])
        for value in node.values():
            keys.update(citation_keys(value))
    elif isinstance(node, list):
        for value in node:
            keys.update(citation_keys(value))
    return keys


def bibliography_errors(entries: list[dict]) -> list[str]:
    counts = Counter(entry["id"] for entry in entries)
    errors = [f"Duplicate bibliography key: {key}" for key, count in counts.items() if count > 1]
    errors.extend(f"Retired bibliography key: {key}" for key in RETIRED_KEYS if key in counts)
    return errors


def document_errors(source: str, known_keys: set[str]) -> list[str]:
    document = parse_with_pandoc(source, "markdown", "json")
    errors = []
    for key in sorted(citation_keys(document)):
        if key in RETIRED_KEYS:
            errors.append(f"Retired citation {key}; use {RETIRED_KEYS[key]}")
        elif key not in known_keys and not key.startswith(CROSSREF_PREFIXES) and key != "*":
            errors.append(f"Unresolved citation: {key}")
    def check_links(node: object) -> None:
        if isinstance(node, dict):
            if node.get("t") == "Link":
                target = node["c"][-1][0].split("#")[0].split("?")[0]
                if target.endswith(("/references.bib", "/synthetic-control.bib")) or target in {"references.bib", "synthetic-control.bib"}:
                    errors.append(f"Reference to removed bibliography: {target}")
            for value in node.values():
                check_links(value)
        elif isinstance(node, list):
            for value in node:
                check_links(value)
    check_links(document)
    return errors


def bibliography_overrides(node: object) -> bool:
    if isinstance(node, dict):
        return "bibliography" in node or any(bibliography_overrides(value) for value in node.values())
    if isinstance(node, list):
        return any(bibliography_overrides(value) for value in node)
    return False


def validate(root: Path) -> tuple[list[str], int, int]:
    root = root.resolve()
    canonical = root.parent / "evaluation-bibliography.bib"
    errors = []
    entries = parse_with_pandoc(canonical.read_text(encoding="utf-8"), "biblatex", "csljson")
    errors.extend(bibliography_errors(entries))
    known_keys = {entry["id"] for entry in entries}
    config = yaml.safe_load((root / "_quarto.yml").read_text(encoding="utf-8"))
    if config.get("bibliography") != "../evaluation-bibliography.bib":
        errors.append("Project bibliography must be ../evaluation-bibliography.bib")
    if bibliography_overrides({key: value for key, value in config.items() if key != "bibliography"}):
        errors.append("Project formats must inherit the shared bibliography")
    for path in root.rglob("*.bib"):
        if not any(part.startswith((".", "_")) for part in path.relative_to(root).parts):
            errors.append(f"Unexpected local bibliography: {path.relative_to(root)}")
    for path in root.rglob("_metadata.y*ml"):
        metadata = yaml.safe_load(path.read_text(encoding="utf-8"))
        if bibliography_overrides(metadata):
            errors.append(f"Directory bibliography override: {path.relative_to(root)}")
    pages = iter_qmd_files(root)
    for page in pages:
        relative = page.relative_to(root)
        source = page.read_text(encoding="utf-8")
        front, _ = parse_front_matter(source)
        if bibliography_overrides(front):
            errors.append(f"{relative}: remove the page bibliography override")
        if bibliography_paths(root, relative, front, config) != [canonical]:
            errors.append(f"{relative}: does not resolve to the shared bibliography")
        errors.extend(f"{relative}: {error}" for error in document_errors(source, known_keys))
    return errors, len(entries), len(pages)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DOCS_DIR)
    args = parser.parse_args()
    try:
        errors, entries, pages = validate(args.root)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Bibliography validation failed: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError):
            print(error.stderr, file=sys.stderr)
        return 1
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Validated {entries} bibliography entries and citations in {pages} pages.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
