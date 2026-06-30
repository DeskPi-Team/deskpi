# Installation / 安装说明

## Quick start / 快速开始

The simplest entry point is the **unified installer** at the top of this
directory. It auto-detects your OS, prints a summary, and asks for
confirmation before doing anything.

最简单的入口是本目录顶层的 **unified installer**。它会自动检测你的
操作系统，打印摘要，并在执行任何操作前要求你确认。

```bash
sudo ./install.sh
```

The matching unified uninstaller is `./uninstall.sh`. Both accept
`--help`, `--dry-run`, `--yes`, and `--os=<distro>` to override
detection.

> 32-bit systems are no longer supported. Use a 64-bit OS to get the
> full performance of the Raspberry Pi 4.
>
> 32 位系统已不再支持，请使用 64 位操作系统以充分发挥 Raspberry Pi 4
> 的性能。

> The official Raspberry Pi OS image receives the most testing and is
> recommended for most users.
>
> 对于大多数用户，推荐使用官方 Raspberry Pi OS 镜像（测试最充分）。

If you prefer the per-distro scripts, you can still run them directly
(see "Per-distro scripts" below), but the unified installer is now the
canonical entry point.

## What gets installed / 安装内容

Every per-distro installer deploys the same two systemd units and the same
three binaries, so the user-visible behavior is identical regardless of
which OS you pick.

每个发行版的安装脚本都会部署同样两个 systemd unit 和同样三个二进制，
所以无论你装在哪个系统上，用户感知到的行为是一致的。

| Component / 组件 | Path | Role |
|------------------|------|------|
| `pwmFanControl64V2` | `/usr/bin/pwmFanControl64V2` | Fan daemon. Reads CPU temperature, sends `pwm_NNN` to the MCU. Also listens for `poweroff` from the MCU and calls `systemctl poweroff`. |
| `safeCutOffPower64` | `/usr/bin/safeCutOffPower64` | One-shot helper. Writes 9 bytes of `power_off` to the MCU so it cuts the 5 V rail ~15 s later. |
| `deskpi-config` | `/usr/bin/deskpi-config` | Interactive fan-speed configurator (the TUI you get with `sudo deskpi-config`). |
| `deskpi.service` | `/etc/systemd/system/deskpi.service` | `Type=simple` long-running fan daemon. |
| `deskpi-cut-off-power.service` | `/etc/systemd/system/deskpi-cut-off-power.service` | `Type=oneshot` service, `WantedBy=halt.target shutdown.target poweroff.target`, `Conflicts=reboot.target`. Runs `safeCutOffPower64` during the shutdown sequence. |
| `dtoverlay=dwc2,dr_mode=host` | `/boot/firmware/config.txt` (or `/boot/config.txt` on legacy layouts) | Enables the dwc2 host-mode overlay so the on-board CH340 enumerates as `/dev/ttyUSB0`. |

> If `systemctl list-unit-files` shows `deskpi.service` but not
> `deskpi-cut-off-power.service`, the OS will halt but the 5 V rail will
> stay hot. Re-run the installer to fix that.
>
> 如果 `systemctl list-unit-files` 里只看到 `deskpi.service` 而没有
> `deskpi-cut-off-power.service`，系统会 halt 但 5V 不会断。重跑一遍
> 对应发行版的安装脚本就能修好。

## Per-distro scripts / 各发行版脚本

These are still available for users who want to call a specific
installer directly. The unified installer dispatches to the matching
one of these.

| Distro | Install | Uninstall |
|--------|---------|-----------|
| Raspberry Pi OS 64-bit | `RaspberryPiOS/64bit/install-raspios-64bit.sh` | `RaspberryPiOS/64bit/uninstall-raspios-64bit.sh` |
| Ubuntu 64-bit | `Ubuntu/install-ubuntu-64.sh` | `Ubuntu/uninstall-ubuntu-mate.sh` |
| DietPi 64-bit | `DietPi/install-dietPi-64bit.sh` | `DietPi/uninstall-dietPi-64bit.sh` |
| Kali ARM-64 | `Kali/install-kali.sh` | `Kali/uninstall-kali.sh` |
| Manjaro ARM-64 | `Manjaro/install-manjaro.sh` | `Manjaro/uninstall-manjaro.sh` |
| Fedora aarch64 (deprecated) | `Fedora/install-fedora.sh` | `Fedora/uninstall-fedora.sh` |

Each per-distro script accepts `--auto-reboot` and `--help`.

## The current file structure

```
.
├── install.sh                 # unified installer (auto-detects, prompts)
├── uninstall.sh               # unified uninstaller (auto-detects, prompts)
├── deskpi-config              # canonical interactive configurator
├── DietPi/
│   ├── install-dietPi-64bit.sh
│   └── uninstall-dietPi-64bit.sh
├── drivers/
│   ├── c/
│   │   ├── Makefile
│   │   ├── pwmFanControl_v2.c     # fan daemon (default on every supported distro)
│   │   └── safeCutOffPower.c      # one-shot cut-off helper
│   ├── deskpi-config          # mirror of the canonical configurator
│   ├── Deskpi-uninstall       # legacy menu-driven uninstaller
│   ├── python/
│   │   ├── pwmControlFan.py
│   │   └── safecutoffpower.py
│   └── README.md
├── Fedora/
│   ├── install-fedora.sh
│   ├── README.md              # deprecation notice
│   └── uninstall-fedora.sh
├── Kali/
│   ├── install-kali.sh
│   └── uninstall-kali.sh
├── Manjaro/
│   ├── install-manjaro.sh
│   └── uninstall-manjaro.sh
├── RaspberryPiOS/
│   └── 64bit/
│       ├── install-raspios-64bit.sh     # recommended for most users
│       └── uninstall-raspios-64bit.sh
├── README.md                      # this file
└── Ubuntu/
    ├── install-ubuntu-64.sh
    └── uninstall-ubuntu-mate.sh
```

## Get Support / 获取支持

If you have any trouble on using our product, please kindly send E-mail to: **support@deskpi.com**

如果你在使用过程中遇到任何问题，欢迎发邮件到： **support@deskpi.com**

For the change history of this repository (including the 2026-06-22 5 V
cutoff fix and the unified installer), see [CHANGELOG.md](../CHANGELOG.md)
at the repo root.
