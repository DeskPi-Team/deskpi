DEFAULT: all
.PHONY: install

all: pwmFanControl64 safeCutOffPower64

install:
	sudo chmod 755 pwmFanControl64 safeCutOffPower64
	sudo cp pwmFanControl64 safeCutOffPower64 /usr/bin/

pwmFanControl64:  pwmFanControl.c
	gcc -o pwmFanControl64 pwmFanControl.c
safeCutOffPower64:  safeCutOffPower.c 
	gcc -o safeCutOffPower64 safeCutOffPower.c
clean:
	rm -rf safeCutOffPower64 pwmFanControl64 
