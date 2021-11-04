DEFAULT: all
.PHONY: install

all: pwmControlFan fanStop safecutoffpower

install:
	sudo chmod 755 pwmControlFan fanStop safecutoffpower
	sudo cp pwmControlFan fanStop safecutoffpower /usr/bin/
	sudo chcon -u system_u -t bin_t /usr/bin/pwmControlFan /usr/bin/fanStop /usr/bin/safecutoffpower

pwmControlFan:  pwmControlFan.c
	gcc -o pwmControlFan pwmControlFan.c
fanStop: fanStop.c
	gcc -o fanStop fanStop.c
safecutoffpower:  safecutoffpower.c 
	gcc -o safecutoffpower safecutoffpower.c
clean:
	rm -rf safecutoffpower pwmControlFan fanStop
