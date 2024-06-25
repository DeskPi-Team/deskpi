#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>
#include <math.h>

//#define TEST_MODE
#define PERCENTAGE 10 // switch over percentage range



static int serial_port=0;
/* initialized the serial port*/
int init_serial( char *serial_name)
{
	serial_port = open(serial_name, O_RDWR);

	if (serial_port < 0){
		printf("Can not open /dev/ttyUSB0 serial port ErrorCode: %s\n", strerror(errno));
		printf("Please check the /boot/config.txt file and add dtoverlay=dwc2, dr_mode=host and reboot RPi \n");
	}

	struct termios tty;

	if(tcgetattr(serial_port, &tty) !=0){
		printf("Please check serial port over OTG\n");
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
		printf("---Serial Port Can not detected---\n");
	}
	return 0;
}

/* send data to serial port function*/
int send_serial(char *data,size_t data_len)
{
	return  write(serial_port, data, data_len);
}

/* close the serial port function*/
int __init_serial()
{
	return close(serial_port);
}
/* read cpu temperature function */
unsigned int read_cpu_tmp()
{
	FILE *fp=NULL;
	unsigned int cpu_temp=0;
	char buff[255];
	bzero(buff, sizeof(buff));
	fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
	if( NULL != fp)
	{
		if (fgets(buff, 255, (FILE*)fp) != NULL){
			cpu_temp = atoi(buff) /1000 ;
		}
		fclose(fp);
	}
	return cpu_temp;
}


/* check for poweroff command and shutdown system once user double press power button */
void check_for_poweroff_command() { 
	char mcu_message[100];
	int bytes_read = read(serial_port, mcu_message, sizeof(mcu_message)-1);
	if (bytes_read > 0){
		mcu_message[bytes_read] = '\0';
		if (strstr(mcu_message, "poweroff") != NULL) {
			system("sudo sync; sudo init 0");
		}

	}
}


/* main loop */
int main(void){
	int i=0;
	FILE *fp=NULL;
	char buffer[100];
	bzero(buffer, sizeof(buffer));

	char data[8]={0};
	unsigned int conf_info[8];
	unsigned int cpu_temp=0;
	unsigned int last_cpu_temp = 0; // last temperature level recorded
	unsigned int min_temp = 0; // calculated minimum temperature based on percentage
	init_serial("/dev/ttyUSB0");
    /* default configuration if /etc/deskpi.conf dose not exist */
	conf_info[0]=40;
	conf_info[1]=75;

	conf_info[2]=50;
	conf_info[3]=75;

	conf_info[4]=65;
	conf_info[5]=100;

	conf_info[6]=75;
	conf_info[7]=100;

	while(1)
	{
		check_for_poweroff_command();

		fp = fopen("/etc/deskpi.conf", "r");
		if(fp != NULL)
		{
			for(i=0;i<8;i++)
			{
				bzero(buffer, sizeof(buffer));
				if (fgets(buffer, 100, fp) != NULL)
				{
					conf_info[i] = atoi(buffer);
				}
			}
			fclose(fp);
		}

		/* Testing section
		  for(i=0;i<8;i++)
		{
			printf("temp:%d\n",conf_info[i]);
			i++;
			printf("pwm:%d\n",conf_info[i]);
		}
		*/
		cpu_temp = read_cpu_tmp();
		#ifdef TEST_MODE
		printf("cpu_temp:%d / last_cpu_temp:%d / fan_speed:", cpu_temp, last_cpu_temp);
		#endif

		if (last_cpu_temp == 0 || cpu_temp > last_cpu_temp) {
			if(cpu_temp < conf_info[0])
			{
				memcpy( (char *) &data, "pwm_000", sizeof("pwm_000"));
				last_cpu_temp = 0;
			}
			else if(cpu_temp >= conf_info[0] && cpu_temp < conf_info[2])
			{
				sprintf((char *)&data, "pwm_%03d", conf_info[1]);
				last_cpu_temp = conf_info[0];
			}
			else if(cpu_temp >= conf_info[2] && cpu_temp < conf_info[4])
			{
				sprintf((char *)&data, "pwm_%03d", conf_info[3]);
				last_cpu_temp = conf_info[2];
			}
			else if(cpu_temp >= conf_info[4] && cpu_temp < conf_info[6])
			{
				sprintf((char *)&data, "pwm_%03d", conf_info[5]);
				last_cpu_temp = conf_info[4];
			}
			else if(cpu_temp >= conf_info[6])
			{
				sprintf((char *)&data, "pwm_%03d", conf_info[7]);
				last_cpu_temp = conf_info[6];
			}
			send_serial((char *) &data, sizeof(data));
			#ifdef TEST_MODE
			printf("*");
			#endif
		}

		// leave fan speed as is if not within pre defined percentage
		min_temp = last_cpu_temp - round(last_cpu_temp * PERCENTAGE / 100);
		if (cpu_temp < min_temp) {
			last_cpu_temp = 0;  // reset level
		}

		#ifdef TEST_MODE
		printf("%s", data);
		printf(" until min_temp:%d", min_temp);
		printf("\n");
		#endif

		sleep(1);

	}
	__init_serial();
	return 0;
}
