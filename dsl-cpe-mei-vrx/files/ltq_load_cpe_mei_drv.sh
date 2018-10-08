#!/bin/sh /etc/rc.common
# Copyright (C) 2015 OpenWrt.org
DebugLevel=3

BIN_DIR=@dsl_bin_dir@

# Default configuration for values that will be overwritten with external
# values defined within "dsl_auto.cfg.

start() {
	[ -z "`cat /proc/modules | grep ifxos`" ] && {
		echo "Ooops - IFXOS isn't loaded, MEI Driver will do it. Check your basefiles..."
		insmod /lib/modules/*/drv_ifxos.ko
	}

	# Temporary workaround for missing FAPI implementation
	[ -n "`lspci -n | grep 1bef:0020`" ] && {
		echo "VRX318 TC inserted"
		insmod /lib/modules/*/vrx318.ko
		insmod /lib/modules/*/vrx318_tc.ko
	}
	
	[ -n "`lspci -n | grep 8086:09a9`" ] && {
		echo "VRX518 TC inserted"
	insmod /lib/modules/*/vrx518.ko
	insmod /lib/modules/*/vrx518_tc.ko
	}
	
	
	if [ -r ${BIN_DIR}/dsl.cfg ]; then
		. ${BIN_DIR}/dsl.cfg 2> /dev/null
	fi

	if [ "$xDSL_Dbg_DebugLevel" != "" ]; then
		DebugLevel="${xDSL_Dbg_DebugLevel}"
	else
		if [ -e ${BIN_DIR}/debug_level.cfg ]; then
			# read in the global definition of the debug level
			. ${BIN_DIR}/debug_level.cfg 2> /dev/null

			if [ "$ENABLE_DEBUG_OUTPUT" != "" ]; then
				DebugLevel="${ENABLE_DEBUG_OUTPUT}"
			fi
		fi
	fi

	# Get environment variables for system related configuration
	if [ -r ${BIN_DIR}/dsl_auto.cfg ]; then
		. ${BIN_DIR}/dsl_auto.cfg 2> /dev/null
	fi

	# loading VDSL MEI Driver -
	cd ${BIN_DIR}
	${BIN_DIR}/inst_drv_mei_cpe.sh $DebugLevel
}

stop() {
	rmmod drv_mei_cpe.ko

	if [ -r ${BIN_DIR}/dsl.cfg ]; then
		. ${BIN_DIR}/dsl.cfg 2> /dev/null
	fi

	if [ "${xDSL_Cfg_LdAfeShutdown}" == "1" ]; then
		[ -n "`lspci -n | grep 1bef:0020`" ] && {
			echo "vrx318 modules removing"
			rmmod vrx318_tc
			rmmod vrx318
		}

		[ -n "`lspci -n | grep 8086:09a9`" ] && {
			echo "vrx518 modules removing"
			rmmod vrx518_tc
			rmmod vrx518
		}
	fi
}
