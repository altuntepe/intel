#
# Copyright (C) 2017 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk


PKG_NAME:=dsl-cpe-control-vrx
PKG_VERSION:=4.20.1.2.0
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=5e45d5fbfa5dd2a93a888b53ae811cafa59dab4b
#PKG_MD5SUM:=85d293ee43f01ba367301a7fe7c46156
PKG_RELEASE:=1
PKG_BASE_NAME:=dsl_cpe_control_vrx
PKG_SOURCE:=$(PKG_BASE_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
#PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/dsl_cpe_control-$(PKG_VERSION)
#PKG_SOURCE_URL:=http://localhost
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/$(PKG_BASE_NAME).git

DSL_BIN_DIR=$(VENDOR_PATH)/bin
DSL_INITD_DIR=$(VENDOR_PATH)/etc/init.d
DSL_FW_DIR=$(VENDOR_PATH)/firmware

ifeq (y,$(CONFIG_dsl-cpe-mei-vrx_DTM_STANDALONE))
	STARTSEQ = 22
endif

PKG_FIXUP:=autoreconf

include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk
#include $(INCLUDE_DIR)/ugw-loglevel.mk
$(call include_mk, ugw-loglevel.mk)

# Get config values from general image config or other packages in dependency list
# Definition of these values will be overtaken from package 'dsl-cpe-mei-vrx'

DSL_NETLINK_ID=$(strip $(subst ",, $(CONFIG_dsl-cpe-mei-vrx_DSL_NETLINK_ID)))

ifeq ($(CONFIG_LTQ_CLI),)
CONFIG_LTQ_CLI=y
endif

ifeq ($(DSL_NETLINK_ID),)
	DSL_NETLINK_ID=28
endif

ifeq ($(DUMP),)
	STAMP_CONFIGURED:=$(strip $(STAMP_CONFIGURED))_$(shell $(SH_FUNC) ( \
		grep '^CONFIG_$(PKG_NAME)' $(TOPDIR)/.config; \
		grep '^CONFIG_DSL_' $(TOPDIR)/.config; \
		grep '^CONFIG_VRX_' $(TOPDIR)/.config; \
		grep '^CONFIG_VRX320_' $(TOPDIR)/.config; \
		grep '^CONFIG_$(PKG_NAME)_DTM_' $(TOPDIR)/.config; \
		grep '^CONFIG_PTM_VECTORING' $(LINUX_DIR)/.config) | md5s)
endif

define Package/dsl-cpe-control
	SECTION:=application
	CATEGORY:=Lantiq
	SUBMENU:=DSL Subsystem
	TITLE:=DSL CPE control application for VRX Family
	URL:=http://www.lantiq.com/
	MAINTAINER:=Lantiq Beteiligungs-GmbH & Co. KG
	PROVIDES:=dsl-cpe-control
	DEPENDS:= +libugwhelper
	MENU:=1
endef

define Package/dsl-cpe-control/description
	Lantiq DSL CPE for Amazon SE, Danube,Vinax and VRx.
endef

define Package/$(PKG_NAME)
	$(call Package/dsl-cpe-control)
	DEPENDS:= +dsl-cpe-api-vrx +libpthread +librt +lib-dti +(LANTIQ_OPENWRT_FIRMWARE):libscapi
endef

define Package/$(PKG_NAME)/description
	This package contains the DSL CPE control application.

	Supported Devices:
		- VRX200 Family
		- VRX300 Family
endef

define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
source "$(SOURCE)/Config.in"
endef

CONFIGURE_ARGS += \
	--enable-vrx \
	--enable-driver-include="-I$(STAGING_DIR)/usr/include/drv_dsl_cpe_api" \
	--enable-device-driver-include="-I$(STAGING_DIR)/usr/include" \
	--enable-ifxos \
	--enable-ifxos-include="-I$(STAGING_DIR)/usr/include/ifxos" \
	--enable-ifxos-library="-I$(STAGING_DIR)/usr/lib" \
	--enable-dsl-ceoc=no

ifdef CONFIG_dsl-cpe-mei-vrx_DSL_NETLINK_ID
	CONFIGURE_ARGS += \
	--enable-debug-logger-support \
	--with-dbg-netlink-id="$(DSL_NETLINK_ID)"
endif

ifeq ($(CONFIG_dsl-cpe-control-vrx_DTI),y)
CONFIGURE_ARGS += \
	--enable-dti=yes
CONFIGURE_ARGS += \
	--enable-dti-include="-I$(STAGING_DIR)/usr/include/dti" \
	--enable-dti-library="-L$(STAGING_DIR)/usr/lib"
endif

ifeq ($(CONFIG_LTQ_CLI),y)
CONFIGURE_ARGS += \
	--enable-cli-support
endif

# Add underscore at the end to keep backward-compatibility
MODEL_NAME += $(CONFIG_BUILD_SUFFIX)_

ifeq ($(CONFIG_dsl-cpe-mei-vrx_DEVICE_VR9),y)
	CONFIGURE_ARGS += --enable-vrx-device=vr9
else ifeq ($(CONFIG_dsl-cpe-mei-vrx_DEVICE_VR10),y)
	CONFIGURE_ARGS += --enable-vrx-device=vr10
else ifeq ($(CONFIG_dsl-cpe-mei-vrx_DEVICE_VR10_320),y)
	CONFIGURE_ARGS += --enable-vrx-device=vr10_320
else
	CONFIGURE_ARGS += --enable-vrx-device=vr9
endif

# Default number of pipes used for CLI communication
NUM_PIPES:=1
ifeq ($(CONFIG_$(PKG_NAME)_MODEL_LITE),y)
	CONFIGURE_ARGS += --enable-model=lite
	APP_BILD_MODEL="lite"
else ifeq ($(CONFIG_$(PKG_NAME)_MODEL_FOOTPRINT),y)
	CONFIGURE_ARGS += --enable-model=footprint
	APP_BILD_MODEL="footprint"
else ifeq ($(CONFIG_$(PKG_NAME)_MODEL_TYPICAL),y)
	CONFIGURE_ARGS += --enable-model=typical
	APP_BILD_MODEL="typical"
else ifeq ($(CONFIG_$(PKG_NAME)_MODEL_FULL),y)
	CONFIGURE_ARGS += --enable-model=full
	APP_BILD_MODEL="full"
else ifeq ($(CONFIG_$(PKG_NAME)_MODEL_DEBUG),y)
	CONFIGURE_ARGS += --enable-model=debug
	# In case of debug compilation number of pipes is increased
	NUM_PIPES:=2
	APP_BILD_MODEL="debug"
else
	CONFIGURE_ARGS += --enable-model=footprint
	APP_BILD_MODEL="footprint"
endif

CONFIGURE_ARGS += --enable-add-appl-cflags="-DMAX_CLI_PIPES=$(NUM_PIPES)"

ifeq ($(CONFIG_$(PKG_NAME)_USE_ADDITIONAL_BUILD_OPTIONS),y)
	CONFIGURE_ARGS += $(CONFIG_$(PKG_NAME)_ADDITIONAL_BUILD_OPTIONS)
endif

ifeq ($(CONFIG_$(PKG_NAME)_USE_DSL_ADD_EXT_APPL_CFLAGS),y)
CONFIGURE_ARGS += --enable-add_ext_appl_cflags=$(CONFIG_$(PKG_NAME)_DSL_ADD_EXT_APPL_CFLAGS)
endif

ifdef CONFIG_PACKAGE_dsl-cpe-dti-agent
CONFIGURE_ARGS += --enable-dti-agent-st-alone-support
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

define Package/$(PKG_NAME)/install

	$(INSTALL_DIR) $(1)/$(DSL_INITD_DIR)
	$(INSTALL_BIN) ./files/ltq_dsl_fw_dbg.sh $(1)/$(DSL_INITD_DIR)
	$(SED) "s:@dsl_bin_dir@:$(DSL_BIN_DIR):g" $(1)/$(DSL_INITD_DIR)/ltq_dsl_fw_dbg.sh
	$(SED) "s:@dsl_fw_dir@:$(DSL_FW_DIR):g" $(1)/$(DSL_INITD_DIR)/ltq_dsl_fw_dbg.sh

	$(INSTALL_BIN) ./files/ltq_cpe_control_init.sh $(1)/$(DSL_INITD_DIR)
	$(SED) "s:@dsl_bin_dir@:$(DSL_BIN_DIR):g" $(1)/$(DSL_INITD_DIR)/ltq_cpe_control_init.sh
	$(SED) "s:@dsl_fw_dir@:$(DSL_FW_DIR):g" $(1)/$(DSL_INITD_DIR)/ltq_cpe_control_init.sh
	$(SED) "s:@model_name@:$(MODEL_NAME):g" $(1)/$(DSL_INITD_DIR)/ltq_cpe_control_init.sh

ifneq (y,$(CONFIG_NEW_FRAMEWORK))
ifeq (y,$(CONFIG_dsl-cpe-mei-vrx_DTM_STANDALONE))
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ltq_cpe_control_init_standalone.sh $(1)/etc/init.d/
	$(SED) "s:@dsl_init_dir@:$(DSL_INITD_DIR):g" $(1)/etc/init.d/ltq_cpe_control_init_standalone.sh
	$(SED) "s:@start_seq@:$(STARTSEQ):g" $(1)/etc/init.d/ltq_cpe_control_init_standalone.sh
endif
endif

	$(INSTALL_DIR) $(1)/etc/profile.d
	$(INSTALL_BIN) ./files/alias_dsl_cpe.sh $(1)/etc/profile.d/
	$(SED) "s:@dsl_bin_dir@:$(DSL_BIN_DIR):g" $(1)/etc/profile.d/alias_dsl_cpe.sh

	$(INSTALL_DIR) $(1)/$(DSL_BIN_DIR)

ifeq ($(DSL_LINES_PER_DEVICE),1)
	$(INSTALL_DATA) ./files/adsl.scr $(1)/$(DSL_BIN_DIR)
	$(INSTALL_DATA) ./files/vdsl.scr $(1)/$(DSL_BIN_DIR)
else
	$(INSTALL_DATA) ./files/adsl_bonding.scr $(1)/$(DSL_BIN_DIR)/adsl.scr
	$(INSTALL_DATA) ./files/vdsl_bonding.scr $(1)/$(DSL_BIN_DIR)/vdsl.scr
endif

	# Copy configuration files to rootfs
	@- [ -e ./files/dsl_auto_app.cfg ] && $(INSTALL_DATA) ./files/dsl_auto_app.cfg $(1)/$(DSL_BIN_DIR)

	# Set common variables within DSL config file
	$(SED) "s:@num_dsl_pipes@:$(NUM_PIPES):g" $(1)/$(DSL_BIN_DIR)/dsl_auto_app.cfg;
	$(SED) "s:@app_build_model@:$(APP_BILD_MODEL):g" $(1)/$(DSL_BIN_DIR)/dsl_auto_app.cfg;

	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/dsl_cpe_control $(1)/$(DSL_BIN_DIR)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tools/pipe/dsl_cpe_pipe $(1)/$(DSL_BIN_DIR)
	ln -snf dsl_cpe_pipe $(1)/$(DSL_BIN_DIR)/dsl_cpe_pipe.sh

	$(if $(CONFIG_LANTIQ_OPENWRT_FIRMWARE), \
                $(INSTALL_DIR) $(1)/etc/init.d/; \
                $(INSTALL_BIN) ./files/xdsl.init $(1)/etc/init.d/xdsl; \
                $(SED) "s:@dsl_bin_dir@:$(DSL_BIN_DIR):g" $(1)/etc/init.d/xdsl; \
                $(SED) "s:@dsl_dir@:$(VENDOR_PATH):g" $(1)/etc/init.d/xdsl; \
        )
endef

define Package/$(PKG_NAME)/postinst
        #!/bin/sh
        $(if $(CONFIG_LANTIQ_OPENWRT_FIRMWARE), \
        if [ -z "$${IPKG_INSTROOT}" ]; then \
                /etc/init.d/xdsl enable; \
        fi; \
        )
        exit 0
endef

define Package/$(PKG_NAME)/prerm
        #!/bin/sh
        $(if $(CONFIG_LANTIQ_OPENWRT_FIRMWARE), \
        if [ -z "$${IPKG_INSTROOT}" ]; then \
                /etc/init.d/xdsl disable; \
                /etc/init.d/xdsl stop; \
        fi; \
        )
        exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
