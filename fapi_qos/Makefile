#
# Copyright (C) 2009 OpenWrt.org
# Copyright (C) 2017 Intel Corporation
#
# Openwrt Makefile for fapi_qos
#
#

#### Includes ###################################
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

#### Package Info ###############################
PKG_NAME:=fapi_qos
PKG_VERSION:=1.3.0.3
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/fapi_qos_src.git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=b536fb81ec17982b4400e224ad7a67d71dbd61ae
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_MAINTAINER:=Intel

PKG_LICENSE:=Intel
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

#PKG_CONFIG_DEPENDS:=\
#	$(foreach _mr,$(shell grep -w config Config.in|awk '{ print $$2 }'),CONFIG_$(_mr))

include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk
$(call include_mk, ugw-loglevel.mk)

ifeq ($(CONFIG_FEATURE_HOST_ENVIR),y)
  include $(INCLUDE_DIR)/host-build.mk
endif

define Package/$(PKG_NAME)
  SECTION:=libs
  CATEGORY:=Intel
  SUBMENU:=UGW Functional APIs
  TITLE:=UGW QoS FAPI
  URL:=http://www.intel.com
  MAINTAINER:=Intel Corporation
  DEPENDS:=+switch_cli_ugw8 +libhelper +libubox +libezxml +kmod-intel-extmark \
	+kmod-intel-iptables +ebtables +kmod-intel-ebtables +kmod-ebtables-ipv4 \
	+iptables-mod-ipopt +kmod-intel-qos +libsafec +tc
  MENU:=1
endef

define Package/$(PKG_NAME)/description
	Intel UGW QoS FAPI
endef

define KernelPackage/intel-qos
  TITLE:=Intel support for QoS
  SUBMENU:=Intel
  DEPENDS:=+kmod-sched
  KCONFIG:= \
	CONFIG_INTEL_IPQOS=y \
	CONFIG_INTEL_IPQOS_ACCEL_DISABLE=y \
	CONFIG_INTEL_IPQOS_MARK_SKBPRIO=y \
	CONFIG_VLAN_8021Q_COPY_TO_EXTMARK=y
endef

define KernelPackage/intel-qos/description
  Kernel Support for QoS.
endef

### Menuconfig ##################################
define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
endef

### Configurations depends on Menuconfig ########
IFX_LDFLAGS_y:= -L$(STAGING_DIR)/usr/lib

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
IFX_CFLAGS_y+= $(if $(SWITCH_INC),-I$(SWITCH_INC))
IFX_CFLAGS:=$(IFX_CFLAGS_y) -I$(STAGING_DIR)/usr/include
IFX_LDFLAGS:=$(IFX_LDFLAGS_y)

TARGET_CFLAGS += $(IFX_CFLAGS) -I$(LINUX_DIR)/user_headers/include/net/ -I$(LINUX_DIR)/user_headers/include/ -I$(LINUX_DIR)/include -I$(LINUX_DIR)/include/net -I$(LINUX_DIR)/include/net/ppa -I$(STAGING_DIR)/usr/include/libubox/

#### Export Section for Features & Others #######
CONFIG_OPTS=$(TARGET_CONFIGURE_OPTS)
CFLAGS="$(TARGET_CFLAGS) $(IFX_CFLAGS) "
LDFLAGS="$(IFX_LDFLAGS) "

PKG_BUILD_DIR_FAPIQOS:=$(PKG_BUILD_DIR)/$(MAKE_PATH)
MAKE_FLAGS += \
	QOSAL_DIR="$(PKG_BUILD_DIR)/$(MAKE_PATH)"

