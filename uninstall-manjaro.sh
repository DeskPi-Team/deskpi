#!/bin/bash

echo "================ DeskPi driver uninstallation ================"

echo ""

echo "---------------- DeskPi service configuration ----------------"
sudo systemctl stop deskpiFanStop
sudo systemctl stop deskpiFanControl
sudo systemctl disable deskpiFanStop
sudo systemctl disable deskpiFanControl
sudo rm -f  /lib/systemd/system/deskpiFanStop.service
sudo rm -f  /lib/systemd/system/deskpiFanControl.service
sudo rm -f /usr/bin/deskpiFanStop
sudo rm -f /usr/bin/deskpiFanControl
echo "Successfully removed and disabled DeskPi Fan Control and Safeshut Services"
echo "------------ DeskPi service configuration finished ------------"

echo ""

sync
echo "=========== Uninstalled DeskPi Driver successfully ============"
