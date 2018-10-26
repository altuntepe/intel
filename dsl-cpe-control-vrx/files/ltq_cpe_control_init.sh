#!/bin/sh /etc/rc.common
# Copyright (C) 2015 OpenWrt.org
exec > /dev/console
xTSE=""
LINE_SET=""
LINE_GET=""

xDSL_BinDir=@dsl_bin_dir@
#xDSL_FwDir=/lib/firmware/`uname -r`
xDSL_FwRootfsDir=@dsl_fw_dir@
# VRX500-BU: To be clarified why the mounting point of the DSL Firmware has been
# changed from '/firmware' to '/lib/firmware'!?
xDSL_FwDir=/firmware
xDSL_FwLibDir=/lib/firmware
xDSL_FwFileName=xcpe_hw.bin
xDSL_FwFileName_2p=xcpe_hw_2p.bin
xDSL_InitDir=/etc/init.d
xDSL_CtrlAppName="ltq_cpe_control_init.sh"
xDSL_WhatStrPrefix="@(#)"

# Default configuration for values that will be overwritten with external
# values defined within "dsl_auto.cfg.
xDSL_AutoCfg_VectoringL2=0

eval $( cat /proc/driver/mei_cpe/devinfo )
xDSL_AutoCfg_Bonding=$(( $MaxDeviceNumber * $LinesPerDevice > 1 ))

status=0
wait_for_dsl_process() {
   retrycnt=10
   i=1
   while [ $i -le $retrycnt ]
   do
      PS=`ps`
      echo $PS | grep -q dsl_cpe_control &>/dev/null && {
         status=1
         return
      }
      let i++
      sleep 1
   done
}

if [ ! "$CONFIGLOADED" ]; then
   if [ -r /etc/rc.d/config.sh ]; then
      . /etc/rc.d/config.sh 2>/dev/null
      CONFIGLOADED="1"
   fi
fi

if [ -r ${xDSL_BinDir}/dsl_auto.cfg ]; then
   . ${xDSL_BinDir}/dsl_auto.cfg 2> /dev/null
fi

if [ ${xDSL_AutoCfg_NumPipes} == "" ]; then
   xDSL_MaxPipeIdx=0
else
   xDSL_MaxPipeIdx=`expr ${xDSL_AutoCfg_NumPipes} - 1`
   if [ ${xDSL_MaxPipeIdx} -lt 0 ]; then
      xDSL_MaxPipeIdx=0
   fi
fi
echo "${xDSL_CtrlAppName}: xDSL_MaxPipeIdx=$xDSL_MaxPipeIdx"

if [ ${xDSL_AutoCfg_Bonding} = 1 ]; then
   # In case of activated bonding an additional line/device parameter needs
   # to be used for all CLI commands.
   # In case of a get command just read it from line/device zero (by default
   # all lines/devices will have the same configuration)
   LINE_GET="0"
   # In case of a set command apply configuration to all lines/devices
   LINE_SET="-1"
fi

# Function to wait until the firmware download has been successfully finished
# on all available lines
# Arguments for this function
#   $1: Timeout in seconds
# Return value(s):
#   FIRMWARE_READY (global variable)
#     0: One or both lines does not reach defined linestate (from $1)
#     1: Both lines have reached defined linestate (from $1)
wait_for_firmware_ready() {
   nTimeout=$(($1 * 2))
   nTimeoutInit=$nTimeout

   while [ $nTimeout -gt 0 ]
   do
      nFirmwareReady=0

      if [ ${xDSL_AutoCfg_Bonding} = 1 ]; then
         nLines=2
      else
         nLines=1
      fi

      nLine=0
      while [ $nLine -lt $nLines ]
      do
         if [ ${xDSL_AutoCfg_Bonding} = 1 ]; then
            nLineGet="$nLine"
         else
            nLineGet=""
         fi

         FDSG_VALS=`${xDSL_BinDir}/dsl_cpe_pipe.sh fdsg $nLineGet`
         if [ "$?" = "0" ]; then
            for k in $FDSG_VALS; do eval $k 2>/dev/null; done
            if [ "$nStatus" == "2" ]; then
               nFirmwareReady=`expr $nFirmwareReady + 1`
            fi
         else
            echo "Error during processing of fdsg command!"
         fi
         nLine=`expr $nLine + 1`
      done
      if [ "$nFirmwareReady" = "$nLines" ]; then
         nTimeUsed=`expr $nTimeoutInit - $nTimeout`
         echo "${xDSL_CtrlAppName}: Firmware ready wait time $nTimeUsed sec."
         FIRMWARE_READY=1
         break
      fi
      nTimeout=`expr $nTimeout - 1`
      usleep 500000;
   done
}

# Function to extract version information from the firmware binary
# on all available lines
# Arguments for this function
#   $1: Firmware binary filename to extract version information (what string)
# Return value(s):
#   FW_WHAT_STRING (global variable)
#
# Remarks on how the what string is defined:
# For VRX platform there is always a combined VDSL/ADSL firmware binary used.
# Therefore two what strings (version numbers) are included within binary.
# The format of the extracted what strings has to have to following format
# /firmware/xcpe_hw.bin : 5.3.1.A.1.6 5.3.3.0.1.1
#                         +---------+ +---------+
#                          VDSL FW     ADSL FW
# For ADSL only platforms (Danube, Amazon-SE, ARX100) there is only one
# what string (version number) included.
# The format of the extracted what strings has to have to following format
# /firmware/dsl_firmware_a.bin : 4.4.7.B.0.1
#                                +---------+
#                                 ADSL FW
# Also note that firmware what string can have an appendix for each version
# that includes some internal, additional debug information/version, typically
# in case if release state (2nd last digit within 6 digits) is '3', for example
# /firmware/xcpe_hw.bin : 5.3.1.A.3.6_02 5.3.3.0.3.1_13
dsl_get_what_string() {
   for i in $1; do
      FW_WHAT_STRING=`strings $i | grep ${xDSL_WhatStrPrefix} | \
         sed "s/\(.*\)${xDSL_WhatStrPrefix}\(.*\)/\2 /g" | tr -d '\n\r'`
   done
}

