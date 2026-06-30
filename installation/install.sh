#!/usr/bin/env bash
#==============================================================================
# DeskPi Pro — unified installer
# https://github.com/DeskPi-Team/deskpi
#
# Auto-detects the running OS and dispatches to the matching
# installation/<Distro>/install-*.sh. Shows what it is about to do and
# asks for confirmation before touching the system.
#
# Usage:
#   sudo ./install.sh [options]
#
# Options:
#   --auto-reboot   Reboot automatically after a successful install
#   --yes, -y       Skip the "Are you sure?" prompt
#   --os=<distro>   Skip detection and force a specific installer
#                   (one of: raspi | ubuntu | debian | dietpi |
#                            kali | manjaro | fedora)
#   --dry-run       Show what would be done, but do nothing
#   --verbose, -v   Forward --verbose to the per-distro installer
#   -h, --help      Show this help
#==============================================================================
set -euo pipefail

# ---- locate the script ----------------------------------------------------
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
${C_BOLD}DeskPi Pro unified installer${C_RESET}

${C_BOLD}Usage:${C_RESET} sudo $0 [options]

${C_BOLD}Options:${C_RESET}
  --auto-reboot       Reboot automatically after a successful install
  --yes, -y           Skip the "Are you sure?" confirmation prompt
  --os=<distro>       Skip detection and force a specific installer.
                      Supported values:
                        raspi     Raspberry Pi OS (any 64-bit release)
                        debian    Plain Debian 64-bit (uses RaspiOS installer)
                        ubuntu    Ubuntu 64-bit
                        dietpi    DietPi 64-bit
                        kali      Kali Linux ARM-64
                        manjaro   Manjaro ARM-64
                        fedora    Fedora aarch64
  --dry-run           Print what would be done, but do nothing
  --verbose, -v       Forward --verbose to the per-distro installer
  -h, --help          Show this help

${C_BOLD}What it does:${C_RESET}
  1. Inspects /etc/os-release and the running kernel.
  2. Detects whether you are on a Raspberry Pi (via /proc/device-tree/model).
  3. Selects the matching per-distro installer under installation/<Distro>/.
  4. Prints a summary and asks for confirmation.
  5. Forwards --auto-reboot (and any other flags) to that installer.

${C_BOLD}After the install:${C_RESET}
  - The fan daemon (deskpi.service) and the 5 V cut-off helper
    (deskpi-cut-off-power.service) are enabled.
  - You can run  ${C_BOLD}sudo deskpi-config${C_RESET}  to set fan curves interactively.
  - See installation/README.md for the full layout, and CHANGELOG.md
    for the 2026-06-22 5 V cutoff fix.
EOF
}

# ---- CLI ------------------------------------------------------------------
AUTO_REBOOT=0
YES=0
DRY_RUN=0
VERBOSE=0
OS_OVERRIDE=""

for arg; do
    case "$arg" in
        --auto-reboot) AUTO_REBOOT=1 ;;
        -y|--yes)      YES=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        -v|--verbose)  VERBOSE=1 ;;
        --os=*)        OS_OVERRIDE="${arg#*=}" ;;
        -h|--help)     usage; exit 0 ;;
        *) err "Unknown argument: $arg"; usage; exit 1 ;;
    esac
done

# ---- preflight ------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "Please run with sudo (this installer needs root to enable systemd units and write to /boot)."

# /etc/os-release is the standard since systemd 40+. Every supported distro
# ships it. We load it as a shell variable source.
[ -f /etc/os-release ] || die "/etc/os-release is missing — this installer only supports systemd-based systems."
# shellcheck source=/dev/null
. /etc/os-release

# ---- per-distro installer map ---------------------------------------------
# Maps an internal tag to the relative path of the per-distro installer and
# the human-readable name used in the summary.
DISTRO_TABLE=(
    "raspi|Raspberry Pi OS|RaspberryPiOS/64bit/install-raspios-64bit.sh"
    "debian|Debian 64-bit (Raspberry Pi)|RaspberryPiOS/64bit/install-raspios-64bit.sh"
    "ubuntu|Ubuntu 64-bit|Ubuntu/install-ubuntu-64.sh"
    "dietpi|DietPi 64-bit|DietPi/install-dietPi-64bit.sh"
    "kali|Kali Linux ARM-64|Kali/install-kali.sh"
    "manjaro|Manjaro ARM-64|Manjaro/install-manjaro.sh"
    "fedora|Fedora aarch64|Fedora/install-fedora.sh"
)

