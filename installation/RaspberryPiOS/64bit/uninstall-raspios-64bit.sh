#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro driver uninstaller for RaspiOS-ARM-64-lite (Buster+)
#==============================================================================
set -euo pipefail

#############################  User-adjustable vars  ###########################
SYSTEMD_DIR="/etc/systemd/system"
FAN_SERVICE="$SYSTEMD_DIR/deskpi.service"
PWR_SERVICE="$SYSTEMD_DIR/deskpi-cut-off-power.service"
BIN_DIR="/usr/bin"
FAN_BIN="pwmFanControl64"          # legacy name used in early packages
CFG_BIN="deskpi-config"
AUTO_REBOOT=0

# ##############################  Helper functions  ##############################
# if [ -e /lib/lsb/init-functions ]; then
#     # shellcheck source=/dev/null
#     . /lib/lsb/init-functions
# else
#     log_action_msg()  { echo "[INFO]  $*"; }
#     log_action_warn() { echo "[WARN]  $*"; }
# fi
# log_info() { log_action_msg "$*"; }
# log_warn() { log_action_warn "$*"; }
# log_die()  { echo "[ERROR] $*" >&2; exit 1; }

# ##############################  CLI parser  ####################################
# for arg; do
#     case "$arg" in
#         --auto-reboot) AUTO_REBOOT=1 ;;
#         -h|--help)
#             cat <<EOF
# Usage: sudo $0 [OPTIONS]
# OPTIONS:
#   --auto-reboot   Reboot automatically after uninstall
#   -h, --help      Show this help
# EOF
#             exit 0
#             ;;
#         *) log_die "Unknown argument: $arg" ;;
#     esac
# done

##############################  Pre-flight check  ##############################
[ "$(id -u)" -eq 0 ] || echo "Run this script as root (sudo)"

##############################  Stop & disable  ################################
if [ -f "$FAN_SERVICE" ]; then
    echo "Stopping and disabling deskpi.service"
    systemctl stop    deskpi.service 2>/dev/null || true
    systemctl disable deskpi.service 2>/dev/null || true
    rm -f "$FAN_SERVICE"
fi

if [ -f "$PWR_SERVICE" ]; then
    echo "Stopping and disabling deskpi-cut-off-power.service"
    systemctl disable deskpi-cut-off-power.service 2>/dev/null || true
    rm -f "$PWR_SERVICE"
fi

##############################  Remove binaries  ###############################
for bin in "$FAN_BIN" "safeCutOffPower64" "$CFG_BIN" "pwmFanControl64V2"; do
    [ -f "$BIN_DIR/$bin" ] && rm -f "$BIN_DIR/$bin" && echo "Removed $BIN_DIR/$bin"
done

##############################  Clean temp clone  ##############################
if [ -d /tmp/deskpi ]; then
    rm -rf /tmp/deskpi
    echo "Removed /tmp/deskpi"
fi

##############################  Final message  #################################
echo "DeskPi Pro driver has been uninstalled successfully!"
if [ "$AUTO_REBOOT" -eq 1 ]; then
    echo "System will reboot in 5 seconds..."
    sync && sleep 5 && reboot
else
    echo "Please reboot manually if you also removed dwc2 overlay manually:  sudo reboot"
fi
