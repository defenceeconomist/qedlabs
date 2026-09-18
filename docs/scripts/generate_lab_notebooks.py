#!/usr/bin/env python3
"""Build deterministic, offline R lab documents, Jupyter notebooks and ZIPs."""
from __future__ import annotations

import argparse
from functools import lru_cache
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit
import zipfile

import nbformat
import yaml

from validate_bibliography import citation_keys, pandoc_command, parse_with_pandoc

DOCS_DIR = Path(__file__).resolve().parents[1]
LABS_DIR = DOCS_DIR / "labs"
NOTEBOOKS_DIR = LABS_DIR / "notebooks"
DOWNLOADS_DIR = LABS_DIR / "downloads"
DATA_DIR = LABS_DIR / "data"
SITE_BASE_URL = "https://defenceeconomist.github.io/qedlabs"
LAB_DATA = {
    "black-politicians-lab": ["black_politicians"],
    "difference-in-differences-foundations-lab": ["injury"],
    "difference-in-differences-staggered-diagnostics-lab": ["castle"],
    "difference-in-differences-modern-estimators-lab": ["mpdta"],
    "hisp-ie-practice-lab": ["hisp"],
    "interrupted-time-series-mechanics-lab": ["Seatbelts"],
    "interrupted-time-series-design-diagnostics-lab": ["Seatbelts"],
    "interrupted-time-series-counterfactual-validation-lab": ["service"],
    "lalonde-matching-lab": ["lalonde"],
    "nsw-cps-benchmark-lab": ["nsw_mixtape", "cps_mixtape"],
    "regression-discontinuity-foundations-lab": ["gov_transfers"],
    "regression-discontinuity-diagnostics-lab": ["gov_transfers", "gov_transfers_density"],
    "regression-discontinuity-fuzzy-lab": ["mortgages"],
    "synthetic-control-augmentation-lab": ["kansas"],
    "synthetic-control-design-lab": [],
    "synthetic-control-donor-pool-lab": [],
    "synthetic-control-mechanics-lab": ["synth.data"],
    "synthetic-control-proposition-99-lab": ["smoking"],
}
LAB_STEMS = tuple(LAB_DATA)
CHUNK_START_RE = re.compile(r"^(`{3,})\{(r|python)([^}]*)\}\s*$")


def split_front_matter(source: str, source_path: Path) -> tuple[dict, str]:
    match = re.match(r"\A---\s*\n(.*?)\n---\s*\n", source, re.S)
    if not match:
        raise ValueError(f"{source_path}: expected YAML front matter")
    metadata = yaml.safe_load(match[1])
    if not isinstance(metadata, dict) or "title" not in metadata:
        raise ValueError(f"{source_path}: front matter must define a title")
    return metadata, source[match.end():]


def pandoc(source: str, *args: str) -> str:
    result = subprocess.run([*pandoc_command(), *args], input=source, text=True,
                            capture_output=True, check=True)
    if "not found" in result.stderr or "Could not" in result.stderr:
        raise ValueError(result.stderr)
    return result.stdout


def public_page_url(path: Path) -> str:
    return SITE_BASE_URL + "/" + path.resolve().relative_to(DOCS_DIR).with_suffix(".html").as_posix()


def clean_body(body: str) -> str:
    # The download strip belongs on the website, not inside its own downloads.
    body = re.sub(r"<!-- lab-downloads:start -->.*?<!-- lab-downloads:end -->", "", body, flags=re.S)
    body = re.sub(r"(?m)^\[Download (?:the )?R Jupyter notebook\].*\n?", "", body)
    return body.strip()


def split_cells(body: str, source_path: Path) -> list[tuple[str, str]]:
    cells, buffer = [], []
    fence = None
    options = ""
    ordinary_fence = None

    def flush(kind: str) -> None:
        value = "".join(buffer).strip("\n")
        buffer.clear()
        if value.strip():
            if kind == "code":
                found = dict(re.findall(r"(fig\.(?:width|height))\s*=\s*([0-9.]+)", options))
                rest = re.sub(r"fig\.(?:width|height)\s*=\s*[0-9.]+", "", options).strip(" ,")
                if rest:
                    raise ValueError(f"{source_path}: unsupported chunk options: {rest}")
                if re.search(r"(?m)^#\|", value):
                    raise ValueError(f"{source_path}: translate new Quarto chunk options explicitly")
                value = (f'options(repr.plot.width = {found.get("fig.width", "8")}, '
                         f'repr.plot.height = {found.get("fig.height", "4.8")})\n' + value)
            cells.append((kind, value))

    for line in body.splitlines(keepends=True):
        match = CHUNK_START_RE.match(line.strip())
        if fence:
            if re.fullmatch(r"`{%d,}\s*" % len(fence), line.strip()):
                flush("code")
                fence = None
            else:
                buffer.append(line)
        elif ordinary_fence:
            buffer.append(line)
            if line.strip() == ordinary_fence:
                ordinary_fence = None
        elif match:
            if match[2] != "r":
                raise ValueError(f"{source_path}: only R teaching chunks are supported")
            flush("markdown")
            fence, options = match[1], match[3]
        else:
            if re.match(r"^`{3,}", line):
                ordinary_fence = re.match(r"^`+", line)[0]
            buffer.append(line)
    if fence or ordinary_fence:
        raise ValueError(f"{source_path}: unclosed code chunk")
    flush("markdown")
    return cells


