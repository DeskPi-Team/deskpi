# deskpi
DeskPi Pro is the Ultimate Case Kit for Raspberry Pi 4 with Full Size HDMI/2.5 Hard Disk Support and Safe Power Button, It has QC 3.0 Power Supply inside and New ICE Tower Cooler inside.
## Product Links: https://deskpi.com
## How to install it.
### For Raspbian and RetroPie OS.
```bash
cd ~
git clone https://github.com/DeskPi-Team/deskpi.git
cd ~/deskpi/
chmod +x install.sh
sudo ./install.sh
```
### For Ubuntu-mate OS
```bash
cd ~
git clone https://github.com/DeskPi-Team/deskpi.git
cd ~/deskpi/
chmod +x install-ubuntu-mate.sh
sudo ./install-ubuntu-mate.sh
```
### For Manjaro OS
```bash
cd ~
git clone https://github.com/DeskPi-Team/deskpi.git
cd ~/deskpi/
chmod +x install-manjaro.sh
sudo ./install-manjaro.sh
```
### For Kali-linux-arm OS.
* Image Download URL: https://images.kali.org/arm-images/kali-linux-2020.3a-rpi3-nexmon.img.xz <br>
```bash
cd ~
git clone https://github.com/DeskPi-Team/deskpi.git
cd ~/deskpi/
chmod +x install-kali.sh
sudo ./install-kali.sh
```
## How to Uninstall deskpi
```bash
DeskPi-uninstall 
```
And then select the number against to your OS Type.
### For Windows IoT OS
* Unsupported due to lacking of driver.
* Testing version: Midnight falcon
## How to control fan speed mannualy.
* Open a terminal and typing following command:
```bash
deskpi-config
```
You can follow the instructions to setup fan speed level by typing numbers as
following example:
### Selection explain
* The number from 1 to 4 is to setting your fan speed to a static level.
* Number 5 is just turn off the fan.
* Number 6 is to guide you to create a file located to /etc/deskpi.conf and you
can specify the threshold of temperature and fan speed level according to your
idea, once the file has been created, the program will according to the
configuration file to setup your fan.
* Number 7 is to enable automatic fan control by default paramaters. 
** Default arguments:  
```
TEMP   : Fan_SPEED_LEVEL
<40C   : 0%  
40~50C : 25%  
50~65C : 50%  
65~75C : 75%  
>75C   : 100%  
```
![Example](https://raw.githubusercontent.com/DeskPi-Team/deskpi/master/imgs/deskpi-config-snap.jpg)
## How to boot from USB SSD/HDD?
After initial Raspberry Pi Configuration and once you have Internet Connectivity established, Install the DeskPi Pro Utilities from `https://github.com/DeskPi-Team/deskpi.git`
Open a Terminal / Console and run the following commands:  
```bash 
sudo apt update
sudo apt full-upgrade
sudo rpi-update
```
When complete, run:
```bash
sudo reboot
```
Upon reboot, open Terminal again:
```bash
sudo raspi-config
```
* go to Advanced Options 
* Select Boot Order, select #1 `USB Boot`, Return to Advanced Options,
* Select Boot Loader Version, choose `Latest Version`
* Save & exit
### Reboot again (to restart with new settings)
```bash
sudo reboot 
```
After reboot, re-open Terminal again
```bash
sudo -E rpi-eeprom-config --edit
```
•	do not change anything, it is unnecessary
•	press Ctrl-X to save, answer Y to overwrite file.
```bash
sudo reboot    
```
Now you are ready to install Raspberry-OS onto your USB Boot Device.
You can use the Raspberry Imager from `www.raspberrypi.org` website. 
Depending on device the new SD Card Copier can transfer the SD-Card image to the USB Device (ensure you select generate a new UUID). 
Once your USB drive is imaged & ready to boot, shutdown your Deskpi-Pro, remove the SD-Card and power-up to boot from the USB Boot drive, once running & configured you can install your additional software and proceed as usual. 
<br>
* Tutorial video: https://youtu.be/wUHZb9E_WDQ  <br>
## How to Use IR function onboard.
1. You need to enable `gpio-ir` function by modify `/boot/config.txt` file.
uncomment this line if not exsit please add it.
```bash
dtoverlay=gpio-ir,gpio_pin=17 
```
2. Install `lirc` package:
```bash
sudo apt-get install lirc
```
3. Modify configuration file on location: /etc/lirc/lirc_options.conf and make sure it has following parameters:
```bash
driver          = default
device          = /dev/lirc0
```
4. Reboot your Raspberry Pi and test it with following command:
```bash
mode2 -d /dev/lirc1
```
## LOGO
![LOGO](https://raw.githubusercontent.com/DeskPi-Team/deskpi/master/imgs/deskpilogo1.png)

