#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro driver uninstaller for Fedora
#
# NOTE: Fedora on Raspberry Pi 4 is no longer actively tested upstream.
# This uninstaller is kept in sync with the canonical layout.
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

# Temp clone left by the installer's curl fallback (rm -rf /tmp/deskpi).
[ -d /tmp/deskpi ] && rm -rf /tmp/deskpi && echo "Removed /tmp/deskpi"

# Legacy Fedora service names
LEGACY_SERVICES=(
    "/lib/systemd/system/deskpi.service"
    "/lib/systemd/system/deskpi-safeshut.service"
    "/etc/systemd/system/deskpi-safeshut.service"
)

echo "Uninstalling DeskPi Fan Control and Cut-off Power services."

if [ -f "$FAN_SERVICE" ] || [ -f "$PWR_SERVICE" ]; then
    systemctl stop    deskpi.service               2>/dev/null || true
    systemctl disable deskpi.service               2>/dev/null || true
    systemctl stop    deskpi-cut-off-power.service 2>/dev/null || true
    systemctl disable deskpi-cut-off-power.service 2>/dev/null || true
fi

# Legacy safeshut service
systemctl stop    deskpi-safeshut.service 2>/dev/null || true
systemctl disable deskpi-safeshut.service 2>/dev/null || true

echo "Removing systemd unit files"
rm -f "$FAN_SERVICE" "$PWR_SERVICE"
for f in "${LEGACY_SERVICES[@]}"; do
    [ -f "$f" ] && rm -f "$f"
done

echo "Removing /usr/bin/ binaries"
for bin in pwmFanControl64 pwmFanControl64V2 pwmFanControl64V3 safeCutOffPower64 deskpi-shutdown-helper \
           pwmControlFan fanStop \
           deskpi-config Deskpi-uninstall; do
    [ -f "$BIN_DIR/$bin" ] && rm -f "$BIN_DIR/$bin"
done
if [ -f /etc/deskpi.conf ]; then
    echo "The following file will be REMOVED: /etc/deskpi.conf"
    echo "--- begin /etc/deskpi.conf ---"
    cat /etc/deskpi.conf
    echo "--- end /etc/deskpi.conf ---"
    printf 'Remove /etc/deskpi.conf? [y/N]: '
    if [ "$DESKPI_ASSUME_YES" = "1" ]; then
        REPLY=y
    else
        read -r REPLY || REPLY=""
    fi
    case "$REPLY" in
        [yY]|[yY][eE][sS])
            rm -f /etc/deskpi.conf
            echo "Removed /etc/deskpi.conf"
            ;;
        *)
            echo "Skipped: /etc/deskpi.conf left in place."
            ;;
    esac
fi
rm -f /etc/logrotate.d/deskpi

echo "Removing dtoverlay line from config.txt"
for f in /boot/efi/config.txt /boot/firmware/config.txt /boot/config.txt; do
    [ -f "$f" ] || continue
    grep -Eq '^(dtoverlay=dwc2|# DeskPi)' "$f" || continue
    echo "The following lines will be REMOVED from $f:"
    grep -nE '^(dtoverlay=dwc2|# DeskPi)' "$f"
    printf 'Apply these changes to %s? [y/N]: ' "$f"
    if [ "$DESKPI_ASSUME_YES" = "1" ]; then
        REPLY=y
    else
        read -r REPLY || REPLY=""
    fi
    case "$REPLY" in
        [yY]|[yY][eE][sS])
            sed -i -e '/^dtoverlay=dwc2/d' -e '/^# DeskPi$/d' "$f"
            echo "Removed DeskPi lines from $f"
            ;;
        *)
            echo "Skipped: $f left unchanged."
            ;;
    esac
done

systemctl daemon-reload
echo "Uninstall DeskPi Driver Successfully."
