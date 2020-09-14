#!/bin/bash
# 
. /lib/lsb/init-functions

daemonname="deskpi"
tempmonscript=/usr/bin/pmwFanControl
deskpidaemon=/lib/systemd/system/$daemonname.service
stopfandaemon=/lib/systemd/system-shutdown/fanStop.sh
installationfolder=/home/pi/deskpi

# install wiringPi library.
log_action_msg "DeskPi Fan control script installation Start..." 
# sudo apt -y purge wiringpi && hash -r 
# cd $installationfolder
# sudo dpkg -i wiringpi-latest.deb

# Create service file on system.
if [ -e $deskpidaemon ]; then
	sudo rm -f $deskpidaemon
fi

# sudo touch $stopfandaemon 
# sudo chmod 666 $stopfandaemon

# install PWM fan control daemon.
cd $installationfolder/drivers/c/ 
sudo cp -rf $installationfolder/drivers/c/pwmFanControl /usr/bin/pwmFanControl
sudo cp -rf $installationfolder/drivers/c/fanStop  /usr/bin/fanStop
sudo chmod 755 /usr/bin/pwmFanControl
sudo chmod 755 /usr/bin/fanStop

# Build Fan Daemon
echo "[Unit]" > $deskpidaemon
echo "Description=DeskPi Fan Service" >> $deskpidaemon
echo "After=multi-user.target" >> $deskpidaemon
echo "[Service]" >> $deskpidaemon
echo "Type=oneshot" >> $deskpidaemon
echo "RemainAfterExit=true" >> $deskpidaemon
echo "ExecStart=sudo /usr/bin/pwmFanControl &" >> $deskpidaemon
echo "[Install]" >> $deskpidaemon
echo "WantedBy=multi-user.target" >> $deskpidaemon

# send signal to MCU before system shuting down.
echo "#!/bin/bash" > $stopfandaemon
echo ". /lib/lsb/init-functions" >> $stopfandaemon
echo "log_begin_msg \"Initializing shutdown sequences...\"" >> $stopfandaemon
echo "log_success_msg \"Shutting down deskpi.service\"" >> $stopfandaemon
echo "sudo sync" >> $stopfandaemon
echo "sudo /usr/bin/fanStop" >> $stopfandaemon
echo "sudo init 0" >> $stopfandaemon

sudo chown root:root $stopfandaemon
sudo chmod 755 $stopfandaemon

sudo chown root:root $deskpidaemon
sudo chown root:root $stopfandaemon
sudo chmod 755 $deskpidaemon
sudo chmod 755 $stopfandaemon
sudo systemctl enable $daemonname.service
sudo systemctl start $daemonname.service &

# Finished 
log_success_msg "DeskPi Fan control service installation is finished." 
