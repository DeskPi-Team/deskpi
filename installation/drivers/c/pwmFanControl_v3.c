/*  pwmFanControl_v3.c — DeskPi fan daemon.
 *
 *  Reads the CPU temperature once per second, maps it onto a
 *  temperature→PWM curve from /etc/deskpi.conf and writes the
 *  corresponding 7-byte ASCII token ("pwm_000" … "pwm_100") to the
 *  DeskPi Pro MCU on /dev/ttyUSB0.  Also watches the same port for
 *  the MCU asking the host to shut down ("poweroff" / "power_off") and
 *  triggers a clean `systemctl poweroff`.  Note the button semantics
 *  (confirmed on hardware with a DeskPi Pro; other DeskPi models are
 *  unverified): the front-panel power button reacts ONLY to a
 *  double-click — a single click sends nothing at all, and each click
 *  of the pair sends its own token, so the daemon receives TWO tokens
 *  back to back.  The daemon deliberately does NOT write the
 *  9-byte "power_off" cut-off token itself — that is the exclusive
 *  job of deskpi-cut-off-power.service at poweroff.target, see
 *  drivers/c/README.md for the reasoning.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>

#define SERIAL_DEV  "/dev/ttyUSB0"      /* CH340 USB-UART bridge on the MCU side */
#define CONF_FILE   "/etc/deskpi.conf"
#define PERCENTAGE  10                  /* hysteresis band, in percent of the
                                           last trigger temperature */

#define PWM_CMD     "pwm_%03u"          /* wire format: 7 ASCII bytes, no NUL,
                                           no terminator — see drivers/c/README.md */

static int serial_fd = -1;

/* Set by load_conf() from the optional "log_fan_changes" config key:
 * when non-zero, every fan level change is journaled with the CPU
 * temperature that triggered it.  Default off. */
static int log_fan_changes = 0;

/* ---------------- serial port init ----------------
   Raw 8N1, 9600 baud, no flow control (the MCU does not drive CTS/RTS —
   enabling CRTSCTS here would block write() forever, see safeCutOffPower.c).
   VMIN=0 / VTIME=1 → read() returns whatever arrived within 100 ms, so
   the main loop keeps its ~1 s cadence including the trailing sleep(). */
static int serial_init(const char *dev)
{
    int fd = open(dev, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        fprintf(stderr,
                "pwmFanControl64V3: cannot open %s (%s).\n"
                "  Is the dwc2 overlay enabled (dtoverlay=dwc2,dr_mode=host)?\n",
                dev, strerror(errno));
        return -1;
    }

    struct termios tio = {0};
    cfsetspeed(&tio, B9600);
    tio.c_cflag |= CS8 | CREAD | CLOCAL;
    tio.c_iflag = tio.c_oflag = tio.c_lflag = 0;
    tio.c_cc[VMIN]  = 0;
    tio.c_cc[VTIME] = 1;            /* read timeout: 100 ms */

    tcflush(fd, TCIOFLUSH);         /* drop stale bytes from previous runs */
    if (tcsetattr(fd, TCSANOW, &tio) < 0) {
        fprintf(stderr,
                "pwmFanControl64V3: tcsetattr on %s failed: %s\n",
                dev, strerror(errno));
        close(fd);
        return -1;
    }
    return fd;
}

/* ---------------- serial port send ---------------- */
static void serial_send(const char *buf, size_t len)
{
    /* Failure is non-fatal (the next cycle retries), but logging it
     * unconditionally would spam the journal once per second while the
     * port is dead — log only the ENTER and LEAVE of the failure state. */
    static int write_failing = 0;
    if (serial_fd < 0) return;
    if (write(serial_fd, buf, len) < 0) {
        if (!write_failing) {
            fprintf(stderr,
                    "pwmFanControl64V3: serial write failed (%s) — keeping the "
                    "last fan level, retrying every cycle\n",
                    strerror(errno));
            write_failing = 1;
        }
    } else if (write_failing) {
        fprintf(stderr, "pwmFanControl64V3: serial write recovered\n");
        write_failing = 0;
    }
}