# ---- detection ------------------------------------------------------------
detect_distro() {
    local detected=""

    # 1. Honour --os= override
    if [ -n "$OS_OVERRIDE" ]; then
        local row tag name path
        for row in "${DISTRO_TABLE[@]}"; do
            IFS='|' read -r tag name path <<< "$row"
            if [ "$tag" = "$OS_OVERRIDE" ]; then
                DISTRO_TAG="$tag"
                DISTRO_NAME="$name"
                DISTRO_INSTALLER="$INSTALL_ROOT/$path"
                return 0
            fi
        done
        die "--os=$OS_OVERRIDE is not one of: raspi debian ubuntu dietpi kali manjaro fedora"
    fi

    # 2. /etc/os-release driven detection
    case "${ID:-unknown}" in
        raspbian)
            detected="raspi" ;;
        debian)
            # DietPi is Debian underneath, but has its own marker file.
            if [ -f /boot/dietpi.txt ] || [ -f /etc/dietpi ]; then
                detected="dietpi"
            elif [ -f /proc/device-tree/model ] && grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; then
                # Plain Debian on a Raspberry Pi uses the RaspiOS installer.
                detected="raspi"
            else
                detected="debian"
            fi
            ;;
        ubuntu)
            detected="ubuntu" ;;
        kali)
            detected="kali" ;;
        manjaro|arch|archarm)
            detected="manjaro" ;;
        fedora)
            detected="fedora" ;;
        *)
            # Fall back to ID_LIKE for derivative distros.
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
            DISTRO_INSTALLER="$INSTALL_ROOT/$path"
            return 0
        fi
    done
    return 1
}

DISTRO_TAG=""
DISTRO_NAME=""
DISTRO_INSTALLER=""

if ! detect_distro; then
    err "Could not identify a supported distribution."
    err "/etc/os-release reports: ID=${ID:-?}  PRETTY_NAME=${PRETTY_NAME:-?}"
    err "Supported: Raspberry Pi OS, Ubuntu, DietPi, Kali, Manjaro, Fedora, plain Debian on a Pi."
    err "Override with:  sudo $0 --os=<raspi|ubuntu|dietpi|kali|manjaro|fedora|debian>"
    exit 1
fi

# ---- environment snapshot -------------------------------------------------
ARCH="$(uname -m)"
KERNEL="$(uname -r)"

IS_PI="no"
[ -f /proc/device-tree/model ] && grep -qi "raspberry" /proc/device-tree/model 2>/dev/null && IS_PI="yes"

HAS_GCC="no"
command -v gcc >/dev/null && HAS_GCC="yes"
HAS_GIT="no"
command -v git  >/dev/null && HAS_GIT="yes"
HAS_MAKE="no"
command -v make >/dev/null && HAS_MAKE="yes"

HAS_TTYUSB0="no"
[ -e /dev/ttyUSB0 ] && HAS_TTYUSB0="yes"
HAS_DWC2_OVERLAY="no"
for f in /boot/firmware/config.txt /boot/config.txt; do
    if [ -f "$f" ] && awk '
        BEGIN { in_header = 0 }
        /^\[/ { in_header = 1 }
        !in_header && /^dtoverlay=dwc2/ { found = 1 }
        END { exit !found }
    ' "$f" 2>/dev/null; then
        HAS_DWC2_OVERLAY="yes"
        DWC2_CONFIG_TXT="$f"
        break
    fi
done

# ---- per-distro compatibility matrix --------------------------------------
# Determines whether we expect this combination to actually work.
COMPAT="expected"
case "$DISTRO_TAG" in
    raspi|debian|dietpi)
        # 64-bit Raspberry Pi OS / Debian / DietPi are the reference targets.
        if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
            COMPAT="unsupported (needs aarch64; this is $ARCH)"
        fi
        [ "$IS_PI" = "no" ] && COMPAT="untested (no /proc/device-tree/model Raspberry marker)"
        ;;
    ubuntu|kali)
        if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
            COMPAT="unsupported (needs aarch64; this is $ARCH)"
        fi
        [ "$IS_PI" = "no" ] && COMPAT="untested (no /proc/device-tree/model Raspberry marker)"
        ;;
    manjaro)
        if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
            COMPAT="unsupported (needs aarch64; this is $ARCH)"
        fi
        ;;
    fedora)
        if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
            COMPAT="unsupported (needs aarch64; this is $ARCH)"
        fi
        # Fedora on Pi is best-effort; flagged as deprecated in installation/Fedora/README.md
        COMPAT="$COMPAT — Fedora is on the deprecated list, expect rough edges"
        ;;
