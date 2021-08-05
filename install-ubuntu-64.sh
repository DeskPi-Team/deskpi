#!/bin/bash
# 
. /lib/lsb/init-functions

daemonname="deskpi"
tempmonscript=/usr/bin/pmwFanControl
deskpidaemon=/lib/systemd/system/$daemonname.service
safeshutdaemon=/lib/systemd/system/$daemonname-safeshut.service
# Thanks for muckypaws' help, solve the location problem.
installationfolder=/home/$SUDO_USER/deskpi

# install DeskPi stuff.
log_action_msg "DeskPi Fan control script installation Start." 

# Create service file on system.
if [ -e $deskpidaemon ]; then
	sudo rm -f $deskpidaemon
fi

# adding dtoverlay to enable dwc2 on host mode.
sudo sed -i '/dtoverlay=dwc2*/d' /boot/firmware/config.txt 
sudo sed -i '$a\dtoverlay=dwc2,dr_mode=host' /boot/firmware/config.txt 

# install PWM fan control daemon.
log_action_msg "DeskPi main control service loaded."
cd $installationfolder/drivers/c/ 
mv $installationfolder/drivers/c/pwmFanControl $installationfolder/drivers/c/pwmFanControl.old
gcc -o $installationfolder/drivers/c/pwmFanControl $installationfolder/drivers/c/pwmControlFan.c
sudo cp -rf $installationfolder/drivers/c/pwmFanControl /usr/bin/pwmFanControl
sudo cp -rf $installationfolder/drivers/c/fanStop  /usr/bin/fanStop
sudo cp -rf $installationfolder/deskpi-config  /usr/bin/deskpi-config
sudo cp -rf $installationfolder/Deskpi-uninstall  /usr/bin/Deskpi-uninstall
sudo chmod 755 /usr/bin/pwmFanControl
sudo chmod 755 /usr/bin/fanStop
sudo chmod 755 /usr/bin/deskpi-config
sudo chmod 755 /usr/bin/Deskpi-uninstall

# Build Fan Daemon
echo "[Unit]" > $deskpidaemon
echo "Description=DeskPi PWM Control Fan Service" >> $deskpidaemon
echo "After=multi-user.target" >> $deskpidaemon
echo "[Service]" >> $deskpidaemon
echo "Type=oneshot" >> $deskpidaemon
echo "RemainAfterExit=true" >> $deskpidaemon
echo "ExecStart=sudo /usr/bin/pwmFanControl &" >> $deskpidaemon
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
echo "ExecStart=/usr/bin/sudo /usr/bin/fanStop" >> $safeshutdaemon
echo "RemainAfterExit=yes" >> $safeshutdaemon
echo "[Install]" >> $safeshutdaemon
echo "WantedBy=halt.target shutdown.target poweroff.target" >> $safeshutdaemon

log_action_msg "DeskPi Service configuration finished." 
sudo chown root:root $safeshutdaemon
sudo chmod 755 $safeshutdaemon

sudo chown root:root $deskpidaemon
sudo chmod 755 $deskpidaemon

log_action_msg "DeskPi Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable $daemonname.service
sudo systemctl start $daemonname.service &
sudo systemctl enable $daemonname-safeshut.service

# Finished 
log_success_msg "DeskPi PWM Fan Control and Safeshut Service installed successfully." 
# greetings and require rebooting system to take effect.
log_action_msg "System will reboot in 5 seconds to take effect." 
sudo sync
sleep 5 
# sudo reboot
echo "Reboot system for changes to take effect"
