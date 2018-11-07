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
/* Purpose: driver for intel pa mc flows                                     */
/*                                                                           */
/*****************************************************************************/

/**

  @file intel.c
  @author tim.hayes@smartrg.com
  @date Spring 2016
  @brief Intel Multicast Packet Accelerator
  @details Adds and deletes multicast groups to Intel PPA subsystem using ppacmd, mcast_cli or libmcastfapi

 */

#include <mcast-pa.h>

// choose one and only one of these three: 

//#define INTEL_MCAST_USE_PPA 1
//#define INTEL_MCAST_USE_MCAST_CLI 1
#define INTEL_MCAST_USE_MCAST_FAPI 1

// are you sure ? 

#ifdef INTEL_MCAST_USE_PPA
/**
 * @brief inits intel mcast subsystem
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_init(struct mcastpa_system_init_t *msi)
{

	syslog(LOG_NOTICE, "%s:%d \n", __FUNCTION__, __LINE__);
	return (0);
}

/**
 * @brief joins by building a pppacmd and using system call
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_join(struct mcastpa_join_leave_t *mjl)
{
	int len = 0;
	char cmd[128] = { 0 };
	char *lan;
	int bridge = 0;

	if (mjl->flags & MJL_FLAG_BRIDGE)
		bridge = 1;

	syslog(LOG_NOTICE, "%s:%d join request group %s wan %s\n", __FUNCTION__, __LINE__, mjl->group, mjl->wan);
	if (mjl->flags & MJL_FLAG_LAN) {
		syslog(LOG_NOTICE, "%s:%d lan %s\n", __FUNCTION__, __LINE__, mjl->lan);
	}
	len += sprintf(cmd + len, "ppacmd addmc -s %d -g %s -w %s -i %s ", bridge, mjl->group, mjl->wan, mjl->srcip);

	lan = strtok(mjl->lan, " ");
	while (lan != NULL) {
		len += sprintf(cmd + len, "-l %s ", lan);
		lan = strtok(NULL, " ");
	}

	system(cmd);
	syslog(LOG_NOTICE, "%s:%d cmd %s\n", __FUNCTION__, __LINE__, cmd);
	return (0);
}

/**
 * @brief leaves by building a pppacmd and using system call
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_leave(struct mcastpa_join_leave_t *mjl)
{
	int len = 0;
	char cmd[128] = { 0 };
	char *lan;
	int bridge = 0;

	if (mjl->flags & MJL_FLAG_BRIDGE)
		bridge = 1;

	syslog(LOG_NOTICE, "%s:%d leave request group %s wan %s\n", __FUNCTION__, __LINE__, mjl->group, mjl->wan);

	if (mjl->flags & MJL_FLAG_LAN) {
		syslog(LOG_NOTICE, "%s:%d lan %s\n", __FUNCTION__, __LINE__, mjl->lan);
		len += sprintf(cmd + len, "ppacmd addmc -s %d -g %s -w %s -i %s ",
			       bridge, mjl->group, mjl->wan, mjl->srcip);
		lan = strtok(mjl->lan, " ");
		while (lan != NULL) {
			len += sprintf(cmd + len, "-l %s ", lan);
			lan = strtok(NULL, " ");
		}
	} else {
		len += sprintf(cmd + len, "ppacmd addmc -g %s ", mjl->group);
	}

	system(cmd);
	syslog(LOG_NOTICE, "%s:%d cmd %s\n", __FUNCTION__, __LINE__, cmd);
	return (0);
}

/**
 * @brief de-inits intel mcast subsystem
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_deinit(struct mcastpa_system_init_t *msi)
{

	syslog(LOG_NOTICE, "%s:%d \n", __FUNCTION__, __LINE__);
	return (0);
}

#endif				// INTEL_MCAST_USE_PPA

#ifdef INTEL_MCAST_USE_MCAST_CLI
#define MCAST_CLI "/opt/lantiq/usr/sbin/mcast_cli"
/**
 * @brief inits intel mcast_cli subsystem
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_init(struct mcastpa_system_init_t *msi)
{
	int len = 0;
	char cmd[128] = { 0 };

	syslog(LOG_NOTICE, "%s:%d \n", __FUNCTION__, __LINE__);

	len += sprintf(cmd + len, "%s -O INIT \n", MCAST_CLI);

	system(cmd);
	syslog(LOG_NOTICE, "%s:%d cmd %s\n", __FUNCTION__, __LINE__, cmd);
	return (0);

}

/**
 * @brief joins by building a mcast_cli and using system call
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_join(struct mcastpa_join_leave_t *mjl)
{
	int len = 0;
	char cmd[128] = { 0 };

	syslog(LOG_NOTICE, "%s:%d join request group %s wan %s\n", __FUNCTION__, __LINE__, mjl->group, mjl->wan);

	len += sprintf(cmd + len, "%s -O ADD -G %s -R %s -S %s -I %s \n", MCAST_CLI,
		       mjl->group, mjl->wan, mjl->srcip, mjl->lan_dev);

	system(cmd);
	syslog(LOG_NOTICE, "%s:%d cmd %s\n", __FUNCTION__, __LINE__, cmd);
	return (0);
}

/**
 * @brief leaves by building a mcast_cli and using system call
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_leave(struct mcastpa_join_leave_t *mjl)
{
	int len = 0;
	char cmd[128] = { 0 };

	syslog(LOG_NOTICE, "%s:%d join request group %s wan %s\n", __FUNCTION__, __LINE__, mjl->group, mjl->wan);

	len += sprintf(cmd + len, "%s -O DEL -G %s -R %s -S %s -I %s \n", MCAST_CLI,
		       mjl->group, mjl->wan, mjl->srcip, mjl->lan_dev);

	system(cmd);
	syslog(LOG_NOTICE, "%s:%d cmd %s\n", __FUNCTION__, __LINE__, cmd);
	return (0);
}

/**
 * @brief de-inits intel mcast subsystem
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_deinit(struct mcastpa_system_init_t *msi)
{
	int len = 0;
	char cmd[128] = { 0 };

	if (1)
		return (0);

	syslog(LOG_NOTICE, "%s:%d \n", __FUNCTION__, __LINE__);

	len += sprintf(cmd + len, "%s -O UNINIT \n", MCAST_CLI);

	system(cmd);
	syslog(LOG_NOTICE, "%s:%d cmd %s\n", __FUNCTION__, __LINE__, cmd);
	return (0);
}

#endif				// INTEL_MCAST_USE_MCAST_CLI

#ifdef INTEL_MCAST_USE_MCAST_FAPI
#include <arpa/inet.h>
#include <linux/if.h>
#include <mcast/fapi_mcast.h>
#define MCAST_HELPER_DEV_MAJOR_NUM  240
#define MCAST_HELPER_DEVICE	"/dev/mcast"
#define MCAST_HELPER_DEV_MINOR_NUM  0

/**
 * @brief inits intel mcast_helper module
 * @details from fapi_mcast.c (libmcastfapi) - a subset without igmp, iptables init ...
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
fapi_mch_init_sos(void)
{
	int ret = 0;
	uint32_t devNo = 0;
	uint32_t majorNo = MCAST_HELPER_DEV_MAJOR_NUM;
	uint32_t minorNo = MCAST_HELPER_DEV_MINOR_NUM;

	system("modprobe mcast_helper.ko");

	sleep(1);

	devNo = majorNo << 8;
	devNo |= minorNo;

	if (mknod(MCAST_HELPER_DEVICE, S_IFCHR | 0666, devNo)) {
		ret = -1;
	}

	return ret;
}

/**
 * @brief inits intel mcast fapi subsystem
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_init_sos(struct mcastpa_system_init_t *msi)
{
	int res = 0;
	res = fapi_mch_init_sos();
	syslog(LOG_NOTICE, "%s:%d res %d\n", __FUNCTION__, __LINE__, res);
	return (res);
}

/**
 * @brief inits intel mcast fapi subsystem using fapi_mcast.c (libmcastfapi)
 * @details 
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_init(struct mcastpa_system_init_t *msi)
{
	int res = 0;
#if 0
	res = fapi_mch_init();
#endif
#if 1
	res = fapi_mch_init_sos();
#endif

	syslog(LOG_NOTICE, "%s:%d res %d\n", __FUNCTION__, __LINE__, res);
	return (res);
}

/**
 * @brief joins by libmcastfapi call
 * @details first group join is add additions are updates
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_join(struct mcastpa_join_leave_t *mjl)
{
	int res = 0;
	MCAST_MEMBER_t xmcastcfg;

	memset(&xmcastcfg, 0, sizeof (xmcastcfg));
	xmcastcfg.groupIP.type = IPV4;
	res = inet_pton(AF_INET, (const char *) mjl->group, &(xmcastcfg.groupIP.addr.ip4.s_addr));

	strncpy(xmcastcfg.rxIntfName, mjl->wan, IFNAMSIZ);
	strncpy(xmcastcfg.intfName, mjl->lan_dev, IFNAMSIZ);
	memcpy(xmcastcfg.macaddr,mjl->srcmac, ETH_ALEN);

	if (strlen(mjl->srcip) > 4) {
		xmcastcfg.srcIP.type = IPV4;
		inet_pton(AF_INET, (const char *) mjl->srcip, &(xmcastcfg.srcIP.addr.ip4.s_addr));
	}
	if (mjl->flags & MJL_FLAG_UPDATE) {
		res = fapi_mch_update_entry(&xmcastcfg);
		syslog(LOG_NOTICE, "%s:%d join update group %s wan %s lan %s src %s res %d\n", __FUNCTION__, __LINE__,
		       mjl->group, mjl->wan, mjl->lan_dev, mjl->srcip, res);
	} else {
		res = fapi_mch_add_entry(&xmcastcfg);
		syslog(LOG_NOTICE, "%s:%d join new group %s wan %s lan %s src %s res %d\n", __FUNCTION__, __LINE__,
		       mjl->group, mjl->wan, mjl->lan_dev, mjl->srcip, res);
	}
	if ( mjl->flags & MJL_FLAG_BRIDGE ) {
		static int count=0;
		count++;
		/* on startup in bridge mode we can't process these things back to back */
		if (count < 12) {
			sleep(1);
			syslog(LOG_NOTICE, "%s:%d sleeping after join count %d\n", __FUNCTION__, __LINE__,count);
		}
	}
	return (res);
}

