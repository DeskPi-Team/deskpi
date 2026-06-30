# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- **5 V cut-off signalling was unreliable — the MCU did not always
  receive `power_off`.** Two related bugs:
  1. `safeCutOffPower.c` set the wrong line discipline. The
     `&= ~FLAG; |= FLAG;` no-op pairs left `PARENB`, `CSTOPB` and
     `CRTSCTS` *set*, configuring the UART as 8E2 with hardware
     flow control. The CH340 is 8N1 and does not assert CTS, so
     `write()` could block on CTS forever. Replaced with a clean
     `tcgetattr` / `tcsetattr` block: 9600 8N1, no hw flow,
     raw mode, no OPOST.
  2. Only **one** `write()` of the 9-byte token was issued. If it
     raced the fan daemon's pwm_* token, both bytes could be lost.
     The binary now writes `power_off` **5 times** with `tcdrain()`
     and `tcflush(TCIOFLUSH)` between each, ensuring every copy
     actually leaves the UART shift register.

  Redundancy now also spans the host:
  - **PRIMARY** (`pwmFanControl_v2.c::check_poweroff`): the moment
    the daemon reads `poweroff` / `power_off` from the MCU, it
    writes the cut-off token to the MCU *before* calling
    `systemctl poweroff`. The MCU sees the signal seconds before
    the kernel begins tearing down drivers, so the 15 s internal
    delay comfortably precedes any halts.
  - **BACKUP** (`safeCutOffPower64` via `deskpi-cut-off-power.service`):
    re-fires the same token at `poweroff.target` for shutdowns
    that did not originate from the front-panel power button
    (SSH, apt, kernel panic). The 18 s `sleep` in
    `deskpi-shutdown-helper` keeps the poweroff.target chain
    pinned until the MCU reacts.

  Fix verified on a Raspberry Pi 4B running Debian 13: a double-click
  of the front power button now cuts the 5 V rail within ~15 s
  and the SoC powers off (previously the OS would halt while 5 V
  stayed hot).

### Changed
- **All distros now use the V2 fan daemon (`pwmFanControl64V2`).**
  The Ubuntu / DietPi / Kali / Manjaro / Fedora installers previously
  installed the legacy `pwmFanControl64` (V1, no curve support, no
  poweroff detection); they now install V2 just like the Raspberry Pi OS
  installer. The V1 source (`drivers/c/pwmFanControl.c`) and the
  corresponding `pwmFanControl64` build/install target have been
  removed. Uninstaller scripts still scrub `pwmFanControl64` from
  `/usr/bin/` for legacy hosts.

### Fixed
- **`pwmFanControl_v2.c` built-in default curve.**
  The default array was `{40,75, 50,75, 65,100, 75,100}` which sent
  the fan to 75 % from 40 °C upward — loud and contrary to the FAQ
  statement "the fan stops automatically". Changed to
  `{40,25, 50,50, 65,75, 75,100}`, matching the defaults shown in
  `deskpi-config`.
