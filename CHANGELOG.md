# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Journal warnings when the CPU temperature becomes unreadable.** A
  dead thermal zone used to be silent forever (the fan just froze at
  its last level); the daemon now logs the failure once
  (`cannot read CPU temperature … keeping the current fan level`),
  retries every cycle and logs the recovery with the temperature
  value. The same enter/leave-of-failure-state rate limiting applies
  to serial write failures (previously a dead port spammed
  `write serial: …` once per second).

- **Optional `log_fan_changes = 1` key in `/etc/deskpi.conf`.** When
  set, `pwmFanControl64V3` journals a line on every fan level change
  with the CPU temperature that triggered it
  (`fan 25 % -> 50 % at 62 degC`; the startup assertion is logged as
  `fan level 50 % asserted at 62 degC (startup)`). Boolean value,
  default `0` (silent); non-0/1 values are treated as `1` with a
  warning; duplicates follow the first-value-wins rule. `deskpi-config`
  preserves the setting when rewriting the curve; in the generated file
  the key is documented in the header and written commented-out
  (`# log_fan_changes = 1`) at the end — uncomment that one line to
  enable journaling.

- **End-to-end event logging of the shutdown chain.** Every step of the
  5 V cut-off flow is now visible in the logs: the daemon announces its
  fan curve at startup, logs a front-panel button press (`front-panel
  power button pressed — MCU sent a poweroff token`) and its exit;
  `safeCutOffPower64` reports the port open, the first delivered attempt
  (`attempt 1/5: token delivered`; further successes are silent, the
  final summary reports n/5) and a final verdict with the ~15 s
  rail-cut note or a "5 V rail stays hot" warning; the
  `deskpi-shutdown-helper` wrapper writes every event both to
  `/var/log/deskpi-shutdown.log` and to journald (`BEGIN` /
  `DELIVERED` / `FAILED` / `HOLD` / `END`). Reaching `END` in the log
  is a diagnostic that the rail was **not** cut — on success the SoC
  loses power mid-hold and the line is never written.

- **Validation and journald warnings for `/etc/deskpi.conf`.**
  `pwmFanControl_v3.c::load_conf` now reports every inconsistency on
  stderr (captured by journald under `deskpi.service`) instead of
  silently repairing it: garbage lines (with line number and content),
  unknown level keys (`fan_30`, `fan_100`, …), repeated keys (the first
  occurrence wins, repetitions are reported and skipped), values
  outside 1–110 °C, and a non-increasing temperature sequence — e.g.
  `fan_0 = 75` with `fan_75 = 30` (0 % up to 75 °C while 100 % already
  starts at 30 °C), each violating threshold is pushed just above the
  previous one with a warning. An unreadable file (EACCES, …) is
  reported once and the built-in defaults apply; only a missing file
  (ENOENT) stays silent, since having no custom curve is normal. A
  corrupt/binary file stops parsing after 16 malformed lines with a
  single "file looks corrupt" summary instead of flooding the journal
  (binary bytes are masked to '?' in the log). Nothing in the config
  is fatal: the daemon always ends up with a usable, monotonic curve.

- **Automatic rotation of `/var/log/deskpi-shutdown.log`.** All six
  installers now drop a logrotate policy into
  `/etc/logrotate.d/deskpi` (monthly, 3 compressed archives,
  `missingok`/`notifempty`); the uninstallers remove it again. The
  shutdown history file itself is deliberately kept on uninstall.

### Changed
- **Safer, self-documenting `/etc/deskpi.conf` written by
  `deskpi-config`.** The wizard (option 6) creates the file with mode
  `0644` (was `0666` — the old mode made the daemon's config
  world-writable). All documentation now lives in one grouped header
  block at the top of the file (curve format, monotonicity rule, the
  optional logging key), followed by a blank line and the four
  `fan_N = TEMPERATURE` lines; the file ends with a commented-out
  `# log_fan_changes = 1` the user can simply uncomment. An already
  enabled `log_fan_changes = 1` survives a rewrite (written
  uncommented in the same place). The two copies of the script
  (`installation/deskpi-config` and `installation/drivers/deskpi-config`)
  remain identical; both are shellcheck-clean.

