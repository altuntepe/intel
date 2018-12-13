#
# Openwrt Makefile for ltq-voip
#


#### Includes ###################################
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

#### Package Info ###############################
PKG_NAME:=ltq-voip
PKG_VERSION:=3.8.7.15
PKG_RELEASE:=1
PKG_MD5SUM:=6eec4b4aa39e6ce54838fd623e7def55
PKG_BASE_NAME:=ltq_voip
PKG_SOURCE:=$(PKG_BASE_NAME)-$(PKG_VERSION).tar.gz
PKG_CAT:=zcat
#PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_BASE_NAME)-$(PKG_VERSION)
PKG_BUILD_DEPENDS:=PACKAGE_teridian-voice-daa-ter1x66:teridian-voice-daa-ter1x66 PACKAGE_ltq_hanfun_agent:ltq_hanfun_agent PACKAGE_ltq-voice-vmmc:ltq-voice-vmmc PACKAGE_ltq-voice-vmmc-xrx500:ltq-voice-vmmc-xrx500 \
                   PACKAGE_ltq-voice-grx750:ltq-voice-grx750 \
                   PACKAGE_ifxos-devio:ifxos-devio \
                   PACKAGE_ltq-voice-ccu:ltq-voice-ccu \
                   PACKAGE_ltq-voice-svca:ltq-voice-svca \
                   PACKAGE_ltq-voice-mxp:ltq-voice-mxp \
                   PACKAGE_ltq-voice-mxp-core:ltq-voice-mxp-core \
                   PACKAGE_ltq_hanserver:ltq_hanserver
#PKG_SOURCE_URL:=http://localhost
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=3abca3799d6ceb3076fe52d382d590493fa99f50
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/ltq_voip.git
PKG_FILE_DEPENDS:=$(PKG_BUILD_DIR)/.configured__*
PKG_NO_AUTORECONF:=y
PKG_DEFAULT_CUSTOM_SOURCE_DIR:=$(TOPDIR)/../../../repo_voip_source/
include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk
#LINK1:=
LINK1:=ln -s $(TOPDIR)/../../../repo_dect_source/dect_ifx_agent $(TOPDIR)/../../../repo_voip_source/dect_ifx_agent
#to add .config feature dependency only for VoIP features
ifeq ($(DUMP),)
  STAMP_CONFIGURED:=$(strip $(STAMP_CONFIGURED))_$(shell grep -e CONFIG_VOIP_FAX -e CONFIG_VOIP_FXO -e CONFIG_DECT_SUPPORT  -e CONFIG_CVOIP_SUPPORT $(TOPDIR)/.config | md5s)
#	echo "STAMP_CONFIGURED=" $STAMP_CONFIGURED
endif

define Package/$(PKG_NAME)
	SECTION:=utils
	CATEGORY:=Intel
	SUBMENU:=VOIP and DECT Subsystem
	TITLE:=Intel VoIP & Dect Sub Sytem Package for GW 4.2 onwards
	URL:=http://www.intel.com
	MAINTAINER:=Intel Corporation
#  DEPENDS:=+ltq-voice-tapi +!NEW_FRAMEWORK:ltq-mapi @+FEATURE_IFX_VOIP @+LTQ_VOICE_TAPI_DECT @TARGET_lantiq_xrx200||TARGET_lantiq_xrx300||TARGET_lantiq_xrx330||TARGET_lantiq_xrx500||TARGET_x86_puma_puma7 +ltq-voice-kpi2udp +ltq-voip-common +ltq-voice-lib-nlt +libcal +NEW_FRAMEWORK:libstdcpp +libexpat
	DEPENDS:=+!NEW_FRAMEWORK:ltq-mapi @+FEATURE_IFX_VOIP @+!TARGET_x86_puma_puma7:LTQ_VOICE_TAPI_DECT @TARGET_intel_mips_xrx200||TARGET_intel_mips_xrx300||TARGET_intel_mips_xrx330||TARGET_intel_mips_xrx500||TARGET_x86_puma_puma7 +ltq-voip-common +libcal +libsafec +NEW_FRAMEWORK:libstdcpp +libexpat +TARGET_x86_puma_puma7:system_fapi +TARGET_x86_puma_puma7:ltq-voice-tapi-us +!TARGET_x86_puma_puma7:ltq-voice-tapi
	MENU:=1