@lru_cache(maxsize=1)
def references() -> list[dict]:
    return parse_with_pandoc((DOCS_DIR.parent / "evaluation-bibliography.bib").read_text(), "biblatex", "csljson")


def resolve_links(node: object, source_path: Path) -> None:
    if isinstance(node, dict):
        if node.get("t") in {"Link", "Image"}:
            target = node["c"][-1][0]
            url = urlsplit(target)
            if not url.scheme and not url.netloc and url.path:
                path = (DOCS_DIR / url.path.lstrip("/") if url.path.startswith("/")
                        else source_path.parent / url.path).resolve()
                relative = path.relative_to(DOCS_DIR)
                if relative.suffix == ".qmd":
                    relative = relative.with_suffix(".html")
                node["c"][-1][0] = SITE_BASE_URL + "/" + relative.as_posix() + ("#" + url.fragment if url.fragment else "")
        for value in node.values():
            resolve_links(value, source_path)
    elif isinstance(node, list):
        for value in node:
            resolve_links(value, source_path)


def rewrite_markdown(markdown: str, source_path: Path) -> str:
    ast = json.loads(pandoc(clean_body(markdown), "-f", "markdown", "-t", "json"))
    resolve_links(ast, source_path)
    return pandoc(json.dumps(ast), "-f", "json", "-t", "gfm+tex_math_dollars", "--wrap=none").strip()


def build_notebook(source_path: Path) -> dict:
    metadata, body = split_front_matter(source_path.read_text(), source_path)
    if metadata.get("notebook-language", "r") != "r":
        raise ValueError("Only R notebooks are supported")
    chunks = split_cells(clean_body(body), source_path)
    # Parse and cite-process the whole document once so reference numbering and
    # the bibliography remain consistent across Markdown cells.
    fragments, code = [], []
    for kind, value in chunks:
        if kind == "code":
            code.append(value)
            fragments.append(f'```{{.qed-code index="{len(code)-1}"}}\nplaceholder\n```')
        else:
            fragments.append(value)
    front = yaml.safe_dump({"references": references()}, allow_unicode=True, sort_keys=False)
    ast = json.loads(pandoc("---\n" + front + "---\n\n" + "\n\n".join(fragments),
                           "-f", "markdown", "-t", "json", "--citeproc"))
    resolve_links(ast, source_path)
    raw_cells = [("markdown", f'# {metadata["title"]}\n\n[Website]({public_page_url(source_path)})\n\n'
                  'Use the R kernel. Keep the supplied `data/` folder beside this notebook. '
                  'Run cells in order after installing the documented R environment. Data loading is entirely local.')]
    pending = []

    def flush() -> None:
        if pending:
            document = {**ast, "meta": {}, "blocks": pending.copy()}
            text = pandoc(json.dumps(document), "-f", "json", "-t", "gfm+tex_math_dollars", "--wrap=none").strip()
            raw_cells.append(("markdown", text))
            pending.clear()

    def blocks(items: list) -> None:
        for block in items:
            if block["t"] == "Div":
                blocks(block["c"][1])
            elif block["t"] == "CodeBlock" and "qed-code" in block["c"][0][1]:
                flush()
                raw_cells.append(("code", code[int(dict(block["c"][0][2])["index"])]))
            else:
                if block["t"] == "Header":
                    flush()
                pending.append(block)
    blocks(ast["blocks"])
    flush()
    cells = []
    for i, (kind, value) in enumerate(raw_cells):
        cell = {"cell_type": kind, "id": hashlib.sha256(f"{source_path.stem}\0{i}\0{kind}\0{value}".encode()).hexdigest()[:12],
                "metadata": {}, "source": value.splitlines(keepends=True)}
        if kind == "code":
            cell.update(execution_count=None, outputs=[])
        cells.append(cell)
    return {"cells": cells, "metadata": {
        "kernelspec": {"display_name": "R", "language": "R", "name": "ir"},
        "language_info": {"name": "R", "codemirror_mode": "r", "file_extension": ".r", "mimetype": "text/x-r-source", "pygments_lexer": "r"},
        "qedlabs": {"generated_from": f"labs/{source_path.name}", "generator": "scripts/generate_lab_notebooks.py"}},
        "nbformat": 4, "nbformat_minor": 5}


