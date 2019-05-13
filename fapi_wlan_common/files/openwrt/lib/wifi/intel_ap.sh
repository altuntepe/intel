#!/bin/sh
append DRIVERS "intel_ap"
DEV_PREFIX=wlan

PATH=$PATH':/opt/intel/bin'
export PATH
LD_LIBRARY_PATH='/opt/intel/lib:/opt/intel/usr/lib'
export LD_LIBRARY_PATH

MAX_VAPS_PER_RADIO=16
START_VAPS_INDEX=6
MAX_FAPI_INDEX_SEARCH=128
PREV_UCI_CONF_FILE="/tmp/prev_uci_wireless_conf"

# Log Level, DTIM period definitions
MAX_LOG_LEVEL=4
DEFAULT_LOG_LEVEL=2
DEFAULT_DTIM_PERIOD=2
MAX_DTIM_PERIOD=255
MIN_DTIM_PERIOD=1

# Encryption definitions
DEFAULT_WEP_KEY_INDEX=1
MAX_WEP_KEYS=4
WEP_64_KEY_HEX_DIGIT_LENGTH=10
WEP_128_KEY_HEX_DIGIT_LENGTH=26
DEFAULT_ENCRYPTION_KEY="test_passphrase"
DEFAULT_RADIUS_SERVER_IP="127.0.0.0"
DEFAULT_RADIUS_SERVER_PORT=1812
DEFAULT_RADIUS_SERVER_KEY="test_passphrase"
DEFAULT_RADIUS_SERVER_WPA_REKEY_INTERVAL=600

error_flag=0
reload_required=0
detected_changes=""
index_realign_required=""

# ----------------------------- UTILITY FUNCTIONS ------------------------------

print()
{
	for i in $*; do 
		echo -n $i" " > /dev/console
	done
	echo " " > /dev/console
}

print_error()
{
	/usr/bin/logger -s -t "OpenWRT_FAPI" "$@"
	print "print_error: $@"
}

bool_to_str()
{
	local val=$1
	local res="false"

	if [[ $val -eq 0 ]]; then
		res="false"
	else
		res="true"
	fi

	echo $res
}

str_to_bool()
{
	local val=$1
	local res=0

	if [[ "$val" = "true" ]]; then
		res=1
	else
		res=0
	fi

	echo "$res"
}

is_hex_num()
{
	local hexNum=$1
	local val

	case $hexNum in
		''|*[!0-9A-Fa-f]*)
			val=0
			;;
		*)
			val=1
			;;
	esac

	echo "$val"
}

# Check whether 40+ width can be used for a given channel
can_use_above_channel()
{
	local ch=$1

	# When channel is auto, select secondary above, unless value must be secondary below
	secondary_channel="AboveControlChannel"
	if [ "$ch" != "auto" ]
	then
		secondary_channel="AboveControlChannel"
		case "$ch" in ("8"|"9"|"10"|"11"|"12"|"13"|"40"|"48"|"56"|"64"|"104"|"112"|"120"|"128"|"136"|"144"|"153"|"161")
			secondary_channel="BelowControlChannel"
			;;
		esac
	fi

	echo "$secondary_channel"

}

# This function gets a radio device (wlanX) and n params and chacks if
# any of the params have been changes compared to the data in the last saved
# configuration file
was_dev_param_changed(){
	local dev=$1
	local str
	shift
	SAVEIFS=$IFS
	
	# Is device in radio param list?
	uci show wireless | grep -q "^wireless\.${dev}=wifi-device$"
	if [[ $? -eq 0 ]]; then
		#device exists, check if parameter was changed
		for param_name in $@; do
			IFS=''
			echo $detected_changes | grep -q "^wireless\.${dev}\.${param_name}="
			if [[ $? -eq 0 ]]; then
				IFS=$SAVEIFS
				return 0
			fi
			IFS=$SAVEIFS
		done
	else
		# device not found, this is a new device
		return 0
	fi

	# none of the params were found in the list of change params
	return 1
}

# Checks if any of the parameters was changed for a given interface
was_iface_param_changed(){
	local iface=$1
	local str
	shift
	SAVEIFS=$IFS

	local if_name=`uci show wireless.${iface}.ifname | awk -F"=" '{print $2}'`
	str=`uci show wireless | grep "^wireless\.\@wifi-iface\[[0-9]*\]\.ifname=${if_name}$"`
	local idx=`echo $str | grep -o "\[[0-9]*\]" | tr -d "[]"`
	local res=`cat ${PREV_UCI_CONF_FILE}_wlan* | grep "^wireless\.\@wifi-iface\[[0-9]*\]\.ifname=${if_name}$"`
	if [ "$res" != "" ]; then
		#interface found in previous conf file
		for param_name in $@; do
			IFS=''
			echo $detected_changes | grep -q "^wireless\.@wifi-iface\[${idx}\].${param_name}="
			if [[ $? -eq 0 ]]; then
				IFS=$SAVEIFS
				return 0
			fi
			IFS=$SAVEIFS
		done
	else
		# new interface or device
		return 0
	fi
	
	# none of the params were found in list of change params
	return 1
}

# Update prev conf file (saved for future comparison for performance reasons)
# for a specific radio
update_prev_conf_file(){

	SAVEIFS=$IFS
	IFS=''
	local dev=$1
	local wireless_conf=`uci show wireless`
	local dev_conf=`echo $wireless_conf | grep "^wireless.${dev}[\.\=]"`

	echo $dev_conf > ${PREV_UCI_CONF_FILE}_$dev

	local vifs=`echo $wireless_conf | grep "^wireless.@wifi-iface\[[0-9]*\].device=${dev}$"`
	IFS=$SAVEIFS
	for cur_vif in $vifs; do
		IFS=''
		local idx=`echo $cur_vif | grep -o "\[[0-9]*\]" | tr -d "[]"`
		echo $wireless_conf | grep "^wireless\.@wifi-iface\[${idx}\]"  >> ${PREV_UCI_CONF_FILE}_$dev
	done
	IFS=$SAVEIFS

}


# removing interface might change the UCI unnamed section index
# need to update prev_vonf file accordingly
realign_iface_idx_in_prev_conf(){
	SAVE_IFS=$IFS
	IFS=''
	local curr_ifaces=`uci show wireless | grep "^wireless\.@wifi-iface\[[0-9]*\]\.ifname="`

	IFS=$SAVE_IFS
	for iface in $curr_ifaces; do
		local iface_name=`echo $iface | grep -o "wlan.*"`

		local idx=`echo $iface  | grep -o "\[[0-9]*\]" | tr -d "[]"`

		for file in ${PREV_UCI_CONF_FILE}_wlan*; do
			IFS=''
			local conf_idx=`cat $file | grep "^wireless\.@wifi-iface\[[0-9]*\]\.ifname=${iface_name}$"`
			if [ "$conf_idx" == "" ]; then
				# echo "index was not found in conf file $file"
				continue
			else
				# echo "index was found in conf file $file"
				conf_idx=`echo $conf_idx | grep -o "\[[0-9]*\]" | tr -d "[]"`

				# is current index the same as the index in the previous file we've saved?
				if [ $conf_idx != $idx ]; then
					print "UCI interface idx $conf_idx in $file has changed to $idx, need to update file"
					sed -i "s/^wireless\.@wifi-iface\[${conf_idx}/wireless\.@wifi-iface\[${idx}/g" "$file"
				fi
			fi

		IFS=$SAVE_IFS
		done
	done
	IFS=$SAVE_IFS
}

get_fapi_ret_val() {
	local ret=$@

	eval "local value=\${ret##*=}"
	eval "local val=\${value%%retVal*}"

	echo $val
}

is_fapi_command_fail() {
	local funcRet=$1
	local ret_str=$2
	local command=$3

	# TODO: add a check to see which function was called (after main Entry command = getChannel and before FAPI_WLAN_COMMON)
	# eval "local value=\${ret##*=}"
	# eval "local val=\${value%%retVal*}"
	
	if [[ $funcRet -ne 0 ]]; then
		# fapi command totally failed
		print_error "$command FAILED"
		return 1
	fi

	if [[ ! -n "$ret_str" ]]; then
		print_error "$command FAILED"
		return 1
	fi

	# get the last word of ret_str string
	eval "local ret=\${ret_str##* }"
	# check if the value is failed or not
	if [[ "$ret" = "Failed" ]]; then
		# there was an error in the fapi command
		print_error "$command FAILED"
		return 1
	fi
	# fapi command was successful
	return 0
}

run_fapi_cli_set_cmd() {
	local command="$1"
	local device="$2"
	local param="$3"
	local value="$4"
	local ret

	ret=`fapi_wlan_cli $command | tee /dev/console`
	is_fapi_command_fail $? "$ret" "$command"
	if [[ $? -ne 0 ]]; then
	    if [[ -n "$device" -a -n "$param" -a -n "$value" ]]; then
		    set_uci_param "$device" "$param" "$value"
	    fi
	    return 1
	fi

	return 0
}

run_fapi_cli_get_cmd() {
	local command="$1"
	local ret val

	ret=`fapi_wlan_cli $command`
	is_fapi_command_fail $? "$ret" "$command"
	if [[ $? -ne 0 ]]; then
		return 1 
	fi

	val=`get_fapi_ret_val $ret`
	echo $val
}

run_fapi_cli_get_cmd_can_not_fail() {
	local command="$1"
	local ret val

	ret=`$command`
	val=`get_fapi_ret_val $ret`

	echo $val   
}

get_last_word() {
	# get the last word of the input string
	eval "local ret=\${$#}"
	# check if the value is failed or not
	echo $ret
}

is_vap_index_free() {
	local fapi_index=$1
	local ret_str=`fapi_wlan_cli getInterfaceName -i $fapi_index`
	local val=`get_last_word $ret_str`

	if [[ "$val" = "Failed" ]]; then
		return 1
	fi

	return 0
}

get_fapi_index_from_ifname() {
	local fapi_index=0
	local ifname="$1"
	local command val

	until [ $fapi_index -gt $MAX_FAPI_INDEX_SEARCH ]
	do
		command="fapi_wlan_cli getInterfaceName -i $fapi_index"
		val=`run_fapi_cli_get_cmd_can_not_fail "$command"`

		if [[ "$val" = "$ifname" ]]; then
			echo "$fapi_index"
			return 0
		fi

		fapi_index=$(( fapi_index+1 ))
	done

	return 1
}

replace_dot_with_underscore() {
	echo "$@" | tr . _
}

set_uci_param() {
	local vif=$1
	local param=$2
	local value=$3

	# write parameter to file
	uci_set "wireless" "$vif" $param "$value"
	uci_commit
	# set parameter 
	config_set $vif $param $value
}

check_vap_mac_address() {
	local mac_address=$1
	local address="00:00:00:00:00:00"
	local retVal=1

	# check if received MAC address string is legal
	if [[ ! -z "$mac_address" ]]; then
		if [ `echo "$mac_address" | egrep "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$"` ]
		then
			if [[ "$address" != "$mac_address" ]]; then
				retVal=0
			fi
		fi
	fi

	echo "$retVal"
}

# ---------------------------- ACTIONS FUNCTIONS ---------------------------------


