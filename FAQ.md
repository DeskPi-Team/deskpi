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
  adds it for you automatically.

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
  2. `deskpi-cut-off-power.service` — `Type=oneshot`, `WantedBy=poweroff.target`, `Before=halt.target shutdown.target poweroff.target`, `Conflicts=reboot.target`. When systemd processes the power-off, this service starts first, runs `/usr/bin/safeCutOffPower64` (which writes 9 bytes of `power_off` to the MCU), and exits cleanly in ~60 ms. The MCU then waits ~15 s and cuts the 5 V rail.
* If only one of those two is present, you get exactly the symptoms above (OS halts, but the DeskPi Pro stays powered). The fix is to re-run the installer — the unified `sudo ./install.sh` is the easiest entry point; it auto-detects your OS and deploys both units. Verify with:
  ```bash
  systemctl is-enabled  deskpi.service                  # enabled
  systemctl is-enabled  deskpi-cut-off-power.service    # enabled
  ls -l /usr/bin/safeCutOffPower64 /usr/bin/pwmFanControl64V2
  ```
* You can also exercise the cut-off unit in isolation (this **will** trigger the MCU to cut 5 V ~15 s later, so only do it when you are ready to power-cycle the Pi):
  ```bash
  sudo systemctl start deskpi-cut-off-power.service
  ```
  To see exactly which bytes were written, run it under `strace` first:
  ```bash
  sudo strace -e openat,write /usr/bin/safeCutOffPower64
  # expected last lines:
  # openat(AT_FDCWD, "/dev/ttyUSB0", O_RDWR|O_NOCTTY) = 3
  # write(3, "power_off", 9) = 9
  # +++ exited with 0 +++
  ```
* See `CHANGELOG.md` (2026-06-22 entry) for the full bug history.
