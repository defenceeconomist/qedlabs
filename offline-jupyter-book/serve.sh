#!/usr/bin/env bash
set -euo pipefail

BOOK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
[[ -f "$BOOK_DIR/_build/html/index.html" ]] || {
  echo "Prebuilt HTML is missing; run ./setup.sh and ./build.sh." >&2
  exit 1
}

PYTHON="$BOOK_DIR/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  PYTHON="${PYTHON_BIN:-python3}"
  command -v "$PYTHON" >/dev/null 2>&1 || {
    echo "Python is needed only to serve the prebuilt site." >&2
    echo "Alternatively, open $BOOK_DIR/_build/html/index.html directly." >&2
    exit 1
  }
fi
exec "$PYTHON" -m http.server "${PORT:-8000}" --directory "$BOOK_DIR/_build/html"
