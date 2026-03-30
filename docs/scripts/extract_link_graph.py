from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlparse, urlunparse

import yaml


ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "_quarto.yml"
PAYLOAD_PATH = ROOT / "data" / "link_graph_payload.js"
EXCLUDE_PARTS = {".quarto", "_site", "site_libs", "assets", "data", "scripts"}
MARKDOWN_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
URL_RE = re.compile(r"https?://[^\s<>{}\"')]+")


def load_config() -> dict:
    return yaml.safe_load(CONFIG_PATH.read_text(encoding="utf-8"))


def iter_qmd_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*.qmd"):
        rel = path.relative_to(ROOT)
        if any(part in EXCLUDE_PARTS for part in rel.parts):
            continue
        files.append(path)
    return sorted(files)


def parse_front_matter(text: str) -> tuple[dict, str]:
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text
    front = yaml.safe_load(text[4:end]) or {}
    body = text[end + 5 :]
    return front, body


def qmd_to_html(rel_path: Path) -> str:
    return rel_path.with_suffix(".html").as_posix()


def title_case(value: str) -> str:
    parts = re.split(r"[-_]", value)
    return " ".join(part[:1].upper() + part[1:] for part in parts if part)


def label_from_rel(rel_path: Path) -> str:
    if rel_path.as_posix() == "index.qmd":
        return "QED Labs"
    if rel_path.name == "index.qmd":
        return title_case(rel_path.parent.name)
    return title_case(rel_path.stem)


def clean_url(url: str) -> str:
    parsed = urlparse(url.strip().strip("<>").rstrip(".,};:"))
    return urlunparse((parsed.scheme, parsed.netloc, parsed.path, "", parsed.query, ""))


def normalize_internal_target(source_rel: Path, target: str) -> str | None:
    cleaned = target.strip().strip("<>").split("#", 1)[0].split("?", 1)[0]
    if not cleaned or cleaned.startswith(("http://", "https://", "mailto:", "javascript:")):
        return None
    candidate = (source_rel.parent / cleaned).resolve()
    try:
        rel = candidate.relative_to(ROOT.resolve())
    except ValueError:
        return None
    if any(part in EXCLUDE_PARTS for part in rel.parts):
        return None
    if rel.suffix.lower() == ".qmd":
        return rel.as_posix()
    if rel.suffix.lower() == ".html":
        return rel.with_suffix(".qmd").as_posix()
    return None


def extract_linkable_text(body: str) -> str:
    without_fences = re.sub(r"```.*?```", "", body, flags=re.S)
    without_scripts = re.sub(r"<script\b.*?</script>", "", without_fences, flags=re.S | re.I)
    without_styles = re.sub(r"<style\b.*?</style>", "", without_scripts, flags=re.S | re.I)
    kept_lines: list[str] = []
    for line in without_styles.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("<"):
            continue
        kept_lines.append(line)
    return "\n".join(kept_lines)


def extract_hrefs(items: list | None) -> list[str]:
    hrefs: list[str] = []
    for item in items or []:
        if not isinstance(item, dict):
            continue
        href = item.get("href")
        if href:
            hrefs.append(href)
        hrefs.extend(extract_hrefs(item.get("contents")))
    return hrefs


def external_label(url: str) -> str:
    parsed = urlparse(url)
    host = parsed.netloc.replace("www.", "")
    path_parts = [part for part in parsed.path.split("/") if part]
    tail = path_parts[-1] if path_parts else host
    tail = tail.replace(".html", "").replace(".htm", "").replace("-", " ").replace("_", " ")
    label = f"{host}: {tail}".strip()
    if len(label) > 38:
        return f"{label[:35].rstrip()}..."
    return label


def add_edge(edges: dict[tuple[str, str], dict], source: str, target: str, kind: str) -> None:
    if not source or not target or source == target:
        return
    edges[(source, target)] = {"source": source, "target": target, "kind": kind}


