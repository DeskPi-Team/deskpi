# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
