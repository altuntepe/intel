include $(TOPDIR)/rules.mk

PKG_NAME:=vrx518_ppe_fw
PKG_VERSION:=1.3.6
#PKG_MD5SUM:=f720ac093aa8f3611f9803504fb26a86
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=7e28cafbf312c86ef97e45d8fc77fcdf468a691c
PKG_RELEASE:=1
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
#PKG_SOURCE_URL:=https://mts-chd.intel.com/~wlnsw/dist/
PKG_SOURCE_URL:=git@dev.iopsys.eu:intel/$(PKG_NAME).git

include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk

define Package/$(PKG_NAME)
  SECTION:=firmware
  SUBMENU:=Intel
  TITLE:=VRX518 PPE firmware
  URL:=http://www.intel.com
  MAINTAINER:=Intel
  MENU:=1
endef

define Package/$(PKG_NAME)/description
	VRX518 PPE firmware
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/lib/firmware

ifeq ($(CONFIG_TARGET_lantiq_xrx330),y)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/platform/xrx330/ppe_fw.bin $(1)/lib/firmware/
endif
ifeq ($(CONFIG_TARGET_lantiq_xrx500),y)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/platform/xrx500/ppe_fw.bin $(1)/lib/firmware/
endif
ifeq ($(CONFIG_TARGET_intel_mips_xrx500),y)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/platform/xrx500/ppe_fw.bin $(1)/lib/firmware/
endif
ifeq ($(CONFIG_TARGET_x86_puma),y)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/platform/xrx750/ppe_fw.bin $(1)/lib/firmware/
endif
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