- **Installers and uninstallers now show the exact change and ask
  before touching boot/fan configuration.**
  - **Install** (`config.txt`): the modified copy is built first
    (dry run), shown as a unified `diff -u` against the current file,
    and applied only after an `Apply these changes? [y/N]` prompt
    (default: no). On approval the previous file is backed up under a
    timestamped name (`config.txt.<YYYY-MM-DD-HH-MM-SS>.bak`); the
    rewrite via `cat >` preserves the file's permissions and ownership. The unified installer's `--yes` flag
    (exported as `DESKPI_ASSUME_YES=1`) auto-confirms these prompts
    for scripted / non-interactive runs.
  - **Uninstall** (`config.txt`): the lines to be removed are listed
    with line numbers before the same `[y/N]` prompt.
  - **Uninstall** (`/etc/deskpi.conf`): the file contents are shown
    and its removal requires a separate `Remove /etc/deskpi.conf?
    [y/N]` confirmation — an empty answer keeps the file.
  - The dwc2 overlay block inserted into the global section of
    `config.txt` is now marked with a `# DeskPi` comment and separated
    by a blank line, so it is easy to spot and re-run-safe: the
    de-dup step removes stray markers and old overlay lines before
    re-inserting.
- **Log audit of the fan daemon and cut-off helper.** Unified every
  message under the `pwmFanControl64V3:` / `safeCutOffPower64:` prefix
  (the daemon's serial errors used bare `perror("open serial")`-style
  prefixes); a failed `open()` of the serial port now carries the same
  dwc2-overlay hint as the cut-off helper. Redundancy removed: the
  button-press and daemon-exit lines no longer repeat the token-deferral
  explanation twice, and `safeCutOffPower64` logs only the first
  delivered attempt instead of five identical lines.

- **Fan daemon renamed to V3.** `pwmFanControl_v2.c` →
  `pwmFanControl_v3.c`, binary `pwmFanControl64V2` →
  `pwmFanControl64V3` (Makefile, all installers and docs updated;
  uninstallers scrub both binary names).

- **All distros now use the same fan daemon.** The Ubuntu / DietPi /
  Kali / Manjaro / Fedora installers previously installed the legacy
  `pwmFanControl64` (V1, no curve support, no poweroff detection); they
  now install the same V3 daemon just like the Raspberry Pi OS
  installer. The V1 source (`installation/drivers/c/pwmFanControl.c`) and the
  corresponding `pwmFanControl64` build/install target have been
  removed. Uninstaller scripts still scrub `pwmFanControl64` from
  `/usr/bin/` for legacy hosts.

- **Legacy `/etc/deskpi.conf` format is no longer parsed.** V3 reads
  only the `fan_N = TEMPERATURE` format; a leftover legacy file (8
  bare integers) matches no keys — each of its lines is reported as
  garbage in the journal and the daemon falls back to its built-in
  defaults. Rewrite the file in the new format or delete it.

- **`/etc/deskpi.conf` rewritten as a human-readable fan-level format.**
  The old layout (8 bare integers: temp/pwm pairs) is replaced by one
  `fan_N = TEMPERATURE` line per named fan level — 0 / 25 / 50 / 75 /
  100 % — where TEMPERATURE is the CPU temperature up to which the
  level applies. Blank lines and `#` comments are ignored; values must
  not decrease. The fan speeds are fixed to the five named levels; the
  four temperatures are the only configurable part.
  - `pwmFanControl_v3.c::load_conf` parses the new format.
  - `deskpi-config` option 6 now asks only for the four temperatures
    and writes the new annotated format; the two copies of the script
    remain identical. Each prompt names its config key
    (`fan_0 … fan_75`) and shows which level comes next, ending with
    "100 % (pwm_100) above <fan_75> degC" so the top level is never
    mistaken for a fifth configurable point.

- **Front-panel power button no longer acks the MCU with an immediate
  `power_off` token.** `pwmFanControl_v3.c::check_poweroff` used to
  write the cut-off token the moment it read `poweroff` from the MCU,
  which started the MCU's ~15 s rail-cut timer at button-press time
  and left the OS only ~14 s to shut down — a slow or heavily loaded
  system could get its 5 V cut mid-teardown. The daemon now only runs
  `sync && systemctl poweroff`; the token is sent exclusively by
  `deskpi-cut-off-power.service` at `poweroff.target`, after every
  regular service has stopped, so the 15 s window covers only the
  final unmount + halt. Trade-off: an OS that hangs before reaching
  `poweroff.target` no longer gets a guaranteed rail cut — same
  behaviour as non-button shutdowns; force-cut with a long button
  press or by unplugging. `send_power_off()` was removed from the
  daemon; token sending now lives only in `safeCutOffPower.c`.