# ----------------------------- RADIO FUNCTIONS ---------------------------------
set_beacon_int() {
	local device="$1"
	local fapi_index="$2"
	local val beacon_int command

	config_get beacon_int "$device" beacon_int

	val=`get_beacon_int $fapi_index`
	if [[ $? -eq 0 -a "$val" = "$beacon_int" ]]; then
		return 0
	fi

	if [[ ! -n "$beacon_int" ]]; then
		set_uci_param "$device" "beacon_int" "$val"
	fi

	command="setRadioBeaconPeriod -i $fapi_index -p $beacon_int"
	run_fapi_cli_set_cmd "$command" "$device" "beacon_int" "$val"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

get_channel() {
	local fapi_index=$1
	local val=`run_fapi_cli_get_cmd "getAutoChannelEnable -i $fapi_index"`

	if [[ "$val" = "true" ]]; then
		val="auto"
	else
		val=`run_fapi_cli_get_cmd "getChannel -i $fapi_index"`
	fi

	echo "$val"
}

set_channel() {
	local device="$1"
	local fapi_index="$2"
	local failed=0
	local val val2 channel

	config_get channel "$device" channel
	val=`get_channel $fapi_index`

	if [[ ! -n "$channel" ]]; then
		set_uci_param "$device" "channel" "$val"
		config_get channel "$device" channel
	fi

	if [ "$channel" = "auto" ]; then
		val=`run_fapi_cli_get_cmd "getAutoChannelEnable -i $fapi_index"`
		if [[ $? -ne 0 -o "$val" = "false" ]]; then
		    command="setAutoChannelEnable -i $fapi_index -e true"
			run_fapi_cli_set_cmd "$command" "$device" "channel" "$val"
			if [[ $? -ne 0 ]]; then
				return 1
			fi
		fi
	else
		val=`run_fapi_cli_get_cmd "getAutoChannelEnable -i $fapi_index"`
		if [[ $? -ne 0 ]]; then
			failed=1
		fi
		val2=`run_fapi_cli_get_cmd "getChannel -i $fapi_index"`
		if [[ $? -ne 0 ]]; then
			failed=1
		fi
		if [[ $failed -eq 1 -o "$val" = "true" -o "$val2" != "$channel" ]]; then
		    command="setAutoChannelEnable -i $fapi_index -e false"
			run_fapi_cli_set_cmd "$command" "$device" "channel" "$val"
			if [[ $? -ne 0 ]]; then
				return 1
			fi

			command="setChannel -i $fapi_index -c $channel"
			run_fapi_cli_set_cmd "$command" "$device" "channel" "$val2"
			if [[ $? -ne 0 ]]; then
				return 1
			fi
		fi
	fi
	return 0
}

set_channel_mode() {
	local device="$1"
	local fapi_index="$2"
	local newMode=""
	local command hw_mode hwmode ht_mode htmode
	local channel
	local secondary_channel
	
	config_get channel "$device" channel
	
	config_get hwmode "$device" hwmode
	hw_mode=`get_hw_mode $fapi_index`

	if [[ ! -n "$hwmode" ]]; then
		set_uci_param "$device" "hwmode" "$hw_mode"
		config_get hwmode "$device" hwmode
	fi

	config_get htmode "$device" htmode
	ht_mode=`get_ht_mode $fapi_index`
	if [[ ! -n "$htmode" ]]; then
		set_uci_param "$device" "htmode" "$ht_mode"
		config_get htmode "$device" htmode
	fi

	case "$hwmode" in
		11a)
			newMode="11A"
			;;
		11an)
			case "$htmode" in
				HT20)
					newMode="11NAHT20"
					;;
				HT40-)
					newMode="11NAHT40MINUS"
					;;
				HT40+)
					newMode="11NAHT40PLUS"
					;;
				HT40)
					secondary_channel=`can_use_above_channel $channel`
					if [[ "$secondary_channel" == "AboveControlChannel" ]]
					then
						newMode="11NAHT40PLUS"
					else
						newMode="11NAHT40MINUS"
					fi
					;;
			esac
			;;
		11anac)
			case "$htmode" in
				VHT20)
					newMode="11ACVHT20"
					;;
				VHT40-)
					newMode="11ACVHT40MINUS"
					;;
				VHT40+)
					newMode="11ACVHT40PLUS"
					;;
				VHT40)
					secondary_channel=`can_use_above_channel $channel`
					if [[ "$secondary_channel" == "AboveControlChannel" ]]
					then
						newMode="11ACVHT40PLUS"
					else
						newMode="11ACVHT40MINUS"
					fi
					;;
				VHT80)
					newMode="11ACVHT80"
					;;
			esac
			;;
		11b)
			newMode="11B"
			;;
		11bg)
			newMode="11G"
			;;
		11bgn)
			case "$htmode" in
				HT20)
					newMode="11NGHT20"
					;;
				HT40-)
					newMode="11NGHT40MINUS"
					;;
				HT40+)
					newMode="11NGHT40PLUS"
					;;
				HT40)
					secondary_channel=`can_use_above_channel $channel`
					if [[ "$secondary_channel" == "AboveControlChannel" ]]
					then
						newMode="11NGHT40PLUS"
					else
						newMode="11NGHT40MINUS"
					fi
					;;
			esac
			;;
	esac

	if [ ! -n "$newMode" ]; then
		print_error "Channel mode set is invalid. Unknown hw/ht mode combination (hw: $hwmode ht: $htmode)"
		set_uci_param "$device" "hwmode" "$hw_mode"
		set_uci_param "$device" "htmode" "$ht_mode"
		return 1
	fi

	command="setChannelMode -i $fapi_index -p $newMode"
	run_fapi_cli_set_cmd "$command"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

set_country() {
	local device="$1"
	local fapi_index="$2"
	local command val country

	config_get country "$device" country
	val=`get_country $fapi_index`

	if [[ ! -n "$country" ]]; then
		set_uci_param "$device" "country" "$val"
		config_get country "$device" country
	fi

	command="setCountryCode -i $fapi_index -p $country"
	run_fapi_cli_set_cmd "$command" "$device" "country" "$val"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

get_country() {
	local fapi_index="$1"
	local command val

	command="getCountryCode -i $fapi_index"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	echo $val
}

setRadioEnabled() {
	local fapi_index="$1"
	local enabled="$2"
	local command

	# Enable/disable radio
	command="setRadioEnabled -i $fapi_index -e $enabled"
	run_fapi_cli_set_cmd "$command"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}


set_log_level()
{
	local dev="$1"
	local fapi_index="$2"
	local file="/tmp/wlan_wave/SetLogLevelConfig_$dev"
	local command saveDevice log_level local_log_level

	config_get log_level "$dev" log_level
	saveDevice=`replace_dot_with_underscore $dev`
	log_level_identification $dev $fapi_index
	config_get local_log_level $saveDevice local_log_level

	if [[ ! -n "$log_level" ]]; then
		set_uci_param "$dev" "log_level" "$local_log_level"
		config_get log_level "$dev" log_level
	fi

	if [[ $log_level -gt $MAX_LOG_LEVEL ]]; 
	then
		# Error, log level is higher than expected
		return 1
	fi

	# Cofigure log level parameter usin TR181
	echo "Object_1=Device.WiFi.Radio.X_LANTIQ_COM_Vendor" > $file
	echo "WaveHostapdLoglevel_1=$log_level" >> $file

	command="setRadioTR181 -i $fapi_index -f $file"
	run_fapi_cli_set_cmd "$command" "$dev" "log_level" "$local_log_level"
	if [[ $? -ne 0 ]]; 
	then
		return 1
	fi

	return 0
}

log_level_identification()
{
	local device="$1"
	local fapi_index="$2"
	local log_level=$DEFAULT_LOG_LEVEL
	local command val ret_val ret_str
	
	command="getTR181 -i $fapi_index -t i -p Device.WiFi.Radio.X_LANTIQ_COM_Vendor -q WaveHostapdLoglevel"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 -o -z $val ]]; then
		print_error "ERROR, log_level_identification string empty"
		return 1
	fi
	log_level=$val

	if [[ $log_level -gt $MAX_LOG_LEVEL ]]; then
		config_set $device local_log_level $DEFAULT_LOG_LEVEL
	else
		config_set $device local_log_level $log_level
	fi
}

set_radio_params ()
{
	local device="$1"
	local fapi_index="$2"
	local command ret_val macaddr
	local disabled
	local radio_index=${device:4:1}

	print "================ Set Radio[ " $device " ] Parameters =================="

	# Set radio enable/disable
	if (was_dev_param_changed $device "disabled"); then
		config_get disabled "$device" disabled
		if [[ $disabled -eq '1' ]]; then
			setRadioEnabled "$radio_index" "false"
		else
			setRadioEnabled "$radio_index" "true"
		fi
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	# Set channel
	if (was_dev_param_changed $device "channel"); then
		set_channel "$device" "$fapi_index"
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	# Set Channel mode
	if (was_dev_param_changed $device "hwmode htmode"); then
		set_channel_mode $device $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	if (was_dev_param_changed $device "beacon_int"); then
		set_beacon_int $device $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi
	
	if (was_dev_param_changed $device "country"); then
		set_country $device $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	# Get BSSID (MAC address)
	config_get macaddr "$device" macaddr

	# Set LOG Level
	if (was_dev_param_changed $device "log_level"); then
		set_log_level $device $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set txpower
	if (was_dev_param_changed $device "txpower"); then
		set_txpower $device $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

}

# ----------------------------- VIF FUNCTIONS ---------------------------------
set_dtim_period()
{
	local vif=$1
	local fapi_index=$2
	local file="/tmp/wlan_wave/SetDtimPeriod_$fapi_index"
	local command saveDevice dtim_period local_dtim_period

	config_get device $vif device
	dtim_period_identification $fapi_index $device
	saveDevice=`run_fapi_cli_get_cmd "getInterfaceName -i $fapi_index"`
	saveDevice=`replace_dot_with_underscore $saveDevice`
	config_get local_dtim_period $saveDevice local_dtim_period
	config_get dtim_period $vif dtim_period
	if [[  "$dtim_period" = "$local_dtim_period" ]]; then
		return 0
	fi

	if [[ ! -n "$dtim_period" ]]; then
		set_uci_param "$vif" "dtim_period" "$local_dtim_period"
		config_get dtim_period "$vif" dtim_period
	fi

	if [[ $fapi_index -ge $START_VAPS_INDEX ]]; then
		# we cant do this for vif so we are reverting the value and failing
		set_uci_param "$vif" "dtim_period" "$local_dtim_period"
		config_get dtim_period "$vif" dtim_period
		return 1
	fi

	if [[ $dtim_period -gt $MAX_DTIM_PERIOD ]];
	then
		# set the default DTIM period
		dtim_period=$DEFAULT_DTIM_PERIOD
	elif [[ $dtim_period -lt $MIN_DTIM_PERIOD ]];
	then
		# set the default DTIM period
		dtim_period=$DEFAULT_DTIM_PERIOD
	fi

	# Cofigure dtim period parameter usin TR181
	echo "Object_1=Device.WiFi.Radio" > $file
	echo "DTIMPeriod_1=$dtim_period" >> $file

	command="setRadioTR181 -i $fapi_index -f $file"
	run_fapi_cli_set_cmd "$command" "$vif" "dtim_period" "$local_dtim_period"
	if [[ $? -ne 0 ]]; 
	then
		return 1
	fi

	return 0
}

set_doth_enabled()
{
	local vif=$1
	local fapi_index=$2
	local file="/tmp/wlan_wave/SetDotHConfig_$fapi_index"
	local command temp_val doth_enabled local_doth

	config_get doth_enabled "$vif" doth

	config_get device $vif device
	doth_identification $fapi_index $device
	config_get local_doth   $vif local_doth
	if [[  "$doth_enabled" = "$local_doth" ]]; then
		return 0
	fi

	if [[ ! -n "$doth_enabled" ]]; then
		set_uci_param "$vif" "doth_enabled" "$local_doth"
		config_get doth_enabled "$vif" doth_enabled
	fi

	if [[ $fapi_index -ge $START_VAPS_INDEX ]]; then
		# we cant do this for vif so we are reverting the value and failing
		set_uci_param "$vif" "doth_enabled" "$local_doth"
		config_get doth_enabled "$vif" doth_enabled
		return 1
	fi

	doth_enabled=`bool_to_str $doth_enabled`

	# Configure doth level parameter usin TR181
	echo "Object_1=Device.WiFi.Radio" > $file
	echo "IEEE80211hEnabled_1=$doth_enabled" >> $file

	command="setRadioTR181 -i $fapi_index -f $file"
	run_fapi_cli_set_cmd "$command" "$vif" "doth_enabled" "$local_doth"
	if [[ $? -ne 0 ]]; 
	then
		return 1
	fi

	return 0
}

