#!/bin/bash
# Fit for raspiOS-arm-64bit-lite-buster

# Define systemd service name
fanDaemon="/lib/systemd/system/deskpi.service"
pwrCutOffDaemon="/lib/systemd/system/deskpi-cut-off-power.service"

# initializing functions
if [ -e /lib/lsb/init-functions ]; then
  . /lib/lsb/init-functions
  log_action_msg "Initializing functions..."
fi


# remove old repository.
if [ -d /tmp/deskpi ]; then
  rm -rf /tmp/deskpi*
fi

if [[ -f $fanDaemon ]]; then
  sudo sh -c "sudo systemctl stop deskpi.service"
  sudo sh -c "sudo systemctl disable deskpi.service"
  sudo sh -c "rm -f $fanDaemon"
fi

if [[ -f $pwrCutOffDaemon ]]; then
  
  sudo sh -c "sudo systemctl disable deskpi-cut-off-power.service"
  sudo sh -c "sudo rm -f $pwrCutOffDaemon"
fi

# install git tool
pkgStatus=`dpkg-query -l git |grep git | awk '{print $1}'`
if [ $pkgStatus != 'ii' ]; then
  sudo sh -c "sudo apt-get update"
  sudo sh -c "sudo apt-get -y install git-core"
fi

# check if dwc2 dtoverlay has been enabled.
checkResult=`grep dwc2 /boot/config.txt`
if [ $? -ne 0 ];  then
  log_warning_msg "Adding dtoverlay=dwc2,dr_mode=host to /boot/config.txt file."
  sudo sh -c "sudo sed -i '/dtoverlay=dwc2*/d' /boot/firmware/config.txt
         sed -i '$a\dtoverlay=dwc2,dr_mode=host' /boot/firmware/config.txt
        log_action_msg "check dwc2 overlay will be enabled after rebooting."
fi
# download deskpi driver
cd /tmp/
sh -c "git clone https://github.com/DeskPi-Team/deskpi.git"
if [ -d /tmp/deskpi ]; then
  cd /tmp/deskpi/
else
  log_warning_msg "Could not able to download deskpi repo,please check the network and try again."
fi

# Define systemd service name
fanDaemon="/lib/systemd/system/deskpi.service"
pwrCutOffDaemon="/lib/systemd/system/deskpi-cut-off-power.service"

# copy pre-compiled binary file to /usr/bin/ folder
if [ -d /tmp/deskpi/ ]; then
        cp -Rvf /tmp/deskpi/drivers/c/pwmFanControl64 /usr/bin/pwmFanControl64
        cp -Rvf /tmp/deskpi/drivers/c/safecutoffpower64 /usr/bin/safecutoffpower64
        cp -Rvf /tmp/deskpi/deskpi-config  /usr/bin/deskpi-config
        chmod +x /usr/bin/pwmFanControl64
        chmod +x /usr/bin/safecutoffpower64
        chmod +x /usr/bin/deskpi-config
fi

# genreate systemd service file
if [ ! -e $fanDaemon ]; then
echo "[Unit]" >> $fanDaemon
echo "Description=DeskPi Fan Control Service" >> $fanDaemon
echo "After=multi-user.target" >> $fanDaemon
echo "[Service]" >> $fanDaemon
echo "Type=oneshot" >> $fanDaemon
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
  echo "ExecStart= /usr/bin/safecutoffpower64" >> $pwrCutOffDaemon
  echo "RemainAfterExit=yes" >> $pwrCutOffDaemon
  echo "[Install]" >> $pwrCutOffDaemon
  echo "WantedBy=halt.target shutdown.target poweroff.target" >> $pwrCutOffDaemon
fi

# grant privilleges to root user.
if [ -e $fanDaemon ]; then
  chown root:root $fanDaemon
  chmod 755 $fanDaemon
  log_action_msg "Load DeskPi service and load modules"
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
  log_action_warning "Could not download deskpi repository, please check the internet connection and try to execute it again!"
  log_action_msg "Usage: sudo ./install-raspios-64bit.sh"
fi

sync && sleep 5 &&  reboot
