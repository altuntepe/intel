#!/bin/sh

. /lib/wifi/iopsys_wifi_addons.sh

append DRIVERS "intel"

HARDWARE=$(db -q get hw.board.hardware)
BASEMAC=$(db -q get hw.board.BaseMacAddr)

BASEMAC=${BASEMAC//:/}
ssid="$HARDWARE-$BASEMAC"
key="1234567890"
encryption="psk2"

wifi_interface_is_ap() {
	iw dev ${1} info | grep -q 'type AP'
}

wifi_device_get_macaddress() {
	local phydev=$1
	local netdev=$2

	echo $(cat /sys/class/ieee80211/$phydev/device/net/$netdev/address)
}

wifi_device_get_intparam() {
	local phydev=$1
	local netdev=$2
	local param=$3

	out=$(iw dev $netdev iwlwav $param)
	[ "$?" == "0" ] && {
		echo $out | sed -e s/${param}://
	}
}

wifi_get_radio_netdev() {
        local phy=$1

        for _netdev in /sys/class/ieee80211/${phy}/device/net/*; do
                [ -e "$_netdev" ] || continue

                netdev="${_netdev##*/}"
                echo "$netdev" && return
        done
}

check_phypath() {
	local path

	config_get path $1 path
	[ -n "$path" ] && [ "$path" == "$2" ] && {
		found_phypath=1
	}
	return 0
}

detect_intel_interfaces() {
	local phyname=$1
	local radio=$2

	for _vif in /sys/class/ieee80211/${1}/device/net/*; do
		[ -e "$_vif" ] || {
			continue
		}

		vif="${_vif##*/}"
		wifi_interface_is_ap $vif
		[ "$?" == "0" ] || {
			continue
		}

		hidden=$(wifi_device_get_intparam $phyname $vif gHiddenSSID)
		apfwd=$(wifi_device_get_intparam $phyname $vif gAPforwarding)
		[ "$apfwd" == "0" ] && isolate=1 || isolate=0

		uci -q add wireless wifi-iface
		uci -q set wireless.@wifi-iface[${ifidx}].device=${radio}
		uci -q set wireless.@wifi-iface[${ifidx}].ifname=${vif}
		uci -q set wireless.@wifi-iface[${ifidx}].mode=ap
		uci -q set wireless.@wifi-iface[${ifidx}].network=lan
		uci -q set wireless.@wifi-iface[${ifidx}].ssid=${ssid}
		uci -q set wireless.@wifi-iface[${ifidx}].hidden=${hidden}
		uci -q set wireless.@wifi-iface[${ifidx}].isolate=${isolate}
		uci -q set wireless.@wifi-iface[${ifidx}].encryption=${encryption}
		uci -q set wireless.@wifi-iface[${ifidx}].key=${key}
		uci -q commit wireless
		ifidx=$(($ifidx + 1))
	done
}

detect_intel() {
	devidx=0
	ifidx=0
	config_load wireless

	for _dev in /sys/class/ieee80211/*; do
		[ -e "$_dev" ] || continue

		dev="${_dev##*/}"
		radioname=$(wifi_get_radio_netdev ${dev})

		mode_band="g"
		channel="11"
		htmode=""
		ht_capab=""

		iw phy "$dev" info | grep -q 'Capabilities:' && htmode=HT20
		iw phy "$dev" info | grep -q '2412 MHz' || { mode_band="a"; channel="36"; }

		vht_cap=$(iw phy "$dev" info | grep -c 'VHT Capabilities')
		cap_5ghz=$(iw phy "$dev" info | grep -c "Band 2")
		[ "$vht_cap" -gt 0 -a "$cap_5ghz" -gt 0 ] && {
			mode_band="a";
			channel="36"
			htmode="VHT80"
		}

		[ -n "$htmode" ] && ht_capab="set wireless.${radioname}.htmode=$htmode"

		if [ -x /usr/bin/readlink -a -h /sys/class/ieee80211/${dev} ]; then
			path="$(readlink -f /sys/class/ieee80211/${dev}/device)"
		else
			path=""
		fi
		if [ -n "$path" ]; then
			path="${path##/sys/devices/}"
			case "$path" in
				platform*/pci*) path="${path##platform/}";;
			esac
			dev_id="set wireless.${radioname}.path='$path'"
		else
			dev_id="set wireless.${radioname}.macaddr=$(cat /sys/class/ieee80211/${dev}/macaddress)"
		fi

		found_phypath=0
		config_foreach check_phypath wifi-device $path
		[ $found_phypath -gt 0 ] && {
			devidx=$(($devidx + 1))
			continue
		}

		macaddr=$(wifi_device_get_macaddress $dev $radioname)
		beacon_int=$(wifi_device_get_intparam $dev $radioname gBeaconPeriod)
		country_ie=$(wifi_device_get_intparam $dev $radioname g11dActive)
		[ "$country_ie" == "1" ] && {
			country="DE"	## FIXME
		}

		## include iopsys addons
		wifi_add_section_status
		wifi_add_section_bandsteering

		uci -q batch <<-EOF
			set wireless.${radioname}=wifi-device
			set wireless.${radioname}.type=intel
			set wireless.${radioname}.channel=auto
			set wireless.${radioname}.hwmode=auto
			set wireless.${radioname}.macaddr=${macaddr}
			set wireless.${radioname}.beacon_int=${beacon_int}
			set wireless.${radioname}.country=${country}
			set wireless.${radioname}.country_ie=${country_ie}
			${dev_id}
			${ht_capab}
			set wireless.${radioname}.disabled=0
EOF
		[ "${mode_band}" == "a" ] && {
			uci set wireless.${radioname}.band=a
			uci set wireless.${radioname}.bandwidth=80
			uci set wireless.${radioname}.doth=1
			uci set wireless.${radioname}.dfsc=1
			uci set wireless.${radioname}.channels="36-48 52-64 100-112"
		} || {
			uci set wireless.${radioname}.band=b
			uci set wireless.${radioname}.bandwidth=20
			uci set wireless.${radioname}.doth=0
			uci set wireless.${radioname}.channels="1 6 11"
		}

		uci -q commit wireless
		config_load wireless

		detect_intel_interfaces $dev $radioname $ifidx
		devidx=$(($devidx + 1))
	done
}