set_isolate() {
	local vif=$1
	local fapi_index=$2
	local file="/tmp/wlan_wave/SetIsolateConfig_$fapi_index"
	local command val isolate

	config_get isolate "$vif" isolate
	val=`run_fapi_cli_get_cmd "getApIsolationEnable -i $fapi_index"`
	val=`str_to_bool $val`

	if [[  "$isolate" = "$val" ]]; then
		return 0
	fi

	if [[ ! -n "$isolate" ]]; then
		set_uci_param "$vif" "isolate" "$val"
		config_get isolate "$vif" isolate
	fi

	isolate=`bool_to_str $isolate`

	echo "Object_$fapi_index=Device.WiFi.AccessPoint" > $file
	echo "IsolationEnable_$fapi_index=$isolate" >> $file

	command="setApTR181 -i $fapi_index -f $file"
	run_fapi_cli_set_cmd "$command" "$vif" "isolate" "$val"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

set_macaddr() {
	local vif=$1
	local fapi_index=$2
	local file="/tmp/wlan_wave/SetMacaddrConfig_$fapi_index"
	local command macaddr fapi_macaddr val

	config_get macaddr "$vif" macaddr

	command="getTR181 -i $fapi_index -t s -p Device.WiFi.SSID -q MACAddress"
	fapi_macaddr=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	# if same MAC address - no update needed
	if [[ "$fapi_macaddr" == "$macaddr" ]]; then
		return 0
	fi

	# Check UCI MAC address sanity and set FAPI MAC address if check failed
	val=`check_vap_mac_address $macaddr`
	if [[ "$val" = "1" ]]; then
		set_uci_param "$vif" "macaddr" "$fapi_macaddr"
		config_get macaddr "$vif" macaddr
	fi

	# Write UCI MAC address to FAPI DB
	echo "Object_$fapi_index=Device.WiFi.SSID" > $file
	echo "MACAddress_$fapi_index=$macaddr" >> $file

	command="setSsidTR181 -i $fapi_index -f $file"
	run_fapi_cli_set_cmd "$command" "$vif" "macaddr" "$macaddr"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

set_ieee80211rw() {
	local vif=$1
	local fapi_index=$2
	local file="/tmp/wlan_wave/SetSecurityConfig_$fapi_index"
	local command fapi_11w fapi_11r ieee80211w ieee80211r nasid mobility_domain r0_key_lifetime r1_key_holder reassociation_deadline
	local r0kh r1kh pmk_r1_push

	config_get ieee80211w "$vif" ieee80211w 0
	fapi_11w=`get_ieee80211w $fapi_index`

	if [[ ! -n "$ieee80211w" ]]; then
		set_uci_param "$vif" "ieee80211w" "$fapi_11w"
		config_get ieee80211w "$vif" ieee80211w
	fi

	config_get_bool ieee80211r "$vif" ieee80211r 0
	fapi_11r=`get_ieee80211r $fapi_index`

	if [[ ! -n "$ieee80211r" ]]; then
		set_uci_param "$vif" "ieee80211r" "$fapi_11r"
		config_get ieee80211r "$vif" ieee80211r
	fi

	echo "Object_$fapi_index=Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security" > $file
	case $ieee80211w in
		0)
			echo "ManagementFrameProtection_$fapi_index=false" >> $file
			echo "ManagementFrameProtectionRequired_$fapi_index=false" >> $file
			;;
		1)
			echo "ManagementFrameProtection_$fapi_index=true" >> $file
			echo "ManagementFrameProtectionRequired_$fapi_index=false" >> $file
			;;
		2)
			echo "ManagementFrameProtection_$fapi_index=true" >> $file
			echo "ManagementFrameProtectionRequired_$fapi_index=true" >> $file
			;;
	esac

	if [ "$ieee80211r" -gt 0 ]
	then
		config_get nasid "$vif" nasid
		config_get mobility_domain "$vif" mobility_domain "4f57"
		config_get r0_key_lifetime "$vif" r0_key_lifetime "10000"
		config_get r1_key_holder "$vif" r1_key_holder "00004f577274"
		config_get reassociation_deadline "$vif" reassociation_deadline "1000"
		config_get r0kh "$vif" r0kh
		config_get r1kh "$vif" r1kh
		config_get_bool pmk_r1_push "$vif" pmk_r1_push 0
		local network=`run_fapi_cli_get_cmd "getBridgeName -i $fapi_index"`

		echo "FastTransionSupport_$fapi_index=true" >> $file
		echo "dot11FTMobilityDomainID_$fapi_index=$mobility_domain" >> $file
		echo "dot11FTR0KeyLifetime_$fapi_index=$r0_key_lifetime" >> $file
		echo "dot11FTR1KeyHolderID_$fapi_index=$r1_key_holder" >> $file
		echo "dot11FTReassociationDeadline_$fapi_index=$reassociation_deadline" >> $file
		echo "NASIdentifierAp_$fapi_index=$nasid" >> $file
		echo "InterAccessPointProtocol_$fapi_index=$network" >> $file

		local kh
		local r0counter=0
		for kh in $r0kh; do
			r0counter=$((r0counter+1))
			echo "R0KH"$r0counter"MACAddress_$fapi_index=$(echo "$kh" | awk -F ',' '{print $1}')" >> $file
			echo "NASIdentifier"$r0counter"_$fapi_index=$(echo "$kh" | awk -F ',' '{print $2}')" >> $file
			echo "R0KH"$r0counter"key_$fapi_index=$(echo "$kh" | awk -F ',' '{print $3}')" >> $file
		done
		if [ "$r0counter" -gt 0 ]; then
			echo "R0KHNumberOfEntries_$fapi_index=$r0counter" >> $file
		fi

		local r1counter=0
		for kh in $r1kh; do
			r1counter=$((r1counter+1))
			echo "R1KH"$r1counter"MACAddress_$fapi_index=$(echo "$kh" | awk -F ',' '{print $1}')" >> $file
			echo "R1KH"$r1counter"Id_$fapi_index=$(echo "$kh" | awk -F ',' '{print $2}')" >> $file
			echo "R1KH"$r1counter"key_$fapi_index=$(echo "$kh" | awk -F ',' '{print $3}')" >> $file
		done
		if [ "$r1counter" -gt 0 ]; then
			echo "R1KHNumberOfEntries_$fapi_index=$r1counter" >> $file
		fi
	else
		echo "FastTransionSupport_$fapi_index=false" >> $file
	fi

	command="setSecurityTR181 -i $fapi_index -f $file"
	run_fapi_cli_set_cmd "$command" "$vif" "ieee80211w" "$fapi_11w"
	if [[ $? -ne 0 ]]; then
		set_uci_param "$vif" "ieee80211r" "$fapi_11r"
		return 1
	fi

	return 0
}

set_ssid() {
	local vif="$1"
	local fapi_index="$2"
	local val ret ssid

	config_get ssid "$vif" ssid
	val=`run_fapi_cli_get_cmd "getSsid -i $fapi_index"`

	if [[ $? -eq 0 -a "$val" = "$ssid" ]]; then
		return 0
	fi

	if [[ ! -n "$ssid" ]]; then
		set_uci_param "$vif" "ssid" "$val"
		config_get ssid "$vif" ssid
	fi

	ret=`fapi_wlan_cli setSsid -i $fapi_index -s "${ssid}"`
	is_fapi_command_fail $? "$ret" 'fapi_wlan_cli setSsid -i $fapi_index -s "${ssid}"'
	if [[ $? -ne 0 ]]; then
		return 1 
	fi

	return 0
}


set_bssid() {
	local vif="$1"
	local fapi_index="$2"
	local val ret bssid

	config_get bssid "$vif" bssid
	val=`run_fapi_cli_get_cmd "getWdsPeers -i $fapi_index"`

	if [[ $? -eq 0 -a "$val" = "$bssid" ]]; then
		return 0
	fi

	if [[ ! -n "$bssid" ]]; then
		set_uci_param "$vif" "bssid" "$val"
		config_get bssid "$vif" bssid
	fi

	ret=`fapi_wlan_cli setWdsPeers -i $fapi_index -p $bssid`
	is_fapi_command_fail $? "$ret" 'fapi_wlan_cli setWdsPeers -i $fapi_index -p $bssid'
	if [[ $? -ne 0 ]]; then
		return 1 
	fi

	return 0
}

get_beacon_int() {
	local fapi_index="$1"
	local command val

	command="getRadioBeaconPeriod -i $fapi_index"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	echo $val
}

set_wmm() {
	local vif="$1"
	local fapi_index="$2"
	local command val wmm

	config_get wmm "$vif" wmm

	val=`run_fapi_cli_get_cmd "getWmmEnable -i $fapi_index"`
	val=`str_to_bool $val`

	if [[ ! -n "$wmm" ]]; then
		set_uci_param "$vif" "wmm" "$val"
		config_get wmm "$vif" wmm
	fi

	wmm=`bool_to_str $wmm`

	command="setWmmEnable -i $fapi_index -e $wmm"
	run_fapi_cli_set_cmd "$command" "$vif" "wmm" "$val"
	if [[ $? -ne 0 ]]; then
		print_error "WMM: HW supports WMM=TRUE only"
		return 1
	fi

	return 0
}

set_txpower() {
	local vif="$1"
	local fapi_index="$2"
	local command val converted_txpower txpower

	config_get txpower "$vif" txpower
	val=`get_txpower $fapi_index`
	if [[ ! -n "$txpower" ]]; then
		set_uci_param "$vif" "txpower" "$val"
		config_get txpower "$vif" txpower
	fi

	case $txpower in
		21)
			converted_txpower=12
			;;
		24)
			converted_txpower=25
			;;
		27)
			converted_txpower=50
			;;
		30)
			converted_txpower=100
			;;
	esac
	if [ -n "$converted_txpower" ]
	then
		command="setTransmitPower -i $fapi_index -p $converted_txpower"
		run_fapi_cli_set_cmd "$command" "$vif" "txpower" "$val"
		if [[ $? -ne 0 ]]; then
			return 1
		fi
	fi

	return 0
}

get_txpower() {
	local fapi_index="$1"
	local command val

	command="getTransmitPower -i $fapi_index"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	case $val in
		12)
			val=21
			;;
		25)
			val=24
			;;
		50)
			val=27
			;;
		100)
			val=30
			;;
	esac

	echo $val
}

set_network() {
	local vif="$1"
	local fapi_index="$2"
	local val_in_fapi network local_network bridge

	config_get network "$vif" network
	val_in_fapi=`run_fapi_cli_get_cmd "getBridgeName -i $fapi_index"`
	local_network=`bridge_to_network $val_in_fapi`

	if [[ $? -eq 0 -a "$local_network" = "$network" ]]; then
		return 0
	fi

	bridge=`network_to_bridge $network`

	# run_fapi_cli_set_cmd is not used here since we must wrap the bridge name with quotes 
	ret=`fapi_wlan_cli setBridgeName -i $fapi_index -p "$bridge" | tee /dev/console`
	is_fapi_command_fail $? "$ret" 'fapi_wlan_cli setBridgeName -i $fapi_index -p "${bridge}"'
	if [[ $? -ne 0 ]]; then
		if [[ -n "$vif" -a -n "$network" -a -n "$val_in_fapi" ]]; then
			set_uci_param "$vif" "network" "$val_in_fapi"
		fi
		return 1
	fi

	return 0
}

