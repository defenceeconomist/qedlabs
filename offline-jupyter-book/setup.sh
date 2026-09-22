#!/usr/bin/env bash
set -euo pipefail

BOOK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"

command -v "$PYTHON_BIN" >/dev/null 2>&1 || {
  echo "Python 3.12 is required (set PYTHON_BIN if it has another name)." >&2
  exit 1
}
command -v Rscript >/dev/null 2>&1 || {
  echo "R 4.5.1 is required." >&2
  exit 1
}
for tool in make gcc g++ gfortran rustc cargo; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "$tool is required to compile the locked CRAN packages." >&2
    exit 1
  }
done

for rust_tool in rustc cargo; do
  rust_version="$($rust_tool --version | awk '{print $2}')"
  if [[ "$(printf '%s\n' "1.78.0" "$rust_version" | sort -V | head -n 1)" != "1.78.0" ]]; then
    echo "$rust_tool 1.78.0 or newer is required (found $rust_version)." >&2
    exit 1
  fi
done

"$PYTHON_BIN" -c 'import sys; assert sys.version_info[:2] == (3, 12), sys.version'
Rscript -e 'stopifnot(getRversion() == "4.5.1")'

if [[ ! -x "$BOOK_DIR/.venv/bin/python" ]]; then
  "$PYTHON_BIN" -m venv "$BOOK_DIR/.venv"
fi
"$BOOK_DIR/.venv/bin/python" -m pip install --disable-pip-version-check \
  --require-hashes -r "$BOOK_DIR/requirements.lock.txt"
"$BOOK_DIR/.venv/bin/python" -m pip check

mkdir -p "$BOOK_DIR/.r-library"
R_LIBS_USER="$BOOK_DIR/.r-library" \
  Rscript "$BOOK_DIR/scripts/setup.R" "$BOOK_DIR" "$BOOK_DIR/.r-library"

KERNEL_DIR="$BOOK_DIR/.venv/share/jupyter/kernels/ir"
mkdir -p "$KERNEL_DIR"
cp "$BOOK_DIR/scripts/kernel.json.in" "$KERNEL_DIR/kernel.json"
cp "$BOOK_DIR/scripts/launch-ir.sh" "$KERNEL_DIR/launch-ir.sh"
chmod 0755 "$KERNEL_DIR/launch-ir.sh"

"$BOOK_DIR/.venv/bin/jupyter" kernelspec list
echo "Setup complete. Run ./build.sh, ./serve.sh, or ./lab.sh."
