include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk
SUBTARGET_SUFFIX:=$(shell echo $(subst .,_,$(subst -,_,$(subst /,_,$(SUBTARGET)))) | cut -d_ -f2-)

PKG_NAME:=ppa-drv
PKG_VERSION:=1.0
PKG_RELEASE=$(PKG_SOURCE_VERSION)

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/$(PKG_NAME).git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=9f7292137a4d1e31984cc13a675066e8ea19d96d
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_MAINTAINER:=Intel

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=
PKG_BUILD_PARALLEL:=1
PKG_IS_KERNEL_MODULE:=y
#PKG_DEFAULT_CUSTOM_SOURCE_DIR:=$(TOPDIR)/ppa-drv

-include $(INCLUDE_DIR)/package-version-override.mk
include $(INCLUDE_DIR)/package.mk

PKG_CONFIG_DEPENDS := CONFIG_PACKAGE_kmod-nf-conntrack

define add_ppa_config
MAKE_FLAGS += $(if $(CONFIG_PACKAGE_kmod-$(1)),$(patsubst CONFIG_%,CONFIG_%=1,$(2)))
PKG_EXTRA_KCONFIG += $(if $(CONFIG_PACKAGE_kmod-$(1)),$(patsubst CONFIG_%,CONFIG_%=m,$(2)))
endef

define Package/ppacmd
 SECTION:=utils
 CATEGORY:=Intel
 TITLE:=Packet Protocol Acceleration Commandline tool
 DEPENDS:=@TARGET_intel_mips +kmod-ppa-drv +libsafec
 MAINTAINER:=Intel
 URL:=http://www.intel.com
 MENU:=1
endef

define Package/ppacmd/description
 Command line tool for PPA acceleration
endef

define Package/ppacmd/install
        $(INSTALL_DIR) $(1)/usr/sbin/; \
        $(INSTALL_BIN) $(PKG_BUILD_DIR)/tools/ppacmd/ppacmd $(1)/usr/sbin/;
endef

define KernelPackage/ppa-drv
 SUBMENU:=Intel
 TITLE:=Packet Protocol Acceleration Support
 DEPENDS:=@TARGET_intel_mips \
	+kmod-ppa-drv-stack-al \
	+TARGET_intel_mips_xrx500:kmod-ppa-drv-grx500 \
	+TARGET_intel_mips_falcon_mountain:kmod-ppa-drv-falcon \
	PACKAGE_kmod-ppa-drv-grx500-mpe:kmod-ppa-drv-grx500-mpe

 MAINTAINER:=Intel
 KCONFIG:= \
	CONFIG_PPA=y \
  	CONFIG_PPA_API_SW_FASTPATH=y \
	CONFIG_PPA_TCP_LITEPATH=y

 FILES:= \
	$(PKG_BUILD_DIR)/src/ppa_api/ppa_api.ko \
	$(PKG_BUILD_DIR)/src/ppa_api/ppa_api_sw_accel_mod.ko

 AUTOLOAD:=$(call AutoProbe,ppa_api_sw_accel_mod ppa_api)
 MENU:=1
endef

define KernelPackage/ppa-drv/description
 Kernel support for PPA acceleration
endef

define KernelPackage/ppa-drv/config
$(call Package/$(PKG_NAME_PREF)$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME_PREF)$(PKG_NAME)/override_source_path)
endef

define KernelPackage/ppa-drv-stack-al
 SUBMENU:=Intel
 TITLE:=Packet Protocol Acceleration Stack Adaptation Layer
 DEPENDS:=@TARGET_intel_mips +kmod-nf-conntrack +kmod-veth
 MAINTAINER:=Intel
 KCONFIG:= \
	CONFIG_PPA=y \
	CONFIG_PPA_QOS=y \
 	CONFIG_PPA_API_DIRECTPATH=y \
	CONFIG_PPA_TMU_MIB_SUPPORT=n \
  	CONFIG_PPA_API_SW_FASTPATH=n \
  	CONFIG_PPA_BR_SESS_LEARNING=y \
	CONFIG_PPA_TCP_LITEPATH=n
 
 FILES:= \
	$(PKG_BUILD_DIR)/src/ppa_api/ppa_drv_stack_al.ko

 AUTOLOAD:=$(call AutoProbe,ppa_drv_stack_al)
 MENU:=1
endef

define KernelPackage/ppa-drv-stack-al/description
 PPA acceleration Stack Adaptation Layer
endef

