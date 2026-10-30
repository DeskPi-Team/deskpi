# `installation/drivers/c/` — fan daemon source tree

Two C programs and a `Makefile`. Both binaries they produce are
deployed by every per-distro installer (Raspberry Pi OS, Ubuntu,
DietPi, Kali, Manjaro, Fedora) and are required for the DeskPi Pro
hardware to work end-to-end.

| Binary | Source | Role |
|--------|--------|------|
| `pwmFanControl64V3` | [`pwmFanControl_v3.c`](pwmFanControl_v3.c) | Long-running fan daemon. Reads CPU temperature every 1 s and writes the appropriate `pwm_NNN` token to `/dev/ttyUSB0`. Also listens for the `poweroff` / `power_off` byte sequence from the MCU and triggers `systemctl poweroff`. |
| `safeCutOffPower64` | [`safeCutOffPower.c`](safeCutOffPower.c) | One-shot helper. Opens `/dev/ttyUSB0`, writes the literal 9-byte string `power_off` (no NUL terminator), closes the fd and exits. The systemd `Type=oneshot` unit that wraps it (`deskpi-cut-off-power.service`) runs at `poweroff.target` and finishes in ~500 ms (5 attempts with 100 ms gaps). |

## What ships where

```
installation/
├── deskpi-config                    # canonical interactive configurator
├── install.sh / uninstall.sh        # unified auto-detecting installer
├── <Distro>/
│   ├── install-<distro>.sh          # per-distro installer (calls make)
│   └── uninstall-<distro>.sh        # per-distro uninstaller
└── drivers/
    ├── c/                           # ← you are here
    │   ├── Makefile
    │   ├── README.md                # this file
    │   ├── pwmFanControl_v3.c       # fan daemon
    │   └── safeCutOffPower.c        # 5 V cut-off helper
    ├── deskpi-config                # mirror of the canonical configurator
    └── README.md                    # legacy quick-start + Python examples
```

## Building

From the C source directory:

```bash
cd installation/drivers/c
make              # builds pwmFanControl64V3 + safeCutOffPower64
sudo make install # copies both to /usr/bin/ with mode 0755
make clean        # removes the local build artifacts
```

The `Makefile` is intentionally tiny — it only invokes `gcc` with the
default flags. No autoconf, no pkg-config, no external libraries:
just plain POSIX + Linux `<termios.h>`.

The fan daemon uses `vcgencmd` for the temperature read on the
reference build but is not strictly required — the daemon falls back
to `/sys/class/thermal/thermal_zone0/temp` and reports 0 °C if that
also fails (no compile-time dependency on either tool).

## How the binaries talk to the MCU

Both binaries talk to the DeskPi Pro daughter-board MCU over
`/dev/ttyUSB0`, a CH340 enumerated by the
`dtoverlay=dwc2,dr_mode=host` overlay enabled in
`/boot/firmware/config.txt` (or `/boot/config.txt` on legacy
layouts). The protocol is intentionally trivial: short fixed-length
strings, 9600 8-N-1.

| Direction | Token | Meaning |
|-----------|-------|---------|
| host → MCU | `pwm_000` | fan off |
| host → MCU | `pwm_025` | fan at 25 % |
| host → MCU | `pwm_050` | fan at 50 % |
| host → MCU | `pwm_075` | fan at 75 % |
| host → MCU | `pwm_100` | fan at 100 % |
| host → MCU | `power_off` | cut 5 V rail ~15 s later |
| MCU → host | `poweroff` / `power_off` | DeskPi Pro front-panel power button. The MCU reacts **only to a double-click** — a single click sends nothing. Each click of the pair sends its own token, so one double-click delivers the token **twice**; `pwmFanControl64V3` calls `systemctl poweroff` on the first token and the second is ignored. (Button behaviour on other DeskPi models has not been verified — confirmed on a DeskPi Pro only) |

`printf '%s' "$token" > /dev/ttyUSB0` is the entire write path. Do
**not** use `echo` — it appends a trailing newline which the MCU
silently mis-parses as a different token.

## How the fan curve works

`pwmFanControl64V3` reads `/etc/deskpi.conf` at start-up. The file is
human-readable: one `fan_N = TEMPERATURE` line per fan level, where
TEMPERATURE is the CPU temperature (°C) **up to which** that level
applies. Above the last line the fan runs at 100 %. Blank lines and
`#` comments are ignored; values must not decrease.

