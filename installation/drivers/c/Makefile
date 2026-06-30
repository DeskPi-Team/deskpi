DEFAULT: all
.PHONY: install

all: pwmFanControl64V2 safeCutOffPower64

install:
	sudo chmod 755 pwmFanControl64V2 safeCutOffPower64
	sudo cp pwmFanControl64V2 /usr/bin/
	sudo cp safeCutOffPower64 /usr/bin/

pwmFanControl64V2:  pwmFanControl_v2.c
	gcc -o pwmFanControl64V2 pwmFanControl_v2.c

safeCutOffPower64:  safeCutOffPower.c
	gcc -o safeCutOffPower64 safeCutOffPower.c

clean:
	rm -rf safeCutOffPower64 pwmFanControl64V2