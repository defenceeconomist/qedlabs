#!/usr/bin/env python3
"""Verify the standalone book's integrity, output, and offline resource policy."""
from __future__ import annotations

from html.parser import HTMLParser
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit


EXPECTED_NOTEBOOKS = 18
EXPECTED_EXECUTABLE = 16
REMOTE = ("http://", "https://", "//")


class ResourceParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.resources: list[tuple[str, str]] = []
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "script" and values.get("src"):
            self.resources.append((tag, values["src"]))
        elif tag == "link" and values.get("href") and values.get("rel"):
            rel = values["rel"].lower()
            if any(token in rel for token in ("stylesheet", "icon", "preload", "modulepreload")):
                self.resources.append((tag, values["href"]))
        elif tag in {"img", "source", "video", "audio", "iframe", "embed"}:
            for key in ("src", "poster"):
                if values.get(key):
                    self.resources.append((tag, values[key]))
            if values.get("srcset"):
                for candidate in values["srcset"].split(","):
                    url = candidate.strip().split()[0]
                    if url:
                        self.resources.append((tag, url))
        if tag == "a" and values.get("href"):
            self.links.append(values["href"])


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_checksums(book: Path) -> None:
    manifest = book / "checksums.sha256"
    if not manifest.is_file():
        raise AssertionError("checksums.sha256 is missing")
    for line in manifest.read_text(encoding="utf-8").splitlines():
        expected, relative = line.split("  ", 1)
        path = book / relative
        if not path.is_file():
            raise AssertionError(f"Missing checksummed file: {relative}")
        actual = sha256(path)
        if actual != expected:
            raise AssertionError(f"Checksum mismatch: {relative}")


def verify_dataset_manifest(book: Path) -> None:
    manifest = json.loads((book / "data" / "manifest.json").read_text(encoding="utf-8"))
    for name, item in manifest.items():
        path = book / "data" / item["file"]
        if sha256(path) != item["sha256"]:
            raise AssertionError(f"Dataset manifest mismatch: {name}")


def verify_notebooks(book: Path) -> None:
    notebooks = sorted((book / "notebooks").glob("*.ipynb"))
    included_pages = {path.stem for path in notebooks} | {"data"}
    if len(notebooks) != EXPECTED_NOTEBOOKS:
        raise AssertionError(f"Expected {EXPECTED_NOTEBOOKS} notebooks, found {len(notebooks)}")
    executable = 0
    for path in notebooks:
        notebook = json.loads(path.read_text(encoding="utf-8"))
        if notebook.get("metadata", {}).get("kernelspec", {}).get("name") != "ir":
            raise AssertionError(f"Unexpected kernel metadata: {path.name}")
        if any(cell.get("cell_type") == "code" for cell in notebook.get("cells", [])):
            executable += 1
        text = "".join("".join(cell.get("source", [])) for cell in notebook.get("cells", []))
        for match in re.finditer(
            r"https://defenceeconomist\.github\.io/qedlabs/labs/([a-z0-9-]+)\.html",
            text,
        ):
            if match.group(1) in included_pages:
                raise AssertionError(f"Unlocalized included-book link: {path.name}")
    if executable != EXPECTED_EXECUTABLE:
        raise AssertionError(
            f"Expected {EXPECTED_EXECUTABLE} executable notebooks, found {executable}"
        )


def local_target(html: Path, root: Path, url: str) -> Path | None:
    if "{{" in url or "{%" in url:
        return None
    parsed = urlsplit(url)
    if parsed.scheme or parsed.netloc or not parsed.path or parsed.path.startswith(("mailto:", "javascript:")):
        return None
    path = parsed.path
    if path.startswith("/"):
        return root / path.lstrip("/")
    return (html.parent / path).resolve()


