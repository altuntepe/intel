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