endef

define Package/$(PKG_NAME)/description
	This ltq-voip package is VoIP & DECT subsytem used to realize DECT & VoIP functionality on GW 4.2 onwards.
endef

ifdef CONFIG_NEW_FRAMEWORK
ifdef CONFIG_M5T_SCEAGENT_ENABLE_SUPPORT
M5T_SCEAGENT_PKG_VERSION:=1.0.3.14.1
M5T_SCEAGENT_PKG_NAME:=M5T-SceAgent
M5T_SCEAGENT_PKG_BASE_NAME:=$(M5T_SCEAGENT_PKG_NAME)
M5T_SCEAGENT_PKG_SOURCE:=$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION).zip

define Package/$(M5T_SCEAGENT_PKG_NAME)
  SECTION:=utils
  CATEGORY:=Intel
  SUBMENU:=VOIP and DECT Subsystem
  TITLE:=M5T SCE Agent
  URL:=http://www.media5corp.com/
  MAINTAINER:=Media5 Corporation
  DEPENDS:=
  MENU:=1
endef

define Package/$(M5T_SCEAGENT_PKG_NAME)/description
	M5T SCE Agent
endef

define Download/$(M5T_SCEAGENT_PKG_NAME)
	FILE:=$(M5T_SCEAGENT_PKG_SOURCE)
	URL:=http://localhost/
endef

define Prepare/$(M5T_SCEAGENT_PKG_NAME)
	if [ ! -d $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION) ] ; then \
		mkdir -p $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION) && \
		unzip "$(DL_DIR)/$(M5T_SCEAGENT_PKG_SOURCE)" -d "$(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)";\
	fi;
ifdef CONFIG_TARGET_x86_puma_puma7
	if [ $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)/M5T_X86 ] ; then \
		mv $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)/M5T_X86 $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)/M5T ; \
		rm -rf $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)/M5T_MIPS; \
	fi;
else
	if [ $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)/M5T_MIPS ] ; then \
		mv $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)/M5T_MIPS $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)/M5T ; \
		rm -rf $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION)/M5T_X86; \
	fi;
endif
	$(LN) $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION) $(PKG_BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME);
endef

$(eval $(call Download,$(M5T_SCEAGENT_PKG_NAME)))
endif
endif
#### Directory Paths ############################

IFX_UBOOT_DIR:=$(KERNEL_BUILD_DIR)/open_uboot/open_uboot
IFX_TAPI_DIR:=$(wildcard $(STAGING_DIR)/usr/include/drv_tapi*)
IFX_VMMC_DIR:=$(wildcard $(STAGING_DIR)/usr/include/drv_vmmc*)
DSL_API_DIR:=$(wildcard $(STAGING_DIR)/usr/include/drv_dsl_cpe_api*)
#DSL_CONTROL_DIR:=$(wildcard $(KERNEL_BUILD_DIR)/dsl_cpe_control*)
#DSL_API_DIR:=$(wildcard $(BUILD_DIR)/drv_dsl_cpe_api*)
#DSL_CONTROL_DIR:=$(wildcard $(BUILD_DIR)/dsl_cpe_control*)
DRV_TEREDIAN_DIR:=$(wildcard $(STAGING_DIR)/usr/include/drv_ter*)
#MAPI_DIR:=$(wildcard $(BUILD_DIR)/ifx_IFXAPIs*)
MAPI_DIR:=$(wildcard $(STAGING_DIR)/usr/include/ifx_IFXAPIs) -DBUILD_FROM_LTQ_APPS -Wl,-rpath-link,$(STAGING_DIR)/usr/lib
IFX_VOIP_COMMON_DIR:=$(wildcard $(BUILD_DIR)/ltq_voip_common*)