/* ---------------- read CPU temperature ----------------
   Returns temperature in whole degC, or -1 if the sysfs read failed.
   The caller skips the iteration on -1 instead of treating it as 0 degC
   (which would look like "cool down" and drop the fan level). */
static int cpu_temp_get(void)
{
    FILE *fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (!fp) return -1;
    int t = -1;
    if (fscanf(fp, "%d", &t) != 1) t = -1;   /* millidegrees, e.g. 45123 */
    fclose(fp);
    if (t >= 0) t /= 1000;                   /* millidegrees → degC */
    return t;
}

/* ---------------- parse config file ----------------
   Human-readable format, one fan level per line:

       fan_0   = 40     # 0 %  (off) applies while CPU temp <= 40 degC
       fan_25  = 50     # 25 % applies between fan_0  and fan_25
       fan_50  = 65     # 50 % applies between fan_25 and fan_50
       fan_75  = 75     # 75 % applies between fan_50 and fan_75
                        # above fan_75 the fan runs at 100 %

   Optional boolean key:

       log_fan_changes = 1   # journal a line on every fan level change,
                             # e.g. "fan 25 % -> 50 % at 62 degC";
                             # default 0 (silent)

   Blank lines and #-comments are ignored; values must not decrease.
   The fan speeds themselves are fixed at 0/25/50/75/100 % — the four
   temperatures are the only configurable part.  There is deliberately
   NO fan_100 key: the top level has no upper bound, its switch-on
   point IS fan_75 (a fan_100 line would be an unknown key and is
   reported and ignored).  This is the ONLY supported format (the
   legacy 8-bare-integer layout is not parsed; missing keys fall back
   to the defaults below, key by key).

   Every problem found while parsing — garbage lines, unknown keys,
   out-of-range values, repeated keys (the FIRST occurrence wins, any
   repetition is reported and skipped) and a non-increasing temperature
   sequence (e.g. 0 % up to 75 degC but 100 % from 30 degC) — is
   reported on stderr, which journald captures under deskpi.service;
   the offending value is skipped or repaired, never fatal.

   An unreadable file (EACCES etc.) is reported once and the built-in
   defaults apply; only a genuinely missing file (ENOENT) is silent,
   since having no custom curve is a normal state.  A corrupt/binary
   file trips the garbage-line limit: parsing stops after 16 malformed
   lines with a single "file looks corrupt" summary instead of
   flooding the journal.
------------------------------------------------*/
static void load_conf(unsigned int cfg[8])
{
    /* Internal representation — (threshold, pwm) pairs:
       temp<=cfg[0] -> 0 (off), cfg[0]..cfg[2] -> 25,
       cfg[2]..cfg[4] -> 50, cfg[4]..cfg[6] -> 75, >=cfg[6] -> 100. */
    unsigned int def[8] = {40,25, 50,50, 65,75, 75,100};
    memcpy(cfg, def, sizeof(def));

    static const char *const keys[4] = {"fan_0", "fan_25", "fan_50", "fan_75"};

    /* Enabled by the optional "log_fan_changes = 1" config key: journal
     * a line on every fan level change (level + CPU temperature). */
    log_fan_changes = 0;

    FILE *fp = fopen(CONF_FILE, "r");
    if (!fp) {
        /* Missing file is a normal state (no custom curve, defaults are
         * used) — stay silent.  Anything else (EACCES on a hand-edited
         * file, EISDIR, ...) deserves a log line: the user thinks their
         * curve is active while the daemon is running on defaults. */
        if (errno != ENOENT)
            fprintf(stderr,
                    "pwmFanControl64V3: cannot open %s (%s) — using built-in default curve\n",
                    CONF_FILE, strerror(errno));
        return;
    }

    int lineno = 0;
    int garbage = 0;
    int seen[4] = {0, 0, 0, 0};
    int seen_log = 0;
    char line[128];
    while (fgets(line, sizeof(line), fp)) {
        lineno++;
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#' || *p == '\n' || *p == '\r' || *p == '\0') continue;

        char key[16];
        unsigned int val = 0;
        if (sscanf(p, "%15[a-z0-9_] = %u", key, &val) != 2) {
            /* for the log message: strip the newline, mask binary bytes */
            line[strcspn(line, "\r\n")] = '\0';
            for (char *q = line; *q; ++q)
                if (!isprint((unsigned char)*q)) *q = '?';
            fprintf(stderr,
                    "pwmFanControl64V3: %s: line %d: garbage ignored: \"%s\"\n",
                    CONF_FILE, lineno, line);
            /* A valid config has at most 4 value lines.  A wall of
             * garbage (e.g. the file is binary, or the editor saved
             * something alien) would flood the journal line by line —
             * report it once and stop parsing, the defaults apply. */
            if (++garbage >= 16) {
                fprintf(stderr,
                        "pwmFanControl64V3: %s: %d malformed lines — file looks "
                        "corrupt, ignoring the rest (built-in default curve applies)\n",
                        CONF_FILE, garbage);
                break;
            }
            continue;
        }

        /* Optional boolean: log every fan level change. */
        if (strcmp(key, "log_fan_changes") == 0) {
            if (seen_log) {
                fprintf(stderr,
                        "pwmFanControl64V3: %s: line %d: log_fan_changes redefined,"
                        " first value kept\n",
                        CONF_FILE, lineno);
                continue;
            }
            seen_log = 1;
            if (val > 1)
                fprintf(stderr,
                        "pwmFanControl64V3: %s: line %d: log_fan_changes = %u:"
                        " expected 0 or 1, treating as 1\n",
                        CONF_FILE, lineno, val);
            log_fan_changes = (val != 0);
            continue;
        }

        int slot = -1;
        for (int i = 0; i < 4; ++i)
            if (strcmp(key, keys[i]) == 0) { slot = i * 2; break; }

        if (slot < 0) {
            fprintf(stderr,
                    "pwmFanControl64V3: %s: line %d: unknown key \"%s\" ignored"
                    " (valid keys: fan_0, fan_25, fan_50, fan_75,"
                    " log_fan_changes)\n",
                    CONF_FILE, lineno, key);
            continue;
        }
        if (seen[slot / 2]) {
            fprintf(stderr,
                    "pwmFanControl64V3: %s: line %d: %s redefined, first value kept\n",
                    CONF_FILE, lineno, key);
            continue;
        }
        seen[slot / 2] = 1;

        if (val == 0 || val > 110) {
            fprintf(stderr,
                    "pwmFanControl64V3: %s: line %d: %s = %u out of range 1..110, clamped\n",
                    CONF_FILE, lineno, key, val);
            if (val == 0)  val = 1;
            if (val > 110) val = 110;
        }
        cfg[slot] = val;
    }
    fclose(fp);

    /* Sequence check: fan_0 < fan_25 < fan_50 < fan_75 must hold, or the
       bands collapse/overlap and the curve makes no sense (e.g. 0 % up
       to 75 degC while 100 % already starts at 30 degC).  Report every
       violation and repair it by pushing the threshold just above the
       previous one. */
    for (int i = 1; i < 4; ++i) {
        int cur  = i * 2;          /* cfg index of this threshold  */
        int prev = cur - 2;        /* cfg index of the previous one */
        if (cfg[cur] <= cfg[prev]) {
            fprintf(stderr,
                    "pwmFanControl64V3: %s: %s (%u degC) does not follow %s (%u degC)"
                    " — thresholds must increase; using %u degC\n",
                    CONF_FILE, keys[i], cfg[cur], keys[i - 1], cfg[prev],
                    cfg[prev] + 1);
            cfg[cur] = cfg[prev] + 1;
        }
    }
}

