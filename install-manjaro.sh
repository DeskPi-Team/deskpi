#!/bin/bash

# Variables
deskPiDir=/home/$USER
fanstop=/tmp/deskpi/deskpiFanStop.service
fancontrol=/tmp/deskpi/deskpiFanControl.service

# Temp dir
mkdir /tmp/deskpi
touch /tmp/deskpi/deskpiFanStop.service
touch /tmp/deskpi/deskpiFanControl.service

echo "================= DeskPi driver installation ================="

echo ""

echo "---------------------- DeskPi compiling ----------------------"
yes | sudo pacman -S gcc
gcc $deskPiDir/deskpi/drivers/c/pwmControlFan.c -o $deskPiDir/deskpi/drivers/c/pwmFanControl
gcc $deskPiDir/deskpi/drivers/c/fanStop.c -o $deskPiDir/deskpi/drivers/c/fanStop
echo "------------------ DeskPi compiling finished -----------------"

echo ""

echo "---------------- DeskPi service configuration ----------------" 
# Boot config
sudo touch /etc/modprobe.d/raspberry.conf
sudo sh -c "echo dwc2 > /etc/modprobe.d/raspberry.conf"
sudo sh -c "echo '# Deskpi Pro USB configuration' >> /boot/config.txt"
sudo sh -c "echo 'dtoverlay=dwc2,dr_mode=host' >> /boot/config.txt"

# Commands copy
sudo cp $deskPiDir/deskpi/drivers/c/fanStop  /usr/bin/deskpiFanStop
sudo chmod 755 /usr/bin/deskpiFanStop
sudo cp $deskPiDir/deskpi/drivers/c/pwmFanControl /usr/bin/deskpiFanControl
sudo chmod 755 /usr/bin/deskpiFanControl

# Safe shutdown service
sudo echo "[Unit]" > $fanstop
sudo echo "Description=DeskPi Safe Cut-off Power Service" >> $fanstop
sudo echo "Conflicts=reboot.target" >> $fanstop
sudo echo "DefaultDependencies=no" >> $fanstop
sudo echo "" >> $fanstop
sudo echo "[Service]" >> $fanstop
sudo echo "Type=oneshot" >> $fanstop
sudo echo "ExecStart=/usr/bin/sudo /usr/bin/deskpiFanStop" >> $fanstop
sudo echo "RemainAfterExit=yes" >> $fanstop
sudo echo "TimeoutStartSec=15" >> $fanstop
sudo echo "" >> $fanstop
sudo echo "[Install]" >> $fanstop
sudo echo "WantedBy=halt.target shutdown.target poweroff.target final.target" >> $fanstop

# Fan control service
sudo echo "[Unit]" > $fancontrol
sudo echo "Description=DeskPi PWM Control Fan Service" >> $fancontrol
sudo echo "After=multi-user.target" >> $fancontrol
sudo echo "" >> $fancontrol
sudo echo "[Service]" >> $fancontrol
sudo echo "Type=simple" >> $fancontrol
sudo echo "RemainAfterExit=no" >> $fancontrol
sudo echo "ExecStart=/usr/bin/sudo /usr/bin/deskpiFanControl" >> $fancontrol
sudo echo "" >> $fancontrol
sudo echo "[Install]" >> $fancontrol
sudo echo "WantedBy=multi-user.target" >> $fancontrol

sudo touch /lib/systemd/system/deskpiFanStop.service
sudo touch /lib/systemd/system/deskpiFanControl.service

sudo mv /tmp/deskpi/deskpiFanStop.service /lib/systemd/system/deskpiFanStop.service
sudo mv /tmp/deskpi/deskpiFanControl.service /lib/systemd/system/deskpiFanControl.service
sudo rm -rf /tmp/deskpi

# Permissions
sudo chown root:root /lib/systemd/system/deskpiFanStop.service
sudo chmod 644 /lib/systemd/system/deskpiFanStop.service
sudo chown root:root /lib/systemd/system/deskpiFanControl.service
sudo chmod 644 /lib/systemd/system/deskpiFanControl.service
echo "------------ DeskPi service configuration finished ------------" 

echo ""

echo "------------- DeskPi service initialisation start -------------" 
sudo systemctl daemon-reload
sudo systemctl start deskpiFanControl.service
sudo systemctl enable deskpiFanControl.service
sudo systemctl enable deskpiFanStop.service
echo "------------ DeskPi service initialisation finished -----------"

echo ""

sync
echo "DeskPi Driver installation successful, system will reboot in 10 seconds to take effect!"
sleep 10
sudo reboot