esac

# ---- summary --------------------------------------------------------------
say "DeskPi Pro installer"
printf '\n'
printf '%sSystem snapshot%s\n' "$C_BOLD" "$C_RESET"
printf '  Distro          : %s%s%s (ID=%s, VERSION=%s)\n' \
    "$C_CYAN" "$DISTRO_NAME" "$C_RESET" "${ID:-?}" "${VERSION_ID:-?}"
printf '  Architecture    : %s\n' "$ARCH"
printf '  Kernel          : %s\n' "$KERNEL"
printf '  Raspberry Pi    : %s\n' "$IS_PI"
printf '  /dev/ttyUSB0    : %s\n' "$HAS_TTYUSB0"
printf '  dwc2 overlay    : %s%s%s\n' \
    "$([ "$HAS_DWC2_OVERLAY" = "yes" ] && echo "$C_GREEN" || echo "$C_YELLOW")" \
    "$HAS_DWC2_OVERLAY" \
    "$([ -n "${DWC2_CONFIG_TXT:-}" ] && echo " (in $DWC2_CONFIG_TXT)")"
printf '  Build tools     : gcc=%s git=%s make=%s\n' "$HAS_GCC" "$HAS_GIT" "$HAS_MAKE"
printf '\n'
printf '%sWhat will be installed%s\n' "$C_BOLD" "$C_RESET"
printf '  Binaries in /usr/bin/ :  pwmFanControl64V2  safeCutOffPower64  deskpi-config\n'
printf '  systemd units         :  deskpi.service  deskpi-cut-off-power.service\n'
printf '  boot config           :  dtoverlay=dwc2,dr_mode=host (added to %s)\n' \
    "$([ "$HAS_DWC2_OVERLAY" = "yes" ] && echo "${DWC2_CONFIG_TXT:-/boot/firmware/config.txt}" || echo "/boot/firmware/config.txt or /boot/config.txt, whichever exists")"
printf '\n'
printf '%sCompatibility:%s %s\n' "$C_BOLD" "$C_RESET" "$COMPAT"

# ---- per-distro warnings --------------------------------------------------
case "$DISTRO_TAG" in
    fedora)
        warn "Fedora on Raspberry Pi 4 is no longer actively tested by upstream."
        warn "  The installer is kept in sync with the canonical layout, but"
        warn "  expect to do manual debugging. See installation/Fedora/README.md."
        ;;
esac

if [ "$HAS_TTYUSB0" = "no" ]; then
    warn "/dev/ttyUSB0 is not present. The driver will be installed but the"
    warn "  daemon will not see the MCU until you reboot with the dwc2 overlay"
    warn "  enabled (this installer will enable it if it is missing)."
fi

# ---- confirm --------------------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
    say "Dry run — nothing will be changed."
    printf '  Would run: %s\n' "$DISTRO_INSTALLER"
    if [ "$AUTO_REBOOT" = "1" ]; then printf '  --auto-reboot forwarded\n'; fi
    if [ "$VERBOSE" = "1" ]; then printf '  --verbose forwarded\n'; fi
    exit 0
fi

if [ "$YES" != "1" ]; then
    printf '\n'
    printf '%sProceed with the install?%s\n' "$C_BOLD" "$C_RESET"
    printf '  Type %syes%s to install, or %sno%s to cancel.\n' \
        "$C_GREEN" "$C_RESET" "$C_RED" "$C_RESET"
    read -r -p "  install? " answer
    case "${answer,,}" in
        yes|y) ;;
        *) say "Cancelled by user."; exit 0 ;;
    esac
fi

# ---- dispatch -------------------------------------------------------------
[ -x "$DISTRO_INSTALLER" ] || chmod +x "$DISTRO_INSTALLER"
say "Dispatching to: $DISTRO_INSTALLER"
exec "$DISTRO_INSTALLER" \
    $([ "$AUTO_REBOOT" = "1" ] && echo "--auto-reboot") \
    $([ "$VERBOSE"    = "1" ] && echo "--verbose")