/* ---------------- shutdown command detection ----------------
   Called once per loop iteration.  Returns 1 once the MCU asked for a
   shutdown — the caller then exits the loop.

   The MCU sends the token as plain bytes with no framing, so a read()
   can return a partial token ("power_of" one second, "f" the next).
   Leftover bytes are therefore accumulated across calls in a static
   buffer; if no token is found, the buffer is trimmed to the last few
   bytes — enough to hold a partial token — so serial noise cannot
   clog it.  The longest token is "power_off" (9 bytes), so keeping
   the last 8 bytes preserves any possible split point.

   Button semantics (confirmed on hardware with a DeskPi Pro; other
   DeskPi models are unverified): the MCU reacts ONLY to a double-click
   of the front-panel power button — a single click sends nothing at
   all.  Each click of the pair sends its own token, so one double-click
   delivers TWO "poweroff" tokens back to back.  The first
   one triggers the shutdown below; the second is harmless (the daemon
   exits after the first token, and duplicate poweroff requests are
   ignored by systemd).

   Why we do NOT ack with our own "power_off" token here: the MCU cuts
   the 5 V rail ~15 s after seeing that token.  Acking immediately
   would start the 15 s timer at button-press time and leave the OS
   only ~14 s to shut down — a slow or heavily loaded system would get
   its power cut mid-teardown.  Instead we just request an orderly
   shutdown; deskpi-cut-off-power.service fires at poweroff.target,
   AFTER every regular service has stopped, and only then starts the
   MCU's 15 s window.  Trade-off: if the OS hangs before reaching
   poweroff.target, the token is never sent and the rail stays hot —
   same as for any non-button shutdown.
   ----------------------------------------------------------------- */
