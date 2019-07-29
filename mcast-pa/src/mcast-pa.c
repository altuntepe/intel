/*****************************************************************************/
/*               _____                      _  ______ _____                  */
/*              /  ___|                    | | | ___ \  __ \                 */
/*              \ `--. _ __ ___   __ _ _ __| |_| |_/ / |  \/                 */
/*               `--. \ '_ ` _ \ / _` | '__| __|    /| | __                  */
/*              /\__/ / | | | | | (_| | |  | |_| |\ \| |_\ \                 */
/*              \____/|_| |_| |_|\__,_|_|   \__\_| \_|\____/ Inc.            */
/*                                                                           */
/*****************************************************************************/
/*                                                                           */
/*                      copyright 2018 by SmartRG, Inc.                      */
/*                             Santa Barbara, CA                             */
/*                                                                           */
/*****************************************************************************/
/*                                                                           */
/* Author: tim.hayes@smartrg.com                                             */
/*                                                                           */
/* Purpose: Multicast packet accelerator manager                             */
/*                                                                           */
/*                                                                           */
/*****************************************************************************/

/**

  @file mcast-pa.c
  @author tim.hayes@smartrg.com
  @date Summer 2017
  @brief Multicast Packet Accelerator 
  @details Adds and deletes multicast groups to PA (Intel PPA)

  @mainpage Multicast Packet Accelerator 

  @section	Overview Overview

  The basic OWRT multicast model consisting of the multicast aware Linux bridge and MCPROXY
  works on platforms where the CPU has the horsepower to meet the multicast delivery requirements
  and perform general CPE management functions in parallel.

  On platforms where a proprietary acceleration module is required the MCPROXY/bridge model must
  be augmented with an agent to support insertion and deletion of multicast entries into the acceleration
  module. This document describes the MCAST-PA agent that augments the MCPROXY/bridge model.

  MCAST-PA manages the insertion and deletion of multicast groups into a proprietary 
  multicast accelerator module. Fundamentally MCAST-PA consists of two parts - a generic
  Linux component with RTNETLINK callbacks to listen for multicast callbacks and a proprietary
  compile time driver to interface with a proprietary accelerator.

  The RTNETLINK callbacks consist of two components - bridge MDB callbacks and router ROUTE callbacks.
  The bridge MDB callbacks consist of NEWMDB and DELMDB messages that result in join and leave 
  operations respectively.   The ROUTE callbacks consist of NEWROUTE and DELROUTE messages of type
  RTN_MULTICAST. 

  The following diagram illustrates the basic operation of the model.

  @image html mcast-pa-ov.png
  @image latex mcast-pa-ov.png "" height=4cm

  Internally the logic of MCAST-PA is similar to the multicast component of the Linux bridge.
  Essentially MCAST-PA is a list manager, maintaining a list of multicast groups.  For each
  multicast group there is a list of group members.  When a NEWMDB message is received for a 
  new group, a group head and group member are created.  When a multicast route is received 
  for that group, the group member(s) are pushed to the accelerator via pa_join(). When a NEWMDB
  message is received for an existing route the pa_join() is executed immediately.

  The following diagram illustrates the list management component.

  @image html mcast-pa-list.png
  @image latex mcast-pa-list.png "" height=4cm

  It should be noted that under this model the Linux bridge will software bridge a few packets
  until the entry is pushed to the accelerator.  This has a beneficial affect of minimizing the
  first packet delay to the STB.

  Since the Linux bridge supports multicast to unicast conversion, the bridge also tracks
  source MAC addresses of the STBs.  To support source MAC requirements of the Intel PA, MCAST-PA
  also needs to maintain source MAC addresses within its internal MDB Entry structure (from if_bridge.h).

  To support this a patch was added to the Linux bridge to pass source MAC address in the NEWMDB and 
  DELMDB messages.  There is also a requirement for Network Operators to know what devices are watching
  various channels.  Both requirements can be addressed via MDB Entry and bridge patches/enhancements.
  There is also a patch that forces the bridge to track source MAC addresses even when multicast to 
  unicast conversion is not enabled.

  @subsection	Invocation Invocation

  Three types of video delivery are supported: routed from a single wan interface(proxy), routed from
  a dedicated video interface(proxy) and pure bridge with a dedicated video interface attached to a
  dedicated video bridge(snoop).

  For the single wan interface case, MCAST-PA just needs to know the wan interface:
   
  @verbatim
  mcast-pa --wan <wan interface name>
  @endverbatim

  For the dedicate video wan interface case, MCAST-PA needs to know the wan interface, the bridge name
  and the "video2lan" mode.  Note that video clients are still attached to br-lan but the IP
  address is held by the video bridge with the video wan interface a member of the bridge.
  
  @verbatim
  mcast-pa --wan <wan interface name> --video2lan <video bridge device name>
  @endverbatim

  For the pure bridge case, MCAST-PA needs to know the wan interface and the bridge name:
  		
  @verbatim
  mcast-pa --wan <wan interface name> --bridge <video bridge device name>
  @endverbatim

  @subsection	Logging Logging


  By default syslog LOG_NOTICE is turned on so channel changes can be monitored:

  @verbatim
  Tue Jul 17 07:40:30 2018 local1.notice mcast-pa[13135]: pa_leave:401 leave group 224.0.18.113 wan wan lan wifi5g src 10.0.3.17 res 0
  Tue Jul 17 07:40:37 2018 local1.notice mcast-pa[13135]: RTM_NEWMDB dev br-lan port wifi5g grp 224.0.18.115 srcmac 48:51:B7:77:7D:79
  Tue Jul 17 07:40:37 2018 local1.notice mcast-pa[13135]: pa_join:363 join new group 224.0.18.115 wan wan lan wifi5g src 10.0.3.17 res 0
  Tue Jul 17 07:40:40 2018 local1.notice mcast-pa[13135]: RTM_DELMDB dev br-lan port wifi5g grp 224.0.18.114 srcmac 48:51:B7:77:7D:79
  Tue Jul 17 07:40:40 2018 local1.notice mcast-pa[13135]: pa_leave:401 leave group 224.0.18.114 wan wan lan wifi5g src 10.0.3.17 res 0
  Tue Jul 17 07:40:47 2018 local1.notice mcast-pa[13135]: RTM_NEWMDB dev br-lan port wifi5g grp 224.0.18.116 srcmac 48:51:B7:77:7D:79
  Tue Jul 17 07:40:47 2018 local1.notice mcast-pa[13135]: pa_join:363 join new group 224.0.18.116 wan wan lan wifi5g src 10.0.3.17 res 0
  @endverbatim

  With the optional command line arguement --verbose, all netlink messages are also logged with a LOG_INFO.

  @subsection	MCPROXY MCPROXY
  
  As mentioned above the basic model independent of Packet Acceleration is MCPROXY with a Linux bridge.  The MCPROXY package can be found here:   

  @verbatim
  https://github.com/openwrt-routing/packages/tree/master/mcproxy
  @endverbatim

  A sample MCPROXY configuration for the simple single wan case:

  @verbatim
  
  /etc/config/mcproxy:

  config mcproxy 'mcproxy'
        option disabled '0'
        option respawn '1'
        option protocol 'IGMPv2'

  config instance
        option name 'wan2lan'
        option upstream 'wan'
        option downstream 'br-lan'
        option disabled '0'


  @endverbatim

  @verbatim

  /var/etc/mcproxy_mcproxy.conf:

  protocol IGMPv2;

  pinstance wan2lan: "wan" ==> "br-lan";

  @endverbatim

  Adding a source address structure to the above would meet both requirements as follows:

  @verbatim
  struct br_mdb_entry {
  	__u32 ifindex;
  #define MDB_TEMPORARY 0
  #define MDB_PERMANENT 1
  	__u8 state;
  	struct {
  		union {
  			__be32	ip4;
  			struct in6_addr ip6;
  		} u;
  		__be16		proto;
  	} addr;
  	struct {
  		union {
  			__be32	ip4;
  			struct in6_addr ip6;
  		} u;
  		__be16		proto;
		unsigned char eth_addr[ETH_ALEN];
  	} src_addr;
  };
  @endverbatim

 */

#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <syslog.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <linux/if.h>
#include <netinet/ip_icmp.h>
#include <netinet/udp.h>
#include <netinet/tcp.h>
#include <netinet/ip.h>
#include <pcap.h>
#include <getopt.h>
#include <errno.h>
#include <sys/time.h>
#include <time.h>
#include <signal.h>
#include <asm/types.h>
// we must local src this because it is patched (struct mdb_entry) and STAGING_DIR does not have the patch result
#include "if_bridge.h"
//#include <linux/if_bridge.h>
#include <libnetlink.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/in_route.h>
#include <linux/mroute.h>
#include "list.h"
#include <mcast-pa.h>

char *_SL_ = "\n";

#define INET_ADDR_SIZE 128
#define CMD_BUF_SIZE 256

extern const char *ll_index_to_name(unsigned idx);
extern unsigned ll_name_to_index(const char *name);
extern void ll_init_map(struct rtnl_handle *rth);

static const char *mx_names[RTAX_MAX + 1] = {
	[RTAX_MTU] = "mtu",
	[RTAX_WINDOW] = "window",
	[RTAX_RTT] = "rtt",
	[RTAX_RTTVAR] = "rttvar",
	[RTAX_SSTHRESH] = "ssthresh",
	[RTAX_CWND] = "cwnd",
	[RTAX_ADVMSS] = "advmss",
	[RTAX_REORDERING] = "reordering",
	[RTAX_HOPLIMIT] = "hoplimit",
	[RTAX_INITCWND] = "initcwnd",
	[RTAX_FEATURES] = "features",
	[RTAX_RTO_MIN] = "rto_min",
	[RTAX_INITRWND] = "initrwnd",
};

#define SPRINT_BSIZE 64
#define SPRINT_BUF(x)   static char x[SPRINT_BSIZE]

#ifndef MDBA_RTA
#define MDBA_RTA(r) \
	((struct rtattr*)(((char*)(r)) + NLMSG_ALIGN(sizeof(struct br_port_msg))))
#endif

static struct mcastpa_t mcastpa;

