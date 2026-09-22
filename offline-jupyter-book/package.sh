#!/usr/bin/env bash
set -euo pipefail

BOOK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PARENT_DIR="$(dirname -- "$BOOK_DIR")"
BOOK_NAME="$(basename -- "$BOOK_DIR")"
ARCHIVE="$BOOK_DIR/dist/qedlabs-offline-jupyter-book-linux-x86_64.tar.gz"

"$BOOK_DIR/verify.sh"
mkdir -p "$BOOK_DIR/dist"
tar \
  --exclude="$BOOK_NAME/.venv" \
  --exclude="$BOOK_NAME/.r-library" \
  --exclude="$BOOK_NAME/.jupyter_cache" \
  --exclude="$BOOK_NAME/.ipynb_checkpoints" \
  --exclude="$BOOK_NAME/_build/.doctrees" \
  --exclude="$BOOK_NAME/_build/jupyter_execute" \
  --exclude="$BOOK_NAME/_build/.jupyter_cache" \
  --exclude="$BOOK_NAME/dist" \
  -C "$PARENT_DIR" -czf "$ARCHIVE" "$BOOK_NAME"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$ARCHIVE" | sed "s|$BOOK_DIR/dist/||" > "$ARCHIVE.sha256"
else
  shasum -a 256 "$ARCHIVE" | sed "s|$BOOK_DIR/dist/||" > "$ARCHIVE.sha256"
fi
echo "Created $ARCHIVE"
echo "Created $ARCHIVE.sha256"