export UBOOT_DIR=$(IFX_UBOOT_DIR)
export IFX_DRV_TEREDIAN_DIR=$(DRV_TEREDIAN_DIR)
export TAPI_DIR=$(IFX_TAPI_DIR)
export VMMC_DIR=$(IFX_VMMC_DIR)
export IFX_PRODUCT_ROOT=$(PKG_BUILD_DIR)
export IFX_MAPI_DIR=$(MAPI_DIR)
export IFX_DSL_API_DIR=$(DSL_API_DIR)
#export IFX_DSL_CONTROL_DIR=$(DSL_CONTROL_DIR)
export IFX_HTTPD_DIR=$(wildcard $(STAGING_DIR)/usr/include/ifx_httpd*)
export IFX_STAGING_DIR=$(STAGING_DIR)
export CONFIG_FEATURE_DEVM_TR104
export IFX_INCLUDE_DIR=$(INCLUDE_DIR) -I/home/kent/Inteno/Intel/UGW-8.1.1-SW-CD/ugw_sw/openwrt/staging_dir/target-mips_24kc+nomips16_musl-1.1.16_grx500_mr_cpe/usr/include/lib_tapi_nlt_cpe


### Menuconfig ##################################
define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
#	menu "DECT features"
#		depends on PACKAGE_$(PKG_NAME)
#		source "$(SOURCE)/config/Config.in.dect"
#	endmenu
	menu "VoIP features"
		depends on PACKAGE_$(PKG_NAME)
		source "$(SOURCE)/config/Config.in.voip"
	endmenu
endef

### Configurations depends on Menuconfig ########
#CFLAGS += -fstack-protector 
#CFLAGS += -fPIE -fPIC 
#CFLAGS += -O2 -D_FORTIFY_SOURCE=2
#CFLAGS += -Wformat -Wformat-security

#IFX_LDFLAGS += -z noexecstack
#IFX_LDFLAGS += -z relro -z now
#IFX_LDFLAGS += -pie

CFLAGS += -Werror 

ifdef CONFIG_DECT_PART
CFLAGS += -DDECT_PART
endif

ifeq ($(CONFIG_VOIP_ENABLE_SINGLE_FXS),y)
CFLAGS +=  -DUTA
endif

ifdef CONFIG_NEW_FRAMEWORK
CFLAGS += -DVOIP_NEWVMAPI
export NEWVMAPI_DIR=1
endif

ifeq ($(CONFIG_DECT_ULE_DEMO),y)
CFLAGS +=  -DSMART_HOME_DEMO
endif
ifdef CONFIG_OSGI_POWER_OUTLET_SUPPORT
CFLAGS += -DLTQ_OSGI_POWER_OUTLET -DLTQ_RAW_DPSU
endif
ifdef CONFIG_DT_FEATURES
CFLAGS += -DLTQ_DT_SUPPORT
endif
ifdef CONFIG_DECT_SUPPORT
CFLAGS += -DDECT_SUPPORT
export DECT_AGENT_DIR=1
endif
ifdef CONFIG_CVOIP_SUPPORT
CFLAGS += -DCVOIP_SUPPORT
export CVOIP_AGENT_DIR=1
endif


ifdef CONFIG_TARGET_intel_mips_xrx330_EASY300_SH
ifdef CONFIG_VOIP_DISABLE_FXS
CFLAGS += -DDISABLE_FXS
endif
endif

ifdef CONFIG_TARGET_intel_mips_xrx200
CFLAGS += -DCONFIG_VR9
ifdef CONFIG_VOIP_FAX
CFLAGS += -DFAX_SUPPORT
export FAX_AGENT_DIR=1
endif
ifdef CONFIG_VOIP_FXO
CFLAGS += -DTEREDIAN
CFLAGS += -DENABLE_FXO
CFLAGS += -I${IFX_DRV_TEREDIAN_DIR}
endif
endif

ifdef CONFIG_TARGET_x86_puma_puma7
CFLAGS += -DCONFIG_XRX750
CFLAGS += -DDISABLE_GR909
export XRX750=1
endif

ifdef CONFIG_TARGET_intel_mips_xrx500
CFLAGS += -DCONFIG_XRX500
endif