define KernelPackage/ppa-drv-grx500
 SUBMENU:=Intel
 TITLE:=Packet Protocol Acceleration Support for xRX500
 DEPENDS:=@TARGET_intel_mips_xrx500 +kmod-ppa-drv-stack-al
 MAINTAINER:=Intel
 KCONFIG:= \
	CONFIG_PPA_HAL_SELECTOR=y \
	CONFIG_PPA_TMU_MIB_SUPPORT=y \
	CONFIG_PPA_API_DIRECTCONNECT=y

 FILES:= \
	$(PKG_BUILD_DIR)/src/platform/xrx500/ltq_pae_hal.ko \
	$(PKG_BUILD_DIR)/src/platform/xrx500/ltq_tmu_hal_drv.ko \
	$(PKG_BUILD_DIR)/src/platform/xrx500/ltq_directpath_datapath.ko

 AUTOLOAD:=$(call AutoProbe,ltq_pae_hal ltq_tmu_hal_drv ltq_directpath_datapath)
endef

$(eval $(call add_ppa_config,ppa-drv-grx500, \
	CONFIG_PPA_TMU_HAL \
	CONFIG_NAT_LOOP_BACK \
))

define KernelPackage/ppa-drv-grx500/description
  PPA GRX500 Acceleration Support
endef

define KernelPackage/ppa-drv-falcon
 SUBMENU:=Intel
 TITLE:=Packet Protocol Acceleration Support for FALCON Mountain
 DEPENDS:=@TARGET_intel_mips_falcon_mountain +kmod-ppa-drv-stack-al +kmod-sched-flower +kmod-sched-act-extra
 MAINTAINER:=Intel
 KCONFIG:= \
        CONFIG_PPA_HAL_SELECTOR=y \
        CONFIG_PPA_API_DIRECTCONNECT=y

 FILES:= \
        $(PKG_BUILD_DIR)/src/platform/xrx500/qos_hal_drv.ko

 AUTOLOAD:=$(call AutoProbe,qos_hal_drv)
endef

$(eval $(call add_ppa_config,ppa-drv-falcon, \
	CONFIG_PPA_QOS_HAL \
	CONFIG_QOS_MGR_TC_SUPPORT \
))

define KernelPackage/ppa-drv-falcon/description
  PPA FALCON Mountain Acceleration Support
endef

define KernelPackage/ppa-drv-grx500-mpe
 SUBMENU:=Intel
 TITLE:=Packet Protocol Acceleration Multi-Protocol Engine for GRX500
 DEPENDS:=@TARGET_intel_mips_xrx500 +kmod-ppa-drv-grx500
 MAINTAINER:=Intel
 
 FILES:= \
	$(PKG_BUILD_DIR)/src/platform/xrx500/ltq_mpe_hal_drv.ko \
	$(PKG_BUILD_DIR)/src/ppa_api/ppa_api_tmplbuf.ko

 AUTOLOAD:=$(call AutoProbe,ppa_api_tmplbuf ltq_mpe_hal_drv)
endef

$(eval $(call add_ppa_config,ppa-drv-grx500-mpe, \
	CONFIG_PPA_MPE_HAL \
))

define KernelPackage/ppa-drv-grx500-mpe/description
  PPA GRX500 Packet Protocol Acceleration Multi-Protocol Engine module
endef

# Install additional files from this.
define KernelPackage/ppa-drv-grx500-mpe/install
		$(INSTALL_DIR) $(1)/lib/firmware; \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/platform/xrx500/mpe_fw_be.img $(1)/lib/firmware/;
endef

define KernelPackage/ppa-drv-mpe-ip97
 SUBMENU:=Intel
 TITLE:=LTQ PPA MPE IP97 Support for xRX500
 DEPENDS:=@TARGET_intel_mips_xrx500 @PACKAGE_kmod-ppa-drv +kmod-eip97
 KCONFIG:= \
	CONFIG_PPA_MPE_IP97=y
endef

define KernelPackage/ppa-drv-mpe-ip97/description
  PPA GRX500 MPE IP97 Support
endef

define KernelPackage/ppa-drv-grx500-eth-bond
 SUBMENU:=Intel
 TITLE:=Ethernet Bonding support for xRX500
 DEPENDS+=@TARGET_intel_mips_xrx500 @PACKAGE_kmod-ppa-drv
 KCONFIG+= \
	CONFIG_HGU_BONDING=y \
	CONFIG_LTQ_PPA_ETH_BOND
        
 $(if $(wildcard $(LINUX_DIR)/drivers/net/lantiq_ppa),PPAPATH:="lantiq_ppa",PPAPATH:="lantiq_ppa/src")
 FILES := \
	$(LINUX_DIR)/drivers/net/$(PPAPATH)/platform/$(SUBTARGET_SUFFIX)/ltq_eth_bond_dp.ko
 
endef

define KernelPackage/ppa-drv-grx500-eth-bond/description
  PPA GRX500 - HGU Board ethernet bonding dp enable pluggable module
endef

define KernelPackage/ppa-drv-grx500-eth-bond/install
        $(INSTALL_DIR) $(1)/etc/init.d/; \
        $(INSTALL_BIN) $(LINUX_DIR)/drivers/net/lantiq_ppa/platform/xrx500/eth_bond_init.sh $(1)/etc/init.d/;
