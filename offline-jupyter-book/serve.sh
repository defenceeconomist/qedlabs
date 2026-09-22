#!/usr/bin/env bash
set -euo pipefail

BOOK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
[[ -f "$BOOK_DIR/_build/html/index.html" ]] || {
  echo "Prebuilt HTML is missing; run ./setup.sh and ./build.sh." >&2
  exit 1
}

PYTHON="$BOOK_DIR/.venv/bin/python"
[[ -x "$PYTHON" ]] || PYTHON="${PYTHON_BIN:-python3}"
exec "$PYTHON" -m http.server "${PORT:-8000}" --directory "$BOOK_DIR/_build/html"

