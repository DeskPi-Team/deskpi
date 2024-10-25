# About the DeskPi Pro

The DeskPi Pro is a hardware kit for converting a standard Raspberry Pi 4 from a naked SBC, with limited storage, into a mini PC complete with a power button, cooling, better ports and, via SATA then USB3, 2.5" or M.2 SSD storage.

## Youtube Tutorial

[Youtube video](https://youtu.be/eaXC5O3amfA)

## Currently tested operating systems that can support Deskpi scripts
* Raspberry Pi OS(32bit) - Deprecated 
* RaspiOS (64bit) - tested 
* Ubuntu-mate OS(32bit) - Deprecated 
* Ubuntu OS (64bit) - on testing (24.04) - Unsupport anymore. `dtoverlay=dwc2,dr_mode=host` will not work well. 
* Manjaro OS (32bit) - Deprecated 
* Manjaro OS (64bit) - tested
* Kali-linux-arm OS (32bit) - Deprecated
* Kali-linux-arm OS (64-Bit) - Deprecated 
* Twister OS v2.0.2 (32bit) - Deprecated 
* DietPi OS (64bit) - tested
* Volumio OS Version: 2021-04-24-Pi (32bit) - tested 
* RetroPie OS (32bit) - tested
* Windows 10 IoT - NOT Supported 
* Windows 11 - NOT Supported  

## Please Read this section carefully
* if you are using 64bit OS, The script to control the fan is in the `installation/drivers/c/` directory. The file suffix with `64` means `64bit`, and the `32bit` executable file has been removed, if you want to use 32bit, please download the repository and compile it by yourself. 

* Before you install this script, please make sure your Raspberry Pi can access internet and can access github website.

## How to install it.
* 1. Download the Repository 
* 2. Enter `installation` directory 
* 3. Select Your OS type
* 4. Execute shell script inside the OS folder.

For example: 

### For Raspbian OS 64bit (bookworm)
```bash 
git clone https://github.com/DeskPi-Team/deskpi.git 
cd ~/deskpi/installation/RaspberryPiOS/64bit/
sudo ./install-raspios-64bit.sh 
```

### For Volumio OS Version: 2021-04-24-Pi
* Image Download URL: https://updates.volumio.org/pi/volumio/2.882/volumio-2.882-2021-04-24-pi.img.zip
* Getting Start:　https://volumio.github.io/docs/User_Manual/Quick_Start_Guide.html
* Make sure your Volumio can access internet. 
* There are some steps need to do.
```
sudo nano /etc/network/interface
```
make sure following parameters in file `/etc/network/interface` 
```
auto wlan0 
allow-hotplug wlan0 
iface wlan0 inet dhcp
wpa-ssid "YOUR WIFI SSID"
wpa-psk "YOUR WIFI PASSWORD"
```
and enable the internet access by typing this command in terminal:
```
volumio internet on
```
and then reboot your DeskPi.
```
sudo reboot
```

###Setting Fan Speed Manually
* Open a terminal and typing: 
```
deskpi-config
```
Select `4` and press `Enter`, you would see the fan is spinning and the front USB port are now available.

> NOTE: Once you execute this `deskpi-config` command, the deskpi.service will be stopped at background.

> you will need to execute `sudo systemctl restart deskpi.service` to re-activate it. 

> If `deskpi.service` is in a stopped state, it will not read the configuration in the `/etc/deskpi.conf` file to control the fan. 

> Therefore, if you want the fan to operate automatically according to your custom temperature settings, please ensure that the `deskpi.service` is always running in the background, especially after executing the deskpi-config command, you need to manually restart the `deskpi.service` by executing `sudo systemctl restart deskpi.service` command in a terminal. 


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
** If you want to change it, just typing :
```
deskpi-config
```
Select `6` and then input `45` and enter, and then input `50` means setup the fan speed level to `50%` when CPU temp is above 45 degree it has 4 level to setup.

> NOTE: 50% Speed level means you have already send `PWM50` to `/dev/ttyUSB0` port, and this port will available when you add `dtoverlay=dwc2,dr_mode=host` to `/boot/firmware/config.txt` file and `reboot` your DeskPi. 


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
