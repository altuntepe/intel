#!/bin/sh /etc/rc.common
#
# Install Voice TAPI subsystem high level driver


START=30

KERNEL_VERSION=`uname -r | cut -d- -f1`
KERNEL_MAJOR=`uname -r | cut -f1,2 -d. | sed -e 's/\.//'`

# check for Linux 2.6 or higher
if [ $KERNEL_MAJOR -ge 26 ]; then
	MODEXT=.ko
fi

modules_dir=/lib/modules/${KERNEL_VERSION}
drv_obj_file_name=drv_tapi$MODEXT

start() {
	# load IFXOS if not already loaded
	[ -e ${modules_dir}/drv_ifxos$MODEXT ] &&
	[ -z `cat /proc/modules | grep '^drv_ifxos' | cut -f1 -d' '` ] && {
		insmod ${modules_dir}/drv_ifxos$MODEXT
	}
	# load SRTP if not already loaded
	[ -e ${modules_dir}/libsrtp$MODEXT ] &&
	[ -z `cat /proc/modules | grep '^libsrtp' | cut -f1 -d' '` ] && {
		insmod ${modules_dir}/libsrtp$MODEXT
	}
	# check for loading the eventlogger driver
	[ -e ${modules_dir}/drv_event_logger$MODEXT ] &&
	[ -z `cat /proc/modules | grep '^drv_event_logger' | cut -f1 -d' '` ] && {
		insmod ${modules_dir}/drv_event_logger$MODEXT
	}
	[ -e ${modules_dir}/${drv_obj_file_name} ] && {
		insmod ${modules_dir}/${drv_obj_file_name};
 	}
}

stop() {
	rmmod ${drv_obj_file_name}
	rmmod drv_event_logger
	rmmod libsrtp
}

