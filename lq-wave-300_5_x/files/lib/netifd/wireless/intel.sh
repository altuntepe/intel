#!/bin/sh
. /lib/netifd/netifd-wireless.sh
. /lib/netifd/hostapd.sh
. /lib/netifd/wireless/iopsys_fixup_hwmode.sh
. /lib/netifd/wireless/iopsys_utils.sh

init_wireless_driver "$@"

drv_intel_init_device_config() {
	hostapd_common_add_device_config

	config_add_string path phy 'macaddr:macaddr'
	config_add_string hwmode band
	config_add_int beacon_int chanbw bandwidth frag rts
	config_add_int rxantenna txantenna antenna_gain txpower distance
	config_add_boolean noscan dfsc
	config_add_array ht_capab
	config_add_array channels
	config_add_boolean \
		rxldpc \
		short_gi_80 \
		short_gi_160 \
		tx_stbc_2by1 \
		su_beamformer \
		su_beamformee \
		mu_beamformer \
		mu_beamformee \
		vht_txop_ps \
		htc_vht \
		rx_antenna_pattern \
		tx_antenna_pattern
	config_add_int vht_max_a_mpdu_len_exp vht_max_mpdu vht_link_adapt vht160 rx_stbc tx_stbc
	config_add_boolean \
		ldpc \
		greenfield \
		short_gi_20 \
		short_gi_40 \
		max_amsdu \
		dsss_cck_40
	config_add_boolean wmm_apsd atf
}

drv_intel_init_iface_config() {
	hostapd_common_add_bss_config

	config_add_string 'macaddr:macaddr' ifname

	config_add_boolean powersave
	config_add_int maxassoc
	config_add_int max_listen_int
	config_add_int dtim_period
	config_add_int start_disabled
}

intel_add_capabilities() {
	local __var="$1"; shift
	local __mask="$1"; shift
	local __out= oifs

	oifs="$IFS"
	IFS=:
	for capab in "$@"; do
		set -- $capab

		[ "$(($4))" -gt 0 ] || continue
		[ "$(($__mask & $2))" -eq "$((${3:-$2}))" ] || continue
		__out="$__out[$1]"
	done
	IFS="$oifs"

	export -n -- "$__var=$__out"
}

intel_setup_atf() {
	atf_conf_file="/var/run/atf-$1.conf"

	cat >> "$atf_conf_file" <<EOF
#[<vap_name>]
debug=1
distr_type=1
algo_type=1
weighted_type=0
#interval
#free_time
vap_enabled=0
station_enabled=0
#vap_grant

EOF
	append base_cfg "atf_config_file=$atf_conf_file" "$N"
}

