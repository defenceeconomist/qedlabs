#!/usr/bin/env bash
set -euo pipefail

RESOURCE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BOOK_DIR="$(CDPATH= cd -- "$RESOURCE_DIR/../../../../.." && pwd)"
export R_LIBS_USER="$BOOK_DIR/.r-library"
export R_LIBS="$BOOK_DIR/.r-library"
exec R --slave -e 'IRkernel::main()' --args "$1"