#### Target Rules ###############################

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)/usr/include/qosfapi
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/share/*.h $(STAGING_DIR)/usr/include/qosfapi/.
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/fapi/fapi_high.h $(STAGING_DIR)/usr/include/qosfapi/.
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/usr/sbin
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/usr/lib/qosal
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/engines/cpu_n/libcpu_n.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/engines/switch/libswitch.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/engines/ppe_e/libppe_e.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/
	$(if $(CONFIG_TARGET_intel_mips_xrx500),$(CP) $(PKG_BUILD_DIR_FAPIQOS)/engines/ppa/libppa.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/)
	$(if $(CONFIG_TARGET_x86_puma),$(CP) $(PKG_BUILD_DIR_FAPIQOS)/engines/ppa/libppa.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/)
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/ipc/libqosipc.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/fapi/libqosfapi.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/misc/libsysapi.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/utils/libutils.so $(1)/$(VENDOR_PATH)/usr/lib/qosal/
	cd $(1)/$(VENDOR_PATH)/usr/lib/qosal/; \
		for i_file in `ls *.so`; do \
			ln -s qosal/$$$$i_file ../$$$$i_file; \
		done
	$(INSTALL_BIN) $(PKG_BUILD_DIR_FAPIQOS)/qosd/qosd $(1)/$(VENDOR_PATH)/usr/sbin/.
	$(if $(CONFIG_TARGET_lantiq_xrx200),$(INSTALL_BIN) $(PKG_BUILD_DIR_FAPIQOS)/qosd/qosal_xrx200_cfg.xml $(1)/$(VENDOR_PATH)/usr/sbin/qosal_plat_cfg.xml)
	$(if $(CONFIG_TARGET_lantiq_xrx300),$(INSTALL_BIN) $(PKG_BUILD_DIR_FAPIQOS)/qosd/qosal_xrx300_cfg.xml $(1)/$(VENDOR_PATH)/usr/sbin/qosal_plat_cfg.xml)
	$(if $(CONFIG_TARGET_lantiq_xrx330),$(INSTALL_BIN) $(PKG_BUILD_DIR_FAPIQOS)/qosd/qosal_xrx330_cfg.xml $(1)/$(VENDOR_PATH)/usr/sbin/qosal_plat_cfg.xml)
	$(if $(CONFIG_TARGET_intel_mips_xrx500),$(INSTALL_BIN) $(PKG_BUILD_DIR_FAPIQOS)/qosd/qosal_xrx500_cfg.xml $(1)/$(VENDOR_PATH)/usr/sbin/qosal_plat_cfg.xml)
	$(if $(CONFIG_TARGET_x86_puma),$(INSTALL_BIN) $(PKG_BUILD_DIR_FAPIQOS)/qosd/qosal_xrx700_cfg.xml $(1)/$(VENDOR_PATH)/usr/sbin/qosal_plat_cfg.xml)
	$(INSTALL_BIN) $(PKG_BUILD_DIR_FAPIQOS)/qosd/qos_def_cfg.xml $(1)/$(VENDOR_PATH)/usr/sbin/qos_def_cfg.xml
	$(INSTALL_DIR) $(STAGING_DIR)/usr/include/qosfapi
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/share/*.h $(STAGING_DIR)/usr/include/qosfapi/.
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/fapi/fapi_high.h $(STAGING_DIR)/usr/include/qosfapi/.
	$(INSTALL_DIR) $(STAGING_DIR)/usr/lib/qosfapi
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/ipc/libqosipc.so $(STAGING_DIR)/usr/lib/qosfapi/.
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/fapi/libqosfapi.so $(STAGING_DIR)/usr/lib/qosfapi/.
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/utils/libutils.so $(STAGING_DIR)/usr/lib/qosfapi/.
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/utils/libutils.so $(STAGING_DIR)/usr/lib/qosfapi/.
	$(INSTALL_DIR) $(STAGING_DIR)/usr/docs
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/share/commondefs.h $(STAGING_DIR)/usr/docs/.
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/share/qosal_queue_api.h $(STAGING_DIR)/usr/docs/.
	$(CP) $(PKG_BUILD_DIR_FAPIQOS)/share/qosal_cl_api.h $(STAGING_DIR)/usr/docs/.
endef

define Build/Clean
	if [ -d $(PKG_BUILD_DIR_FAPIQOS) ]; then $(MAKE) -C $(PKG_BUILD_DIR_FAPIQOS) clean; \
	$(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); fi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
$(eval $(call KernelPackage,intel-qos))
