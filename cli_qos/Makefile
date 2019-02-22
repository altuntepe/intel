#
# Copyright (C) 2009 OpenWrt.org
# Copyright (C) 2017 Intel Corporation
#
# Openwrt Makefile for qoscli
#
#

#### Includes ###################################
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

#### Package Info ###############################
PKG_NAME:=qoscli
PKG_VERSION:=1.0.2.1
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=ssh://git@gts-chd.intel.com:29418/sw_ugw/qos_service.git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=9098835145310785fb402f21b716d91fa259597f
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_MAINTAINER:=Intel

PKG_LICENSE:=Intel
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_DEFAULT_CUSTOM_SOURCE_DIR:=$(shell pwd)/src


include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/package-version-override.mk
$(call include_mk, ugw-loglevel.mk)

ifeq ($(CONFIG_FEATURE_HOST_ENVIR),y)
  include $(INCLUDE_DIR)/host-build.mk
endif

define Package/$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Intel
  SUBMENU:=UGW Functional APIs
  TITLE:=UGW QoS FAPI CLI
  URL:=http://www.intel.com
  MAINTAINER:=Intel Corporation
  DEPENDS:= +fapi_qos +libhelper +libsafec
  MENU:=1
endef

define Package/$(PKG_NAME)/description
  Intel UGW QoS FAPI CLI
endef

### Menuconfig ##################################
define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
endef

ifeq ($(CONFIG_TARGET_lantiq_xrx200),y)
        IFX_CFLAGS_y +=-DPLATFORM_XRX288
endif
ifeq ($(CONFIG_TARGET_lantiq_xrx330),y)
        IFX_CFLAGS_y +=-DPLATFORM_XRX330
  export PLATFORM_XRX330=1
endif
ifeq ($(CONFIG_TARGET_lantiq_xrx300),y)
        IFX_CFLAGS_y +=-DPLATFORM_XRX300
endif
ifeq ($(CONFIG_TARGET_intel_mips_xrx500),y)
  export PLATFORM_XRX500=1
  IFX_CFLAGS_y +=-DPLATFORM_XRX500
endif
ifeq ($(CONFIG_TARGET_x86_puma),y)
  export PLATFORM_PUMA=1
  IFX_CFLAGS_y +=-DPLATFORM_PUMA
ifeq ($(CONFIG_PACKAGE_kmod-lan_port_separation),y)
  export ENABLE_LAN_PORT_SEPARATION=1
  IFX_CFLAGS_y +=-DENABLE_LAN_PORT_SEPARATION
endif
endif
IFX_CFLAGS_y +=-DPLATFORM_XML='\"$(VENDOR_PATH)\"'
IFX_CFLAGS:=$(IFX_CFLAGS_y) -I$(STAGING_DIR)/usr/include
TARGET_CFLAGS += $(IFX_CFLAGS) -I$(STAGING_DIR)/usr/include/qosfapi
TARGET_LDFLAGS += -L$(STAGING_DIR)/usr/lib/qosfapi
CFLAGS="$(TARGET_CFLAGS) "

ifeq ($(CONFIG_LANTIQ_OPENWRT_FIRMWARE),y)
	EXTRA_CFLAGS += -DCONFIG_LANTIQ_OPENWRT
endif


MAKE_PATH:=cli_qos_src
PKG_BUILD_DIR_CLIQOS:=$(PKG_BUILD_DIR)/$(MAKE_PATH)

#### Target Rules ###############################
define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR_CLIQOS)/qos_cli $(1)/$(VENDOR_PATH)/usr/sbin/.
	cd $(1)/$(VENDOR_PATH)/usr/sbin; \
		ln -s qos_cli qoscfg; \
		ln -s qos_cli qcfg; \
		ln -s qos_cli ifcfg; \
		ln -s qos_cli classcfg
endef

define Build/Clean
	if [ -d $(PKG_BUILD_DIR_CLIQOS) ]; then $(MAKE) -C $(PKG_BUILD_DIR_CLIQOS) clean; \
	$(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); fi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
