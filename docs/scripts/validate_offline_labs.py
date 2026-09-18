#!/usr/bin/env python3
"""Validate data and execute extracted R lab bundles without data-network access."""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

import nbformat
from nbclient import NotebookClient

from generate_lab_notebooks import LAB_DATA, LABS_DIR, DATA_DIR, DOWNLOADS_DIR, split_cells, split_front_matter

ROOT = LABS_DIR.parents[1]
NETWORK_GUARD = '''
options(repr.plot.res=100)
for (name in c("download.file", "install.packages"))
  trace(name, where=asNamespace("utils"), tracer=quote(stop("Network/install access forbidden during offline validation")), print=FALSE)
trace("url", where=baseenv(), tracer=quote(stop("Remote URLs forbidden during offline validation")), print=FALSE)
'''


def check_data() -> dict:
    manifest = json.loads((DATA_DIR / "manifest.json").read_text())
    for name, spec in manifest.items():
        path = DATA_DIR / spec["file"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == spec["sha256"], f"Corrupt data: {name}"
        for filename in spec.get("additional_files", []):
            assert (DATA_DIR / filename).is_file(), f"Missing {filename}"
            assert hashlib.sha256((DATA_DIR / filename).read_bytes()).hexdigest() == spec["additional_sha256"][filename]
    for stem, names in LAB_DATA.items():
        assert set(names) <= manifest.keys(), stem
        source = LABS_DIR / (stem + ".qmd")
        _, body = split_front_matter(source.read_text(), source)
        for kind, code in split_cells(body, source):
            if kind == "code":
                assert not re.search(r"download\.file\(|install\.packages\(|install_github\(|https?://", code), f"Network code in {stem}"
                assert not re.search(r'\bdata\([^)]*package\s*=', code), f"Unbundled package data: {stem}"
        with zipfile.ZipFile(DOWNLOADS_DIR / (stem + ".zip")) as archive:
            for name in names:
                spec = manifest[name]
                assert hashlib.sha256(archive.read("data/"+spec["file"])).hexdigest() == spec["sha256"]
    return manifest


def execute(stem: str, out: Path, export: str = "", render: bool = False) -> dict:
    destination = out / stem
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(DOWNLOADS_DIR / (stem + ".zip")) as bundle:
        bundle.extractall(destination)
    nb = nbformat.read(destination / (stem + ".ipynb"), as_version=4)
    nbformat.validate(nb)
    code_count = sum(c.cell_type == "code" for c in nb.cells)
    if code_count:
        nb.cells.insert(0, nbformat.v4.new_code_cell(NETWORK_GUARD))
        if export:
            nb.cells.append(nbformat.v4.new_code_cell(export))
        print(f"Executing {stem}", flush=True)
        try:
            NotebookClient(nb, timeout=900, kernel_name="ir", resources={"metadata": {"path": str(destination)}}).execute()
        finally:
            nbformat.write(nb, destination / "executed.ipynb")
        plots = sum("image/png" in output.get("data", {}) for c in nb.cells if c.cell_type == "code" for output in c.outputs)
        assert plots > 0 or stem == "hisp-ie-practice-lab", f"No rendered figures: {stem}"
    else:
        plots = 0
    if render:
        print(f"Rendering standalone {stem}", flush=True)
        profile = destination / "offline-profile.R"
        profile.write_text(NETWORK_GUARD)
        env = {**os.environ, "R_PROFILE_USER": str(profile)}
        with (destination / "render.log").open("w") as log:
            subprocess.run(["quarto", "render", stem+".qmd"], cwd=destination, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
        assert (destination / (stem + ".html")).exists()
    return {"code_cells": code_count, "plots": plots, "standalone_render": render,
            "status": "executed" if code_count else "worksheet validated"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--lab", action="append", choices=LAB_DATA)
    parser.add_argument("--output", type=Path, default=ROOT / ".qedlabs-validation/offline")
    args = parser.parse_args()
    manifest = check_data()
    results = {}
    if args.execute or args.render:
        args.output.mkdir(parents=True, exist_ok=True)
        summary = args.output / "summary.json"
        summary.unlink(missing_ok=True)
        for stem in args.lab or LAB_DATA:
            results[stem] = execute(stem, args.output.resolve(), render=args.render)
        summary.write_text(json.dumps({"verified_utc": datetime.now(timezone.utc).isoformat(), "labs": results}, indent=2)+"\n")
    print(f"Validated {len(manifest)} datasets and {len(LAB_DATA)} lab bundles.")


if __name__ == "__main__":
    main()