static int check_poweroff(void)
{
    static char acc[64];         /* accumulated serial input */
    static size_t acc_len = 0;
    char buf[32];
    ssize_t n = read(serial_fd, buf, sizeof(buf));
    if (n <= 0) return 0;        /* nothing within the VTIME window */

    for (ssize_t i = 0; i < n && acc_len < sizeof(acc) - 1; ++i)
        acc[acc_len++] = buf[i];
    acc[acc_len] = '\0';

    int trigger = strstr(acc, "poweroff") || strstr(acc, "power_off");
    if (!trigger) {
        const size_t keep = 8;   /* see comment above: max partial token */
        if (acc_len > keep) {
            memmove(acc, acc + acc_len - keep, keep);
            acc_len = keep;
            acc[acc_len] = '\0';
        }
        return 0;
    }

    /* MCU asked for a shutdown (front-panel power button).  Request an
     * orderly power-off and let deskpi-cut-off-power.service send the
     * cut-off token at poweroff.target (see the comment above). */
    fprintf(stderr,
            "pwmFanControl64V3: front-panel power button pressed — MCU sent a "
            "poweroff token; requesting orderly shutdown "
            "('sync && systemctl poweroff').  The 5 V cut-off token will be "
            "sent later by deskpi-cut-off-power.service at poweroff.target.\n");
    (void)system("sync && systemctl poweroff");
    return 1;
}

