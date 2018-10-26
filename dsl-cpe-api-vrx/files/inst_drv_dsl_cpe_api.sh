#! /bin/sh
#
# Install DSL CPE API Driver
# if no para : use local debug level
# para 1 ($1): debug level (0 = use local debug level)
# para 2 ($2): entities (default: 0)
#

BIN_DIR=@dsl_bin_dir@

# check for linux 2.6.x or 3.x or 4.x
uname -r | grep -q -e "^2.6." -e "^3." -e "^4."
if [ $? -eq 0 ]; then
   MODEXT=.ko
fi

drv_dev_base_name=dsl_cpe_api
drv_obj_file_name=drv_dsl_cpe_api$MODEXT

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

[ ! -z "$modlist" ] && {
   echo "- $drv_dev_base_name loaded -"
   exit 0
}

if [ "$debug_level" -le 2 ]; then
   echo "- loading $drv_dev_base_name ($drv_obj_file_name device) driver -"
fi

eval $( cat /proc/driver/mei_cpe/devinfo )

insmod $drv_obj_file_name debug_level=$debug_level\
    g_MaxDeviceNumber=$MaxDeviceNumber g_LinesPerDevice=$LinesPerDevice\
    g_ChannelsPerLine=$ChannelsPerLine
# add "drv_major_number=$drv_major_number" for fixed major number

if [ $? -ne 0 ]; then
   echo "- loading driver failed! -"
   exit 1
fi

major_no=`grep $drv_dev_base_name /proc/devices |cut -d' ' -f1`
#major_no=109

# exit if major number not found (in case of devfs)
if [ -z $major_no ]; then
   exit 0
fi

if [ "$debug_level" -le 2 ]; then
   echo "- create device nodes for $drv_dev_base_name device driver -"
fi

prefix=/dev/$drv_dev_base_name
test ! -d $prefix/ && mkdir $prefix/

# use param $2 or default to 1"
export entities=$(( $MaxDeviceNumber * $LinesPerDevice ))

I=0
while test $I -lt $entities; do
   test ! -e $prefix/$I && mknod $prefix/$I c $major_no $I
   I=`expr $I + 1`
done
