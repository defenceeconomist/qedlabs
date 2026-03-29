import argparse
import json
import os
import re
import socket
import sys
import urllib.error
import urllib.request
from pathlib import Path


class RedisClient:
    def __init__(self, host: str, port: int, db: int, password: str | None = None):
        self.sock = socket.create_connection((host, port), timeout=30)
        self.reader = self.sock.makefile("rb")
        if password:
            self.command("AUTH", password)
        self.command("SELECT", str(db))

    def close(self) -> None:
        try:
            self.reader.close()
        finally:
            self.sock.close()

    def command(self, *parts: str):
        payload = [f"*{len(parts)}\r\n".encode("utf-8")]
        for part in parts:
            encoded = part.encode("utf-8")
            payload.append(f"${len(encoded)}\r\n".encode("utf-8"))
            payload.append(encoded + b"\r\n")
        self.sock.sendall(b"".join(payload))
        return self._read_reply()

    def _read_reply(self):
        prefix = self.reader.read(1)
        if not prefix:
            raise RuntimeError("Redis connection closed unexpectedly")
        if prefix == b"+":
            return self._read_line()
        if prefix == b"-":
            raise RuntimeError(self._read_line())
        if prefix == b":":
            return int(self._read_line())
        if prefix == b"$":
            length = int(self._read_line())
            if length == -1:
                return None
            data = self.reader.read(length)
            self.reader.read(2)
            return data.decode("utf-8")
        if prefix == b"*":
            length = int(self._read_line())
            if length == -1:
                return None
            return [self._read_reply() for _ in range(length)]
        raise RuntimeError(f"Unsupported Redis reply prefix: {prefix!r}")

    def _read_line(self) -> str:
        return self.reader.readline().rstrip(b"\r\n").decode("utf-8")


def hgetall_to_dict(values):
    if values is None:
        return {}
    return {values[i]: values[i + 1] for i in range(0, len(values), 2)}


def http_json(url: str, payload: dict) -> dict:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("._-")
    return slug or "export"


def fetch_qdrant_chunks(host: str, port: str, collection: str, document_id: str) -> list[dict]:
    url = f"http://{host}:{port}/collections/{collection}/points/scroll"
    offset = None
    chunks: list[dict] = []
    while True:
        payload = {
            "limit": 128,
            "with_payload": True,
            "with_vector": False,
            "filter": {"must": [{"key": "document_id", "match": {"value": document_id}}]},
        }
        if offset is not None:
            payload["offset"] = offset
        page = http_json(url, payload)
        result = page.get("result", {})
        points = result.get("points", [])
        chunks.extend(points)
        offset = result.get("next_page_offset")
        if offset is None:
            return chunks


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch processed document data from EvidenceBase Redis and Qdrant."
    )
    parser.add_argument(
        "--collection",
        help="Logical EvidenceBase collection name, for example 'evaluation'.",
    )
    parser.add_argument(
        "--source",
        help="Source filename or path within the collection, for example 'gertler_ch8.pdf'.",
    )
    parser.add_argument(
        "--source-key",
        help="Full EvidenceBase source key, for example 'evaluation/gertler_ch8.pdf'.",
    )
    parser.add_argument(
        "--qdrant-collection",
        help="Explicit Qdrant collection name. Defaults to 'evidencebase_<collection>'.",
    )
    parser.add_argument(
        "--output-dir",
        help="Explicit output directory. Defaults to $EXPORT_ROOT/<collection>/<source_stem>/.",
    )
    return parser.parse_args()


def resolve_source_key(args: argparse.Namespace) -> tuple[str, str, str]:
    if args.source_key:
        source_key = args.source_key.strip("/")
        if "/" not in source_key:
            raise RuntimeError(
                "source-key must include a collection prefix, for example evaluation/gertler_ch8.pdf"
            )
        collection, relative_source = source_key.split("/", 1)
        return source_key, collection, relative_source

    collection = args.collection or os.environ.get("EVIDENCEBASE_COLLECTION")
    source = args.source or os.environ.get("EVIDENCEBASE_SOURCE")
    if not collection or not source:
        raise RuntimeError("provide either --source-key or both --collection and --source")
    return f"{collection.strip('/')}/{source.strip('/')}", collection.strip("/"), source.strip("/")