set_disable() {
	local vif="$1"
	local fapi_index="$2"
	local command val disabled isEnabled

	if [[ $fapi_index -lt $START_VAPS_INDEX ]]; then
		print_error "Can't execute vif disable on radio interface"
		return 1
	fi

	config_get disabled "$vif" disabled
	# If disabled is empty - then it is "Enabled", i.e 0
	if [[ ! -n "$disabled" ]]; then
		set_uci_param "$vif" "disabled" "0"
		config_get disabled "$vif" disabled
	fi

	# Set Enable value from disabled parameter
	if [[ $disabled -eq 0 ]]; then
		isEnabled="true"
	else
		isEnabled="false"
	fi

	# Update FAPI and UCI
	command="setEnable -i $fapi_index -e $isEnabled"
	run_fapi_cli_set_cmd "$command" "$vif" "disabled" "$val"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

set_hidden() {
	local vif="$1"
	local fapi_index="$2"
	local show_ssid="false"
	local command val

	config_get hidden "$vif" hidden

	val=`run_fapi_cli_get_cmd "getSsidAdvertisementEnabled -i $fapi_index"`
	if [[ "$val" = "true" ]]; then
		val=0
	else
		val=1
	fi

	if [[ ! -n "$hidden" ]]; then
		set_uci_param "$vif" "hidden" "$val"
		config_get hidden "$vif" hidden
	fi

	if [[ $hidden -eq 0 ]]; then
		show_ssid="true"
	fi

	command="setSsidAdvertisementEnabled -i $fapi_index -e $show_ssid"
	run_fapi_cli_set_cmd "$command" "$vif" "hidden" "$val"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

set_wds() {
	local vif="$1"
	local fapi_index="$2"
	local command val wds
	local mode

	config_get mode "$vif" mode
	config_get wds "$vif" wds

	if [[ "$mode" == "wds" ]]; then
		uci_set "wireless" "$vif" wds "1"
		uci_commit
	fi

	val=`run_fapi_cli_get_cmd "getWdsEnabled -i $fapi_index"`
	val=`str_to_bool $val`

	if [[ ! -n "$wds" ]]; then
		set_uci_param "$vif" "wds" "$val"
		config_get wds "$vif" wds
	fi

	wds=`bool_to_str $wds`

	command="setWdsEnabled -i $fapi_index -e $wds"
	run_fapi_cli_set_cmd "$command" "$vif" "wds" "$val"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}


set_mode() {
	local vif="$1"
	local fapi_index="$2"
	local wds

	config_get wds "$vif" wds
	if [[ "$wds" -eq "1" ]]; then
		uci_set "wireless" "$vif" mode "wds"
	else
		uci_set "wireless" "$vif" mode "ap"
	fi  
	uci_commit

	return 0
}

get_hw_mode() {
	local fapi_index="$1"
	local command val

	command="getChannelMode -i $fapi_index"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		echo "11b"
		return
	fi

	case "$val" in
		11B)
			val="11b"
		;;
		11G)
			val="11bg"
		;;
		11NGHT20|11NGHT40MINUS|11NGHT40PLUS|11NGHTAUTO)
			val="11bgn"
		;;
		11A)
			val="11a"
		;;
		11NAHT20|11NAHT40MINUS|11NAHT40PLUS|11NAHTAUTO)
			val="11an"
		;;
		11ACVHT20|11ACVHT40MINUS|11ACVHT40PLUS|11ACVHT80|11ACVHTAUTO)
			val="11anac"
		;;
	esac

	echo $val
}

get_ht_mode() {
	local fapi_index="$1"
	local command val

	command="getChannelMode -i $fapi_index"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	case "$val" in
		11A|11NAHT20|11B|11G|11NGHT20)
			val="HT20"
		;;
		11NAHT40MINUS|11NGHT40MINUS)
			val="HT40-"
		;;
		11NAHT40PLUS|11NGHT40PLUS)
			val="HT40+"
		;;
		11NAHTAUTO|11NGHTAUTO)
			val="HT40"
		;;
		11ACVHT20)
			val="VHT20"
		;;
		11ACVHT40MINUS)
			val="VHT40-"
		;;
		11ACVHT40PLUS)
			val="VHT40+"
		;;
		11ACVHT80|11ACVHTAUTO)
			val="VHT80"
		;;
	esac

	echo $val
}

set_maxassoc() {
	local vif="$1"
	local fapi_index="$2"
	local command val maxassoc
	
	config_get maxassoc "$vif" maxassoc

	val=`get_maxassoc "$fapi_index"`
	if [[ $? -eq 0 -a "$val" = "$maxassoc" ]]; then
		return 0
	fi

	if [[ ! -n "$maxassoc" ]]; then
		set_uci_param "$vif" "maxassoc" "$val"
		config_get maxassoc "$vif" maxassoc
	fi

	command="setMaxStations -i $fapi_index -p $maxassoc"
	run_fapi_cli_set_cmd "$command" "$vif" "maxassoc" "$val"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

get_maxassoc() {
	local fapi_index="$1"
	local command val

	command="getMaxStations -i $fapi_index"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	echo $val
}

remove_all_maclist() {
	local fapi_index="$1"
	local command ret mac
		
	ret=`fapi_wlan_cli getAclDeviceNum -i $fapi_index | grep -o -E "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}"`
	for mac in $ret; do
		command="delAclDevice -i $fapi_index -p $mac"
		run_fapi_cli_set_cmd "$command"
		if [[ $? -ne 0 ]]; then
			return 1
		fi
	done

	return 0
}

set_maclist() {
	local vif="$1"
	local fapi_index="$2"
	local command maclist macpolicy maclist_local macpolicy_local
	local need_change=0

	config_get maclist "$vif" maclist

	maclist_local=`fapi_wlan_cli getAclDeviceNum -i $fapi_index | grep -o -E "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}"`

	config_get macpolicy "$vif" macpolicy

	macpolicy_local=`get_macpolicy $fapi_index`

	if [[ ! -n "$maclist" ]]; then
		set_uci_param "$vif" "maclist" "$maclist_local"
		config_get maclist "$vif" maclist
	fi

	if [[ ! -n "$macpolicy" ]]; then
		#empty in GUI means disabled
		macpolicy="disable"
	fi

	if [[  "$maclist" != "$maclist_local" ]]; then
		need_change=1
	fi

	if [[  "$macpolicy" != "$macpolicy_local" ]]; then
		need_change=1
	fi

	if [[ $need_change -eq 0 ]]; then
		return 0
	fi

	case "$macpolicy" in
		disable)
			command="setMacAddControlMode -i $fapi_index -p Disabled"
			run_fapi_cli_set_cmd "$command" "$vif" "macpolicy" "$macpolicy_local"
			if [[ $? -ne 0 ]]; then
				return 1
			fi
			;;
		allow)
			command="setMacAddControlMode -i $fapi_index -p Allow"
			run_fapi_cli_set_cmd "$command" "$vif" "macpolicy" "$macpolicy_local"
			if [[ $? -ne 0 ]]; then
				return 1
			fi
			;;
		deny)
			command="setMacAddControlMode -i $fapi_index -p Deny"
			run_fapi_cli_set_cmd "$command" "$vif" "macpolicy" "$macpolicy_local"
			if [[ $? -ne 0 ]]; then
				return 1
			fi
			;;
	esac

	remove_all_maclist $fapi_index
	if [[ $? -ne 0 ]]; then
		 return 1
	fi

	config_get maclist "$vif" maclist
	if [ -n "$maclist" ]
	then
		for mac in $maclist; do
			command="addAclDevice -i $fapi_index -p $mac"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				return 1
			fi
		done
	fi

	return 0
}

get_ieee80211w() {
	local fapi_index="$1"
	local command val ManagementFrameProtection ManagementFrameProtectionRequired

	command="getTR181 -i $fapi_index -t b -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q ManagementFrameProtection"
	ManagementFrameProtection=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	command="getTR181 -i $fapi_index -t b -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q ManagementFrameProtectionRequired"
	ManagementFrameProtectionRequired=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	if [[ "$ManagementFrameProtection" = "true" ]]; then
		if [[ "$ManagementFrameProtectionRequired" = "true" ]]; then
			val=2
		else
			val=1
		fi
	else
		val=0
	fi

	echo $val
}

get_ieee80211r() {
	local fapi_index=$1
	local command val=0 ieee80211r

	command="getTR181 -i $fapi_index -t b -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q FastTransionSupport"
	ieee80211r=`run_fapi_cli_get_cmd "$command"`
	if [[ "$ieee80211r" = "true" ]]; then
		val=1
	fi

	echo $val
}

get_macpolicy() {
	local fapi_index="$1"
	local command val

	command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor -q MACAddressControlMode"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	case "$val" in
		Disabled)
			val="disable"
			;;
		Allow)
			val="allow"
			;;
		Deny)
			val="deny"
			;;
	esac

	echo $val
}

add_vap_if_required() {
	local device="$1"
	local interface=${device:4:1}
	local vif="$2"
	local fapi_index=$START_VAPS_INDEX 
	local foundIdx=0
	local command funcRet ssid

	# check if we need to add this vap
	config_get fapi_idx "$vif" fapi_idx
	print "fapi index is: " $fapi_idx
	if [ ! -z $fapi_idx ]; then
		# this vif already exists
		return 0
	fi

	print "Adding new vap: $vif"
	reload_required=1

	# indicate that re-setting uci interface indexes in prev-conf file will be needed
	index_realign_required=1

	# get parameters for the fapi command
	config_get ssid "$vif" ssid

	# getting vif index for fapi
	until [ $foundIdx -eq 1 ]
	do
		is_vap_index_free $fapi_index
		funcRet=$?
		if [[ $funcRet -eq 1 ]]; then
			# this index is free
			foundIdx=1
			break
		fi
		fapi_index=$(( fapi_index+2 ))
	done
 
	# send the add vap command (with a flag to prevent hostapd restart
	# which will need to be done  when all params are set anyway)
	command="createVap -i $interface -v $fapi_index -s $ssid -e false"
	run_fapi_cli_set_cmd "$command"
	if [[ $? -ne 0 ]]; then
		uci delete wireless.$vif
		uci_commit
		return 1
	fi

	# add a flag to know if we added this vap or not
	uci_set "wireless" "$vif" fapi_idx "$fapi_index"
	uci_commit
	config_set $vif fapi_idx $fapi_index
	return 0
}

set_vif_params ()
{
	local vif="$1"
	local fapi_index="$2"
	local command ret_val

	print "================ Set VIF[ " $fapi_index " ] Parameters =================="
	# get additinal UCI parameters

	# Print arguments
	print 'vif=' $vif

	#Set SSID
	if (was_iface_param_changed $vif "ssid"); then
		set_ssid "$vif" "$fapi_index"
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set bssid
	if (was_iface_param_changed $vif "bssid"); then
		set_bssid "$vif" "$fapi_index"
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set wmm
	if (was_iface_param_changed $vif "wmm"); then
		set_wmm "$vif" "$fapi_index"
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set network
	if (was_iface_param_changed $vif "network"); then
		set_network "$vif" "$fapi_index"
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set disable, legal only for non master vap
	if (was_iface_param_changed $vif "disabled"); then
		if [[ $fapi_index -ge $START_VAPS_INDEX ]]; then
			set_disable "$vif" "$fapi_index"
			if [[ $? -ne 0 ]]; then
				error_flag=1
			fi
		fi
	fi
	
	#Set hidden
	if (was_iface_param_changed $vif "hidden"); then
		set_hidden "$vif" "$fapi_index"
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set wds
	if (was_iface_param_changed $vif "mode wds"); then
		set_wds "$vif" "$fapi_index"
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set mode
	if (was_iface_param_changed $vif "mode wds"); then
		set_mode "$vif" "$fapi_index"
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set maxassoc
	if (was_iface_param_changed $vif "maxassoc"); then
		set_maxassoc $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set maclist
	if (was_iface_param_changed $vif "maclist macpolicy"); then
		set_maclist $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set ieee80211rw
	if (was_iface_param_changed $vif "ieee80211w"); then
		set_ieee80211rw $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set isolate
	if (was_iface_param_changed $vif "isolate"); then
		set_isolate $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	#Set macaddr
	if (was_iface_param_changed $vif "macaddr"); then
		set_macaddr $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	# set Encryption
	if (was_iface_param_changed $vif "encryption key key1 key2 key3 key4 server port wpa_group_rekey"); then
		set_encryption $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	# set WPS
	if (was_iface_param_changed $vif "wps_config wps_pin wps_uuid wps_device_name wps_manufacturer_url wps_manufacturer wps_pushbutton"); then
		set_wps $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	# set DTIM Period
	if (was_iface_param_changed $vif "dtim_period"); then
		set_dtim_period $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi

	# set DOT-H enable
	if (was_iface_param_changed $vif "doth"); then
		set_doth_enabled $vif $fapi_index
		if [[ $? -ne 0 ]]; then
			error_flag=1
		fi
	fi
}

