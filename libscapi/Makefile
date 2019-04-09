#
# Copyright (C) 2009 OpenWrt.org
# Copyright (C) 2018 Intel Corporation
# Copyright (C) 2017-2018 Intel Corporation
#
# Openwrt Makefile for libscapi
#
#

#### Includes ###################################
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

#### Package Info ############################### 
PKG_NAME:=libscapi
PKG_VERSION:=1.5.1.4
PKG_SOURCE_VERSION:=dfd4ee90f6578ad4a2db3ae432277a377c8544f2
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/$(PKG_NAME).git

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Intel
PKG_LICENSE:=LGPL2.1

include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk
$(call include_mk, ugw-loglevel.mk)

define Package/$(PKG_NAME)
  SECTION:=lib
  CATEGORY:=Intel
  SUBMENU:=UGW Framework
  TITLE:=UGW Framework System Configuration APIs
  URL:=http://www.intel.com
  MAINTAINER:=Intel Corporation
  DEPENDS:= +libhelper
  MENU:=1
endef

define Package/$(PKG_NAME)/description
	UGW Framework System Configuration APIs
endef

### Menuconfig ##################################
define Package/$(PKG_NAME)/config
	$(call Package/$(PKG_NAME)/override_version)
	$(call Package/$(PKG_NAME)/override_source_path)
	$(call Package/$(PKG_NAME)/config_debug_level)
	menu "$(PKG_NAME) features"
	depends on PACKAGE_$(PKG_NAME)
        source "$(SOURCE)/config/Config.in"
        endmenu
endef
#export $(PKG_CONFIG_DEPENDS)

ifeq ($(CONFIG_USE_MUSL),y)
  TARGET_CFLAGS += -DCONFIG_USE_MUSL
endif

#### Target Rules ###############################
define Build/Prepare
	$(call Build/Prepare/Default)
	$(if $(CONFIG_$(PKG_NAME)_USE_CUSTOM_SOURCE_DIR),,./files/interface_config.sh $(TOPDIR)/.config $(PKG_BUILD_DIR)/interfaces.cfg)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/*.so $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/include/*.h $(1)/usr/include
	$(INSTALL_DIR) $(1)/usr/docs
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/include/scapi_proto.h $(1)/usr/docs/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/include/ugw_error.h $(1)/usr/docs/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/include/ulogging.h $(1)/usr/docs/
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mem $(1)/usr/sbin/ 
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/utils/scapiutil $(1)/usr/sbin/ 
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/etc/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/interfaces.cfg $(1)/$(VENDOR_PATH)/etc/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/*.so $(1)/usr/lib
	$(if $(CONFIG_TARGET_x86), \
		$(INSTALL_DIR) $(1)/lib/preinit; \
		$(INSTALL_BIN) ./files/scapi_utils.sh $(1)/lib/preinit/; \
	,\
		$(INSTALL_DIR) $(1)/etc/preinit.d; \
		$(INSTALL_BIN) ./files/scapi_utils.sh $(1)/etc/preinit.d/; \
		$(SED) 's/.*boot_hook_add.*preinit.*/scapi_utils_init/g' $(1)/etc/preinit.d/scapi_utils.sh; \
	)
endef

define Build/Clean
	if [ -d $(PKG_BUILD_DIR) ]; then $(MAKE) -C $(PKG_BUILD_DIR) clean; \
	$(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); fi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
