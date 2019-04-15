#!/bin/sh

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