set_encryption ()
{
	local vif="$1"
	local fapi_index="$2"
	local need_change=0
	local command ret_val authMode encMode saveDevice enc
	local encryption key key1 key2 key3 key4 server port wpa_group_rekey
	local local_encryption local_key local_key1 local_key2 local_key3 local_key4 local_server local_port local_wpa_group_rekey isHex
	local encError=false
	local isRadiusServerNeeded=false

	print "============ Set Encryption VIF[ " $fapi_index " ] Parameters ==========="
	# calling encryption function that will use config_set to set the variables
	encryption_identification $fapi_index $vif

	saveDevice=`replace_dot_with_underscore $vif`

	# make sure that the value exist
	config_get local_encryption $saveDevice local_encryption
	config_get encryption $saveDevice encryption
	if [[ ! -n "$encryption" ]]; then
		set_uci_param "$vif" "encryption" "$local_encryption"
		config_get encryption "$vif" encryption
	fi

	config_get local_key $saveDevice local_key
	config_get key $saveDevice key
	if [[ ! -n "$key" ]]; then
		set_uci_param "$vif" "key" "$local_key"
		config_get key "$vif" key
	fi

	config_get local_key1 $saveDevice local_key1
	config_get key1 $saveDevice key1
	if [[ ! -n "$key1" ]]; then
		set_uci_param "$vif" "key1" "$local_key1"
		config_get key1 "$vif" key1
	fi

	config_get local_key2 $saveDevice local_key2
	config_get key2 $saveDevice key2
	if [[ ! -n "$key2" ]]; then
		set_uci_param "$vif" "key2" "$local_key2"
		config_get key2 "$vif" key2
	fi

	config_get local_key3 $saveDevice local_key3
	config_get key3 $saveDevice key3
	if [[ ! -n "$key3" ]]; then
		set_uci_param "$vif" "key3" "$local_key3"
		config_get key3 "$vif" key3
	fi

	config_get local_key4 $saveDevice local_key4
	config_get key4 $saveDevice key4
	if [[ ! -n "$key4" ]]; then
		set_uci_param "$vif" "key4" "$local_key4"
		config_get key4 "$vif" key4
	fi

	config_get local_server $saveDevice local_server
	config_get server $saveDevice server
	if [[ ! -n "$server" ]]; then
		set_uci_param "$vif" "server" "$local_server"
		config_get server "$vif" server
	fi

	config_get local_port $saveDevice local_port
	config_get port $saveDevice port
	if [[ ! -n "$port" ]]; then
		set_uci_param "$vif" "port" "$local_port"
		config_get port "$vif" port
	fi

	config_get local_wpa_group_rekey $saveDevice local_wpa_group_rekey
	config_get wpa_group_rekey $saveDevice wpa_group_rekey
	if [[ ! -n "$wpa_group_rekey" ]]; then
		set_uci_param "$vif" "wpa_group_rekey" "$local_wpa_group_rekey"
		config_get wpa_group_rekey "$vif" wpa_group_rekey
	fi

	# check if the value had changed
	if [[  "$encryption" != "$local_encryption" ]]; then
		need_change=1
	fi

	if [[  "$key" != "$local_key" ]]; then
		need_change=1
	fi

	if [[  "$key1" != "$local_key1" ]]; then
		need_change=1
	fi

	if [[  "$key2" != "$local_key2" ]]; then
		need_change=1
	fi

	if [[  "$key3" != "$local_key3" ]]; then
		need_change=1
	fi

	if [[  "$key4" != "$local_key4" ]]; then
		need_change=1
	fi

	if [[  "$server" != "$local_server" ]]; then
		need_change=1
	fi

	if [[  "$port" != "$local_port" ]]; then
		need_change=1
	fi

	if [[  "$wpa_group_rekey" != "$local_wpa_group_rekey" ]]; then
		need_change=1
	fi

	if [[ $need_change -eq 0 ]]; then
		return 0
	fi

	# get Encryption UCI parameters
	config_get enc "$vif" encryption
	config_get key "$vif" key
	if [[ "$enc" = "wep" ]]; then
		# In WEP, the key parmeter is ignored in OpenWRT,set as 1
		key=$DEFAULT_WEP_KEY_INDEX
	fi
	config_get key1 "$vif" key1

	# Set encryption configuration to FAPI
	case "$enc" in
		wep)			# WEP 64, 128
			# Calculate Key1 length
			local wepKeyLen=${#key1}
			print "wepKeyLen=" $wepKeyLen
			
			# Check Key legality
			 case "$wepKeyLen" in 
				$WEP_64_KEY_HEX_DIGIT_LENGTH)   # WEP-64: 10 HEX digits
					print "WEP-64 Encryption parameters: "
					;;
				$WEP_128_KEY_HEX_DIGIT_LENGTH)   # WEP-128: 26 HEX digits
					print "WEP-128 Encryption parameters: "
					;;
				*)
					print_error "ERROR, WEP key length is ilegal: " $wepKeyLen
					encError=true
					;;
			esac

			# check if key is legal hex number
			isHex=`is_hex_num $key1`
			if [[ $isHex -eq 0 ]]; then
				print_error "ERROR, key1 is not HEX: " $key1
				encError=true
			fi
			print " enc=" $enc "key index=" $key "key=" $key1 "key length=" ${#key1} 

			# Set encryption
			#command="setEncMode -i $fapi_index -p WEPEncryption"
			command="setBeaconType -i $fapi_index -p Basic"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setBeaconType failed" 
				encError=true
			fi

			# Set Key index
			command="setWepKeyIndex -i $fapi_index -p $key"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setWepKeyIndex failed"
				encError=true
			fi

			# Set WEP key
			command="setWepKey -i $fapi_index -p $key1"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setWepKey failed" 
				encError=true
			fi
			;;
		psk*)		   # WPA, WPA2, WPA-mixed Personal (PSK)
			# Print arguments
			print "WPA, WPA2, WPA-mixed Personal encryption"
			print " enc=" $enc "key=" $key "key length=" ${#key} 
			case "$enc" in
				psk+tkip)		  # WPA Personal (PSK)
					encMode=TKIPEncryption
					authMode=None
					;;
				psk2+aes)		 # WPA2 Personal (PSK)
					encMode=AESEncryption
					authMode=None
					;;
				psk-mixed+tkip+aes) # WPA/WPA2 Personal (PSK)
					encMode=TKIPandAESEncryption
					authMode=None
					;;
				*)  # default
					encMode=None
					authMode=None
					print_error "Encryption Error: illegal PSK Mode, set: " "Encryption mode=" $encMode " Authenticaion=" $authMode
					encError=true
					;;
			esac
			
			command="setWpaEncMode -i $fapi_index -p $encMode"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setWpaEncMode failed" 
				encError=true
			fi

			command="setAuthMode -i $fapi_index -p $authMode"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setAuthMode failed" 
				encError=true
			fi

			command="setKeyPassphrase -i $fapi_index -p $key"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setKeyPassphrase failed" 
				encError=true
			fi

			;;
		wpa*)		  # WPA, WPA2, WPA-mixed Enterprise
			# Print arguments
			isRadiusServerNeeded=true
			print "WPA, WPA2, WPA mixed Enterprise encryption"
			print " enc=" $enc "key=" $key "key length=" ${#key} 
			case "$enc" in
				wpa2+aes)		  # WPA2 Enterprise, AES
					encMode=AESEncryption
					authMode=EAPAuthentication
					;;
				wpa+tkip)		  # WPA Enterprise, TKIP
					encMode=TKIPEncryption
					authMode=EAPAuthentication
					;;
				wpa-mixed+tkip+aes) # WPA-WPA2 Enterprise, TKIP+AES
					encMode=TKIPandAESEncryption
					authMode=EAPAuthentication
					;;
				*)				# defualt - None
					encMode=None
					authMode=None
					;;
			esac
			command="setWpaEncMode -i $fapi_index -p $encMode"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setWpaEncMode failed"
				encError=true
			fi

			command="setAuthMode -i $fapi_index -p $authMode"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setAuthMode failed"
				encError=true
			fi

			command="setKeyPassphrase -i $fapi_index -p $key"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setKeyPassphrase failed"
				encError=true
			fi

			# Set RADIUS Server parameters - if needed
			if [[ "$isRadiusServerNeeded" = "true" ]]; then
				config_get serverIP "$vif" server
				config_get serverPort "$vif" port
				config_get server_wpa_group_rekey "$vif" wpa_group_rekey
				
				# Check Radius read parameters:
				if [[ -z "$serverIP" ]]; then
					serverIP=$DEFAULT_RADIUS_SERVER_IP
					encError=true
				fi
				
				if [[ ! -n "$serverPort" ]]; then
					serverPort=$DEFAULT_RADIUS_SERVER_PORT
					encError=true
				fi
				
				if [[ ! -n "$server_wpa_group_rekey" ]]; then
					server_wpa_group_rekey=$DEFAULT_RADIUS_SERVER_WPA_REKEY_INTERVAL
					encError=true
				fi

				if [[ -z "$key" ]]; then
					key=$DEFAULT_RADIUS_SERVER_KEY
					encError=true
				fi
				
				print "Encryption Radius Server INPUT parameters:"
				print "IP=" $serverIP " Port=" $serverPort " Key=" $key " ReKey Interval=" $server_wpa_group_rekey "Default=" $encError

				# Set Radius Server parameters
				command="setApSecurityRadiusServerIP -i $fapi_index -p $serverIP"
				run_fapi_cli_set_cmd "$command"
				if [[ $? -ne 0 ]]; then
					print_error "Encryption command Error: setApSecurityRadiusServerIP failed"
					encError=true
				fi

				command="setApSecurityRadiusServerPort -i $fapi_index -p $serverPort"
				run_fapi_cli_set_cmd "$command"
				if [[ $? -ne 0 ]]; then
					print_error "Encryption command Error: setApSecurityRadiusServerPort failed"
					encError=true
				fi

				command="setRadiusSecret -i $fapi_index -p $key"
				run_fapi_cli_set_cmd "$command"
				if [[ $? -ne 0 ]]; then
					print_error "Encryption command Error: setRadiusSecret failed"
					encError=true
				fi

				command="setWpaRekeyInterval -i $fapi_index -p $server_wpa_group_rekey"
				run_fapi_cli_set_cmd "$command"
				if [[ $? -ne 0 ]]; then
					print_error "Encryption command Error: setWpaRekeyInterval failed"
					encError=true
				fi
			fi
			;;
		*)			# None
			# Print arguments
			print "Encryption None"
			command="setBeaconType -i $fapi_index -p None"
			run_fapi_cli_set_cmd "$command"
			if [[ $? -ne 0 ]]; then
				print_error "Encryption command Error: setBeaconType failed"
				encError=true
			fi
			;;
	esac

	# Error in Encryption input - return error
	if [[ $"encError" = "true" ]]; then
		return 1
	fi

	# Success in Encryption input - return OK
	return 0
}

