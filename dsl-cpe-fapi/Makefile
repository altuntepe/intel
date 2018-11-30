#
# Copyright (C) 2017 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=dsl-cpe-fapi
PKG_VERSION:=0.6.1
#PKG_MD5SUM:=4d24f6163e6c2ba53222872bf7019198
PKG_BASE_NAME:=$(PKG_NAME)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=8c578787c4c7a578822b3381d69b4ccae817185e
PKG_SOURCE:=$(PKG_BASE_NAME)-$(PKG_VERSION).tar.gz
PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_BASE_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/$(PKG_NAME).git

LANTIQ_BIN_DIR=/$(VENDOR_PATH)/bin

PKG_FIXUP:=autoreconf
PKG_FIXUP:=libtool
PKG_INSTALL:=1

-include $(INCLUDE_DIR)/package-version-override.mk
include $(INCLUDE_DIR)/package.mk

ifeq ($(findstring intel,$(VENDOR_PATH)),intel)
#UGW8 onwards
$(call include_mk, ugw-loglevel.mk)
else
-include $(INCLUDE_DIR)/ugw-loglevel.mk
endif

# Get config values from general image config or other packages in dependency list
# Definition of these values will be overtaken from package 'dsl-cpe-mei-vrx'

# Set default config values if necessary (not defined before)

define Package/$(PKG_NAME)
	CATEGORY:=Lantiq
	SUBMENU:=DSL Subsystem
	TITLE:=DSL CPE FAPI shared lib
	URL:=http://www.lantiq.com/
	MAINTAINER:=Lantiq Beteiligungs-GmbH & Co. KG
	DEPENDS:= +libugwhelper +libpthread +librt +lib-cli +dsl-cpe-control-vrx +libscapi +system_fapi
	MENU:=1
endef

define Package/$(PKG_NAME)/description
	This package contains the DSL CPE FAPI.
endef

define Package/$(PKG_NAME)/config
    $(call Package/$(PKG_NAME)/override_version)
    $(call Package/$(PKG_NAME)/override_source_path)
    $(call Package/$(PKG_NAME)/config_debug_level)
	source "$(SOURCE)/Config.in"
endef

CONFIGURE_ARGS += \
	--enable-vrx \
	--enable-driver-include="-I$(STAGING_DIR)/usr/include/drv_dsl_cpe_api" \
	--enable-ifxos-include="-I$(STAGING_DIR)/usr/include/ifxos" \
	--enable-ifxos-library="-L$(STAGING_DIR)/usr/lib" \
	--enable-dsl-fapi-include="-I$(STAGING_DIR)/usr/include/dsl-fapi" \
	--enable-dsl-fapi-library="-L$(STAGING_DIR)/usr/lib" \
	--enable-cli \
	--enable-cli-include="-I$(STAGING_DIR)/usr/include/cli" \
	--enable-cli-library="-L$(STAGING_DIR)/usr/lib"	\

ifeq ($(CONFIG_dsl-cpe-fapi_FAPI_DAEMON),y)
CONFIGURE_ARGS += --enable-dsl-fapi-daemon=yes
else
CONFIGURE_ARGS += --enable-dsl-fapi-daemon=no
endif

TARGET_CFLAGS += -I$(LINUX_DIR)/user_headers/include/net/ -I$(LINUX_DIR)/user_headers/include/ -I$(LINUX_DIR)/include/

ifeq ($(CONFIG_USE_MUSL),y)
TARGET_CFLAGS += -DCONFIG_USE_MUSL
endif

define Build/Configure
	# remove "configured" stamps of other configs
	@- rm $(PKG_BUILD_DIR)/.configured*
	$(call Build/Configure/Default)
endef

define Build/Clean
	@- rm -Rf $(PKG_BUILD_DIR)/ipkg*
	@- [ -e $(PKG_BUILD_DIR)/Makefile ] && $(MAKE) -C $(PKG_BUILD_DIR) clean
	$(call Build/Clean/Default)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/{lib,include/dsl-fapi}
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/include/* $(1)/usr/include/dsl-fapi
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/dsl_fapi_config.h $(1)/usr/include/dsl-fapi
	mkdir -p $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/lib/*.{a,la,so*} $(1)/usr/lib/
endef

define Build/UninstallDev
	- rm -f $(1)/usr/lib/libdslfapi*.*
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib
	cd $(1)/usr/lib && rm -f "libdslfapi.so.0" && ln -s "../../$(VENDOR_PATH)/usr/lib/libdslfapi.so" "libdslfapi.so.0"
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/usr/lib
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/lib/libdslfapi.so $(1)/$(VENDOR_PATH)/usr/lib/
	$(INSTALL_DIR) $(1)/$(LANTIQ_BIN_DIR)
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/dsl_fapid $(1)/$(LANTIQ_BIN_DIR)
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/dsl_fapi_pipe.sh $(1)/$(LANTIQ_BIN_DIR)
	$(INSTALL_BIN) ./files/dsl_fapi.cfg $(1)/$(LANTIQ_BIN_DIR)
	$(INSTALL_DIR) $(STAGING_DIR)/usr/docs
	$(CP) $(PKG_BUILD_DIR)/include/dsl_fapi.h $(STAGING_DIR)/usr/docs/.
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