def verify_html(book: Path) -> None:
    root = book / "_build" / "html"
    if not (root / "index.html").is_file():
        raise AssertionError("Prebuilt HTML is missing")
    expected_pages = [book / "index.md", book / "offline-setup.md", book / "data.md"]
    expected_pages.extend(sorted((book / "notebooks").glob("*.ipynb")))
    for source in expected_pages:
        relative = source.relative_to(book).with_suffix(".html")
        if not (root / relative).is_file():
            raise AssertionError(f"Missing rendered page: {relative.as_posix()}")

    executable_pages = []
    for notebook_path in sorted((book / "notebooks").glob("*.ipynb")):
        notebook = json.loads(notebook_path.read_text(encoding="utf-8"))
        if any(cell.get("cell_type") == "code" for cell in notebook.get("cells", [])):
            executable_pages.append(root / "notebooks" / notebook_path.with_suffix(".html").name)
    for page in executable_pages:
        rendered = page.read_text(encoding="utf-8", errors="replace")
        if "cell_output" not in rendered:
            raise AssertionError(f"Rendered computational notebook has no outputs: {page.name}")
        if "An error occurred while executing" in rendered or "Traceback (most recent call last)" in rendered:
            raise AssertionError(f"Rendered computational notebook contains an execution error: {page.name}")
    if not any((root / "_images").glob("*")):
        raise AssertionError("Rendered figures are missing from _build/html/_images")

    broken: list[str] = []
    remote_resources: list[str] = []
    css_remote: list[str] = []
    for html in root.rglob("*.html"):
        parser = ResourceParser()
        parser.feed(html.read_text(encoding="utf-8", errors="replace"))
        for tag, url in parser.resources:
            if url.startswith(REMOTE):
                remote_resources.append(f"{html.relative_to(root)}: {tag} {url}")
                continue
            target = local_target(html, root, url)
            if target is not None and not target.exists():
                broken.append(f"{html.relative_to(root)} -> {url}")
        for url in parser.links:
            target = local_target(html, root, url)
            if target is not None and not target.exists():
                broken.append(f"{html.relative_to(root)} -> {url}")
    css_pattern = re.compile(r"url\(\s*['\"]?(https?:)?//", re.I)
    for css in root.rglob("*.css"):
        if css_pattern.search(css.read_text(encoding="utf-8", errors="replace")):
            css_remote.append(str(css.relative_to(root)))
    if remote_resources:
        raise AssertionError("Remote runtime resources:\n" + "\n".join(remote_resources[:20]))
    if css_remote:
        raise AssertionError("Remote CSS resources: " + ", ".join(css_remote))
    if broken:
        raise AssertionError("Broken local links/resources:\n" + "\n".join(broken[:30]))


def verify_versions(book: Path) -> None:
    python = book / ".venv" / "bin" / "python"
    if not python.is_file():
        return
    result = subprocess.run(
        [str(python), "-c", "import jupyter_book, jupyterlab; print(jupyter_book.__version__, jupyterlab.__version__)"],
        check=True,
        capture_output=True,
        text=True,
    )
    if result.stdout.strip() != "1.0.4.post1 4.6.4":
        raise AssertionError("Unexpected Python tool versions: " + result.stdout.strip())

    r_library = book / ".r-library"
    if not r_library.is_dir():
        return
    r_code = r'''
args <- commandArgs(trailingOnly = TRUE)
lock <- jsonlite::fromJSON(args[[1]], simplifyVector = FALSE)
stopifnot(as.character(getRversion()) == lock$R$Version)
expected <- vapply(lock$Packages, function(x) x$Version, character(1))
installed <- vapply(names(expected), function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) return(NA_character_)
  as.character(packageVersion(pkg))
}, character(1))
same_version <- mapply(function(actual, wanted) {
  !is.na(actual) && package_version(actual) == package_version(wanted)
}, installed, expected, USE.NAMES = FALSE)
bad <- names(expected)[!same_version]
if (length(bad)) {
  details <- paste0(bad, " expected=", expected[bad], " installed=", installed[bad])
  stop("R lock mismatch: ", paste(details, collapse = "; "))
}
local_library <- normalizePath(Sys.getenv("R_LIBS"), mustWork = TRUE)
augsynth_path <- normalizePath(find.package("augsynth"), mustWork = TRUE)
stopifnot(startsWith(augsynth_path, paste0(local_library, .Platform$file.sep)))
marker <- file.path(local_library, ".augsynth-source-sha256")
stopifnot(
  file.exists(marker),
  identical(
    readLines(marker, warn = FALSE),
    "af6f7d84002b185b4672d7c0dfb85f0a6f9edab96b72fccc75e516543c32811e"
  )
)
cat(length(expected), "locked R packages match\n")
'''
    env = os.environ.copy()
    env["R_LIBS_USER"] = str(r_library)
    env["R_LIBS"] = str(r_library)
    subprocess.run(
        ["Rscript", "-e", r_code, str(book / "renv.lock")],
        check=True,
        env=env,
    )


def main() -> None:
    book = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    verify_checksums(book)
    verify_dataset_manifest(book)
    verify_notebooks(book)
    verify_html(book)
    verify_versions(book)
    print("Verified checksums, 18 notebooks, 16 executable labs, HTML links, and offline assets")


if __name__ == "__main__":
    main()
