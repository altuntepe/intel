#
# Copyright (C) 2008 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ltq-voice-tapi
PKG_VERSION:=4.18.1.0
PKG_MD5SUM:=0a8de1ebdb2b1c771971ce08bf415052
PKG_RELEASE:=1

# IMPORTANT - include the version-override here after PKG_VERSION definition
include $(INCLUDE_DIR)/package-version-override.mk
# IMPORTANT - ... and before using PKG_VERSION below

PKG_BASE_NAME:=drv_tapi
PKG_SOURCE:=$(PKG_BASE_NAME)-$(PKG_VERSION).tar.gz
#PKG_SOURCE_URL:=http://localhost
#PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(PKG_BASE_NAME)-$(PKG_VERSION)
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/drv_tapi.git
PKG_START_SCRIPT:=load_voice_tapi.sh
PKG_BUILD_DEPENDS:=ifxos \
                   PACKAGE_ltq-evtlog:ltq-evtlog \
                   PACKAGE_kmod-libsrtp-km:libsrtp-km
PKG_USE_MIPS16:=0

# Add dependencies on symbols in the configure file
PKG_CONFIG_DEPENDS:=\
        $(foreach _mr,$(shell grep -w config config/Config.in|awk '{ print $$2 }'),CONFIG_$(_mr)) \
        CONFIG_PACKAGE_kmod-lantiq-cpufreq

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=driver
  CATEGORY:=Intel
  SUBMENU:=Voice Subsystem
  TITLE:=TAPI driver
  URL:=http://www.intel.com/
  MAINTAINER:=Intel Corporation
  MENU:=1
  DEPENDS:=+kmod-ifxos +kmod-voice-tapi
endef

define Package/$(PKG_NAME)/description
	Voice Subsystem Telephony API High Level Driver
endef

define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
	source "$(SOURCE)/config/Config.in"
endef

# Set TAPI API interface version
CONFIGURE_ARGS += --enable-tapi3


# Add user specified CFLAGS and configure options

ifneq ($(CONFIG_LTQ_VOICE_TAPI_USER_FLAGS),"")
TAPI_CFLAGS=$(strip $(subst ",, $(CONFIG_LTQ_VOICE_TAPI_USER_FLAGS)))
endif

ifneq ($(CONFIG_LTQ_VOICE_TAPI_USER_OPTIONS),"")
CONFIGURE_ARGS += $(subst ",, $(CONFIG_LTQ_VOICE_TAPI_USER_OPTIONS))
endif

# Debugging support
ifeq ($(CONFIG_LTQ_VOICE_TAPI_DEBUGGING),y)
CONFIGURE_ARGS += --enable-debug \
                  --enable-warnings
TAPI_CFLAGS += -O0
endif

# put CFLAGS on the configure line
ifneq ($(TAPI_CFLAGS),"")
CONFIGURE_ARGS += --with-cflags="$(TAPI_CFLAGS)"
endif


# Configuration Options
ifeq ($(CONFIG_TARGET_intel_mips_xrx500)$(CONFIG_TARGET_lantiq_xrx500),y)
CONFIGURE_ARGS += --with-linux-alloc
endif

ifeq ($(CONFIG_LTQ_VOICE_TAPI_PMC),y)
CONFIGURE_ARGS += --enable-pmc
  ifeq ($(CONFIG_PACKAGE_kmod-lantiq-cpufreq),y)
  CONFIGURE_ARGS += --enable-pmc-if=cpufreq
  endif
else
CONFIGURE_ARGS += --disable-pmc
CONFIGURE_ARGS += --disable-pmc-if
endif



# Fixed options for TAPI V3 API
CONFIGURE_ARGS += --enable-voice \
                  --enable-packet \
                  --enable-hsm \
                  --enable-dtmf \
                  --disable-peakd \
                  --disable-mfr2 \
                  --disable-event-counter \
                  --enable-mos-lqe \
                  --enable-linux-smp

CONFIGURE_ARGS += --with-kernel-incl="$(LINUX_DIR)/include"
CONFIGURE_ARGS += --with-ifxos-incl=$(STAGING_DIR)/usr/include/ifxos
CONFIGURE_ARGS += --with-ifxos-lib=$(STAGING_DIR)/usr/lib
ifeq ($(CONFIG_LTQ_VOICE_TAPI_EVENT_LOGGER),y)
CONFIGURE_ARGS += --with-el-incl=$(STAGING_DIR)/usr/include/event_logger
endif
ifeq ($(CONFIG_LTQ_VOICE_TAPI_SRTP),y)
CONFIGURE_ARGS += --with-srtp-incl=$(STAGING_DIR)/usr/include/srtp-km
endif

ifneq ($(CONFIG_LINUX_2_4),y)
CONFIGURE_ARGS += --enable-linux-26 --with-kernel-build="$(LINUX_DIR)" ARCH=$(LINUX_KARCH)
PKG_MODULE_EXTENSION=.$(LINUX_KMOD_SUFFIX)
endif

CONFIGURE_ARGS += \
	--enable-tapi3 \
	--enable-kernelbuild="$(LINUX_DIR)" \
	--enable-kernelincl="$(LINUX_DIR)/include" \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_EVENT_LOGGER,el-debug) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_FAX,fax t38) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_CID,cid) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_DECT,dect) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_KPI,kpi kpi-tasklet) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_QOS,qos) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_LT_GR909,nlt) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_STATISTICS,statistics) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_METERING,metering) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_HDLC,hdlc) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_PCM,pcm) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_PHONE_DETECTION,phone-detection) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_CONT_MEASUREMENT,cont-measurement) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_CAP_MEASUREMENT,cap-measurement) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_SRTP,srtp) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_TRACES,trace) \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_HOTPLUG,hotplug)

