#!/usr/bin/env bash
set -euo pipefail

BOOK_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

find_python() {
  local candidate
  if [[ -n "${PYTHON_BIN:-}" ]]; then
    candidates=("$PYTHON_BIN")
  else
    candidates=(python3.12 python3)
  fi
  for candidate in "${candidates[@]}"; do
    if command -v "$candidate" >/dev/null 2>&1 &&
      "$candidate" -c 'import sys; raise SystemExit(sys.version_info[:2] != (3, 12))' 2>/dev/null; then
      command -v "$candidate"
      return 0
    fi
  done
  echo "Python 3.12 was not found. Install it or set PYTHON_BIN to its executable." >&2
  return 1
}

PYTHON_BIN="$(find_python)"

missing=()
for tool in Rscript curl make gcc g++ gfortran; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done

missing_packages=()
if command -v dpkg-query >/dev/null 2>&1; then
  debian_packages=(
    curl libcurl4-openssl-dev libfontconfig1-dev libfreetype-dev
    libnode-dev libx11-dev libzmq3-dev pandoc
  )
  for package in "${debian_packages[@]}"; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'ok installed' ||
      missing_packages+=("$package")
  done
fi

if (( ${#missing[@]} || ${#missing_packages[@]} )); then
  if (( ${#missing[@]} )); then
    echo "Missing system tools: ${missing[*]}" >&2
  fi
  if (( ${#missing_packages[@]} )); then
    echo "Missing Ubuntu/Debian packages: ${missing_packages[*]}" >&2
    echo "Install them with:" >&2
    echo "  sudo apt-get install ${missing_packages[*]}" >&2
  fi
  echo "Install the missing prerequisites, then rerun this command." >&2
  exit 1
fi

if ! Rscript -e 'quit(status = as.integer(getRversion() != "4.5.1"))'; then
  echo "R 4.5.1 is required; found $(Rscript -e 'cat(as.character(getRversion()))')." >&2
  exit 1
fi

echo "[1/4] Preparing the Python environment"

if [[ ! -x "$BOOK_DIR/.venv/bin/python" ]] ||
  ! "$BOOK_DIR/.venv/bin/python" -c 'import sys; raise SystemExit(sys.version_info[:2] != (3, 12))' 2>/dev/null; then
  "$PYTHON_BIN" -m venv --clear "$BOOK_DIR/.venv"
fi
"$BOOK_DIR/.venv/bin/python" -m pip install --disable-pip-version-check \
  --quiet --require-hashes -r "$BOOK_DIR/requirements.lock.txt"
"$BOOK_DIR/.venv/bin/python" -m pip check

echo "[2/4] Restoring the R environment"
mkdir -p "$BOOK_DIR/.r-library"
R_LIBS_USER="$BOOK_DIR/.r-library" \
  Rscript "$BOOK_DIR/scripts/setup.R" "$BOOK_DIR" "$BOOK_DIR/.r-library"

echo "[3/4] Registering the R notebook kernel"
KERNEL_DIR="$BOOK_DIR/.venv/share/jupyter/kernels/ir"
mkdir -p "$KERNEL_DIR"
cp "$BOOK_DIR/scripts/kernel.json.in" "$KERNEL_DIR/kernel.json"
cp "$BOOK_DIR/scripts/launch-ir.sh" "$KERNEL_DIR/launch-ir.sh"
chmod 0755 "$KERNEL_DIR/launch-ir.sh"

echo "[4/4] Checking the installation"
"$BOOK_DIR/.venv/bin/jupyter" kernelspec list
echo
echo "Setup complete. Run ./lab.sh for the exercises or ./build.sh to rebuild the book."
