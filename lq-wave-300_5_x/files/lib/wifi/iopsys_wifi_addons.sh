#!/bin/sh

remove_from_networks() {
	local iface=$1
	local ifname=""

	echo removing iface=$iface > /dev/console

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

	config_load network
	config_get is_lan $cfg is_lan "0"
	config_get type $cfg type

	[ "$is_lan" == "0" -o  "$type" != "bridge" ] && return

	ifname=$(uci -q get network.$cfg.ifname)

	for ifc in $ifname; do
		vif_cfg=$(uci show wireless | grep @wifi-iface | grep "ifname=\'$ifc\'" | awk -F '.' '{print $2}')

		device=$(uci -q get wireless.$vif_cfg.device)
		radio_disabled=$(uci -q get wireless.$device.disabled)
		disabled=$(uci -q get wireless.$vif_cfg.disabled)
		net=$(uci -q get wireless.$vif_cfg.network)
		[ "$disabled" == "1" -o "$net" != "$cfg" -o "$radio_disabled" == "1" ] || continue

		if [ $ifc == $vif ]; then
			#echo "wifi: remove $ifc from $interface" >/dev/console
			remove_from_networks $interface $ifc
			break
		fi
	done
}

add_to_network() {
	local cfg=$1
	local iface=""
	local ifname=""

	config_get network $cfg network
	config_get iface $cfg ifname
	config_get disabled $cfg disabled "0"

	[ "$disabled" == "1" ] && return

	config_get device $cfg device
	radio_disabled=$(uci -q get wireless.$device.disabled)
	[ "$radio_disabled" == "1" ] && return

	for net in $(uci show network | grep network.*.interface | awk -F'[.,=]' '{print$2}'); do
		echo net=$net > /dev/console
		is_lan="$(uci -q get network.$net.is_lan)"
		is_lan=${is_lan:-0}
		type="$(uci -q get network.$net.type)"

		echo is_lan=$is_lan type=$type > /dev/console

		[ "$is_lan" == "1" -a "$type" == "bridge" ] || continue

		ifname="$(uci -q get network.$net.ifname)"
		if [ "$net" == "$network" ]; then
			ifname="$ifname $iface"
		fi

		uci -q set network.$net.ifname="$(echo $ifname | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/[ \t]*$//')"
	done
	uci commit network
}

wifi_add_section_status() {
	if ! uci -q get wireless.status >/dev/null; then
		[ -f /etc/config/wireless ] || touch /etc/config/wireless

		uci -q add wireless wifi-status
		uci -q rename wireless.@wifi-status[-1]=status
		uci -q set wireless.status.wlan=1
		uci -q commit wireless
	fi
}

wifi_add_section_bandsteering() {
	if ! uci -q get wireless.bandsteering >/dev/null; then
		[ -f /etc/config/wireless ] || touch /etc/config/wireless

		uci -q add wireless bandsteering
		uci -q rename wireless.@bandsteering[-1]=bandsteering
		uci -q set wireless.bandsteering.enabled=0
		uci -q set wireless.bandsteering.policy=0
		uci -q commit wireless
	fi
}