# Get the Platform-ID from the FW binary that is provided as input.
# Arguments for this function
#   $1: Firmware binary filename to extract version information (what string)
# Return value(s):
#   FW_PLATFORM_ID (global variable)
#
# Remarks:
# The first digit of the xDSL firmware version specifies the pltform as follows:
# 1 - Amazon
# 2 - Danube
# 3 - Amazon-SE
# 4 - ARX100 (AR9)
# 5 - VRX200 (VR9)
# 6 - ARX300 (AR10)
# 7 - VRX318 (VR10)
dsl_get_platform_id() {
   sFirwareBinName=$1

   dsl_get_what_string ${sFirwareBinName}
   FW_WHAT_STRING=${FW_WHAT_STRING#$xDSL_WhatStrPrefix}
   FW_PLATFORM_ID=`echo $FW_WHAT_STRING | cut -d' ' -f1 | cut -d'_' -f1 | cut -d'.' -f1`
}

#Convert arguments from string format to the ascii_code string
#for example argument "123 ABC" => "31 32 33 20 41 42 43"
# Arguments for this function
#   $1: string to convert
# Return value(s):
#   ASCII_RES (global variable)
parse_string_to_ascii() {
   args=$1
   i=0
   ASCII_RES=""
   while [ $i -lt ${#args} ]; do
      ascii_code=`LC_ALL=C printf '%X' "'${args:$i:1}"`
      ASCII_RES=$(echo ${ASCII_RES} ${ascii_code})
      i=$(($i+1))
   done
}

#Set inventory data
# Arguments for this function
#   $1: Fw what string (returned by dsl_get_platform_id function)
#   $2: MAC address (format XX:XX:XX:XX:XX:XX)
dsl_inventory_data_set() {
   sWhatString=$1
   sMacAddr=$2
   asciiInventoryVendor="B5 00 49 46 54 4E 00 00"
   sInventoryAux="12344321"
   ASCII_RES=""

   sPlatform=${CONFIG_IFX_MODEL_NAME%%_*}
   sModelInfo=`cat /etc/version`

   sInvenoryVersion=`echo ${sWhatString} | tr -d '.' | tr -d ' '`
   sInvenoryVersion=`echo ${sInvenoryVersion:0:12} ${sPlatform:0:3}`
   while [ ${#sInvenoryVersion} -lt 16 ]; do sInvenoryVersion=$(echo ${sInvenoryVersion}\_); done

   sPlatform=${sPlatform:0:9}
   while [ ${#sPlatform} -lt 9 ]; do sPlatform=$(echo ${sPlatform}\_); done

   sModelInfo=${sModelInfo:0:9}
   while [ ${#sModelInfo} -lt 9 ]; do sModelInfo=$(echo ${sModelInfo}\_); done

   sInventorySerial=`echo ${sMacAddr//:/} ${sPlatform} ${sModelInfo}`
   while [ ${#sInventorySerial} -lt 16 ]; do sInventorySerial=$(echo ${sInventorySerial}\_); done

   asciiInventoryArgs=${asciiInventoryVendor}
   for i in "${sInvenoryVersion}" "${sInventorySerial}" "${sInventoryAux}"; do
      parse_string_to_ascii "$i"
      asciiInventoryArgs=$(echo ${asciiInventoryArgs} ${ASCII_RES})
   done

   ${xDSL_BinDir}/dsl_cpe_pipe.sh g997lis $LINE_SET ${asciiInventoryArgs} >/dev/null
}

dsl_get_lan_network_interface_ip()
{
   retVal=""
   found=0

   net_if_1="br-lan"
   net_if_2="br0"
   net_if_3="eth0"
   net_if_4="eth0_1"

   for i in 1 2 3 4
   do
      eval "IF=\$net_if_$i"

      CURR_IF=`ifconfig | grep -o $IF | cut -d" " -f1`
      CURR_IF_LEN=${#CURR_IF}

      if [ "$CURR_IF_LEN" -gt 0 ]
      then
         found=1
         break
      fi
   done

   if [ "$found" -eq 1 ]
   then
      retVal=`ifconfig $IF | \
         grep -E -o 'addr:([0-9]{1,3}?\.){3}([0-9]{1,3}?{1})' | \
         cut -d':' -f2`
   else
      retVal=`ifconfig | \
         grep -E -o 'addr:([0-9]{1,3}?\.){3}([0-9]{1,3}?{1})' | \
         grep -v 127.0.0.1 | \
         cut -d':' -f2`
   fi

   # last ifconfig grep command may return couple of IPs
   # in that case return only the first one
   echo $retVal | { read firstIP nextIPs; echo $firstIP; }
}

# Parameters that are externally defined and which are of relevance within
# this script handling
# Starting with "xDSL_Cfg_xxx" or "xDSL_Dbg_xx" are defined within dsl.cfg
start() {

   FW_WHAT_STRING=""
   FW_PLATFORM_ID=0

   MAC_ADR=""
   DBG_TEST_IF=""
   DTI_IF_STR=""
   TCPM_IF_STR=""
   AUTOBOOT_ADSL=""
   AUTOBOOT_VDSL=""
   NOTIFICATION_SCRIPT=""
   DEBUG_CFG=""
   ACTIVATION_CFG=""
   REMEMBER_CFG=""
   TCPM_IF=""
   DTI_IF=""
   XDSL_MULTIMODE=""
   XTM_MULTIMODE=""
   DSL_FIRMWARE=""
   DSL_FIRMWARE_2P=""
   DSL_FIRMWARE_FILE=""
   FW_FOUND=0
   FW_FOUND_2P=0
   START_CTRL=0

   BS_ADSL_US_ENA_API_DEFAULT=1
   BS_ADSL_DS_ENA_API_DEFAULT=1
   BS_VDSL_US_ENA_API_DEFAULT=1
   BS_VDSL_DS_ENA_API_DEFAULT=1
   BS_US_ENA_API_DEFAULT=1
   BS_DS_ENA_API_DEFAULT=1
   VN_US_ENA_API_DEFAULT=1
   VN_DS_ENA_API_DEFAULT=1
   RETX_ADSL_US_ENA_API_DEFAULT=0
   RETX_ADSL_DS_ENA_API_DEFAULT=0
   RETX_VDSL_US_ENA_API_DEFAULT=1
   RETX_VDSL_DS_ENA_API_DEFAULT=1
   CNTL_MODE_ENA=0
   CNTL_MODE=0
   VECT_ENA=1

   # Initialize MAC address with Linux command line setting (from u-boot)
   MAC_ADR=`cat /proc/cmdline | grep -E -o '([a-fA-F0-9]{2}\:){5}[a-fA-F0-9]{2}'`

   # This script handles the DSL FSM for Multimode configuration
   # Determine the mode in which the DSL Control Application should be started
   #echo "0" > /tmp/adsl_status

   if [ -r ${xDSL_BinDir}/dsl.cfg ]; then
      . ${xDSL_BinDir}/dsl.cfg 2> /dev/null
   fi

   if [ -r /tmp/dsl_web.cfg ]; then
      . /tmp/dsl_web.cfg 2> /dev/null
   fi

   echo "${xDSL_CtrlAppName}: DSL related system status:"
   echo "${xDSL_CtrlAppName}:   L2 vectoring = $xDSL_AutoCfg_VectoringL2"
   echo "${xDSL_CtrlAppName}:   bonding      = $xDSL_AutoCfg_Bonding"

   echo `cat /proc/modules` | grep -q "drv_dsl_cpe_api" && {
      START_CTRL=1
   }

   if [ -e ${xDSL_BinDir}/adsl.scr ]; then
      AUTOBOOT_ADSL="-a ${xDSL_BinDir}/adsl.scr"
   fi

   if [ -e ${xDSL_BinDir}/vdsl.scr ]; then
      AUTOBOOT_VDSL="-A ${xDSL_BinDir}/vdsl.scr"
   fi

   if [ -e ${xDSL_InitDir}/xdslrc.sh ]; then
      NOTIFICATION_SCRIPT="-n ${xDSL_InitDir}/xdslrc.sh"
   fi

   if [ -e ${xDSL_FwDir}/${xDSL_FwFileName} ]; then
      DSL_FIRMWARE_FILE="${xDSL_FwDir}/${xDSL_FwFileName}"
      DSL_FIRMWARE="-f ${DSL_FIRMWARE_FILE}"
      FW_FOUND=1
   elif [ -e ${xDSL_FwLibDir}/${xDSL_FwFileName} ]; then
      DSL_FIRMWARE_FILE="${xDSL_FwLibDir}/${xDSL_FwFileName}"
      DSL_FIRMWARE="-f ${DSL_FIRMWARE_FILE}"
      FW_FOUND=1
   elif [ -e ${xDSL_FwRootfsDir}/${xDSL_FwFileName} ]; then
      DSL_FIRMWARE_FILE="${xDSL_FwRootfsDir}/${xDSL_FwFileName}"
      DSL_FIRMWARE="-f ${DSL_FIRMWARE_FILE}"
      FW_FOUND=1
   fi

   if [ ${LinesPerDevice} -ge 2 ]; then
      if [ -e ${xDSL_FwDir}/${xDSL_FwFileName_2p} ]; then
         DSL_FIRMWARE_2P="-F ${xDSL_FwDir}/${xDSL_FwFileName_2p}"
         FW_FOUND_2P=1
      elif [ -e ${xDSL_FwLibDir}/${xDSL_FwFileName_2p} ]; then
         DSL_FIRMWARE_2P="-F ${xDSL_FwLibDir}/${xDSL_FwFileName_2p}"
         FW_FOUND_2P=1
      elif [ -e ${xDSL_FwRootfsDir}/${xDSL_FwFileName_2p} ]; then
         DSL_FIRMWARE_2P="-F ${xDSL_FwRootfsDir}/${xDSL_FwFileName_2p}"
         FW_FOUND_2P=1
      fi
   fi

   # Check if debug capabilities are enabled within dsl_cpe_control
   # and configure according settings if required
   echo `${xDSL_BinDir}/dsl_cpe_control -h` | grep -q "(-D)" && {
      if [ "$xDSL_Dbg_DebugLevel" != "" ]; then
         DEBUG_LEVEL_COMMON="-D${xDSL_Dbg_DebugLevel}"
         if [ "$xDSL_Dbg_DebugLevelsApp" != "" ]; then
            DEBUG_LEVELS_APP="-G${xDSL_Dbg_DebugLevelsApp}"
         fi
         if [ "$xDSL_Dbg_DebugLevelsDrv" != "" ]; then
            DEBUG_LEVELS_DRV="-g${xDSL_Dbg_DebugLevelsDrv}"
         fi
         DEBUG_CFG="${DEBUG_LEVEL_COMMON} ${DEBUG_LEVELS_DRV} ${DEBUG_LEVELS_APP}"
         echo "${xDSL_CtrlAppName}: TestCfg: DEBUG_CFG=${DEBUG_CFG}"
      else
         if [ -e ${xDSL_BinDir}/debug_level.cfg ]; then
            # read in the global definition of the debug level
            . ${xDSL_BinDir}/debug_level.cfg 2> /dev/null

            if [ "$ENABLE_DEBUG_OUTPUT" != "" ]; then
               DEBUG_CFG="-D${ENABLE_DEBUG_OUTPUT}"
            fi
         fi
      fi
   }

   # Usage of debug and test interfaces (if available).
   # Configuration from dsl.cfg
   case "$xDSL_Dbg_DebugAndTestInterfaces" in
      "0")
         # Do not use interfaces, empty string is anyhow default (just in case)
         DBG_TEST_IF=""
         DTI_IF_STR=""
         TCPM_IF_STR=""
         ;;
      "1")
         # Use LAN interfaces for debug and test communication
         DBG_TEST_IF=`dsl_get_lan_network_interface_ip`
         if [ "$DBG_TEST_IF" != "" ]; then
            DTI_IF_STR="-d${DBG_TEST_IF}"
            TCPM_IF_STR="-t${DBG_TEST_IF}"
         else
            echo -e "\033[5m"
            echo "*********************************************************************************************"
            echo "${xDSL_CtrlAppName}: Error - Test and debug interfaces could not be bound to LAN ports!!!"
            echo "*********************************************************************************************"
            echo -e "\033[0m"
            echo "${xDSL_CtrlAppName}: Please consider to change the configuration within"
            echo "${xDSL_CtrlAppName}: ${xDSL_BinDir}/dsl.cfg"
            echo "${xDSL_CtrlAppName}: as follows and reboot the modem afterwards"
            echo "${xDSL_CtrlAppName}: xDSL_Dbg_DebugAndTestInterfaces=\"2\""
         fi
         ;;
      "2")
         # Use all interfaces for debug and test communication
         DBG_TEST_IF="0.0.0.0"
         DTI_IF_STR="-d${DBG_TEST_IF}"
         TCPM_IF_STR="-t${DBG_TEST_IF}"
         ;;
   esac

   echo `${xDSL_BinDir}/dsl_cpe_control -h` | grep -q "(-d)" && {
      DTI_IF="${DTI_IF_STR}"
   }

   # Start DTI standalone agent if available (currently only in case of binding
   # to all interfaces is configured because binding to a specific LAN port
   # IP address does not work correctly)
   if [ "$xDSL_Dbg_DebugAndTestInterfaces" = "2" ]; then
      if [ -e ${xDSL_BinDir}/dsl_cpe_dti_agent ]; then
         ${xDSL_BinDir}/dsl_cpe_dti_agent -l ${LinesPerDevice} -d ${MaxDeviceNumber} -D 1 -p 9001 -a ${DBG_TEST_IF} &
      fi
   fi

   echo `${xDSL_BinDir}/dsl_cpe_control -h` | grep -q "(-t)" && {
      TCPM_IF="${TCPM_IF_STR}"
   }

   #----------------------------------------------------
   # Special test and debug functionality to use Telefonica switching mode
   # configuration from dsl.cfg
   ACTIVATION_CFG="-S${xDSL_Cfg_ActSeq}_${xDSL_Cfg_ActMode}"

   if [ "$xDSL_Cfg_Remember" != "" ]; then
      REMEMBER_CFG="-R${xDSL_Cfg_Remember}"
   elif [ "$DSLRemember" != "" ]; then
      REMEMBER_CFG="-R${DSLRemember}"
   else
      REMEMBER_CFG=""
   fi

   # Special test and debug functionality to use multimode realted
   # configuration for initial xDSL mode
   if [ "$xDSL_Cfg_NextMode" != "" ]; then
      # Use multimode realted configuration from dsl.cfg
      XDSL_MULTIMODE="-M${xDSL_Cfg_NextMode}"
   elif [ "$DSLNextMode" != "" ]; then
      # Use multimode realted configuration from UGW system level provided
      # from SL via dsl_web.cfg
      # Initialize the NextMode with the last showtime mode to optimize the
      # timing of the first link start
      XDSL_MULTIMODE="-M${DSLNextMode}"
      ACTIVATION_CFG="-S${DSLActSeq}_${DSLActMode}"
   else
      # Use default configuration (set to API-default value)
      XDSL_MULTIMODE="-M0"
   fi

   # Special test and debug functionality to use multimode realted
   # configuration for initial SystemInterface configuration
   if [ "$xDSL_Cfg_SystemInterface" != "" ]; then
      # Use multimode realted configuration from dsl.cfg
      XTM_MULTIMODE="-T${xDSL_Cfg_SystemInterface}"
      echo "${xDSL_CtrlAppName}: TestCfg: XTM_MULTIMODE=${XTM_MULTIMODE}"
   elif [ "$LinkEncapsulationConfig" != "" ]; then
      # Use multimode realted configuration from dsl_web.cfg
      XTM_MULTIMODE="-T${LinkEncapsulationConfig}"
      echo "${xDSL_CtrlAppName}: TestCfg: XTM_MULTIMODE=${XTM_MULTIMODE}"
   else
      # Use multimode realted configuration from UGW system level
      if [ "$nADSL_TC_Mode" != "" -a "$nVDSL_TC_Mode" != "" ]; then
         XTM_MULTIMODE="-T$nADSL_TC_Mode:0x1:0x1_$nVDSL_TC_Mode:0x1:0x1"
      else
         XTM_MULTIMODE=""
      fi
   fi

   # Device and line configuration
   DEVICE_LAYOUT="-V${MaxDeviceNumber} -L${LinesPerDevice} -C${ChannelsPerLine}"

   ##########################################################################
   # start dsl cpe control application with appropriate options

   if [ ${FW_FOUND} = 0 ]; then
      echo "${xDSL_CtrlAppName}: API *not* started! " \
         "No firmware binary available within '${xDSL_FwDir}'"
   elif [ ${FW_FOUND_2P} = 0 -a ${xDSL_AutoCfg_LinesPerDevice} -ge 2 ]; then
      echo "${xDSL_CtrlAppName}: API *not* started! " \
         "No 2P firmware binary available within '${xDSL_FwDir}'"
   elif [ ${START_CTRL} = 0 ]; then
      echo "${xDSL_CtrlAppName}: API *not* started! " \
         "API driver (drv_dsl_cpe_api) not installed within system"
   else
      # Special test and debug functionality uses xTSE configuration from dsl.cfg
      if [ "$xDSL_Cfg_G997XtuSet" == "0" ]; then
         xTSE=""
         echo "${xDSL_CtrlAppName}: TestCfg: xTSE=API internal defaults"
      elif [ "$xDSL_Cfg_G997XtuSet" == "1" ]; then
         xTSE="${xDSL_Cfg_G997XtuVal}"
         echo "${xDSL_CtrlAppName}: TestCfg: xTSE=${xTSE}"
      # Standard configuration uses xTSE configuration from dsl_web.cfg
      elif [ "$XTSE" != "" ]; then
         xTSE="${XTSE}"
         echo "${xDSL_CtrlAppName}: StandardCfg: xTSE=${xTSE} (system level data base)"
      else
         xTSE=""
         echo "${xDSL_CtrlAppName}: DefaultCfg: xTSE=API internal defaults (no dedicated cfg provided!)"
      fi

      # Special test and debug functionality to activate DSL related kernel prints
      if [ "$xDSL_Dbg_EnablePrint" == "1" ]; then
         echo 8 > /proc/sys/kernel/printk
      fi

      # start DSL CPE Control Application in the background
      ${xDSL_BinDir}/dsl_cpe_control ${DEBUG_CFG} -i${xTSE} ${DSL_FIRMWARE} \
         ${DSL_FIRMWARE_2P} ${XDSL_MULTIMODE} ${XTM_MULTIMODE} ${AUTOBOOT_VDSL} \
         ${AUTOBOOT_ADSL} ${NOTIFICATION_SCRIPT} ${TCPM_IF} ${DTI_IF} \
         ${ACTIVATION_CFG} ${REMEMBER_CFG} ${DEVICE_LAYOUT} &

      wait_for_dsl_process

      # Timeout to wait for dsl_cpe_control startup [in seconds]
      iLp=10
      [ $status == 1 ] && {
         # workaround for nfs: allow write to pipes for non-root
         while [ ! -e /tmp/pipe/dsl_cpe${xDSL_MaxPipeIdx}_ack -a $iLp -gt 0 ] ; do
            iLp=`expr $iLp - 1`
            usleep 500000;
         done

         if [ ${iLp} -le 0 ]; then
            echo "${xDSL_CtrlAppName}: Problem with pipe handling, exit" \
               "dsl_cpe_control startup!!!"
            exit 1
         fi

         chmod a+w /tmp/pipe/dsl_*
      }
      [ $status == 0 ] && {
         echo "${xDSL_CtrlAppName}: Start of dsl_cpe_control failed!!!"
         exit 1
      }

      # Special test and debug functionality to activate event console prints
      if [ "$xDSL_Dbg_EnablePrint" == "1" ]; then
         tail -f /tmp/pipe/dsl_cpe0_event &
      fi

      sleep 1

      #if [ "$wan_mode" = "ADSL" ]; then
      #   /usr/sbin/status_oper SET BW_INFO max_us_bw "512"
      #fi

      # Apply low level configurations
      # Special test and debug functionality uses Handshake tone configuration from dsl.cfg
      if [ "$xDSL_Cfg_LowLevelHsTonesSet" == "1" ]; then
         echo "${xDSL_CtrlAppName}: TestCfg: Test/Debug cfg for HS tones selected"
         echo "${xDSL_CtrlAppName}:   A =0x${xDSL_Cfg_LowLevelHsTonesVal_A}"
         echo "${xDSL_CtrlAppName}:   V =0x${xDSL_Cfg_LowLevelHsTonesVal_V}"

         LLCG_VALS=`${xDSL_BinDir}/dsl_cpe_pipe.sh llcg $LINE_GET`
         if [ "$?" = "0" ]; then
            for i in $LLCG_VALS; do eval $i 2>/dev/null; done
            ${xDSL_BinDir}/dsl_cpe_pipe.sh llcs $LINE_SET $nFilter 1 \
               $xDSL_Cfg_LowLevelHsTonesVal_A $xDSL_Cfg_LowLevelHsTonesVal_V \
               0 $nBaseAddr $nIrqNum $bNtrEnable >/dev/null
         else
            echo "Error during processing of HS tones. Using defaults instead!"
         fi
      fi

      usleep 500000;

      #Init BitSwap config
      nDslMode="ADSL VDSL"
      nDir="US DS"
      for m in $nDslMode ; do
       for d in $nDir ; do
         if [ "$xDSL_Cfg_BitswapEnable" != "" ]; then
            if [ "$xDSL_Cfg_BitswapEnable" = "0" ]; then
               #ADSL
               if [ "$m" = "ADSL" ]; then
                  #ADSL US
                  if [ "$d" = "US" ]; then
                     BS_ENA_CLI="${BS_ADSL_US_ENA_API_DEFAULT}"
                  #ADSL DS
                  else
                     BS_ENA_CLI="${BS_ADSL_DS_ENA_API_DEFAULT}"
                  fi
               #VDSL
               else
                  #VDSL US
                  if [ "$d" = "US" ]; then
                     BS_ENA_CLI="${BS_VDSL_US_ENA_API_DEFAULT}"
                  #VDSL DS
                  else
                     BS_ENA_CLI="${BS_VDSL_DS_ENA_API_DEFAULT}"
                  fi
               fi
            else
            #ADSL
               if [ "$m" = "ADSL" ]; then
                  #ADSL US
                  if [ "$d" = "US" ]; then
                     BS_ENA_CLI=${xDSL_Cfg_Bitswap_A_Us}
                  #ADSL DS
                  else
                     BS_ENA_CLI=${xDSL_Cfg_Bitswap_A_Ds}
                  fi
               #VDSL
               else
                  #VDSL US
                  if [ "$d" = "US" ]; then
                     BS_ENA_CLI=${xDSL_Cfg_Bitswap_V_Us}
                  #VDSL DS
                  else
                     BS_ENA_CLI=${xDSL_Cfg_Bitswap_V_Ds}
                  fi
               fi
            fi
         #from SL via dsl_web.cfg
         else
            #ADSL
            if [ "$m" = "ADSL" ]; then
               #ADSL US
               if [ "$d" = "US" ]; then
                  if [ "$BitswapUs_A" != "" ]; then
                     BS_ENA_CLI=${BitswapUs_A}
                  else
                     BS_ENA_CLI="${BS_ADSL_US_ENA_API_DEFAULT}"
                  fi
               else
                  #ADSL DS
                  if [ "$BitswapDs_A" != "" ]; then
                     BS_ENA_CLI=${BitswapDs_A}
                  else
                     BS_ENA_CLI="${BS_ADSL_DS_ENA_API_DEFAULT}"
                  fi
               fi
            #VDSL
            else
               #VDSL US
               if [ "$d" = "US" ]; then
                  if [ "$BitswapUs_V" != "" ]; then
                     BS_ENA_CLI=${BitswapUs_V}
                  else
                     BS_ENA_CLI="${BS_VDSL_US_ENA_API_DEFAULT}"
                  fi
               #VDSL DS
               else
                  if [ "$BitswapDs_V" != "" ]; then
                     BS_ENA_CLI=${BitswapDs_V}
                  else
                     BS_ENA_CLI="${BS_VDSL_DS_ENA_API_DEFAULT}"
                  fi
               fi
            fi
         fi

         #ADSL
         if [ "$m" = "ADSL" ]; then
            #ADSL US
            if [ "$d" = "US" ]; then
               BS_A_US_ENA_CLI="${BS_ENA_CLI}"
               echo "${xDSL_CtrlAppName}: TestCfg: BS_A_US_ENA_CLI=${BS_A_US_ENA_CLI}"
            #ADSL DS
            else
               BS_A_DS_ENA_CLI="${BS_ENA_CLI}"
               echo "${xDSL_CtrlAppName}: TestCfg: BS_A_DS_ENA_CLI=${BS_A_DS_ENA_CLI}"
            fi
         #VDSL
         else
            #VDSL US
            if [ "$d" = "US" ]; then
               BS_V_US_ENA_CLI="${BS_ENA_CLI}"
               echo "${xDSL_CtrlAppName}: TestCfg: BS_V_US_ENA_CLI=${BS_V_US_ENA_CLI}"
            #VDSL DS
            else
               BS_V_DS_ENA_CLI="${BS_ENA_CLI}"
               echo "${xDSL_CtrlAppName}: TestCfg: BS_V_DS_ENA_CLI=${BS_V_DS_ENA_CLI}"
            fi
         fi
       done
      done

      #Init VirtualNoise config
      nDir="US DS"
      for d in $nDir ; do
         # Special test and debug functionality uses VirtNoise configuration from dsl.cfg
         # otherwise from SL via dsl_web.cfg
         if [ "$xDSL_Cfg_VNEnable" != "" ]; then
            VN_ENA_CLI="${xDSL_Cfg_VNEnable}"
         elif [ "$d" = "US" ]; then
            #US direction
            if [ "$VirtualNoiseUs" != "" ]; then
               VN_ENA_CLI="${VirtualNoiseUs}"
            else
               VN_ENA_CLI="${VN_US_ENA_API_DEFAULT}"
            fi
         else
            #DS direction
            if [ "$VirtualNoiseDs" != "" ]; then
               VN_ENA_CLI="${VirtualNoiseDs}"
            else
               VN_ENA_CLI="${VN_DS_ENA_API_DEFAULT}"
            fi
         fi

         if [ "$d" = "US" ]; then
            #US direction
            VN_US_ENA_CLI="${VN_ENA_CLI}"
            echo "${xDSL_CtrlAppName}: TestCfg: VN_US_ENA_CLI=${VN_US_ENA_CLI}"
         else
            #DS direction
            VN_DS_ENA_CLI="${VN_ENA_CLI}"
            echo "${xDSL_CtrlAppName}: TestCfg: VN_DS_ENA_CLI=${VN_DS_ENA_CLI}"
         fi
      done

      #Init ReTx config
      nDslMode="ADSL VDSL"
      nDir="US DS"
      for m in $nDslMode ; do
         for d in $nDir ; do
            if [ "$xDSL_Cfg_ReTxSet" != "" ]; then
               # Special test and debug functionality uses ReTx configuration from dsl.cfg
               if [ "$xDSL_Cfg_ReTxSet" = "0" ]; then
                  #ADSL
                  if [ "$m" = "ADSL" ]; then
                     #ADSL US
                     if [ "$d" = "US" ]; then
                        RETX_ENA_CLI="0"
                     else
                     #ADSL DS
                        RETX_ENA_CLI="0"
                     fi
                  #VDSL
                  else
                     #VDSL US
                     if [ "$d" = "US" ]; then
                        RETX_ENA_CLI="1"
                     else
                     #VDSL DS
                        RETX_ENA_CLI="1"
                     fi
                  fi
               else
                  #ADSL
                  if [ "$m" = "ADSL" ]; then
                     #ADSL US
                     if [ "$d" = "US" ]; then
                        if [ "$xDSL_Cfg_ReTxVal_A_Us" != "" ]; then
                           RETX_ENA_CLI=${xDSL_Cfg_ReTxVal_A_Us}
                        else
                           RETX_ENA_CLI="${RETX_ADSL_US_ENA_API_DEFAULT}"
                        fi
                     else
                     #ADSL DS
                        if [ "$xDSL_Cfg_ReTxVal_A_Ds" != "" ]; then
                           RETX_ENA_CLI=${xDSL_Cfg_ReTxVal_A_Ds}
                        else
                           RETX_ENA_CLI="${RETX_ADSL_DS_ENA_API_DEFAULT}"
                        fi
                     fi
                  #VDSL
                  else
                     #VDSL US
                     if [ "$d" = "US" ]; then
                        if [ "$xDSL_Cfg_ReTxVal_V_Us" != "" ]; then
                           RETX_ENA_CLI=${xDSL_Cfg_ReTxVal_V_Us}
                        else
                           RETX_ENA_CLI="${RETX_VDSL_US_ENA_API_DEFAULT}"
                        fi
                     else
                     #VDSL DS
                        if [ "$xDSL_Cfg_ReTxVal_V_Ds" != "" ]; then
                           RETX_ENA_CLI=${xDSL_Cfg_ReTxVal_V_Ds}
                        else
                           RETX_ENA_CLI="${RETX_VDSL_DS_ENA_API_DEFAULT}"
                        fi
                     fi
                  fi
               fi
            #from SL via dsl_web.cfg
            else
               #ADSL
               if [ "$m" = "ADSL" ]; then
                  #ADSL US
                  if [ "$d" = "US" ]; then
                     RETX_ENA_CLI="${RETX_ADSL_US_ENA_API_DEFAULT}"
                  else
                  #ADSL DS
                     RETX_ENA_CLI="${RETX_ADSL_DS_ENA_API_DEFAULT}"
                  fi
               #VDSL
               else
                  #VDSL US
                  if [ "$d" = "US" ]; then
                     if [ "$ReTxUs" != "" ]; then
                        RETX_ENA_CLI="${ReTxUs}"
                     else
                        RETX_ENA_CLI="${RETX_VDSL_US_ENA_API_DEFAULT}"
                     fi
                  else
                  #VDSL DS
                     if [ "$ReTxDs" != "" ]; then
                        RETX_ENA_CLI="${ReTxDs}"
                     else
                        RETX_ENA_CLI="${RETX_VDSL_DS_ENA_API_DEFAULT}"
                     fi
                  fi
               fi
            fi

            #ADSL
            if [ "$m" = "ADSL" ]; then
               #ADSL US
               if [ "$d" = "US" ]; then
                  RETX_A_US_ENA_CLI="${RETX_ENA_CLI}"
                  echo "${xDSL_CtrlAppName}: TestCfg: RETX_A_US_ENA_CLI=${RETX_A_US_ENA_CLI}"
               #ADSL DS
               else
                  RETX_A_DS_ENA_CLI="${RETX_ENA_CLI}"
                  echo "${xDSL_CtrlAppName}: TestCfg: RETX_A_DS_ENA_CLI=${RETX_A_DS_ENA_CLI}"
               fi
            #VDSL
            else
               #VDSL US
               if [ "$d" = "US" ]; then
                  RETX_V_US_ENA_CLI="${RETX_ENA_CLI}"
                  echo "${xDSL_CtrlAppName}: TestCfg: RETX_V_US_ENA_CLI=${RETX_V_US_ENA_CLI}"
               #VDSL DS
               else
                  RETX_V_DS_ENA_CLI="${RETX_ENA_CLI}"
                  echo "${xDSL_CtrlAppName}: TestCfg: RETX_V_DS_ENA_CLI=${RETX_V_DS_ENA_CLI}"
               fi
            fi

         done
      done

      # Apply configurations for LineFeatureConfigSet (lfcs)
      nDslMode="0 1"
      nDir="0 1"
      for i in $nDslMode ; do
       for j in $nDir ; do
         LFCG_VALS=`${xDSL_BinDir}/dsl_cpe_pipe.sh lfcg $LINE_GET $i $j`
         if [ "$?" = "0" ]; then
            # Take current API defaults for config parameters
            for k in $LFCG_VALS; do eval $k 2>/dev/null; done
            TRELLIS_ENA_CLI=$bTrellisEnable
            TWENTY_BIT_CLI=$b20BitSupport
         else
            # In case config get failed set defaults for config parameters
            TRELLIS_ENA_CLI="1"
            TWENTY_BIT_CLI="-1"
         fi

         #ADSL
         if [ "$i" = "0" ]; then
            #US
            if [ "$j" = "0" ]; then
               BS_ENA_CLI="${BS_A_US_ENA_CLI}"
               VN_ENA_CLI="${VN_US_ENA_CLI}"
               RETX_ENA_CLI="${RETX_A_US_ENA_CLI}"
            #DS
            else
               BS_ENA_CLI="${BS_A_DS_ENA_CLI}"
               VN_ENA_CLI="${VN_DS_ENA_CLI}"
               RETX_ENA_CLI="${RETX_A_DS_ENA_CLI}"
            fi
         #VDSL
         else
            #US
            if [ "$j" = "0" ]; then
               BS_ENA_CLI="${BS_V_US_ENA_CLI}"
               VN_ENA_CLI="${VN_US_ENA_CLI}"
               RETX_ENA_CLI="${RETX_V_US_ENA_CLI}"
            #DS
            else
               BS_ENA_CLI="${BS_V_DS_ENA_CLI}"
               VN_ENA_CLI="${VN_DS_ENA_CLI}"
               RETX_ENA_CLI="${RETX_V_DS_ENA_CLI}"
            fi
         fi

         ${xDSL_BinDir}/dsl_cpe_pipe.sh lfcs $LINE_SET $i $j $TRELLIS_ENA_CLI \
            $BS_ENA_CLI $RETX_ENA_CLI $VN_ENA_CLI $TWENTY_BIT_CLI >/dev/null
       done
      done

      # Apply TestMode configuration from system level configuration
      if [ "$CNTL_MODE_ENA" = "1" ]; then
         if [ "$CNTL_MODE" = "0" ]; then
            ${xDSL_BinDir}/dsl_cpe_pipe.sh tmcs $LINE_SET 1 >/dev/null
         elif [ "$CNTL_MODE" = "1" ]; then
            ${xDSL_BinDir}/dsl_cpe_pipe.sh tmcs $LINE_SET 2 >/dev/null
         fi
      fi

      # Apply configurations for reboot criteria's
      # Special test and debug functionality uses configuration from dsl.cfg
      if [ "$xDSL_Cfg_RebootCritSet" == "1" ]; then
         ${xDSL_BinDir}/dsl_cpe_pipe.sh rccs $LINE_SET 0 $xDSL_Cfg_RebootCritVal_A >/dev/null
         echo "${xDSL_CtrlAppName}: TestCfg: xDSL_Cfg_RebootCritVal_A=${xDSL_Cfg_RebootCritVal_A}"
         ${xDSL_BinDir}/dsl_cpe_pipe.sh rccs $LINE_SET 1 $xDSL_Cfg_RebootCritVal_V >/dev/null
         echo "${xDSL_CtrlAppName}: TestCfg: xDSL_Cfg_RebootCritVal_V=${xDSL_Cfg_RebootCritVal_V}"
      fi

      # Apply configurations for Vdsl profile config
      # Special test and debug functionality uses configuration from dsl.cfg
      if [ "$xDSL_Cfg_VdslProfileSet" == "1" ]; then
         ${xDSL_BinDir}/dsl_cpe_pipe.sh vpcs $LINE_SET $xDSL_Cfg_VdslProfileVal >/dev/null
         echo "${xDSL_CtrlAppName}: TestCfg: xDSL_Cfg_VdslProfileVal=${xDSL_Cfg_VdslProfileVal}"
      fi

      # Apply configurations for SRA
      # Special test and debug functionality uses configuration from dsl.cfg
      if [ "$xDSL_Cfg_SraSet" == "1" ]; then
         ${xDSL_BinDir}/dsl_cpe_pipe.sh g997racs $LINE_SET 0 0 `expr $xDSL_Cfg_SraVal_A_Us + 2` >/dev/null
         ${xDSL_BinDir}/dsl_cpe_pipe.sh g997racs $LINE_SET 0 1 `expr $xDSL_Cfg_SraVal_A_Ds + 2` >/dev/null
         ${xDSL_BinDir}/dsl_cpe_pipe.sh g997racs $LINE_SET 1 0 `expr $xDSL_Cfg_SraVal_V_Us + 2` >/dev/null
         ${xDSL_BinDir}/dsl_cpe_pipe.sh g997racs $LINE_SET 1 1 `expr $xDSL_Cfg_SraVal_V_Ds + 2` >/dev/null
         echo "${xDSL_CtrlAppName}: TestCfg: xDSL_Cfg_SraVal_A_Us=${xDSL_Cfg_SraVal_A_Us}"
         echo "${xDSL_CtrlAppName}: TestCfg: xDSL_Cfg_SraVal_A_Ds=${xDSL_Cfg_SraVal_A_Ds}"
         echo "${xDSL_CtrlAppName}: TestCfg: xDSL_Cfg_SraVal_V_Us=${xDSL_Cfg_SraVal_V_Us}"
         echo "${xDSL_CtrlAppName}: TestCfg: xDSL_Cfg_SraVal_V_Ds=${xDSL_Cfg_SraVal_V_Ds}"
      fi

      # get platform information from
      dsl_get_platform_id ${DSL_FIRMWARE_FILE}

      # Temporary solution using BAR13 to let DSL FW access the MIPS registers
      # FFS_REG to reset the TC layer PTM code word generator (required for US-ReTx).
      # The FFSM_REG is platform dependent, means different for VRX200 and VRX300
      case "$FW_PLATFORM_ID" in
         "5")
            PP_REGBASE="1E234000"
            echo "${xDSL_CtrlAppName}: US-ReTx: Set BAR13 to 0x${PP_REGBASE} (VRX200)"
            echo 13 ${PP_REGBASE} > /proc/driver/mei_cpe/bar_usr_dbg/00
            ;;
         "7")
            PP_REGBASE="1E234000"
            echo "${xDSL_CtrlAppName}: US-ReTx: Set BAR13 of line 0 to 0x${PP_REGBASE} (VRX300)"
            echo 13 ${PP_REGBASE} > /proc/driver/mei_cpe/bar_usr_dbg/00
            if [ ${xDSL_AutoCfg_Bonding} = 1 ]; then
               echo "${xDSL_CtrlAppName}: US-ReTx: Set BAR13 of line 1 to 0x${PP_REGBASE} (VRX300)"
               echo 13 ${PP_REGBASE} > /proc/driver/mei_cpe/bar_usr_dbg/01
            fi
            ;;
         "8")
            # Currently the BAR13 configuration is not used (just reserved)
            ;;
         *)
            echo "${xDSL_CtrlAppName}: US-ReTx: BAR13 *not* configured (unknown PlatformID)!!!"
            ;;
      esac

      #@model_name@

      if [ -z "$CONFIG_IFX_MODEL_NAME" ]; then
         echo "CONFIG_IFX_MODEL_NAME unset or empty. Setting to GRX550_2000_MR_ETH_RT_81";
         CONFIG_IFX_MODEL_NAME="GRX550_2000_MR_ETH_RT_81"
      fi

      dsl_inventory_data_set "${FW_WHAT_STRING}" ${MAC_ADR}

      FIRMWARE_READY=0
      wait_for_firmware_ready 7

      if [ $FIRMWARE_READY = 1 ]; then

         # Configurations that are done directly within MEI driver MUST be done after
         # Firmware download has been finished (because some configurations require
         # information about FW capabilities!

         platform=${CONFIG_IFX_MODEL_NAME%%_*}
         if [ $platform = "VRX220" ]; then
            echo "${xDSL_CtrlAppName}: Setting PLL offset to -30 ppm (VRX220)"
            ${xDSL_BinDir}/dsl_cpe_pipe.sh meipocs $LINE_SET -30
         fi

         if [ ${xDSL_AutoCfg_VectoringL2} = 1 ]; then
            ${xDSL_BinDir}/dsl_cpe_pipe.sh dsmmcs $LINE_SET $MAC_ADR
            # Special functionality uses vectoring configuration from dsl.cfg
            if [ "$xDSL_Cfg_VectoringEnable" = "" ]; then
               # update variable from dsl_web.cfg for empty value case
               xDSL_Cfg_VectoringEnable="$Vectoring"
            fi
            if [ "$xDSL_Cfg_VectoringEnable" != "" ]; then
               if [ ${xDSL_Cfg_VectoringEnable} = 3 ]; then
                  # *No* configuration required in this case (MEI driver handles it autonomously)!
                  echo "${xDSL_CtrlAppName}: G.Vector (best fitting, automatic MEI Driver mode)"
               else
                  ${xDSL_BinDir}/dsl_cpe_pipe.sh dsmcs $LINE_SET $xDSL_Cfg_VectoringEnable
                  echo "${xDSL_CtrlAppName}: G.Vector configuration = ${xDSL_Cfg_VectoringEnable}"
               fi
            else
               # Not supported yet, using MEI Driver automatic mode instead as default
               #if [ "$VECT_ENA" = "1" ]; then
               #   ${xDSL_BinDir}/dsl_cpe_pipe.sh dsmcs $LINE_SET 1
               #fi
               # *No* configuration required in this case (MEI driver handles it autonomously)!
               echo "${xDSL_CtrlAppName}: G.Vector (best fitting, automatic MEI Driver mode)"
            fi
         fi

         # Test and Debug configuration only: Switch back to polling mode if configured within dsl.cfg
         if [ "$xDSL_Dbg_FwMsgPollingOnly" = "1" ]; then
            echo "${xDSL_CtrlAppName}: TestCfg: xDSL_Dbg_FwMsgPollingOnly=$xDSL_Dbg_FwMsgPollingOnly"
            ${xDSL_BinDir}/dsl_cpe_pipe.sh ics $LINE_SET 1 0 0
         fi

         ${xDSL_BinDir}/dsl_cpe_pipe.sh acs $LINE_SET 1
      else
         echo "Timeout within waiting for firmware ready!"
         echo "Autoboot handling of API could be not started!"
      fi
   fi
}

stop() {
   if [ -r ${xDSL_BinDir}/dsl.cfg ]; then
      . ${xDSL_BinDir}/dsl.cfg 2> /dev/null
   fi

   if [ ${xDSL_AutoCfg_Bonding} = 1 ]; then
      sLineNumsToDisable="1 0"
   else
      sLineNumsToDisable="0"
   fi
   bDisableAllLines=1

   # from SL via dsl_web.cfg
   if [ "${xDSL_Cfg_EntitiesEnabledSet}" == "" ]; then
	#reset it to 0 when dsl webcfg not found as its duplicate variable from
	#mei_cpe/devinfo and getting exported
	EntitiesEnabled=0
      if [ -r /tmp/dsl_web.cfg ]; then
         . /tmp/dsl_web.cfg 2> /dev/null
      fi

      # all lines will be operated
      if [ "${EntitiesEnabled}" == "2" ]; then

         sLineNumsToDisable=""
         bDisableAllLines=0

      # one line will be operated
      elif [ "${EntitiesEnabled}" == "1" ]; then

         bDisableAllLines=0

         if [ ${xDSL_AutoCfg_Bonding} = 1 ]; then
            sLineNumsToDisable="1"
         else
            sLineNumsToDisable=""
         fi

      # none lines will be operated
      else
         :
      fi

   # from dsl.cfg
   else

      # all lines will be operated
      if [ "${xDSL_Cfg_EntitiesEnabledSet}" == "0" ] ||
         ([ "${xDSL_Cfg_EntitiesEnabledSet}" == "1" ] && [ "${xDSL_Cfg_EntitiesEnabledSelect}" == "2" ]); then

         sLineNumsToDisable=""
         bDisableAllLines=0

      # one line will be operated
      elif [ "${xDSL_Cfg_EntitiesEnabledSet}" == "1" ] && [ "${xDSL_Cfg_EntitiesEnabledSelect}" == "1" ]; then

         bDisableAllLines=0

         if [ ${xDSL_AutoCfg_Bonding} = 1 ]; then
            sLineNumsToDisable="1"
         else
            sLineNumsToDisable=""
         fi

      # none lines will be operated
      else
         :
      fi
   fi

   for line in $sLineNumsToDisable; do
      echo "${xDSL_CtrlAppName}: stop(): line[${line}]"

      if [ ${xDSL_AutoCfg_Bonding} -ne 1 ]; then
         # backward-compatibility
         line=""
      fi

      if [ "${xDSL_Cfg_LdAfeShutdown}" == "1" ]; then
         ${xDSL_BinDir}/dsl_cpe_pipe.sh acs $line 7
         sleep 3
      else
         ${xDSL_BinDir}/dsl_cpe_pipe.sh acos $line 1 1 1 0 0 0
         ${xDSL_BinDir}/dsl_cpe_pipe.sh acs $line 2
         sleep 3
         ${xDSL_BinDir}/dsl_cpe_pipe.sh acs $line 0
      fi
   done

   if [ ${bDisableAllLines} -eq 1 ]; then
      ${xDSL_BinDir}/dsl_cpe_pipe.sh quit $LINE_SET
   fi
}
