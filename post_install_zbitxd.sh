#!/usr/bin/env bash
set -euo pipefail

# Post-install helper for zbitxd.
# - Copies legacy configs/logs from /home/pi/sbitx/data into /var/lib/zbitxd (if missing)
# - Fixes ownership
# - Reloads systemd, enables, and restarts the service
#
# Env overrides:
#   LEGACY_DIR  (default: /home/pi/sbitx/data)
#   STATE_DIR   (default: /var/lib/zbitxd)
#   COPY_MODE   (default: skip) -> "force" to overwrite existing files in STATE_DIR

LEGACY_DIR=${LEGACY_DIR:-/home/pi/sbitx/data}
STATE_DIR=${STATE_DIR:-/var/lib/zbitxd}
COPY_MODE=${COPY_MODE:-skip}

log() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

copy_file() {
  local src="$1" dst="$2"
  [ -f "${src}" ] || return 0
  if [ "${COPY_MODE}" = "force" ]; then
    cp -f "${src}" "${dst}"
  else
    cp -n "${src}" "${dst}" 2>/dev/null || true
  fi
}

log "Ensuring state dir ${STATE_DIR}"
sudo mkdir -p "${STATE_DIR}"

if [ -d "${LEGACY_DIR}" ]; then
  log "Copying legacy data from ${LEGACY_DIR} (mode=${COPY_MODE})"
  copy_file "${LEGACY_DIR}/sbitx.db" "${STATE_DIR}/sbitx.db"
  copy_file "${LEGACY_DIR}/hw_settings.ini" "${STATE_DIR}/hw_settings.ini"
  copy_file "${LEGACY_DIR}/user_settings.ini" "${STATE_DIR}/user_settings.ini"
else
  log "Legacy dir not found (${LEGACY_DIR}); skipping copy"
fi

log "Fixing ownership"
sudo chown zbitxd:zbitxd "${STATE_DIR}"/* 2>/dev/null || true

log "Reloading systemd and enabling zbitxd"
sudo systemctl daemon-reload
sudo systemctl enable zbitxd
sudo systemctl restart zbitxd

log "Done. Check status with: sudo systemctl status zbitxd"
