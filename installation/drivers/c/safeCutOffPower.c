/*
 * safeCutOffPower — robustly write "power_off" to the DeskPi Pro MCU
 * over /dev/ttyUSB0 so it cuts the 5 V rail ~15 s later.
 *
 * This is the BACKUP path for the cut-off signalling. The PRIMARY path
 * lives in pwmFanControl_v2.c's check_poweroff(): the moment the MCU
 * sends "poweroff" to the host (the front-panel double-click), the
 * daemon acks with "power_off" before calling `systemctl poweroff`.
 * This systemd service exists for the cases where the OS is shut down
 * by some other route (sudo poweroff over SSH, apt-triggered reboot,
 * etc.) so the MCU still gets the cut-off token.
 *
 * Reliability requirements:
 *   - line discipline MUST be 9600 8N1, no hardware flow control.
 *     The DeskPi Pro's CH340 runs at 9600 8N1 and does not assert
 *     CTS, so CRTSCTS must be CLEARED or the write() blocks forever.
 *   - the write MUST hit the wire before the kernel begins tearing
 *     down drivers. We use O_SYNC on open + tcdrain() after each
 *     write to make sure every byte has left the UART shift register.
 *   - we write the 9-byte sequence REPEATS times in case the first
 *     attempt races with the fan daemon also writing pwm_* tokens.
 *
 * Exit code:
 *   0  — at least one write() succeeded AND its tcdrain() returned 0.
 *        The systemd Type=oneshot unit can complete.
 *   1  — every write() failed (port not open, EBADF, etc.).
 *        The systemd unit will be marked failed, which is the right
 *        signal to the user that the cut-off signalling was lost.
 */
#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

#define SERIAL_PORT "/dev/ttyUSB0"
#define REPEATS     5           /* belt-and-suspenders: send 5 copies  */
#define RETRY_USEC  100000      /* 100 ms between attempts            */

static int open_serial_raw_8n1(void)
{
    /*
     * O_SYNC asks the kernel to flush the underlying device on every
     * write, which on a USB serial adapter translates to "wait for the
     * URB to complete". Belt-and-suspenders alongside tcdrain() below.
     */
    int fd = open(SERIAL_PORT, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) return -1;

    struct termios tty;
    if (tcgetattr(fd, &tty) != 0) {
        close(fd);
        return -1;
    }

    cfsetispeed(&tty, B9600);
    cfsetospeed(&tty, B9600);

    /* 8 data bits, no parity, 1 stop bit, no hw flow control.
     * The &= ~ ... | ... pattern is correct here because the ~ runs
     * FIRST, clearing every flag we want off, before we | in only the
     * flags we want on. */
    tty.c_cflag &= ~(PARENB | CSTOPB | CSIZE | CRTSCTS);
    tty.c_cflag |=  (CS8 | CREAD | CLOCAL);

    /* Raw input — no CR/LF translation, no XON/XOFF, no BREAK ints. */
    tty.c_iflag &= ~(IXON | IXOFF | IXANY
                     | IGNBRK | BRKINT | PARMRK | ISTRIP
                     | INLCR | IGNCR | ICRNL);

    /* Raw output — no OPOST processing (we do not want a stray \n
     * mangling the 9-byte payload). */
    tty.c_oflag &= ~(OPOST | ONLCR);

    /* Non-canonical, no echo, no signals. */
    tty.c_lflag &= ~(ICANON | ECHO | ECHOE | ECHONL | ISIG);

    /* VMIN=0, VTIME=10 deciseconds → write() returns immediately,
     * read() returns after 1 s of silence or with whatever's in buf. */
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 10;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        close(fd);
        return -1;
    }

    /* Drain anything the fan daemon may have written in the last 1 s
     * (pwm_xxx tokens) so it cannot corrupt our payload. */
    tcflush(fd, TCIOFLUSH);
    return fd;
}

int main(void)
{
    int fd = open_serial_raw_8n1();
    if (fd < 0) {
        fprintf(stderr,
                "safeCutOffPower64: cannot open %s (%s).\n"
                "  Is the dwc2 overlay enabled? Is deskpi.service running?\n",
                SERIAL_PORT, strerror(errno));
        return 1;
    }

    static const char data[] = "power_off";
    const size_t len = sizeof(data) - 1;   /* 9 bytes, no NUL */

    int ok_count = 0;
    for (int i = 0; i < REPEATS; i++) {
        /* Re-flush before each write in case the fan daemon sneaked in
         * a pwm_xxx token between our previous write and this one. */
        tcflush(fd, TCIOFLUSH);

        ssize_t n = write(fd, data, len);
        if (n == (ssize_t)len) {
            ok_count++;
            /* tcdrain() blocks until every byte written above has been
             * transmitted out of the UART shift register. Without this,
             * a successful write() return value only means the kernel
             * accepted the bytes into the tty buffer — they may still
             * be sitting there when the kernel halts. */
            if (tcdrain(fd) != 0) {
                perror("tcdrain");
            }
        } else if (n < 0) {
            fprintf(stderr, "safeCutOffPower64: write attempt %d failed: %s\n",
                    i + 1, strerror(errno));
        } else {
            fprintf(stderr,
                    "safeCutOffPower64: short write on attempt %d: %zd of %zu bytes\n",
                    i + 1, n, len);
        }

        /* 100 ms gap — short enough to fit comfortably in the systemd
         * oneshot timeout, long enough for the CH340 + USB stack to
         * settle between writes. */
        usleep(RETRY_USEC);
    }

    /* One final drain + flush so nothing lingers if a follow-up open()
     * of /dev/ttyUSB0 (e.g. by a subsequent daemon process) happens. */
    tcdrain(fd);
    tcflush(fd, TCIOFLUSH);
    close(fd);

    if (ok_count == 0) {
        fprintf(stderr,
                "safeCutOffPower64: every write to %s failed.\n"
                "  The MCU did NOT receive the cut-off signal.\n",
                SERIAL_PORT);
        return 1;
    }

    fprintf(stderr,
            "safeCutOffPower64: 'power_off' written %d/%d times to %s.\n",
            ok_count, REPEATS, SERIAL_PORT);
    return 0;
}