intel_hostapd_setup_base() {
	local phy="$1"

	json_select config

	[ "$auto_channel" -gt 0 ] && {
		channel=acs_smart
		append base_cfg "acs_num_scans=1" "$N"
	}

	[ "$auto_channel" -gt 0 ] && json_get_values channel_list channels

	json_get_vars noscan dfsc
	json_get_values ht_capab_list ht_capab

	#echo "band = $band  bw = $bandwidth  hwmode = $hwmode" > /dev/console
	#echo "dfsc = $dfsc" > /dev/console

	[ "$atf" -eq 1 ] && intel_setup_atf $phy

	ieee80211n=
	ht_capab=
	[ "$auto_channel" -gt 0 ] && ch=auto || ch=$channel
	fixup_hwmode_band_${band} $hwmode $ch $bandwidth

	[ -n "$ieee80211n" ] && {
		append base_cfg "ieee80211n=1" "$N"

		json_get_vars \
			ldpc:1 \
			greenfield:0 \
			short_gi_20:1 \
			short_gi_40:1 \
			tx_stbc:1 \
			rx_stbc:3 \
			max_amsdu:1 \
			dsss_cck_40:1

		ht_cap_mask=0
		for cap in $(iw phy "$phy" info | grep 'Capabilities:' | cut -d: -f2); do
			ht_cap_mask="$(($ht_cap_mask | $cap))"
		done

		cap_rx_stbc=$((($ht_cap_mask >> 8) & 3))
		[ "$rx_stbc" -lt "$cap_rx_stbc" ] && cap_rx_stbc="$rx_stbc"
		ht_cap_mask="$(( ($ht_cap_mask & ~(0x300)) | ($cap_rx_stbc << 8) ))"

		intel_add_capabilities ht_capab_flags $ht_cap_mask \
			LDPC:0x1::$ldpc \
			GF:0x10::$greenfield \
			SHORT-GI-20:0x20::$short_gi_20 \
			SHORT-GI-40:0x40::$short_gi_40 \
			TX-STBC:0x80::$tx_stbc \
			RX-STBC1:0x300:0x100:1 \
			RX-STBC12:0x300:0x200:1 \
			RX-STBC123:0x300:0x300:1 \
			MAX-AMSDU-7935:0x800::$max_amsdu \
			DSSS_CCK-40:0x1000::$dsss_cck_40

		ht_capab="$ht_capab$ht_capab_flags"
		[ -n "$ht_capab" ] && append base_cfg "ht_capab=$ht_capab" "$N"
	}


	ieee80211ac=0
	[ "$auto_channel" -gt 0 ] && ch=auto
	fixup_hwmode_band_${band} $hwmode $ch $bandwidth

	if [ "$ieee80211ac" != "0" ]; then
		[ -n $vht_oper_chwidth ] && {
			append base_cfg "vht_oper_chwidth=${vht_oper_chwidth}" "$N"
		}
		[ -n $vht_oper_centr_freq_seg0_idx ] && {
			append base_cfg "vht_oper_centr_freq_seg0_idx=${vht_oper_centr_freq_seg0_idx}" "$N"
		}
	fi

	if [ "$ieee80211ac" != "0" ]; then
		json_get_vars \
			rxldpc:1 \
			short_gi_80:1 \
			short_gi_160:1 \
			tx_stbc_2by1:1 \
			su_beamformer:1 \
			su_beamformee:1 \
			mu_beamformer:1 \
			mu_beamformee:1 \
			vht_txop_ps:1 \
			htc_vht:1 \
			rx_antenna_pattern:1 \
			tx_antenna_pattern:1 \
			vht_max_a_mpdu_len_exp:7 \
			vht_max_mpdu:11454 \
			rx_stbc:4 \
			vht_link_adapt:3 \
			vht160:2

		append base_cfg "ieee80211ac=1" "$N"
		vht_cap=0
		for cap in $(iw phy "$phy" info | awk -F "[()]" '/VHT Capabilities/ { print $2 }'); do
			vht_cap="$(($vht_cap | $cap))"
		done

		cap_rx_stbc=$((($vht_cap >> 8) & 7))
		[ "$rx_stbc" -lt "$cap_rx_stbc" ] && cap_rx_stbc="$rx_stbc"
		vht_cap="$(( ($vht_cap & ~(0x700)) | ($cap_rx_stbc << 8) ))"

		intel_add_capabilities vht_capab $vht_cap \
			RXLDPC:0x10::$rxldpc \
			SHORT-GI-80:0x20::$short_gi_80 \
			SHORT-GI-160:0x40::$short_gi_160 \
			TX-STBC-2BY1:0x80::$tx_stbc_2by1 \
			SU-BEAMFORMER:0x800::$su_beamformer \
			SU-BEAMFORMEE:0x1000::$su_beamformee \
			MU-BEAMFORMER:0x80000::$mu_beamformer \
			MU-BEAMFORMEE:0x100000::$mu_beamformee \
			VHT-TXOP-PS:0x200000::$vht_txop_ps \
			HTC-VHT:0x400000::$htc_vht \
			RX-ANTENNA-PATTERN:0x10000000::$rx_antenna_pattern \
			TX-ANTENNA-PATTERN:0x20000000::$tx_antenna_pattern \
			RX-STBC-1:0x700:0x100:1 \
			RX-STBC-12:0x700:0x200:1 \
			RX-STBC-123:0x700:0x300:1 \
			RX-STBC-1234:0x700:0x400:1 \

		# supported Channel widths
		vht160_hw=0
		[ "$(($vht_cap & 12))" -eq 4 -a 1 -le "$vht160" ] && \
			vht160_hw=1
		[ "$(($vht_cap & 12))" -eq 8 -a 2 -le "$vht160" ] && \
			vht160_hw=2
		[ "$vht160_hw" = 1 ] && vht_capab="$vht_capab[VHT160]"
		[ "$vht160_hw" = 2 ] && vht_capab="$vht_capab[VHT160-80PLUS80]"

		# maximum MPDU length
		vht_max_mpdu_hw=3895
		[ "$(($vht_cap & 3))" -ge 1 -a 7991 -le "$vht_max_mpdu" ] && \
			vht_max_mpdu_hw=7991
		[ "$(($vht_cap & 3))" -ge 2 -a 11454 -le "$vht_max_mpdu" ] && \
			vht_max_mpdu_hw=11454
		[ "$vht_max_mpdu_hw" != 3895 ] && \
			vht_capab="$vht_capab[MAX-MPDU-$vht_max_mpdu_hw]"

		# maximum A-MPDU length exponent
		vht_max_a_mpdu_len_exp_hw=0
		[ "$(($vht_cap & 58720256))" -ge 8388608 -a 1 -le "$vht_max_a_mpdu_len_exp" ] && \
			vht_max_a_mpdu_len_exp_hw=1
		[ "$(($vht_cap & 58720256))" -ge 16777216 -a 2 -le "$vht_max_a_mpdu_len_exp" ] && \
			vht_max_a_mpdu_len_exp_hw=2
		[ "$(($vht_cap & 58720256))" -ge 25165824 -a 3 -le "$vht_max_a_mpdu_len_exp" ] && \
			vht_max_a_mpdu_len_exp_hw=3
		[ "$(($vht_cap & 58720256))" -ge 33554432 -a 4 -le "$vht_max_a_mpdu_len_exp" ] && \
			vht_max_a_mpdu_len_exp_hw=4
		[ "$(($vht_cap & 58720256))" -ge 41943040 -a 5 -le "$vht_max_a_mpdu_len_exp" ] && \
			vht_max_a_mpdu_len_exp_hw=5
		[ "$(($vht_cap & 58720256))" -ge 50331648 -a 6 -le "$vht_max_a_mpdu_len_exp" ] && \
			vht_max_a_mpdu_len_exp_hw=6
		[ "$(($vht_cap & 58720256))" -ge 58720256 -a 7 -le "$vht_max_a_mpdu_len_exp" ] && \
			vht_max_a_mpdu_len_exp_hw=7
		vht_capab="$vht_capab[MAX-A-MPDU-LEN-EXP$vht_max_a_mpdu_len_exp_hw]"

		# whether or not the STA supports link adaptation using VHT variant
		vht_link_adapt_hw=0
		[ "$(($vht_cap & 201326592))" -ge 134217728 -a 2 -le "$vht_link_adapt" ] && \
			vht_link_adapt_hw=2
		[ "$(($vht_cap & 201326592))" -ge 201326592 -a 3 -le "$vht_link_adapt" ] && \
			vht_link_adapt_hw=3
		[ "$vht_link_adapt_hw" != 0 ] && \
			vht_capab="$vht_capab[VHT-LINK-ADAPT-$vht_link_adapt_hw]"

		[ -n "$vht_capab" ] && append base_cfg "vht_capab=$vht_capab" "$N"
	fi

	### restore hwmode the way hostapd likes it
	if [ "$band" == "a" ]; then
		hwmode=a
	else
		hwmode=g
	fi
	###
	[ "$dfsc" == "0" -a "$band" == "a" ] && channel_list="36-48"

	hostapd_prepare_device_config "$hostapd_conf_file" nl80211
	cat >> "$hostapd_conf_file" <<EOF
${channel:+channel=$channel}
${channel_list:+chanlist=$channel_list}
${noscan:+noscan=$noscan}
$base_cfg

EOF
	json_select ..
}

