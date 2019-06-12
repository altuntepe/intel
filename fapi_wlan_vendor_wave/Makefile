#
# Openwrt Makefile for fapi_wlan_vendor_wave
#
#

#### Includes ###################################
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

#### Package Info ############################### 
PKG_NAME:=fapi_wlan_vendor_wave
PKG_VERSION:=05.04.02.49
PKG_SOURCE_VERSION:=f0c4ef9bccc9db40f30723b8844e345880cc023f
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/fapi_wlan_vendor_wave.git
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz

include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk
$(call include_mk, ugw-loglevel.mk)

PKG_BUILD_DEPENDS:=+PACKAGE_ltq-wlan-wave_5_x:hostapd_wave

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Intel
  SUBMENU:=UGW Functional APIs
  TITLE:=Intel WLAN Vendor FAPI
  URL:=http://www.intel.com
  MAINTAINER:=Intel Corporation
  DEPENDS:= +fapi_wlan_common +!LANTIQ_OPENWRT_FIRMWARE:libugwhelper +LANTIQ_OPENWRT_FIRMWARE:libhelper @+BUSYBOX_CONFIG_SORT
  MENU:=1
endef

define Package/$(PKG_NAME)/description
	Intel FAPI for WLAN
endef

ifneq ($(CONFIG_PACKAGE_ltq-wlan-wave_5_x),)
export VENDOR_WAVE_BUILD = $(CONFIG_PACKAGE_ltq-wlan-wave_5_x)
endif

ifeq ($(CONFIG_LANTIQ_OPENWRT_FIRMWARE),y)
export LANTIQ_OPENWRT_FIRMWARE = $(CONFIG_LANTIQ_OPENWRT_FIRMWARE)
endif

### Menuconfig ##################################
define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
$(call Package/$(PKG_NAME)/config_debug_level)
endef

# To ipkg / Rootfs
define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/lib
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/usr/sbin
	$(INSTALL_DIR) $(1)/$(VENDOR_PATH)/wave/scripts
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/libfapiwave.so $(1)/$(VENDOR_PATH)/lib
	#$(INSTALL_BIN) $(PKG_BUILD_DIR)/test_wlan $(1)/$(VENDOR_PATH)/usr/sbin
	# Copy Scripts
	$(CP) $(PKG_BUILD_DIR)/scripts/fapi* $(1)/$(VENDOR_PATH)/wave/scripts
	$(INSTALL_DIR) $(STAGING_DIR)/usr/docs
	$(CP) $(PKG_BUILD_DIR)/fapi_wlan_wave.h $(STAGING_DIR)/usr/docs/.
endef

define Build/Clean
	if [ -d $(PKG_BUILD_DIR) ]; then $(MAKE) -C $(PKG_BUILD_DIR) clean; \
	$(RM) -r $(PKG_BUILD_DIR)/ipkg-$(BOARD); fi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
