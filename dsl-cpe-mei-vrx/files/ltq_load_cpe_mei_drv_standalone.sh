#!/bin/sh /etc/rc.common
# Copyright (C) 2017 OpenWrt.org
#
# This script is just a small wrapper that bridges the standard OpenWRT handling
# with the handling that is used by UGW framework.
# It will/shall be only used in case of DSL related components from the
# UGW framework (FAPI/SL) are NOT used/included.

START=17

initd_dir=@dsl_init_dir@

start() {
	# In standalone mode FAPI/SL services are not in place so install
	# required modules here before continuing MEI Driver initialization 
	
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
	
	[ -f /lib/modules/*/directconnect_datapath.ko ] && {
		insmod /lib/modules/*/directconnect_datapath.ko
	}

	${initd_dir}/ltq_load_cpe_mei_drv.sh start
}

stop() {
	${initd_dir}/ltq_load_cpe_mei_drv.sh stop
}
