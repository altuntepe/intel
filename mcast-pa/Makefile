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
  DEPENDS:=@TARGET_intel_mips +libpcap +librt +ip-full +mcproxy
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

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/mcast-pa $(1)/etc/init.d/mcast-pa

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/mcast-pa $(1)/etc/uci-defaults/99-mcast-pa
endef

$(eval $(call BuildPackage,mcast-pa))
