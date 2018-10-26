#! /bin/sh
#
# Install MEI CPE device driver
#
# if no para : use local debug level
# para 1 ($1): debug level (0 = use local debug level)
# para 2 ($2): number of entities (default: 1)
#

bindir=@dsl_bin_dir@

# check for linux 2.6.x or 3.x or 4.x
uname -r | grep -q -e "^2.6." -e "^3." -e "^4."
if [ $? -eq 0 ]; then
    MODEXT=.ko
fi

#drv_major_number=247
drv_dev_base_name=mei_cpe
drv_obj_file_name=drv_mei_cpe$MODEXT

entities=1

# set debug_level: 1=low, 2=normal, 3=high, 4=off
debug_level=3

# use parameter as debug_level, if != 0
if [ $# != 0 ] && [ "$1" != 0 ]; then
   debug_level=$1
fi

# enable debugging outputs, if necessary
if [ "$debug_level" -le 2 ]; then
    echo 8 > /proc/sys/kernel/printk
fi

cmd_modlist="cat /proc/modules | grep $drv_dev_base_name"
modlist=$(eval $cmd_modlist)

if [ -z "$modlist" ]; then

   # installation of the driver is only necessary if a loadable module is used
   if [ -e ${bindir}/${drv_obj_file_name} ]; then
      if [ "$debug_level" -le 2 ]; then
         echo "- loading MEI CPE device driver -"
      fi
      insmod $drv_obj_file_name debug_level=$debug_level
      # add "drv_major_number=$drv_major_number" for fixed major number

      if [ $? -ne 0 ]; then
         echo "- loading driver failed! -"
         exit 1
      fi
   fi

   major_no=`grep mei_cpe /proc/devices |cut -d' ' -f1`
   #major_no=$drv_major_number

   # exit if major number not found (in case of devfs)
   if [ -z $major_no ]; then
      exit 0
   fi

   if [ "$debug_level" -le 2 ]; then
      echo - create device nodes for MEI CPE device driver -
   fi

   prefix=/dev/$drv_dev_base_name
   test ! -d $prefix/ && mkdir $prefix/

   eval $( cat /proc/driver/mei_cpe/devinfo )
   entities=$(( $MaxDeviceNumber * $LinesPerDevice ))

   I=0
   while test $I -lt $entities; do
      test ! -e $prefix/$I && mknod $prefix/$I c $major_no `expr $I`
      I=`expr $I + 1`
   done

else

   echo "- $drv_dev_base_name loaded -"

   eval $( cat /proc/driver/mei_cpe/devinfo )
   entities=$(( $MaxDeviceNumber * $LinesPerDevice ))

fi

if [ -r ${bindir}/dsl.cfg ]; then
    . ${bindir}/dsl.cfg 2> /dev/null
fi

if [ "${xDSL_Cfg_PLL_SwitchOff}" != "" ]; then
   if [ ${entities} -eq 2 ]; then
      echo xDSL_Cfg_PLL_SwitchOff ${xDSL_Cfg_PLL_SwitchOff} 0 > /proc/driver/vrx518/cfg
      echo xDSL_Cfg_PLL_SwitchOff ${xDSL_Cfg_PLL_SwitchOff} 1 > /proc/driver/vrx518/cfg
   else
      echo xDSL_Cfg_PLL_SwitchOff ${xDSL_Cfg_PLL_SwitchOff} 0 > /proc/driver/vrx518/cfg
   fi
fi