def main() -> None:
    config = load_config()
    page_nodes: dict[str, dict] = {}
    external_nodes: dict[str, dict] = {}
    edges: dict[tuple[str, str], dict] = {}

    for path in iter_qmd_files():
        rel = path.relative_to(ROOT)
        front, body = parse_front_matter(path.read_text(encoding="utf-8"))
        linkable_body = extract_linkable_text(body)
        node_id = rel.as_posix()
        page_nodes[node_id] = {
            "id": node_id,
            "label": str(front.get("title") or label_from_rel(rel)),
            "kind": "internal",
            "path": node_id,
        }

        for raw_target in MARKDOWN_LINK_RE.findall(linkable_body):
            if raw_target.startswith(("http://", "https://")):
                url = clean_url(raw_target)
                external_nodes.setdefault(
                    url,
                    {
                        "id": url,
                        "label": external_label(url),
                        "kind": "external",
                        "url": url,
                    },
                )
                add_edge(edges, node_id, url, "external")
                continue

            internal_target = normalize_internal_target(rel, raw_target)
            if internal_target:
                add_edge(edges, node_id, internal_target, "internal")

        for url in URL_RE.findall(linkable_body):
            cleaned = clean_url(url)
            external_nodes.setdefault(
                cleaned,
                {
                    "id": cleaned,
                    "label": external_label(cleaned),
                    "kind": "external",
                    "url": cleaned,
                },
            )
            add_edge(edges, node_id, cleaned, "external")

    website = config.get("website", {})
    for nav_item in website.get("navbar", {}).get("left", []):
        if not isinstance(nav_item, dict) or not nav_item.get("href"):
            continue
        target = normalize_internal_target(Path("index.qmd"), nav_item["href"])
        if target and target in page_nodes:
            add_edge(edges, "index.qmd", target, "internal")

    for sidebar in website.get("sidebar", []):
        contents = sidebar.get("contents", [])
        overview = next((item.get("href") for item in contents if isinstance(item, dict) and item.get("href")), None)
        overview_target = normalize_internal_target(Path("index.qmd"), overview) if overview else None
        if not overview_target:
            continue
        for href in extract_hrefs(contents):
            target = normalize_internal_target(Path("index.qmd"), href)
            if target and target in page_nodes and overview_target in page_nodes:
                add_edge(edges, overview_target, target, "internal")

    incoming: defaultdict[str, set[str]] = defaultdict(set)
    outgoing: defaultdict[str, set[str]] = defaultdict(set)
    neighbors: defaultdict[str, set[str]] = defaultdict(set)

    for edge in edges.values():
        source = edge["source"]
        target = edge["target"]
        outgoing[source].add(target)
        incoming[target].add(source)
        neighbors[source].add(target)
        neighbors[target].add(source)

    connected_ids = set(neighbors)
    nodes: list[dict] = []
    for node_id, node in page_nodes.items():
        if node_id != "index.qmd" and node_id not in connected_ids:
            continue
        nodes.append(
            {
                **node,
                "incoming": len(incoming[node_id]),
                "outgoing": len(outgoing[node_id]),
                "degree": len(neighbors[node_id]),
            }
        )

    for node_id, node in external_nodes.items():
        if node_id not in connected_ids:
            continue
        nodes.append(
            {
                **node,
                "incoming": len(incoming[node_id]),
                "outgoing": len(outgoing[node_id]),
                "degree": len(neighbors[node_id]),
            }
        )

    nodes.sort(key=lambda item: (item["kind"], item["label"].lower(), item["id"]))
    edge_list = sorted(edges.values(), key=lambda item: (item["source"], item["target"]))

    payload = {
        "nodes": nodes,
        "edges": edge_list,
    }

    PAYLOAD_PATH.parent.mkdir(parents=True, exist_ok=True)
    PAYLOAD_PATH.write_text(
        "window.__LINK_GRAPH__ = " + json.dumps(payload, ensure_ascii=False, indent=2) + ";\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
