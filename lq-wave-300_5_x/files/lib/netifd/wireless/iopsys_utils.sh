#!/bin/sh

wlan2_list="wlan2.1 wlan2.2 wlan2.3 wlan2.4"
wlan0_list="wlan0.1 wlan0.2 wlan0.3 wlan0.4"

wlan2_idlist=
wlan2_nowlist=
wlan2_freelist=

wlan0_idlist=
wlan0_nowlist=
wlan0_freelist=

idlist=
freelist=

wdevs="wlan0 wlan2"

_update_used_ifs() {
	local i
	local ret
	local d
	local v
	local vnos="0 1 2 3 4 5 6 7 8"

	uci reload wireless
	i=0
	#while [ $i -lt 8]; do
	for i in ${vnos}; do
		d=$(uci get wireless.@wifi-iface[$i].device)
		v=$(uci get wireless.@wifi-iface[$i].ifname)
		ret="$?"
		[ "$ret" = "0" ] && {
			[ "$d" = "$v" ] || {
				eval nowlist=\${${d}_nowlist}
				nowlist="$nowlist $v"
				eval ${d}_nowlist=\${nowlist}
				#echo "<$d> Used VIFs: $nowlist" > /dev/console
			}
		}
		#i=$((i+1))
	done
}

_update_free_ifs() {
	local i
	local j

	wlan2_freelist=$wlan2_list
	wlan0_freelist=$wlan0_list

	for i in $wdevs; do
		eval freelist=\${${i}_freelist}
		eval nowlist=\${${i}_nowlist}
		for j in $nowlist; do
			freelist="${freelist/$j}"
		done

		eval ${i}_idlist=\${freelist}
		#echo "<$i> Free VIFs: ${i}_idlist = $freelist" > /dev/console
	done
}

wifi_generate_ifname() {
	_update_used_ifs
	_update_free_ifs

	local iftmp
	local i

	eval idlist=\${$1_idlist}
	for i in $idlist; do
		iftmp=$i
		break
	done

	idlist="${idlist/$iftmp}"
	eval $1_idlist=\${idlist}
	echo $iftmp

	local vnos="0 1 2 3 4 5 6 7 8"

	for i in ${vnos}; do
		d=$(uci get wireless.@wifi-iface[$i].device)
		v=$(uci get wireless.@wifi-iface[$i].ifname)
		ret="$?"
		[ "$ret" = "1" ] && {
			[ -n "$d" -a "$d" == "$1" ] && {
				uci -q set wireless.@wifi-iface[$i].ifname="$iftmp"
				uci commit wireless
				uci reload wireless
				return
			}
		}
	done
}

remove_from_networks() {
	local iface=$1
	local ifname=""

	for net in $(uci show network | grep network.*.interface | awk -F'[.,=]' '{print$2}' | tr '\n' ' '); do
		ifname=""
		for ifc in $(uci -q get network.$net.ifname); do
			if [ "$ifc" != "$iface" ]; then
				ifname="$ifname $ifc"
			fi
		done
		uci -q set network.$net.ifname="$(echo $ifname | sed 's/[ \t]*$//')"
		uci commit network
	done
}

remove_disabled_vifs() {
	local cfg=$1
	local vif=$2

	config_get is_lan $cfg is_lan "0"
	config_get type $cfg type

	[ "$is_lan" == "0" -o  "$type" != "bridge" ] && return

	ifname=$(uci -q get network.$cfg.ifname)

	for ifc in $ifname; do
		[ -n "${ifc/wlan*/}" ] && continue

		vif_cfg=$(uci show wireless | grep @wifi-iface | grep "ifname=\'$ifc\'" | awk -F '.' '{print $2}')

		device=$(uci -q get wireless.$vif_cfg.device)
		radio_disabled=$(uci -q get wireless.$device.disabled)
		disabled=$(uci -q get wireless.$vif_cfg.disabled)
		net=$(uci -q get wireless.$vif_cfg.network)
		[ "$disabled" == "1" -o "$net" != "$cfg" -o "$radio_disabled" == "1" -o -z "$vif_cfg" ] || continue

		remove_from_networks $ifc
	done
}

network_remove_disabled_vifs() {
	config_load network
	config_foreach remove_disabled_vifs interface
}

add_to_network() {
	local cfg=$1
	local nets=$2
	local iface=""
	local ifname=""

	config_get network $cfg network
	config_get iface $cfg ifname
	config_get disabled $cfg disabled "0"

	[ -n "$iface" ] || return

	[ "$disabled" == "1" ] && return

	config_get device $cfg device
	radio_disabled=$(uci -q get wireless.$device.disabled)
	[ "$radio_disabled" == "1" ] && return

	for net in $nets; do
		is_lan="$(uci -q get network.$net.is_lan)"
		is_lan=${is_lan:-0}
		type="$(uci -q get network.$net.type)"

		[ "$is_lan" == "1" -a "$type" == "bridge" ] || continue

		ifname="$(uci -q get network.$net.ifname)"
		if [ "$net" == "$network" ]; then
			ifname="$ifname $iface"
		fi

		uci -q set network.$net.ifname="$(echo $ifname | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/[ \t]*$//')"
	done
	uci commit network
}

network_add_vifs() {
	nets=$(uci show network | grep network.*.interface | awk -F'[.,=]' '{print$2}')

	config_load wireless
	config_foreach add_to_network wifi-iface "$nets"
}