# FAQ 
## About USB booting, what is UASP?
* Without UASP, a drive is mounted as a Mass Storage Device using Bulk Only Transport (or BOT), a protocol that was designed for transferring files way back in the USB 'Full speed' days, when the fastest speed you could get was a whopping 12 Mbps!
* With USB 3.0, the BOT protocol cripples throughput. USB 3.0 has 5 Gbps of bandwidth, which is 400x more than USB 1.1. The old BOT protocol would transfer data in large chunks, and each chunk of data had to be delivered in order, without regard for buffering or multiple bits of data being able to transfer in parallel.
* So a new protocol was created, called 'USB Attached SCSI Protocol', or 'UASP'
 
## How to check if my drive is support UASP?
* If you have a USB drive and don't want to take it apart and look up the specs of the controller chip, the only reliable way to tell if it's being mounted with UASP support or not is to plug it into your Pi, then run the command lsusb -t:
```bash
$ lsusb -t
/:  Bus 02.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 5000M
    |__ Port 1: Dev 2, If 0, Class=Mass Storage, Driver=uas, 5000M
```
This command lists all the USB devices in a tree, and for each of the hard drives, you should see a Driver listed. If it's uas (like in the above example), then your drive supports UASP and you'll get the best speed. If it's usb-storage, then it's using the older BOT protocol and you won't see the full potential.
## Why does my fan not spin after the Pi has been idle for a while?
* By default the DeskPi fan driver adjusts the speed according to the
  CPU temperature. When the temperature is below the fan rotation
  threshold (see the table in the README), the fan stops automatically.
  To pin the fan at a specific speed, run `sudo deskpi-config` and pick
  one of the static levels from the menu.

## How do I customize the fan curve in `/etc/deskpi.conf`?
* The daemon reads `/etc/deskpi.conf` **once at start-up** — after
  editing the file run `sudo systemctl restart deskpi.service`.
* The file is human-readable: one `fan_N = TEMPERATURE` line per fan
  level, where TEMPERATURE is the CPU temperature (°C) **up to which**
  that level applies. Above the last line the fan runs at 100 %.
  `deskpi-config` writes the file with a documentation header and a
  commented-out logging option at the end:
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
  The fan speeds themselves are fixed at 0 / 25 / 50 / 75 / 100 % —
  only the four temperatures are configurable. There is deliberately
  **no `fan_100` key**: the top level has no upper bound, its
  switch-on point *is* `fan_75`.
* Optional key `log_fan_changes = 1` journals a line on every fan
  level change with the temperature that triggered it, e.g.
  `pwmFanControl64V3: fan 25 % -> 50 % at 62 degC`
  (`journalctl -u deskpi.service`). Default is `0` (silent) — to
  enable it, uncomment the `# log_fan_changes = 1` line at the end of
  the file.
* You cannot break anything by hand-editing: every inconsistency is
  reported in the journal and repaired — garbage lines and unknown
  keys are skipped (with a warning), values are clamped to 1–110 °C,
  repeated keys keep the **first** value, and a non-increasing
  temperature sequence (e.g. `fan_0 = 75` with `fan_75 = 30`) is
  pushed back into a monotonic curve. If the file is missing or
  unreadable, the built-in defaults (40 / 50 / 65 / 75) apply.
* The interactive way: `sudo deskpi-config`, option **6** — it asks
  for the four temperatures in sequence (`fan_0` → `fan_25` →
  `fan_50` → `fan_75`, each prompt showing which level comes next and
  ending with "100 % (pwm_100) above <fan_75> degC") and writes the
  file for you with mode `0644`, the documentation header shown above,
  and a commented-out `# log_fan_changes = 1` at the end (an already
  enabled `log_fan_changes = 1` is preserved uncommented).

## What are the credentials on the pre-installed Raspbian OS image?
* Username: `pi`, password: `raspberry`. This is the standard Raspbian
  default; the DeskPi team does not change it when distributing the
  image.

## Why is the pre-installed Raspbian OS image set up for China by default?
* The pre-installed image is based on Raspbian Buster (2020-08-20),
  and during initialisation we have to set the Wi-Fi country before the
  Wi-Fi adapter can be enabled. The product is sold worldwide, so we
  cannot predict the buyer's country in advance — the default is
  therefore Shanghai, China. To change it, run `sudo raspi-config` and
  pick **Localisation Options** → **WLAN Country**.

