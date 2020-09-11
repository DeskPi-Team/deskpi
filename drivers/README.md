# Control Your Fan througn PWM signal via Serial port(OTG)
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
This program is send the pwm signal from Raspberry Pi to the extension board via OTG serial port, which will be recognized by your Raspberry Pi as "/dev/ttyUSB0" device. so if you want to control the fan as your wish, you can modify pwmControlFan.c code and recompile it.
* In the default code, we have set 4 level for you Fan on pwm signal:
** Level 0: 0%  speed-> send "pwm_000" to /dev/ttyUSB0", means to turn off the fan 
** Level 1: 25% speed-> send "pwm_025" to /dev/ttyUSB0", means to set fan speed to 25%
** Level 2: 50% speed-> send "pwm_050" to /dev/ttyUSB0", means to set fan speed to 50%
** Level 3: 75% speed-> send "pwm_075" to /dev/ttyUSB0", means to set fan speed to 75%
** Level 4:100% speed-> send "pwm_100" to /dev/ttyUSB0", means to set fan speed to 100%

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
sudo python3 pwmcontrolfan.py
```
### Job Done.

