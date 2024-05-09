DEFAULT: all
.PHONY: install

all: pwmControlFan64 safeCutOffPower64

install:
	sudo sh -c "sudo chmod 755 pwmControlFan64 safeCutOffPower64"
	sudo sh -c "sudo cp pwmControlFan64 safeCutOffPower64 /usr/bin/"
	sudo sh -c "sudo chcon -u system_u -t bin_t /usr/bin/pwmControlFan64 /usr/bin/safeCutOffPower64"

pwmControlFan64:  pwmControlFan.c
	gcc -o pwmControlFan64 pwmControlFan.c
safeCutOffPower64:  safeCutOffPower.c 
	gcc -o safeCutOffPower64 safeCutOffPower.c
clean:
	rm -rf safeCutOffPower64 pwmControlFan64 