```
# /etc/deskpi.conf — DeskPi Pro fan curve
#
# Fan curve: one "fan_N = TEMPERATURE" line per level, where
# TEMPERATURE is the CPU temperature (degC) up to which that
# level applies. Above the last line (fan_75) the fan runs at
# 100 %. Values must not decrease; blank lines and #-comments
# are ignored.
#
# Optional: log_fan_changes = 1 — journal a line on every fan
# level change (e.g. "fan 25 % -> 50 % at 62 degC").
# Default: 0 (silent). Uncomment the last line to enable it.

fan_0 = 40
fan_25 = 50
fan_50 = 65
fan_75 = 75
# log_fan_changes = 1
```

With `log_fan_changes = 1` the daemon journals a line on every fan
level change, with the temperature that triggered it — e.g.
`pwmFanControl64V3: fan 25 % -> 50 % at 62 degC` (the first assertion
at startup is logged as `fan level 50 % asserted at 62 degC
(startup)`). The value must be `0` or `1`; anything else is treated as
`1` with a warning. Default is `0` (silent). Lines appear in
`journalctl -u deskpi.service`.

The fan speeds are fixed at 0 / 25 / 50 / 75 / 100 % — the four
temperatures are the only configurable part. (The MCU itself accepts
any `pwm_NNN` token, but the curve exposes only these five named
levels.)

There is deliberately **no `fan_100` key**: `fan_N` is the temperature
*up to which* a level applies, and the top level has no upper bound —
its switch-on point *is* `fan_75`. A `fan_100` line (or any other
unknown key, e.g. `fan_30`) is reported and ignored, so a typo in a
key name degrades to the default value rather than breaking the file.

Every inconsistency is reported on stderr (visible as
`journalctl -u deskpi.service`): garbage lines, unknown keys, repeated
keys (**the first occurrence wins** — any repetition is reported and
skipped), values outside 1–110 °C, and a non-increasing temperature
sequence — e.g. `fan_0 = 75` with `fan_75 = 30` (0 % up to 75 °C while
100 % already starts at 30 °C) is repaired by pushing each threshold
just above the previous one, with a warning per violation. An
**unreadable** file (permissions, …) is reported once (`cannot open …
using built-in default curve`) and the defaults apply — only a
genuinely missing file stays silent, since having no custom curve is a
normal state. A **corrupt/binary** file stops parsing after 16
malformed lines with a single "file looks corrupt" summary instead of
flooding the journal. Nothing in the config is ever fatal: the daemon
always ends up with a usable, monotonic curve.

**Legacy support:** configs in the old format (8 bare integers, one
per line: `temp1`/`pwm1`/…/`temp4`/`pwm4`) are **not** parsed by V3 —
a leftover legacy file is effectively ignored (malformed lines are
skipped key by key, the rest falls back to the defaults). Rewrite the
file in the `fan_N` format above, or delete it and let the daemon use
the built-in defaults, or run `sudo deskpi-config` option 6.

If the file is missing or unreadable, the daemon falls back to the
built-in default curve (the values shown above):

| CPU temperature | Fan speed |
|-----------------|-----------|
| ≤ 40 °C | 0 % (off) |
| 40 – 50 °C | 25 % |
| 50 – 65 °C | 50 % |
| 65 – 75 °C | 75 % |
| ≥ 75 °C | 100 % |

A 10 % hysteresis band (`PERCENTAGE` in the source) prevents the fan
from chattering when the CPU temperature sits right on a threshold.

Use `sudo deskpi-config` to interactively edit the curve: option 6
asks for the four temperatures and writes the file above, option 7
deletes `/etc/deskpi.conf` so the daemon falls back to the built-in
defaults.

## The 5 V cut-off flow

The MCU only knows it should cut the 5 V rail once it sees the
9-byte literal `power_off` on `/dev/ttyUSB0`. There is no
acknowledgement protocol — fire-and-forget. The token is written by
exactly one component for **every** shutdown cause:

### `deskpi-cut-off-power.service` — the only token sender

`safeCutOffPower64`, wrapped by the `deskpi-shutdown-helper` script,
covers all shutdown paths: the front-panel power button, `sudo poweroff`
over SSH, unattended apt upgrades, kernel panic followed by an orderly
halt, etc. The `Type=oneshot` unit is ordered
`Before=halt.target shutdown.target poweroff.target`, so it fires only
after every regular service has already been stopped.

