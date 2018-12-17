# mcast-pa

Source code for the mcast-pa (Multicast Packet Acclerator) application.

You can find more details about mcast-pa specifically in doc/mcast-pa.pdf.. this readme will cover the package layout and other functionality outside of mcast-pa.

## License
Copyright (c) 2018 by SmartRG, Inc.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

## IPTV Overview

This package contains everything necessary to run a hardened IPTV implementation with packet acceleration on the xrx500 platform. It consists of a few main pieces:

* iptv config and init script
* iptv hotplug (used to reload mcproxy on certain interface level events)
* kernel patches to add eth_addr to struct br_mdb_entry and populate it
* mcast-pa source code with adaptation layer to support Intel xrx500 PPA

The iptv config file is where all IPTV configuration should go. The associated init script will create relevant configs for mcproxy as well as start/stop the process and also start/stop mcast-pa with appropriate arguments.

Currently the iptv config is committed directly in the files directory.. it should be turned into a uci-default.

Control is handled as follows: iptv (boot/start) -> read iptv config -> generate mcproxy config -> start mcproxy -> start mcast-pa using mcastpamgr.sh

Running /etc/init.d/iptv start will perform the above and start all necessary apps; likewise stop will stop all apps.

## Building

In the default operating mode for Intel, dependencies necessary include:

* libmcastfapi - to be provided by Intel
* mcast_helper - kernel module to be provided by Intel
* switch_cli - part of Intel UGW; not mandatory.. I believe mcastpamgr.sh only calls this to set an unknown multicast rate limit on the CPU port for protection
* reamining dependencies are part of OpenWrt (libpcap, librt, ip-full and mcproxy)

It also may be best to break out the iptv scripts and hotplug into their own package at some point as they are separate entities not tied directly to mcast-pa. For the sake of simplicity, everything is packated into one repo for now.

In order to contain this all within a single package, two kernel patches are included in the "patches-kernel" directory. These should go in our target directory once we have one.

NOTE: the above kernel patches were updated to support kernel 4.9 (what UGW 8.x is based on).. if you happen to be using an older kernel such as 3.10 (what UGW 7.x is based on) you can see the previous commit in the directory mentioned above.

## Mcproxy

