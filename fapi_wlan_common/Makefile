#
# Openwrt Makefile for fapi_wlan_common
#

#### Includes ###################################
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

#### Package Info ############################### 
PKG_NAME:=fapi_wlan_common
PKG_VERSION:=05.04.02.50
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/fapi_wlan_common.git
PKG_SOURCE_VERSION:=aca66d02e57a0cbaf573ecbadda35773a22445ed
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk
$(call include_mk, ugw-loglevel.mk)

PKG_BUILD_DEPENDS:=+PACKAGE_ltq-wlan-wave_5_x:hostapd_wave PACKAGE_safeclibs

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Intel
  SUBMENU:=UGW Functional APIs
  TITLE:=Intel WLAN Common FAPI
  URL:=http://www.intel.com
  MAINTAINER:=Intel Corporation
  DEPENDS:= +libhelper +libncurses +libreadline +librt +hostapd_wave +libsafec
  MENU:=1
endef

define Package/$(PKG_NAME)/description
	Intel Common FAPI layer
endef

ifneq ($(CONFIG_PACKAGE_ltq-wlan-wave_5_x),)
export COMMON_WAVE_BUILD = $(CONFIG_PACKAGE_ltq-wlan-wave_5_x)
endif

### Menuconfig ##################################
define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
$(call Package/$(PKG_NAME)/config_debug_level)
endef

#### Target Rules ###############################
define Build/Prepare
	$(call Build/Prepare/Default)

	$(eval THISPATH=$(shell pwd))
	$(eval INXML=$(shell pwd)/../feed_sl_wlan/files/db_xml)
	$(if $(CONFIG_PACKAGE_servd),, \
#		cd $(PKG_BUILD_DIR)/; $(PKG_BUILD_DIR)/scripts/fapi_wlan_wave_createDB.sh -x $(INXML) -b $(PKG_BUILD_DIR)/scripts ; cd -; \
	)
endef

# To ipkg / Rootfs
define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/sbin
#	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/wave/scripts/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libfapiwlancommon.so $(1)/usr/lib/
ifneq ($(COMMON_WAVE_BUILD),)
#	$(INSTALL_BIN) $(PKG_BUILD_DIR)/fapi_wlan_daemon $(1)/usr/lib/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/fapi_wlan_debug_cli $(1)/usr/sbin
#	$(INSTALL_BIN) $(PKG_BUILD_DIR)/fapi_wlan_cli $(1)/usr/sbin
#	$(INSTALL_BIN) $(PKG_BUILD_DIR)/fapi_wlan_dbXml $(1)/usr/sbin/
#	$(CP) $(PKG_BUILD_DIR)/scripts/fapi_wlan_wave_createDB.sh $(1)/$(VENDOR_PATH)/wave/scripts/
	chmod 555 $(1)/usr/sbin/fapi_wlan_debug_cli

#	$(if $(CONFIG_PACKAGE_servd),, \
#		$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/wave/db/ ; \
#		$(CP) $(PKG_BUILD_DIR)/output $(1)/$(VENDOR_PATH)/wave/db/default ; \
#	)
endif
	$(INSTALL_DIR) $(STAGING_DIR)/usr/docs
	$(CP) $(PKG_BUILD_DIR)/include/fapi_wlan.h $(STAGING_DIR)/usr/docs/.
#ifeq ($(CONFIG_LANTIQ_OPENWRT_FIRMWARE),y)
#	$(INSTALL_DIR) $(1)/lib
#	$(INSTALL_DIR) $(1)/etc/init.d
#	$(CP) ./files/openwrt/etc/init.d/*  $(1)/etc/init.d/
#	$(CP) ./files/openwrt/lib/wifi  $(1)/lib
#endif
endef

define Build/Clean
	if [ -d $(PKG_BUILD_DIR) ]; then $(MAKE) -C $(PKG_BUILD_DIR) clean; \
	$(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); fi
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libfapiwlancommon.so $(1)/usr/lib/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/include/*.h $(1)/usr/include/
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/*.h $(1)/usr/include/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