`safeCutOffPower64` opens `/dev/ttyUSB0`, sets the line to raw 9600
8N1, no flow control, then writes `power_off` five times with
`tcdrain()` + `tcflush()` between each attempt — every event is logged
to stderr (journald, `journalctl -u deskpi-cut-off-power.service`):
the port open, each delivered attempt, and a final verdict. After the
writes it returns 0 only if at least one copy made it out.

The wrapper script (`/usr/bin/deskpi-shutdown-helper`) logs every step
both to `/var/log/deskpi-shutdown.log` (persistent history) and to
journald. Every file line is `sync`ed immediately after being written:
the MCU cuts the 5 V rail ~15 s after the token, and anything still in
the page cache at that moment is lost — without the sync the log would
look exactly like the helper never ran (verified on hardware):

- `BEGIN cut-off sequence …` — the service started, the token is about
  to be sent;
- the timestamped `safeCutOffPower64` output lines (attempts, verdict);
- `DELIVERED …` on success, or `FAILED … rc=1` with a "power stays on"
  warning when the token never made it;
- `HOLD waiting 18 s …` on success;
- `END hold elapsed …` — **reaching this line means the 5 V rail was
  NOT cut**: if the MCU did its job, the SoC loses power mid-hold and
  the helper dies before writing `END`. An `END` line in the log is a
  "power stayed on" diagnostic, not a routine confirmation.

The installers also drop a logrotate policy into
`/etc/logrotate.d/deskpi` (monthly, 3 compressed archives),
so the persistent log stays bounded without any manual maintenance.

Because the token goes out at `poweroff.target`, the MCU's internal
~15 s delay covers only the final unmount + halt — never the service
shutdown itself.

### `pwmFanControl_v3.c` — button handling only

The daemon watches the serial port in its 1-second loop. When it reads
the literal `poweroff` / `power_off` token from the MCU (DeskPi Pro
front-panel double-click — the MCU reacts to nothing less; other DeskPi
models unverified), it logs
`front-panel power button pressed — MCU sent a poweroff token`, runs
`sync && systemctl poweroff` and exits. A double-click delivers the
token twice, once per click; the daemon acts on the first and the
second is harmlessly ignored. It
deliberately does **not** write the `power_off` cut-off token itself:
doing so would start the MCU's 15 s timer at button-press time and
leave the OS only ~14 s to shut down — a slow or heavily loaded system
would get its 5 V cut mid-teardown. Deferring the token to
`poweroff.target` trades that risk for the opposite one: an OS that
hangs before reaching `poweroff.target` never sends the token and the
rail stays hot — the same behaviour as any non-button shutdown; the
user can force-cut with a long button press or by unplugging.

| Shutdown cause | Who sends `power_off` |
|---|---|
| Double-click front power button (DeskPi Pro) | daemon triggers shutdown → service at `poweroff.target` |
| `sudo poweroff` over SSH | service |
| unattended apt upgrade | service |
| Kernel panic → orderly halt | service, if the OS still reaches `poweroff.target` |

In all cases the token is sent while the system is quiescent (all
regular services stopped), and the MCU's ~15 s window is spent on the
final unmount + halt only.

### Line discipline — why it matters

`safeCutOffPower64` MUST set 9600 8N1 with no hardware flow control.
The DeskPi Pro's CH340 runs at 9600 8N1 and does not assert CTS,
so any stray `CRTSCTS` bit will make the kernel `write()` block
forever waiting for a CTS pulse that never arrives. The daemon
already has the port set up correctly at startup; the helper binary
re-asserts the same settings every time it opens the port.


## File history

| Removed in this tree | Replaced by | Reason |
|----------------------|-------------|--------|
| `pwmFanControl.c` (V1) | `pwmFanControl_v2.c` (V2) | V1 had no curve support, no poweroff detection, and a no-op `c_cflag &= ~PARENB; \|= PARENB;` block. V2 adds the temperature→PWM curve, the `poweroff` MCU-to-host listener, and 10 % hysteresis. |
| `pwmFanControl_v2.c` (V2) | `pwmFanControl_v3.c` (V3) | V3 fixes the spin-down to `pwm_000` (the fan could stay stuck at its last level, also after a daemon restart), defers the 5 V cut-off token entirely to `deskpi-cut-off-power.service`, and switches `/etc/deskpi.conf` to the human-readable `fan_N` format — legacy 8-integer files are no longer parsed. |

See the repo-root `CHANGELOG.md` under `[Unreleased]` for the
migration entry.
