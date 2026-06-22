#!/bin/bash
# Fit for ubuntu 64bit

# initializing functions
# if [ -e /lib/lsb/init-functions ]; then
#   . /lib/lsb/init-functions
#   echo  "Initializing functions..."
# fi


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

# check if dwc2 dtoverlay has been enabled in the GLOBAL section.
# IMPORTANT: The overlay MUST be in the global section (before any [xxx]
# conditional header). Some firmware revisions silently skip overlays placed
# under conditional filters, leaving the DeskPi Pro internal CH340 invisible.
CONFIG_TXT=/boot/firmware/config.txt
if ! awk '
    BEGIN { in_header = 0 }
    /^\[/ { in_header = 1 }
    !in_header && /^dtoverlay=dwc2/ { found = 1 }
    END { exit !found }
' "$CONFIG_TXT" 2>/dev/null; then
  echo "Adding dtoverlay=dwc2,dr_mode=host to GLOBAL section of $CONFIG_TXT."
  cp "$CONFIG_TXT" "$CONFIG_TXT.bak.$(date +%F-%H-%M-%S)" 2>/dev/null || sudo cp "$CONFIG_TXT" "$CONFIG_TXT.bak.$(date +%F-%H-%M-%S)"
  sudo sed -i '/^dtoverlay=dwc2/d' "$CONFIG_TXT"
  if sudo grep -q '^\[' "$CONFIG_TXT"; then
    sudo awk -v line='dtoverlay=dwc2,dr_mode=host' '
        BEGIN { inserted = 0 }
        !inserted && /^\[/ { print line; inserted = 1 }
        { print }
    ' "$CONFIG_TXT" | sudo tee "$CONFIG_TXT.tmp" >/dev/null && sudo mv "$CONFIG_TXT.tmp" "$CONFIG_TXT"
  else
    sudo sed -i '1i\dtoverlay=dwc2,dr_mode=host' "$CONFIG_TXT"
  fi
  echo "dwc2 overlay will be enabled after rebooting."
fi

# Define systemd service name
fanDaemon="/etc/systemd/system/deskpi.service"
pwrCutOffDaemon="/etc/systemd/system/deskpi-cut-off-power.service"

# copy pre-compiled binary file to /usr/bin/ folder
cd /tmp && git clone https://github.com/deskpi-team/deskpi.git || echo "please check your connection or download repository manually, download the repository to /tmp folder."
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
  echo "Load DeskPi service and load modules"
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
  echo "Congratulations! DeskPi Pro driver has been installed successfully, Have Fun!"
  echo  "System will be reboot in 5 seconds to take effect."
else
  echo "Could not download deskpi repository, please check the internet connection and try to execute it again. "
  echo  "Usage: sudo ./install-ubuntu-64.sh"
fi

sync && sleep 5 &&  reboot

