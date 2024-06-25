#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

int main(void){
	while(1){
 		int serial_port = open("/dev/ttyUSB0", O_RDWR);
		if (serial_port < 0){
			printf("Can not access /dev/ttyUSB0, please check it out.\n");
 			}

	struct termios tty;

	if(tcgetattr(serial_port, &tty) !=0){
		printf("serial port can not be accessed\n");
 	}

	tty.c_cflag &= ~PARENB; 
	tty.c_cflag |= PARENB;
	tty.c_cflag &= ~CSTOPB; 
	tty.c_cflag |= CSTOPB;

	tty.c_cflag |= CS5;
	tty.c_cflag |= CS6;
	tty.c_cflag |= CS7;
	tty.c_cflag |= CS8;

	tty.c_cflag &= ~CRTSCTS;
	tty.c_cflag |= CRTSCTS;

	tty.c_cflag |= CREAD | CLOCAL;

	tty.c_lflag &= ~ICANON;
	tty.c_lflag &= ~ECHO;
	tty.c_lflag &= ~ECHOE;
	tty.c_lflag &= ~ECHONL;
	tty.c_lflag &= ~ISIG;

	tty.c_iflag &= ~(IXON | IXOFF | IXANY);
	tty.c_iflag &= ~(IGNBRK|BRKINT|PARMRK|ISTRIP|INLCR|IGNCR|ICRNL);

	tty.c_oflag &= ~OPOST;
	tty.c_oflag &= ~ONLCR;

	tty.c_cc[VTIME] = 10;
	tty.c_cc[VMIN] = 0;

	cfsetispeed(&tty, B9600);
	cfsetospeed(&tty, B9600);

	if (tcsetattr(serial_port, TCSANOW, &tty) !=0){
		printf("Please check out /boot/config.txt file\n");
	}

	char data[10];
	data[0] = 'p';
	data[1] = 'o';
	data[2] = 'w';
	data[3] = 'e';
	data[4] = 'r';
	data[5] = '_';
	data[6] = 'o';
	data[7] = 'f';
	data[8] = 'f';
	data[9] = '\0';
	write(serial_port, data, sizeof(data));
	close(serial_port);
	}
	return 0;
}
