#!/bin/bash
# uninstall deskpi script 
daemonname="deskpi"
deskpidaemon=/lib/systemd/system/$daemonname.service
stopfandaemon=/lib/systemd/system-shutdown/fanStop.service

echo "Uninstalling deskpi fan scipt..."
sleep 1
sudo systemctl disable $daemonname.service 2&>/dev/null  
sudo systemctl stop $daemonname.service  2&>/dev/null
sudo systemctl disable $stopfandaemon.service 2&>/dev/null
sudo systemctl stop $stopfandaemon.service 2&>/dev/null
sudo rm -f  $deskpidaemon  2&>/dev/null || echo "remove $deskdaemon"
sudo rm -f  $stopfandaemon 2&>/dev/null || echo "remove $stopfandaemon"
sudo rm -f /usr/bin/fanStop 2&>/dev/null
sudo rm -f /usr/bin/pwmFanControl 2&>/dev/null 
echo "Uninstalling deskpi is finished, have a nice day" 
