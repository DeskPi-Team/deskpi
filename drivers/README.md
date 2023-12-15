# Control your fan through `PWM` signalling via the serial interface of the USB port (in `OTG` mode)
## Configure `/boot/config.txt` to enable USB `OTG` mode.
```bash
sudo vim.tiny /boot/config.txt 
```
add:
```bash
dtoverlay=dwc2, dr_mode=host
```
save it and reboot Raspberry Pi.
## C Language
* 1. At First, get the demo code from github.
```bash
cd ~
git clone https://github.com/DeskPi-Team/deskpi.git
cd ~/deskpi/drivers/c/
```
* 2. How to compile it.
```bash
make 
```
* 3. How to run it.
```bash
sudo ./pwmFanControl
```
* 4. How to stop it.
Press "Ctrl + C"
* 5. How to clean the source code directory.
```bash
make clean
```
## How to change speed of the fan.
This program sends a `PWM` signal from your Raspberry Pi to the extension board, via USB port in `OTG` mode, which will your Raspberry Pi recognizes as the `/dev/ttyUSB0` device. 

So if you want to control the fan as your wish, you can modify the code in `pwmControlFan.c` and recompile it.

However, as defaults, we have set 4 levels users can apply, via `PWM` signal:

* Level 0: 0%  speed-> send `pwm_000` to `/dev/ttyUSB0` , means to turn off the fan 
* Level 1: 25% speed-> send `pwm_025` to `/dev/ttyUSB0` , means to set fan speed to 25%
* Level 2: 50% speed-> send `pwm_050` to `/dev/ttyUSB0` , means to set fan speed to 50%
* Level 3: 75% speed-> send `pwm_075` to `/dev/ttyUSB0` , means to set fan speed to 75%
* Level 4:100% speed-> send `pwm_100` to `/dev/ttyUSB0` , means to set fan speed to 100%

# Python
## How to control fan through PWM signal via serial port.
You can also control your fan with python script.
just remember to send "pwm_xxx" to "/dev/ttyUSB0" device. xxx means the level of your fan speed. from 0-100 (integer).
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
cd ~/deskpi/drivers/python/
sudo python3 pwmControlFan.py
```
### Job Done.

