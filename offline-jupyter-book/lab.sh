#!/usr/bin/env bash
set -euo pipefail

BOOK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
[[ -x "$BOOK_DIR/.venv/bin/jupyter-lab" ]] || {
  echo "Run ./setup.sh first." >&2
  exit 1
}

export JUPYTER_PATH="$BOOK_DIR/.venv/share/jupyter${JUPYTER_PATH:+:$JUPYTER_PATH}"
export R_LIBS_USER="$BOOK_DIR/.r-library"
export R_LIBS="$BOOK_DIR/.r-library"
cd "$BOOK_DIR"
exec "$BOOK_DIR/.venv/bin/jupyter-lab" notebooks