struct rtnl_handle rth = {.fd = -1 };

struct mcast_ip_entry_t {
	struct list_head head;		/**< prev next pointers for ip address list */
	int ifindex;				/**< ifindex of device which has address */
	char address[INET_ADDR_SIZE];	/**< ip address of device */
	char name[IFNAMSIZ];			/**< name of device */
};

struct mcast_wan_entry_t {
	struct list_head head;		/**< prev next pointers for ip address list */
	int ifindex;				/**< ifindex of device which has address */
	char address[INET_ADDR_SIZE];	/**< ip address of device */
	char name[IFNAMSIZ];			/**< name of device */
};

struct mcg_br_mdb_entry_t {
	struct list_head mcg_head;		/**< prev next pointers for mc group header list mgmt (list of groups) */
	struct list_head mcg_entry;		/**< prev next pointers for mc group interface members (list of ifindexes via br_mdb_entry struct - head use only */
	struct br_mdb_entry e;		/**< copy of mdb entry from bridge table with mc group and ifindex of joined interfaces */
	int joined;				/**< set to 1 if pa_join() called */
	int wan_ifindex;			/**< ifindex of wan interface - head use only */
	int br_ifindex;			/**< ifindex of bridge interface - head use only */
	char src[INET_ADDR_SIZE];		/**< ip address of video source - head use only */
};

struct vsa_t {
	char op[128];				/**< vsa join or leave */
	char group[128];			/**< vsa mc group */
	char device[128];			/**< vsa device - like a lan bridge port */
	int valid;				/**< valid data in this struct */
};

struct params_t {
	int dbg;				/**< set if debug output is desired */
	int foreground;			/**< set if we are to run in foreground - background daemon is default */
	int verbose;				/**< set to generate verbose output */
	int monitor;				/**< set to monitor NEWMDB and DELMDB */
	int wan;				/**< set if wan input provided */
	int wan_ifindex;			/**< set if wan exists on boot */
	int bridged;				/**< set if in bridge mode */
	char bridge_name[IFNAMSIZ];		/**< name of video bridge e.g. br-lan or br-video */
	int video2lan;			/**< set if in video2lan is like bridge mode but don't care which bridge */
	char video2lan_name[IFNAMSIZ];	/**< name of video ip interface */
	int use_src;				/**< use ip address of video source from command line */
	int nowifi;				/**< don't push wifi ifaces to packet accelerator */
	char src[INET_ADDR_SIZE];		/**< ip address of video source from command line */
	int exp;				/**< experimental code segment testing */
	struct vsa_t vsa;			/**< for vsa join and leave operations */
};

struct mcastpa_t {
	struct params_t params;		/**< command line args on invocation */
	uint64_t timer_tick;			/**< increment each 1 second timer tick in timer handler */
	struct ip_mreq group;		/**< group struct used for joins */
	int sock;				/**< socket used for joins */
	char dev_name[IFNAMSIZ];		/**< video ingress device name */
	struct timespec current_time;	/**< current time from timer handler */
	struct timespec last_time;		/**< last time in timer handler - used to get actual interval - about 1 second plus or minus */
	struct timespec start_time;		/**< time that we started */
	time_t start_ctime;			/**< start time in local time format when we started */
	time_t error_ctime;			/**< error detected time in local time format when we started */
	struct list_head mcg_head;		/**< global list header for mc groups */
	struct list_head ip_head;		/**< global list header for our host ip addresses */
	struct list_head wan_head;		/**< global list header for our host interfaces */
};

int mcg_br_entry_leave(struct mcg_br_mdb_entry_t *head, struct br_mdb_entry *e);

static inline __u32
nl_mgrp(__u32 group)
{
	if (group > 31) {
		syslog(LOG_INFO, "Use setsockopt for this group %d\n", group);
		exit(-1);
	}
	return group ? (1 << (group - 1)) : 0;
}

