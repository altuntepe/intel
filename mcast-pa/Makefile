###############################################################################
#               _____                      _  ______ _____                    #
#              /  ___|                    | | | ___ \  __ \                   #
#              \ `--. _ __ ___   __ _ _ __| |_| |_/ / |  \/                   #
#               `--. \ '_ ` _ \ / _` | '__| __|    /| | __                    #
#              /\__/ / | | | | | (_| | |  | |_| |\ \| |_\ \                   #
#              \____/|_| |_| |_|\__,_|_|   \__\_| \_|\____/ Inc.              #
#                                                                             #
###############################################################################
#                                                                             #
#                       copyright 2018 by SmartRG, Inc.                       #
#                              Santa Barbara, CA                              #
#                                                                             #
###############################################################################
#                                                                             #
# Author: tim.hayes@smartrg.com                                               #
#                                                                             #
# Purpose: Multicast packet accelerator manager                               #
#                                                                             #
###############################################################################
include $(TOPDIR)/rules.mk

PKG_NAME:=mcast-pa
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/mcast-pa

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/mcast-pa
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Multicast Packet Accelerator
  DEPENDS:=+libpcap +librt +ip-full +mcproxy
endef

define Package/mcast-pa/description
 This package contains a daemon that pushes and pulls mcast groups in Packet Accellerator (Intel)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
# we must local src this because it is patched and STAGING_DIR does not have the patch result
	$(CP) $(LINUX_DIR)/include/uapi/linux/if_bridge.h $(PKG_BUILD_DIR)
endef

define Package/mcast-pa/install
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mcast-pa $(1)/sbin/

	$(INSTALL_DIR) $(1)/usr/prpl/scripts
	$(CP) ./files/usr/prpl/scripts $(1)/usr/prpl/scripts/.

##
# install iptv scripts from here now too
#
# NOTE: these should probably be in their own package
##
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/iptv $(1)/etc/init.d/.

# HACK / FIXME - don't do this! make a uci-default instead
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_BIN) ./files/etc/config/iptv $(1)/etc/config/.

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/etc/hotplug.d/iface/60-iptv $(1)/etc/hotplug.d/iface/.
endef

$(eval $(call BuildPackage,mcast-pa))
