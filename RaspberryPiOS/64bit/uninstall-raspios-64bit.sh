
#!/bin/bash
# uninstall Fit for raspiOS-arm-64bit-lite-buster

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

if [ -f $fanDaemon ]; then
  sudo systemctl stop deskpi.service
  sudo systemctl disable deskpi.service
  rm -f $fanDaemon
fi

if [ -f $pwrCutOffDaemon ]; then
  sudo systemctl disable deskpi-cut-off-power.service
  rm -f $pwrCutOffDaemon
fi

if [ -e $pwrCutOffDaemon ]; then
  systemctl disable deskpi-cut-off-power.service
fi

# delete pwmfancontrol64 and safecutoffpower64 execute binary file.
if [ -e /usr/bin/pwmFanControl64 ]; then
        rm -f /usr/bin/pwmFanControl64
        rm -f /usr/bin/safecutoffpower64
fi

# Greetings
if [ $? -eq 0 ]; then
  log_action_msg "Congratulations! DeskPi Pro driver has been uninstalled successfully!"
  log_action_msg "System will be reboot in 5 seconds to take effect."
fi

sync && sleep 5 &&  reboot