/**
 * @brief read a file and look for a vsa operation
 * @details join or leave channel device
 * @returns 0 if OK
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcast_vsa_get(void)
{
	FILE *fp;
	if ((fp = fopen("/tmp/vsapa.cfg", "r")) == NULL) {
		mcastpa.params.vsa.valid = 0;
		return (0);
	}
	fscanf(fp, "%s %s %s", mcastpa.params.vsa.op, mcastpa.params.vsa.group, mcastpa.params.vsa.device);
	fclose(fp);
	syslog(LOG_INFO, "%s:%d op: %s group: %s device: %s\n", __FUNCTION__, __LINE__,
	       mcastpa.params.vsa.op, mcastpa.params.vsa.group, mcastpa.params.vsa.device);
	mcastpa.params.vsa.valid = 1;
	return (0);
}

/**
 * @brief add a wan iface to our host list
 * @details 
 * @returns pointer to entry or null
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcast_wan_entry_t *
mcast_wan_entry_add(char *name)
{
	struct mcast_wan_entry_t *p_mcast_wan_entry;
	p_mcast_wan_entry = (struct mcast_wan_entry_t *) malloc(sizeof (struct mcast_wan_entry_t));
	if (p_mcast_wan_entry == NULL) {
		return (NULL);
	}
	memset(p_mcast_wan_entry, 0, sizeof (struct mcast_wan_entry_t));
	INIT_LIST_HEAD(&p_mcast_wan_entry->head);
	list_add(&p_mcast_wan_entry->head, &mcastpa.wan_head);
	sprintf(p_mcast_wan_entry->name, "%s", name);
	return (p_mcast_wan_entry);
}

/**
 * @brief delete a wan iface if found on list
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcast_wan_entry_del(char *name)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcast_wan_entry_t *p_mcast_wan_entry;

	list_for_each_safe(pos, q, &mcastpa.wan_head) {
		p_mcast_wan_entry = (struct mcast_wan_entry_t *) list_entry(pos, struct mcast_wan_entry_t, head);
		if (strcmp(p_mcast_wan_entry->name, name) == 0) {
			list_del(pos);
			free(p_mcast_wan_entry);
			return (0);
		}
	}
	return (-ENOENT);
}

/**
 * @brief returns a list entry of the wan iface
 * @details removes instance of a wan iface
 * @note
 * @returns entry if name found null otherwise
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcast_wan_entry_t *
mcast_wan_entry_get(char *name)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcast_wan_entry_t *p_mcast_wan_entry;

	list_for_each_safe(pos, q, &mcastpa.wan_head) {
		p_mcast_wan_entry = (struct mcast_wan_entry_t *) list_entry(pos, struct mcast_wan_entry_t, head);
		if (strcmp(p_mcast_wan_entry->name, name) == 0) {
			return (p_mcast_wan_entry);
		}
	}
	return (NULL);
}

/**
 * @brief returns a first entry of the wan iface
 * @details 
 * @note
 * @returns first if name found null otherwise
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
char *
mcast_wan_entry_default(void)
{
	struct list_head *pos;
	static char name[IFNAMSIZ];
	struct mcast_wan_entry_t *p_mcast_wan_entry;

	list_for_each(pos, &mcastpa.wan_head) {
		p_mcast_wan_entry = (struct mcast_wan_entry_t *) list_entry(pos, struct mcast_wan_entry_t, head);
		sprintf(name, "%s", p_mcast_wan_entry->name);
		return (name);
	}
	return ("wan");
}

/**
 * @brief list all host wan ifaces
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcast_wan_entry_list(void)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcast_wan_entry_t *p_mcast_wan_entry;

	list_for_each_safe(pos, q, &mcastpa.wan_head) {
		p_mcast_wan_entry = (struct mcast_wan_entry_t *) list_entry(pos, struct mcast_wan_entry_t, head);
		syslog(LOG_NOTICE, "wan iface %s\n", p_mcast_wan_entry->name);
	}
	return (-ENOENT);
}

/**
 * @brief determines if a interface is a wan interface
 * @details 
 * @returns 1 if wan 0 otherwise
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
iswan(char *name)
{
	struct mcast_wan_entry_t *p_mcast_wan_entry;

	if (mcastpa.params.video2lan) {
		if (strcmp(mcastpa.params.video2lan_name, name) == 0) {
			return (1);
		}
	}

	p_mcast_wan_entry = mcast_wan_entry_get(name);
	if (p_mcast_wan_entry != NULL)
		return (1);
	return (0);
}

/**
 * @brief determines if a interface is a wifi interface
 * @details 
 * @returns 1 if wifi 0 otherwise
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
iswifi(char *name)
{
	if (strncmp(name, "wifi", strlen("wifi")) == 0)
		return (1);
	return (0);
}

/**
 * @brief add a ip address to our host list
 * @details 
 * @returns pointer to entry or null
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcast_ip_entry_t *
mcast_ip_entry_add(char *address)
{
	struct mcast_ip_entry_t *p_mcast_ip_entry;
	p_mcast_ip_entry = (struct mcast_ip_entry_t *) malloc(sizeof (struct mcast_ip_entry_t));
	if (p_mcast_ip_entry == NULL) {
		return (NULL);
	}
	memset(p_mcast_ip_entry, 0, sizeof (struct mcast_ip_entry_t));
	INIT_LIST_HEAD(&p_mcast_ip_entry->head);
	list_add(&p_mcast_ip_entry->head, &mcastpa.ip_head);
	sprintf(p_mcast_ip_entry->address, "%s", address);
	return (p_mcast_ip_entry);
}

/**
 * @brief delete a ip address if found on list
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcast_ip_entry_del(char *address)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcast_ip_entry_t *p_mcast_ip_entry;

	list_for_each_safe(pos, q, &mcastpa.ip_head) {
		p_mcast_ip_entry = (struct mcast_ip_entry_t *) list_entry(pos, struct mcast_ip_entry_t, head);
		if (strcmp(p_mcast_ip_entry->address, address) == 0) {
			list_del(pos);
			free(p_mcast_ip_entry);
			return (0);
		}
	}
	return (-ENOENT);
}

/**
 * @brief returns a list entry of the ip address
 * @details removes instance of a group as a sub of the group head
 * @note
 * @returns entry if address found null otherwise
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcast_ip_entry_t *
mcast_ip_entry_get(char *address)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcast_ip_entry_t *p_mcast_ip_entry;

	list_for_each_safe(pos, q, &mcastpa.ip_head) {
		p_mcast_ip_entry = (struct mcast_ip_entry_t *) list_entry(pos, struct mcast_ip_entry_t, head);
		if (strcmp(p_mcast_ip_entry->address, address) == 0) {
			return (p_mcast_ip_entry);
		}
	}
	return (NULL);
}

/**
 * @brief determines if an address is one of our own local
 * @details this is a temp hack need a list of adresses
 * @returns 1 if ours 0 otherwise
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
islocaladdr(char *address)
{
	struct mcast_ip_entry_t *p_mcast_ip_entry = mcast_ip_entry_get(address);
	if (p_mcast_ip_entry != NULL)
		return (1);
	return (0);
}

/**
 * @brief list all host ip addresses
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcast_ip_entry_list(void)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcast_ip_entry_t *p_mcast_ip_entry;

	list_for_each_safe(pos, q, &mcastpa.ip_head) {
		p_mcast_ip_entry = (struct mcast_ip_entry_t *) list_entry(pos, struct mcast_ip_entry_t, head);
		syslog(LOG_NOTICE, "ip address %s\n", p_mcast_ip_entry->address);
	}
	return (-ENOENT);
}

/**
 * @brief show an instance of a mc group entry head
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
mcg_br_entry_head_show(FILE * f, struct mcg_br_mdb_entry_t *head)
{
	SPRINT_BUF(abuf);
	if (f == NULL)
		return;
	if (inet_ntop(AF_INET, &head->e.addr.u.ip4, abuf, sizeof (abuf))) {
		fprintf(f, "wandev: %s brdev: %s first port: %s grp: %s ",
			(char *) ll_index_to_name(head->wan_ifindex),
			(char *) ll_index_to_name(head->br_ifindex), (char *) ll_index_to_name(head->e.ifindex), abuf);
		fprintf(f, "video src: %s\n", head->src);
	}
	return;
}

/**
 * @brief show an instance of a mc group entry
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
mcg_br_entry_show(FILE * f, struct mcg_br_mdb_entry_t *mcge)
{
	SPRINT_BUF(abuf);
	if (f == NULL)
		return;
	if (inet_ntop(AF_INET, &mcge->e.addr.u.ip4, abuf, sizeof (abuf))) {
		fprintf(f, "brdev %s port %s grp %s \n", (char *) ll_index_to_name(mcge->br_ifindex),
			(char *) ll_index_to_name(mcge->e.ifindex), abuf);
	}
	return;
}

/**
 * @brief compare bridge entries
 * @details return 1 if equal 0 otherwise
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcg_br_entry_equal(struct br_mdb_entry *ex, struct br_mdb_entry *ey)
{
	if (ex->ifindex == ey->ifindex) {
		if (ex->addr.u.ip4 == ey->addr.u.ip4) {
			if (memcmp(&ex->src_addr.eth_addr, &ey->src_addr.eth_addr, ETH_ALEN) == 0) {
				return (1);
			}
		}
	}
	return (0);
}

/**
 * @brief gets a head instance of mc group
 * @details just compares mcgroup
 * @returns pointer to entry or null
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcg_br_mdb_entry_t *
mcg_br_entry_head_get(struct br_mdb_entry *e)
{
	struct list_head *pos;
	struct mcg_br_mdb_entry_t *mcge;

	list_for_each(pos, &mcastpa.mcg_head) {
		mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_head);
		if (e->addr.proto == htons(ETH_P_IP)) {
			if (memcmp(&e->addr.u.ip4, &mcge->e.addr.u.ip4, sizeof (__be32)) == 0) {
				return (mcge);
			}
		} else {
			if (memcmp(&e->addr.u.ip6, &mcge->e.addr.u.ip6, sizeof (struct in6_addr)) == 0) {
				return (mcge);
			}
		}
	}
	return (NULL);
}

/**
 * @brief get a mdb entry from the mc group list head list of attached group entries
 * @details compares br_mdb_entries 
 * @returns pointer to entry or null
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcg_br_mdb_entry_t *
mcg_br_entry_get(struct mcg_br_mdb_entry_t *head, struct br_mdb_entry *e)
{
	struct list_head *pos;
	struct mcg_br_mdb_entry_t *mcge;

	list_for_each(pos, &head->mcg_entry) {
		mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_entry);
		if (mcg_br_entry_equal(e, &mcge->e)) {
			return (mcge);
		}
	}
	return (NULL);
}

/**
 * @brief add a bridge mdb entry to the mc group list head list
 * @details subordinate members of group
 * @returns pointer to entry or null
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcg_br_mdb_entry_t *
mcg_br_entry_add(struct mcg_br_mdb_entry_t *head, struct br_mdb_entry *e)
{
	struct mcg_br_mdb_entry_t *p_mcg_br_mdb_entry;
	p_mcg_br_mdb_entry = (struct mcg_br_mdb_entry_t *) malloc(sizeof (struct mcg_br_mdb_entry_t));
	if (p_mcg_br_mdb_entry == NULL) {
		return (NULL);
	}
	memset(p_mcg_br_mdb_entry, 0, sizeof (struct mcg_br_mdb_entry_t));
	INIT_LIST_HEAD(&p_mcg_br_mdb_entry->mcg_entry);
	memcpy(&p_mcg_br_mdb_entry->e, e, sizeof (struct br_mdb_entry));
	list_add(&p_mcg_br_mdb_entry->mcg_entry, &head->mcg_entry);
	return (p_mcg_br_mdb_entry);
}

/**
 * @brief add a bridge mdb entry to the mc group list head
 * @details initial instance of a group
 * @returns pointer to entry or null
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcg_br_mdb_entry_t *
mcg_br_entry_head_add(struct br_mdb_entry *e)
{
	struct mcg_br_mdb_entry_t *p_mcg_br_mdb_entry;
	p_mcg_br_mdb_entry = (struct mcg_br_mdb_entry_t *) malloc(sizeof (struct mcg_br_mdb_entry_t));
	if (p_mcg_br_mdb_entry == NULL) {
		return (NULL);
	}

	memset(p_mcg_br_mdb_entry, 0, sizeof (struct mcg_br_mdb_entry_t));
	INIT_LIST_HEAD(&p_mcg_br_mdb_entry->mcg_head);
	INIT_LIST_HEAD(&p_mcg_br_mdb_entry->mcg_entry);
	memcpy(&p_mcg_br_mdb_entry->e, e, sizeof (struct br_mdb_entry));
	list_add(&p_mcg_br_mdb_entry->mcg_head, &mcastpa.mcg_head);
	return (p_mcg_br_mdb_entry);
}

/**
 * @brief delete a bridge mdb entry from the mc group list head
 * @details removes instance of a group
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcg_br_entry_head_del(struct mcg_br_mdb_entry_t *head)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcg_br_mdb_entry_t *mcge;

	list_for_each_safe(pos, q, &mcastpa.mcg_head) {
		mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_head);
		if (mcge->e.addr.u.ip4 == head->e.addr.u.ip4) {
			list_del(pos);
			free(mcge);
			return (0);
		}
	}
	return (-ENOENT);
}

/**
 * @brief delete a bridge mdb entry from the mc group list head list
 * @details removes instance of a group as a sub of the group head
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcg_br_entry_del(struct mcg_br_mdb_entry_t *head, struct br_mdb_entry *e)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcg_br_mdb_entry_t *mcge;

	list_for_each_safe(pos, q, &head->mcg_entry) {
		mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_entry);
		if (mcg_br_entry_equal(e, &mcge->e)) {
			list_del(pos);
			free(mcge);
			return (0);
		}
	}
	return (-ENOENT);
}

/**
 * @brief delete a bridge mdb entry from the mc group list head
 * @details removes instance of a group
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
mcg_br_entry_head_del_all(struct mcg_br_mdb_entry_t *head)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcg_br_mdb_entry_t *mcge;

	list_for_each_safe(pos, q, &mcastpa.mcg_head) {
		mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_head);
		mcg_br_entry_del(head, &mcge->e);
	}
}

/**
 * @brief traverses all head groups, removes all sub entries issues leave and deletes head
 * @details calls leave for head group
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcg_br_entry_head_list_del_all(void)
{
	struct list_head *pos;
	struct list_head *q;
	struct mcg_br_mdb_entry_t *head;
	list_for_each_safe(pos, q, &mcastpa.mcg_head) {
		head = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_head);
		mcg_br_entry_leave(head, NULL);
		mcg_br_entry_head_del(head);
	}
	return (0);
}

/**
 * @brief lists instances of a mc group entires tied to a mc group head entry
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
mcg_br_entry_list_show(FILE * f, struct mcg_br_mdb_entry_t *head)
{
	struct list_head *pos;
	struct mcg_br_mdb_entry_t *mcge;
	if (f == NULL)
		return;
	list_for_each(pos, &head->mcg_entry) {
		mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_entry);
		mcg_br_entry_show(f, mcge);
	}
	return;
}

/**
 * @brief sets src mac in mjl struct
 * @details uses part of ipv6 union - this is supported by a bridge patch
 * @todo someday get a really clean way of doing this
 * @note done to support Intel wifi mc which requires source of video subscriber
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
mcg_br_entry_srcmac_set(struct mcg_br_mdb_entry_t *mcge, struct mcastpa_join_leave_t *mjl)
{
	memcpy(mjl->srcmac, &mcge->e.src_addr.eth_addr, ETH_ALEN);
}

/**
 * @brief joins a new group
 * @details calls hw specific pa_join()
 * @todo IPV6
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcg_br_entry_join(struct mcg_br_mdb_entry_t *head)
{
	SPRINT_BUF(group);
	struct list_head *pos;
	struct mcg_br_mdb_entry_t *mcge;
	int len = 0;
	char src[INET_ADDR_SIZE] = { 0 };
					/**< ip address of video source - head use only */
	struct mcastpa_join_leave_t mjl;
	int res = 0;

	if (inet_ntop(AF_INET, &head->e.addr.u.ip4, group, sizeof (group))) {
		syslog(LOG_INFO, "%s:%d join request group %s\n", __FUNCTION__, __LINE__, group);
	} else {
		syslog(LOG_NOTICE, "%s:%d BUG join request no IPV4 Group\n", __FUNCTION__, __LINE__);
		return (-ENOENT);	/* not ready to join - no video src */
	}

	if (!mcastpa.params.bridged) {
		if (mcastpa.params.use_src == 0) {
			if (head->src[0] == 0) {
				return (-ENOENT);	/* not ready to join - no video src */
			}
			strcpy(src, head->src);
		} else {
			strcpy(src, mcastpa.params.src);
		}
	}

	memset(&mjl, 0, sizeof (struct mcastpa_join_leave_t));
	if (inet_ntop(AF_INET, &head->e.addr.u.ip4, group, sizeof (group))) {
		if (mcastpa.params.bridged) {
			mjl.flags |= MJL_FLAG_BRIDGE;
		}
		sprintf((char *) &mjl.group, "%s", group);
		mjl.flags |= MJL_FLAG_SRCIP;
		sprintf((char *) &mjl.srcip, "%s", src);
		sprintf((char *) &mjl.wan, "%s", mcast_wan_entry_default());
		list_for_each(pos, &head->mcg_entry) {
			mjl.flags |= MJL_FLAG_LAN;
			mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_entry);
			len += sprintf((char *) (mjl.lan + len), " %s ", (char *) ll_index_to_name(mcge->e.ifindex));
			if (mcge->joined == 1) {
				/* at least one group has been joined already */
				mjl.flags |= MJL_FLAG_UPDATE;
			}
		}
		list_for_each(pos, &head->mcg_entry) {
			mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_entry);
			mcg_br_entry_srcmac_set(mcge, &mjl);
			if (mcge->joined == 0) {
				sprintf((char *) (&mjl.lan_dev), "%s", (char *) ll_index_to_name(mcge->e.ifindex));
				res = pa_join(&mjl);
				if (res == 0)
					mcge->joined = 1;
				syslog(LOG_INFO, "%s:%d join request sent group %s res: %d\n", __FUNCTION__, __LINE__,
				       group, res);
			}
		}
	}

	return (0);
}

