#!/bin/bash
# uninstall deskpi script 
. /lib/lsb/init-functions

daemonname="deskpi"
arch="$(uname -m | grep -o 64)"
deskpidaemon=/lib/systemd/system/$daemonname.service
safeshutdaemon=/lib/systemd/system/$daemonname-safeshut.service

log_action_msg "Uninstalling DeskPi PWM Fan Control and Safeshut Service."
sleep 1
log_action_msg "Diable DeskPi PWM Fan Control and Safeshut Service."
log_action_msg "Remove dtoverlay configure from /boot/firmware/config.txt file"
sudo sed -i '/dtoverlay=dwc2,dr_mode=host/d' /boot/firmware/config.txt
log_action_msg "Stop and disable DeskPi services"
sudo systemctl disable $daemonname.service 2&>/dev/null  
sudo systemctl stop $daemonname.service 2&>/dev/null
sudo systemctl disable $daemonname-safeshut.service 2&>/dev/null
sudo systemctl stop $daemonname-safeshut.service 2&>/dev/null
log_action_msg "Remove DeskPi PWM Fan Control and Safeshut Service."
sudo rm -f $deskpidaemon 2&>/dev/null 
sudo rm -f $safeshutdaemon 2&>/dev/null 
sudo rm -f /usr/bin/safecutoffpower$arch 2&>/dev/null
sudo rm -f /usr/bin/pwmFanControl$arch 2&>/dev/null 
sudo rm -f /usr/bin/deskpi-config 2&>/dev/null 
sudo rm -f /usr/bin/Deskpi-uninstall 2&>/dev/null
if [ -e /lib/udev/rules.d/*-brltty.rules ]; then
sudo sed -i 's/#ENV{PRODUCT}=="1a86\/7523/ENV{PRODUCT}=="1a86\/7523/g' /lib/udev/rules.d/*-brltty.rules; fi   
log_success_msg "Uninstall DeskPi Driver Successfully." 