set_all_wps_back() {
	local saveDevice="$1"
	local vif="$2"

	# setting the values back to the originals
	config_get local_wps_config $saveDevice local_wps_config
	config_get wps_config $saveDevice wps_config
	set_uci_param "$vif" "wps_config" "$local_wps_config"

	config_get local_wps_device_name $saveDevice local_wps_device_name
	config_get wps_device_name $saveDevice wps_device_name
	set_uci_param "$vif" "wps_device_name" "$local_wps_device_name"

	config_get local_wps_manufacturer $saveDevice local_wps_manufacturer
	config_get wps_manufacturer $saveDevice wps_manufacturer
	set_uci_param "$vif" "wps_manufacturer" "$local_wps_manufacturer"

	config_get local_wps_pushbutton $saveDevice local_wps_pushbutton
	config_get wps_pushbutton $saveDevice wps_pushbutton
	set_uci_param "$vif" "wps_pushbutton" "$local_wps_pushbutton"

	config_get local_wps_pin $saveDevice local_wps_pin
	config_get wps_pin $saveDevice wps_pin
	set_uci_param "$vif" "wps_pin" "$local_wps_pin"

	config_get local_wps_manufacturer_url $saveDevice local_wps_manufacturer_url
	config_get wps_manufacturer_url $saveDevice wps_manufacturer_url
	set_uci_param "$vif" "wps_manufacturer_url" "$local_wps_manufacturer_url"

	config_get local_wps_uuid $saveDevice local_wps_uuid
	config_get wps_uuid $saveDevice wps_uuid
	set_uci_param "$vif" "wps_uuid" "$local_wps_uuid"
}

set_wps ()
{
	local vif="$1"
	local fapi_index="$2"
	local need_change=0
	local file="/tmp/wlan_wave/setWpsConfig_$fapi_index"
	local command ret_val saveDevice wpsConfig wpsDevName wpsManufacturer wpsPushbutton wpsPin wpsManufacturerUrl wpsUUID

	print "=============== Set WPS VIF[ " $fapi_index " ] Parameters ==============="
	saveDevice=`run_fapi_cli_get_cmd "getInterfaceName -i $fapi_index"`
	saveDevice=`replace_dot_with_underscore $saveDevice`
	config_get device $vif device

	# calling WPS function that will use config_set to set the variables
	wps_identification $fapi_index $device

	# make sure that the value exist
	config_get local_wps_config $saveDevice local_wps_config
	config_get wps_config $saveDevice wps_config
	if [[ ! -n "$wps_config" ]]; then
		set_uci_param "$vif" "wps_config" "$local_wps_config"
		config_get wps_config "$vif" wps_config
	fi

	config_get local_wps_device_name $saveDevice local_wps_device_name
	config_get wps_device_name $saveDevice wps_device_name
	if [[ ! -n "$wps_device_name" ]]; then
		set_uci_param "$vif" "wps_device_name" "$local_wps_device_name"
		config_get wps_device_name "$vif" wps_device_name
	fi

	config_get local_wps_manufacturer $saveDevice local_wps_manufacturer
	config_get wps_manufacturer $saveDevice wps_manufacturer
	if [[ ! -n "$wps_manufacturer" ]]; then
		set_uci_param "$vif" "wps_manufacturer" "$local_wps_manufacturer"
		config_get wps_manufacturer "$vif" wps_manufacturer
	fi

	config_get local_wps_pushbutton $saveDevice local_wps_pushbutton
	config_get wps_pushbutton $saveDevice wps_pushbutton
	if [[ ! -n "$wps_pushbutton" ]]; then
		set_uci_param "$vif" "wps_pushbutton" "$local_wps_pushbutton"
		config_get wps_pushbutton "$vif" wps_pushbutton
	fi

	config_get local_wps_pin $saveDevice local_wps_pin
	config_get wps_pin $saveDevice wps_pin
	if [[ ! -n "$wps_pin" ]]; then
		set_uci_param "$vif" "wps_pin" "$local_wps_pin"
		config_get wps_pin "$vif" wps_pin
	fi

	config_get local_wps_manufacturer_url $saveDevice local_wps_manufacturer_url
	config_get wps_manufacturer_url $saveDevice wps_manufacturer_url
	if [[ ! -n "$wps_manufacturer_url" ]]; then
		set_uci_param "$vif" "wps_manufacturer_url" "$local_wps_manufacturer_url"
		config_get wps_manufacturer_url "$vif" wps_manufacturer_url
	fi

	config_get local_wps_uuid $saveDevice local_wps_uuid
	config_get wps_uuid $saveDevice wps_uuid
	if [[ ! -n "$wps_uuid" ]]; then
		set_uci_param "$vif" "wps_uuid" "$local_wps_uuid"
		config_get wps_uuid "$vif" wps_uuid
	fi

	if [[ $fapi_index -ge $START_VAPS_INDEX ]]; then
		# we cant do this for vif so we returning the value and failing
		set_all_wps_back "$saveDevice" "$vif"
		return 1
	fi

	# check if the value had changed
	if [[  "$wps_config" != "$local_wps_config" ]]; then
		need_change=1
	fi

	if [[  "$wps_device_name" != "$local_wps_device_name" ]]; then
		need_change=1
	fi

	if [[  "$wps_manufacturer" != "$local_wps_manufacturer" ]]; then
		need_change=1
	fi

	if [[  "$wps_pushbutton" != "$local_wps_pushbutton" ]]; then
		need_change=1
	fi

	if [[  "$wps_pin" != "$local_wps_pin" ]]; then
		need_change=1
	fi

	if [[  "$wps_manufacturer_url" != "$local_wps_manufacturer_url" ]]; then
		need_change=1
	fi

	if [[  "$wps_uuid" != "$local_wps_uuid" ]]; then
		need_change=1
	fi

	if [[ $need_change -eq 0 ]]; then
		return 0
	fi

	# get WPS UCI parameters
	config_get wpsConfig "$vif" wps_config
	config_get wpsDevName "$vif" wps_device_name
	config_get wpsManufacturer "$vif" wps_manufacturer
	config_get wpsPushbutton "$vif" wps_pushbutton
	config_get wpsPin "$vif" wps_pin
	config_get wpsManufacturerUrl "$vif" wps_manufacturer_url
	config_get wpsUUID "$vif" wps_uuid

	# Create WPS parameters file
	wpsPushbutton=`bool_to_str $wpsPushbutton`
	echo "Object_0=Device.WiFi.AccessPoint.WPS" > $file
	echo "Enable_0=$wpsPushbutton" >> $file
	echo "Object_1=Device.WiFi.Radio.X_LANTIQ_COM_Vendor.WPS" >> $file
	echo "WPS2ConfigMethodsEnabled_1=$wpsConfig" >> $file
	echo "PIN_1=$wpsPin" >> $file
	#echo "ConfigState_1=Configured" >> $file
	echo "UUID_1=$wpsUUID" >> $file
	echo "DeviceName_1=$wpsDevName" >> $file
	echo "ManufacturerUrl_1=$wpsManufacturerUrl" >> $file

	# Set WPS temporary file to update DB
	command="setWpsTR181 -i $fapi_index -f $file"
	run_fapi_cli_set_cmd "$command"
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	return 0
}

set_params() {
	local device="$1"
	local device_number=${device:4:1}
	local command ret ret_val uci_iface_list iface vif vifs fapi_index
	local uci_iface_list

	# Check if any changes were made to previous configuration
	touch ${PREV_UCI_CONF_FILE}_$device	

	SAVEIFS=$IFS
	IFS=''
	detected_changes=`(cat ${PREV_UCI_CONF_FILE}_wlan* && uci show wireless) | sort | uniq -u`
	IFS=$SAVEIFS

	if [[ "x$detected_changes" == x'' ]]
	then 
		print "UCI: no changes detected for $1 wireless configuration"
	else

		print "UCI: changes were detected in $1 wireless configuration, need to update fapi..."

		reload_required=1

		# Radio settings 
		set_radio_params $device $device_number

		# Vifs settings 
		config_get vifs "$device" vifs

		for vif in $vifs; do

			add_vap_if_required $device $vif
			if [[ $? -ne 0 ]]; then
				error_flag=1
				continue
			fi

			config_get fapi_index $vif fapi_idx

			# Update a list of interfaces which will not be removed
			iface=`run_fapi_cli_get_cmd "getInterfaceName -i $fapi_index"`
			uci_iface_list=$uci_iface_list$iface"_"

			# Set ifname
			set_uci_param "$vif" "ifname" "$iface"

			# Set vif params
			set_vif_params $vif $fapi_index
			if [[ $? -ne 0 ]]; then
				error_flag=1
			fi

		done

		# Remove virtual interfaces, if required
		# not including wlan0/2/4 which can't be removed.
		local ifaces_to_be_removed=`ifconfig -a | grep "^$device\." | awk '{ print $1 }'`
		local idx
		for iface in $ifaces_to_be_removed; do
			echo $uci_iface_list | grep -o $iface"_"
			if [[ $? -ne 0 ]]; then
				idx=`get_fapi_index_from_ifname $iface`
				if [[ $? -ne 0 ]]; then
					print_error "interface removal: invalid fapi index"
					break
				fi
				reload_required=1
				# indicate that re-setting uci interface indexes in prev-conf file will be needed
				index_realign_required=1
				print "Removing Vap, index: $idx"
				command="deleteVap -i $idx"
				run_fapi_cli_set_cmd "$command"
				if [[ $? -ne 0 ]]; then
					print_error "Failed to remove VAP, fapi index: $idx"
					return 1
				fi
			fi
		done

		# ifconfig up all the interfaces
		# (except for the interface we've removed)
		for vif in $vifs; do
			#getting fapi index for the set commands
			config_get fapi_index $vif fapi_idx

			#ifconfigUp the interface
			if [[ "$reload_required" == "1" ]]; then
				command="ifconfigUp -i $fapi_index"
				run_fapi_cli_set_cmd "$command"
				if [[ $? -ne 0 ]]; then
					return 1
				fi
			fi
		
			if [[ $error_flag -ne 0 ]]; then
				error_flag=0
				return 1
			fi
		done
	fi #changes detected

	return 0
}

# ----------------------------- API FUNCTIONS ---------------------------------

scan_intel_ap() {
	print "scan"
}

disable_intel_ap() {
	local device="$1"
	local disabled

	print "Disable: $@"

	if [ ! -f "/tmp/wlan_wave/hw_init_out_conf" ]; then
		print "Ignoring, FAPI init was not done yet"
		return 0
	else
		grep status=success /tmp/wlan_wave/hw_init_out_conf > /dev/null
		if [[ $? -ne 0 ]]; then
			print_error "FAPI init didn't finished successfully"
			return 1
		fi
	fi

	# if device is enabled, we don't need to do anything here because soon enable_intel_ap will be called
	config_get disabled "$device" disabled
	if [[ $disabled -eq 0 ]]; then
		print "Radio should be enabled, no need to do anything..."
		return 0
	fi

	set_params $@
	if [[ $? -ne 0 ]]; then
		error_flag=1	
	fi

	# Update old configuration file in order to detect future changes
	if [[ $reload_required == '1' ]]; then
		print "Updating prev conf file for $device"
		uci_commit
		update_prev_conf_file $device
		if [ "$index_realign_required" == "1" ]; then
			print "Interface was added/removed, need to update interface indexes in prev conf files"
			realign_iface_idx_in_prev_conf
		fi
	fi
		
	print "+=====================+"
	print "|Disable $device DONE |"
	print "+=====================+"

	return $error_flag 
}

