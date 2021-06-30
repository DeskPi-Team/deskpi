# Before you import the library, you need to install pyserial library.
# via "pip3 install pyserial" in Python3.x or "pip install pyserial" in Python2.x
# This script will send `power_off` to daughter board, and the daughter board will cut off the power.
import serial
import time 


ser = serial.Serial("/dev/ttyUSB0", 9600, timeout=30)

try: 
    while True:
        if ser.isOpen():
            ser.write(b'power_off')
            ser.close()

except KeyboardInterrupt:
    ser.write(b'power_off')
    ser.close()
    