intel_hostapd_setup_bss() {
	local phy="$1"
	local ifname="$2"
	local bssaddr="$3"
	local type="$4"

	hostapd_cfg=
	append hostapd_cfg "$type=$ifname" "$N"

	hostapd_set_bss_options hostapd_cfg "$vif" || {
		echo "hostapd_bss_options ERROR!" > /dev/console
		return 1
	}
	json_get_vars dtim_period max_listen_int start_disabled

	set_default start_disabled 0

	[ "$staidx" -gt 0 -o "$start_disabled" -eq 1 ] && append hostapd_cfg "start_disabled=1" "$N"

	cat >> /var/run/hostapd-$phy.conf <<EOF
$hostapd_cfg
bssid=$bssaddr
${dtim_period:+dtim_period=$dtim_period}
${max_listen_int:+max_listen_interval=$max_listen_int}
EOF
}

intel_get_addr() {
	local phy="$1"
	local idx="$(($2 + 1))"

	head -n $(($macidx + 1)) /sys/class/ieee80211/${phy}/addresses | tail -n1
}

intel_generate_mac() {
	local phy="$1"
	local id="${macidx:-0}"

	local ref="$(cat /sys/class/ieee80211/${phy}/macaddress)"
	local mask="$(cat /sys/class/ieee80211/${phy}/address_mask)"

	[ "$mask" = "00:00:00:00:00:00" ] && {
		mask="ff:ff:ff:ff:ff:ff";

		[ "$(wc -l < /sys/class/ieee80211/${phy}/addresses)" -gt 1 ] && {
			addr="$(intel_get_addr "$phy" "$id")"
			[ -n "$addr" ] && {
				echo "$addr"
				return
			}
		}
	}

	local oIFS="$IFS"; IFS=":"; set -- $mask; IFS="$oIFS"

	local mask1=$1
	local mask6=$6

	local oIFS="$IFS"; IFS=":"; set -- $ref; IFS="$oIFS"

	macidx=$(($id + 1))
	[ "$((0x$mask1))" -gt 0 ] && {
		b1="0x$1"
		[ "$id" -gt 0 ] && \
			b1=$(($b1 ^ ((($id - 1) << 2) | 0x2)))
		printf "%02x:%s:%s:%s:%s:%s" $b1 $2 $3 $4 $5 $6
		return
	}

	[ "$((0x$mask6))" -lt 255 ] && {
		printf "%s:%s:%s:%s:%s:%02x" $1 $2 $3 $4 $5 $(( 0x$6 ^ $id ))
		return
	}

	off2=$(( (0x$6 + $id) / 0x100 ))
	printf "%s:%s:%s:%s:%02x:%02x" \
		$1 $2 $3 $4 \
		$(( (0x$5 + $off2) % 0x100 )) \
		$(( (0x$6 + $id) % 0x100 ))
}

