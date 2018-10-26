#!/bin/sh /etc/rc.common
# Copyright (C) 2016 OpenWrt.org
#
# This script is just a small wrapper that bridges the standard OpenWRT handing
# with the handling that is used by UGW framework.
# It will/shall be only used in case of DSL related components from the
# UGW framework (FAPI/SL) are NOT used/included.

START=@start_seq@
initd_dir=@dsl_init_dir@

EXTRA_COMMANDS="dbg_on dbg_off"
EXTRA_HELP="	dbg_on	Enable debugging outputs \n
	dbg_off	Disable debugging outputs"

start() {
	${initd_dir}/ltq_load_dsl_cpe_api.sh start
}

stop() {
	${initd_dir}/ltq_load_dsl_cpe_api.sh stop
}

dbg_on() {
	${initd_dir}/ltq_load_dsl_cpe_api.sh dbg_on
}

dbg_off() {
	${initd_dir}/ltq_load_dsl_cpe_api.sh dbg_off
}