/**
 * @brief leaves with no groups or joins with smaller group list
 * @details calls hw specific pa_leave()
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
mcg_br_entry_leave(struct mcg_br_mdb_entry_t *head, struct br_mdb_entry *e)
{
	SPRINT_BUF(group);
	struct list_head *pos;
	struct mcg_br_mdb_entry_t *mcge;
	int len = 0;
	char src[INET_ADDR_SIZE];		/**< ip address of video source - head use only */
	struct mcastpa_join_leave_t mjl;

	syslog(LOG_INFO, "%s:%d leave request \n", __FUNCTION__, __LINE__);
	if (!mcastpa.params.bridged) {
		if (mcastpa.params.use_src == 0) {
			if (head->src[0] == 0) {
				return (-ENOENT);	/* not ready to join - no video src */
			}
			strcpy(src, head->src);
		} else {
			strcpy(src, mcastpa.params.src);
		}
	}

	memset(&mjl, 0, sizeof (struct mcastpa_join_leave_t));
	if (inet_ntop(AF_INET, &head->e.addr.u.ip4, group, sizeof (group))) {
		if (mcastpa.params.bridged) {
			mjl.flags |= MJL_FLAG_BRIDGE;
		}
		sprintf((char *) &mjl.group, "%s", group);
		mjl.flags |= MJL_FLAG_SRCIP;
		sprintf((char *) &mjl.srcip, "%s", src);
		sprintf((char *) &mjl.wan, "%s", mcast_wan_entry_default());
		list_for_each(pos, &head->mcg_entry) {
			mjl.flags |= MJL_FLAG_LAN;
			mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_entry);
			len += sprintf((char *) (mjl.lan + len), " %s ", (char *) ll_index_to_name(mcge->e.ifindex));
		}
		list_for_each(pos, &head->mcg_entry) {
			mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_entry);
			mcg_br_entry_srcmac_set(mcge, &mjl);
			if (e != NULL) {
				if (mcg_br_entry_equal(e, &mcge->e)) {
					if (mcge->joined == 1) {
						sprintf((char *) (&mjl.lan_dev), "%s",
							(char *) ll_index_to_name(mcge->e.ifindex));
						pa_leave(&mjl);
						mcge->joined = 0;
					}
				}
			} else {
				if (mcge->joined == 1) {
					sprintf((char *) (&mjl.lan_dev), "%s",
						(char *) ll_index_to_name(mcge->e.ifindex));
					pa_leave(&mjl);
					mcge->joined = 0;
					syslog(LOG_INFO, "%s:%d leave request sent group %s\n", __FUNCTION__,
					       __LINE__, group);
				}
			}
		}
	}

	if (e != NULL) {
		mcg_br_entry_del(head, e);
	} else {
		mcg_br_entry_head_del_all(head);
	}

	return (0);
}

