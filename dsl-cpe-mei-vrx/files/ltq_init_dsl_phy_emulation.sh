#!/bin/sh /etc/rc.common
# Copyright (C) 2016 OpenWrt.org
#
# Initializes the DSL PHY via MEI CPE device driver for emulation purpose only.
# This means that NO DSL CPE API should run. However for DSL Firmware debugging
# capability the standalone version of the Winhost should be used.

bindir=/@dsl_bin_dir@
fw_bin=/@dsl_fwbin_dir@/xcpe_hw.bin
pmcs_cfg="@dsl_pmcs_cfg@"

start() {
   echo "================================================================================"
   echo " -- Preparing DSL PHY for emulation --" 
   echo "================================================================================"
   PS=`ps`
   echo $PS | grep -q dsl_cpe_control && {
      echo "Attention: It seems that the DSL CPE API is running but for emulation"
      echo "           this shall be avoided!!!"
   }

   if [ "$1" != "" -a -e $1 ]; then
      fw_bin=$1
      echo "User defined DSL Firmware binary used:"
   else
      echo "Default DSL Firmware binary used:"
   fi
   echo "$fw_bin"
   ${bindir}/what.sh $fw_bin

   echo "================================================================================"
   echo " -- Reset device --"
   echo "================================================================================"
   ${bindir}/mei_cpe_drv_test -R 0x1F0000 -n 0

   echo "================================================================================"
   echo " -- Select VDSL2 mode for VRX, VDSL (with vectoring) and ADSL AnnexA --"
   echo "================================================================================"
   ${bindir}/mei_cpe_drv_test -e -z ${pmcs_cfg} -n 0
 
   echo "================================================================================"
   echo " -- Download firmware --"
   echo " Note:"
   echo " * Within emulation environment firmware download might take up to 20 minutes!!!"
   echo "   Please be patient and get a coffee :-)"
   echo "================================================================================"
   echo "fw_bin=$fw_bin"
   time ${bindir}/mei_cpe_drv_test -n 0 -F -z $fw_bin &
}
