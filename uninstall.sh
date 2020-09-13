#!/bin/bash
# uninstall deskpi script 
daemonname="deskpi"
deskpidaemon=/lib/systemd/system/$daemonname.service
stopfandaemon=/lib/systemd/system-shutdown/$daemonname-shutdown.service

echo "Uninstalling deskpi fan scipt..."
sleep 1
sudo systemctl disable $daemonname.service
sudo systemctl stop $daemonname.service
sudo systemctl disable $stopfandaemon.service
sudo systemctl stop $stopfandaemon.service
sudo rm -f  $stopfandaemon
sudo rm -f  $stopfandaemon
sudo rm -f /usr/bin/fanStop
sudo rm -f /usr/bin/pwmFanControl
echo "Uninstalling deskpi is finished, have a nice day" 