/**
 * @brief lists instances of head a mc group entires 
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
mcg_br_entry_head_list_show(void)
{
	struct list_head *pos;
	struct mcg_br_mdb_entry_t *head;
	FILE *f = fopen("/tmp/mcastpa-dump", "w");
	if (f == NULL)
		return;
	list_for_each(pos, &mcastpa.mcg_head) {
		head = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_head);
		fprintf(f, "%s\n", "==== head list ====\n");
		mcg_br_entry_head_show(f, head);
		fprintf(f, "%s\n", "==== entry list ====\n");
		mcg_br_entry_list_show(f, head);
	}
	fclose(f);
	return;
}

/**
 * @brief joins a vsa requested group on a device
 * @details emulates a bridge device joining
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
vsa_entry_join(void)
{
	struct br_mdb_entry _e;
	struct br_mdb_entry *e;
	struct mcg_br_mdb_entry_t *head;
	struct mcg_br_mdb_entry_t *mcge;

	e = &_e;
	inet_pton(AF_INET, mcastpa.params.vsa.group, &(e->addr.u.ip4));
	e->ifindex = ll_name_to_index(mcastpa.params.vsa.device);
	e->addr.proto = ETH_P_IP;
	head = mcg_br_entry_head_get(e);
	if (head == NULL) {
		head = mcg_br_entry_head_add(e);
		if (head != NULL) {
			head->br_ifindex = 0;
		}
	}
	if (head != NULL) {
		mcge = mcg_br_entry_get(head, e);
		if (mcge == NULL) {
			mcge = mcg_br_entry_add(head, e);
		}
		mcg_br_entry_join(head);
	}
}

/**
 * @brief leave a vsa requested group on a device
 * @details emulates a bridge device joining
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
vsa_entry_leave(void)
{
	struct br_mdb_entry _e;
	struct br_mdb_entry *e;
	struct mcg_br_mdb_entry_t *head;
	struct mcg_br_mdb_entry_t *mcge;

	e = &_e;
	inet_pton(AF_INET, mcastpa.params.vsa.group, &(e->addr.u.ip4));
	e->ifindex = ll_name_to_index(mcastpa.params.vsa.device);
	e->addr.proto = ETH_P_IP;
	head = mcg_br_entry_head_get(e);
	if (head == NULL) {
		return;
	}

	mcge = mcg_br_entry_get(head, e);
	if (mcge == NULL) {
		syslog(LOG_INFO, "vsa mcge is NULL\n");
		return;
	}

	mcg_br_entry_leave(head, e);

	if (list_empty(&head->mcg_entry)) {
		mcg_br_entry_head_del(head);
	}

}

/**
 * @brief process a vsa request
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
vsa_entry_process(void)
{
	if (strcmp(mcastpa.params.vsa.op, "join") == 0) {
		vsa_entry_join();
	}
	if (strcmp(mcastpa.params.vsa.op, "leave") == 0) {
		vsa_entry_leave();
	}
}

/**
 * @brief finds a head entry from a specific mc group
 * @details 
 * @returns pointer if group found NULL otherwise 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
struct mcg_br_mdb_entry_t *
mcg_br_entry_head_get_from_group(char *group)
{
	SPRINT_BUF(headgroup);
	struct list_head *pos;
	struct mcg_br_mdb_entry_t *mcge;
	list_for_each(pos, &mcastpa.mcg_head) {
		mcge = (struct mcg_br_mdb_entry_t *) list_entry(pos, struct mcg_br_mdb_entry_t, mcg_head);
		if (inet_ntop(AF_INET, &mcge->e.addr.u.ip4, headgroup, sizeof (headgroup))) {
			if (strcmp(headgroup, group) == 0)
				return (mcge);
		}
	}
	return (NULL);
}

/**
 * @brief  exit handler
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
#define MDB_FORK_EXIT 69
static void
mdb_exit_handler()
{
	struct mcastpa_system_init_t msi;
	syslog(LOG_INFO, "%s:%d removing head lists\n", __FUNCTION__, __LINE__);
	mcg_br_entry_head_list_del_all();
	memset(&msi, 0, sizeof (struct mcastpa_system_init_t));
	pa_deinit(&msi);
	closelog();
}

/**
 * @brief  misc parse_route support function
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
const char *
rt_addr_n2a(int af, const void *addr, char *buf, int buflen)
{
	switch (af) {
	case AF_INET:
	case AF_INET6:
		return inet_ntop(af, addr, buf, buflen);
	default:
		return "???";
	}
}

/**
 * @brief  misc parse_route support function
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
char *
format_host(int af, int len, const void *addr, char *buf, int buflen)
{
	return (char *) rt_addr_n2a(af, addr, buf, buflen);
}

/**
 * @brief  misc parse_route support function
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
af_bit_len(int af)
{
	switch (af) {
	case AF_INET6:
		return 128;
	case AF_INET:
		return 32;
	case AF_DECnet:
		return 16;
	case AF_IPX:
		return 80;
	}

	return 0;
}

/**
 * @brief  misc parse_route support function
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
static inline int
rtm_get_table(struct rtmsg *r, struct rtattr **tb)
{
	__u32 table = r->rtm_table;
	if (tb[RTA_TABLE])
		table = rta_getattr_u32(tb[RTA_TABLE]);
	return table;
}

/**
 * @brief  misc parse_route support function
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
static void
print_rtax_features(FILE * fp, unsigned int features)
{
	unsigned int of = features;

	if (features & RTAX_FEATURE_ECN) {
		syslog(LOG_INFO, " ecn");
		features &= ~RTAX_FEATURE_ECN;
	}

	if (features)
		syslog(LOG_INFO, " 0x%x", of);
}

/**
 * @brief parses route update and gets our host ip address
 * @todo support for multihoming and review
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
parse_route(const struct sockaddr_nl *who, struct nlmsghdr *n, void *arg)
{
	struct rtmsg *r = NLMSG_DATA(n);
	int len = n->nlmsg_len;
	struct rtattr *tb[RTA_MAX + 1];
	char abuf[256];
	int host_len;
	static int hz;

	if (n->nlmsg_type != RTM_NEWROUTE && n->nlmsg_type != RTM_DELROUTE) {
		syslog(LOG_INFO, "Not a route: %08x %08x %08x\n", n->nlmsg_len, n->nlmsg_type, n->nlmsg_flags);
		return 0;
	}

	len -= NLMSG_LENGTH(sizeof (*r));
	if (len < 0) {
		syslog(LOG_INFO, "BUG: wrong nlmsg len %d\n", len);
		return -1;
	}

	host_len = af_bit_len(r->rtm_family);

	parse_rtattr(tb, RTA_MAX, RTM_RTA(r), len);

	if (tb[RTA_OIF]) {
		if (iswan((char *)ll_index_to_name(*(int *) RTA_DATA(tb[RTA_OIF])))) {
		} else {
			return 0;
		}
	}

	if (tb[RTA_DST]) {
		if (r->rtm_dst_len != host_len) {
			syslog(LOG_INFO, "%s/%u ", rt_addr_n2a(r->rtm_family,
							       RTA_DATA(tb[RTA_DST]), abuf, sizeof (abuf)),
			       r->rtm_dst_len);
		} else {
			syslog(LOG_INFO, "%s ", (char *) format_host(r->rtm_family,
								     RTA_PAYLOAD(tb[RTA_DST]),
								     RTA_DATA(tb[RTA_DST]), abuf, sizeof (abuf))
			    );
		}
	} else if (r->rtm_dst_len) {
		syslog(LOG_INFO, "0/%d ", r->rtm_dst_len);
	} else {
		syslog(LOG_INFO, "default ");
	}

	if (tb[RTA_SRC]) {
		if (r->rtm_src_len != host_len) {
			syslog(LOG_INFO, "from %s/%u ", rt_addr_n2a(r->rtm_family,
								    RTA_DATA(tb[RTA_SRC]),
								    abuf, sizeof (abuf)), r->rtm_src_len);
		} else {
			syslog(LOG_INFO, "from %s ", (char *) format_host(r->rtm_family,
									  RTA_PAYLOAD(tb[RTA_SRC]),
									  RTA_DATA(tb[RTA_SRC]), abuf, sizeof (abuf))
			    );
		}
	} else if (r->rtm_src_len) {
		syslog(LOG_INFO, "from 0/%u ", r->rtm_src_len);
	}

	if (tb[RTA_GATEWAY]) {
		syslog(LOG_INFO, "via %s ",
		       (char *) format_host(r->rtm_family,
					    RTA_PAYLOAD(tb[RTA_GATEWAY]),
					    RTA_DATA(tb[RTA_GATEWAY]), abuf, sizeof (abuf)));
	}

	if (tb[RTA_OIF]) {
		syslog(LOG_INFO, "dev %s ", ll_index_to_name(*(int *) RTA_DATA(tb[RTA_OIF])));
	}

	if (tb[RTA_PREFSRC]) {
		char address[INET_ADDR_SIZE] = { 0 };
		struct mcast_ip_entry_t *p_mcast_ip_entry = NULL;
		/* Do not use format_host(). It is our local addr
		   and symbolic name will not be useful.
		 */
		syslog(LOG_INFO, " src %s ",
		       (char *) rt_addr_n2a(r->rtm_family, RTA_DATA(tb[RTA_PREFSRC]), abuf, sizeof (abuf)));
		sprintf(address, (char *) rt_addr_n2a(r->rtm_family, RTA_DATA(tb[RTA_PREFSRC]), abuf, sizeof (abuf)));

		p_mcast_ip_entry = mcast_ip_entry_get(address);
		if (p_mcast_ip_entry == NULL) {
			mcast_ip_entry_add(address);
		}
	}
	if (tb[RTA_PRIORITY])
		syslog(LOG_INFO, " metric %u ", rta_getattr_u32(tb[RTA_PRIORITY]));
	if (r->rtm_flags & RTNH_F_DEAD)
		syslog(LOG_INFO, "dead ");
	if (r->rtm_flags & RTNH_F_ONLINK)
		syslog(LOG_INFO, "onlink ");
	if (r->rtm_flags & RTNH_F_PERVASIVE)
		syslog(LOG_INFO, "pervasive ");
	if (r->rtm_flags & RTM_F_NOTIFY)
		syslog(LOG_INFO, "notify ");
	if (tb[RTA_MARK]) {
		unsigned int mark = *(unsigned int *) RTA_DATA(tb[RTA_MARK]);
		if (mark) {
			if (mark >= 16)
				syslog(LOG_INFO, " mark 0x%x", mark);
			else
				syslog(LOG_INFO, " mark %u", mark);
		}
	}

	if ((r->rtm_flags & RTM_F_CLONED) && r->rtm_family == AF_INET) {
		__u32 flags = r->rtm_flags & ~0xFFFF;
		int first = 1;

		syslog(LOG_INFO, "%s    cache ", _SL_);

#define PRTFL(fl,flname) if (flags&RTCF_##fl) { \
  flags &= ~RTCF_##fl; \
  syslog (LOG_INFO,"%s" flname "%s", first ? "<" : "", flags ? "," : "> "); \
  first = 0; }
		PRTFL(LOCAL, "local");
		PRTFL(REJECT, "reject");
		PRTFL(MULTICAST, "mc");
		PRTFL(BROADCAST, "brd");
		PRTFL(DNAT, "dst-nat");
		PRTFL(SNAT, "src-nat");
		PRTFL(MASQ, "masq");
		PRTFL(DIRECTDST, "dst-direct");
		PRTFL(DIRECTSRC, "src-direct");
		PRTFL(REDIRECTED, "redirected");
		PRTFL(DOREDIRECT, "redirect");
		PRTFL(FAST, "fastroute");
		PRTFL(NOTIFY, "notify");
		PRTFL(TPROXY, "proxy");

		if (flags)
			syslog(LOG_INFO, "%s%x> ", first ? "<" : "", flags);
		if (tb[RTA_CACHEINFO]) {
			struct rta_cacheinfo *ci = RTA_DATA(tb[RTA_CACHEINFO]);
			if (ci->rta_expires != 0)
				syslog(LOG_INFO, " expires %dsec", ci->rta_expires / hz);
			if (ci->rta_error != 0)
				syslog(LOG_INFO, " error %d", ci->rta_error);
			if (ci->rta_id)
				syslog(LOG_INFO, " ipid 0x%04x", ci->rta_id);
			if (ci->rta_ts || ci->rta_tsage)
				syslog(LOG_INFO, " ts 0x%x tsage %dsec", ci->rta_ts, ci->rta_tsage);
		}
	} else if (r->rtm_family == AF_INET6) {
		struct rta_cacheinfo *ci = NULL;
		if (tb[RTA_CACHEINFO])
			ci = RTA_DATA(tb[RTA_CACHEINFO]);
		if ((r->rtm_flags & RTM_F_CLONED) || (ci && ci->rta_expires)) {
			if (r->rtm_flags & RTM_F_CLONED)
				syslog(LOG_INFO, "%s    cache ", _SL_);
			if (ci->rta_expires)
				syslog(LOG_INFO, " expires %dsec", ci->rta_expires / hz);
			if (ci->rta_error != 0)
				syslog(LOG_INFO, " error %d", ci->rta_error);
		} else if (ci) {
			if (ci->rta_error != 0)
				syslog(LOG_INFO, " error %d", ci->rta_error);
		}
	}
	if (tb[RTA_METRICS]) {
		int i;
		unsigned mxlock = 0;
		struct rtattr *mxrta[RTAX_MAX + 1];

		parse_rtattr(mxrta, RTAX_MAX, RTA_DATA(tb[RTA_METRICS]), RTA_PAYLOAD(tb[RTA_METRICS]));
		if (mxrta[RTAX_LOCK])
			mxlock = *(unsigned *) RTA_DATA(mxrta[RTAX_LOCK]);

		for (i = 2; i <= RTAX_MAX; i++) {
			__u32 val;

			if (mxrta[i] == NULL)
				continue;

			if (i < sizeof (mx_names) / sizeof (char *) && mx_names[i])
				syslog(LOG_INFO, " %s", mx_names[i]);
			else
				syslog(LOG_INFO, " metric %d", i);

			if (mxlock & (1 << i))
				syslog(LOG_INFO, " lock");

			val = rta_getattr_u32(mxrta[i]);

			switch (i) {
			case RTAX_FEATURES:
				print_rtax_features(NULL, val);
				break;
			case RTAX_HOPLIMIT:
				if ((int) val == -1)
					val = 0;
				/* fall through */
			default:
				syslog(LOG_INFO, " %u", val);
				break;

			case RTAX_RTT:
			case RTAX_RTTVAR:
			case RTAX_RTO_MIN:
				if (i == RTAX_RTT)
					val /= 8;
				else if (i == RTAX_RTTVAR)
					val /= 4;

				if (val >= 1000)
					syslog(LOG_INFO, " %gs", val / 1e3);
				else
					syslog(LOG_INFO, " %ums", val);
				break;
			}
		}
	}
	if (tb[RTA_IIF]) {
		syslog(LOG_INFO, " iif %s", ll_index_to_name(*(int *) RTA_DATA(tb[RTA_IIF])));
	}
	if (tb[RTA_MULTIPATH]) {
		struct rtnexthop *nh = RTA_DATA(tb[RTA_MULTIPATH]);
		int first = 0;

		len = RTA_PAYLOAD(tb[RTA_MULTIPATH]);

		for (;;) {
			if (len < sizeof (*nh))
				break;
			if (nh->rtnh_len > len)
				break;
			if (r->rtm_flags & RTM_F_CLONED && r->rtm_type == RTN_MULTICAST) {
				if (first)
					syslog(LOG_INFO, " Oifs:");
				else
					syslog(LOG_INFO, " ");
			} else
				syslog(LOG_INFO, "%s\tnexthop", _SL_);
			if (nh->rtnh_len > sizeof (*nh)) {
				parse_rtattr(tb, RTA_MAX, RTNH_DATA(nh), nh->rtnh_len - sizeof (*nh));
				if (tb[RTA_GATEWAY]) {
					syslog(LOG_INFO, " via %s ",
					       format_host(r->rtm_family,
							   RTA_PAYLOAD(tb[RTA_GATEWAY]),
							   RTA_DATA(tb[RTA_GATEWAY]), abuf, sizeof (abuf)));
				}
			}
			if (r->rtm_flags & RTM_F_CLONED && r->rtm_type == RTN_MULTICAST) {
				syslog(LOG_INFO, " %s", (char *) ll_index_to_name(nh->rtnh_ifindex));
				if (nh->rtnh_hops != 1)
					syslog(LOG_INFO, "(ttl>%d)", nh->rtnh_hops);
			} else {
				syslog(LOG_INFO, " dev %s", (char *) ll_index_to_name(nh->rtnh_ifindex));
				syslog(LOG_INFO, " weight %d", nh->rtnh_hops + 1);
			}
			if (nh->rtnh_flags & RTNH_F_DEAD)
				syslog(LOG_INFO, " dead");
			if (nh->rtnh_flags & RTNH_F_ONLINK)
				syslog(LOG_INFO, " onlink");
			if (nh->rtnh_flags & RTNH_F_PERVASIVE)
				syslog(LOG_INFO, " pervasive");
			len -= NLMSG_ALIGN(nh->rtnh_len);
			nh = RTNH_NEXT(nh);
		}
	}
	syslog(LOG_INFO, "\n");
	return 0;
}

