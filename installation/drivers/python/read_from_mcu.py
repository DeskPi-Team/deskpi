import serial
import time

ser = serial.Serial("/dev/ttyUSB0", baudrate=9600, timeout=30)

while True:
    print("grap data...")
    if ser.isOpen():
        data = ser.readline()
        print(data)

    print("no data get")
