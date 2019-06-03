#!/bin/sh

_generate_ht_config() {
	ch=$1
	bw=$2

	ieee80211n=1
	if [ "$bw" -ge 40 ]; then
		[ "$ch" == "auto" -o "$ch" == "0" ] && \
			ht_capab="[HT40+][HT40-]" || {
				case "$ch" in
					36|44|52|60|100|108|116|124|132|149|157) ht_capab="[HT40+]";;
					40|48|56|64|104|112|120|128|136|153|161) ht_capab="[HT40-]";;
					1|2|3|4|5|6|7) ht_capab="[HT40+]";;
					8|9|10|11|12|13) ht_capab="[HT40-]";;
				esac
		}
	fi
}

_generate_vht_config() {
	ch=$1
	bw=$2

	ieee80211ac=1
	vht_oper_chwidth=
	vht_oper_centr_freq_seg0_idx=

	case "$bw" in
		40)
			vht_oper_chwidth=0
			[ "$ch" == "auto" -o "$ch" == "0" ] || {
				case "$(( ($ch / 4) % 2 ))" in
					1) idx=$(($ch + 2));;
					0) idx=$(($ch - 2));;
				esac
				vht_oper_centr_freq_seg0_idx=$idx
			}
		;;
		80)
			vht_oper_chwidth=1
			[ "$ch" == "auto" -o "$ch" == "0" ] || {
				case "$(( ($ch / 4) % 4 ))" in
					1) idx=$(($ch + 6));;
					2) idx=$(($ch + 2));;
					3) idx=$(($ch - 2));;
					0) idx=$(($ch - 6));;
				esac
				vht_oper_centr_freq_seg0_idx=$idx
			}
		;;
		160)
			vht_oper_chwidth=2
			[ "$ch" == "auto" -o "$ch" == "0" ] || {
				case "$ch" in
					36|40|44|48|52|56|60|64) idx=50;;
					100|104|108|112|116|120|124|128) idx=114;;
				esac
				vht_oper_centr_freq_seg0_idx=$idx
			}
		;;
	esac
}

fixup_hwmode_band_a() {
	std=$1
	ch=$2
	bw=$3

	echo "std = $std   ch = $ch   bw = $bw" > /dev/console

	case "$std" in
		auto|ac)
			_generate_ht_config $ch $bw
			_generate_vht_config $ch $bw
			;;
		n)
			_generate_ht_config $ch $bw
			;;
	esac
}

fixup_hwmode_band_b() {
	std=$1
	ch=$2
	bw=$3

	case "$std" in
		auto|n)
			_generate_ht_config $ch $bw
		;;
	esac
}
