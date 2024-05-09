#!/bin/bash
# Function: install driver for DeskPi Pro
# Work flow:
# 1. Enable front USB port by adding parameter to /boot/firmware/config.txt
# 2. create deskpi.service systemd file 
# 3. create deskpi-cutoffpower.service systemd file
# 4. Grant permissions to systemd file 
# 5. Enable systemd service 
# 6. Copy pre-compiled binary file to /usr/bin/deskpi/ folder 
# 7. copy deskpi-config shell script file to /usr/bin/deskpi/ folder
# 8. Bind USB device under a static name: from /dev/ttyUSB0 to /dev/DeskPi_FAN
# 9. Greetings to everybody.
# 10. Reboot Raspberry Pi and take effect. 

# Define systemd service name
deskpi_service_file="/etc/systemd/system/deskpi.service"
deskpi_powermanager_file="/etc/systemd/system/deskpi-cutoffpower.service"


# Initializing message functions
if [[ -e /lib/lsb/init-functions ]]; then
  . /lib/lsb/init-functions
  log_action_msg "Initializing functions..."
fi

# Install figlet display information 
sudo sh -c "sudo apt update"
sudo sh -c "sudo apt -y install figlet"
sudo sh -c "echo 'DESKPI PRO INSTALLATION' | figlet -c"
sleep 3
sudo sh -c "echo 'STARTING...' | figlet -c"

# OS information detection 
OS_version=`lsb_release -a|grep -i codename |awk '{print $2}'`
if [[ $OS_version != 'bookworm' ]]; then
	log_action_msg "Current OS is not fit for this script, please download Raspberry Pi OS 64bit bookworm and try again, or use other installation scripts!"
fi

# Bind USB device under static name from /dev/ttyUSB0 to /dev/DeskPi_FAN 
idVendor=`lsusb |grep -i QinHeng|awk -F: '{print $2}' |awk '{print $NF}'`
idProduct=`lsusb |grep -i QinHeng|awk -F: '{print $3}' |awk '{print $1}'`

deskpi_rules_file="/etc/udev/rules.d/10-deskpi.rules"

if [[ ! -e $deskpi_rules_file ]]; then
  sudo sh -c "sudo cat <<EOF > '$deskpi_rules_file'
  ACTION==\"add\", ATTRS{\"$idVendor\"},ATTRS{\"$idProduct\"},SYMLINK+=\"DeskPi_FAN\"
  EOF"
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
fi

# Install git tool
pkgStatus=`sudo dpkg-query -l git |grep git | awk '{print $1}'`
if [[ $pkgStatus != 'ii' ]]; then
  sudo sh -c "sudo apt-get update"
  sudo sh -c "sudo apt-get -y install git-core"
  
fi

# Check if dwc2 dtoverlay has been enabled.
checkResult=`grep dwc2 /boot/firmware/config.txt`
if [[ $? -ne 0 ]];  then
  log_action_msg "Adding dtoverlay=dwc2,dr_mode=host to /boot/firmware/config.txt file."
  sudo sh -c "sudo sed -i '/dtoverlay=dwc2*/d' /boot/firmware/config.txt"
  sudo sh -c "sudo sed -i '\$a\dtoverlay=dwc2,dr_mode=host' /boot/firmware/config.txt"
  log_action_msg "check dwc2 overlay will be enabled after rebooting."
fi

# Download deskpi driver
cd /tmp/
if [[ ! -d /tmp/deskpi ]]; then  
   while [[ ! -d /tmp/deskpi ]]; 
   do
  	log_warning_msg "Could not able to download deskpi repo,will retry again."
	sh -c "git clone -b feature/bookworm https://github.com/DeskPi-Team/deskpi.git"
   done
fi


# copy pre-compiled binary file to /usr/bin/ folder
#
if [[ -d /tmp/deskpi ]]; then
  sudo sh -c "sudo mkdir -pv /usr/bin/deskpi/"
  if [[ -e /tmp/deskpi/installation/drivers/c/pwmControlFan64 ]]; then
  sudo sh -c "sudo cp -Rvf /tmp/deskpi/installation/drivers/c/pwmControlFan64 /usr/bin/deskpi/pwmControlFan64 && echo 'Copy ok'" 
  sudo sh -c "sudo cp -Rvf /tmp/deskpi/installation/drivers/c/safeCutOffPower64 /usr/bin/deskpi/safeCutOffPower64 && echo 'Copy ok'"
  fi 

  sudo sh -c "sudo cp -Rvf /tmp/deskpi/installation/deskpi-config  /usr/bin/deskpi-config"
  sudo sh -c "sudo chmod +x /usr/bin/deskpi/pwmControlFan64"
  sudo sh -c "sudo chmod +x /usr/bin/deskpi/safeCutOffPower64"
  sudo sh -c "sudo chmod +x /usr/bin/deskpi-config"
fi

# Genreate systemd service file
if [[ ! -e $deskpi_service_file ]]; then
sudo sh -c "sudo cat <<EOF > '$deskpi_service_file'
[Unit]
Description=DeskPi Fan Control Service
After=multi-user.target
[Service]
Type=simple
RemainAfterExit=true
ExecStart=/usr/bin/sudo /usr/bin/deskpi/pwmControlFan64 
[Install]
WantedBy=multi-user.target

EOF"

fi

# Send signal to MCU before system shutting down.
if [[ ! -e $deskpi_powermanager_file ]]; then
   sudo sh -c "sudo cat <<EOF > '$deskpi_powermanager_file'
[Unit]
Description=DeskPi cutoffpower service
Conflicts=reboot.target
Before=halt.target shutdown.target poweroff.target
DefaultDependencies=no
[Service]
Type=oneshot
ExecStart=/usr/bin/sudo /usr/bin/deskpi/safeCutOffPower64
RemainAfterExit=yes
[Install]
WantedBy=halt.target shutdown.target poweroff.target

EOF"

fi

# Grant privilleges to root user.
if [[ -e $deskpi_service_file ]]; then
  sudo sh -c "sudo chown root:root $deskpi_service_file"
  sudo sh -c "sudo chmod 755 $deskpi_service_file"
  log_action_msg "Load DeskPi service and load modules"
  sudo sh -c "sudo systemctl daemon-reload"
  sudo sh -c "sudo systemctl enable deskpi.service"
  sudo sh -c "sudo systemctl start deskpi.service"
fi

if [[ -e $deskpi_powermanager_file ]]; then 
  sudo sh -c "sudo chown root:root $deskpi_powermanager_file"
  sudo sh -c "sudo chmod 755 $deskpi_powermanager_file"
  sudo sh -c "sudo systemctl daemon-reload"
  sudo sh -c "sudo systemctl enable deskpi-cutoffpower.service" 
fi


# Greetings
if [[ $? -eq 0 ]]; then
  log_success_msg "Congratulations! DeskPi Pro driver has been installed successfully, Have Fun!"
  log_success_msg "System will be reboot in 5 seconds to take effect."
else
  log_success_warning "Could not download deskpi repository, please check the internet connection and try to execute it again!"
  log_success_msg "Usage: ./install.sh"
fi
echo "DESKPI PRO" |figlet -c 
echo "INSTALLATION SUCCESSFULL!" | figlet -c
echo "REBOOT IN 5 SECONDS" | figlet -c
sudo sh -c "sudo sync && sleep 5 && sudo reboot"
