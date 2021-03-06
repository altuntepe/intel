#!/bin/sh

script_name="wave_wlan_config_execute.sh"

# Reconfigure the requested interface by creating/modifying configuration file and execute OTF commands or restart the needed radio.
# When command is "stop", the script calls only the script wave_wlan_down.sh which adds commands to bring down the radio to the runner.
[ ! "$LIB_COMMON_SOURCED" ] && . /tmp/wave_wlan_lib_common.sh
[ ! "$RC_CONF_SOURCED" ] && rc_conf_source

# Define local parameters
local ap_index interface_name
local first_command i radio_cpe_id vendor i_ap_type input_arguments phy_name supported_frequencies rc_conf_freq rc_conf_freq_str supported_frequencies_str

first_command=$1
# If script was called by wave_wlan_start script, set the "start" flag and re-read the first command.
if [ "$first_command" = "start" ]
then
	start_command=yes
	shift
	first_command=$1
fi
ap_index=$2
timestamp $ap_index "$script_name:$ap_index:begin"
print2log $ap_index DEBUG "$script_name $*"

input_arguments=$@


# If the command is logger_modify which was called on init, write the logger commands of the current ap_index to the runner.
[ "$first_command" = "logger_modify" ] && [ "$3" = "init" ] && (. $ETC_PATH/wave_wlan_set_logger_params.sh $ap_index $$ init) && return

# If the command is "stop", no need to call the prepare script.
[ "$first_command" != "stop" ] && (. $ETC_PATH/wave_wlan_prepare.sh $input_arguments)

# Delete the runner file. It will be regenerated by the conf files.
rm -f $CONF_DIR/$WAVE_WLAN_RUNNNER

# If the command is "stop", call only wave_wlan_down.sh script for all the existing radios
if [ "$first_command" = "stop" ]
then
	# Check indexes 1 and 0 to see if they are physical WAVE interfaces and if so, call wave_wlan_down.sh for this interface.
	for i in 1 0
	do
		eval radio_cpe_id=\${wlmn_${i}_radioCpeId}
		radio_cpe_id=$((radio_cpe_id-1))
		eval vendor=\${wlss_${radio_cpe_id}_vendor}
		if [ "$vendor" = "LANTIQ" ]
		then
			eval i_ap_type=\${wlmn_${i}_apType}
			[ "$i_ap_type" = "$AP" ] && eval interface_name=\${wlmnwave_${i}_interfaceName} && (. $ETC_PATH/wave_wlan_down.sh $interface_name)
			# Remove interface related configuration files
			eval interface_name=\${wlmnwave_${i}_interfaceName}
			echo "rm -f $TEMP_CONF_DIR/*${interface_name}* $CONF_DIR/drvhlpr_${interface_name}* $CONF_DIR/hostapd_${interface_name}*" >> $CONF_DIR/$WAVE_WLAN_RUNNNER
		fi
	done
# If the command is "start", call only wave_wlan_up.sh script for all the existing radios
elif [ "$start_command" ]
then
	# Check indexes 0 and 1 to see if they are physical WAVE interfaces and if so, call wave_wlan_up.sh for this interface.
	for i in 0 1
	do
		eval radio_cpe_id=\${wlmn_${i}_radioCpeId}
		radio_cpe_id=$((radio_cpe_id-1))
		eval vendor=\${wlss_${radio_cpe_id}_vendor}
		if [ "$vendor" = "LANTIQ" ]
		then
			eval i_ap_type=\${wlmn_${i}_apType}
			if [ "$i_ap_type" = "$AP" ]
			then
				eval interface_name=\${wlmnwave_${i}_interfaceName}
				(. $ETC_PATH/wave_wlan_up.sh $interface_name)
				# Check if the supported frequencies of the radio is the same as set in rc.conf.
				# If values are not the same, display message to the user in the console to change rc.conf configuration.
				
				# Get the phy name in iw for the interface
				phy_name=`find_phy_from_interface_name $interface_name`
				if [ -n "$phy_name" ]
				then
					# Read iw info for the interface to a file and remove tabs and asterisks
					iw $phy_name info > $TEMP_CONF_DIR\iw_info_${interface_name}
					sed -i -e 's/\t//g' -e 's/\* //' $TEMP_CONF_DIR\iw_info_${interface_name}
					
					# Return the needed parameters
					supported_frequencies=`get_supported_frequencies $TEMP_CONF_DIR\iw_info_${interface_name}`
					rm -rf $TEMP_CONF_DIR\iw_info_${interface_name}
					
					# Read currently set frequency in rc.conf and if it is different than the supported frequency, print message to console
					eval rc_conf_freq=\${wlphy_${i}_freqBand}
					if [ "$supported_frequencies" -ne "$FREQ_BOTH" ] && [ "$supported_frequencies" -ne "$rc_conf_freq" ]
					then
						rc_conf_freq_str=`freq_index_to_str $rc_conf_freq`
						supported_frequencies_str=`freq_index_to_str $supported_frequencies`
						print2log $i ALERT "######################################################################"
						print2log $i ALERT "##### $interface_name is configured to $rc_conf_freq_str and it supports only $supported_frequencies_str."
						print2log $i ALERT "##### Go to web and set the correct configurations"
						print2log $i ALERT "######################################################################"
					fi
				fi
			fi
		fi
	done
	rm -f /tmp/$RESTART_FLAG
else
	# If the restart flag exists, need to restart the radio, if not, just execute the OTF commands.
	if [ -e "/tmp/$RESTART_FLAG" ]
	then
		# Source the RESTART_FLAG file and restart radios that need to be restarted
		. /tmp/$RESTART_FLAG

		[ "$restart_wlan1" = "yes" ] && (. $ETC_PATH/wave_wlan_down.sh wlan1)
		[ "$restart_wlan0" = "yes" ] && (. $ETC_PATH/wave_wlan_down.sh wlan0)

		[ "$restart_wlan0" = "yes" ] && (. $ETC_PATH/wave_wlan_up.sh wlan0)
		[ "$restart_wlan1" = "yes" ] && (. $ETC_PATH/wave_wlan_up.sh wlan1)

		rm /tmp/$RESTART_FLAG
	else
		[ -e $TEMP_CONF_DIR/$OTF_CONFIG_FILE ] && cat $TEMP_CONF_DIR/$OTF_CONFIG_FILE >> $CONF_DIR/$WAVE_WLAN_RUNNNER
		# Delete DRIVER_SINGLE_CALL_CONFIG_FILE since the commands in it are already in OTF file
		rm -f $TEMP_CONF_DIR/${DRIVER_SINGLE_CALL_CONFIG_FILE}_${pap_name}*
	fi
fi

# Delete the OTF file.
rm -f $TEMP_CONF_DIR/$OTF_CONFIG_FILE
# Execute the runner
if [ -e "$CONF_DIR/$WAVE_WLAN_RUNNNER" ]
then
	chmod +x $CONF_DIR/$WAVE_WLAN_RUNNNER
	$CONF_DIR/$WAVE_WLAN_RUNNNER
fi

print2log $ap_index DEBUG "$script_name done"
timestamp $ap_index "$script_name:$ap_index:done"
