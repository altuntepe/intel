#!/bin/sh /etc/rc.common
#
# Install Voice TAPI subsystem low level driver for VCODEC mailbox handling


START=30

KERNEL_VERSION=`uname -r`
KERNEL_MAJOR=`uname -r | cut -f1,2 -d. | sed -e 's/\.//'`

# check for Linux 2.6 or higher
if [ $KERNEL_MAJOR -ge 26 ]; then
	MODEXT=.ko
fi

modules_dir=/lib/modules/${KERNEL_VERSION}
drv_obj_file_name=drv_sdd_mbx$MODEXT

start() {
	[ -e ${modules_dir}/${drv_obj_file_name} ] && {
		insmod ${modules_dir}/${drv_obj_file_name};
	}
}

stop() {
   rmmod ${drv_obj_file_name}
}