def build_quarto(source_path: Path) -> str:
    original, body = split_front_matter(source_path.read_text(), source_path)
    body = clean_body(body)
    keys = citation_keys(parse_with_pandoc(body, "markdown", "json"))
    metadata = {"title": original["title"], "format": {"html": {"toc": True, "embed-resources": True}},
                "engine": "knitr", "execute": {"echo": True, "eval": True, "error": False},
                "references": [ref for ref in references() if ref["id"] in keys]}
    # Preserve executable Quarto fences while rewriting only prose links.
    pieces = re.split(r"(```\{r[^}]*\}.*?\n```)", body, flags=re.S)
    for i in range(0, len(pieces), 2):
        pieces[i] = re.sub(r" {2,}\n", "\\\n", pieces[i])
        pieces[i] = re.sub(r"\]\(([^\s)]+\.qmd)(#[^)]*)?\)",
            lambda m: "](" + public_page_url(source_path.parent / m[1]) + (m[2] or "") + ")", pieces[i])
    return "---\n" + yaml.safe_dump(metadata, sort_keys=False, allow_unicode=True) + "---\n\n" + "".join(pieces) + "\n"


def serialize_notebook(notebook: dict) -> str:
    return json.dumps(notebook, indent=1, ensure_ascii=False) + "\n"


def validate_notebook(notebook: dict, source_path: Path) -> None:
    nbformat.validate(nbformat.from_dict(notebook))
    if notebook["metadata"]["kernelspec"]["name"] != "ir":
        raise ValueError("Only R kernels are allowed")
    expected = sum(k == "code" for k, _ in split_cells(split_front_matter(source_path.read_text(), source_path)[1], source_path))
    if expected != sum(c["cell_type"] == "code" for c in notebook["cells"]):
        raise ValueError(f"{source_path}: code-cell count changed")


def archive(files: dict[str, bytes]) -> bytes:
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for name, contents in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, contents)
    return output.getvalue()


def data_files(names: list[str]) -> dict[str, bytes]:
    manifest = json.loads((DATA_DIR / "manifest.json").read_text())
    files = {"data/manifest.json": (json.dumps({n: manifest[n] for n in names}, indent=2, ensure_ascii=False)+"\n").encode(),
             "data/load-data.R": (DATA_DIR / "load-data.R").read_bytes()}
    for path in (DATA_DIR / "provenance").rglob("*"):
        if path.is_file():
            files["data/" + path.relative_to(DATA_DIR).as_posix()] = path.read_bytes()
    for name in names:
        spec = manifest[name]
        for filename in [spec["file"], *spec.get("additional_files", [])]:
            files["data/" + filename] = (DATA_DIR / filename).read_bytes()
    return files


def generate(check: bool) -> int:
    expected = {}
    for stem in LAB_STEMS:
        source = LABS_DIR / (stem + ".qmd")
        nb = build_notebook(source)
        validate_notebook(nb, source)
        notebook = serialize_notebook(nb).encode()
        quarto = build_quarto(source).encode()
        expected[NOTEBOOKS_DIR / (stem + ".ipynb")] = notebook
        expected[DOWNLOADS_DIR / (stem + ".qmd")] = quarto
        files = data_files(LAB_DATA[stem])
        files.update({stem + ".ipynb": notebook, stem + ".qmd": quarto,
                      "README.md": (LABS_DIR / "offline-setup.md").read_bytes()})
        expected[DOWNLOADS_DIR / (stem + ".zip")] = archive(files)
    names = list(json.loads((DATA_DIR / "manifest.json").read_text()))
    expected[DOWNLOADS_DIR / "all-lab-data.zip"] = archive(data_files(names))
    failures = []
    for path, contents in expected.items():
        if check:
            if not path.exists() or path.read_bytes() != contents:
                failures.append(f"Missing or stale: {path.relative_to(DOCS_DIR)}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(contents)
    for directory in (NOTEBOOKS_DIR, DOWNLOADS_DIR):
        for path in directory.glob("*"):
            if path.is_file() and path not in expected:
                failures.append(f"Unexpected artifact: {path}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f'{"Checked" if check else "Generated"} {len(LAB_STEMS)} R notebooks, Quarto documents and lab bundles, plus all-data ZIP.')
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    raise SystemExit(generate(parser.parse_args().check))
