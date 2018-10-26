#!/bin/sh /etc/rc.common
# Copyright (C) 2016 OpenWrt.org
#
# This script is just a small wrapper that bridges the standard OpenWRT handing
# with the handling that is used by UGW framework.
# It will/shall be only used in case of DSL related components from the
# UGW framework (FAPI/SL) are NOT used/included.

START=@start_seq@
initd_dir=@dsl_init_dir@

start() {
	${initd_dir}/ltq_cpe_control_init.sh start
}

stop() {
	${initd_dir}/ltq_cpe_control_init.sh stop
}
