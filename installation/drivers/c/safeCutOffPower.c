/*
 * safeCutOffPower — robustly write "power_off" to the DeskPi Pro MCU
 * over /dev/ttyUSB0 so it cuts the 5 V rail ~15 s later.
 *
 * This is the ONLY sender of the cut-off token, for every shutdown
 * cause. When the MCU sends "poweroff" to the host (the front-panel
 * double-click), the fan daemon (pwmFanControl_v3.c) only triggers
 * `systemctl poweroff` — it deliberately does not write the token
 * itself, because an immediate ack would start the MCU's ~15 s
 * rail-cut timer before the OS has stopped its services. This
 * systemd service fires at poweroff.target, after every regular
 * service has stopped, so the 15 s window covers only the final
 * unmount + halt.
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
 *   0  — at least one attempt fully succeeded: write() wrote all 9
 *        bytes AND its tcdrain() returned 0, so a copy of the token
 *        left the UART shift register. The systemd Type=oneshot unit
 *        can complete.
 *   1  — no attempt fully succeeded (port not open, EBADF, tcdrain
 *        failure on every copy, etc.). The systemd unit will be
 *        marked failed, which is the right signal to the user that
 *        the cut-off signalling was lost.
 */
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <termios.h>
#include <stdlib.h>
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

    /* VMIN=0, VTIME=10 deciseconds — set for completeness; this
     * program never reads, write() is not affected by them. */
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 10;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        close(fd);
        return -1;
    }

    /* Flush the kernel-side tty buffers (they are per-device, so this
     * also discards bytes the fan daemon may have queued in the last
     * 1 s — pwm_xxx tokens).  Note this cannot recall bytes that have
     * already reached the CH340's hardware FIFO; the write REPEATS
     * below is what protects against in-flight interleaving. */
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

    fprintf(stderr,
            "safeCutOffPower64: %s open — sending the 'power_off' cut-off token "
            "(the MCU cuts the 5 V rail ~15 s after receiving it)\n",
            SERIAL_PORT);

    int ok_count = 0;
    for (int i = 0; i < REPEATS; i++) {
        /* Re-flush before each write in case the fan daemon (or a dying
         * daemon's in-flight write) left bytes in the kernel tty buffer
         * between our previous attempt and this one.  Bytes already in
         * the CH340 hardware FIFO cannot be flushed — the REPEATS loop
         * is the real protection there. */
        tcflush(fd, TCIOFLUSH);

        ssize_t n = write(fd, data, len);
        if (n == (ssize_t)len) {
            /* tcdrain() blocks until every byte written above has been
             * transmitted out of the UART shift register. Without this,
             * a successful write() return value only means the kernel
             * accepted the bytes into the tty buffer — they may still
             * be sitting there when the kernel halts.  An attempt only
             * counts as delivered once tcdrain() confirms the bytes
             * left the wire (see exit-code contract in the header). */
            if (tcdrain(fd) == 0) {
                ok_count++;
                /* Log the first delivery only — the final summary reports
                 * n/REPEATS, five identical lines add nothing. */
                if (ok_count == 1)
                    fprintf(stderr,
                            "safeCutOffPower64: attempt %d/%d: token delivered\n",
                            i + 1, REPEATS);
            } else {
                perror("safeCutOffPower64: tcdrain");
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
         * settle between writes.  Skipped after the last attempt. */
        if (i < REPEATS - 1)
            usleep(RETRY_USEC);
    }

    /* One final drain + flush so nothing lingers if a follow-up open()
     * of /dev/ttyUSB0 (e.g. by a subsequent daemon process) happens. */
    tcdrain(fd);
    tcflush(fd, TCIOFLUSH);
    close(fd);

    if (ok_count == 0) {
        fprintf(stderr,
                "safeCutOffPower64: no copy of 'power_off' was reliably "
                "written to %s.\n"
                "  The MCU did NOT receive the cut-off signal: the system will "
                "halt from the OS side, but the 5 V rail will stay HOT.\n"
                "  Check the USB cable to the DeskPi board and that %s is "
                "the right port.\n",
                SERIAL_PORT, SERIAL_PORT);
        return 1;
    }

    fprintf(stdout,
            "safeCutOffPower64: 'power_off' delivered %d/%d times — the MCU "
            "will cut the 5 V rail in ~15 s.\n",
            ok_count, REPEATS);
    return 0;
}
