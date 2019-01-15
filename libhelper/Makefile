#
# Copyright (C) 2009 OpenWrt.org
# Copyright (C) 2017 Intel Corporation
#
# Openwrt Makefile for libhelper
#
#

#### Includes ###################################
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

#### Package Info ############################### 
PKG_NAME:=libhelper
PKG_VERSION:=1.4.0.3
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=ff1956b0c768af7efb33e4d8f0d4c880f052d8c9
PKG_SOURCE_INNERDIR:=helper/libhelper
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/$(PKG_NAME).git

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_MAINTAINER:=Intel
PKG_LICENSE:=Intel

include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk
$(call include_mk, ugw-loglevel.mk)

define Package/$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Intel
  SUBMENU:=UGW Framework
  TITLE:=UGW SDK Helper library
  URL:=http://www.intel.com
  MAINTAINER:=Intel Corporation
  DEPENDS:= 
  MENU:=1
endef

define Package/$(PKG_NAME)/description
	UGW SDK Helper Library to define function,prototypes,structs,enums which are
	used for list manipulation and debug purposes.
endef

### Menuconfig ##################################
define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
$(call Package/$(PKG_NAME)/config_debug_level)
$(call config_add_global_debug_level)
	config $(PKG_NAME)_MEM_DEBUG
	depends on PACKAGE_$(PKG_NAME)
		bool "Memory Debug"
		help
		  Memory Debug
endef

TARGET_CFLAGS += $(if $(CONFIG_libugwhelper_MEM_DEBUG),-DMEM_DEBUG)

#### Target Rules ###############################
define Build/Prepare
	$(call Build/Prepare/Default)
	$(INSTALL_DIR) $(STAGING_DIR)/usr/include
	touch $(STAGING_DIR)/usr/include/vendor.h
	echo "#define VENDOR_PATH \"$(VENDOR_PATH)\"" > $(STAGING_DIR)/usr/include/vendor.h
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/include
	$(INSTALL_DIR) $(1)/usr/docs
	$(INSTALL_DIR) $(STAGING_DIR)/mk/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/include/*.h $(1)/usr/include/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/include/*.h $(1)/usr/docs/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libhelper.so $(1)/usr/lib/
	$(INSTALL_DATA) ./files/ugw-loglevel.mk $(STAGING_DIR)/mk/
	$(RM) $(1)/usr/docs/list.h
endef

define Build/UninstallDev
	- rm -f $(1)/usr/lib/libhelper*.*
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libhelper.so $(1)/$(VENDOR_PATH)/usr/lib/
	cd $(1)/usr/lib && rm -f "libhelper.so*" && ln -s "../../$(VENDOR_PATH)/usr/lib/libhelper.so" "libhelper.so"
endef

define Build/Clean
	if [ -d $(PKG_BUILD_DIR) ]; then $(MAKE) -C $(PKG_BUILD_DIR) clean; \
	$(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); fi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
