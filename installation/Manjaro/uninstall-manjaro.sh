#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro driver uninstaller for Manjaro ARM-64
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

# Legacy Manjaro service names
LEGACY_SERVICES=(
    "/etc/systemd/system/deskpiFanControl.service"
    "/etc/systemd/system/deskpiFanStop.service"
    "/lib/systemd/system/deskpiFanControl.service"
    "/lib/systemd/system/deskpiFanStop.service"
)

echo "Uninstalling DeskPi Fan Control and Cut-off Power services."

if [ -f "$FAN_SERVICE" ] || [ -f "$PWR_SERVICE" ]; then
    systemctl stop    deskpi.service               2>/dev/null || true
    systemctl disable deskpi.service               2>/dev/null || true
    systemctl stop    deskpi-cut-off-power.service 2>/dev/null || true
    systemctl disable deskpi-cut-off-power.service 2>/dev/null || true
fi

# Legacy Manjaro service names
systemctl stop    deskpiFanControl.service 2>/dev/null || true
systemctl disable deskpiFanControl.service 2>/dev/null || true
systemctl stop    deskpiFanStop.service    2>/dev/null || true
systemctl disable deskpiFanStop.service    2>/dev/null || true

echo "Removing systemd unit files"
rm -f "$FAN_SERVICE" "$PWR_SERVICE"
for f in "${LEGACY_SERVICES[@]}"; do
    [ -f "$f" ] && rm -f "$f"
done

echo "Removing /usr/bin/ binaries"
for bin in pwmFanControl64 pwmFanControl64V2 safeCutOffPower64 \
           deskpiFanControl deskpiFanStop \
           pwmFanControl fanStop \
           deskpi-config Deskpi-uninstall; do
    [ -f "$BIN_DIR/$bin" ] && rm -f "$BIN_DIR/$bin"
done
[ -f /etc/deskpi.conf ] && rm -f /etc/deskpi.conf

echo "Removing dtoverlay line from config.txt"
for f in /boot/firmware/config.txt /boot/config.txt; do
    if [ -f "$f" ]; then
        sed -i '/^dtoverlay=dwc2/d' "$f"
    fi
done

systemctl daemon-reload
echo "Uninstall DeskPi Driver Successfully."