/**
 * @brief leaves by libmcastfapi call
 * @details all group leaves are deletes no matter how many members
 * @note
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_leave(struct mcastpa_join_leave_t *mjl)
{
	int res;
	MCAST_MEMBER_t xmcastcfg;

	memset(&xmcastcfg, 0, sizeof (xmcastcfg));
	xmcastcfg.groupIP.type = IPV4;
	inet_pton(AF_INET, mjl->group, &(xmcastcfg.groupIP.addr.ip4.s_addr));
	strncpy(xmcastcfg.rxIntfName, mjl->wan, IFNAMSIZ);
	strncpy(xmcastcfg.intfName, mjl->lan_dev, IFNAMSIZ);
	memcpy(xmcastcfg.macaddr,mjl->srcmac, ETH_ALEN);
	xmcastcfg.srcIP.type = IPV4;
	inet_pton(AF_INET, mjl->srcip, &(xmcastcfg.srcIP.addr.ip4.s_addr));
	res = fapi_mch_del_entry(&xmcastcfg);
	syslog(LOG_NOTICE, "%s:%d leave group %s wan %s lan %s src %s res %d\n", __FUNCTION__, __LINE__, mjl->group,
	       mjl->wan, mjl->lan_dev, mjl->srcip, res);
	return (res);
}

/**
 * @brief de-inits intel mcast subsystem
 * @details not used because it unload the module
 * @note 
 * @todo flush entries 
 * @author tim.hayes@smartrg.com
 * @callgraph
 * @callergraph
 */
int
pa_deinit(struct mcastpa_system_init_t *msi)
{
	int res = 0;
//      res = fapi_mch_uninit();
	system("rmmod mcast_helper");
	syslog(LOG_NOTICE, "%s:%d res %d\n", __FUNCTION__, __LINE__, res);
	return (res);
}

#endif				// INTEL_MCAST_USE_MCAST_FAPI