enable_intel_ap() {
	local device="$1"

	print "Enable: $@"

	if [ ! -f "/tmp/wlan_wave/hw_init_out_conf" ]; then
		print "Ignoring, FAPI init was not done yet"
		return 0
	else
		grep status=success /tmp/wlan_wave/hw_init_out_conf
		if [[ $? -ne 0 ]]; then
			print_error "FAPI init didn't finished successfully"
			return 1
		fi
	fi

	set_params $@
	if [[ $? -ne 0 ]]; then
		error_flag=1
	fi

	# Update old configuration file in order to detect future changes
	if [[ $reload_required == '1' ]]; then
		print "Updating prev conf file for $device"
		uci_commit
		update_prev_conf_file $device
		if [ "$index_realign_required" == "1" ]; then
			print "Interface was added/removed, need to update interface indexes in prev conf files"
			realign_iface_idx_in_prev_conf
		fi
	fi

	print "+====================+"
	print "|Enable $device DONE |"
	print "+====================+"

	return $error_flag 
}

detect_intel_ap() {
	local dev
	local fapi_index
	local ifnum
	local radio_list

	if [ ! -f "/tmp/wlan_wave/hw_init_out_conf" ]; then
		print "Ignoring, FAPI init was not done yet"
		return 0
	else
		grep status=success /tmp/wlan_wave/hw_init_out_conf > /dev/null
		if [[ $? -ne 0 ]]; then
			print_error "FAPI init didn't finished successfully"
			return 1
		fi
	fi

	for dev in $(/sbin/ifconfig -a | grep ^${DEV_PREFIX} | awk '{print $1;}' 2>&-); do
		fapi_index=0
		ifnum=${dev:4:1}
	
		# ignoring wlan1,3,5 (Station mode interfaces) 
		if [ $ifnum -eq 1 -o $ifnum -eq 3 -o $ifnum -eq 5 ] ; then
			continue
		fi

		# get VAP fapi index
		fapi_index=`get_fapi_index_from_ifname $dev`
		if [[ $? -ne 0 ]]; then
			print_error "detect_intel_ap: could not get fapi index for interface name: $dev"
			return 1
		fi

		# check if this is a device that we need to fill
		if [[ $fapi_index -lt $START_VAPS_INDEX ]]; then
			# fill device section
			fill_device "$fapi_index" "$dev"
			radio_list="$radio_list $dev"
		fi
	
		#this is a vif
		fill_vif "$fapi_index" "$dev"

	done

	config_load wireless
	# Update conf file, which will be used to detect future changes
	for radio in $radio_list; do
		update_prev_conf_file $radio
	done

}


# ----------------------------- DETECT FUNCTIONS ---------------------------------
fill_device() {
	local fapi_index=$1
	local dev=$2
	local val channel hw_mode ht_mode disabled phy_idx ifname beacon_int country saveDevice txpower

	# get channel
	channel=`get_channel $fapi_index`

	# get phy_idx
	phy_idx=${dev:4:1}

	# get channelMode
	hw_mode=`get_hw_mode $fapi_index`
	ht_mode=`get_ht_mode $fapi_index`

	# get disabled
	val=`run_fapi_cli_get_cmd "getRadioEnabled -i $fapi_index"`
	if [[ "$val" = "true" ]]; then
		disabled=0
	else
		disabled=1
	fi

	# get ifname
	# ifname=`run_fapi_cli_get_cmd "getInterfaceName -i $fapi_index"`
	ifname=$dev

	# get beacon_int
	beacon_int=`get_beacon_int $fapi_index`

	# get country
	country=`get_country $fapi_index`

	# Get LOG LEVEL identification from FAPI, and then check and update config
	saveDevice=$dev
	saveDevice=`replace_dot_with_underscore $saveDevice`
	log_level_identification $dev $fapi_index
	config_get log_level $saveDevice local_log_level

	# get txpower
	txpower=`get_txpower $fapi_index`

cat <<EOF

config wifi-device  $dev
		option type                    'intel_ap'
		option macaddr                 '$(/sbin/ifconfig -a | grep "${dev} " | grep -o -E "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}")'
		option channel                 '$channel'
		option hwmode                  '$hw_mode'
		option htmode                  '$ht_mode'
		option disabled                '$disabled'
		option phy                     'phy$phy_idx'
		option ifname                  '$ifname'
		option beacon_int              '$beacon_int'
		option country                 '$country'
		option log_level               '$log_level'
		option txpower                 '$txpower'
EOF


}

encryption_identification() 
{
	local fapi_index=$1
	local commmand val ret_str ret_val encConfig key key1 key2 key3 key4 serverIP serverPort serverKey serverReKey detConfig saveDevice

	# Get default Encryption FAPI parameters
	# Get Security ModeEnabled, 
	# Modes supported are: 
	#	  None, WEP-64, WEP-128, WPA-Personal, WPA2-Personal, WPA-WPA2-Personal, 
	#	  WPA-Enterprise, WPA2-Enterprise, WPA-WPA2-Enterprise
	# TODO: remove - ret_str=`fapi_wlan_cli getEncMode -i $fapi_index`
	command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.Security -q ModeEnabled"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		print_error "getTR181 get security mode enabled failed"
		return 1
	fi

	case "$val" in
		WEP-64|WEP-128)
			# Set UCI encryption mode
			encConfig=wep

			# Get Key Index
			ret_str=`fapi_wlan_cli getWepKeyIndex -i $fapi_index`
			ret_val=$?
			if [[ $ret_val -eq 0 ]]; then
				val=`get_fapi_ret_val $ret_str`
				if [[ ! -z $val ]]; then
					if [[ $val -gt $MAX_WEP_KEYS ]]; then
						print_error "getWepKeyIndex illegal key index value: " $val
						val=$DEFAULT_WEP_KEY_INDEX
						print  "Set default Key index: " $val
					fi
				fi
			else
				val=$DEFAULT_WEP_KEY_INDEX
				print_error "getWepKeyIndex failed: set default: " $val
			fi
			key=$val

			# Get Key
			command="getWepKey -i $fapi_index"
			val=`run_fapi_cli_get_cmd "$command"`
			if [[ $? -ne 0 ]]; then
				print_error "getWepKey failed" 
				val="ERROR"
				print "Set default WEP Key: " $val
			fi

			# Set UCI key parameters to empty string
			key1=""
			key2=""
			key3=""
			key4=""

			if [[ ! -z $val ]]; then
				# Set UCI key by key index
				case "$key" in
					1) key1=$val ;;
					2) key2=$val ;;
					3) key3=$val ;;
					4) key4=$val ;;
				esac

				# Check if key is hex number - if not, error
				isHex=`is_hex_num $key1`
				if [[ $isHex -eq 0 ]]; then
					print_error "ERROR: key1 is not HEX" $key1
				fi
			fi
			;;
		WPA-Personal)	   		encConfig=psk+tkip ;;
		WPA2-Personal)	 		encConfig=psk2+aes ;;
		WPA-WPA2-Personal)  	encConfig=psk-mixed+tkip+aes ;;
		WPA-Enterprise)   		encConfig=wpa+tkip ;;
		WPA2-Enterprise)		encConfig=wpa2+aes ;;
		WPA-WPA2-Enterprise)	encConfig=wpa-mixed+tkip+aes ;;
		*)				 		encConfig=None ;;
	esac

	# Key Passphrase for WPA Security
	if [ "$encConfig" != "wep" ] && [ "$encConfig" != "None" ]; then
		# Get WPA passphrase
		command="getKeyPassphrase -i $fapi_index"
		val=`run_fapi_cli_get_cmd "$command"`
		if [[ $? -ne 0 ]]; then
			print_error "getKeyPassphrase failed" 
			val=$DEFAULT_ENCRYPTION_KEY
		fi
	    key=$val

		# Get WPA Server parameters - relevant for Enterprise Encryption
		# Server IP
		command="getApSecurityRadiusServerIP -i $fapi_index"
		val=`run_fapi_cli_get_cmd "$command"`
		if [[ $? -ne 0 ]]; then
			print_error "getApSecurityRadiusServerIP failed" 
			serverIP=$DEFAULT_RADIUS_SERVER_IP
		fi
    	serverIP=$val

		# Server port
		command="getApSecurityRadiusServerPort -i $fapi_index"
		val=`run_fapi_cli_get_cmd "$command"`
		if [[ $? -ne 0 ]]; then
			print_error "getApSecurityRadiusServerPort failed" 
			serverPort=$DEFAULT_RADIUS_SERVER_PORT
		fi
		serverPort=$val

		# Server key
		serverKey=$key

		# Server ReKey interval
		command="getWpaRekeyInterval -i $fapi_index"
		val=`run_fapi_cli_get_cmd "$command"`
		if [[ $? -ne 0 ]]; then
			print_error "getWpaRekeyInterval failed" 
			server_wpa_group_rekey=$DEFAULT_RADIUS_SERVER_WPA_REKEY_INTERVAL
		fi
		serverReKey=$val
	fi

	# setting all the encryption to it's types so in fill_vif we can just get them
	saveDevice=`run_fapi_cli_get_cmd "getInterfaceName -i $fapi_index"`
	saveDevice=`replace_dot_with_underscore $saveDevice`

	config_set $saveDevice local_encryption $encConfig
	config_set $saveDevice local_key $key
	config_set $saveDevice local_key1 $key1
	config_set $saveDevice local_key2 $key2
	config_set $saveDevice local_key3 $key3
	config_set $saveDevice local_key4 $key4
	config_set $saveDevice local_server $serverIP
	config_set $saveDevice local_port $serverPort
	config_set $saveDevice local_wpa_group_rekey $serverReKey
}

wps_identification()
{
	local fapi_index=$1
	local command val saveDevice
	local wpsConfig wpsPin wpsUUID wpsDevName wpsManufacturerUrl wpsManufacturer wpsPushbutton
	local index_to_use=$1

	wpsManufacturer="Intel Corporation"

	# check if this is vif
	if [[ $fapi_index -ge $START_VAPS_INDEX ]]; then
		#changing the fapi index to be master vap
		index_to_use=$2
		index_to_use=${index_to_use:4:1}
	fi

	# WPS enabled
	command="getWpsEnable -i $index_to_use"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	wpsPushbutton=`str_to_bool $val`
	
	# Get configuration enabled
	command="getWpsConfigMethodsEnabled -i $index_to_use"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	wpsConfig=$val

	# Get WPS PIN
	command="getWpsDevicePIN -i $index_to_use"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	wpsPin=$val

	# Get WPS UUID
	command="getTR181 -i $index_to_use -t s -p Device.WiFi.Radio.X_LANTIQ_COM_Vendor.WPS -q UUID"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	wpsUUID=$val

	# Get WPS DeviceName
	command="getTR181 -i $index_to_use -t s -p Device.WiFi.Radio.X_LANTIQ_COM_Vendor.WPS -q DeviceName"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	wpsDeviceName=$val

	 # Get WPS ManufacturerUrl
	command="getTR181 -i $index_to_use -t s -p Device.WiFi.Radio.X_LANTIQ_COM_Vendor.WPS -q ManufacturerUrl"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 ]]; then
		return 1
	fi
	wpsManufacturerUrl=$val

	# Get WPS Manufacturer #TODO: Get value from FAPI. DeviceInfo is under whole instance now, which is a problem
	wpsManufacturer="Intel Corporation"
	
	# setting all the WPS to it's types so in fill_vif we can just get them
	saveDevice=`run_fapi_cli_get_cmd "getInterfaceName -i $fapi_index"`
	saveDevice=`replace_dot_with_underscore $saveDevice`

	config_set $saveDevice local_wps_config "$wpsConfig"
	config_set $saveDevice local_wps_pin $wpsPin
	config_set $saveDevice local_wps_uuid "$wpsUUID"
	config_set $saveDevice local_wps_device_name $wpsDeviceName
	config_set $saveDevice local_wps_manufacturer_url "$wpsManufacturerUrl"
	config_set $saveDevice local_wps_manufacturer "$wpsManufacturer"
	config_set $saveDevice local_wps_pushbutton "$wpsPushbutton"
}

