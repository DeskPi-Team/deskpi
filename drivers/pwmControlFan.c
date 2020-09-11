#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>
#include <wiringPi.h>
/* wiringPi.h requires wiringPi library, you can install it as following
 * commands 
 * sudo apt-get update 
 * sudo apt -y purge wiringpi
 * hash -r 
 * cd /tmp
 * wget https://project-downloads.drogon.net/wiringpi-latest.deb
 * sudo dpkg -i wiringpi-latest.deb
 */

const int PWM_pin = 1;  /* GPIO 1 as per WiringPi, GPIO 18 as per BCM */
int n = 0;

int main(void){
	int intensity; 
	if (wiringPiSetup() == -1)
		exit(1);
	pinMode(PWM_pin, PWM_OUTPUT);  /* Set PWM pin as output */

	while(1){
 		int serial_port = open("/dev/ttyUSB0", O_RDWR);
		if (serial_port < 0){
			printf("Error $i from open: %s\n", errno, strerror(errno));
 			}

	struct termios tty;

	if(tcgetattr(serial_port, &tty) !=0){
		printf("Error $i from open: %s\n", errno, strerror(errno));
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
		printf("Error %i from tcsetattr: %s\n", errno, strerror(errno));
	}

/* Read Temperature from system file  */
	FILE *fp;
	char buff[255];
	char ch;
	int num;
	char data[8];

	fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
	if (fgets(buff, 255, (FILE*)fp)!= NULL){
    	num = atoi(buff);
	}
	// fgets(buff, 255, (FILE*)fp);
	fclose(fp);

/* check the temperature level and send pwm to serial port */
	if ( num < 45000){
 		printf("buff is less than 45000\n");
		data[0] = 'p';
		data[1] = 'w';
		data[2] = 'm';
		data[3] = '_';
		data[4] = '0';
		data[5] = '2';
		data[6] = '5';
		data[7] = '\0';
	}
	else if ( num > 50000 & num < 60000){
 		printf("buff is greater than 50000 and less than 60000\n");
		data[0] = 'p';
		data[1] = 'w';
		data[2] = 'm';
		data[3] = '_';
		data[4] = '0';
		data[5] = '5';
		data[6] = '0';
		data[7] = '\0';
 	}
	else if ( num > 60000 & num < 70000){
 		printf("buff is greater than 60000 less then 70000\n");
		data[0] = 'p';
		data[1] = 'w';
		data[2] = 'm';
		data[3] = '_';
		data[4] = '0';
		data[5] = '7';
		data[6] = '5';
		data[7] = '\0';
	}
	else if ( num > 70000){
 		printf("buff is greater than 70000\n");
		data[0] = 'p';
		data[1] = 'w';
		data[2] = 'm';
		data[3] = '_';
		data[4] = '1';
		data[5] = '0';
		data[6] = '0';
		data[7] = '\0';
	}
	write(serial_port, data, sizeof(data));
	close(serial_port);
	printf("Send data %s\n",  data);
	printf("Send Temperature %d times\n", n+=1);
	sleep(1);
	}
	return 0;
}