/**
 * @brief  initialize our wan route knowledge
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
static int
iproute_parse_init(void)
{

	if (rtnl_wilddump_request(&rth, AF_INET, RTM_GETROUTE) < 0) {
		syslog(LOG_INFO, "Cannot send dump request\n");
		return 1;
	}

	if (rtnl_dump_filter(&rth, parse_route, stdout) < 0) {
		syslog(LOG_INFO, "Dump terminated\n");
		return 1;
	}
	return 0;
}

static inline char *
cache_mdb_entry_srcmac(struct br_mdb_entry *e)
{
	SPRINT_BUF(abuf);
	int i;
	int len = 0;
	for (i = 0; i < ETH_ALEN; i++) {
		if (i < (ETH_ALEN - 1)) {
			len += sprintf(abuf + len, "%02X:", e->src_addr.eth_addr[i]);
		} else {
			len += sprintf(abuf + len, "%02X", e->src_addr.eth_addr[i]);
		}
	}
	return (abuf);
}

static void
cache_mdb_entry(struct nlmsghdr *n, int ifindex, struct br_mdb_entry *e)
{
	SPRINT_BUF(abuf);
	struct mcg_br_mdb_entry_t *head;
	struct mcg_br_mdb_entry_t *mcge;

	syslog(LOG_INFO, "%s:%d \n", __FUNCTION__, __LINE__);

	if (e->state & MDB_PERMANENT)
		return;

	if (iswifi((char *) ll_index_to_name(e->ifindex))) {
		if (mcastpa.params.nowifi) {
			return;
		}
	}

	if (e->addr.proto == htons(ETH_P_IP)) {
		if (inet_ntop(AF_INET, &e->addr.u.ip4, abuf, sizeof (abuf))) {

			if ((n->nlmsg_type == RTM_NEWMDB) || (n->nlmsg_type == RTM_GETMDB)) {

				syslog(LOG_NOTICE, "RTM_NEWMDB dev %s port %s grp %s srcmac %s\n",
				       (char *) ll_index_to_name(ifindex), (char *) ll_index_to_name(e->ifindex), abuf,
				       cache_mdb_entry_srcmac(e));

				head = mcg_br_entry_head_get(e);
				if (head == NULL) {
					head = mcg_br_entry_head_add(e);
				}
				if (head != NULL) {
					head->br_ifindex = ifindex;
					mcge = mcg_br_entry_get(head, e);
					if (mcge == NULL) {
						mcge = mcg_br_entry_add(head, e);
					}
					if (mcge != NULL) {
						mcge->br_ifindex = ifindex;
					}
					mcg_br_entry_join(head);
				} else {
				}
			}
			if (n->nlmsg_type == RTM_DELMDB) {

				syslog(LOG_NOTICE, "RTM_DELMDB dev %s port %s grp %s srcmac %s\n",
				       (char *) ll_index_to_name(ifindex), (char *) ll_index_to_name(e->ifindex), abuf,
				       cache_mdb_entry_srcmac(e));

				head = mcg_br_entry_head_get(e);
				if (head == NULL) {
					syslog(LOG_INFO, "RTM_DELMDB head is NULL\n");
					return;
				}
				mcge = mcg_br_entry_get(head, e);
				if (mcge == NULL) {
					syslog(LOG_INFO, "RTM_DELMDB mcge is NULL\n");
					return;
				}
				mcg_br_entry_leave(head, e);
				if (list_empty(&head->mcg_entry)) {
					mcg_br_entry_head_del(head);
				}
			}
		}
	} else {
		if (inet_ntop(AF_INET, &e->addr.u.ip6, abuf, sizeof (abuf))) {
			syslog(LOG_INFO, "dev %s port %s grp %s \n", (char *) ll_index_to_name(ifindex),
			       (char *) ll_index_to_name(e->ifindex),
			       inet_ntop(AF_INET6, &e->addr.u.ip6, abuf, sizeof (abuf)));
		}
	}
}

/**
 * @brief parses mdb_entry - may contain mulitiples and calls cache function 
 * @details checks for bridge membership and not wan interface
 * @note We saw Cspire join on wan interface
 * @note ifindex is bridge ifindex
 * @todo we only look for one wan interface.  
 * @todo what about guest bridge -  need to check for that
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
static void
parse_br_mdb_entry(struct nlmsghdr *n, int ifindex, struct rtattr *attr)
{
	struct rtattr *i;
	int rem;
	struct br_mdb_entry *e;

	syslog(LOG_INFO, "%s:%d bridge %s\n", __FUNCTION__, __LINE__, (char *) ll_index_to_name(ifindex));

	rem = RTA_PAYLOAD(attr);
	for (i = RTA_DATA(attr); RTA_OK(i, rem); i = RTA_NEXT(i, rem)) {
		e = RTA_DATA(i);
		if (mcastpa.params.wan_ifindex == ifindex) {
			syslog(LOG_INFO, "%s:%d ignoring join on wan interface\n", __FUNCTION__, __LINE__);
			continue;
		}
		if (mcastpa.params.bridged) {
			if (ifindex == ll_name_to_index(mcastpa.params.bridge_name)) {
				cache_mdb_entry(n, ifindex, e);
			} else {
				syslog(LOG_INFO, "%s:%d bridge %s mismatch %s\n", __FUNCTION__, __LINE__,
				       (char *) ll_index_to_name(ifindex), mcastpa.params.bridge_name);
			}
		} else {
			cache_mdb_entry(n, ifindex, e);
		}
	}
}

int
parse_mdb(const struct sockaddr_nl *who, struct nlmsghdr *n, void *arg)
{
	struct br_port_msg *r = NLMSG_DATA(n);
	int len = n->nlmsg_len;
	struct rtattr *tb[MDBA_MAX + 1];

	syslog(LOG_INFO, "%s:%d \n", __FUNCTION__, __LINE__);

	if (n->nlmsg_type != RTM_GETMDB && n->nlmsg_type != RTM_NEWMDB && n->nlmsg_type != RTM_DELMDB) {
		syslog(LOG_INFO, "Not RTM_GETMDB, RTM_NEWMDB or RTM_DELMDB: %08x %08x %08x\n",
		       n->nlmsg_len, n->nlmsg_type, n->nlmsg_flags);

		return 0;
	}

	len -= NLMSG_LENGTH(sizeof (*r));
	if (len < 0) {
		syslog(LOG_INFO, "BUG: wrong nlmsg len %d\n", len);
		return -1;
	}

	parse_rtattr(tb, MDBA_MAX, MDBA_RTA(r), n->nlmsg_len - NLMSG_LENGTH(sizeof (*r)));

	if (tb[MDBA_MDB]) {
		struct rtattr *i;
		int rem = RTA_PAYLOAD(tb[MDBA_MDB]);

		for (i = RTA_DATA(tb[MDBA_MDB]); RTA_OK(i, rem); i = RTA_NEXT(i, rem))
			parse_br_mdb_entry(n, r->ifindex, i);
	}

	return 0;
}

int
do_mroute(const struct sockaddr_nl *who, struct nlmsghdr *n, void *arg)
{
	struct rtmsg *r = NLMSG_DATA(n);
	int len = n->nlmsg_len;
	struct rtattr *tb[RTA_MAX + 1];
	char abuf[256];
	int iif = 0;
	int family;
	int delete = 0;
	char this_address[128] = { 0 };
	char group_address[128] = { 0 };
	struct mcg_br_mdb_entry_t *head;

	syslog(LOG_INFO, "%s:%d \n", __FUNCTION__, __LINE__);

	if ((n->nlmsg_type != RTM_NEWROUTE && n->nlmsg_type != RTM_DELROUTE) || !(n->nlmsg_flags & NLM_F_MULTI)) {
//              syslog (LOG_INFO,"Not a multicast route: %08x %08x %08x\n", n->nlmsg_len, n->nlmsg_type, n->nlmsg_flags);
//              return 0;
	}
	len -= NLMSG_LENGTH(sizeof (*r));
	if (len < 0) {
		syslog(LOG_INFO, "BUG: wrong nlmsg len %d\n", len);
		return -1;
	}

	if (r->rtm_type != RTN_MULTICAST) {
		return 0;
	}

	parse_rtattr(tb, RTA_MAX, RTM_RTA(r), len);

	if (tb[RTA_IIF]) {
		iif = *(int *) RTA_DATA(tb[RTA_IIF]);
		if (!iswan((char *) ll_index_to_name(iif))) {
			return 0;
		}
	} else {
		return 0;
	}

	family = r->rtm_family == RTNL_FAMILY_IPMR ? AF_INET : AF_INET6;

	if (tb[RTA_SRC]) {
		len =
		    snprintf(this_address, sizeof (this_address), "%s",
			     (char *) rt_addr_n2a(family, RTA_DATA(tb[RTA_SRC]), abuf, sizeof (abuf)));
		if (islocaladdr(this_address)) {
			return 0;
		} else {
		}
	} else {
		return 0;
	}

	if (n->nlmsg_type == RTM_DELROUTE) {
		delete = 1;
	}

	if (tb[RTA_DST]) {
		len =
		    snprintf(group_address, sizeof (group_address), "%s",
			     (char *) rt_addr_n2a(family, RTA_DATA(tb[RTA_DST]), abuf, sizeof (abuf)));
	} else {
		return 0;
	}

	if (delete) {
		head = mcg_br_entry_head_get_from_group(group_address);
		if (head != NULL) {
			syslog(LOG_INFO, "%s:%d not deleteing mc group %s from %s head not found\n", __FUNCTION__,
			       __LINE__, group_address, this_address);
#if 0

			// routes get deleted and added every few minutes so we loose ppa flows

			mcg_br_entry_head_del_all(head);
			mcg_br_entry_leave(head, NULL);
			mcg_br_entry_head_del(head);
#endif
		} else {
			syslog(LOG_INFO, "%s:%d mc group %s from %s head not found\n", __FUNCTION__, __LINE__,
			       group_address, this_address);
		}
	} else {
		syslog(LOG_INFO, "%s:%d mc group %s from %s\n", __FUNCTION__, __LINE__, group_address, this_address);
		head = mcg_br_entry_head_get_from_group(group_address);
		if (head != NULL) {
			if (head->src[0] == 0) {
				strcpy(head->src, this_address);
				head->wan_ifindex = iif;
				mcg_br_entry_join(head);
				syslog(LOG_INFO, "%s:%d mc group %s from %s added to head\n", __FUNCTION__, __LINE__,
				       group_address, head->src);
			} else {
				syslog(LOG_INFO, "%s:%d mc group %s from %s was not installed because %s exist \n",
				       __FUNCTION__, __LINE__, group_address, this_address, head->src);
			}
		} else {
		}
	}
	return 0;
}

static int
do_monitor_msg(const struct sockaddr_nl *who, struct rtnl_ctrl_data *data, struct nlmsghdr *n, void *arg)
{
	struct rtmsg *r = NLMSG_DATA(n);

	switch (n->nlmsg_type) {
	case RTM_NEWMDB:
		syslog(LOG_INFO, "%s:%d NEWMDB\n", __FUNCTION__, __LINE__);
		parse_mdb(who, n, arg);
		break;
	case RTM_DELMDB:
		syslog(LOG_INFO, "%s:%d DELMDB\n", __FUNCTION__, __LINE__);
		parse_mdb(who, n, arg);
		break;
	case RTM_NEWROUTE:
		if (r->rtm_type == RTN_MULTICAST) {
			syslog(LOG_INFO, "%s:%d NEWMCROUTE\n", __FUNCTION__, __LINE__);
			do_mroute(who, n, arg);
		} else {
			syslog(LOG_INFO, "%s:%d NEWROUTE\n", __FUNCTION__, __LINE__);
			parse_route(who, n, arg);
		}
		break;
	case RTM_DELROUTE:
		if (r->rtm_type == RTN_MULTICAST) {
			syslog(LOG_INFO, "%s:%d DELMCROUTE\n", __FUNCTION__, __LINE__);
			do_mroute(who, n, arg);
		} else {
			parse_route(who, n, arg);
			syslog(LOG_INFO, "%s:%d DELROUTE\n", __FUNCTION__, __LINE__);
		}
		break;
	default:
		syslog(LOG_INFO, "do_monitor: nlmmsg_type unknown %u\n", n->nlmsg_type);
		break;
	}
	return (0);
}

/**
 * @brief  initialize our wan mroute knowledge
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
static int
mroute_parse_init(void)
{

	if (rtnl_wilddump_request(&rth, AF_INET, RTM_GETROUTE) < 0) {
		syslog(LOG_INFO, "Cannot send dump request\n");
		return 1;
	}

	if (rtnl_dump_filter(&rth, do_mroute, stdout) < 0) {
		syslog(LOG_INFO, "Dump terminated\n");
		return 1;
	}
	return 0;
}

/**
 * @brief sets br-video to be a virtual router port 
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 */
#define MROUTE_RATE_LIMIT_ENDLESS 0
#define MROUTE_TTL_THRESHOLD 1
#define MROUTE_DEFAULT_TTL 1
void
mroute_bridge_init(void)
{

	int res;
	int sock;
	int proto;
	int mrt_cmd;
	int val = 1;
	int table = 0;
	struct vifctl vc;
	unsigned char flags;

	syslog(LOG_INFO, "%s:%d ", __FUNCTION__, __LINE__);
	if ((sock = socket(AF_INET, SOCK_RAW, IPPROTO_IGMP)) == -1) {
		syslog(LOG_INFO, "%s:%d IPPROTO_IGMP faild", __FUNCTION__, __LINE__);
		return;
	}

	res = setsockopt(sock, IPPROTO_IP, MRT_TABLE, &table, sizeof (table));
	syslog(LOG_INFO, "%s:%d MRT_TABLE res %d\n", __FUNCTION__, __LINE__, res);
	proto = IPPROTO_IP;
	mrt_cmd = MRT_INIT;
	res = setsockopt(sock, proto, mrt_cmd, (void *) &val, sizeof (val));
	syslog(LOG_INFO, "%s:%d MRT_INIT res %d\n", __FUNCTION__, __LINE__, res);

	memset(&vc, 0, sizeof (vc));
	flags = VIFF_USE_IFINDEX + VIFF_REGISTER;
	flags = VIFF_USE_IFINDEX;
	vc.vifc_vifi = 0;	//vifNum;
	vc.vifc_flags = flags;
	vc.vifc_threshold = MROUTE_TTL_THRESHOLD;
	vc.vifc_rate_limit = MROUTE_RATE_LIMIT_ENDLESS;
	vc.vifc_lcl_ifindex = ll_name_to_index("br-video");	//if_index;
	res = setsockopt(sock, IPPROTO_IP, MRT_ADD_VIF, (void *) &vc, sizeof (vc));
	syslog(LOG_INFO, "%s:%d MRT_ADD_VIF res %d\n", __FUNCTION__, __LINE__, res);

}

