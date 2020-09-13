#!/bin/bash
# 
daemonname="deskpi"
tempmonscript=/usr/bin/pmwFanControl
deskpidaemon=/lib/systemd/system/$daemonname.service
stopfandaemon=/lib/systemd/system-shutdown/$daemonname-shutdown.service
installationfolder=/home/pi/deskpi

# install wiringPi library.
sudo apt -y purge wiringpi && hash -r 
cd /tmp
wget https://project-downloads.drogon.net/wiringpi-latest.deb
sudo dpkg -i wiringpi-latest.deb

# Create service file on system.
if [ -e $deskpidaemon ]; then
	sudo rm -f $deskpidaemon
fi

sudo touch $stopfandaemon 
sudo chmod 666 $stopfandaemon

# install PWM fan control daemon.
cd $installationfolder/drivers/c/ && make
sudo cp -rf $installationfolder/drivers/c/pwmFanControl /usr/bin/pwmFanControl
sudo cp -rf $installationfolder/drivers/c/fanStop  /usr/bin/fanStop
sudo chmod 755 /usr/bin/pwmFanControl
sudo chmod 755 /usr/bin/fanStop

# Build Fan Daemon
echo "[Unit]" >> $deskpidaemon
echo "Description=DeskPi Fan Service" >> $deskpidaemon
echo "After=multi-user.target" >> $deskpidaemon
echo "" >> $daemonfanservic 
echo "[Service]" >> $deskpidaemon
echo "Type=forking" >> $deskpidaemon
echo "Restart=always" >> $deskpidaemon
echo "RemainAfterExit=true" >> $deskpidaemon
echo "ExecStart=/usr/bin/pwmFanControl &" >> $deskpidaemon
echo "" >> $daemonfanservic 
echo "[Install]" >> $deskpidaemon
echo "WantedBy=multi-user.target" >> $deskpidaemon

# Make it works
sudo chmod 644 $deskpidaemon
sudo systemctl enable $daemonname.service
sudo systemctl start $daemonname.service

# send signal to MCU before system shuting down.

echo "[Unit]" >> $stopfandaemon
echo "Description=Send shutdown signal to MCU at shutdown only" >> $stopfandaemon
echo "DefaultDependencies=no" >> $stopfandaemon
echo "Conflicts=reboot.target" >> $stopfandaemon
echo "Before=poweroff.target halt.target shutdown.target" >> $stopfandaemon
echo "Requires=poweroff.target" >> $stopfandaemon
echo "" >> $stopfandaemon
echo "[Service]" >> $stopfandaemon
echo "Type=oneshot" $stopfandaemon
echo "ExecStart=/usr/bin/fanStop &" >> $stopfandaemon
echo "RemainAfterExit=yes" >> $stopfandaemon
echo "" >> $stopfandaemon
echo "[Install]" >> $stopfandaemon
echo "WantedBy=shutdown.target" >> $stopfandaemon

# Make it works 
sudo chmod 644 $stopfandaemon
sudo systemctl enable $stopfandaemon
sudo systemctl start  $stopfandaemon

# Finished 
echo -e "DeskPi Fan control script installation finished." 
