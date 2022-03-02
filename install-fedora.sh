#!/bin/bash
# 

function pre-reqs() {
    sudo dnf install git redhat-lsb-core glibc-devel.aarch64 glibc-headers-s390.noarch glibc-headers-x86.noarch glibc-common.aarch64 glibc-static gcc make -y
}

if [[ ! -f /lib/lsb/init-functions ]]; then
    pre-reqs
fi

. /lib/lsb/init-functions
cd ~
sh -c "git clone https://github.com/DeskPi-Team/deskpi.git"
cd $HOME/deskpi/
daemonname="deskpi"
tempmonscript=/usr/bin/pmwFanControl
deskpidaemon=/lib/systemd/system/$daemonname.service
safeshutdaemon=/lib/systemd/system/$daemonname-safeshut.service
installationfolder=$HOME/$daemonname

# install wiringPi library.
echo "DeskPi Fan control script installation Start." 

# Create service file on system.
if [ -e $deskpidaemon ]; then
	sudo rm -f $deskpidaemon
fi

# adding dtoverlay to enable dwc2 on host mode.
echo "Enable dwc2 on Host Mode"
sudo sed -i '/dtoverlay=dwc2*/d' /boot/efi/config.txt
sudo sed -i '$a\dtoverlay=dwc2,dr_mode=host' /boot/efi/config.txt 
if [ $? -eq 0 ]; then
   log_success_msg "dwc2 has been setting up successfully"
fi

# install PWM fan control daemon.
echo "DeskPi main control service loaded."
cd $installationfolder/drivers/c/
make clean
make
sudo cp -rf $installationfolder/drivers/c/pwmControlFan /usr/bin/
sudo cp -rf $installationfolder/drivers/c/fanStop  /usr/bin/
sudo chmod 755 /usr/bin/pwmControlFan
sudo chcon -u system_u -t bin_t /usr/bin/pwmControlFan
sudo chmod 755 /usr/bin/fanStop
sudo chcon -u system_u -t bin_t /usr/bin/fanStop
sudo cp -rf $installationfolder/deskpi-config /usr/bin/
sudo cp -rf $installationfolder/Deskpi-uninstall /usr/bin/
sudo chmod 755 /usr/bin/deskpi-config
sudo chcon -u system_u -t bin_t /usr/bin/deskpi-config
sudo chmod 755 /usr/bin/Deskpi-uninstall
sudo chcon -u system_u -t bin_t /usr/bin/Deskpi-uninstall
sudo restorecon -vr /usr/bin/

# Build Fan Daemon
echo "[Unit]" > $deskpidaemon
echo "Description=DeskPi PWM Control Fan Service" >> $deskpidaemon
echo "After=multi-user.target" >> $deskpidaemon
echo "[Service]" >> $deskpidaemon
echo "Type=simple" >> $deskpidaemon
echo "RemainAfterExit=no" >> $deskpidaemon
echo "ExecStart=/usr/bin/pwmControlFan" >> $deskpidaemon
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
echo "ExecStart=/usr/bin/fanStop" >> $safeshutdaemon
echo "RemainAfterExit=yes" >> $safeshutdaemon
echo "TimeoutSec=1" >> $safeshutdaemon
echo "[Install]" >> $safeshutdaemon
echo "WantedBy=halt.target shutdown.target poweroff.target" >> $safeshutdaemon

echo "DeskPi Service configuration finished." 
sudo chown root:root $safeshutdaemon
sudo chmod 644 $safeshutdaemon
chcon -u system_u -t systemd_unit_file_t $safeshutdaemon

sudo chown root:root $deskpidaemon
sudo chmod 644 $deskpidaemon
chcon -u system_u -t systemd_unit_file_t $deskpidaemon
restorecon -vr /lib/systemd/system/

echo "DeskPi Service Load module." 
sudo systemctl daemon-reload
sudo systemctl enable $daemonname.service
sudo systemctl start $daemonname.service &
sudo systemctl enable $daemonname-safeshut.service

# Finished 
log_success_msg "DeskPi PWM Fan Control and Safeshut Service installed successfully." 
# greetings and require rebooting system to take effect.
echo "System will reboot in 5 seconds to take effect." 
sudo sync
sleep 5 
sudo reboot
