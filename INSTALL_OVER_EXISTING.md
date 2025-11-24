Install/upgrade this zbitxd build in place (no reflash)
========================================================

Summary
-------
- Installs build/runtime deps, enables ALSA loopback, and updates boot GPIO/audio config (with backups).
- Backs up your existing logbook/settings before touching them.
- Clones or updates this repo and runs `make && sudo make install` to refresh the daemon/service.

Script (already in repo root)
-----------------------------
1. On the Pi: `cd /home/pi/zbitxd` (or wherever you cloned this repo).
2. `chmod +x install_zbitxd_over_existing.sh`
3. `./install_zbitxd_over_existing.sh`
4. `sudo reboot` when it finishes.

Defaults and options
--------------------
- Repo URL: `https://github.com/dg0jde/zbitxd.git` (override with `REPO_URL=...`).
- Repo dir: `/home/pi/zbitxd` (override with `REPO_DIR=...`).
- Backups land under `/home/pi/zbitxd-backup-YYYYMMDD-HHMMSS/`.
- Config file target: `/boot/firmware/config.txt` if it exists, else `/boot/config.txt`.
- If `git pull --ff-only` fails due to local edits, resolve/stash and rerun.

What the script does
--------------------
- Installs packages: build-essential, pkg-config, git, wget, libasound2-dev, libfftw3-dev, libsqlite3-dev, libsystemd-dev, sqlite3, ncurses-dev, libgtk-3-dev, ntp, ntpstat, iptables-persistent, wiringpi (tolerant if missing).
- Builds wiringPi from source if `gpio` is absent.
- Configures ALSA loopback (`snd-aloop`) via `/etc/modules` and `/etc/modprobe.d/snd-aloop.conf`, and modprobes it immediately.
- Updates `/boot/firmware/config.txt` (or `/boot/config.txt`) with GPIO settings, audioinjector overlay, RTC overlay, disables onboard audio, and backs up the original.
- Disables `fake-hwclock` (prefer RTC/system time).
- Clones or updates the repo, checks out `main`, then runs `make` and `sudo make install` (creates the `zbitxd` user and systemd unit).
- Copies legacy data from `/home/pi/sbitx/data` into `/var/lib/zbitxd` when present (sbitx.db, hw_settings.ini, user_settings.ini) and fixes ownership.
- Reloads systemd, enables, and restarts `zbitxd`.

After running
-------------
- Reboot to apply boot config changes.
- Service should be running via systemd (`sudo systemctl status zbitxd`). Backups remain under `/home/pi/zbitxd-backup-*`.
