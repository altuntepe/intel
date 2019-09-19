#
# Openwrt Makefile for ltq-wlan-wave_5_x
####################################

# Includes
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk


KERNEL_PKG_NAME:=lantiq-wlan-wave-support_5_x
PKG_NAME:=ltq-wlan-wave_5_x
LINUX_ENV_NAME:=ugw-linux310
PKG_BASE_NAME:=ltq-wave300
PKG_BUILD_DEPENDS_EXTRA:=kmod-lantiq-cpufreq
DEPENDS_EXTRA:=+libnl3 +libpthread +librt +libnl-genl

# Package Info
PKG_VERSION:=05.04.02.47
DRV_VERSION:=05.04.02.00.25.631d9a7d75d3
FW_VERSION:=FW_5.4.2_r21111
TX_SENDER_VERSION:=TxSender_2.1_r2165
HOST_INTERFACE_VERSION:=HostInterface_2.1_r2174
RX_HANDLER_VERSION:=RxHandler_2.1_r2223

PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=eb4a7ab53a5f5b9e9f6fa49b2e1e8105ad471628
PKG_SOURCE:=$(PKG_BASE_NAME)-$(PKG_VERSION)-$(PKG_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/altuntepe/intel/$(PKG_BASE_NAME)

TX_SENDER_GEN5B_VERSION:=TxSender_3.4.1_r4550
HOST_INTERFACE_GEN5B_VERSION:=HostInterface_3.4.2_r4564
RX_HANDLER_GEN5B_VERSION:=RxHandler_3.4.1_r4552

PROGMODEL_VERSION_AR10:=3002
PROGMODEL_VERSION_WAVE500:=2721
PROGMODEL_VERSION_GEN5B:=4201

FPGA_SIM_VERSION:=wave500_mac_npu_2_2_26_3_G5_G5_6MHz_async
WAVE_PSD_VER:=TODO_UPDATE_VER_STRING
PKG_RELEASE:=1
#PKG_SOURCE_VERSION:=$(DRV_VERSION).gpl.wls.src
#PKG_SOURCE_NAME:=$(DRV_VERSION).wls.src
#PKG_SOURCE:=lq-wave-300-$(PKG_SOURCE_VERSION).tar.bz2

DRV_RFLIB_PKG_NAME:=$(PKG_NAME)-rflib
DRV_RFLIB_PKG_VERSION:=05.04.02.47
DRV_RFLIB_PKG_SOURCE:=lq-wave-300-$(DRV_VERSION).rflib.wls.src.tar.bz2
DRV_RFLIB_PKG_SOURCE_URL:=http://localhost
DRV_RFLIB_PKG_BIN:=lq-wave-300-$(DRV_VERSION).rflib.wls.bin.tar.bz2
KERNEL_PKG_NAME_BCKPRT_SPPRT:=$(KERNEL_PKG_NAME)_backport_support

BINARY_PKG:=$(if $(wildcard $(TOPDIR)/dl/$(DRV_RFLIB_PKG_BIN)),y)
UGW_MODEL_NAME:=$(shell echo $(CONFIG_BUILD_SUFFIX)|tr a-z A-Z)

ifndef CONFIG_$(PKG_NAME)_USE_CUSTOM_SOURCE_DIR
  #PKG_SOURCE_DIR:=lq-wave-300-$(PKG_SOURCE_NAME)
  #PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_BASE_NAME)-$(PKG_VERSION)
  #PKG_FULL_DIR:=$(PKG_BUILD_DIR)/$(PKG_SOURCE_DIR)
  PKG_FULL_DIR:=$(PKG_BUILD_DIR)
else
  PKG_FULL_DIR:=$(CONFIG_lq-wave-300_5_x_CUSTOM_SOURCE_DIR)
endif

PKG_BUILD_DEPENDS:=libnl3 $(DRV_RFLIB_PKG_NAME) $(PKG_BUILD_DEPENDS_EXTRA)
#PKG_SOURCE_URL:=http://localhost
PKG_DEFAULT_CUSTOM_SOURCE_DIR:=
PKG_NO_AUTORECONF:=y

COPY_SCRIPTS:=n
SCRIPTS_FOLDER:=etc/rc.d
BIN_FOLDER:=bin
BINS_FOLDER:=lib/firmware
#BINS_FOLDER:=root/mtlk/images
IMAGES_FOLDER:=files/root/mtlk/images
DRIVER_FOLDER:=lib/modules/$(LINUX_VERSION)/net
SBIN_FOLDER:=sbin
UBIN_FOLDER:=/usr/bin

ifneq ($(CONFIG_PACKAGE_fapi_wlan_vendor_wave),)
 COPY_SCRIPTS:=
 SCRIPTS_FOLDER=$(VENDOR_PATH)/wave/scripts
 BIN_FOLDER:=$(VENDOR_PATH)/bin
 BINS_FOLDER:=$(VENDOR_PATH)/wave/images
 DRIVER_FOLDER:=$(VENDOR_PATH)/lib/modules/$(LINUX_VERSION)/net
 SBIN_FOLDER:=$(VENDOR_PATH)/sbin
 UBIN_FOLDER:=$(VENDOR_PATH)/usr/bin
endif
ifeq ($(CONFIG_FEATURE_LTQ_WAVE_300),y)
 COPY_WAVE300:=y
 WAVE_CFG_SFX:=
endif
ifeq ($(CONFIG_FEATURE_LTQ_WAVE_400),y)
 COPY_WAVE400:=y
 WAVE_CFG_SFX:=-vbg400
endif

FW_FOLDER:=real_phy_wrx300
ifeq ($(CONFIG_FEATURE_LTQ_WAVE_500),y)
 FW_FOLDER:=real_phy_wrx500
 COPY_WAVE500:=y
 WAVE_CFG_SFX:=-vbg500
 ifeq ($(CONFIG_FEATURE_LTQ_WAVE_FGPA_DUMMY_PHY),y)
  FW_FOLDER:=dummy_phy
 endif
endif

# AR10 must be before WAVE500_PCIE, because the last will override what driver config file to use
# and wave500 supports both AR10 and Wave500 PCIE
ifeq ($(CONFIG_FEATURE_LTQ_WAVE_AR10_SUPPORT),y)
 COPY_AR10:=y
 WAVE_CFG_SFX:=-wave400
endif
ifeq ($(CONFIG_FEATURE_LTQ_WAVE_STA),y)
 COPY_STA:=y
endif

# TODO: Need to revisit the FW_FOLDER parameter when driver supports both.
# e.g. what to do when GRX350 is wrx300 and Wave500 is wrx500
ifeq ($(CONFIG_FEATURE_LTQ_WAVE_500_PCIE),y)
 COPY_WAVE500_PCIE:=y
 WAVE_CFG_SFX:=-wave500
 ifeq ($(CONFIG_TARGET_x86),y)
  WAVE_CFG_SFX:=-wave500-x86
  LINUX_ENV_NAME:=ugw-x86-linux312
 endif
 ifeq ($(COPY_AR10),y)
  WAVE_CFG_SFX:=-wave400_wave500
  ifeq ($(CONFIG_TARGET_lantiq_xrx330),y)
   WAVE_CFG_SFX:=-wave400_wave500_ac1200
  endif
  ifeq ($(CONFIG_TARGET_lantiq_xrx330_EASY330_AC1200_35B),y)
   WAVE_CFG_SFX:=-wave400_wave500_ac1200
  endif
 endif
endif

ifeq ($(CONFIG_PACKAGE_kmod-mac80211),y)
 WAVE_CFG_SFX:=-wave400_wave500_backport
endif

ifeq ($(CONFIG_FEATURE_LTQ_WAVE_500B),y)
 COPY_WAVE500B:=y
endif

ifneq ($(CONFIG_FEATURE_LTQ_WAVE_DEBUG_TFTP_BINS),y)
 REMOVE_TFTP_BINS_SCRIPT:=y
endif

ifeq ($(COPY_SCRIPTS),y)
 WAVE_SCRIPTS_VER:=$(shell hg summ > /dev/null 2>&1 && hg summ | head -n1 | awk '{print $$2}')
endif

PKG_CONFIG_DEPENDS:=CONFIG_PACKAGE_kmod-lantiq-cpufreq
include $(INCLUDE_DIR)/package.mk
-include $(INCLUDE_DIR)/package-version-override.mk

ifeq ($(CONFIG_USE_MUSL),y)
  TARGET_CFLAGS += -DCONFIG_USE_MUSL
  TARGET_CFLAGS += -I$(LINUX_DIR)/user_headers/include/net/ -I$(LINUX_DIR)/user_headers/include/ -I$(LINUX_DIR)/include/
endif


define Package/$(PKG_NAME)
	SECTION:=utils
	CATEGORY:=Lantiq
	TITLE:=Wave scripts/binaries
	DEPENDS:= \
		+PACKAGE_kmod-mac80211:kmod-$(KERNEL_PKG_NAME_BCKPRT_SPPRT) \
		+!PACKAGE_kmod-mac80211:kmod-$(KERNEL_PKG_NAME) \
		+$(DRV_RFLIB_PKG_NAME) \
		+@!NEW_FRAMEWORK:FEATURE_WIRELESS \
		+@!NEW_FRAMEWORK:FEATURE_WIRELESS_WAVE300 \
		+PACKAGE_kmod-ltq_wave500_dp_drv:kmod-ltq_wave500_dp_drv \
		+PACKAGE_kmod-lantiq_directconnect_support:kmod-lantiq_directconnect_support \
		@+PACKAGE_ltq-devm:FEATURE_DEVM_WIFILAN \
		$(DEPENDS_EXTRA) \
		@+BUSYBOX_CONFIG_WC \
		@+BUSYBOX_CONFIG_WHICH \
		@+BUSYBOX_CONFIG_AWK \
		@+BUSYBOX_CONFIG_FEATURE_AWK_MATH \
		@+BUSYBOX_CONFIG_FIND \
		@+BUSYBOX_CONFIG_FEATURE_FIND_MTIME \
		@+BUSYBOX_CONFIG_FEATURE_FIND_PERM \
		@+BUSYBOX_CONFIG_FEATURE_FIND_TYPE \
		@+BUSYBOX_CONFIG_FEATURE_FIND_XDEV \
		@+BUSYBOX_CONFIG_FEATURE_FIND_NEWER \
		@+BUSYBOX_CONFIG_FEATURE_FIND_INUM \
		@+BUSYBOX_CONFIG_XARGS \
		@+PACKAGE_libnl3 \
		@+PACKAGE_libopenssl \
		@+PACKAGE_libuuid \
		@+PACKAGE_uuidgen \
		@+PACKAGE_udev \
		@+PACKAGE_crda_wave \
		@+PACKAGE_hostapd_wave \
		@+PACKAGE_wireless-tools \
		@+PACKAGE_iw_wave
#		@+BUSYBOX_CONFIG_LSMOD 
	URL:=http://www.lantiq.com
	MAINTAINER:=Lantiq Technologies
	MENU:=1
endef

define Package/$(PKG_NAME)/description
 This package contains wave scripts/binaries
endef

define Package/$(DRV_RFLIB_PKG_NAME)
$(call Package/$(PKG_NAME)/Default)
 SECTION:=utils
 CATEGORY:=Lantiq
 TITLE:=RFLIB package for Wave400/Wave500 driver
endef

define Package/$(DRV_RFLIB_PKG_NAME)/description
 This package contains the wave RF library
endef

define KernelPackage/$(KERNEL_PKG_NAME)
 SUBMENU:=Lantiq
 TITLE:=Lantiq Support for Wave WLAN
 DEPENDS:=@TARGET_ltqcpe||TARGET_lantiq||TARGET_x86||TARGET_intel_mips

 KCONFIG:= \
	CONFIG_CRYPTO_SHA256=y \
	CONFIG_FW_LOADER=y \
	CONFIG_HOTPLUG=y \
	CONFIG_WIRELESS=y \
	CONFIG_NL80211_TESTMODE=n \
	CONFIG_CFG80211=y \
	CONFIG_CFG80211_WEXT=y \
	CONFIG_CFG80211_DEVELOPER_WARNINGS=n \
	CONFIG_CFG80211_DEFAULT_PS=y \
	CONFIG_CFG80211_DEBUGFS=n \
	CONFIG_CFG80211_INTERNAL_REGDB=n \
	CONFIG_CFG80211_WEXT_EXPORT=y \
	CONFIG_MAC80211=y \
	CONFIG_MAC80211_RC_MINSTREL=y \
	CONFIG_MAC80211_RC_MINSTREL_HT=y \
	CONFIG_MAC80211_RC_MINSTREL_VHT=n \
	CONFIG_MAC80211_MESH=n \
	CONFIG_MAC80211_LEDS=n \
	CONFIG_MAC80211_DEBUGFS=n \
	CONFIG_MAC80211_DEBUG_MENU=n \
	CONFIG_MAC80211_HWSIM=n \
	CONFIG_LIB80211=y \
	CONFIG_WLAN_VENDOR_INTERSIL=y \
	CONFIG_HOSTAP=y \
	CONFIG_HOSTAP_FIRMWARE=n \
	CONFIG_WILC1000_SPI=n
endef


define KernelPackage/$(KERNEL_PKG_NAME)/description
  Kernel Support for Wave WLAN
endef

define KernelPackage/$(KERNEL_PKG_NAME_BCKPRT_SPPRT)
 SUBMENU:=Lantiq
 TITLE:=Lantiq Support for Wave WLAN
 DEPENDS:=@TARGET_ltqcpe||TARGET_lantiq||TARGET_x86||TARGET_intel_mips

 KCONFIG:= \
	CONFIG_CRYPTO_SHA256=y \
	CONFIG_FW_LOADER=y \
	CONFIG_HOTPLUG=y \
	CONFIG_WIRELESS=y \
	CONFIG_CFG80211_WEXT=y
endef

define KernelPackage/$(KERNEL_PKG_NAME_BCKPRT_SPPRT)/description
  Kernel Support for Wave WLAN
endef


#### Exports ###############################
export THISDIR = $(shell pwd)
export TARGET_CROSS

### Menuconfig #############################
define Package/$(PKG_NAME)/config
$(call Package/$(PKG_NAME)/override_version)
$(call Package/$(PKG_NAME)/override_source_path)
      menu "$(PKG_NAME) features"
      depends on PACKAGE_$(PKG_NAME)
      source "$(SOURCE)/config/Config.in"
      endmenu
endef


#### Target Rules ##########################
# Helper func for downloading rflib tarball:
define Download/files
ifneq ($(4),y)
 define Download/$(1)
  FILE:=$(2)
  URL:=http://localhost/
  MD5SUM:=$(3)
  PROTO:=git
  URL:=git@dev.iopsys.eu:intel/$(1).git
  VERSION:=0315e3d102bbdc7feec87c47fb56bc9232d331d8
  SUBDIR:=$(PKG_SOURCE_SUBDIR)
 endef
 define Prepare/$(1)
	tar -xjf "$(DL_DIR)/$(2)" -C "$(PKG_BUILD_DIR)/.."
 endef
 $$(eval $$(call Download,$(1)))
else
 define Prepare/$(1)
 endef
endif
endef

# Download rflib src tarball
ifneq ($(CONFIG_PACKAGE_$(DRV_RFLIB_PKG_NAME)),)
 ifneq ($(BINARY_PKG),y)
   $(eval $(call Download/files,$(PKG_BASE_NAME)-rflib,$(DRV_RFLIB_PKG_SOURCE),$(DRV_RFLIB_PKG_MD5SUM),,))
 else
   $(eval $(call Download/files,$(PKG_BASE_NAME)-rflib,$(DRV_RFLIB_PKG_BIN),$(DRV_RFLIB_PKG_MD5SUM),$(BUILD_DIR),,))
 endif
endif


define Build/Prepare
	$(call Build/Prepare/Default)
	$(call Prepare/$(PKG_BASE_NAME)-rflib)

ifndef CONFIG_lq-wave-300_5_x_USE_CUSTOM_SOURCE_DIR
	#mv $(BUILD_DIR)/$(PKG_SOURCE_DIR) $(PKG_BUILD_DIR)/
endif
	$(if $(BINARY_PKG),\
		$(INSTALL_DIR) $(PKG_FULL_DIR)/wireless/driver/rflib/prebuilt/;
		cp $(BUILD_DIR)/lq-wave*rflib*bin/ugw_models/$(UGW_MODEL_NAME)/* $(PKG_FULL_DIR)/wireless/driver/rflib/prebuilt/ || true;
	)
	### For iw compilation, copy vendor_cmds.h
	$(CP) $(PKG_FULL_DIR)/wireless/driver/linux/vendor_cmds.h $(STAGING_DIR)/usr/include
endef

define Build/Configure
	rm $(PKG_FULL_DIR)/tools/kconfig/*.o || true
	rm $(PKG_FULL_DIR)/tools/kconfig/*.d || true
	rm $(PKG_FULL_DIR)/tools/kconfig/.config || true
	cp files/config/ugw$(WAVE_CFG_SFX).config $(PKG_FULL_DIR)/ugw.config
	$(if $(BINARY_PKG),\
		echo "CONFIG_USE_PREBUILT_RFLIB=y" >> $(PKG_FULL_DIR)/ugw.config;
		echo "CONFIG_RFLIB_PATH=\"\$$$$(pwd)/../../wireless/driver/rflib/prebuilt\"" >> $(PKG_FULL_DIR)/ugw.config;
	)
	sh -c "cd $(PKG_FULL_DIR); $(MAKE) defconfig PWD=$(PKG_FULL_DIR)/ MINICONFIG=ugw.config APP_TOOLCHAIN_DIR=$(TOPDIR) KERNEL_DIR=$(LINUX_DIR) CPPFLAGS=\"-I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/libnl3\" LDFLAGS=\"-L$(STAGING_DIR)/usr/lib -lnl-genl-3 -lnl-3 -L$(STAGING_DIR)/root-intel_mips/lib -lpthread\""
endef

define Build/Compile
	sh -c "cd $(PKG_FULL_DIR) && $(MAKE) APP_TOOLCHAIN_DIR=$(TOPDIR) KERNEL_DIR=$(LINUX_DIR)"
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) -p $(1)/$(DRIVER_FOLDER)/
	$(INSTALL_DIR) -p $(1)/$(BIN_FOLDER)/
	$(INSTALL_DIR) -p $(1)/$(SBIN_FOLDER)/
	$(INSTALL_DIR) -p $(1)/$(BINS_FOLDER)/
	$(INSTALL_DIR) -p $(1)/$(UBIN_FOLDER)/
	$(INSTALL_DIR) -p $(1)/etc/hotplug/
	$(INSTALL_DIR) -p $(1)/etc/hotplug.d/
	$(INSTALL_DIR) -p $(1)/etc/udev/rules.d/

	# if the /aligned/ exist we are in mixed mode 
	# the image directory is flat and we copy all to $(BINS_FOLDER)

ifneq (,$(wildcard ./$(IMAGES_FOLDER)/aligned/.))
	 $(CP) ./$(IMAGES_FOLDER)/aligned/* $(1)/$(BINS_FOLDER)/
else
	 @echo "aligned dir not exist->legacy mode only"
endif

	# if bin_files.list.mod not exist copy PSD.bin else echo

ifeq ($(wildcard ./$(IMAGES_FOLDER)/PSD/bin_files.list.mod),)
	 $(CP) ./$(IMAGES_FOLDER)/PSD/PSD.bin $(1)/$(BINS_FOLDER)/
else
	@echo "PSD->bin_files-list-mod exist handled in auto mode"
endif

	$(LN) /dev/null $(1)/etc/udev/rules.d/75-persistent-net-generator.rules

	@echo "******* COPY_WAVE500B (y?)-> $(COPY_WAVE500B) ***********"

ifeq ($(COPY_WAVE500B),y)
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/progmodels/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/progmodels/wave500b/FPGA/* $(1)/$(BINS_FOLDER)/ || true
	$(CP) ./$(IMAGES_FOLDER)/progmodels/wave500b/CHIP/* $(1)/$(BINS_FOLDER)/ || true
	$(CP) ./$(IMAGES_FOLDER)/progmodels/wave500/FPGA/* $(1)/$(BINS_FOLDER)/ || true
	@echo "COPY_WAVE500B->progmodels->wave500b in legacy mode or Mixed mode"
 else
	@echo "COPY_WAVE500B->progmodels handled in auto mode"
 endif
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/gen_risc/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/tx_sender_gen5b.bin $(1)/$(BINS_FOLDER)/tx_sender_gen5b.bin
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/host_interface_gen5b.bin $(1)/$(BINS_FOLDER)/host_interface_gen5b.bin
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/host_interface_gen5b_fast_path.bin $(1)/$(BINS_FOLDER)/host_interface_gen5b_fast_path.bin
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/rx_handler_gen5b.bin $(1)/$(BINS_FOLDER)/rx_handler_gen5b.bin
	@echo "COPY_WAVE500B->gen_risc in legacy mode"
 else
	@echo "COPY_WAVE500B->gen_risc handled in auto mode"
 endif
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/fw/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/fw/fw_statistics/mtdump_wave500b.mtidlc $(1)/$(BINS_FOLDER)/mtdump_wave500b.mtidlc || true
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx500/ap_upper_gen5_wrx_500_fpga_real_phy.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/ap_upper_gen5_wrx_500_fpga_real_phy.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx500/ap_lower_gen5_wrx_500_fpga_real_phy.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/ap_lower_gen5_wrx_500_fpga_real_phy.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx500/ap_upper_gen5b_wrx_500_fpga_real_phy.bin.platform.wave500b.fpga $(1)/$(BINS_FOLDER)/ap_upper_gen5b_wrx_500_fpga_real_phy.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx500/ap_lower_gen5b_wrx_500_fpga_real_phy.bin.platform.wave500b.fpga $(1)/$(BINS_FOLDER)/ap_lower_gen5b_wrx_500_fpga_real_phy.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/dummy_phy/ap_upper_gen5_wrx_500_fpga_dummy_phy.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/ap_upper_gen5_wrx_500_fpga_dummy_phy.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/dummy_phy/ap_lower_gen5_wrx_500_fpga_dummy_phy.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/ap_lower_gen5_wrx_500_fpga_dummy_phy.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/dummy_phy/ap_upper_gen5b_wrx_500_fpga_dummy_phy.bin.platform.wave500b.fpga $(1)/$(BINS_FOLDER)/ap_upper_gen5b_wrx_500_fpga_dummy_phy.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/dummy_phy/ap_lower_gen5b_wrx_500_fpga_dummy_phy.bin.platform.wave500b.fpga $(1)/$(BINS_FOLDER)/ap_lower_gen5b_wrx_500_fpga_dummy_phy.bin
	@echo "COPY_WAVE500B->fw in legacy mode"
 else
	@echo "COPY_WAVE500B->fw handled in auto mode"
 endif
else
	@echo "COPY_WAVE500B->N"
endif

	@echo "******* COPY_WAVE500 (y?)-> $(COPY_WAVE500) ***********"

ifeq ($(COPY_WAVE500),y)
	$(CP) ./$(IMAGES_FOLDER)/cal/cal_wlan0.bin $(1)/$(BINS_FOLDER)/cal_wlan0.bin
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/gen_risc/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/tx_sender_gen5.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/tx_sender_gen5.bin
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/host_interface_gen5.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/host_interface_gen5.bin || true
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/rx_handler_gen5.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/rx_handler_gen5.bin || true
	@echo "COPY_WAVE500->gen_risc in legacy mode"
 else
	@echo "COPY_WAVE500->gen_risc handled in auto mode"
 endif
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/fw/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/fw/$(FW_FOLDER)/ap_lower_gen5.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/ap_lower_gen5.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/$(FW_FOLDER)/ap_upper_gen5.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/ap_upper_gen5.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/fw_statistics/mtdump_wave500.mtidlc $(1)/$(BINS_FOLDER)/mtdump_wave500.mtidlc || true
  ifeq ($(COPY_STA),y)
		$(CP) ./$(IMAGES_FOLDER)/fw/$(FW_FOLDER)/sta_upper.bin.platform.wave500.fpga $(1)/$(BINS_FOLDER)/sta_upper_wave500.bin
  endif
	@echo "COPY_WAVE500->fw in legacy mode"
  else
	@echo "COPY_WAVE500->fw handled in auto mode"
 endif
else
	@echo "COPY_WAVE500->N"
endif

	@echo "******* COPY_WAVE500_PCIE (y?)-> $(COPY_WAVE500_PCIE)***********"

ifeq ($(COPY_WAVE500_PCIE),y)
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/progmodels/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/progmodels/wave500/CHIP/* $(1)/$(BINS_FOLDER)/  || true
	@echo "COPY_WAVE500_PCIE->progmodels in legacy mode or mixed mode"
 else
	@echo "COPY_WAVE500_PCIE->progmodels handled in auto mode"
 endif
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/gen_risc/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/tx_sender_gen5.bin $(1)/$(BINS_FOLDER)/tx_sender_gen5.bin
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/host_interface_gen5.bin $(1)/$(BINS_FOLDER)/host_interface_gen5.bin || true
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/host_interface_gen5_fast_path.bin $(1)/$(BINS_FOLDER)/host_interface_gen5_fast_path.bin || true
	$(CP) ./$(IMAGES_FOLDER)/gen_risc/rx_handler_gen5.bin $(1)/$(BINS_FOLDER)/rx_handler_gen5.bin || true
	@echo "COPY_WAVE500_PCIE->gen_risc in legacy mode"
 else
	@echo "COPY_WAVE500_PCIE->gen_risc handled in auto mode"
 endif
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/fw/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx300/ap_lower_gen5.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_lower_gen5.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx300/ap_upper_gen5.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_upper_gen5.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx300/ap_lower_gen5b.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_lower_gen5b.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx300/ap_upper_gen5b.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_upper_gen5b.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx500/ap_lower_gen5.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_lower_gen5_wrx_500.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx500/ap_upper_gen5.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_upper_gen5_wrx_500.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx500/ap_lower_gen5b.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_lower_gen5b_wrx_500.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx500/ap_upper_gen5b.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_upper_gen5b_wrx_500.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx514/ap_lower_gen5.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_lower_gen5_wrx_514.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx514/ap_upper_gen5.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_upper_gen5_wrx_514.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx514/ap_lower_gen5b.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_lower_gen5b_wrx_514.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/real_phy_wrx514/ap_upper_gen5b.bin.platform.wave500.asic $(1)/$(BINS_FOLDER)/ap_upper_gen5b_wrx_514.bin
	$(CP) ./$(IMAGES_FOLDER)/fw/fw_statistics/mtdump_wave500.mtidlc $(1)/$(BINS_FOLDER)/mtdump_wave500.mtidlc || true
	@echo "COPY_WAVE500_PCIE->fw in legacy mode"
 else
	@echo "COPY_WAVE500_PCIE->fw handled in auto mode"
 endif
else
	@echo "COPY_WAVE500_PCIE->N"
endif

	@echo "******* COPY_AR10 (y?)-> $(COPY_AR10)***********"

ifeq ($(COPY_AR10),y)
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/progmodels/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/progmodels/ar10/* $(1)/$(BINS_FOLDER)/ || true
	@echo "COPY_AR10->progmodels in legacy mode or mixed mode"
 else
	@echo "COPY_AR10->progmodels handled in auto mode"
 endif
 ifeq ($(wildcard ./$(IMAGES_FOLDER)/fw/bin_files.list.mod),)
	$(CP) ./$(IMAGES_FOLDER)/fw/fw_statistics/mtdump_wave400.mtidlc $(1)/$(BINS_FOLDER)/mtdump_wave400.mtidlc || true
	$(CP) ./$(IMAGES_FOLDER)/fw/$(FW_FOLDER)/ap_upper_debug.bin.platform.wave400.asic $(1)/$(BINS_FOLDER)/ap_upper_gen4_debug.bin || true
	$(CP) ./$(IMAGES_FOLDER)/fw/$(FW_FOLDER)/ap_upper.bin.platform.wave400.asic $(1)/$(BINS_FOLDER)/ap_upper_gen4.bin
  ifeq ($(COPY_STA),y)
		$(CP) ./$(IMAGES_FOLDER)/fw/$(FW_FOLDER)/sta_upper.bin.platform.wave400.asic $(1)/$(BINS_FOLDER)/sta_upper_gen4.bin
		$(CP) ./$(IMAGES_FOLDER)/fw/$(FW_FOLDER)/sta_upper_debug.bin.platform.wave400.asic $(1)/$(BINS_FOLDER)/sta_upper_gen4_debug.bin || true
  endif
	@echo "COPY_AR10->fw in legacy mode"
 else
	@echo "COPY_AR10->fw handled in auto mode"
 endif
else
	@echo "COPY_AR10->N"
endif

	@echo "******* COPY images completed ***********"

	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/driver/mtlk.ko $(1)/$(DRIVER_FOLDER)/
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/driver/mtlkroot.ko $(1)/$(DRIVER_FOLDER)/
	chmod 555 $(1)/$(DRIVER_FOLDER)/mtlk.ko
	chmod 555 $(1)/$(DRIVER_FOLDER)/mtlkroot.ko
	$(if $(COPY_SCRIPTS),
		$(INSTALL_DIR) -p $(1)/ramdisk_copy/flash/
		$(INSTALL_DIR) -p $(1)/$(SCRIPTS_FOLDER)/
		$(CP) ./files/ramdisk_copy/* $(1)/ramdisk_copy/flash/
		$(CP) ./files/scripts/* $(1)/$(SCRIPTS_FOLDER)/)
	$(if $(REMOVE_TFTP_BINS_SCRIPT),
		rm -f $(1)/$(SCRIPTS_FOLDER)/*_debug_tftp_bins.sh)
	$(CP) ./$(IMAGES_FOLDER)/fw/fw_scd_file.scd $(1)/$(BIN_FOLDER)/ || echo "Skipping fw_scd_file.scd install"
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/driver/*.mtidlc $(1)/$(BIN_FOLDER)/	|| echo "Skipping mtidlc from driver folder install"
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/mttools/*.mtidlc $(1)/$(BIN_FOLDER)/ || echo "Skipping mtidlc from mttools folder install"
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/mttools/drvhlpr $(1)/$(BIN_FOLDER)/	|| echo "Skipping drvhlpr install"
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/mttools/mtdump $(1)/$(UBIN_FOLDER)/ || echo "Skipping mtdump install"
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/mttools/mtlk_cli $(1)/$(BIN_FOLDER)/ || echo "Skipping mtlk_cli install"
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/mttools/BclSockServer $(1)/$(BIN_FOLDER)/ || echo "Skipping BclSockServer install"
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/wls/rtlogger/logserver $(1)/$(BIN_FOLDER)/ || echo "Skipping logserver install"
	$(CP) $(PKG_FULL_DIR)/builds/$(LINUX_ENV_NAME)/binaries/dut/dutserver $(1)/$(BIN_FOLDER)/ || echo "Skipping Dutserver install"
	./files/config/mtidlc-generator.sh $(1)/$(BIN_FOLDER)/ || echo "Skipping generation of minimized mtidlc files"

	chmod 555 $(1)/$(BIN_FOLDER)/drvhlpr || true
	chmod 555 $(1)/$(BIN_FOLDER)/*.mtidlc* || true
	chmod 555 $(1)/$(UBIN_FOLDER)/mtdump || true
	chmod 555 $(1)/$(BIN_FOLDER)/mtlk_cli || true
	chmod 555 $(1)/$(BIN_FOLDER)/BclSockServer || true
	chmod 555 $(1)/$(BIN_FOLDER)/logserver || true
	chmod 555 $(1)/$(BIN_FOLDER)/dutserver || true
	$(CP) ./files/binaries/sbin/* $(1)/$(SBIN_FOLDER)/
	$(CP) ./files/etc/* $(1)/etc/
	echo -e "wave_release_minor=\"$(PKG_VERSION)\"\nwave_mac_ver=\"$(FW_VERSION)\"\nwave_psd_ver=\"$(WAVE_PSD_VER)\"\nwave_driver_ver=\"$(DRV_VERSION)\"" > $(1)/etc/wave_components.ver
	$(if $(COPY_SCRIPTS),
		echo -e "wave_scripts_ver=\"$(WAVE_SCRIPTS_VER)\"" >> $(1)/etc/wave_components.ver)
	$(if $(COPY_WAVE500),
		echo -e "wave_fpga_sim_ver=\"$(FPGA_SIM_VERSION)\"\nwave500_progmodel_ver=\"$(PROGMODEL_VERSION_WAVE500)\"\nwave_tx_sender_ver=\"$(TX_SENDER_VERSION)\"\nwave_host_interface_ver=\"$(HOST_INTERFACE_VERSION)\"\nwave_rx_handler_ver=\"$(RX_HANDLER_VERSION)\"" >> $(1)/etc/wave_components.ver)
	$(if $(COPY_WAVE500_PCIE),
		echo -e "wave500_progmodel_ver=\"$(PROGMODEL_VERSION_WAVE500)\"\nwave_tx_sender_ver=\"$(TX_SENDER_VERSION)\"\nwave_host_interface_ver=\"$(HOST_INTERFACE_VERSION)\"\nwave_rx_handler_ver=\"$(RX_HANDLER_VERSION)\"" >> $(1)/etc/wave_components.ver)
	$(if $(COPY_WAVE500B),
		echo -e "wave500B_progmodel_ver=\"$(PROGMODEL_VERSION_GEN5B)\"\nwave_tx_sender_gen5b_ver=\"$(TX_SENDER_GEN5B_VERSION)\"\nwave_host_interface_gen5b_ver=\"$(HOST_INTERFACE_GEN5B_VERSION)\"\nwave_rx_handler_gen5b_ver=\"$(RX_HANDLER_GEN5B_VERSION)\"" >> $(1)/etc/wave_components.ver)
	$(if $(COPY_AR10),
		echo -e "wave_ar10_progmodel_ver=\"$(PROGMODEL_VERSION_AR10)\"" >> $(1)/etc/wave_components.ver)
endef

$(eval $(call BuildPackage,$(DRV_RFLIB_PKG_NAME)))
$(eval $(call BuildPackage,$(PKG_NAME)))
$(eval $(call KernelPackage,$(KERNEL_PKG_NAME)))
$(eval $(call KernelPackage,$(KERNEL_PKG_NAME_BCKPRT_SPPRT)))
