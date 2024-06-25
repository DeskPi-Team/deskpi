#!/bin/bash
# Function: uninstall driver for DeskPi Pro

# Define systemd service name
deskpi_service_file="/etc/systemd/system/deskpi.service"
deskpi_powermanager_file="/etc/systemd/system/deskpi-cutoffpower.service"


# Initializing message functions
if [[ -e /lib/lsb/init-functions ]]; then
  . /lib/lsb/init-functions
  log_action_msg "Initializing functions..."
fi

# warning message 
echo "DESKPI PRO UNINSTALLATION" | figlet -c 
echo "BEGIN IN 3 seconds" | figlet -c 
sleep 1
for i in `seq 1 3|sort -rn`
do 
	echo "$i " | figlet -c 
	sleep 1
done 


# Remove udev rules of deskpi
deskpi_rules_file="/etc/udev/rules.d/10-deskpi.rules"

if [[ -e $deskpi_rules_file ]]; then
  sudo sh -c "sudo rm -f $deskpi_rules_file"
  sudo sh -c "sudo udevadm control --reload-rules"
  sudo sh -c "sudo udevadm trigger"
fi

# Remove old repository.
if [[ -d /tmp/deskpi ]]; then
  rm -rf /tmp/deskpi*
fi


if [[ -f $deskpi_service_file ]]; then
  sudo sh -c "sudo systemctl stop deskpi.service"
  sudo sh -c "sudo systemctl disable deskpi.service"
  sudo sh -c "sudo rm -f $deskpi_service_file"
  sudo sh -c "sudo systemctl daemon-reload"
fi

if [[ -f $deskpi_powermanager_file ]]; then
  sudo sh -c "sudo systemctl disable deskpi-cutoffpower.service"
  sudo sh -c "sudo rm -f $deskpi_powermanager_file"
  sudo sh -c "sudo systemctl daemon-reload"
fi

# Check if dwc2 dtoverlay has been enabled.
checkResult=`grep dwc2 /boot/firmware/config.txt`
if [[ $? -ne 0 ]];  then
  log_warning_msg "Find dtoverlay=dwc2,dr_mode=host in /boot/firmware/config.txt file."
  sudo sh -c "sudo sed -i '/dtoverlay=dwc2*/d' /boot/firmware/config.txt"
  log_action_msg "Remove dtoverlay parameter from /boot/firmware/config.txt file."
fi

# Remove /usr/bin/deskpi folder and /usr/bin/deskpi-config file
if [[ -d /usr/bin/deskpi/ ]]; then
  sudo sh -c "sudo rm -rf /usr/bin/deskpi"
  sudo sh -c "sudo rm -f /usr/bin/deskpi-config"
  log_success_msg "/usr/bin/deskpi folder has been removed!"
  log_success_msg "/usr/bin/deskpi-config file has been removed!"
fi

# Greetings
if [[ $? -eq 0 ]]; then
  log_success_msg "System will be reboot in 5 seconds to take effect."
fi
echo "COUNTING DOWN TO REBOOT" | figlet -c
sleep 1
for i in `seq 1 5|sort -rn`
do 
	echo "$i" | figlet -c
	sleep 1
	clear
done 
echo "DeskPi Pro!" | figlet -c
echo "FAREWELL!" | figlet -c
sudo sh -c "sudo sync && sleep 1 && sudo reboot"