## The front panel USB port is unavailable.
* That is almost always because `dtoverlay=dwc2,dr_mode=host` is
  missing from `/boot/firmware/config.txt` (or `/boot/config.txt` on
  legacy layouts). Add that line and reboot. The unified installer
  adds it for you — it shows the exact diff and asks for confirmation
  first, and marks the inserted block with a `# DeskPi` comment so it
  is easy to find (and cleanly removed by the uninstaller, which asks
  the same way).

## How do I change the hostname on the pre-installed Raspbian OS image?
* Either run `sudo raspi-config` and pick **System Options** → **S4
  Hostname**, or run `sudo hostnamectl set-hostname YOURHOSTNAMEHERE`
  from the command line.

## How do I check whether my drive supports UASP?
* Run `lsusb -t | grep -i uas` — drives listed with the `uas` driver
  support UASP and run at full speed; drives listed with `usb-storage`
  fall back to the older BOT protocol.

## How do I install the DeskPi fan control driver after re-flashing the SD card?
* Make sure your OS is on the supported list (see the README).
* Make sure your Raspberry Pi can reach the internet.
* Clone the repo and run the unified installer:
  ```bash
  git clone https://github.com/DeskPi-Team/deskpi.git
  cd ~/deskpi/installation
  sudo ./install.sh
  ```
  The installer auto-detects your OS, prints what it is about to do,
  and asks for confirmation. To uninstall, run `sudo ./uninstall.sh`
  from the same directory.

## Where is the list of supported OSes?
* See the README at https://github.com/DeskPi-Team/deskpi and the table
  in `installation/README.md`.

## I double-press the front power button and the OS shuts down, but the 5 V rail stays on — the fan and the front USB LED never go off. What's wrong?
* The DeskPi Pro daughter board cuts the 5 V rail **only when it receives the literal byte sequence `power_off` over `/dev/ttyUSB0` during the shutdown sequence**. The OS-level `systemctl poweroff` only halts the CPU; on a Raspberry Pi 4 the firmware leaves 5 V on by default (`POWER_OFF_ON_HALT=0` in the EEPROM config) and relies on the DeskPi Pro's MCU to do the actual cut.
* A correct installation must therefore have **two** systemd units:
  1. `deskpi.service` — runs at boot, monitors the MCU for `poweroff`, calls `systemctl poweroff` when it sees it.
  2. `deskpi-cut-off-power.service` — `Type=oneshot`, `WantedBy=poweroff.target`, `Before=halt.target shutdown.target poweroff.target`, `Conflicts=reboot.target`. When systemd processes the power-off, this service starts first, runs `/usr/bin/deskpi-shutdown-helper` (which invokes `/usr/bin/safeCutOffPower64` to write 9 bytes of `power_off` to the MCU, then holds the shutdown open for ~18 s). The MCU waits ~15 s and cuts the 5 V rail.
* If only one of those two is present, you get exactly the symptoms above (OS halts, but the DeskPi Pro stays powered). The fix is to re-run the installer — the unified `sudo ./install.sh` is the easiest entry point; it auto-detects your OS and deploys both units. Verify with:
  ```bash
  systemctl is-enabled  deskpi.service                  # enabled
  systemctl is-enabled  deskpi-cut-off-power.service    # enabled
  ls -l /usr/bin/safeCutOffPower64 /usr/bin/pwmFanControl64V3
  ```
* The full shutdown event history is in `/var/log/deskpi-shutdown.log` and `journalctl -u deskpi-cut-off-power.service`. Note that a *successful* cut-off never writes an `END` line — the SoC loses power mid-hold; an `END` line means the rail was **not** cut. The file is rotated automatically by logrotate (monthly, 3 compressed archives kept).
* You can also exercise the cut-off unit in isolation (this **will** trigger the MCU to cut 5 V ~15 s later, so only do it when you are ready to power-cycle the Pi):
  ```bash
  sudo systemctl start deskpi-cut-off-power.service
  ```
  To see exactly which bytes were written, run it under `strace` first:
  ```bash
  sudo strace -e openat,write /usr/bin/safeCutOffPower64
  # expected last lines:
  # openat(AT_FDCWD, "/dev/ttyUSB0", O_RDWR|O_NOCTTY|O_SYNC) = 3
  # write(3, "power_off", 9) = 9
  # +++ exited with 0 +++
  ```
* See `CHANGELOG.md` (2026-06-22 entry) for the full bug history.
