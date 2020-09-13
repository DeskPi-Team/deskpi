#!/bin/bash
# 
daemonname="deskpid"
tempmonscript=/usr/bin/pmwfancontrol
daemonfanservice=/lib/systemd/system/$daemonname.service
fanshutdownservice=/lib/systemd/system-shutdown/$daemonname-shutdown.service
installationfolder=/home/pi/deskpi

# Create service file on system.
sudo touch $fanshutdownservice 
sudo chmod 666 $fanshutdownservice

# install PWM fan control daemon.
cd $installationfolder/drivers/c/
make
sudo cp -rf $installationfolder/drivers/c/pwmFanControl /usr/bin/pwmFanControl
sudo cp -rf $installationfolder/drivers/c/fanStop  /usr/bin/fanStop
sudo chmod 666 /usr/bin/pwmFanControl
sudo chmod 666 /usr/bin/fanStop

# Build Fan Daemon
echo "[Unit]" >> $daemonfanservice
echo "Description=DeskPi Fan Service" >> $daemonfanservice
echo "After=multi-user.target" >> $daemonfanservice
echo '[Service]' >> $daemonfanservice
echo 'Type=simple' >> $daemonfanservice
echo "Restart=always" >> $daemonfanservice
echo "RemainAfterExit=true" >> $daemonfanservice
echo "ExecStart=/usr/bin/pwmFanControl &" >> $daemonfanservice
echo '[Install]' >> $daemonfanservice
echo "WantedBy=multi-user.target" >> $daemonfanservice

# Make it works
sudo chmod 644 $daemonfanservice
sudo systemctl enable $daemonname.service
sudo systemctl start $daemonname.service

# send signal to MCU before system shuting down.

echo "[Unit] >> $fanshutdownservice
echo "Description=Send shutdown signal to MCU at shutdown only" >> $fanshutdownservice
echo "DefaultDependencies=no" >> $fanshutdownservice
echo "Conflicts=reboot.target" >> $fanshutdownservice
echo "Before=poweroff.target halt.target shutdown.target" >> $fanshutdownservice
echo "Requires=poweroff.target" >> $fanshutdownservice
echo "" >> $fanshutdownservice
echo "[Service]" >> $fanshutdownservice
echo "Type=oneshot" $fanshutdownservice
echo "ExecStart=/usr/bin/fanStop &" >> $fanshutdownservice
echo "RemainAfterExit=yes" >> $fanshutdownservice
echo "" >> $fanshutdownservice
echo "[Install]" >> $fanshutdownservice
echo "WantedBy=shutdown.target" >> $fanshutdownservice

# Make it works 
sudo chmod 644 $fanshutdownservice
sudo systemctl enable $fanshutdownservice
sudo systemctl start  $fanshutdownservice

# Finished 
echo -e "\[32;40mDeskPi Fan control script installation finished.\[0m" 
