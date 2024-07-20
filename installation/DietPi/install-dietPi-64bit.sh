#!/bin/bash
# Fit for raspiOS-arm-64bit-lite-buster

# initializing functions
if [ -e /lib/lsb/init-functions ]; then
  . /lib/lsb/init-functions
  log_action_msg "Initializing functions..."
fi


# remove old daemon file
if [[ -f $fanDaemon ]]; then
  systemctl stop deskpi.service
  systemctl disable deskpi.service
  rm -f $fanDaemon
fi

if [[ -f $pwrCutOffDaemon ]]; then
  
  systemctl disable deskpi-cut-off-power.service
  rm -f $pwrCutOffDaemon
fi

# install git tool
pkgStatus=`dpkg-query -l git |grep git | awk '{print $1}'`
if [ $pkgStatus != 'ii' ]; then
  apt-get update
  apt-get -y install git-core 
fi

# check if dwc2 dtoverlay has been enabled.
checkResult=`grep dwc2 /boot/config.txt`
if [ $? -ne 0 ];  then
  log_warning_msg "Adding dtoverlay=dwc2,dr_mode=host to /boot/config.txt file."
  sed -i '/dtoverlay=dwc2*/d' /boot/config.txt
  sed -i '$a\dtoverlay=dwc2,dr_mode=host' /boot/config.txt
  log_action_msg "check dwc2 overlay will be enabled after rebooting."
fi

# Define systemd service name
fanDaemon="/etc/systemd/system/deskpi.service"
pwrCutOffDaemon="/etc/systemd/system/deskpi-cut-off-power.service"

# copy pre-compiled binary file to /usr/bin/ folder
cd /tmp/
git clone https://github.com/deskpi-team/deskpi.git 
if [ -d /tmp/deskpi/ ]; then
        cp -Rvf /tmp/deskpi/installation/drivers/c/pwmFanControl64 /usr/bin/pwmFanControl64
        cp -Rvf /tmp/deskpi/installation/drivers/c/safeCutOffPower64 /usr/bin/safeCutOffPower64
        cp -Rvf /tmp/deskpi/installation/deskpi-config  /usr/bin/deskpi-config
        chmod +x /usr/bin/pwmFanControl64
        chmod +x /usr/bin/safeCutOffPower64
        chmod +x /usr/bin/deskpi-config
fi

# genreate systemd service file
if [ ! -e $fanDaemon ]; then
echo "[Unit]" >> $fanDaemon
echo "Description=DeskPi Fan Control Service" >> $fanDaemon
echo "After=multi-user.target" >> $fanDaemon
echo "[Service]" >> $fanDaemon
echo "Type=simple" >> $fanDaemon
echo "RemainAfterExit=true" >> $fanDaemon
echo "ExecStart=/usr/bin/pwmFanControl64 &" >> $fanDaemon
echo "[Install]" >> $fanDaemon
echo "WantedBy=multi-user.target" >> $fanDaemon
fi

# send signal to MCU before system shutting down.
if [ ! -e $pwrCutOffDaemon ]; then
  echo "[Unit]" >> $pwrCutOffDaemon
  echo "Description=DeskPi-cut-off-power service" >> $pwrCutOffDaemon
  echo "Conflicts=reboot.target" >> $pwrCutOffDaemon
  echo "Before=halt.target shutdown.target poweroff.target" >> $pwrCutOffDaemon
  echo "DefaultDependencies=no" >> $pwrCutOffDaemon
  echo "[Service]" >> $pwrCutOffDaemon
  echo "Type=oneshot" >> $pwrCutOffDaemon
  echo "ExecStart= /usr/bin/safeCutOffPower64" >> $pwrCutOffDaemon
  echo "RemainAfterExit=yes" >> $pwrCutOffDaemon
  echo "[Install]" >> $pwrCutOffDaemon
  echo "WantedBy=halt.target shutdown.target poweroff.target" >> $pwrCutOffDaemon
fi

# grant privilleges to root user.
if [ -e $fanDaemon ]; then
  chown root:root $fanDaemon
  chmod 755 $fanDaemon
  log_action_msg "Load DeskPi service and load modules"
  systemctl daemon-reload
  systemctl enable deskpi.service
  systemctl start deskpi.service &
fi

if [ -e $pwrCutOffDaemon ]; then
  chown root:root $pwrCutOffDaemon
  chmod 755 $pwrCutOffDaemon
  systemctl enable deskpi-cut-off-power.service
fi


# Greetings
if [ $? -eq 0 ]; then
  log_action_msg "Congratulations! DeskPi Pro driver has been installed successfully, Have Fun!"
  log_action_msg "System will be reboot in 5 seconds to take effect."
else
  log_action_warning "Could not download deskpi repository, please check the internet connection and try to execute it again. "
  log_action_msg "Usage: sudo ./install-raspios-64bit.sh"
fi

# sync && sleep 5 &&  reboot
