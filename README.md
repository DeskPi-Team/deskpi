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
TEMP   : Fan_SPEED_LEVEL
<40C   : 0%  
40~50C : 25%  
50~65C : 50%  
65~75C : 75%  
>75C   : 100%  
![Example](https://raw.githubusercontent.com/DeskPi-Team/deskpi/master/imgs/deskpi-config-snap.jpg)

## LOGO
![LOGO](https://raw.githubusercontent.com/DeskPi-Team/deskpi/master/imgs/deskpilogo1.png)

