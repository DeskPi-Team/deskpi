#!/bin/bash
# uninstall deskpi  script 
#
if [ "$EUID" -ne 0 ]
  then echo "Please run as root or with sudo"
  exit
fi

deskpi=/lib/systemd/system/deskpi.service
safeshutdaemon=/lib/systemd/system/deskpi-safeshut.service
echo "DeskPi Driver Uninstalling..."
echo "Configure /boot/config.txt"
sed -i '/dtoverlay=dwc2,dr_mode=host/d' /boot/config.txt
echo "Stop and disable DeskPi services"
systemctl stop deskpi.service
systemctl stop deskpi-safeshut.service
systemctl daemon-reload
rm -f "$deskpi" 2&>/dev/null
rm -f "$safeshutdaemon" 2&>/dev/null
rm -f /usr/bin/safecutoffpower* 2&>/dev/null
rm -f /usr/bin/pwmControlFan* 2&>/dev/null
rm -rf /etc/modules-load.d/raspberry.conf 2&>/dev/null
# remove Uninstall script itself
rm -f /usr/local/bin/Deskpi-uninstall
# remove deskpi-config
rm -f /usr/local/bin/deskpi-config
# remove log functions
rm -f '/usr/local/lib/deskpi-log-functions'
echo "Uninstall DeskPi Driver Successfully." 

