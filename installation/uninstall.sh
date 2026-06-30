#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro — unified uninstaller
# https://github.com/DeskPi-Team/deskpi
#
# Auto-detects the OS that was used to install the driver and dispatches to
# the matching installation/<Distro>/uninstall-*.sh. If the matching
# per-distro uninstaller is missing (or the OS is unrecognised), it falls
# back to a manual cleanup that removes the canonical units and binaries
# regardless of which installer originally deployed them.
#
# Usage:
#   sudo ./uninstall.sh [options]
#
# Options:
#   --yes, -y       Skip the "Are you sure?" prompt
#   --os=<distro>   Skip detection and force a specific uninstaller
#                   (one of: raspi | ubuntu | debian | dietpi |
#                            kali | manjaro | fedora)
#   --dry-run       Show what would be done, but do nothing
#   -h, --help      Show this help
#==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
INSTALL_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

# ---- pretty-print helpers -------------------------------------------------
if [ -t 1 ] && command -v tput >/dev/null && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_CYAN=$'\e[36m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

say()  { printf '%s==>%s %s\n' "$C_BOLD$C_CYAN" "$C_RESET" "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_GREEN"        "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_YELLOW"       "$C_RESET" "$*" >&2; }
err()  { printf '%s[FAIL]%s %s\n' "$C_RED"          "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ---- usage ----------------------------------------------------------------
usage() {
    cat <<EOF
${C_BOLD}DeskPi Pro unified uninstaller${C_RESET}

${C_BOLD}Usage:${C_RESET} sudo $0 [options]

${C_BOLD}Options:${C_RESET}
  --yes, -y         Skip the "Are you sure?" confirmation prompt
  --os=<distro>     Skip detection and force a specific uninstaller.
                    Supported values:
                      raspi     uninstall Raspberry Pi OS install
                      debian    uninstall plain Debian install
                      ubuntu    uninstall Ubuntu install
                      dietpi    uninstall DietPi install
                      kali      uninstall Kali install
                      manjaro   uninstall Manjaro install
                      fedora    uninstall Fedora install
  --dry-run         Print what would be done, but do nothing
  -h, --help        Show this help

${C_BOLD}What it removes:${C_RESET}
  - systemd units:     deskpi.service, deskpi-cut-off-power.service
                       (and legacy aliases like deskpi-safeshut.service,
                        deskpiFanControl.service, deskpiFanStop.service)
  - binaries in /usr/bin/:
                       pwmFanControl64, pwmFanControl64V2,
                       safeCutOffPower64, deskpi-config,
                       Deskpi-uninstall, and the legacy pwmFanControl /
                       pwmControlFan / fanStop / deskpiFanControl /
                       deskpiFanStop names from older installers.
  - configuration:     /etc/deskpi.conf
  - boot config:       dtoverlay=dwc2,dr_mode=host line is removed from
                       /boot/firmware/config.txt or /boot/config.txt
  - temp clones:       /tmp/deskpi
  - udev rules:        /etc/udev/rules.d/10-deskpi.rules
EOF
}

# ---- CLI ------------------------------------------------------------------
YES=0
DRY_RUN=0
OS_OVERRIDE=""

for arg; do
    case "$arg" in
        -y|--yes)      YES=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        --os=*)        OS_OVERRIDE="${arg#*=}" ;;
        -h|--help)     usage; exit 0 ;;
        *) err "Unknown argument: $arg"; usage; exit 1 ;;
    esac
done

# ---- preflight ------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "Please run with sudo."

[ -f /etc/os-release ] || die "/etc/os-release is missing — this uninstaller only supports systemd-based systems."
# shellcheck source=/dev/null
. /etc/os-release

# ---- per-distro uninstaller map -------------------------------------------
DISTRO_TABLE=(
    "raspi|Raspberry Pi OS|RaspberryPiOS/64bit/uninstall-raspios-64bit.sh"
    "debian|Debian 64-bit (Raspberry Pi)|RaspberryPiOS/64bit/uninstall-raspios-64bit.sh"
    "ubuntu|Ubuntu 64-bit|Ubuntu/uninstall-ubuntu-mate.sh"
    "dietpi|DietPi 64-bit|DietPi/uninstall-dietPi-64bit.sh"
    "kali|Kali Linux ARM-64|Kali/uninstall-kali.sh"
    "manjaro|Manjaro ARM-64|Manjaro/uninstall-manjaro.sh"
    "fedora|Fedora aarch64|Fedora/uninstall-fedora.sh"
)

