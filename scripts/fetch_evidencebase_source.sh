#!/bin/zsh

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: scripts/fetch_evidencebase_source.sh <collection> <source> [network]" >&2
  echo "example: scripts/fetch_evidencebase_source.sh evaluation gertler_ch8.pdf mcp-evidencebase_default" >&2
  exit 1
fi

collection="$1"
source_name="$2"
network_name="${3:-${EVIDENCEBASE_NETWORK:-mcp-evidencebase_default}}"

EVIDENCEBASE_NETWORK="$network_name" \
docker compose -f docker-compose.evidencebase-fetch.yml run --rm \
  evidencebase-fetch \
  --collection "$collection" \
  --source "$source_name"
