#!/usr/bin/env bash
set -euo pipefail

# In-place installer/upgrader for zbitxd (no reflash). Run as user 'pi'.
# Overrides: REPO_URL, REPO_DIR, BACKUP_BASE

REPO_URL=${REPO_URL:-https://github.com/dg0jde/zbitxd.git}
REPO_DIR=${REPO_DIR:-/home/pi/zbitxd}
BACKUP_BASE=${BACKUP_BASE:-/home/pi}
BACKUP_DIR="${BACKUP_BASE}/zbitxd-backup-$(date +%Y%m%d-%H%M%S)"
CONFIG_TXT="/boot/firmware/config.txt"
[ -f "${CONFIG_TXT}" ] || CONFIG_TXT="/boot/config.txt"
export DEBIAN_FRONTEND=noninteractive

log() { printf "\n[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
append_if_missing() {
  local line="$1" file="$2"
  sudo grep -qF -- "${line}" "${file}" >/dev/null 2>&1 || echo "${line}" | sudo tee -a "${file}" >/dev/null
}

log "Backing up existing data to ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"
if [ -d /home/pi/sbitx/data ]; then
  mkdir -p "${BACKUP_DIR}/sbitx_data"
  for f in sbitx.db hw_settings.ini user_settings.ini; do
    [ -f "/home/pi/sbitx/data/${f}" ] && cp -a "/home/pi/sbitx/data/${f}" "${BACKUP_DIR}/sbitx_data/" || true
  done
fi
if [ -d /var/lib/zbitxd ]; then
  sudo cp -a /var/lib/zbitxd "${BACKUP_DIR}/var_lib_zbitxd" 2>/dev/null || true
fi

log "Installing base build/runtime packages"
sudo apt-get update
sudo apt-get install -y build-essential pkg-config git wget \
  libasound2-dev libfftw3-dev libfftw3-single3 libsqlite3-dev libsystemd-dev sqlite3 \
  ncurses-dev libgtk-3-dev ntp ntpstat iptables-persistent
sudo apt-get install -y wiringpi || true

log "Installing wiringPi from source if gpio is missing"
if ! command -v gpio >/dev/null 2>&1; then
  tmpdir="$(mktemp -d)"
  git clone https://github.com/WiringPi/WiringPi.git "${tmpdir}/wiringpi"
  (cd "${tmpdir}/wiringpi" && ./build)
  rm -rf "${tmpdir}"
fi

log "Enable ALSA loopback at boot and now"
append_if_missing "snd-aloop" /etc/modules
echo "options snd-aloop enable=1,1,1 index=1,2,3" | sudo tee /etc/modprobe.d/snd-aloop.conf >/dev/null
sudo modprobe snd-aloop enable=1,1,1 index=1,2,3 || true

log "Update ${CONFIG_TXT} for GPIO/audio (backup kept)"
sudo cp "${CONFIG_TXT}" "${CONFIG_TXT}.bak.$(date +%Y%m%d-%H%M%S)" || true
sudo sed -i 's/^dtparam=audio=on/#dtparam=audio=on/' "${CONFIG_TXT}" || true
sudo sed -i 's/^dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d,noaudio/' "${CONFIG_TXT}" || true
for line in \
  "# zbitxd options" \
  "gpio=4,5,9,10,11,17,22,27=ip,pu" \
  "gpio=24,23=op,pu" \
  "avoid_warnings=1" \
  "dtoverlay=audioinjector-wm8731-audio" \
  "dtoverlay=i2c-rtc-gpio,ds1307,bus=2,i2c_gpio_sda=13,i2c_gpio_scl=6"
do
  append_if_missing "${line}" "${CONFIG_TXT}"
done

log "Disable fake-hwclock (prefer RTC/system time)"
sudo systemctl disable fake-hwclock >/dev/null 2>&1 || true
sudo systemctl stop fake-hwclock >/dev/null 2>&1 || true

log "Clone or update repo at ${REPO_DIR}"
if [ ! -d "${REPO_DIR}/.git" ]; then
  sudo -u pi git clone "${REPO_URL}" "${REPO_DIR}"
fi
cd "${REPO_DIR}"
sudo -u pi git fetch --all --tags
sudo -u pi git checkout main
sudo -u pi git pull --ff-only origin main

log "Build and install zbitxd"
sudo -u pi make
sudo make install

log "Restore/copy config and log data into /var/lib/zbitxd if available"
if [ -d /home/pi/sbitx/data ]; then
  sudo mkdir -p /var/lib/zbitxd
  for f in sbitx.db hw_settings.ini user_settings.ini; do
    [ -f "/home/pi/sbitx/data/${f}" ] && sudo cp -n "/home/pi/sbitx/data/${f}" /var/lib/zbitxd/ || true
  done
fi
sudo chown zbitxd:zbitxd /var/lib/zbitxd/* 2>/dev/null || true

log "Enable and restart service"
sudo systemctl daemon-reload
sudo systemctl enable zbitxd
sudo systemctl restart zbitxd

log "Done. Reboot recommended to apply ${CONFIG_TXT} changes."
echo "Reboot with: sudo reboot"
