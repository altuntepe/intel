include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=vrx518_tc_drv
PKG_VERSION:=1.1.1
PKG_RELEASE:=1

PKG_IS_KERNEL_MODULE=y

PKG_SOURCE_PROTO:=git
#PKG_SOURCE_URL:=ssh://git@gts-chd.intel.com:29418/sw_ugw/vrx518_tc_drv.git
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/vrx518_tc_drv.git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)

PKG_SOURCE_VERSION:=1d1d49f10be8f2fb88e106efcbba1ae366489f3a
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_BASE_NAME:=vrx518_tc
#PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
#PKG_DEFAULT_CUSTOM_SOURCE_DIR:=$(shell pwd)/src
PKG_SOURCE_MIRROR:=1
PKG_MIRROR:=0

include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk


KCONFIG_TC:=$(KCONFIG_TC_BASE)
ifneq ($(CONFIG_TARGET_intel_mips_xrx500),)
	PLAT_DIR:=grx500
else ifneq ($(CONFIG_TARGET_lantiq_xrx500),)
    PLAT_DIR:=grx500
else
    PLAT_DIR:=dcdp
endif

define KernelPackage/$(PKG_NAME)
  SUBMENU:=Intel
  TITLE:=VRX518 TC driver
  KCONFIG:= \
    CONFIG_VRX518_TC=m \
    CONFIG_VRX518_PCIE_SWITCH_BONDING=y \
    CONFIG_ATM=y \
    CONFIG_ATM_BR2684=y \
    CONFIG_ATM_LANE=y \
    CONFIG_ATM_CLIP=y \
    CONFIG_ATM_MPOA=y \
    CONFIG_ATM_BR2684_MINI_JUMBO_FRAME_SUPPORT=y \
    CONFIG_LTQ_DATAPATH_ACA_CSUM_WORKAROUND=y
  DEPENDS:=@TARGET_lantiq_xrx500||TARGET_intel_mips_xrx500||TARGET_x86||TARGET_lantiq_xrx330 +PACKAGE_kmod-directconnect_dp:kmod-directconnect_dp +kmod-vrx518_ep +vrx518_ppe_fw +vrx518_aca_fw
ifeq ($(CONFIG_TARGET_lantiq_xrx330),y)
  AUTOLOAD:=$(call AutoLoad,42,vrx518)
else
  AUTOLOAD:=$(call AutoLoad,26,vrx518)
endif
  FILES:=$(PKG_BUILD_DIR)/$(PLAT_DIR)/$(PKG_BASE_NAME).$(LINUX_KMOD_SUFFIX)
  MENU:=1
endef

define KernelPackage/$(PKG_NAME)/description
  VRX518 TC Driver
endef

define KernelPackage/vrx518_ep
 SUBMENU:=Intel
 TITLE:=VRX518 EP Support
 KCONFIG:= \
        CONFIG_VRX518=m \
        CONFIG_VRX518_PCIE_SWITCH_BONDING=y \
        CONFIG_TEST=m
ifeq ($(CONFIG_TARGET_lantiq_xrx330),y)
 AUTOLOAD:=$(call AutoLoad,43,vrx518 vrx518_tc)
else
 AUTOLOAD:=$(call AutoLoad,27,vrx518 vrx518_tc)
endif
 FILES:= \
        $(LINUX_DIR)/drivers/net/ethernet/intel/vrx518/vrx518.ko
endef

define KernelPackage/vrx518_ep/description
  VRX518 endpoint driver
endef

### Menuconfig #############################
define Package/kmod-$(PKG_NAME)/config
$(call Package/kmod-$(PKG_NAME)/override_version)
$(call Package/kmod-$(PKG_NAME)/override_source_path)
config $(PKG_NAME_PREF)$(PKG_NAME)_FEATURE_SELECT_CPUPATH
  depends on PACKAGE_$(PKG_NAME_PREF)$(PKG_NAME)
  bool "Select CPU Path"
  default n
  ---help---
    Select CPU path. No dependency on any other library/function except linux kernel
    and works on any platform.
endef

### CFLAGS #############################
MAKE_OPTS := $(if $(CONFIG_TARGET_lantiq_xrx500),FEATURE_VRX518_GRX500=y) \
			$(if $(CONFIG_TARGET_intel_mips_xrx500),FEATURE_VRX518_GRX500=y) \
	     $(if $(CONFIG_PACKAGE_kmod-directconnect_dp),FEATURE_VRX518_DC_DP=y) \
	     $(if $(CONFIG_kmod-$(PKG_NAME)_FEATURE_SELECT_CPUPATH),FEATURE_VRX518_CPU=y)

include $(INCLUDE_DIR)/kernel-defaults.mk

define Build/Prepare
	$(call Build/Prepare/Default)
	#$(if $(CONFIG_$(PKG_NAME)_USE_CUSTOM_SOURCE_DIR),,$(CP) -L ./src/* $(PKG_BUILD_DIR)/)
	#$(if $(CONFIG_$(PKG_NAME)_USE_CUSTOM_SOURCE_DIR),,$(CP) -L ./* $(PKG_BUILD_DIR)/)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/include/net/
	$(CP) $(PKG_BUILD_DIR)/$(PLAT_DIR)/inc/dsl_tc.h $(1)/include/net/
endef

define Build/Compile
	$(MAKE) $(MAKE_OPTS) $(KERNEL_MAKEOPTS) SUBDIRS="$(PKG_BUILD_DIR)/$(PLAT_DIR)" modules
endef

define Build/Clean
	if [ -d "$(PKG_BUILD_DIR)" ]; then \
		$(MAKE) $(MAKE_OPTS) $(KERNEL_MAKEOPTS) SUBDIRS="$(PKG_BUILD_DIR)" clean; \
		$(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); \
		$(RM) $(PKG_BUILD_DIR)/$(PLAT_DIR)/*.o; \
		$(RM) $(PKG_BUILD_DIR)/$(PLAT_DIR)/*.ko; \
	fi
endef

#define KernelPackage/$(PKG_NAME)/install
#	@echo "+++++$(1)+++++"
#	@echo "+++++$(PKG_BUILD_DIR)++++"
#	@echo "+++++$(MODULES_SUBDIR)+++++"
#	$(INSTALL_DIR) $(1)/$(MODULES_SUBDIR)
#	$(CP) $(PKG_BUILD_DIR)/$(PLAT_DIR)/$(PKG_BASE_NAME).ko $(1)/$(MODULES_SUBDIR)
#endef


$(eval $(call KernelPackage,vrx518_ep))
$(eval $(call KernelPackage,$(PKG_NAME)))
