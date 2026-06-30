# `installation/drivers/c/` — fan daemon source tree

Two C programs and a `Makefile`. Both binaries they produce are
deployed by every per-distro installer (Raspberry Pi OS, Ubuntu,
DietPi, Kali, Manjaro, Fedora) and are required for the DeskPi Pro
hardware to work end-to-end.

| Binary | Source | Role |
|--------|--------|------|
| `pwmFanControl64V2` | [`pwmFanControl_v2.c`](pwmFanControl_v2.c) | Long-running fan daemon. Reads CPU temperature every 1 s and writes the appropriate `pwm_NNN` token to `/dev/ttyUSB0`. Also listens for the `poweroff` / `power_off` byte sequence from the MCU and triggers `systemctl poweroff`. |
| `safeCutOffPower64` | [`safeCutOffPower.c`](safeCutOffPower.c) | One-shot helper. Opens `/dev/ttyUSB0`, writes the literal 9-byte string `power_off` (no NUL terminator), closes the fd and exits. The systemd `Type=oneshot` unit that wraps it (`deskpi-cut-off-power.service`) runs at `poweroff.target` and finishes in ~60 ms. |

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
    │   ├── pwmFanControl_v2.c       # fan daemon
    │   └── safeCutOffPower.c        # 5 V cut-off helper
    ├── deskpi-config                # mirror of the canonical configurator
    └── README.md                    # legacy quick-start + Python examples
```

## Building

From the C source directory:

```bash
cd installation/drivers/c
make              # builds pwmFanControl64V2 + safeCutOffPower64
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
| MCU → host | `poweroff` / `power_off` | double-click on power button — `pwmFanControl64V2` calls `systemctl poweroff` |

`printf '%s' "$token" > /dev/ttyUSB0` is the entire write path. Do
**not** use `echo` — it appends a trailing newline which the MCU
silently mis-parses as a different token.

## How the fan curve works

`pwmFanControl64V2` reads `/etc/deskpi.conf` at start-up. The file
contains 8 integers, 2 per curve point:

```
temp1
pwm1
temp2
pwm2
temp3
pwm3
temp4
pwm4
```

The fan runs at `pwm_i` % whenever
`temp_{i-1} ≤ CPU_temp < temp_i`, and at `pwm_4` % above `temp_4`.
If the file is missing or unreadable, the daemon falls back to the
built-in default curve (defined in the `def[8]` array at the top of
`pwmFanControl_v2.c`):

| CPU temperature | Fan speed |
|-----------------|-----------|
| < 40 °C | 0 % (off) |
| 40 – 50 °C | 25 % |
| 50 – 65 °C | 50 % |
| 65 – 75 °C | 75 % |
| ≥ 75 °C | 100 % |

A 10 % hysteresis band (`PERCENTAGE` in the source) prevents the fan
from chattering when the CPU temperature sits right on a threshold.

Use `sudo deskpi-config` to interactively edit the curve; option 6
launches the wizard, option 7 deletes `/etc/deskpi.conf` so the
daemon falls back to the built-in defaults.

## The 5 V cut-off flow — redundant signalling

The MCU only knows it should cut the 5 V rail once it sees the
9-byte literal `power_off` on `/dev/ttyUSB0`. There is no
acknowledgement protocol — fire-and-forget. To make sure the
message actually reaches the MCU no matter how the OS is being shut
down, the signalling runs on **two independent paths**:

### Path A — `pwmFanControl_v2.c::check_poweroff` (PRIMARY)

The daemon watches the serial port in its 1-second loop. The moment
it reads the literal `poweroff` or `power_off` token from the MCU
(the front-panel double-click), it:

1. Calls `send_power_off()` to write `power_off` to the MCU three
   times with `tcdrain()` between each. This reuses the already-open
   serial fd, so no race for the port against the systemd helper.
2. Then runs `sync && systemctl poweroff`.

This is the primary path because it fires **seconds before**
`poweroff.target` is reached — the system is still fully alive, the
tty driver has not been torn down, and the MCU has the full
shutdown window to react.

### Path B — `deskpi-cut-off-power.service` (BACKUP)

For shutdowns that did not originate from the front-panel power
button (`sudo poweroff` over SSH, unattended apt upgrade, kernel
panic followed by orderly reboot-to-halt, etc.), `pwmFanControl64V2`
is never triggered. The systemd `Type=oneshot` service at
`poweroff.target` covers those cases.

`safeCutOffPower64` opens `/dev/ttyUSB0`, sets the line to raw 9600
8N1, no flow control, then writes `power_off` five times with
`tcdrain()` + `tcflush()` between each attempt. After the writes it
returns 0 only if at least one copy made it out.

The helper script (`/usr/bin/deskpi-shutdown-helper`) wraps the
binary:

- `BEGIN power_off pid=$$ triggered_by=deskpi-cut-off-power.service` is logged.
- `safeCutOffPower64` runs (~500 ms with the redundancy inside).
- on success, sleeps `DESKPI_CUT_OFF_HOLD_SECONDS` (default 18) so
  the kernel cannot return from `systemctl poweroff` before the MCU
  has cut 5 V.
- `END power_off … rc=$?` is logged.

### Why both?

The two paths exist so that:

| Shutdown cause | Path that fires |
|---|---|
| Double-click front power button | **A + B** — daemon acks immediately, service re-acks at `poweroff.target` |
| `sudo poweroff` over SSH | B only |
| unattended apt upgrade | B only |
| Kernel panic → orderly halt | B only |
| daemon crashes before the user presses the button | B only |

In the worst case (`pwmFanControl64V2` is dead for some reason),
the user still gets a 5 V cut within ~15 s of `poweroff.target`
because path B is independent.

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

See the repo-root `CHANGELOG.md` under `[Unreleased]` for the
migration entry.
