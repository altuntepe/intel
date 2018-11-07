/*****************************************************************************/
/*               _____                      _  ______ _____                  */
/*              /  ___|                    | | | ___ \  __ \                 */
/*              \ `--. _ __ ___   __ _ _ __| |_| |_/ / |  \/                 */
/*               `--. \ '_ ` _ \ / _` | '__| __|    /| | __                  */
/*              /\__/ / | | | | | (_| | |  | |_| |\ \| |_\ \                 */
/*             \____/|_| |_| |_|\__,_|_|   \__\_| \_|\____/ Inc.             */
/*                                                                           */
/*****************************************************************************/
/*                                                                           */
/*                       copyright 2018 by SmartRG, Inc.                     */
/*                              Santa Barbara, CA                            */
/*                                                                           */
/*****************************************************************************/
/*                                                                           */
/* Author: tim.hayes@smartrg.com                                             */
/*                                                                           */
/* Purpose: ppacmd driver for intel pa mc flows                              */
/*                                                                           */
/*****************************************************************************/
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <syslog.h>
#include <linux/if_ether.h>

#define MCASTPA_STRING_SIZE 128

struct mcastpa_system_init_t {
#define MSI_FLAG_EXP		1<<0
	int flags;				/**< bridge, srcip valid etc. */
	char srcip[MCASTPA_STRING_SIZE];	/**< ascii string name of video source ip */
	char wan[MCASTPA_STRING_SIZE];	/**< ascii string name of wan video ingress device */
};

struct mcastpa_join_leave_t {
#define MJL_FLAG_EXP		1<<0		/**<  experimental use */
#define MJL_FLAG_BRIDGE	1<<1		/**<  bridge mode - no src ip */
#define MJL_FLAG_SRCIP	1<<2		/**<  srcip included */
#define MJL_FLAG_LAN		1<<3		/**<  contains lan entries i.e. not empty */
#define MJL_FLAG_UPDATE	1<<4		/**<  group has been joined at least once i.e. update to add */

	int flags;				/**< bridge, srcip valid etc. */
	char group[MCASTPA_STRING_SIZE];	/**< ascii string of ip mc group e.g. 224.0.18.101 */
	char srcip[MCASTPA_STRING_SIZE];	/**< ascii string name of video source ip */
	char wan[MCASTPA_STRING_SIZE];	/**< ascii string name of wan video ingress device */
	char lan[MCASTPA_STRING_SIZE];	/**< ascii string names of lan interfaces e.g. lan1 lan2 wifi5g etc */
	char lan_dev[MCASTPA_STRING_SIZE];	/**< ascii string names of lan interfaces that is joined or leaved */
	char srcmac[ETH_ALEN];		/**< source mac address of group subscriber */
};

int pa_init(struct mcastpa_system_init_t *msi);
int pa_join(struct mcastpa_join_leave_t *mjl);
int pa_leave(struct mcastpa_join_leave_t *mjl);
int pa_deinit(struct mcastpa_system_init_t *msi);
