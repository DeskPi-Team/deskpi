/*  fanctl.c  */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include <math.h>

#define SERIAL_DEV  "/dev/ttyUSB0"
#define CONF_FILE   "/etc/deskpi.conf"
#define PERCENTAGE  10          /* 温度回差百分比 */

static int serial_fd = -1;

/* ---------------- 串口初始化 ---------------- */
static int serial_init(const char *dev)
{
    int fd = open(dev, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        perror("open serial");
        return -1;
    }

    struct termios tio = {0};
    cfsetspeed(&tio, B9600);
    tio.c_cflag |= CS8 | CREAD | CLOCAL;
    tio.c_iflag = tio.c_oflag = tio.c_lflag = 0;
    tio.c_cc[VMIN]  = 0;
    tio.c_cc[VTIME] = 10;

    tcflush(fd, TCIOFLUSH);
    tcsetattr(fd, TCSANOW, &tio);
    return fd;
}

/* ---------------- 串口发送 ---------------- */
static void serial_send(const char *buf, size_t len)
{
    if (serial_fd >= 0)
        write(serial_fd, buf, len);
}

/* ---------------- 读取 CPU 温度 ---------------- */
static unsigned int cpu_temp_get(void)
{
    FILE *fp = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    if (!fp) return 0;
    unsigned int t = 0;
    fscanf(fp, "%u", &t);
    fclose(fp);
    return t / 1000;
}

/* ---------------- 解析配置文件 ----------------
   每行一个数字，共 8 行，依次为：
   1.temp1 2.pwm1 3.temp2 4.pwm2 … 8.pwm4
------------------------------------------------*/
static void load_conf(unsigned int cfg[8])
{
    /* 缺省值 */
    unsigned int def[8] = {40,75, 50,75, 65,100, 75,100};
    memcpy(cfg, def, sizeof(def));

    FILE *fp = fopen(CONF_FILE, "r");
    if (!fp) return;
    for (int i = 0; i < 8; ++i) {
        char buf[32];
        if (!fgets(buf, sizeof(buf), fp)) break;
        cfg[i] = (unsigned int)strtoul(buf, NULL, 10);
    }
    fclose(fp);
}

/* ---------------- 关机命令检测 ---------------- */
static void check_poweroff(void)
{
    char buf[64] = {0};
    ssize_t n = read(serial_fd, buf, sizeof(buf)-1);
    if (n > 0) {
        if (strstr(buf, "poweroff") || strstr(buf, "power_off"))
            system("sync && init 0");
    }
}

/* ---------------- 主循环 ---------------- */
int main(void)
{
    unsigned int conf[8];
    unsigned int last_temp = 0;
    char pwm_cmd[16];

    serial_fd = serial_init(SERIAL_DEV);
    if (serial_fd < 0) return 1;

    load_conf(conf);

    while (1) {
        check_poweroff();

        unsigned int temp = cpu_temp_get();

        if (last_temp == 0 || temp > last_temp) {
            unsigned int pwm = 0;
            if      (temp >= conf[6]) pwm = conf[7];
            else if (temp >= conf[4]) pwm = conf[5];
            else if (temp >= conf[2]) pwm = conf[3];
            else if (temp >= conf[0]) pwm = conf[1];
            else                        pwm = 0;

            if (pwm || last_temp) {
                snprintf(pwm_cmd, sizeof(pwm_cmd), "pwm_%03u", pwm);
                serial_send(pwm_cmd, 8);
            }

            if (pwm) last_temp = temp;      /* 记录触发温度 */
        } else {
            /* 回差保护：低于阈值才允许降档 */
            unsigned int min_temp = last_temp - last_temp * PERCENTAGE / 100;
            if (temp < min_temp)
                last_temp = 0;
        }

        sleep(1);
    }

    close(serial_fd);
    return 0;
}
