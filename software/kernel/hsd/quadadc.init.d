#!/bin/bash

### BEGIN INIT INFO
# Provides:          pcie_adc
# Required-Start:    $local_fs $syslog
# Required-Stop:     $local_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Load kernel module and create device nodes at boot time.
# Description:       Load kernel module and create device nodes at boot time for pcie_adc instruments.
### END INIT INFO


function adc_start()
{
    /sbin/modprobe pcie_adc || exit 1
    test -e /dev/qadc[0-9]* && /bin/rm -f /dev/qadc[0-9]*
    `/usr/bin/awk 'BEGIN{n=97;}/pcie_adc/{printf "/bin/mknod -m 666 /dev/qadc%c c %d 0\n", n++, $1}' /proc/devices`
}


function adc_stop()
{
    /sbin/modprobe -r pcie_adc && \
        test -e /dev/qadc[0-9]* && /bin/rm -f /dev/qadc[0-9]*
}


case "$1" in
    start)
        adc_start
        exit 0
    ;;

    stop)
        adc_stop
        exit 0
    ;;

    restart)
        adc_stop
        adc_start
        exit 0
    ;;

    *)
        echo "Error: argument '$1' not supported." >&2
        exit 0
    ;;
esac


