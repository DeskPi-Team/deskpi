# Changelog / 变更日志

All notable changes to this project will be documented in this file.

本文件记录本项目的所有重要变更。格式基于 [Keep a Changelog](https://keepachangelog.com/)，
版本号遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

### Changed / 变更
- **All distros now use the V2 fan daemon (`pwmFanControl64V2`).**
  The Ubuntu / DietPi / Kali / Manjaro / Fedora installers previously
  installed the legacy `pwmFanControl64` (V1, no curve support, no
  poweroff detection); they now install V2 just like the Raspberry Pi OS
  installer. The V1 source (`drivers/c/pwmFanControl.c`) and the
  corresponding `pwmFanControl64` build/install target have been
  removed. Uninstaller scripts still scrub `pwmFanControl64` from
  `/usr/bin/` for legacy hosts.
  所有发行版现在统一使用 V2 守护进程（`pwmFanControl64V2`）。Ubuntu /
  DietPi / Kali / Manjaro / Fedora 此前装的是遗留版 `pwmFanControl64`
  （无曲线、无 poweroff 检测），现在与树莓派 OS 安装器对齐到 V2。V1
  源码（`drivers/c/pwmFanControl.c`）与 `pwmFanControl64` 的构建/安装
  target 已移除；卸载脚本仍会清理 `/usr/bin/pwmFanControl64`，方便老
  机器升级。

### Fixed / 修复
- **`pwmFanControl_v2.c` built-in default curve.**
  The default array was `{40,75, 50,75, 65,100, 75,100}` which sent
  the fan to 75 % from 40 °C upward — loud and contrary to the FAQ
  statement "the fan stops automatically". Changed to
  `{40,25, 50,50, 65,75, 75,100}`, matching the defaults shown in
  `deskpi-config`.
  内置默认曲线 `{40,75, 50,75, 65,100, 75,100}` 让风扇在 40°C 就 75%
  噪音很大，与 FAQ「fan stops automatically」描述不符。改成
  `{40,25, 50,50, 65,75, 75,100}`，与 `deskpi-config` 显示的默认值一致。
- **`deskpi-config` manual levels (1-5) now stop the daemon.**
  Previously the running daemon overwrote the manual PWM token within
  ~1 s, contradicting the FAQ ("To pin the fan at a specific speed,
  run `sudo deskpi-config` and pick one of the static levels").
  Options 1-5 now stop `deskpi.service` so the override sticks;
  option 7 restarts it.
  `deskpi-config` 选项 1-5 现在会停止守护进程，否则运行中的守护进程
  ~1 秒后会覆盖手动设定的 PWM token — 与 FAQ「pin the fan at a
  specific speed」描述矛盾。选项 7 重新启动守护进程。
- **`deskpi-config` cosmetic / code-quality cleanup.**
  Unified the two copies (`installation/deskpi-config` and
  `installation/drivers/deskpi-config`, which had drifted), removed
  redundant `sudo rm` and `daemon-reload`, added `[ -t 0 ]` guard for
  the "Press <Enter>" prompt, and added an exit warning if the
  daemon is left stopped.
  `deskpi-config` 整理：两个副本统一（之前已 drift）、删除冗余的
  `sudo rm` 与 `daemon-reload`、`Press <Enter>` 加 `[ -t 0 ]` 守卫、
  退出时若守护进程仍停止则给出警告。

## [2026-06-22]

### Fixed / 修复
- **关机后 5V 不切断 (The 5 V rail was not being cut after shutdown).**
  On Raspberry Pi OS 64-bit the `install-raspios-64bit.sh` script never
  installed `deskpi-cut-off-power.service`, so even though
  `pwmFanControl64V2` correctly detected the `poweroff` token from the
  MCU and called `systemctl poweroff`, no service ever echoed `power_off`
  back to the MCU, leaving the DeskPi Pro's 5 V rail hot after every
  shutdown. The other distros (Ubuntu, DietPi, Kali) did install the
  service but their `safeCutOffPower.c` was a `while(1)` busy loop that
  would block the `Type=oneshot` unit for the full systemd start
  timeout.

  在树莓派 OS 64 位上，`install-raspios-64bit.sh` 一直没有安装
  `deskpi-cut-off-power.service`。所以即使 `pwmFanControl64V2` 正确检测到
  MCU 发来的 `poweroff` 并调用了 `systemctl poweroff`，也没有任何服务
  向 MCU 回写 `power_off`，导致 DeskPi Pro 的 5V 每次关机后都保持带电。
  其他发行版（Ubuntu、DietPi、Kali）虽然装了这个 service，但它们的
  `safeCutOffPower.c` 是 `while(1)` 死循环，会让 `Type=oneshot` 单元
  卡到 systemd 的 start timeout 才往下走。

### Changed / 变更
- **All `install-*.sh` scripts (Raspberry Pi OS, Ubuntu, DietPi, Kali,
  Manjaro, Fedora) now share the same canonical layout**: `--auto-reboot`
  CLI flag, idempotent unit creation, consistent `Before=`,
  `Conflicts=`, `WantedBy=`, and `DefaultDependencies=` directives for
  `deskpi-cut-off-power.service`. The RaspiOS installer is the
  reference; the others are brought in line.
  所有发行版的 `install-*.sh` 现在使用统一的 canonical 结构：含
  `--auto-reboot` CLI 选项、幂等的 service 创建、`deskpi-cut-off-power.service`
  的 `Before=`/`Conflicts=`/`WantedBy=`/`DefaultDependencies=` 一致。
  RaspiOS 是参考实现，其他发行版对齐过来。
- **`safeCutOffPower.c` rewritten as a one-shot binary.**
  Removed the `while(1)` loop; the program now opens `/dev/ttyUSB0`,
  writes the 9-byte literal `power_off` (no NUL terminator), closes the
  fd and returns 0. The systemd `Type=oneshot` unit completes in
  ~60 ms instead of being killed by `TimeoutStartSec` (default 90 s).
  `safeCutOffPower.c` 重写为一次性 binary：open → write 9 字节 `power_off`
  → close → return 0。`Type=oneshot` service 在 ~60 ms 内正常退出，不再
  被 systemd 的 90 s start timeout 干掉。
- **All `uninstall-*.sh` scripts hardened.**
  Clean up the new `deskpi-cut-off-power.service` unit and the new
  `safeCutOffPower64` / `pwmFanControl64V2` binaries, plus legacy aliases
  (`deskpi-safeshut.service`, `deskpi-cutoffpower.service`, etc.) so
  reinstalls on a previously-installed host do not leave stale state.
  所有 `uninstall-*.sh` 加固：清理新的 `deskpi-cut-off-power.service`、
  `safeCutOffPower64`、`pwmFanControl64V2`，并把历史上出现过的别名
  （`deskpi-safeshut.service`、`deskpi-cutoffpower.service` 等）一起清掉，
  避免老机器上重装留下脏状态。
- **The legacy top-level `uninstall.sh` no longer depends on `figlet`** and
  no longer references the typo'd `deskpi-cutoffpower.service` (missing
  dash) — it was a no-op against the actual unit name.
  顶层 `uninstall.sh` 不再硬依赖 `figlet`，并修正了
  `deskpi-cutoffpower.service`（少一个连字符）的拼写错误——之前这个
  service 名是错的，根本不会匹配到任何已安装的 unit。
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

### Verified / 验证
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
