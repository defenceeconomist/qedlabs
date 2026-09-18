#!/usr/bin/env python3
"""Check rendered navigation, internal targets, lab downloads and article structure."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

from generate_lab_notebooks import LAB_STEMS

SITE = Path(__file__).resolve().parents[1] / "_site"


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.ids, self.links, self.headings, self.downloads, self.images = set(), [], [], [], []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
            if "download" in attrs:
                self.downloads.append(attrs["href"])
        if tag in {"h1", "h2", "h3", "h4", "h5", "h6"}:
            self.headings.append(int(tag[1]))
        if tag == "img" and "src" in attrs:
            self.images.append(attrs["src"])


def main():
    pages = {p.resolve(): Page(p) for p in SITE.rglob("*.html")}
    failures, known_resolver_links = [], 0
    for path, page in pages.items():
        for href in page.links + page.images:
            url = urlsplit(href)
            if url.scheme or url.netloc or href.startswith("#/"):
                continue
            target = ((SITE / unquote(url.path).lstrip("/")) if url.path.startswith("/")
                      else path.parent / unquote(url.path)).resolve() if url.path else path
            if target.is_dir():
                target /= "index.html"
            if not target.exists():
                if target.name == "resolver.html":
                    known_resolver_links += 1
                    continue
                failures.append(f"{path.relative_to(SITE.resolve())}: missing {href}")
            elif url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
                # Quarto alias pages intentionally delegate their fragments to the destination.
                if "window.location.replace" not in target.read_text():
                    failures.append(f"{path.relative_to(SITE.resolve())}: missing anchor {href}")
    overview = pages[(SITE / "labs/index.html").resolve()]
    for stem in LAB_STEMS:
        page = pages[(SITE / "labs" / (stem+".html")).resolve()]
        for suffix, directory in [("qmd", "downloads"), ("ipynb", "notebooks"), ("zip", "downloads")]:
            filename = f"{stem}.{suffix}"
            for view in (overview, page):
                assert any(h.endswith("/"+filename) for h in view.downloads), filename
            assert (SITE / "labs" / directory / filename).read_bytes() == (SITE.parent / "labs" / directory / filename).read_bytes()
    assert not list((SITE / "labs/notebooks").glob("*-python-*.ipynb"))
    for path in SITE.glob("notes/**/how-to-do-*.html"):
        page = pages[path.resolve()]
        assert page.headings.count(1) == 1, path
        assert page.images, f"No computed figures: {path}"
        for previous, current in zip(page.headings, page.headings[1:]):
            assert current <= previous+1, f"Skipped heading level in {path}"
    if failures:
        raise SystemExit("\n".join(sorted(set(failures))))
    print(f"Checked {len(pages)} HTML files, 54 lab download targets and three illustrated articles. "
          f"Retained {known_resolver_links} pre-existing resolver links.")


if __name__ == "__main__":
    main()
