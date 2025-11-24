#!/usr/bin/env bash
set -euo pipefail

# Generate grids.txt from the zbitxd logbook (sbitx.db).
# Default paths: /var/lib/zbitxd/sbitx.db -> /var/lib/zbitxd/grids.txt
# Usage:
#   DB=/var/lib/zbitxd/sbitx.db OUT=/var/lib/zbitxd/grids.txt ./generate_grids.sh
# Notes: ****UNTESTED****; requires sqlite3 and assumes grid is stored in exch_recv.

DB=${DB:-/var/lib/zbitxd/sbitx.db}
OUT=${OUT:-/var/lib/zbitxd/grids.txt}

log() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

if [ ! -f "${DB}" ]; then
  log "Database not found: ${DB}"
  exit 1
fi

tmp=$(mktemp)
trap 'rm -f "${tmp}"' EXIT

log "Extracting distinct grids from ${DB}"
# Assumes grid is in exch_recv; adjust query if your schema differs.
sqlite3 "${DB}" "SELECT DISTINCT UPPER(exch_recv) FROM logbook WHERE exch_recv LIKE '__%';" \
  | grep -E '^[A-R]{2}[0-9]{2}$' \
  | sort -u > "${tmp}"

lines=$(wc -l < "${tmp}")
log "Found ${lines} grid(s); writing ${OUT}"
sudo mkdir -p "$(dirname "${OUT}")"
sudo cp "${tmp}" "${OUT}"
sudo chown zbitxd:zbitxd "${OUT}" 2>/dev/null || true

log "Done."
