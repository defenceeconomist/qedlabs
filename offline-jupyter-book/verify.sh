#!/usr/bin/env bash
set -euo pipefail

BOOK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PYTHON="$BOOK_DIR/.venv/bin/python"
[[ -x "$PYTHON" ]] || PYTHON="${PYTHON_BIN:-python3}"
exec "$PYTHON" "$BOOK_DIR/scripts/verify_book.py" "$BOOK_DIR"