# ---- detection ------------------------------------------------------------
detect_distro() {
    local detected=""
    if [ -n "$OS_OVERRIDE" ]; then
        local row tag name path
        for row in "${DISTRO_TABLE[@]}"; do
            IFS='|' read -r tag name path <<< "$row"
            if [ "$tag" = "$OS_OVERRIDE" ]; then
                DISTRO_TAG="$tag"
                DISTRO_NAME="$name"
                DISTRO_UNINSTALLER="$INSTALL_ROOT/$path"
                return 0
            fi
        done
        die "--os=$OS_OVERRIDE is not one of: raspi debian ubuntu dietpi kali manjaro fedora"
    fi

    case "${ID:-unknown}" in
        raspbian)            detected="raspi" ;;
        debian)
            if [ -f /boot/dietpi.txt ] || [ -f /etc/dietpi ]; then
                detected="dietpi"
            elif [ -f /proc/device-tree/model ] && grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; then
                detected="raspi"
            else
                detected="debian"
            fi
            ;;
        ubuntu)              detected="ubuntu" ;;
        kali)                detected="kali" ;;
        manjaro|arch|archarm) detected="manjaro" ;;
        fedora)              detected="fedora" ;;
        *)
            case " ${ID_LIKE:-} " in
                *" debian "*)
                    if [ -f /proc/device-tree/model ] && grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; then
                        detected="raspi"
                    else
                        detected="debian"
                    fi
                    ;;
                *" arch "*)  detected="manjaro" ;;
                *" fedora "*) detected="fedora" ;;
                *) detected="" ;;
            esac
            ;;
    esac

    [ -n "$detected" ] || return 1
    local row tag name path
    for row in "${DISTRO_TABLE[@]}"; do
        IFS='|' read -r tag name path <<< "$row"
        if [ "$tag" = "$detected" ]; then
            DISTRO_TAG="$tag"
            DISTRO_NAME="$name"
            DISTRO_UNINSTALLER="$INSTALL_ROOT/$path"
            return 0
        fi
    done
    return 1
}

DISTRO_TAG=""
DISTRO_NAME=""
DISTRO_UNINSTALLER=""

if ! detect_distro; then
    warn "Could not identify the OS from /etc/os-release (ID=${ID:-?}). Falling back to a manual cleanup."
    DISTRO_TAG="unknown"
    DISTRO_NAME="Unknown (manual cleanup)"
    DISTRO_UNINSTALLER=""
fi

# ---- what is currently installed ------------------------------------------
HAS_FAN_UNIT="no"
HAS_CUTOFF_UNIT="no"
HAS_FAN_BIN="no"
HAS_CUTOFF_BIN="no"
[ -f /etc/systemd/system/deskpi.service ]               && HAS_FAN_UNIT="yes"
[ -f /etc/systemd/system/deskpi-cut-off-power.service ] && HAS_CUTOFF_UNIT="yes"
[ -x /usr/bin/pwmFanControl64V2 ] || [ -x /usr/bin/pwmFanControl64 ] && HAS_FAN_BIN="yes"
[ -x /usr/bin/safeCutOffPower64 ] && HAS_CUTOFF_BIN="yes"

# ---- summary --------------------------------------------------------------
say "DeskPi Pro uninstaller"
printf '\n'
printf '%sSystem snapshot%s\n' "$C_BOLD" "$C_RESET"
printf '  Distro          : %s%s%s (ID=%s, VERSION=%s)\n' \
    "$C_CYAN" "$DISTRO_NAME" "$C_RESET" "${ID:-?}" "${VERSION_ID:-?}"
