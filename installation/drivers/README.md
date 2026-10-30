# `installation/drivers/` — legacy quick-start

> **Note:** This file is the original quick-start and is preserved for
> users who want the bare-bones "just give me a shell command"
> instructions. For the canonical, up-to-date documentation of the C
> source tree (build, protocol, fan curve, 5 V cut-off flow), see
> [`c/README.md`](c/README.md). The pre-built C daemon shipped by
> every supported distro is `pwmFanControl64V3` — the legacy
> `pwmFanControl` (V1) has been removed.

# Control Your Fan through PWM signal via Serial port(OTG)
## Configure /boot/config.txt to enable otg function.
```bash
sudo vim.tiny /boot/config.txt
```
add:
```bash
dtoverlay=dwc2,dr_mode=host
```
save it and reboot Raspberry Pi.
## C Language
* 1. At First, get the demo code from github.
```bash
cd ~
git clone https://github.com/DeskPi-Team/deskpi.git
cd ~/deskpi/installation/drivers/c/
```
* 2. How to compile it.
```bash
make
```
* 3. How to run it.
```bash
sudo ./pwmFanControl64V3
```
* 4. How to stop it.
Press "Ctrl + C"
* 5. How to clean the source code directory.
```bash
make clean
```
## How to change speed of the fan.
This program sends the pwm signal from Raspberry Pi to the extension board via OTG serial port, which is recognized as `/dev/ttyUSB0` on your Raspberry Pi. To customise the temperature→speed curve, edit `/etc/deskpi.conf` (one `fan_N = TEMPERATURE` line per level; see `installation/drivers/c/README.md` for the full format) or use `sudo deskpi-config` for an interactive editor.
* The fan daemon understands 5 PWM levels (sent as `pwm_NNN` to `/dev/ttyUSB0`):
  * 0 %  → `pwm_000` (fan off)
  * 25 % → `pwm_025`
  * 50 % → `pwm_050`
  * 75 % → `pwm_075`
  * 100 % → `pwm_100`

  Note: in `/etc/deskpi.conf` there is no `fan_100` key — `fan_75` is the
  switch-on temperature of the top level, and above it the fan simply runs
  at 100 %.

# Python
## How to control fan through PWM signal via serial port.
You can also control your fan with a Python script — just send `pwm_xxx` to `/dev/ttyUSB0`, where `xxx` is the desired fan speed (0–100).
### 1. Install pyserial library.
* Python2.x
```bash
pip install pyserial
```
* Python3.x
```bash
pip3 install pyserial
```
### 2. Get the demo code from github and execute it.
```bash
cd ~
git clone https://github.com/DeskPi-Team/deskpi.git
cd ~/deskpi/installation/drivers/python/
sudo python3 pwmControlFan.py
```
### Job Done.

