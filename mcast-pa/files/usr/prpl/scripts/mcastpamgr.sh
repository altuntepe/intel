#!/bin/bash 
###############################################################################
#               _____                      _  ______ _____                    #
#              /  ___|                    | | | ___ \  __ \                   #
#              \ `--. _ __ ___   __ _ _ __| |_| |_/ / |  \/                   #
#               `--. \ '_ ` _ \ / _` | '__| __|    /| | __                    #
#              /\__/ / | | | | | (_| | |  | |_| |\ \| |_\ \                   #
#              \____/|_| |_| |_|\__,_|_|   \__\_| \_|\____/ Inc.              #
#                                                                             #
###############################################################################
#                                                                             #
#                       copyright 2018 by SmartRG, Inc.                       #
#                              Santa Barbara, CA                              #
#                                                                             #
###############################################################################
#                                                                             #
# Author: tim.hayes@smartrg.com                                               #
#                                                                             #
# Purpose: Control mcast-pa based on start/stop and hotplug events            #
#                                                                             #
###############################################################################
. /lib/functions.sh
export LD_LIBRARY_PATH=/opt/lantiq/lib:/opt/lantiq/usr/lib:${LD_LIBRARY_PATH}

PPA_RUN_FILE="/tmp/mcastppamode"

cfg=""
wan=""
bridged=0
model=0

setcfg() {
	cfg=$1
}

setup_mcpd_config() {
	# valid modes are: bridged | video2lan | wan2lan 
	local iptv_mode
	local igmp_v2

	config_load iptv
	config_foreach setcfg iptv
	config_get iptv_mode $cfg mode
	config_foreach setcfg igmp
	config_get igmp_v2 $cfg "force_v2"

	# set mcpd proxy mode
	if [ "$iptv_mode" = "video2lan" ] ; then
		wan=$(uci get network.video.ifname)
		wan=$(echo $wan | grep -o 'wan[a-zA-Z0-9,-,.]*')
		model=1
		echo video2lan $wan
	elif [ "$iptv_mode" = "wan2lan" ] ; then
		wan=$(uci get network.wan.ifname)
		echo wan2lan upif $wan
		model=0
	elif [ "$iptv_mode" = "bridged" ] ; then
		wan=$(uci get network.video.ifname)
		wan=$(echo $wan | grep -o 'wan[a-zA-Z0-9,-,.]*')
		bridged=1
		echo bridged
		model=2
	else
		logger -p info -t "iptv" "setup_mcpd_config(): bad iptv mode: $iptv_mode"	
	fi

	logger -p info -t "mcastpamgr" "setup_mcpd_config mcproxy restarted()"
}

start() {
	logger -p info -t "mcastpamgr" "start_service()"

	if [ -e /tmp/mcastpa-dump ]; then
		rm /tmp/mcastpa-dump
	fi

	killall mcast-pa 

	setup_mcpd_config
	case $model in 
	0)
	switch_cli GSW_MULTICAST_SNOOP_CFG_SET dev=0 eIGMP_Mode=2 eForwardPort=3 nForwardPortId=0
	mcast-pa --wan $wan 
	;;
	1)
	switch_cli GSW_MULTICAST_SNOOP_CFG_SET dev=0 eIGMP_Mode=2 eForwardPort=3 nForwardPortId=0
	mcast-pa --wan $wan --video2lan br-video  
	;;
	2)
	switch_cli GSW_MULTICAST_SNOOP_CFG_SET dev=0 eIGMP_Mode=2 eForwardPort=3 nForwardPortId=0
	mcast-pa --wan $wan --bridge br-video
	;;
	3)
	switch_cli GSW_MULTICAST_SNOOP_CFG_SET dev=0 eIGMP_Mode=2 eForwardPort=3 nForwardPortId=0
	mcast-pa --wan $wan --bridge br-lan
	;;
	esac
	
	touch $PPA_RUN_FILE
}

boot() {
	rmmod mcast_helper
	logger -p info -t "mcastmgrpa" "boot()"
}

stop() {
	logger -p info -t "mcastmgrpa" "stop"
	killall mcast-pa 
	rm $PPA_RUN_FILE
}

