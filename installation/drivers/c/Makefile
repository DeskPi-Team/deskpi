DEFAULT: all
.PHONY: all install clean

# -Werror is intentional: both binaries talk to hardware over a raw
# serial port at shutdown time; any warning here is a latent bug.
CFLAGS = -Wall -Wextra -Werror -O2

all: pwmFanControl64V3 safeCutOffPower64

install:
	sudo chmod 755 pwmFanControl64V3 safeCutOffPower64
	sudo cp pwmFanControl64V3 /usr/bin/
	sudo cp safeCutOffPower64 /usr/bin/

pwmFanControl64V3:  pwmFanControl_v3.c
	gcc $(CFLAGS) -o pwmFanControl64V3 pwmFanControl_v3.c

safeCutOffPower64:  safeCutOffPower.c
	gcc $(CFLAGS) -o safeCutOffPower64 safeCutOffPower.c

clean:
	rm -f safeCutOffPower64 pwmFanControl64V3