ifdef CONFIG_TARGET_intel_mips_xrx300
CFLAGS += -DCONFIG_AR10
ifdef CONFIG_VOIP_FAX
CFLAGS += -DFAX_SUPPORT
export FAX_AGENT_DIR=1
endif
ifdef CONFIG_VOIP_FXO
CFLAGS += -DSLIC121
CFLAGS += -DENABLE_FXO
endif
endif

ifdef CONFIG_TARGET_intel_mips_xrx330
CFLAGS += -DCONFIG_AR10
ifdef CONFIG_VOIP_FAX
CFLAGS += -DFAX_SUPPORT
export FAX_AGENT_DIR=1
endif
ifdef CONFIG_VOIP_FXO
CFLAGS += -DSLIC121
CFLAGS += -DENABLE_FXO
endif
endif

ifdef CONFIG_TARGET_intel_mips_xrx500
CFLAGS += -DCONFIG_XRX500
ifdef CONFIG_VOIP_FAX
export FAX_AGENT_DIR=1
CFLAGS += -DFAX_SUPPORT
endif
ifdef CONFIG_VOIP_FXO
CFLAGS += -DSLIC121
CFLAGS += -DENABLE_FXO
endif
endif

ifdef CONFIG_VOIP_FXO
#CFLAGS += -DTEREDIAN
#CFLAGS += -DENABLE_FXO
endif

ifdef CONFIG_M5T_SCEAGENT_ENABLE_SUPPORT
export M5T_SCE_AGENT_ENABLE_SUPPORT=1
export M5T_SCE_AGENT_DIR=$(M5T_SCEAGENT_PKG_NAME)
endif

ifeq ($(CONFIG_IFX_MODEL_NAME),"ARX182_GW_EL_FXS_DECT")
CFLAGS += -DCOSIC_BMC_FW_ON_RAM
endif

ifeq ($(CONFIG_IFX_MODEL_NAME),"VRX220_GW_EL_VDSL")
CFLAGS += -DUTA
endif
ifdef CONFIG_DECT_ULE
CFLAGS += -DULE_SUPPORT
endif

ifeq ($(CONFIG_PACKAGE_ltq_hanserver),y)
CFLAGS +=  -DHANSERVER_SUPPORT
export HANSERVER_SUPPORT=1
endif

ifeq ($(CONFIG_PACKAGE_ltq_hanfun_agent),y)
CFLAGS +=  -DHANFUN_SUPPORT
export HANFUN_SUPPORT=1
endif

export CONFIGURE_ARGS

#### Target Rules ###############################
define Build/Prepare
$(call Build/Prepare/Default)
	$(call Prepare/$(M5T_SCEAGENT_PKG_NAME))
#	ln -sf $(IFX_VOIP_COMMON_DIR)/voip_ifx_common $(PKG_BUILD_DIR)/voip_ifx_common
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/bin
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/lib

endef


define Build/Compile

	echo $(CFLAGS)
ifdef CONFIG_DECT_SUPPORT
	if [ ! -d $(IFX_PRODUCT_ROOT)/dect_ifx_agent ] ; then \
	$(LINK1) ; \
	fi;
endif
	if [ ! -d $(IFX_PRODUCT_ROOT)/voip_ifx_common ] ; then \
	ln -sf $(IFX_VOIP_COMMON_DIR)/voip_ifx_common $(PKG_BUILD_DIR)/voip_ifx_common ; \
	fi;

	$(MAKE) LINUX_DIR="$(LINUX_DIR)" $(TARGET_CONFIGURE_OPTS) -C $(PKG_BUILD_DIR)/voip_ifx_gateway_appln/ all IFX_CFLAGS="$(CFLAGS) -D__EXPORTED_HEADERS__" IFX_LDFLAGS="$(IFX_LDFLAGS)"

	cp -f $(PKG_BUILD_DIR)/voip_ifx_gateway_appln/bin/ifxsip $(PKG_BUILD_DIR)/voip_ifx_gateway_appln/bin/ifxsip_wo_strip
	$(STRIP) $(PKG_BUILD_DIR)/voip_ifx_gateway_appln/bin/ifxsip 

