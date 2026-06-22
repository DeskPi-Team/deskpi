#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro fan-driver installer for RaspiOS-ARM-64-lite (Buster+)
# https://github.com/DeskPi-Team/deskpi
#==============================================================================
set -euo pipefail

#############################  User-adjustable vars  ###########################
# REPO_URL="https://github.com/DeskPi-Team/deskpi"  # No longer needed - building locally
# TMP_DIR="/tmp/deskpi"                              # No longer needed - building locally
BIN_DIR="/usr/bin"
SYSTEMD_DIR="/etc/systemd/system"
FAN_BIN="pwmFanControl64V2"
CFG_BIN="deskpi-config"
FAN_SERVICE="$SYSTEMD_DIR/deskpi.service"
CONFIG_TXT="/boot/firmware/config.txt"
CONFIG_TXT_BKP="${CONFIG_TXT}.$(date +%F-%H-%M-%S).bak"
AUTO_REBOOT=0

################################  Helper fns  ##################################
# if [ -e /lib/lsb/init-functions ]; then
#     # shellcheck source=/dev/null
#     . /lib/lsb/init-functions
# else
#     log_action_msg()  { echo "[INFO]  $*"; }
#     log_action_warn() { echo "[WARN]  $*"; }
#     log_action_err()  { echo "[ERROR] $*" >&2; }
# fi
# log_info() { log_action_msg "$*"; }
# log_warn() { log_action_warn "$*"; }
# log_die()  { log_action_err "$*"; exit 1; }

################################  CLI parser  ##################################
# for arg; do
#     case "$arg" in
#         --auto-reboot) AUTO_REBOOT=1 ;;
#         -h|--help)
#             cat <<EOF
# Usage: sudo $0 [OPTIONS]
# OPTIONS:
#   --auto-reboot   Reboot automatically after installation
#   -h, --help      Show this help
# EOF
#             exit 0
#             ;;
#         *) log_die "Unknown argument: $arg" ;;
#     esac
# done

#############################  Pre-flight checks  ##############################
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root (sudo)" >&2
    exit 1
fi

if ! command -v gcc >/dev/null; then
    echo "gcc not found, installing..."
    apt-get update -qq >/dev/null
    apt-get install -y build-essential >/dev/null || echo "Failed to install build-essential"
fi

if ! command -v make >/dev/null; then
    echo "make not found, installing..."
    apt-get update -qq >/dev/null
    apt-get install -y build-essential >/dev/null || echo "Failed to install build-essential"
fi

#############################  Stop & clean old units  #########################
systemctl stop    deskpi.service 2>/dev/null || true
systemctl disable deskpi.service 2>/dev/null || true
rm -f "$FAN_SERVICE"

#############################  Build binaries  ###################################
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SOURCE_DIR="$SCRIPT_DIR/../../drivers/c"
CONFIG_DIR="$SCRIPT_DIR/../.."

echo "Building binaries in $SOURCE_DIR"
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory not found at $SOURCE_DIR"
    exit 1
fi

# Build the binaries using make
cd "$SOURCE_DIR"
echo "Running make clean..."
make clean
echo "Running make all..."
if ! make all; then
    echo "ERROR: Failed to build binaries"
    exit 1
fi

#############################  Install binaries  ###############################
echo "Installing binaries to $BIN_DIR"
install -m 755 "$SOURCE_DIR/$FAN_BIN"  "$BIN_DIR/$FAN_BIN"
install -m 755 "$CONFIG_DIR/$CFG_BIN"  "$BIN_DIR/$CFG_BIN"

#############################  Enable dwc2 overlay  ############################
# IMPORTANT: The dwc2 overlay MUST live in the GLOBAL section of config.txt
# (i.e. BEFORE the first [pi4]/[cm4]/[all]/... conditional header).
# Some firmware revisions silently skip overlays placed under conditional
# filters, leaving the DeskPi Pro's internal CH340 (fan MCU) unenumerated.
# Symptom: /dev/ttyUSB0 missing, `lsusb` shows no 1a86:7523, vclog shows
# only `vc4-kms-v3d` loaded but no `dwc2`.
DWC2_LINE='dtoverlay=dwc2,dr_mode=host'

# Skip only if dwc2 already exists in the global section (before any [header]).
if ! awk '
    BEGIN { in_header = 0 }
    /^\[/ { in_header = 1 }
    !in_header && /^dtoverlay=dwc2/ { found = 1 }
    END { exit !found }
' "$CONFIG_TXT"; then
    echo "Enabling dwc2 host overlay in GLOBAL section of $CONFIG_TXT"
    cp "$CONFIG_TXT" "$CONFIG_TXT_BKP"

    # Remove any existing dwc2 line(s) anywhere in the file (de-dup + clean).
    sed -i '/^dtoverlay=dwc2/d' "$CONFIG_TXT"

    # Insert the line BEFORE the first [header]. If no header exists, prepend.
    if grep -q '^\[' "$CONFIG_TXT"; then
        awk -v line="$DWC2_LINE" '
            BEGIN { inserted = 0 }
            !inserted && /^\[/ { print line; inserted = 1 }
            { print }
        ' "$CONFIG_TXT" > "$CONFIG_TXT.tmp" && mv "$CONFIG_TXT.tmp" "$CONFIG_TXT"
    else
        sed -i "1i\\$DWC2_LINE" "$CONFIG_TXT"
    fi
fi
#############################  Create systemd unit  ############################
if [ ! -f "$FAN_SERVICE" ]; then
    echo "Creating $FAN_SERVICE"
    cat > "$FAN_SERVICE" <<EOF
[Unit]
Description=DeskPi Fan Control Service
After=multi-user.target

[Service]
Type=simple
RemainAfterExit=true
ExecStart=$BIN_DIR/$FAN_BIN
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
fi

#############################  Reload & start  #################################
systemctl daemon-reload
systemctl enable --now deskpi.service || log_warn "Failed to start deskpi.service"

#############################  Final message  ##################################
echo "DeskPi Pro driver installed successfully!"
if [ "$AUTO_REBOOT" -eq 1 ]; then
    echo "System will reboot in 5 seconds..."
    sync && sleep 5 && reboot
else
    echo "Please reboot manually to apply dwc2 overlay:  sudo reboot"
fi