find_phy() {
	[ -n "$phy" -a -d /sys/class/ieee80211/$phy ] && {
		return 0
	}
	[ -n "$path" ] && {
		for phy in $(ls /sys/class/ieee80211 2>/dev/null); do
			case "$(readlink -f /sys/class/ieee80211/$phy/device)" in
				*$path) return 0;;
			esac
		done
	}
	[ -n "$macaddr" ] && {
		for phy in $(ls /sys/class/ieee80211 2>/dev/null); do
			grep -i -q "$macaddr" "/sys/class/ieee80211/${phy}/macaddress" && return 0
		done
	}
	return 1
}

intel_check_ap() {
	has_ap=1
}

intel_iw_interface_add() {
	local phy="$1"
	local ifname="$2"
	local type="$3"
	local rc


	iw dev | grep -q $ifname
	rc="$?"
	[ "$rc" = 0 ] && {
		#skip add interface if already there
		return $rc
	}


	iw phy "$phy" interface add "$ifname" type "$type"
	rc="$?"

	[ "$rc" = 233 ] && {
		# Device might have just been deleted, give the kernel some time to finish cleaning it up
		sleep 1

		iw phy "$phy" interface add "$ifname" type "$type"
		rc="$?"
	}

	[ "$rc" = 233 ] && {
		# Device might not support virtual interfaces, so the interface never got deleted in the first place.
		# Check if the interface already exists, and avoid failing in this case.
		ip link show dev "$ifname" >/dev/null 2>/dev/null && rc=0
	}

	[ "$rc" != 0 ] && wireless_setup_failed INTERFACE_CREATION_FAILED
	return $rc
}