#	cp -f $(IFX_PRODUCT_ROOT)/voip_ifx_gateway_appln/create_customer_package.sh  $(IFX_PRODUCT_ROOT)/
endef

define Build/InstallDev
	if [ "y$(CONFIG_NEW_FRAMEWORK)" = "yy" ] ; then \
		$(INSTALL_DIR) $(1)/usr/include	; \
		$(INSTALL_DIR) $(1)/usr/lib	; \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/voip_ifx_vmapi_65/h/* $(1)/usr/include/	; \
		$(INSTALL_BIN) $(PKG_BUILD_DIR)/lib/libxvmapimips-linux.so $(1)/usr/lib	; \
	fi;
endef


define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/
	$(INSTALL_DIR) $(1)/etc/rc.d
	$(INSTALL_DIR) $(1)/lib
	$(INSTALL_DIR) $(1)/www
	$(INSTALL_DIR) $(1)/opt/ifx/downloads/ifx_country_settings
	$(INSTALL_DIR) $(1)/ramdisk_copy/flash

	cp -rf $(PKG_BUILD_DIR)/voip_ifx_country_settings/* $(1)/opt/ifx/downloads/ifx_country_settings
ifndef CONFIG_NEW_FRAMEWORK
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/voip_ifx_webs/*  $(1)/www/
endif

#	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lib/libvmapimips-linux.so $(1)/lib

	$(INSTALL_BIN) $(PKG_BUILD_DIR)/lib/libxvmapimips-linux.so $(1)/lib
ifndef CONFIG_NEW_FRAMEWORK
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/voip_ifx_gateway_appln/bin/ifxsip $(1)/usr/sbin
	echo "VoIP Sub System    $(PKG_VERSION)"  >>  $(1)/usr/sbin/VoIP_VERSION  
else
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/bin 
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/voip_ifx_gateway_appln/bin/ifxsip $(1)/$(VENDOR_PATH)/bin/
	echo "VoIP Sub System    $(PKG_VERSION)"  >>  $(1)/$(VENDOR_PATH)/bin/VoIP_VERSION
	(cd $(1)/usr/sbin/; ln -snf ../../$(VENDOR_PATH)/bin/ifxsip .)
	(cd $(1)/usr/sbin/; ln -snf ../../$(VENDOR_PATH)/bin/VoIP_VERSION .)
endif
ifndef CONFIG_DECT_SUPPORT
ifndef CONFIG_CVOIP_SUPPORT
	rm -f $(1)/www/*dect*.asp
	rm -f $(1)/www/diagnostics.asp 
	rm -f $(BUILD_DIR)/root-ltqcpe/www/*dect*.asp
	rm -f $(BUILD_DIR)/root-ltqcpe/www/diagnostics.asp 
endif
endif
ifndef CONFIG_DT_FEATURES
	if test -f $(1)/ramdisk_copy/flash/rssemail.txt; then \
		rm -f $(1)/ramdisk_copy/flash/rssemail.txt ; \
		rm -f $(1)/ramdisk_copy/flash/chanel*.txt; \
		rm -f $(1)/ramdisk_copy/flash/email*.txt; \
	fi;
endif
ifndef CONFIG_DECT_SUPPORT
	if test -f  $(BUILD_DIR)/root-ltqcpe//etc/dect_rc.conf.gz; then \
		rm -f  $(BUILD_DIR)/root-ltqcpe/etc/dect_rc.conf.gz ; \
		rm -f	 $(BUILD_DIR)/root-ltqcpe/etc/rc.d/read_dect_config ; \
    rm -f	 $(BUILD_DIR)/root-ltqcpe/etc/rc.d/backup_dect_config; \
    rm -f	 $(BUILD_DIR)/root-ltqcpe/usr/sbin/dect_factorycfg.sh; \
	fi;
endif
ifdef CONFIG_DECT_SUPPORT
ifndef CONFIG_DECT_PART
	if test -f  $(BUILD_DIR)/root-ltqcpe//etc/dect_rc.conf.gz; then \
		rm -f  $(BUILD_DIR)/root-ltqcpe/etc/dect_rc.conf.gz ; \
		rm -f	 $(BUILD_DIR)/root-ltqcpe/etc/rc.d/read_dect_config ; \
    rm -f	 $(BUILD_DIR)/root-ltqcpe/etc/rc.d/backup_dect_config; \
    rm -f	 $(BUILD_DIR)/root-ltqcpe/usr/sbin/dect_factorycfg.sh; \
	fi;
endif
endif
ifdef CONFIG_DT_FEATURES
	cp -rf $(IFX_PRODUCT_ROOT)/dect_ifx_agent/config/*.txt $(1)/ramdisk_copy/flash/
endif
ifdef CONFIG_DECT_SUPPORT
ifdef CONFIG_DECT_PART
	cp -rf $(IFX_PRODUCT_ROOT)/dect_ifx_agent/config/*.sh $(1)/usr/sbin/
	cp -rf $(IFX_PRODUCT_ROOT)/dect_ifx_agent/config/read_dect_config $(1)/etc/rc.d/
	cp -rf $(IFX_PRODUCT_ROOT)/dect_ifx_agent/config/backup_dect_config $(1)/etc/rc.d/
	if test -f  $(BUILD_DIR)/root-ltqcpe//etc/dect_rc.conf.gz; then \
		rm -f  $(BUILD_DIR)/root-ltqcpe/etc/dect_rc.conf.gz ; \
		cp -rf $(IFX_PRODUCT_ROOT)/dect_ifx_agent/config/dect_rc.conf $(BUILD_DIR)/root-ltqcpe/etc/ ; \
		gzip -f $(BUILD_DIR)/root-ltqcpe/etc/dect_rc.conf ; \
	fi;
	cp -rf $(IFX_PRODUCT_ROOT)/dect_ifx_agent/config/dect_rc.conf $(1)/etc/
	gzip -f $(1)/etc/dect_rc.conf
endif
endif
	$(INSTALL_DIR) $(STAGING_DIR)/usr/docs
	$(CP) $(PKG_BUILD_DIR)/voip_ifx_gateway_appln/Interface/* $(STAGING_DIR)/usr/docs/.
	rm -f $(STAGING_DIR)/usr/docs/IFX_AgentsUtils.h
endef

define Build/Clean
	if test -f $(IFX_PRODUCT_ROOT)/voip_ifx_gateway_appln/Makefile; then \
	$(MAKE) LINUX_DIR="$(LINUX_DIR)" $(TARGET_CONFIGURE_OPTS) -C $(PKG_BUILD_DIR)/voip_ifx_gateway_appln/ clean IFX_CFLAGS="$(IFX_CFLAGS)" IFX_LDFLAGS="$(IFX_LDFLAGS)"; \
	fi;
	if test -d $(IFX_PRODUCT_ROOT)/voip_ifx_common/make; then \
        $(MAKE) LINUX_DIR="$(LINUX_DIR)" $(TARGET_CONFIGURE_OPTS) -C $(PKG_BUILD_DIR)/voip_ifx_common/make/ clean IFX_CFLAGS="$(IFX_CFLAGS)" IFX_LDFLAGS="$(IFX_LDFLAGS)"; \
        fi;
        if test -d $(IFX_PRODUCT_ROOT)/voip_ifx_timer_driver; then \
        $(MAKE) -C $(LINUX_DIR) M=$(IFX_PRODUCT_ROOT)/voip_ifx_timer_driver clean ;\
        fi;
	rm -rf $(IFX_PRODUCT_ROOT)/lib/*

	if [ -a $(IFX_PRODUCT_ROOT)/voip_ifx_gateway_appln/MediaMgr/h/ltq_gpio.h ] ; then \
	rm -f $(IFX_PRODUCT_ROOT)/voip_ifx_gateway_appln/MediaMgr/h/ltq_gpio.h ; \
	fi;
	if [ -d $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION) ] ; then\
	rm -Rf $(BUILD_DIR)/$(M5T_SCEAGENT_PKG_NAME)-$(M5T_SCEAGENT_PKG_VERSION) ; \
	fi;
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
