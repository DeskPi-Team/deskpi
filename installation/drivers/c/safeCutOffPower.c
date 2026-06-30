#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

/*
 * safeCutOffPower: open /dev/ttyUSB0, write the literal "power_off" string,
 * then close and exit.  Designed to be invoked as a Type=oneshot systemd
 * service at poweroff.target so the DeskPi Pro MCU cuts the 5 V rail ~15 s
 * after the byte sequence is received.
 */
int main(void)
{
    int serial_port = open("/dev/ttyUSB0", O_RDWR | O_NOCTTY);
    if (serial_port < 0) {
        perror("open /dev/ttyUSB0");
        return 1;
    }

    struct termios tty;

    if (tcgetattr(serial_port, &tty) != 0) {
        perror("tcgetattr");
        close(serial_port);
        return 1;
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
    tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL);

    tty.c_oflag &= ~OPOST;
    tty.c_oflag &= ~ONLCR;

    tty.c_cc[VTIME] = 10;
    tty.c_cc[VMIN] = 0;

    cfsetispeed(&tty, B9600);
    cfsetospeed(&tty, B9600);

    if (tcsetattr(serial_port, TCSANOW, &tty) != 0) {
        perror("tcsetattr");
        close(serial_port);
        return 1;
    }

    const char data[] = "power_off";
    ssize_t n = write(serial_port, data, sizeof(data) - 1);
    if (n < 0) {
        perror("write");
        close(serial_port);
        return 1;
    }

    close(serial_port);
    return 0;
}