def main() -> int:
    args = parse_args()
    redis_host = os.environ.get("EVIDENCEBASE_REDIS_HOST", "evidencebase-redis")
    redis_port = int(os.environ.get("EVIDENCEBASE_REDIS_PORT", "6379"))
    redis_db = int(os.environ.get("EVIDENCEBASE_REDIS_DB", "2"))
    redis_password = os.environ.get("EVIDENCEBASE_REDIS_PASSWORD") or None
    qdrant_host = os.environ.get("EVIDENCEBASE_QDRANT_HOST", "evidencebase-qdrant")
    qdrant_port = os.environ.get("EVIDENCEBASE_QDRANT_PORT", "6333")
    source_key, collection_name, relative_source = resolve_source_key(args)
    qdrant_collection = (
        args.qdrant_collection
        or os.environ.get("EVIDENCEBASE_QDRANT_COLLECTION")
        or f"evidencebase_{collection_name}"
    )
    export_root = Path(os.environ.get("EXPORT_ROOT", "/out"))
    export_dir = (
        Path(args.output_dir)
        if args.output_dir
        else export_root / collection_name / slugify(Path(relative_source).stem)
    )
    export_dir.mkdir(parents=True, exist_ok=True)

    client = RedisClient(redis_host, redis_port, redis_db, redis_password)
    try:
        source_meta = hgetall_to_dict(client.command("HGETALL", f"evidencebase:source:{source_key}:meta"))
        if not source_meta:
            raise RuntimeError(f"Source metadata not found for evidencebase:source:{source_key}:meta")

        document_id = source_meta.get("document_id")
        if not document_id:
            raise RuntimeError("Source metadata does not include a document_id")

        document_meta = hgetall_to_dict(client.command("HGETALL", f"evidencebase:document:{document_id}"))
        partition_payload_raw = client.command("GET", f"evidencebase:document:{document_id}:partition")
        sections_raw = client.command("GET", f"evidencebase:document:{document_id}:sections")
        sources = client.command("SMEMBERS", f"evidencebase:document:{document_id}:sources") or []
    finally:
        client.close()

    partition_key = document_meta.get("partition_key")
    if not partition_key:
        raise RuntimeError("Document metadata does not include a partition_key")

    try:
        partition_payload = json.loads(partition_payload_raw) if partition_payload_raw else []
    except json.JSONDecodeError as exc:
        raise RuntimeError("Document partition payload is not valid JSON") from exc

    try:
        sections = json.loads(sections_raw) if sections_raw else []
    except json.JSONDecodeError as exc:
        raise RuntimeError("Document sections payload is not valid JSON") from exc

    try:
        chunks = fetch_qdrant_chunks(qdrant_host, qdrant_port, qdrant_collection, document_id)
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Failed to fetch Qdrant chunks from {qdrant_host}:{qdrant_port}") from exc

    manifest = {
        "collection": collection_name,
        "relative_source": relative_source,
        "source_key": source_key,
        "document_id": document_id,
        "partition_key": partition_key,
        "qdrant_collection": qdrant_collection,
        "export_dir": str(export_dir),
        "chunk_count": len(chunks),
        "section_count": len(sections),
    }

    files = {
        "manifest.json": manifest,
        "source_meta.json": source_meta,
        "document_meta.json": document_meta,
        "document_sources.json": sources,
        "partition.json": partition_payload,
        "sections.json": sections,
        "chunks.json": chunks,
    }
    for name, payload in files.items():
        (export_dir / name).write_text(
            json.dumps(payload, indent=2, ensure_ascii=True) + "\n",
            encoding="utf-8",
        )

    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"export failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
