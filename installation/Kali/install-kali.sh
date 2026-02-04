#!/bin/bash
# 
# . /lib/lsb/init-functions

daemonname="deskpi"
tempmonscript=/usr/bin/pmwFanControl
deskpidaemon=/lib/systemd/system/$daemonname.service
safeshutdaemon=/lib/systemd/system/$daemonname-safeshut.service
installationfolder=/home/kali/deskpi

# install wiringPi library.
echo  "DeskPi Fan control script installation Start." 

# Create service file on system.
if [ -e $deskpidaemon ]; then
	sudo rm -f $deskpidaemon
fi

# adding dtoverlay to enable dwc2 on host mode.
sudo sed -i '/dtoverlay=dwc2*/d' /boot/firmware/config.txt 
sudo sed -i '$a\dtoverlay=dwc2,dr_mode=host' /boot/firmware/config.txt 

# install PWM fan control daemon.
echo  "DeskPi main control service loaded."
cd $installationfolder/installation/drivers/c/ 
sudo cp -rf $installationfolder/installation/drivers/c/pwmFanControl64 /usr/bin/pwmFanControl64
sudo cp -rf $installationfolder/installation/drivers/c/safeCutOffPower64  /usr/bin/safeCutOffPower64
sudo cp -rf $installationfolder/installation/deskpi-config /usr/bin/deskpi-config
sudo cp -rf $installationfolder/installation/Deskpi-uninstall /usr/bin/Deskpi-uninstall
sudo chmod 755 /usr/bin/pwmFanControl64
sudo chmod 755 /usr/bin/safeCutOffPower64
sudo chmod 755 /usr/bin/deskpi-config 
sudo chmod 755 /usr/bin/Deskpi-uninstall

# Build Fan Daemon
echo "[Unit]" > $deskpidaemon
echo "Description=DeskPi PWM Control Fan Service" >> $deskpidaemon
echo "After=multi-user.target" >> $deskpidaemon
echo "[Service]" >> $deskpidaemon
echo "Type=simple" >> $deskpidaemon
echo "RemainAfterExit=true" >> $deskpidaemon
echo "ExecStart=sudo /usr/bin/pwmFanControl64 &" >> $deskpidaemon
echo "[Install]" >> $deskpidaemon
echo "WantedBy=multi-user.target" >> $deskpidaemon

# send signal to MCU before system shuting down.
echo "[Unit]" > $safeshutdaemon
echo "Description=DeskPi Safeshutdown Service" >> $safeshutdaemon
echo "Conflicts=reboot.target" >> $safeshutdaemon
echo "Before=halt.target shutdown.target poweroff.target" >> $safeshutdaemon
echo "DefaultDependencies=no" >> $safeshutdaemon
echo "[Service]" >> $safeshutdaemon
echo "Type=oneshot" >> $safeshutdaemon
echo "ExecStart=/usr/bin/sudo /usr/bin/safeCutOffPower64" >> $safeshutdaemon
echo "RemainAfterExit=yes" >> $safeshutdaemon
echo "[Install]" >> $safeshutdaemon
echo "WantedBy=halt.target shutdown.target poweroff.target" >> $safeshutdaemon

echo  "DeskPi Service configuration finished." 
sudo chown root:root $safeshutdaemon
sudo chmod 755 $safeshutdaemon

sudo chown root:root $deskpidaemon
sudo chmod 755 $deskpidaemon

echo  "DeskPi Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable $daemonname.service
sudo systemctl start $daemonname.service &
sudo systemctl enable $daemonname-safeshut.service

# Finished 
echo "DeskPi PWM Fan Control and Safeshut Service installed successfully." 
# greetings and require rebooting system to take effect.
echo  "System will reboot in 5 seconds to take effect." 
sudo sync
sleep 5 
sudo reboot
