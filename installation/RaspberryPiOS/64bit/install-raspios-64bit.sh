#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro fan-driver installer for RaspiOS-ARM-64-lite (Buster+)
# https://github.com/DeskPi-Team/deskpi
#==============================================================================
set -euo pipefail

#############################  User-adjustable vars  ###########################
REPO_URL="https://github.com/DeskPi-Team/deskpi"
TMP_DIR="/tmp/deskpi"
BIN_DIR="/usr/bin"
SYSTEMD_DIR="/etc/systemd/system"
FAN_BIN="pwmFanControl64V2"
CFG_BIN="deskpi-config"
FAN_SERVICE="$SYSTEMD_DIR/deskpi.service"
CONFIG_TXT="/boot/firmware/config.txt"
CONFIG_TXT_BKP="${CONFIG_TXT}.$(date +%F-%H-%M-%S).bak"
AUTO_REBOOT=0

################################  Helper fns  ##################################

log_action_msg()  { echo "[INFO]  $*"; }
log_action_warn() { echo "[WARN]  $*"; }
log_action_err()  { echo "[ERROR] $*" >&2; }

log_info() { log_action_msg "$*"; }
log_warn() { log_action_warn "$*"; }
log_die()  { log_action_err "$*"; exit 1; }

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
        *) log_die "Unknown argument: $arg" ;;
    esac
done

#############################  Pre-flight checks  ##############################
[ "$(id -u)" -eq 0 ] || log_die "Run this script as root (sudo)"

if ! command -v git >/dev/null; then
    log_info "git not found, installing..."
    apt-get update -qq >/dev/null
    apt-get install -y git-core >/dev/null || log_die "Failed to install git"
fi

#############################  Stop & clean old units  #########################
systemctl stop    deskpi.service 2>/dev/null || true
systemctl disable deskpi.service 2>/dev/null || true
rm -f "$FAN_SERVICE"

#############################  Clone repo  #####################################
[ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
git clone --depth 1 "$REPO_URL" "$TMP_DIR" || log_die "Clone failed"

#############################  Install binaries  ###############################
log_info "Installing binaries to $BIN_DIR"
install -m 755 "$TMP_DIR/installation/drivers/c/$FAN_BIN" "$BIN_DIR/$FAN_BIN"
install -m 755 "$TMP_DIR/installation/$CFG_BIN"           "$BIN_DIR/$CFG_BIN"

#############################  Enable dwc2 overlay  ############################
#if ! grep -q "^dtoverlay=dwc2,dr_mode=host" "$CONFIG_TXT"; then
#    log_warn "Enabling dwc2 host overlay"
#   cp "$CONFIG_TXT" "$CONFIG_TXT_BKP"
#   sed -i '/^dtoverlay=dwc2.*/d' "$CONFIG_TXT"
#   echo "dtoverlay=dwc2,dr_mode=host" >> "$CONFIG_TXT"
#fi
#############################  Enable DWC2 overlay  ############################
# Skips adding the dwc2 line ONLY if:
#   - it appears before the first header (global), OR
#   - it appears in the [all] header.
if ! awk '
    /^\[/ {
        in_section=1
        if ($0 == "[all]") in_all=1
        else in_all=0
    }
    (!in_section && /^dtoverlay=dwc2,dr_mode=host/) { found=1 }
    (in_all && /^dtoverlay=dwc2,dr_mode=host/) { found=1 }
    END { exit !found }
' "$CONFIG_TXT"
then
    log_warn "Enabling dwc2 host overlay"
    cp "$CONFIG_TXT" "$CONFIG_TXT_BKP"

    # remove any misplaced or duplicate dwc2 lines
    sed -i '/^dtoverlay=dwc2.*/d' "$CONFIG_TXT"

    # insert under [all] if the header exists
    if grep -q "^\[all\]" "$CONFIG_TXT"; then
        sed -i '/^\[all\]/a dtoverlay=dwc2,dr_mode=host' "$CONFIG_TXT"
    else
        # if no [all], append it at the end
        echo "dtoverlay=dwc2,dr_mode=host" >> "$CONFIG_TXT"
    fi
fi
#############################  Create systemd unit  ############################
if [ ! -f "$FAN_SERVICE" ]; then
    log_info "Creating $FAN_SERVICE"
    cat > "$FAN_SERVICE" <<'EOF'
[Unit]
Description=DeskPi Fan Control Service
After=multi-user.target

[Service]
Type=simple
RemainAfterExit=true
ExecStart=/usr/bin/pwmFanControl64V2
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
fi

#############################  Reload & start  #################################
systemctl daemon-reload
systemctl enable --now deskpi.service || log_warn "Failed to start deskpi.service"

#############################  Final message  ##################################
log_info "DeskPi Pro driver installed successfully!"
if [ "$AUTO_REBOOT" -eq 1 ]; then
    log_warn "System will reboot in 5 seconds..."
    sync && sleep 5 && reboot
else
    log_info "Please reboot manually to apply dwc2 overlay:  sudo reboot"
fi