intel_generate_bssid() {
	local ifmac=$1
	local incr=$2

	octet6=$(echo -n $ifmac | tail -c 2)
	ifmac=$(echo -n $ifmac | head -c 14)
	octet6=0x$octet6
	octet6=$(printf %X $((octet6 + incr)))
	ifmac=$(printf "%s:%s" $ifmac $octet6)
	echo $ifmac
}

intel_prepare_vif() {
	json_select config
	json_get_vars ifname mode ssid

	if_idx=$((${if_idx:-0} + 1))
	[ -n "$ifname" ] || {
		device=wlan${phy#phy}
		ifname="$(wifi_generate_ifname $device)"
	}

	set_default powersave 0

	#json_select ..

	[ -n "$macaddr" ] || {
		macaddr="$(intel_generate_mac $phy)"
		macidx="$(($macidx + 1))"
	}

	[ "$uapsd" -eq 0 ] && json_add_boolean uapsd 0

	#json_add_object data
	#json_add_string ifname "$ifname"
	#json_close_object
	#json_select config

	# It is far easier to delete and create the desired interface
	case "$mode" in
		ap)
			# Hostapd will handle recreating the interface and
			# subsequent virtual APs belonging to the same PHY
			bssid=
			if [ -n "$hostapd_ctrl" ]; then
				type=bss
				bssid=$(intel_generate_bssid $macaddr $if_idx)
			else
				type=interface
				bssid=$macaddr
			fi

			intel_hostapd_setup_bss "$phy" "$ifname" "$bssid" "$type" || {
				echo "intel_hostap_setup_bss() ret ERROR!" > /dev/console
				return
			}

			[ -n "$hostapd_ctrl" ] || {
				intel_iw_interface_add "$phy" "$ifname" __ap || {
					[ "$?" = 1 ] || return
				}
				hostapd_ctrl="${hostapd_ctrl:-/var/run/hostapd/$ifname}"
			}
		;;
	esac

	json_select ..
}

intel_setup_vif() {
	local name="$1"
	local failed

	json_select config
	json_get_vars ifname

	json_get_vars mode
	json_get_var vif_txpower txpower

	ip link set dev "$ifname" up || {
		wireless_setup_vif_failed IFUP_ERROR
		json_select ..
		return
	}

	set_default vif_txpower "$txpower"
	[ -z "$vif_txpower" ] || iw dev "$ifname" set txpower fixed "${vif_txpower%%.*}00"

	json_select ..
	[ -n "$failed" ] || wireless_add_vif "$name" "$ifname"
}

get_freq() {
	local phy="$1"
	local chan="$2"
	iw "$phy" info | grep -E -m1 "(\* ${chan:-....} MHz${chan:+|\\[$chan\\]})" | grep MHz | awk '{print $2}'
}

intel_interface_cleanup() {
	local phy="$1"

	for wdev in $(list_phy_interfaces "$phy"); do
		ip link set dev "$wdev" down 2>/dev/null
		#hostapd will remove bss-ifs
		#iw dev "$wdev" del
	done
}

