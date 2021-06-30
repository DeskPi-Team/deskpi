#!/bin/bash
# 
echo "DeskPi Driver Installing..."
if [ -d /tmp/deskpi ]; then
	sudo rm -rf /tmp/deskpi 2&>/dev/null
fi
echo "Download the latest DeskPi Driver from GitHub..."
cd /tmp && git clone https://github.com/DeskPi-Team/deskpi.git 

echo "DeskPi Driver Installation Start."
deskpiv1=/lib/systemd/system/systemd-deskpi-safecutoffpower.service
driverfolder=/tmp/deskpi

# delete deskpi-safecutoffpower.service file.
if [ -e $deskpi ]; then
	sudo sh -c "rm -f $deskpi"
fi

# adding dtoverlay to enable dwc2 on host mode.
echo "Configure /boot/config.txt file and enable front USB2.0"
sudo sed -i '/dtoverlay=dwc2*/d' /boot/config.txt
sudo sed -i '$a\dtoverlay=dwc2,dr_mode=host' /boot/config.txt 
sudo sh -c "echo dwc2 > /etc/modules-load.d/raspberry.conf" 

sudo cp -rf $driverfolder/drivers/c/safecutoffpower64 /usr/bin/safecutoffpower64
sudo cp -rf $driverfolder/drivers/python/safecutoffpower.py /usr/bin/safecutoffpower.py
sudo chmod 644 /usr/bin/safecutoffpower64
sudo chmod 644 /usr/bin/safecutoffpower.py

# send cut off power signal to MCU before system shuting down.
sudo echo "[Unit]" > $deskpi
sudo echo "Description=DeskPi Safe Cut-off Power Service" >> $deskpi
sudo echo "Conflicts=reboot.target" >> $deskpi
sudo echo "DefaultDependencies=no" >> $deskpi
sudo echo "" >> $deskpi
sudo echo "[Service]" >> $deskpi
sudo echo "Type=oneshot" >> $deskpi
sudo echo "ExecStart=/usr/bin/sudo /usr/bin/safecutoffpower64" >> $deskpi
sudo echo "# ExecStart=/usr/bin/sudo python3 /usr/bin/safecutoffpower.py" >> $deskpi
sudo echo "RemainAfterExit=yes" >> $deskpi
sudo echo "TimeoutStartSec=15" >> $deskpi
sudo echo "" >> $deskpi
sudo echo "[Install]" >> $deskpi
sudo echo "WantedBy=halt.target shutdown.target poweroff.target final.target" >> $deskpi

sudo chown root:root $deskpi
sudo chmod 644 $deskpi

sudo systemctl daemon-reload
sudo systemctl enable systemd-deskpiv1-safecutoffpower.service
# install rpi.gpio for fan control
yes |sudo pacman -S python-pip
sudo pip3 install pyserial
# sudo pacman -S python python-pip base-devel
# env CFLAGS="-fcommon" pip install rpi.gpio

sync
sudo rm -rf /tmp/deskpi
echo "DeskPi Driver installation successful, system will reboot in 5 seconds to take effect!"
sleep 5 && sudo reboot
