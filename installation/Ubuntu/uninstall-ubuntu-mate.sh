#!/bin/bash
# uninstall deskpi script 

daemonname="deskpi"
deskpidaemon=/lib/systemd/system/$daemonname.service
safeshutdaemon=/lib/systemd/system/$daemonname-safeshut.service

echo  "Uninstalling DeskPi PWM Fan Control and Safeshut Service."
sleep 1
echo  "Diable DeskPi PWM Fan Control and Safeshut Service."
echo  "Remove dtoverlay configure from /boot/firmware/config.txt file"
sudo sed -i '/dtoverlay=dwc2,dr_mode=host/d' /boot/firmware/config.txt
echo  "Stop and disable DeskPi services"
sudo systemctl disable $daemonname.service 2&>/dev/null  
sudo systemctl stop $daemonname.service  2&>/dev/null
sudo systemctl disable $daemonname-safeshut.service 2&>/dev/null
sudo systemctl stop $daemonname-safeshut.service 2&>/dev/null
echo  "Remove DeskPi PWM Fan Control and Safeshut Service."
sudo rm -f  $deskpidaemon  2&>/dev/null 
sudo rm -f  $safeshutdaemon 2&>/dev/null 
sudo rm -f /usr/bin/fanStop 2&>/dev/null
sudo rm -f /usr/bin/pwmFanControl 2&>/dev/null 
sudo rm -f /usr/bin/deskpi-config 2&>/dev/null 
sudo rm -f /usr/bin/Deskpi-uninstall 2&>/dev/null 
echo "Uninstall DeskPi Driver Successfully." 
