#!/bin/bash	
# This is a fan speed control utility tool for user to customize fan speed.
# Priciple: send speed argument to the MCU 
# Technical Part
# There are four arguments:
# pwm_025 means sending 25% PWM signal to MCU. The fan will run at 25% speed level. 
# pwm_050 means sending 50% PWM signal to MCU. The fan will run at 50% speed level.
# pwm_075 means sending 75% PWM signal to MCU. The fan will run at 75% speed level.
# pwm_100 means sending 100% PWM signal to MCU.The fan will run at 100% speed level. 
# 
# This is the serial port that connect to deskPi mainboard and it will
# communicate with Raspberry Pi and get the signal for fan speed adjusting.
serial_port='/dev/ttyUSB0'

# Stop deskpi.service so that user can define the speed level.
sudo systemctl stop deskpi.service 2&>/dev/null

# Greetings and information for user.
echo "Welcome to Use DeskPi-Team's Product"
echo "Please select speed level that you want: "
echo "1 - set fan speed level to 25%"
echo "2 - set fan speed level to 50%"
echo "3 - set fan speed level to 75%"
echo "4 - set fan speed level to 100%"
echo "5 - Turn off Fan"
echo "6 - Cancel manual control and enable automatical fan control"
echo "Just input the number and press enter."
read -p "Your choice:" levelNumber
case $levelNumber in
	1) 
	   echo "You've select 25% speed level"
	   sudo echo pwm_025 > $serial_port
	   echo "Fan speed level has been change to 25%"
	   ;;
	2) 
	   echo "You've select 50% speed level"
	   sudo echo pwm_050 > $serial_port
	   echo "Fan speed level has been change to 50%"
	   ;;
	3) 
	   echo "You've select 75% speed level"
	   sudo echo pwm_075 > $serial_port
	   echo "Fan speed level has been change to 75%"
	   ;;
	4) 
	   echo "You've select 100% speed level"
	   sudo echo pwm_100 > $serial_port
	   echo "Fan speed level has been change to 100%"
	   ;;
	5) 
	   echo "Turn off fan"
	   sudo echo pwm_000 > $serial_port
	   echo "Fan speed level has been turned off."
	   ;;
	6) 
	   echo "Cancel manual control and enable automatical fan control"
	   sudo systemctl restart deskpi.service &
	   ;;
	*) 
	   echo "You type the wrong selection, please try again!"
	   . /usr/bin/deskpi-config
	   ;;
esac