/* ---------------- main loop ----------------
   Two pieces of state drive the curve:

   last_temp — the temperature that triggered the CURRENT fan level.
   While the temperature stays at or below it (within the PERCENTAGE
   hysteresis band) the level is held, so the fan does not oscillate
   around a threshold.  When the temperature falls below
   last_temp - PERCENTAGE%, last_temp is cleared and the curve is
   re-evaluated from scratch on the next iteration.

   last_pwm  — the level currently on the wire (999 = nothing sent
   yet, so the daemon always asserts the curve on startup).  The token
   is sent only when the computed level differs from it, which is what
   makes the spin-DOWN to pwm_000 actually happen: a naive
   "if (pwm || last_temp)" guard would skip the zero level and leave
   the fan stuck at the previous speed.
------------------------------------------------*/
int main(void)
{
    unsigned int conf[8];
    unsigned int last_temp = 0;
    /* 999 is a sentinel that matches no real level (levels are clamped
     * to 0..100): it forces the first computed level onto the wire at
     * startup.  Initialising to 0 instead would assume the MCU is idle
     * — wrong after a daemon crash/restart while the fan was spinning
     * at an old level, or after a manual deskpi-config override: with
     * temp already below the first threshold the computed pwm_000 would
     * equal the assumed wire state and never be sent, leaving the fan
     * stuck at its previous speed. */
    unsigned int last_pwm = 999;
    char pwm_cmd[sizeof("pwm_000")];        /* 7 chars + NUL, exact fit */

    serial_fd = serial_init(SERIAL_DEV);
    if (serial_fd < 0) return 1;

    load_conf(conf);
    fprintf(stderr,
            "pwmFanControl64V3: started — fan curve %u/%u/%u/%u degC for "
            "25/50/75/100 %% (0 %% below %u degC)\n",
            conf[0], conf[2], conf[4], conf[6], conf[0]);

    while (1) {
        if (check_poweroff()) {
            fprintf(stderr,
                    "pwmFanControl64V3: exiting — shutdown requested\n");
            break;                  /* shutdown requested; the cut-off token
                                       will be sent by deskpi-cut-off-power.service
                                       at poweroff.target */
        }

        int temp = cpu_temp_get();
        /* A dead thermal zone would otherwise be silent forever (the fan
         * just freezes at its last level) — log the ENTER/LEAVE of the
         * failure state, not every retry. */
        static int temp_failing = 0;
        if (temp < 0) {
            if (!temp_failing) {
                fprintf(stderr,
                        "pwmFanControl64V3: cannot read CPU temperature "
                        "(/sys/class/thermal/thermal_zone0/temp) — keeping the "
                        "current fan level, retrying every cycle\n");
                temp_failing = 1;
            }
        } else {
            if (temp_failing) {
                fprintf(stderr,
                        "pwmFanControl64V3: CPU temperature read recovered (%u degC)\n",
                        (unsigned int)temp);
                temp_failing = 0;
            }
            unsigned int t = (unsigned int)temp;
            unsigned int pwm = 0;
            if      (t >= conf[6]) pwm = conf[7];   /* top bin: >= temp4 */
            else if (t >= conf[4]) pwm = conf[5];
            else if (t >= conf[2]) pwm = conf[3];
            else if (t >= conf[0]) pwm = conf[1];   /* bottom bin: temp1..temp2 */
            else                     pwm = 0;        /* below temp1: fan off */

            if (last_temp == 0 || t > last_temp) {
                /* Rising edge or fresh start: pick a new level. */
                if (pwm != last_pwm) {
                    snprintf(pwm_cmd, sizeof(pwm_cmd), PWM_CMD, pwm);
                    serial_send(pwm_cmd, sizeof(pwm_cmd) - 1);  /* 7 bytes, no NUL */
                    if (log_fan_changes) {
                        if (last_pwm == 999)
                            fprintf(stderr,
                                    "pwmFanControl64V3: fan level %u %% asserted at %u degC (startup)\n",
                                    pwm, t);
                        else
                            fprintf(stderr,
                                    "pwmFanControl64V3: fan %u %% -> %u %% at %u degC\n",
                                    last_pwm, pwm, t);
                    }
                    last_pwm = pwm;
                }
                if (pwm) last_temp = t;   /* record the temp that triggered this level */
            } else if (t < last_temp - last_temp * PERCENTAGE / 100) {
                /* Hysteresis: release the level only once the temperature
                   has dropped by PERCENTAGE% below the last trigger point.
                   The (possibly lower) level is re-evaluated next iteration. */
                last_temp = 0;
            }
        }

        sleep(1);
    }

    close(serial_fd);
    return 0;
}
