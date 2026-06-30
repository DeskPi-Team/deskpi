#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro driver uninstaller for DietPi (Raspberry Pi OS base)
#==============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root (sudo)" >&2
    exit 1
fi

BIN_DIR="/usr/bin"
SYSTEMD_DIR="/etc/systemd/system"
FAN_SERVICE="$SYSTEMD_DIR/deskpi.service"
PWR_SERVICE="$SYSTEMD_DIR/deskpi-cut-off-power.service"

if [ -d /tmp/deskpi ]; then
    rm -rf /tmp/deskpi
    echo "Removed /tmp/deskpi"
fi

if [ -f "$FAN_SERVICE" ]; then
    echo "Stopping and disabling deskpi.service"
    systemctl stop    deskpi.service 2>/dev/null || true
    systemctl disable deskpi.service 2>/dev/null || true
    rm -f "$FAN_SERVICE"
fi

if [ -f "$PWR_SERVICE" ]; then
    echo "Stopping and disabling deskpi-cut-off-power.service"
    systemctl stop    deskpi-cut-off-power.service 2>/dev/null || true
    systemctl disable deskpi-cut-off-power.service 2>/dev/null || true
    rm -f "$PWR_SERVICE"
fi

for bin in pwmFanControl64 pwmFanControl64V2 safeCutOffPower64 deskpi-config; do
    [ -f "$BIN_DIR/$bin" ] && rm -f "$BIN_DIR/$bin" && echo "Removed $BIN_DIR/$bin"
done

# Remove dwc2 overlay if we are the ones who added it (best-effort: just remove
# the line; users who added it manually can re-add it).
for f in /boot/firmware/config.txt /boot/config.txt; do
    if [ -f "$f" ]; then
        sed -i '/^dtoverlay=dwc2/d' "$f"
    fi
done

systemctl daemon-reload

echo "DeskPi Pro driver has been uninstalled successfully!"
echo "Please reboot manually if you also removed dwc2 overlay:  sudo reboot"
