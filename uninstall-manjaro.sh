#!/bin/bash
# uninstall deskpi  script 

deskpi=/lib/systemd/system/systemd-deskpi-safecutoffpower.service
echo "DeskPi Driver Uninstalling..."
echo "Configure /boot/config.txt"
sudo sed -i '/dtoverlay=dwc2,dr_mode=host/d' /boot/config.txt
echo "Stop and disable DeskPi  services"
sudo rm -f $deskpi 2&>/dev/null 
sudo rm -f /usr/bin/safecutoffpower* 2&>/dev/null
sudo rm -rf /etc/modules-load.d/raspberry.conf 2&>/dev/null
echo "Uninstall DeskPi Driver Successfully." 