iptv_start() {
	local iptv_diff="x"
	local network_diff="x"
#
# hotplug can restart iptv because we have a new ip address 
# only restart mcast-pa if the config has changed
#
# we could use md5 check sum but the diff is useful in seeing the differences
#

	mode=$(uci get operating-mode.settings.current_mode)
	if [ "$mode" == "ap" ]; then
		logger -p info -t "mcastmgrpa.sh iptv_start" "apmode restart "
		start
		return
	fi

	if [ -e /tmp/iptv.config ]; then
		iptv_diff=$(diff /tmp/iptv.config /etc/config/iptv) 
		if [ -z $iptv_diff ]; then 
			logger -p info -t "mcastmgrpa.sh iptv_start" "no iptv diff "
		fi
	fi
	if [ -e /tmp/network.config ]; then
		network_diff=$(diff /tmp/network.config /etc/config/network) 
		if [ -z $network_diff ]; then 
			logger -p info -t "mcastmgrpa.sh iptv_start" "no network diff "
		fi
	fi
	if [ -z $iptv_diff ] && [ -z $network_diff ]; then 
		return;
	fi
	start
	cp /etc/config/iptv /tmp/iptv.config
	cp /etc/config/network /tmp/network.config
	logger -p info -t "mcastmgrpa.sh iptv_start" "started"
}

iptv_stop() {
#
# hotplug can restart iptv because we have a new ip address 
# only restart mcast-pa if the config has changed
#
	local iptv_diff="x"
	local network_diff="x"

	mode=$(uci get operating-mode.settings.current_mode)
	if [ "$mode" == "ap" ]; then
		logger -p info -t "mcastmgrpa.sh iptv_stop" "apmode restart "
		stop
		return
	fi
	if [ -e /tmp/iptv.config ]; then
		iptv_diff=$(diff /tmp/iptv.config /etc/config/iptv) 
		if [ -z $iptv_diff ]; then 
			logger -p info -t "mcastmgrpa.sh iptv_stop" "no iptv diff "
		fi
	fi
	if [ -e /tmp/network.config ]; then
		network_diff=$(diff /tmp/network.config /etc/config/network) 
		if [ -z $network_diff ]; then 
			logger -p info -t "mcastmgrpa.sh iptv_start" "no network diff "
		fi
	fi
	if [ -z $iptv_diff ] && [ -z $network_diff ]; then 
		return;
	fi
	stop
	logger -p info -t "mcastmgrpa.sh iptv_start" "stopped"
}

show() {
	if [ -e /var/run/mcast-pa.pid ]; then
		pid=$(cat /var/run/mcast-pa.pid)
		kill -USR1 $pid
		echo " "
	fi

	echo " "
	echo "ip route: "
	echo " "
	ip route
	echo " "

	echo " "
	echo "ip mroute: "
	echo " "
	ip mroute
	echo " "

	echo " "
	echo "brctl show: "
	echo " "
	brctl show
	echo " "

	echo " "
	echo "bridge mdb: "
	echo " "
	bridge mdb
	echo " "

	echo "cat /proc/mcast_helper: "
	echo " "
	cat /proc/mcast_helper
	echo " "

	echo "ppacmd getmcgroups: "
	echo " "
	ppacmd getmcgroups
	echo " "

	echo "dmesg | grep mcast: "
	echo " "
	dmesg | grep mcast
	echo " "

	echo "ps lax | grep mcast-pa"
	echo " "
	ps lax | grep mcast-pa
	echo " "

	echo " "
       echo "logread | grep mcast | tail -n 20"	
	echo " "
       logread | grep mcast | tail -n 20	
	echo " "
      	if [ -e /tmp/mcastpa-dump ]; then
      		cat /tmp/mcastpa-dump
	fi
	echo " "

}

vsacfg() {
	if [ $# -ne 3 ]; then
		echo "wrong number of args should be 3 got $@"
		return
	fi
	op=$1
	group=$2
	device=$3
	echo "$op $group $device" > /tmp/vsapa.cfg
	if [ -e /var/run/mcast-pa.pid ]; then
		pid=$(cat /var/run/mcast-pa.pid)
		kill -USR2 $pid
	fi

}


#
# for software video bridge just exit
#
# exit 0

cmd=" "

if [ $# -eq 0 ]; then
        logger -p info -t "mcastmgrpa.sh" "no args OK "
else
        cmd=$1
        case $cmd in 
        iptv_start)
	 iptv_start
        ;;
        iptv_stop)
	 iptv_stop
        ;;
        start)
	 start
        ;;
        stop)
	 stop
        ;;
        boot)
	 boot
        ;;
        show)
	 show
        ;;
        vsacfg)
	 shift
	 vsacfg $@
        ;;
        *)
        logger -p info -t "mcastmgrpa.sh" "unrecognized cmd $cmd"
        exit 0
        ;;
        esac
fi
