
#!/bin/bash
# uninstall Fit for raspiOS-arm-64bit-lite-buster

# Define systemd service name
fanDaemon="/etc/systemd/system/deskpi.service"
pwrCutOffDaemon="/etc/systemd/system/deskpi-cut-off-power.service"

# remove old repository.
if [ -d /tmp/deskpi ]; then
  rm -rf /tmp/deskpi*
fi

if [ -f $fanDaemon ]; then
  systemctl stop deskpi.service
  systemctl disable deskpi.service
  rm -f $fanDaemon
fi

if [ -f $pwrCutOffDaemon ]; then
  systemctl disable deskpi-cut-off-power.service
  rm -f $pwrCutOffDaemon
fi

# delete pwmfancontrol64 and safecutoffpower64 execute binary file.
if [ -e /usr/bin/pwmFanControl64 ]; then
        rm -f /usr/bin/pwmFanControl64
        rm -f /usr/bin/safeCutOffPower64
fi

# Greetings
if [ $? -eq 0 ]; then
  echo  "Congratulations! DeskPi Pro driver has been uninstalled successfully!"
  echo  "System will be reboot in 5 seconds to take effect."
fi

sync && sleep 5 &&  reboot