define Build/Configure
	rm -f $(PKG_BUILD_DIR)/.configured*
	$(call Build/Configure/Default)
endef


define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	mkdir -p $(1)/usr/include/drv_tapi
	$(CP) --dereference $(PKG_BUILD_DIR)/include/* $(1)/usr/include/drv_tapi
	(cd $(1)/usr/include/drv_tapi && ln -s ../ifxos/ifx_types.h .)
endef

define Build/UninstallDev
	rm -rf $(BUILD_DIR)/drv_tapi
endef

define Build/Clean
	@- [ -e $(PKG_BUILD_DIR)/ipkg ] && rm -Rf $(PKG_BUILD_DIR)/ipkg
	@- [ -e $(PKG_BUILD_DIR)/Makefile ] && $(MAKE) -C $(PKG_BUILD_DIR) clean
	$(call Build/Clean/Default)
endef

ifneq ($(CONFIG_LTQ_VOICE_VMMC_WITH_DEVICE_FALCON),y)
define Package/$(PKG_NAME)/install
	# Startup script
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/$(PKG_START_SCRIPT) $(1)/etc/init.d/
	# Install the driver binary
	$(INSTALL_DIR) $(1)/$(MODULES_SUBDIR)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/drv_tapi$(PKG_MODULE_EXTENSION) $(1)/$(MODULES_SUBDIR)
	# Copy header file into staging directory
	$(INSTALL_DIR) $(STAGING_DIR)/usr/docs
	$(CP) $(PKG_BUILD_DIR)/include/drv_tapi_io.h $(STAGING_DIR)/usr/docs/.
endef
endif

define KernelPackage/voice-tapi
  SUBMENU:=Voice over IP
  TITLE:=Intel TAPI subsystem
  URL:=http://www.intel.com/
  MAINTAINER:=Intel Corporation
  DEPENDS:=+kmod-ifxos @(TARGET_lantiq||TARGET_intel_mips) @!TARGET_lantiq_ase
  FILES:=$(PKG_BUILD_DIR)/src/drv_tapi$(PKG_MODULE_EXTENSION)
  AUTOLOAD:=$(call AutoLoad,20,drv_tapi)
endef

ifeq ($(CONFIG_LTQ_VOICE_CPE_TAPI_LINUX_HOTPLUG),y)
GPIO_TAPI_HOOK_STATUS0=$(strip $(subst ",,$(CONFIG_LTQ_VOICE_CPE_TAPI_GPIO_HOOK_STATUS0)))
GPIO_TAPI_HOOK_STATUS1=$(strip $(subst ",,$(CONFIG_LTQ_VOICE_CPE_TAPI_GPIO_HOOK_STATUS1)))
endif

define KernelPackage/voice-tapi/description
	Voice Subsystem Telephony API High Level Driver
endef

define KernelPackage/voice-tapi/install
	$(INSTALL_DIR) $(1)/etc/config
ifeq ($(CONFIG_LTQ_VOICE_CPE_TAPI_LINUX_HOTPLUG),y)
	$(INSTALL_DATA) ./files/etc/config/tapi $(1)/etc/config/tapi
	$(SED) 's,@GPIO_TAPI_HOOK_STATUS0@,$(GPIO_TAPI_HOOK_STATUS0),g' $(1)/etc/config/tapi
	$(SED) 's,@GPIO_TAPI_HOOK_STATUS1@,$(GPIO_TAPI_HOOK_STATUS1),g' $(1)/etc/config/tapi
	mkdir -p $(1)/etc/hotplug.d/tapi
	$(INSTALL_DATA) ./files/10-tapi $(1)/etc/hotplug.d/tapi/10-tapi
endif
endef

$(eval $(call KernelPackage,voice-tapi))
$(eval $(call BuildPackage,$(PKG_NAME)))
