#
# Copyright (C) 2008 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ltq-voice-sdd-mbx
PKG_VERSION:=1.4.0.0
PKG_MD5SUM:=e85a7a9f7ef51c5fc9b5f21bc967c0bf
PKG_RELEASE:=1

# IMPORTANT - include the version-override here after PKG_VERSION definition
-include $(INCLUDE_DIR)/package-version-override.mk
# IMPORTANT - ... and before using PKG_VERSION below

PKG_BASE_NAME:=drv_sdd_mbx
PKG_SOURCE:=$(PKG_BASE_NAME)-$(PKG_VERSION).tar.gz
#PKG_SOURCE_URL:=http://localhost
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/drv_sdd_mbx.git
#PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)/$(PKG_BASE_NAME)-$(PKG_VERSION)

PKG_CAT:=zcat
PKG_BUILD_DEPENDS:=ifxos \
                   PACKAGE_ltq-evtlog:ltq-evtlog
PKG_START_SCRIPT:=load_sdd_mbx.sh

# Add dependencies on symbols in the configure file
PKG_CONFIG_DEPENDS:=\
        $(foreach _mr,$(shell grep -w config config/Config.in|awk '{ print $$2 }'),CONFIG_$(_mr))

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=driver
  CATEGORY:=Intel
  SUBMENU:=Voice Subsystem
  TITLE:=TAPI driver for VCODEC
  URL:=http://www.intel.com/
  MAINTAINER:=Intel Corporation
  MENU:=1
  #DEPENDS:=ltq-voice-tapi +kmod-ifxos +kmod-voice-tapi-sdd-mbx
  DEPENDS:=ltq-voice-tapi +kmod-ifxos
endef

define Package/$(PKG_NAME)/description
	TAPI Low Level Driver for SDD mailbox handling
endef

define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
	source "$(SOURCE)/config/Config.in"
endef


# Add user specified CFLAGS and configure options

ifneq ($(CONFIG_LTQ_VOICE_SDD_MBX_USER_FLAGS),"")
SDD_MBX_USER_CFLAGS=$(strip $(subst ",, $(LTQ_VOICE_SDD_MBX_USER_FLAGS)))
endif

ifneq ($(CONFIG_LTQ_VOICE_SDD_MBX_USER_OPTIONS),"")
CONFIGURE_ARGS += $(subst ",, $(CONFIG_LTQ_VOICE_SDD_MBX_USER_OPTIONS))
endif

# Debugging support
ifeq ($(CONFIG_LTQ_VOICE_SDD_MBX_DEBUGGING),y)
CONFIGURE_ARGS += --enable-debug \
                  --enable-warnings
SDD_MBX_USER_CFLAGS += -O0
endif

# put CFLAGS on the configure line
ifneq ($(SDD_MBX_USER_CFLAGS),"")
CONFIGURE_ARGS += --with-cflags="$(SDD_MBX_USER_CFLAGS)"
endif

# Configurable features

CONFIGURE_ARGS += \
	--enable-proc

CONFIGURE_ARGS += \
	$(call autoconf_bool,CONFIG_LTQ_VOICE_TAPI_TRACES,trace)

ifeq ($(CONFIG_LTQ_VOICE_SDD_MBX_EVENT_LOGGER),y)
CONFIGURE_ARGS += \
	--enable-el_debug \
	--with-el-incl=$(STAGING_DIR)/usr/include/event_logger
endif

# Configure environment

CONFIGURE_ARGS += \
	--with-kernel-incl="$(LINUX_DIR)/include" \
	--with-ifxos-incl=$(STAGING_DIR)/usr/include/ifxos

CONFIGURE_ARGS += \
	--enable-linux-26 \
	--with-kernel-build="$(LINUX_DIR)" ARCH=$(LINUX_KARCH)
PKG_MODULE_EXTENSION=.$(LINUX_KMOD_SUFFIX)

define Build/Configure
	rm -f $(PKG_BUILD_DIR)/.configured*
	$(call Build/Configure/Default)
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/{lib,include/drv_sdd_mbx}
	$(CP) -L $(PKG_BUILD_DIR)/include/* $(1)/usr/include/drv_sdd_mbx
endef

define Build/UninstallDev
	rm -rf $(1)/usr/include/drv_sdd_mbx
endef

define Build/Clean
	@- [ -e $(PKG_BUILD_DIR)/ipkg ] && rm -Rf $(PKG_BUILD_DIR)/ipkg
	@- [ -e $(PKG_BUILD_DIR)/Makefile ] && $(MAKE) -C $(PKG_BUILD_DIR) clean
	$(call Build/Clean/Default)
endef

define Package/$(PKG_NAME)/install
	# Startup script
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/$(PKG_START_SCRIPT) $(1)/etc/init.d/
	# Install the driver binary
	$(INSTALL_DIR) $(1)/$(MODULES_SUBDIR)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/drv_sdd_mbx$(PKG_MODULE_EXTENSION) $(1)/$(MODULES_SUBDIR)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

define KernelPackage/voice-tapi-sdd-mbx
  SUBMENU:=Voice over IP
  TITLE:=TAPI driver for VCODEC
  URL:=http://www.intel.com/
  MAINTAINER:=Intel Corporation
  DEPENDS:=+kmod-ltq-tapi
  FILES:=$(PKG_BUILD_DIR)/src/drv_sdd_mbx$(PKG_MODULE_EXTENSION)
  AUTOLOAD:=$(call AutoLoad,21,drv_sdd_mbx)
  KCONFIG:= \
	CONFIG_SPI=y \
	CONFIG_SPI_GRX500=y \
	CONFIG_SPI_MASTER=y
endef

define KernelPackage/voice-tapi-sdd-mbx/description
	Voice Subsystem Driver for VCODEC
endef

define KernelPackage/voice-tapi-sdd-mbx/install
endef

$(eval $(call KernelPackage,voice-tapi-sdd-mbx))
