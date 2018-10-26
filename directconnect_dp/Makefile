#
# Copyright (C) 2016 Intel Corporation
# Copyright (C) 2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=directconnect-dp
PKG_VERSION:=0.2.4.2
PKG_RELEASE:=1

PKG_IS_KERNEL_MODULE=y

PKG_SOURCE_VERSION:=8dd0eb7534afecb72dc6a1054eefba3c8a8312d6
#PKG_SOURCE_URL:=ssh://git@gts-chd.intel.com:29418/sw_ugw/dc_dp_drv.git
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/dc_dp_drv.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_MIRROR:=1
PKG_MIRROR:=0
PKG_DEFAULT_CUSTOM_SOURCE_DIR:=/dc_dp_drv/

-include $(INCLUDE_DIR)/package-version-override.mk
include $(INCLUDE_DIR)/package.mk

define KernelPackage/$(PKG_NAME)
  SUBMENU:=Intel
  TITLE:=DirectConnect datapath driver
  DEPENDS:=@TARGET_intel_mips
  KCONFIG:= \
	CONFIG_DIRECTCONNECT_DP_API
  FILES:= \
	$(PKG_BUILD_DIR)/common/directconnect_datapath.ko \
	$(if $(CONFIG_TARGET_intel_mips_xrx500),$(PKG_BUILD_DIR)/dc_mode/dc_mode0/dc_mode0-xrx500.ko) \
	$(if $(CONFIG_TARGET_intel_xrx330),$(if (CONFIG_PACKAGE_kmod-vrx518_ep), \
		$(PKG_BUILD_DIR)/dc_mode/dc_mode1/dc_mode1-xrx330.ko))

  AUTOLOAD:=$(call AutoProbe,directconnect_datapath dc_mode0-xrx500 dc_mode1-xrx330)
  MENU:=1
endef

define KernelPackage/$(PKG_NAME)/description
  DirectConnect datapath driver
endef

define KernelPackage/$(PKG_NAME)/config
  source "$(SOURCE)/config/Config.in"
  $(call Package/kmod-$(PKG_NAME)/override_version)
  $(call Package/kmod-$(PKG_NAME)/override_source_path)
endef

EXTRA_CFLAGS += \
	-DCONFIG_DIRECTCONNECT_DP_DBG \
	-DCONFIG_DIRECTCONNECT_DP_LITEPATH \
	-DSW_DCMODE1_BUILTIN \
	$(if $(CONFIG_TARGET_intel_mips_xrx500), \
		-DHAVE_DATAPATH_API \
	)

export CONFIG_DIRECTCONNECT_DP_LITEPATH=y
export CONFIG_SW_DCMODE1_BUILTIN=y

ifeq ($(CONFIG_TARGET_intel_mips_xrx500),y)
	export CONFIG_DIRECTCONNECT_DP_XRX500=y
endif

ifeq ($(CONFIG_TARGET_x86_puma),y)
	export CONFIG_DIRECTCONNECT_DP_XRX750=y
	EXTRA_CFLAGS += -DHAVE_DATAPATH_API
endif

ifeq ($(CONFIG_TARGET_intel_xrx330),y)
ifeq ($(CONFIG_PACKAGE_kmod-vrx518_ep),y)
#	# for VRX518 only
	export CONFIG_DIRECTCONNECT_DP_330=y
	EXTRA_CFLAGS += -DHAVE_DATAPATH_API
endif
endif

EXTRA_CFLAGS += -I$(PKG_BUILD_DIR)/include

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR)/include/net/
	$(CP) $(PKG_BUILD_DIR)/include/*.h $(STAGING_DIR)/include/net/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		CROSS_COMPILE="$(TARGET_CROSS)" \
		ARCH="$(LINUX_KARCH)" \
		SUBDIRS="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
		modules
endef

define Build/Clean
	if [ -d $(PKG_BUILD_DIR) ]; then \
		$(MAKE) -C $(PKG_BUILD_DIR) KERNEL_DIR=$(LINUX_DIR) clean; \
		$(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); \
	fi
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