/**
 * @brief  initialize our lan mdb knowledge
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
static int
mdb_parse_init(void)
{

	if (rtnl_wilddump_request(&rth, PF_BRIDGE, RTM_GETMDB) < 0) {
		syslog(LOG_INFO, "Cannot send RTM_GETMDG dump request\n");
		return 1;
	}

	if (rtnl_dump_filter(&rth, parse_mdb, 0) < 0) {
		syslog(LOG_INFO, "Dump terminated\n");
		return 1;
	}
	return 0;
}

/**
 * @brief handle any vsa requests 
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
static int
vsa_parse_init(void)
{
	mcast_vsa_get();
	if (mcastpa.params.vsa.valid) {
		vsa_entry_process();
	}
	return 0;
}

/**
 * @brief starts a netlink listener for routes, multicast routes and MDB changes
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
do_monitor(void)
{

	unsigned groups = 0;
	struct mcastpa_system_init_t msi;

	memset(&msi, 0, sizeof (struct mcastpa_system_init_t));
	pa_init(&msi);

	groups |= nl_mgrp(RTNLGRP_IPV4_MROUTE);
	groups |= nl_mgrp(RTNLGRP_MDB);
	groups |= nl_mgrp(RTNLGRP_IPV4_ROUTE);

	if (rtnl_open(&rth, groups) < 0)
		return (-1);

	ll_init_map(&rth);

	/* get existing state and possibly push flows from the initial state */

	/* order is important */

	syslog(LOG_INFO, "%s %s %s\n", "========= monitor mcast intial ===========", __DATE__, __TIME__);

#if 0
	if (mcastpa.params.bridged) {
		mroute_bridge_init();
	}
#endif

	syslog(LOG_INFO, "%s \n", "========= iproute_parse_init ===========");
	iproute_parse_init();

	syslog(LOG_INFO, "%s \n", "========= mdb_parse_init ===========");
	mdb_parse_init();

	syslog(LOG_INFO, "%s \n", "========= route_parse_init ===========");
	mroute_parse_init();

	syslog(LOG_INFO, "%s \n", "========= vsa_parse_init ===========");
	vsa_parse_init();

	syslog(LOG_INFO, "%s \n", "========= monitoring mcast ... ===========");

	if (rtnl_listen(&rth, do_monitor_msg, NULL) < 0)
		return (-1);

	return 0;
}

/**
 * @brief looks for wan device and sleep poll until it exists
 * @details can be a startup race condition where we are started but netif hasn't created the device yet
 * @note seen in Cspire CDT testing - never happen in default router mode
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
do_wait_wan(char *name)
{
	int ifindex = 0;
	int count = 0;

	syslog(LOG_INFO, "%s:%d wating for wan device %s \n", __FUNCTION__, __LINE__, name);

	while (1) {
		count++;
		ifindex = ll_name_to_index(name);
		if (ifindex <= 0) {
			sleep(1);
		} else {
			mcastpa.params.wan_ifindex = ll_name_to_index(name);
			break;
		}
	}
	syslog(LOG_INFO, "%s:%d found wan device %s ifindex %d in %d try\n", __FUNCTION__, __LINE__, name, ifindex,
	       count);
	return 0;
}

/**
 * @brief sighandler 
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
mcast_sig_handler(int signo)
{

	syslog(LOG_INFO, "%s:%d %d", __FUNCTION__, __LINE__, signo);
	switch (signo) {
	case SIGQUIT:
	case SIGINT:
	case SIGTERM:
		syslog(LOG_INFO, "%s:%d quit or kill %d", __FUNCTION__, __LINE__, signo);
		mdb_exit_handler();
		exit(0);
	case SIGUSR1:
		mcg_br_entry_head_list_show();
		break;
	case SIGUSR2:
		syslog(LOG_INFO, "%s:%d before vsa_entry_process", __FUNCTION__, __LINE__);
		mcast_vsa_get();
		if (mcastpa.params.vsa.valid) {
			vsa_entry_process();
		}
		syslog(LOG_INFO, "%s:%d after vsa_entry_process", __FUNCTION__, __LINE__);
		break;
	}
}

/**
 * @brief experimental code here 
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 */

