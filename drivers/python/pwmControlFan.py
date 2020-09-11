# Before you import the library, you need to install pyserial library.
# via "pip3 install pyserial" in Python3.x or "pip install pyserial" in Python2.x
import serial
import time 
import subprocess 


ser = serial.Serial("/dev/ttyUSB0", 9600, timeout=30)

try: 
    while True:
        if ser.isOpen():
            cpu_temp = subprocess.getoutput('vcgencmd measure_temp|awk -F\'=\' \'{print $2\'}')
            cpu_temp = int(cpu_temp.split('.')[0])

            if cpu_temp > 35 and cpu_temp < 50:
                ser.write(b'pwm_025')
                print("speed level 25%")
            elif cpu_temp > 50 and cpu_temp < 65:
                ser.write(b'pwm_050')
                print("speed level 50%")
            elif cpu_temp > 65 and cpu_temp < 75:
                ser.write(b'pwm_075')
                print("speed level 75%")
            elif cpu_temp > 75:
                ser.write(b'pwm_100')
                print("speed level 100%")

except KeyboardInterrupt:
    ser.write(b'pwm_000')
    print("speed level 0%")
    ser.close()