printf '  Architecture    : %s\n' "$(uname -m)"
printf '\n'
printf '%sDetected DeskPi artifacts on this host%s\n' "$C_BOLD" "$C_RESET"
printf '  deskpi.service                : %s\n' "$([ "$HAS_FAN_UNIT"     = "yes" ] && echo "${C_GREEN}present${C_RESET}" || echo "${C_DIM}not present${C_RESET}")"
printf '  deskpi-cut-off-power.service  : %s\n' "$([ "$HAS_CUTOFF_UNIT" = "yes" ] && echo "${C_GREEN}present${C_RESET}" || echo "${C_DIM}not present${C_RESET}")"
printf '  pwmFanControl64* in /usr/bin  : %s\n' "$([ "$HAS_FAN_BIN"     = "yes" ] && echo "${C_GREEN}present${C_RESET}" || echo "${C_DIM}not present${C_RESET}")"
printf '  safeCutOffPower64 in /usr/bin : %s\n' "$([ "$HAS_CUTOFF_BIN" = "yes" ] && echo "${C_GREEN}present${C_RESET}" || echo "${C_DIM}not present${C_RESET}")"
printf '\n'

if [ -n "$DISTRO_UNINSTALLER" ]; then
    say "Will dispatch to: $DISTRO_UNINSTALLER"
else
    warn "No per-distro uninstaller available. Will perform a manual cleanup"
    warn "  that removes every known DeskPi artifact regardless of which"
    warn "  installer originally deployed it."
fi

# ---- confirm --------------------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
    say "Dry run — nothing will be changed."
    exit 0
fi

if [ "$YES" != "1" ]; then
    printf '\n'
    printf '%sProceed with the uninstall?%s\n' "$C_BOLD" "$C_RESET"
    printf '  This will stop and disable the DeskPi systemd units, remove\n'
    printf '  /usr/bin/{pwmFanControl64, pwmFanControl64V2, safeCutOffPower64,\n'
    printf '  deskpi-config, ...} and the dtoverlay line from your config.txt.\n'
    printf '  Type %syes%s to uninstall, or %sno%s to cancel.\n' \
        "$C_RED" "$C_RESET" "$C_GREEN" "$C_RESET"
    read -r -p "  uninstall? " answer
    case "${answer,,}" in
        yes|y) ;;
        *) say "Cancelled by user."; exit 0 ;;
    esac
fi

# ---- dispatch -------------------------------------------------------------
if [ -n "$DISTRO_UNINSTALLER" ] && [ -f "$DISTRO_UNINSTALLER" ]; then
    [ -x "$DISTRO_UNINSTALLER" ] || chmod +x "$DISTRO_UNINSTALLER"
    say "Dispatching to: $DISTRO_UNINSTALLER"
    exec "$DISTRO_UNINSTALLER"
fi

# ---- manual fallback cleanup ----------------------------------------------
say "Running manual cleanup"

# Canonical units
for svc in deskpi.service deskpi-cut-off-power.service; do
    systemctl stop    "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    rm -f "/etc/systemd/system/$svc"
done

# Legacy aliases
for svc in deskpi-safeshut.service deskpi-cutoffpower.service \
           deskpiFanControl.service deskpiFanStop.service; do
    for dir in /etc/systemd/system /lib/systemd/system; do
        [ -f "$dir/$svc" ] || continue
        systemctl stop    "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "$dir/$svc"
    done
done

# Binaries
for bin in pwmFanControl64 pwmFanControl64V2 safeCutOffPower64 \
           pwmFanControl pwmControlFan fanStop \
           deskpiFanControl deskpiFanStop \
           deskpi-config deskpi-shutdown-helper Deskpi-uninstall; do
    [ -f "/usr/bin/$bin" ] && rm -f "/usr/bin/$bin"
done

[ -f /etc/deskpi.conf ] && rm -f /etc/deskpi.conf
[ -f /etc/udev/rules.d/10-deskpi.rules ] && rm -f /etc/udev/rules.d/10-deskpi.rules

# dwc2 overlay
for f in /boot/firmware/config.txt /boot/efi/config.txt /boot/config.txt; do
    [ -f "$f" ] && sed -i '/^dtoverlay=dwc2/d' "$f"
done

# Temp clone
[ -d /tmp/deskpi ] && rm -rf /tmp/deskpi

systemctl daemon-reload
ok "Manual cleanup complete."
say "Please reboot manually if you also removed dwc2 overlay:  sudo reboot"
