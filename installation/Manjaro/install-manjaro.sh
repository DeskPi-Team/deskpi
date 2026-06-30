#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro fan-driver installer for Manjaro ARM-64
# https://github.com/DeskPi-Team/deskpi
#==============================================================================
set -euo pipefail

#############################  User-adjustable vars  ###########################
BIN_DIR="/usr/bin"
SYSTEMD_DIR="/etc/systemd/system"
FAN_BIN="pwmFanControl64V2"
SAFE_CUTOFF_BIN="safeCutOffPower64"
CFG_BIN="deskpi-config"
FAN_SERVICE="$SYSTEMD_DIR/deskpi.service"
PWR_CUTOFF_SERVICE="$SYSTEMD_DIR/deskpi-cut-off-power.service"
CONFIG_TXT="/boot/config.txt"
[ -f /boot/firmware/config.txt ] && CONFIG_TXT="/boot/firmware/config.txt"
CONFIG_TXT_BKP="${CONFIG_TXT}.$(date +%F-%H-%M-%S).bak"
AUTO_REBOOT=0

################################  CLI parser  ##################################
for arg; do
    case "$arg" in
        --auto-reboot) AUTO_REBOOT=1 ;;
        -h|--help)
            cat <<EOF
Usage: sudo $0 [OPTIONS]
OPTIONS:
  --auto-reboot   Reboot automatically after installation
  -h, --help      Show this help
EOF
            exit 0
            ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

#############################  Pre-flight checks  ##############################
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root (sudo)" >&2
    exit 1
fi

if ! command -v gcc >/dev/null; then
    pacman -Sy --noconfirm gcc make
fi

if ! command -v git >/dev/null; then
    pacman -Sy --noconfirm git
fi

#############################  Stop & clean old units  #########################
systemctl stop    deskpi.service 2>/dev/null || true
systemctl disable deskpi.service 2>/dev/null || true
rm -f "$FAN_SERVICE"
systemctl stop    deskpi-cut-off-power.service 2>/dev/null || true
systemctl disable deskpi-cut-off-power.service 2>/dev/null || true
rm -f "$PWR_CUTOFF_SERVICE"

#############################  Source the upstream repository  ################
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SOURCE_DIR="$SCRIPT_DIR/../../drivers/c"
CONFIG_DIR="$SCRIPT_DIR/../.."

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Cloning upstream repository (local source not found)..."
    rm -rf /tmp/deskpi
    git clone https://github.com/DeskPi-Team/deskpi.git /tmp/deskpi || {
        echo "ERROR: Failed to clone repository. Check your internet connection." >&2
        exit 1
    }
    SOURCE_DIR="/tmp/deskpi/installation/drivers/c"
    CONFIG_DIR="/tmp/deskpi/installation"
fi

#############################  Build binaries  #################################
echo "Building binaries in $SOURCE_DIR"
cd "$SOURCE_DIR"
make clean
make

#############################  Install binaries  ###############################
echo "Installing binaries to $BIN_DIR"
install -m 755 "$SOURCE_DIR/$FAN_BIN"        "$BIN_DIR/$FAN_BIN"
install -m 755 "$SOURCE_DIR/$SAFE_CUTOFF_BIN"        "$BIN_DIR/$SAFE_CUTOFF_BIN"
install -m 755 "$CONFIG_DIR/deskpi-shutdown-helper"   "$BIN_DIR/deskpi-shutdown-helper"
install -m 755 "$CONFIG_DIR/$CFG_BIN"        "$BIN_DIR/$CFG_BIN"

#############################  Enable dwc2 overlay  ############################
# IMPORTANT: The dwc2 overlay MUST live in the GLOBAL section of config.txt
# (i.e. BEFORE the first [pi4]/[cm4]/[all]/... conditional header).
DWC2_LINE='dtoverlay=dwc2,dr_mode=host'
if ! awk '
    BEGIN { in_header = 0 }
    /^\[/ { in_header = 1 }
    !in_header && /^dtoverlay=dwc2/ { found = 1 }
    END { exit !found }
' "$CONFIG_TXT" 2>/dev/null; then
    echo "Enabling dwc2 host overlay in GLOBAL section of $CONFIG_TXT"
    cp "$CONFIG_TXT" "$CONFIG_TXT_BKP"
    sed -i '/^dtoverlay=dwc2/d' "$CONFIG_TXT"
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

#############################  Create systemd unit: fan  #######################
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

#############################  Create systemd unit: cut-off-power  ############
# Runs at poweroff.target, writes "power_off" to the MCU so it cuts the
# 5 V rail ~15 s later. Skipped on reboot via Conflicts=reboot.target.
if [ ! -f "$PWR_CUTOFF_SERVICE" ]; then
    echo "Creating $PWR_CUTOFF_SERVICE"
    cat > "$PWR_CUTOFF_SERVICE" <<'DESKPIPOWER_EOF'
[Unit]
Description=DeskPi-cut-off-power service
Conflicts=reboot.target
Before=halt.target shutdown.target poweroff.target
DefaultDependencies=no

[Service]
Type=oneshot
# Logging is done by the helper itself (systemd's $?/$rc parsing can't capture the binary's exit code).
ExecStart={BINDIR}/deskpi-shutdown-helper
# (Post hook removed: rc and PID are logged inside the helper, see above.)
RemainAfterExit=yes

[Install]
WantedBy=halt.target shutdown.target poweroff.target
DESKPIPOWER_EOF
    sed -i -e "s|{BINDIR}|$BIN_DIR|g" -e "s|{SAFECUTOFFBIN}|$SAFE_CUTOFF_BIN|g" "$PWR_CUTOFF_SERVICE"
fi

#############################  Reload & start  #################################
systemctl daemon-reload
systemctl enable --now deskpi.service               || echo "[WARN] Failed to start deskpi.service"
systemctl enable    deskpi-cut-off-power.service   || echo "[WARN] Failed to enable deskpi-cut-off-power.service"

#############################  Final message  ##################################
echo "DeskPi Pro driver installed successfully!"
if [ "$AUTO_REBOOT" -eq 1 ]; then
    echo "System will reboot in 5 seconds..."
    sync && sleep 5 && reboot
else
    echo "Please reboot manually to apply dwc2 overlay:  sudo reboot"
fi
