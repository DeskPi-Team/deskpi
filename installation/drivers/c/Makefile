DEFAULT: all
.PHONY: install

all: pwmControlFan64 safecutoffpower64

install:
	sudo sh -c "sudo chmod 755 pwmControlFan64 safecutoffpower64"
	sudo sh -c "sudo cp pwmControlFan64 safecutoffpower64 /usr/bin/"
	sudo sh -c "sudo chcon -u system_u -t bin_t /usr/bin/pwmControlFan64 /usr/bin/safecutoffpower64"

pwmControlFan64:  pwmControlFan.c
	gcc -o pwmControlFan64 pwmControlFan.c
safecutoffpower64:  safecutoffpower.c 
	gcc -o safecutoffpower64 safecutoffpower.c
clean:
	rm -rf safecutoffpower64 pwmControlFan64 
