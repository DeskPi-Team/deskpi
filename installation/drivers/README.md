# Control Your Fan througn PWM signal via Serial port(OTG)
## Configure /boot/config.txt to enbale otg function.
```bash
sudo vim.tiny /boot/firmware/config.txt 
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
git clone -b feature/bookworm https://github.com/DeskPi-Team/deskpi.git
cd ~/deskpi/installation/drivers/c/
```
* 2. How to compile it.
```bash
make 
```
* 3. How to run it.
```bash
sudo ./pwmControlFan64
```
* 4. How to stop it.
Press "Ctrl + C" on keyboard.
* 5. How to clean the source code directory.
```bash
make clean
```
## How to change speed of the fan.
This program is send the pwm signal from Raspberry Pi to the extension board via OTG serial port, which will be recognized by your Raspberry Pi as "/dev/DeskPi_FAN" device which is symboliclink to /dev/ttyUSB0. so if you want to control the fan as your wish, you can modify pwmControlFan.c code and recompile it.
* In the default code, we have set 4 level for you Fan on pwm signal:
* Level 0: 0%  speed-> send "pwm_000" to /dev/DeskPi_FAN", means to turn off the fan 
* Level 1: 25% speed-> send "pwm_025" to /dev/DeskPi_FAN", means to set fan speed to 25%
* Level 2: 50% speed-> send "pwm_050" to /dev/DeskPi_FAN", means to set fan speed to 50%
* Level 3: 75% speed-> send "pwm_075" to /dev/DeskPi_FAN", means to set fan speed to 75%
* Level 4:100% speed-> send "pwm_100" to /dev/DeskPi_FAN", means to set fan speed to 100%