Mcproxy (https://github.com/mcproxy/mcproxy) is used to proxy multicast. The package is already incldued in the OpenWrt routing feed.

On initial investigation, it looks like the maintainers incldued our checksum patch in the master branch back on Aug 24, 2017. 

That being said, we have at least 2 more patches to fix the filtering functionality and blacklist groups that shouldn't be forwarded from LAN->WAN. I will work with Imre or whomever does integration to get these included.

IGMP stat retreival is still TBD.

## Multicast PA Modes and Status

There are 3 mutually exclusive operational modes available within the Intel adaptation layer:

1.  INTEL_MCAST_USE_PPA - use ppacmd to add and remove multicast group memberships in hardware
2.  INTEL_MCAST_USE_MCAST_CLI - use mcast_cli to add and remove multicast group memberships in hardware
3.  INTEL_MCAST_USE_MCAST_FAPI - use Intel's multicast FAPI to add and remove multicast group memberships in hardware
		
Mode #3 (FAPI) is the default and preferred method but #1 (ppacmd) can be useful for debugging.

Once up and running, you can view a debug status from mcast-pa using the following command.. sample output included. 

In the sample, my WAN interface is wan.3 (tagged VLAN 3), WAN IP is 10.0.3.106, IPTV client is conneced to lan2 and the video streamer source IP is 10.0.3.17.

For those unfamiliar with PPA, check the section "ppacmd getmcgroups" to see which groups are programmed into the hardware accelerator. You shold see a section like the following:

ppacmd output:

    [000] MC GROUP:224.  0. 18.101 Src IP: 10.0.3.17 
         (route ) qid( 0) dscp( 0) vlan (0000/ffffffff) mib (0:11171148(cpu:hw mib in byte)) From  wan.3 to  lan2
         ADDED_IN_HW|VALID_VLAN_RM|SESSION_VALID_OUT_VLAN_RM|VALID_NEW_SRC_MAC
		 
Note the "hw mib in byte" counter (in this case the value is 11171148).. it shows the number of bytes that have been accelerated for multicast group 224.0.18.101.

Statistics and info related to replication (e.g. same stream to multiple WiFi clients) can be observed in /proc/mcast_helper (also included in mcastpamgr.sh debug output below).

Sample output:
~~~~
SR900ac-FE40-linux: scripts # mcastpamgr.sh show
 
 
ip route: 
 
default via 10.0.3.1 dev wan.3  proto static  src 10.0.3.106 
10.0.3.0/24 dev wan.3  proto kernel  scope link  src 10.0.3.106 
10.0.3.1 dev wan.3  proto static  scope link  src 10.0.3.106  metric 10 
192.0.2.0/24 dev br-setup  proto kernel  scope link  src 192.0.2.1 
192.168.1.0/24 dev br-lan  proto kernel  scope link  src 192.168.1.1 
239.0.0.0/8 dev br-lan  scope link 
 
 
ip mroute: 
 
(10.0.3.17, 224.0.18.101)        Iif: wan.3      Oifs: br-lan 
(10.0.3.106, 224.0.18.101)       Iif: wan.3      Oifs: br-lan 
 
 
brctl show: 
 
bridge name     bridge id               STP enabled     interfaces
br-lan          7fff.3c90666afe41       no              lan1
                                                        lan2
                                                        lan3
                                                        lan4
                                                        wifi2g
                                                        wifi5g
br-setup                7fff.3c90666afe42       no
 
 
bridge mdb: 
 
dev br-lan port lan2 grp 224.0.18.101 temp
 
cat /proc/mcast_helper: 
 
GIdx    RxIntrf         SA         GA  proto  sPort  dPort   sMac memIntrf(MacAddr)
  1      wan.3    a000311   e0001265      0      0      0  (00:00:00:00:00:00)    lan2(c4:2c:03:37:dd:1e)
 
ppacmd getmcgroups: 
 
[000] MC GROUP:224.  0. 18.101 Src IP: 10.0.3.17 
         (route ) qid( 0) dscp( 0) vlan (0000/ffffffff) mib (0:11171148(cpu:hw mib in byte)) From  wan.3 to  lan2
         ADDED_IN_HW|VALID_VLAN_RM|SESSION_VALID_OUT_VLAN_RM|VALID_NEW_SRC_MAC
 
dmesg | grep mcast: 
 
 
ps lax | grep mcast-pa
 
0     0  2277  2241  20   0   2448   400 pipe_w S+   ttyLTQ0    0:00 grep mcast-pa
5     0  2799     1  20   0   2888   644 skb_re Ss   ?          0:00 mcast-pa --wan wan.3
 
 
logread | grep mcast | tail -n 20
 
Wed Aug  1 02:24:21 2018 local1.notice mcast-pa[2799]: RTM_NEWMDB dev br-lan port lan2 grp 224.0.18.115 srcmac C4:2C:03:37:DD:1E
Wed Aug  1 02:24:21 2018 local1.notice mcast-pa[2799]: pa_join:363 join new group 224.0.18.115 wan wan.3 lan lan2 src 10.0.3.17 res 0
Wed Aug  1 02:24:44 2018 local1.notice mcast-pa[2799]: RTM_DELMDB dev br-lan port lan2 grp 224.0.18.115 srcmac C4:2C:03:37:DD:1E
Wed Aug  1 02:24:44 2018 local1.notice mcast-pa[2799]: pa_leave:401 leave group 224.0.18.115 wan wan.3 lan lan2 src 10.0.3.17 res 0
Wed Aug  1 02:24:49 2018 local1.notice mcast-pa[2799]: RTM_NEWMDB dev br-lan port lan2 grp 224.0.18.101 srcmac C4:2C:03:37:DD:1E
Wed Aug  1 02:24:49 2018 local1.notice mcast-pa[2799]: pa_join:363 join new group 224.0.18.101 wan wan.3 lan lan2 src 10.0.3.17 res 0
 
==== head list ====

wandev: wan.3 brdev: br-lan first port: lan2 grp: 224.0.18.101 video src: 10.0.3.17
==== entry list ====

brdev br-lan port lan2 grp 224.0.18.101 
~~~~