endef

define KernelPackage/ppa-drv-grx500-eth-rgmii
 SUBMENU:=Intel
 TITLE:=ETH WAN RGMII mode enable for xRX500
 DEPENDS:=@PACKAGE_kmod-ppa-drv-grx500-eth-bond
 KCONFIG:= \
	CONFIG_LTQ_PPA_ETHWAN_RGMII=y
endef

define KernelPackage/ppa-drv-grx500-eth-rgmii/description
  PPA GRX500 ETH WAN RGMII mode Support
endef

define KernelPackage/ppa-drv-gre
  SUBMENU:=Intel
  TITLE:=Support GRE Acceleration in PPA
  DEPENDS:=+kmod-gre +kmod-gre6
  KCONFIG:= \
	CONFIG_PPA_BR_SESS_LEARNING=y \
	CONFIG_BRIDGE_NETFILTER=y
endef

define KernelPackage/ppa-drv-gre/description
  GRE/EoGRE Acceleration in PPA - Enable this to support GRE/EoGRE in PPA
endef

define KernelPackage/mac-violation-mirror
  SUBMENU:=Intel
  TITLE:=Intel Mac Violation Exception Handling Support
  DEPENDS:=@TARGET_intel_mips_xrx500 +kmod-ppa-drv
  KCONFIG:= \
	CONFIG_MAC_VIOLATION_MIRROR=m
  FILES:= \
	$(PKG_BUILD_DIR)/src/mac_violation_mirror/mac_violation_mirror.ko

 AUTOLOAD:=$(call AutoProbe,mac_violation_mirror)
endef

$(eval $(call add_ppa_config,mac-violation-mirror, \
	CONFIG_MAC_VIOLATION_MIRROR \
))

define KernelPackage/mac-violation-mirror/description
 Kernel support for handling Source Mac Violated Packets by Mirroring to PAE port for connectivity continuation
endef


#############################################################################
PKG_EXTRA_CFLAGS := $(patsubst CONFIG_%, -DCONFIG_%=1, $(patsubst %=m,%,$(filter %=m,$(PKG_EXTRA_KCONFIG))))

PKG_EXTRA_CFLAGS += $(if $(CONFIG_PACKAGE_kmod-nf-conntrack),-DCONFIG_NF_CONNTRACK)

TARGET_CFLAGS += $(PKG_EXTRA_CFLAGS) -DCONFIG_PPA -I$(LINUX_DIR)/include/ -I$(LINUX_DIR)/user_headers/include

MAKE_FLAGS += \
        $(if $(CONFIG_TARGET_x86_puma_puma7),PLATFORM_PUMA7=1) \
        $(if $(CONFIG_PACKAGE_kmod-ppa-drv-grx500),PLATFORM_XRX500=1)

define Build/Compile
        $(MAKE) -C "$(LINUX_DIR)" \
                ARCH="$(LINUX_KARCH)" \
                CROSS_COMPILE="$(TARGET_CROSS)" \
                SUBDIRS="$(PKG_BUILD_DIR)/src" \
		$(PKG_EXTRA_KCONFIG) \
		EXTRA_CFLAGS="$(PKG_EXTRA_CFLAGS)" \
                V="$(if $(V),1)" \
                modules
	$(if $(CONFIG_PACKAGE_ppacmd), \
	+$(MAKE_VARS) \
	$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR)/tools/ppacmd \
		$(MAKE_FLAGS) \
		all \
	)
endef

define Build/Clean	
	if [ -d $(PKG_BUILD_DIR) ]; then $(MAKE) -C "$(LINUX_DIR)" SUBDIRS="$(PKG_BUILD_DIR)/src" clean; \
        $(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); \
	$(if $(CONFIG_PACKAGE_ppacmd), \
        $(MAKE) -C $(PKG_BUILD_DIR)/tools/ppacmd clean \
	); fi
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	mkdir -p $(1)/usr/include/net/switch_api
	$(CP) --dereference $(LINUX_DIR)/include/net/switch_api/* $(1)/usr/include/net/switch_api/
endef

$(eval $(call KernelPackage,ppa-drv-grx500))
$(eval $(call KernelPackage,ppa-drv-falcon))
$(eval $(call KernelPackage,ppa-drv-grx500-mpe))
$(eval $(call KernelPackage,ppa-drv-mpe-ip97))
$(eval $(call KernelPackage,ppa-drv-grx500-eth-bond))
$(eval $(call KernelPackage,ppa-drv-grx500-eth-rgmii))
$(eval $(call KernelPackage,ppa-drv-gre))
$(eval $(call KernelPackage,ppa-drv))
$(eval $(call KernelPackage,ppa-drv-stack-al))
$(eval $(call KernelPackage,mac-violation-mirror))
$(eval $(call BuildPackage,ppacmd))