void
print_ip_header(unsigned char *Buffer, int Size)
{
	struct sockaddr_in source, dest;
	struct iphdr *iph = (struct iphdr *) Buffer;

	memset(&source, 0, sizeof (source));
	source.sin_addr.s_addr = iph->saddr;

	memset(&dest, 0, sizeof (dest));
	dest.sin_addr.s_addr = iph->daddr;

	printf("IP Header\n");
	printf("   |-IP Version        : %d\n", (unsigned int) iph->version);
	printf("   |-IP Header Length  : %d DWORDS or %d Bytes\n", (unsigned int) iph->ihl,
	       ((unsigned int) (iph->ihl)) * 4);
	printf("   |-Type Of Service   : %d\n", (unsigned int) iph->tos);
	printf("   |-IP Total Length   : %d  Bytes(Size of Packet)\n", ntohs(iph->tot_len));
	printf("   |-Identification    : %d\n", ntohs(iph->id));
	printf("   |-TTL      : %d\n", (unsigned int) iph->ttl);
	printf("   |-Protocol : %d\n", (unsigned int) iph->protocol);
	printf("   |-Checksum : %d\n", ntohs(iph->check));
	printf("   |-Source IP        : %s\n", inet_ntoa(source.sin_addr));
	printf("   |-Destination IP   : %s\n", inet_ntoa(dest.sin_addr));
}

void
process_packet(unsigned char *buffer, int size)
{
	//Get the IP Header part of this packet
	struct iphdr *iph = (struct iphdr *) buffer;
	switch (iph->protocol)	//Check the Protocol and do accordingly...
	{
	case 1:		//ICMP Protocol
		printf("ICMP\n");
		break;

	case 2:		//IGMP Protocol
		printf("IGMP\n");
		break;

	case 6:		//TCP Protocol
		printf("TCP\n");
		break;

	case 17:		//UDP Protocol
		printf("UDP\n");
		break;

	default:		//Some Other Protocol like ARP etc.
		printf("protocol %d\n", iph->protocol);
		break;
	}
	print_ip_header(buffer, size);
}

void
do_exp(void)
{

	int data_size;
	unsigned int saddr_size;
	struct sockaddr saddr;
	int res;
	int sock;
	int proto;
	int mrt_cmd;
	int val = 1;
	int table = 0;
	struct vifctl vc;
	unsigned char flags;
	unsigned char *buffer = (unsigned char *) malloc(65536);	//Its Big!

	printf("%s:%d \n", __FUNCTION__, __LINE__);
	if ((sock = socket(AF_INET, SOCK_RAW, IPPROTO_IGMP)) == -1) {
		printf("%s:%d socket IPPROTO_IGMP failed \n", __FUNCTION__, __LINE__);
		return;
	}

	res = setsockopt(sock, IPPROTO_IP, MRT_TABLE, &table, sizeof (table));
	printf("%s:%d MRT_TABLE res %d\n", __FUNCTION__, __LINE__, res);
	proto = IPPROTO_IP;
	mrt_cmd = MRT_INIT;
	res = setsockopt(sock, proto, mrt_cmd, (void *) &val, sizeof (val));
	printf("%s:%d MRT_INIT res %d\n", __FUNCTION__, __LINE__, res);

	memset(&vc, 0, sizeof (vc));
	flags = VIFF_USE_IFINDEX;
	vc.vifc_vifi = 0;	//vifNum;
	vc.vifc_flags = flags;
	vc.vifc_threshold = MROUTE_TTL_THRESHOLD;
	vc.vifc_rate_limit = MROUTE_RATE_LIMIT_ENDLESS;
	vc.vifc_lcl_ifindex = ll_name_to_index("br-video");	//if_index;
	res = setsockopt(sock, IPPROTO_IP, MRT_ADD_VIF, (void *) &vc, sizeof (vc));
	printf("%s:%d MRT_ADD_VIF res %d\n", __FUNCTION__, __LINE__, res);

	while (1) {
		saddr_size = sizeof saddr;
		data_size = recvfrom(sock, buffer, 65536, 0, &saddr, &saddr_size);
		if (data_size < 0) {
			printf("Recvfrom error , failed to get packets\n");
			return;
		}
		printf("%s:%d data size %d\n", __FUNCTION__, __LINE__, data_size);
		process_packet(buffer, data_size);
	}
	close(sock);
	printf("Finished");
	return;

}

/**
 * @brief usage helper
 * @details
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
void
mcastpa_usage(void)
{
	printf("mcastpa version: 0.85\n");
	printf("Usage: \n");
	printf(" --foreground run in foreground \n");
	printf(" --wan <iface> interface\n");
	printf(" --src <A.B.C.D> video source IP address\n");
	printf(" --bridge set to bridged mode \n");
	printf(" --exp experimental code segment testing\n");
	printf(" --nowifi don't push wifi to packet accellerator\n");
}

static struct option long_options[] = {
	{"verbose", no_argument, 0, 'v'},
	{"foreground", no_argument, 0, 'f'},
	{"wan", required_argument, 0, 'w'},
	{"bridge", required_argument, 0, 'b'},
	{"video2lan", required_argument, 0, 'V'},
	{"src", required_argument, 0, 's'},
	{"exp", no_argument, 0, 'x'},
	{"nowifi", no_argument, 0, 'n'},
	{0, 0, 0, 0}
};

/**
 * @brief main entry point
 * @details parse argc argv and get stuff e.g. startup params etc.
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
main(int argc, char **argv)
{
	int opt = 0;
	int long_index = 0;
	pid_t process_id = 0;
	pid_t sid = 0;
	char name[IFNAMSIZ];
	struct mcast_wan_entry_t *p_mcast_wan_entry;

	memset(&mcastpa, 0, sizeof (struct mcastpa_t));

	INIT_LIST_HEAD(&mcastpa.mcg_head);
	INIT_LIST_HEAD(&mcastpa.ip_head);
	INIT_LIST_HEAD(&mcastpa.wan_head);

	while ((opt = getopt_long(argc, argv, "vfgmb:Vw:s:x", long_options, &long_index)) != -1) {
		switch (opt) {
		case 'v':
			mcastpa.params.verbose = 1;
			mcastpa.params.dbg = 1;
			break;
		case 'f':
			mcastpa.params.foreground = 1;
			break;
		case 'm':
			mcastpa.params.monitor = 1;
			break;
		case 'b':
			sscanf(optarg, "%s", mcastpa.params.bridge_name);
			mcastpa.params.bridged = 1;
			break;
		case 'V':
			sscanf(optarg, "%s", mcastpa.params.video2lan_name);
			mcastpa.params.video2lan = 1;
			break;
		case 'w':
			mcastpa.params.wan = 1;
			sscanf(optarg, "%s", name);
			p_mcast_wan_entry = mcast_wan_entry_get(name);
			if (p_mcast_wan_entry == NULL) {
				mcast_wan_entry_add(name);
			}
			break;
		case 's':
			mcastpa.params.use_src = 1;
			sscanf(optarg, "%s", mcastpa.params.src);
			break;
		case 'x':
			mcastpa.params.exp = 1;
			break;
		case 'n':

			mcastpa.params.nowifi = 1;
			break;
		default:
			mcastpa_usage();
			exit(-1);
		}
	}

	/* if no wan specified then add it */

	if (mcastpa.params.wan == 0) {
		p_mcast_wan_entry = mcast_wan_entry_get("wan");
		if (p_mcast_wan_entry == NULL) {
			mcast_wan_entry_add(name);
		}
	}

	if (mcastpa.params.verbose) {
		setlogmask(LOG_UPTO(LOG_INFO));
	} else {
		setlogmask(LOG_UPTO(LOG_NOTICE));
	}

	openlog("mcast-pa", LOG_CONS | LOG_PID | LOG_NDELAY, LOG_LOCAL1);


	if (signal(SIGUSR1, mcast_sig_handler) == SIG_ERR)
		printf("\ncan't catch SIGUSR1\n");

	if (signal(SIGUSR2, mcast_sig_handler) == SIG_ERR)
		printf("\ncan't catch SIGUSR1\n");

	if (signal(SIGQUIT, mcast_sig_handler) == SIG_ERR)
		printf("\ncan't catch SIGQUIT\n");

	if (signal(SIGINT, mcast_sig_handler) == SIG_ERR)
		printf("\ncan't catch SIGINT\n");

	if (signal(SIGTERM, mcast_sig_handler) == SIG_ERR)
		printf("\ncan't catch SIGTERM\n");

	if (mcastpa.params.exp == 1) {
		do_exp();
		exit(0);
	}

	if (mcastpa.params.foreground == 1) {
		do_monitor();
		exit(0);
	}


	{
		FILE *f = fopen("/var/run/mcast-pa.pid", "w");
		if (f) {
			fprintf(f, "%u\n", getpid());
			fclose(f);
		}
	}

	umask(0);
	sid = setsid();
	if (sid < 0) {
		exit(1);
	}

	syslog(LOG_INFO, "mcast-pa process_id %d sid %d ", process_id, sid);

	chdir("/");

	close(STDIN_FILENO);
	close(STDOUT_FILENO);
	close(STDERR_FILENO);

	if (mcastpa.params.wan == 1) {
		do_wait_wan(name);
	}

	do_monitor();

	return 0;
}