drv_intel_cleanup() {
	hostapd_common_cleanup
}

ifname_fixup() {
	local radio vifno vn vdev
	local vnos="0 1 2 3 4 5 6 7"

	for radio in "wlan0" "wlan2"; do
		vifno=0
		for vn in $vnos; do
			vdev="$(uci get wireless.@wifi-iface[$vn].device)"
			[ $vdev == "$radio" ] || continue
			if [ $vifno -eq 0 ]; then
				vifname="$vdev"
			else
				vifname="$vdev"."$vifno"
			fi
			vifno=$((vifno+1))
			uci -q set wireless.@wifi-iface[$vn].ifname="$vifname"
		done
	done
	uci -q commit wireless
}

drv_intel_setup() {
	json_select config
	json_get_vars \
		phy macaddr path \
		country chanbw distance bandwidth band \
		txpower antenna_gain \
		rxantenna txantenna \
		frag rts beacon_int:100 htmode wmm_apsd:1 atf:0
	json_get_values basic_rate_list basic_rate
	json_select ..

	find_phy || {
		echo "Could not find PHY for device '$1'"
		wireless_set_retry 0
		return 1
	}

	wireless_set_data phy="$phy"
	intel_interface_cleanup "$phy"

	# convert channel to frequency
	[ "$auto_channel" -gt 0 ] || freq="$(get_freq "$phy" "$channel")"

	[ -n "$country" ] && {
		iw reg get | grep -q "^country $country:" || {
			iw reg set "$country"
			sleep 1
		}
	}

	hostapd_conf_file="/var/run/hostapd-$phy.conf"
	atf_conf_file="/var/run/atf-$phy.conf"

	no_ap=1
	macidx=0
	staidx=0

	#set_default rxantenna all
	#set_default txantenna all
	#set_default distance 0
	#set_default antenna_gain 0

	#iw phy "$phy" set antenna $txantenna $rxantenna >/dev/null 2>&1
	#iw phy "$phy" set antenna_gain $antenna_gain
	#iw phy "$phy" set distance "$distance"

	[ -n "$frag" ] && iw phy "$phy" set frag "${frag%%.*}"
	[ -n "$rts" ] && iw phy "$phy" set rts "${rts%%.*}"

	has_ap=
	uapsd=${wmm_apsd}
	hostapd_ctrl=
	for_each_interface "ap" intel_check_ap

	rm -f "$hostapd_conf_file"
	rm -f "$atf_conf_file"
	[ -n "$has_ap" ] && intel_hostapd_setup_base "$phy"

	#ifname_fixup

	for_each_interface "ap" intel_prepare_vif

	[ -n "$hostapd_ctrl" ] && {
		/usr/sbin/hostapd -P /var/run/wifi-$phy.pid -B "$hostapd_conf_file"
		ret="$?"
		wireless_add_process "$(cat /var/run/wifi-$phy.pid)" "/usr/sbin/hostapd" 1
		[ "$ret" != 0 ] && {
			wireless_setup_failed HOSTAPD_START_FAILED
			return
		}
	}

	# FIXME: Anjan
	#for_each_interface "ap" intel_setup_vif

	wireless_set_up

	## +++iopsys
	ubus -t 5 call router.network reload
}

list_phy_interfaces() {
	local phy="$1"
	if [ -d "/sys/class/ieee80211/${phy}/device/net" ]; then
		ls "/sys/class/ieee80211/${phy}/device/net" 2>/dev/null;
	else
		ls "/sys/class/ieee80211/${phy}/device" 2>/dev/null | grep net: | sed -e 's,net:,,g'
	fi
}

drv_intel_teardown() {
	wireless_process_kill_all

	json_select data
	json_get_vars phy
	json_select ..

	intel_interface_cleanup "$phy"

	drv_intel_cleanup
}

add_driver intel