### Fixed
- **Uninstallers now remove every artifact the installers deploy.**
  Several per-distro uninstallers left things behind: the
  `deskpi-shutdown-helper` binary survived on Ubuntu / DietPi / Kali /
  Manjaro / Fedora, the DietPi uninstaller never removed
  `/etc/deskpi.conf`, the Raspberry Pi OS uninstaller skipped
  `systemctl daemon-reload` after deleting the unit files (leaving
  stale units loaded until the next unrelated reload), and four
  uninstallers did not clean the `/tmp/deskpi` repository clone that
  the installers' curl fallback creates. All of these are now removed
  by every uninstaller; `/var/log/deskpi-shutdown.log` and its rotated
  archives remain deliberately (user's shutdown history).

- **`Deskpi-uninstall` no longer deletes `/etc/deskpi.conf` behind the
  user's back.** The legacy menu wrapper used to run an unconditional
  `rm -f /etc/deskpi.conf` after dispatching to the per-distro
  uninstaller, silently undoing the uninstaller's own (now
  interactive) decision and bypassing its confirmation prompt. The
  redundant deletes were removed — the per-distro uninstaller is the
  single place where the file is removed, and it asks first.

- **Shellcheck clean-up in `utils/log_functions.include`.** Added a
  `shell=sh` directive for the sourced-only helper and replaced
  `echo "$@."` with `echo "$*."` so a multi-word message keeps its
  trailing dot on the last word. All repository shell scripts now
  pass `shellcheck` without warnings (except the two info-level
  `SC1091` follow-notes in the legacy `Deskpi-uninstall` wrapper for
  files that only exist on an installed system).

- **Fan stuck at its previous level after a daemon restart.**
  `pwmFanControl_v3.c` initialised `last_pwm` to 0, i.e. it assumed
  the MCU was idle at startup. If the daemon was (re)started while the
  fan was actually spinning at an old level (daemon crash, manual
  override) and the temperature had already dropped below the first
  threshold, the computed `pwm_000` equalled the assumed wire state
  and no token was ever sent — the fan stayed at its previous speed
  until the CPU heated up again. `last_pwm` now starts at a 999
  sentinel that matches no real level, so the first temperature
  reading always pushes the computed level onto the wire; a daemon
  restart therefore re-asserts the automatic curve unconditionally.

- **`safeCutOffPower.c` exit code did not match its documented
  contract.** The header promised `0` only when at least one attempt
  wrote all 9 bytes AND its `tcdrain()` returned 0, but the code
  counted an attempt as successful on `write()` alone, leaving a
  failed `tcdrain()` (bytes possibly still in the kernel buffer at
  halt) invisible to the exit code. `ok_count` is now incremented
  only when both succeed, the failure message no longer claims
  "every write failed" when writes went out but were never drained,
  and the success message goes to stdout. Also: skipped the trailing
  100 ms pause after the last attempt and dropped unused includes.

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

   Because `deskpi-cut-off-power.service` is the only token sender and
   covers **every** shutdown path (front-panel button, SSH, apt,
   kernel panic followed by an orderly halt), the 18 s `sleep` in
   `deskpi-shutdown-helper` keeps the poweroff.target chain pinned
   until the MCU reacts.

  Fix verified on a Raspberry Pi 4B running Debian 13: a double-click
  of the front power button now cuts the 5 V rail within ~15 s
  and the SoC powers off (previously the OS would halt while 5 V
  stayed hot).

- **`pwmFanControl_v3.c` built-in default curve.**
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
  option 7 restarts it — note it also deletes `/etc/deskpi.conf`, so
  the daemon falls back to the built-in default curve, not the
  previously saved one.
- **`deskpi-config` cosmetic / code-quality cleanup.**
  Unified the two copies (`installation/deskpi-config` and
  `installation/drivers/deskpi-config`, which had drifted), removed
  redundant `sudo rm` and `daemon-reload`, added `[ -t 0 ]` guard for
  the "Press <Enter>" prompt, and added an exit warning if the
  daemon is left stopped. The manual-level menu is now monotonically
  ordered by fan speed — option 1 is OFF (`pwm_000`) up to option 5
  at 100 % (`pwm_100`) — matching the ascending levels of the curve.

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