doth_identification()
{
	local fapi_index=$1
	local dothSupported="true"
	local command val ret_str ret_val
	local index_to_use=$1

	# check if this is vif
	if [[ $fapi_index -ge $START_VAPS_INDEX ]]; then
		#changing the fapi index to be master vap
		index_to_use=$2
		index_to_use=${index_to_use:4:1}
	fi

	command="getTR181 -i $index_to_use -t b -p Device.WiFi.Radio -q IEEE80211hSupported"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 -o -z $val ]]; then
		return 1
	fi
	dothSupported=`str_to_bool $val`
	
	saveDevice=`run_fapi_cli_get_cmd "getInterfaceName -i $fapi_index"`
	saveDevice=`replace_dot_with_underscore $saveDevice`
	config_set $saveDevice local_doth $dothSupported
}

dtim_period_identification()
{
	local fapi_index=$1
	local dtim_period=$DEFAULT_DTIM_PERIOD
	local command val ret_str ret_val saveDevice
	local index_to_use=$1

	# check if this is vif
	if [[ $fapi_index -ge $START_VAPS_INDEX ]]; then
		#changing the fapi index to be master vap
		index_to_use=$2
		index_to_use=${index_to_use:4:1}
	fi

	command="getTR181 -i $index_to_use -t i -p Device.WiFi.Radio -q DTIMPeriod"
	val=`run_fapi_cli_get_cmd "$command"`
	if [[ $? -ne 0 -o -z $val ]]; then
		return 1
	fi
	dtim_period=$val

	saveDevice=`run_fapi_cli_get_cmd "getInterfaceName -i $fapi_index"`
	saveDevice=`replace_dot_with_underscore $saveDevice`

	if [[ $dtim_period -gt $MAX_DTIM_PERIOD ]];
	then
		config_set $saveDevice local_dtim_period $DEFAULT_DTIM_PERIOD
	elif [[ $dtim_period -lt $MIN_DTIM_PERIOD ]];
	then
		config_set $saveDevice local_dtim_period $DEFAULT_DTIM_PERIOD
	else
		config_set $saveDevice local_dtim_period $dtim_period
	fi
}

bridge_to_network() {
	local bridge=$1
	local network=$bridge

	if [[ ! -z $bridge ]]; then
		# removing br- prefix
		network=${bridge:3}
	fi

	echo "$network"
}

network_to_bridge() {
	local network=$1
	local bridge=$1

	if [[ ! -z $network ]]; then
		#adding br- prefix
		bridge="br-$network"
	fi

	echo "$bridge"
}

fill_vif() {
	local fapi_index=$1
	local ifname=$2
	local command device saveDevice
	local bssid
	local network
	local bridge
	local ssid
	local macaddr
	local disabled enabled
	# Encryption variables:
	local encryption
	local key
	local key1
	local key2
	local key3
	local key4
	local server
	local server
	local wpa_group_rekey
	local ieee80211w
	# Device variables:
	local fapi_idx
	local saveDevice
	local maxassoc
	local macpolicy
	local maclist
	# WPS variables:
	local wpsConfig
	local wpsDevName
	local wpsManufacturer
	local wpsPushbutton
	local wpsPin
	local wpsManufacturerUrl
	local wpsUUID

	local wmm
	local hidden
	local doth_enabled
	local dtim_period
	local isolate
	local wds


	# get device
	device=${ifname:0:5}

	# get bssid
	bssid=`run_fapi_cli_get_cmd "getWdsPeers -i $fapi_index"`
	
	# get network
	bridge=`run_fapi_cli_get_cmd "getBridgeName -i $fapi_index"`
	network=`bridge_to_network $bridge`

	# get ssid
	ssid=`run_fapi_cli_get_cmd "getSsid -i $fapi_index"`
 
	# get macaddr
	macaddr=`/sbin/ifconfig -a | grep "${ifname} " | grep -o -E "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}"`
	
	# get fapi_idx
	fapi_idx=$fapi_index

	# get disabled
	enabled=`run_fapi_cli_get_cmd "getEnable -i $fapi_index"`
	enabled=`str_to_bool $enabled`
	if [[ $enabled -eq 1 ]]; then
		disabled=0
	else
		disabled=1
	fi

	# calling encryption function that will use config_set to set the variables
	encryption_identification $fapi_index

	saveDevice=`replace_dot_with_underscore $ifname`   

	# get encryption
	# was set in encryption_identification
	config_get encryption $saveDevice local_encryption

	# get key
	# was set in encryption_identification
	config_get key $saveDevice local_key

	# get key1-4
	# was set in encryption_identification
	config_get key1 $saveDevice local_key1
	config_get key2 $saveDevice local_key2
	config_get key3 $saveDevice local_key3
	config_get key4 $saveDevice local_key4

	# get server
	# was set in encryption_identification
	config_get server $saveDevice local_server

	# get port
	# was set in encryption_identification
	config_get port $saveDevice local_port

	# get wpa_group_rekey
	# was set in encryption_identification
	config_get wpa_group_rekey $saveDevice local_wpa_group_rekey

	# get maxassoc
	maxassoc=`get_maxassoc $fapi_index`

	# get maclist
	maclist=`fapi_wlan_cli getAclDeviceNum -i $fapi_index | grep -o -E "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}"`

	# get macpolicy
	macpolicy=`get_macpolicy $fapi_index`

	# get ieee80211w
	ieee80211w=`get_ieee80211w $fapi_index`

	# calling WPS function that will use config_set to set the variables
	wps_identification $fapi_index $device
	# Get WPS enable
	config_get wpsConfig $saveDevice local_wps_config
	config_get wpsPin $saveDevice local_wps_pin
	config_get wpsUUID $saveDevice local_wps_uuid
	config_get wpsDevName $saveDevice local_wps_device_name
	config_get wpsManufacturerUrl $saveDevice local_wps_manufacturer_url
	config_get wpsManufacturer $saveDevice local_wps_manufacturer
	config_get wpsPushbutton $saveDevice local_wps_pushbutton

	# Get wmm
	wmm=`run_fapi_cli_get_cmd "getWmmEnable -i $fapi_index"`
	wmm=`str_to_bool $wmm`

	# Get hidden
	show_ssid=`run_fapi_cli_get_cmd "getSsidAdvertisementEnabled -i $fapi_index"`
	show_ssid=`str_to_bool $show_ssid`
	if [[ $show_ssid -eq 1 ]]; then
		hidden=0
	else
		hidden=1
	fi

	# Get DOT_H identification from FAPI, and then check and update config
	doth_identification $fapi_index $device
	config_get doth_enabled   $saveDevice local_doth
	
	# Get DTIM Period identification from FAPI, and then check and update config
	dtim_period_identification $fapi_index $device
	config_get dtim_period $saveDevice local_dtim_period

	# get isolate
	isolate=`run_fapi_cli_get_cmd "getApIsolationEnable -i $fapi_index"`
	isolate=`str_to_bool $isolate`

	# get wds
	wds=`run_fapi_cli_get_cmd "getWdsEnabled -i $fapi_index"`
	wds=`str_to_bool $wds`

	# get mode
	if [[ $wds -eq 1 ]]; then
		mode="wds"
	else
		mode="ap"
	fi

	local maclist_list=""
	for mac in $maclist; do
		maclist_list="$maclist_list""list   maclist '$mac'"$'\n'$'\t'$'\t'
	done

	# get ieee80211r
	local ieee80211r=`get_ieee80211r $fapi_index`
	if [[ $ieee80211r -eq 1 ]]; then
		command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q NASIdentifierAp"
		local nasid=`run_fapi_cli_get_cmd "$command"`
		command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q dot11FTMobilityDomainID"
		local mobility_domain=`run_fapi_cli_get_cmd "$command"`
		command="getTR181 -i $fapi_index -t i -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q dot11FTR0KeyLifetime"
		local r0_key_lifetime=`run_fapi_cli_get_cmd "$command"`
		command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q dot11FTR1KeyHolderID"
		local r1_key_holder=`run_fapi_cli_get_cmd "$command"`
		command="getTR181 -i $fapi_index -t i -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q dot11FTReassociationDeadline"
		local reassociation_deadline=`run_fapi_cli_get_cmd "$command"`
		command="getTR181 -i $fapi_index -t i -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q R0KHNumberOfEntries"
		local R0KHNumberOfEntries=`run_fapi_cli_get_cmd "$command"`
		command="getTR181 -i $fapi_index -t i -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q R1KHNumberOfEntries"
		local R1KHNumberOfEntries=`run_fapi_cli_get_cmd "$command"`
		local r0kh_list=""
		for i in `seq 1 $R0KHNumberOfEntries` ; do
			R0KHMACAddress="R0KH"$i"MACAddress"
		command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q $R0KHMACAddress"
		R0KHMACAddress=`run_fapi_cli_get_cmd "$command"`
		NASIdentifier="NASIdentifier"$i
		command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q $NASIdentifier"
		NASIdentifier=`run_fapi_cli_get_cmd "$command"`
		R0KHKey="R0KH"$i"key"
		command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q $R0KHKey"
		R0KHKey=`run_fapi_cli_get_cmd "$command"`
		r0kh_list="$r0kh_list""list   r0kh '$R0KHMACAddress,$NASIdentifier,$R0KHKey'"$'\n'$'\t'$'\t'
		done
		local r1kh_list=""
		for i in `seq 1 $R1KHNumberOfEntries` ; do
			R1KHMACAddress="R1KH"$i"MACAddress"
			command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q $R1KHMACAddress"
			R1KHMACAddress=`run_fapi_cli_get_cmd "$command"`
			R1KHId="R1KH"$i"Id"
			command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q $R1KHId"
			R1KHId=`run_fapi_cli_get_cmd "$command"`
			R1KHKey="R1KH"$i"key"
			command="getTR181 -i $fapi_index -t s -p Device.WiFi.AccessPoint.X_LANTIQ_COM_Vendor.Security -q $R1KHKey"
			R1KHKey=`run_fapi_cli_get_cmd "$command"`
			r1kh_list="$r1kh_list""list   r1kh '$R1KHMACAddress,$R1KHId,$R1KHKey'"$'\n'$'\t'$'\t'
		done
	fi

cat <<EOF

config wifi-iface
		option device                  '$device'
		option ifname                  '$ifname'
		option bssid                   '$bssid'
		option network                 '$network'
		option mode                    '$mode'
		option ssid                    '$ssid'
		option macaddr                 '$macaddr'
		option fapi_idx                '$fapi_idx'
		option disabled                '$disabled'
		option encryption              '$encryption'
		option key                     '$key'
		option key1                    '$key1'
		option key2                    '$key2'
		option key3                    '$key3'
		option key4                    '$key4'
		option server                  '$server'
		option port                    '$port'
		option wpa_group_rekey         '$wpa_group_rekey'
		option maxassoc                '$maxassoc'
		option macpolicy               '$macpolicy'
		$maclist_list
		option wps_config              '$wpsConfig'
		option wps_pin                 '$wpsPin'
		option wps_uuid                '$wpsUUID'
		option wps_device_name         '$wpsDevName'
		option wps_manufacturer_url    '$wpsManufacturerUrl'
		option wps_manufacturer        '$wpsManufacturer'
		option wps_pushbutton          '$wpsPushbutton'
		option wmm                     '$wmm'
		option ieee80211r              '$ieee80211r'
		option ieee80211w              '$ieee80211w'
		option hidden                  '$hidden'
		option doth                    '$doth_enabled'
		option dtim_period             '$dtim_period'
		option isolate                 '$isolate'
		option wds                     '$wds'
		option nasid                   '$nasid'
		option mobility_domain         '$mobility_domain'
		option r0_key_lifetime         '$r0_key_lifetime'
		option r1_key_holder           '$r1_key_holder'
		option reassociation_deadline  '$reassociation_deadline'
		$r0kh_list$r1kh_list
EOF
}
