from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path
from urllib.parse import urlparse, urlunparse

import yaml


DEFAULT_ROOT = Path(__file__).resolve().parent.parent
EXCLUDE_PARTS = {".quarto", "_site", "site_libs", "assets", "data", "scripts"}
MARKDOWN_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
URL_RE = re.compile(r"https?://[^\s<>{}\"')]+")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build the Quasi-Experimental Design Labs link graph payload from the docs source tree."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help="Docs project root containing _quarto.yml and the .qmd files.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        help="Optional Quarto config path. Defaults to <root>/_quarto.yml.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional output path. Defaults to <root>/data/notes_link_graph_payload.json.",
    )
    parser.add_argument(
        "--include-prefix",
        action="append",
        default=[],
        help="Restrict internal pages to paths beginning with this prefix. May be provided multiple times.",
    )
    return parser.parse_args()


def resolve_path(root: Path, path: Path | None, fallback: str) -> Path:
    if path is None:
        return root / fallback
    return path if path.is_absolute() else root / path


def load_config(config_path: Path) -> dict:
    return yaml.safe_load(config_path.read_text(encoding="utf-8"))


def normalize_prefix(prefix: str) -> str:
    normalized = prefix.strip().lstrip("./")
    return normalized.rstrip("/")


def iter_qmd_files(root: Path, include_prefixes: list[str] | None = None) -> list[Path]:
    files: list[Path] = []
    normalized_prefixes = [normalize_prefix(prefix) for prefix in include_prefixes or [] if prefix.strip()]
    for path in root.rglob("*.qmd"):
        rel = path.relative_to(root)
        if any(part in EXCLUDE_PARTS for part in rel.parts):
            continue
        rel_posix = rel.as_posix()
        if normalized_prefixes and not any(
            rel_posix == prefix or rel_posix.startswith(f"{prefix}/") for prefix in normalized_prefixes
        ):
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


def title_case(value: str) -> str:
    parts = re.split(r"[-_]", value)
    return " ".join(part[:1].upper() + part[1:] for part in parts if part)


def label_from_rel(rel_path: Path) -> str:
    if rel_path.as_posix() == "index.qmd":
        return "Quasi-Experimental Design Labs"
    if rel_path.name == "index.qmd":
        return title_case(rel_path.parent.name)
    return title_case(rel_path.stem)


def clean_url(url: str) -> str:
    parsed = urlparse(url.strip().strip("<>").rstrip(".,};:"))
    return urlunparse((parsed.scheme, parsed.netloc, parsed.path, "", parsed.query, ""))


def normalize_internal_target(root: Path, source_rel: Path, target: str) -> str | None:
    cleaned = target.strip().strip("<>").split("#", 1)[0].split("?", 1)[0]
    if not cleaned or cleaned.startswith(("http://", "https://", "mailto:", "javascript:")):
        return None
    candidate = (root / source_rel.parent / cleaned).resolve()
    try:
        rel = candidate.relative_to(root.resolve())
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


def build_payload(root: Path, config: dict, include_prefixes: list[str] | None = None) -> dict:
    page_nodes: dict[str, dict] = {}
    external_nodes: dict[str, dict] = {}
    edges: dict[tuple[str, str], dict] = {}
    normalized_prefixes = [normalize_prefix(prefix) for prefix in include_prefixes or [] if prefix.strip()]

    for path in iter_qmd_files(root, normalized_prefixes):
        rel = path.relative_to(root)
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

            internal_target = normalize_internal_target(root, rel, raw_target)
            if internal_target and (
                not normalized_prefixes
                or any(
                    internal_target == prefix or internal_target.startswith(f"{prefix}/")
                    for prefix in normalized_prefixes
                )
            ):
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
    for sidebar in website.get("sidebar", []):
        contents = sidebar.get("contents", [])
        overview = next(
            (item.get("href") for item in contents if isinstance(item, dict) and item.get("href")),
            None,
        )
        overview_target = (
            normalize_internal_target(root, Path("index.qmd"), overview) if overview else None
        )
        if not overview_target:
            continue
        for href in extract_hrefs(contents):
            target = normalize_internal_target(root, Path("index.qmd"), href)
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
    return {"nodes": nodes, "edges": edge_list}


def serialize_payload(payload: dict, output_path: Path) -> str:
    serialized = json.dumps(payload, ensure_ascii=False, indent=2)
    if output_path.suffix.lower() == ".js":
        return f"window.__LINK_GRAPH__ = {serialized};\n"
    return serialized + "\n"


def write_payload(payload: dict, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(serialize_payload(payload, output_path), encoding="utf-8")


def main() -> None:
    args = parse_args()
    root = args.root.resolve()
    config_path = resolve_path(root, args.config, "_quarto.yml")
    output_path = resolve_path(root, args.output, "data/notes_link_graph_payload.json")

    config = load_config(config_path)
    payload = build_payload(root, config, args.include_prefix)
    write_payload(payload, output_path)


if __name__ == "__main__":
    main()