- **`deskpi-config` manual levels (1-5) now stop the daemon.**
  Previously the running daemon overwrote the manual PWM token within
  ~1 s, contradicting the FAQ ("To pin the fan at a specific speed,
  run `sudo deskpi-config` and pick one of the static levels").
  Options 1-5 now stop `deskpi.service` so the override sticks;
  option 7 restarts it.
- **`deskpi-config` cosmetic / code-quality cleanup.**
  Unified the two copies (`installation/deskpi-config` and
  `installation/drivers/deskpi-config`, which had drifted), removed
  redundant `sudo rm` and `daemon-reload`, added `[ -t 0 ]` guard for
  the "Press <Enter>" prompt, and added an exit warning if the
  daemon is left stopped.

## [2026-06-22]

### Fixed
- **The 5 V rail was not being cut after shutdown.**
  On Raspberry Pi OS 64-bit the `install-raspios-64bit.sh` script never
  installed `deskpi-cut-off-power.service`, so even though
  `pwmFanControl64V2` correctly detected the `poweroff` token from the
  MCU and called `systemctl poweroff`, no service ever echoed `power_off`
  back to the MCU, leaving the DeskPi Pro's 5 V rail hot after every
  shutdown. The other distros (Ubuntu, DietPi, Kali) did install the
  service but their `safeCutOffPower.c` was a `while(1)` busy loop that
  would block the `Type=oneshot` unit for the full systemd start
  timeout.

### Changed
- **All `install-*.sh` scripts (Raspberry Pi OS, Ubuntu, DietPi, Kali,
  Manjaro, Fedora) now share the same canonical layout**: `--auto-reboot`
  CLI flag, idempotent unit creation, consistent `Before=`,
  `Conflicts=`, `WantedBy=`, and `DefaultDependencies=` directives for
  `deskpi-cut-off-power.service`. The RaspiOS installer is the
  reference; the others are brought in line.
- **`safeCutOffPower.c` rewritten as a one-shot binary.**
  Removed the `while(1)` loop; the program now opens `/dev/ttyUSB0`,
  writes the 9-byte literal `power_off` (no NUL terminator), closes the
  fd and returns 0. The systemd `Type=oneshot` unit completes in
  ~60 ms instead of being killed by `TimeoutStartSec` (default 90 s).
- **All `uninstall-*.sh` scripts hardened.**
  Clean up the new `deskpi-cut-off-power.service` unit and the new
  `safeCutOffPower64` / `pwmFanControl64V2` binaries, plus legacy aliases
  (`deskpi-safeshut.service`, `deskpi-cutoffpower.service`, etc.) so
  reinstalls on a previously-installed host do not leave stale state.
- **The legacy top-level `uninstall.sh` no longer depends on `figlet`** and
  no longer references the typo'd `deskpi-cutoffpower.service` (missing
  dash) — it was a no-op against the actual unit name.
- **`deskpi-config` (interactive fan configurator) rewritten.**
  - Replaces the `figlet` banner with a portable ASCII one.
  - Uses `printf` (not `echo`) to write the PWM token so no stray
    newline is appended to the serial payload.
  - Color output (auto-disabled when stdout is not a TTY).
  - Input validation for both temperature (0-110 °C) and PWM (0-100).
  - Idempotent re-entry: the menu loops instead of recursively
    re-sourcing the script.
  - Catches a missing `/dev/ttyUSB0` with an actionable error message
    instead of a silent `echo > /dev/ttyUSB0` failure.
  - Both copies (`installation/deskpi-config` and
    `installation/drivers/deskpi-config`) are now identical and pass
    `bash -n`.

### Removed
- The Fedora-specific `pwmControlFan` / `fanStop` / `deskpi-safeshut`
  references are gone; the new Fedora installer uses the canonical
  `pwmFanControl64` + `safeCutOffPower64` pair. (The
  `installation/Fedora/README.md` deprecation notice is preserved.)

### Verified
On a Raspberry Pi 4 running Raspberry Pi OS Bookworm 64-bit with the
new installer applied, double-pressing the DeskPi Pro power button now:
1. The MCU emits `poweroff` (8 bytes) over `/dev/ttyUSB0`.
2. `pwmFanControl64V2` reads it and calls `systemctl poweroff`.
3. systemd begins the power-off sequence; because
   `deskpi-cut-off-power.service` is `WantedBy=poweroff.target` and
   `Before=halt.target shutdown.target poweroff.target`, the service
   starts, writes `power_off` to the MCU, and exits in ~60 ms
   (`active (exited)`).
4. The OS continues to halt. About 15 seconds later the MCU cuts the
   5 V rail.

Smoke test (service in isolation):
```
$ sudo strace -e openat,write /usr/bin/safeCutOffPower64
openat(AT_FDCWD, "/dev/ttyUSB0", O_RDWR|O_NOCTTY) = 3
write(3, "power_off", 9)                = 9
+++ exited with 0 +++
```

## [2023-12-31] — Fedora support deprecated
- `installation/Fedora/README.md` marks Fedora as deprecated. The
  installer is retained in the tree and is now in sync with the
  canonical layout, but is not actively tested.

## [2020-08-20] — Initial public release
- Pre-installed Raspberry Pi OS image (Buster) bundled with a working
  fan-control driver; the v1 daemon (`pwmFanControl.c`) was used.
