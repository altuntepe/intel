-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

-- Data init --

local fs  = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

if not uci:get("network", "wan") then
	uci:section("network", "interface", "wan", {proto="none", ifname=" "})
	uci:save("network")
	uci:commit("network")
end

local wlcursor = luci.model.uci.cursor_state()
local wireless = wlcursor:get_all("wireless")
local wifidevs = {}
local ifaces = {}

for k, v in pairs(wireless) do
	if v[".type"] == "wifi-iface" then
		table.insert(ifaces, v)
	end
end

wlcursor:foreach("wireless", "wifi-device",
	function(section)
		table.insert(wifidevs, section[".name"])
	end)


-- Main Map --

m = Map("wireless", translate("Wifi"), translate("Here you can configure installed wifi devices."))
m:chain("network")


-- Status Table --
s = m:section(Table, ifaces, translate("Networks"))

if false then --radio parameter, should not be displayed for VIF
	link = s:option(DummyValue, "_link", translate("Link"))
	function link.cfgvalue(self, section)
		local ifname = self.map:get(section, "ifname")
		local iwinfo = sys.wifi.getiwinfo(ifname)
		return iwinfo and "%d/%d" %{ iwinfo.quality, iwinfo.quality_max } or "-"
	end
end

essid = s:option(DummyValue, "ssid", "ESSID")

bssid = s:option(DummyValue, "_bsiid", "BSSID")
function bssid.cfgvalue(self, section)
	return wireless[self.map:get(section, "device")].macaddr
end

channel = s:option(DummyValue, "channel", translate("Channel"))
function channel.cfgvalue(self, section)
	return wireless[self.map:get(section, "device")].channel
end

if hwtype == "intel_ap" then
	function channel.write(self, section, value)
		local hwmd= m.uci:get("wireless", section, "hwmode")
		if hwmd and (hwmd == "11a" or hwmd == "11bg" or hwmd == "11b") then
			m.uci:set("wireless", section, "htmode", "HT20")
		elseif hwmd and (hwmd == "11an" or hwmd == "11bgn") then
			m.uci:set("wireless", section, "htmode", "HT40")
		elseif hwmd and (hwmd == "11anac") then
			m.uci:set("wireless", section, "htmode", "VHT80")
		end
		m:set(section, "channel", value)
	end
end

if false then --radio parameter, should not be displayed for VIF
	protocol = s:option(DummyValue, "_mode", translate("Protocol"))
	function protocol.cfgvalue(self, section)
		local mode = wireless[self.map:get(section, "device")].mode
		return mode and "802." .. mode
	end
end
mode = s:option(DummyValue, "mode", translate("Mode"))
encryption = s:option(DummyValue, "encryption", translate("<abbr title=\"Encrypted\">Encr.</abbr>"))

if false then --radio parameter, should not be displayed for VIF
power = s:option(DummyValue, "_power", translate("Power"))
	function power.cfgvalue(self, section)
		local ifname = self.map:get(section, "ifname")
		local iwinfo = sys.wifi.getiwinfo(ifname)
		return iwinfo and "%d dBm" % iwinfo.txpower or "-"
	end
end

if false then -- should not display for AP
	scan = s:option(Button, "_scan", translate("Scan"))
	scan.inputstyle = "find"

	function scan.cfgvalue(self, section)
		return self.map:get(section, "ifname") or false
	end

	-- WLAN-Scan-Table --

	t2 = m:section(Table, {}, translate("<abbr title=\"Wireless Local Area Network\">WLAN</abbr>-Scan"), translate("Wifi networks in your local environment"))

	function scan.write(self, section)
		m.autoapply = false
		t2.render = t2._render
		local ifname = self.map:get(section, "ifname")
		local iwinfo = sys.wifi.getiwinfo(ifname)
		if iwinfo then
			local _, cell
			for _, cell in ipairs(iwinfo.scanlist) do
				t2.data[#t2.data+1] = {
					Quality = "%d/%d" %{ cell.quality, cell.quality_max },
					ESSID   = cell.ssid,
					Address = cell.bssid,
					Mode    = cell.mode,
					["Encryption key"] = cell.encryption.enabled and "On" or "Off",
					["Signal level"]   = "%d dBm" % cell.signal,
					["Noise level"]    = "%d dBm" % iwinfo.noise
				}
			end
		end
	end


	t2._render = t2.render
	t2.render = function() end

	t2:option(DummyValue, "Quality", translate("Link"))
	essid = t2:option(DummyValue, "ESSID", "ESSID")
	function essid.cfgvalue(self, section)
		return self.map:get(section, "ESSID")
	end

	t2:option(DummyValue, "Address", "BSSID")
	t2:option(DummyValue, "Mode", translate("Mode"))
	chan = t2:option(DummyValue, "channel", translate("Channel"))
	function chan.cfgvalue(self, section)
		return self.map:get(section, "Channel")
		    or self.map:get(section, "Frequency")
		    or "-"
	end

	t2:option(DummyValue, "Encryption key", translate("<abbr title=\"Encrypted\">Encr.</abbr>"))

	t2:option(DummyValue, "Signal level", translate("Signal"))

	t2:option(DummyValue, "Noise level", translate("Noise"))
end


if #wifidevs < 1 then
	return m
end

-- Config Section --

--s = m:section(NamedSection, wifidevs[1], "wifi-device", translate("Devices"))
s = m:section(TypedSection, "wifi-device", translate("Devices"))
s.addremove = false

en = s:option(Flag, "disabled", translate("enable"))
en.rmempty = false
en.enabled = "0"
en.disabled = "1"

function en.cfgvalue(self, section)
	return Flag.cfgvalue(self, section) or "0"
end

local hwtype = m:get(wifidevs[1], "type")
if hwtype == "atheros" then
	hw_mode = s:option(ListValue, "hwmode", translate("Mode"))
	hw_mode.override_values = true
	hw_mode:value("", "auto")
	hw_mode:value("11b", "802.11b")
	hw_mode:value("11g", "802.11g")
	hw_mode:value("11a", "802.11a")
	hw_mode:value("11bg", "802.11b+g")
	hw_mode.rmempty = true
elseif hwtype == "intel_ap" then
	hw_mode = s:option(ListValue, "hwmode", translate("Mode"))
	hw_mode.override_values = true
	hw_mode:value("11b", "802.11b", {hwmode="11b"},{hwmode="11bg"},{hwmode="11bgn"})
	hw_mode:value("11bg", "802.11bg", {hwmode="11b"},{hwmode="11bg"},{hwmode="11bgn"})
	hw_mode:value("11bgn", "802.11bgn", {hwmode="11b"},{hwmode="11bg"},{hwmode="11bgn"})
	hw_mode:value("11a", "802.11a", {hwmode="11a"},{hwmode="11an"},{hwmode="11anac"})
	hw_mode:value("11an", "802.11an", {hwmode="11a"},{hwmode="11an"},{hwmode="11anac"})
	hw_mode:value("11anac", "802.11anac", {hwmode="11a"},{hwmode="11an"},{hwmode="11anac"})

	function hw_mode.write(self, section, value)
		if value and (value == "11a" or value == "11bg" or value == "11b") then
			m.uci:set("wireless", section, "htmode", "HT20")
		elseif value and (value == "11an" or value == "11bgn") then
			m.uci:set("wireless", section, "htmode", "HT40")
		elseif value and (value == "11anac") then
			m.uci:set("wireless", section, "htmode", "VHT80")
		end
		return Value.write(self, section, value)
	end
end

if hwtype == "intel_ap" then
	ch = s:option(ListValue, "channel", translate("Channel"))
        ch:value("auto", "auto")
	for j=1, #wifidevs do
		local iwinfo = sys.wifi.getiwinfo(wifidevs[j])
		for i=1, #iwinfo.freqlist do
			if iwinfo.freqlist[i].mhz <= 2484 then
				ch:value(iwinfo.freqlist[i].channel, 
					iwinfo.freqlist[i].channel .. " (freq " 
					.. iwinfo.freqlist[i].mhz .. ")" 
					, {hwmode="11b"},{hwmode="11bg"},{hwmode="11bgn"})
			else
				ch:value(iwinfo.freqlist[i].channel, 
				iwinfo.freqlist[i].channel .. " (freq " 
				.. iwinfo.freqlist[i].mhz .. ")" 
				, {hwmode="11a"},{hwmode="11an"},{hwmode="11anac"})
			end
		end
	end
	
else	
	for i=1, 14 do
		ch:value(i, i .. " (2.4 GHz)")
	end
end

s = m:section(TypedSection, "wifi-iface", translate("Local Network"))
s.anonymous = true
s.addremove = false

s:option(Value, "ssid", translate("Network Name (<abbr title=\"Extended Service Set Identifier\">ESSID</abbr>)"))

bssid = s:option(Value, "macaddr", translate("<abbr title=\"Basic Service Set Identifier\">BSSID</abbr>"))

local devs = {}
luci.model.uci.cursor():foreach("wireless", "wifi-device",
	function (section)
		table.insert(devs, section[".name"])
	end)

if #devs > 1 then
	device = s:option(DummyValue, "device", translate("Device"))
else
	s.defaults.device = devs[1]
end

if hwtype ~= "intel_ap" then
	mode = s:option(ListValue, "mode", translate("Mode"))
	mode.override_values = true
	mode:value("ap", translate("Provide (Access Point)"))
	mode:value("adhoc", translate("Independent (Ad-Hoc)"))
	mode:value("sta", translate("Join (Client)"))
else
	device = s:option(DummyValue, "mode", translate("Mode"))
end

function mode.write(self, section, value)
	if value == "sta" then
		local oldif = m.uci:get("network", "wan", "ifname")
		if oldif and oldif ~= " " then
			m.uci:set("network", "wan", "_ifname", oldif)
		end
		m.uci:set("network", "wan", "ifname", " ")

		self.map:set(section, "network", "wan")
	else
		if m.uci:get("network", "wan", "_ifname") then
			m.uci:set("network", "wan", "ifname", m.uci:get("network", "wan", "_ifname"))
		end
		self.map:set(section, "network", "lan")
	end

	return ListValue.write(self, section, value)
end

encr = s:option(ListValue, "encryption", translate("Encryption"))
encr.override_values = true
encr:value("none", "No Encryption")
encr:value("wep", "WEP")

if hwtype == "atheros" or hwtype == "mac80211" then
	local supplicant = fs.access("/usr/sbin/wpa_supplicant")
	local hostapd    = fs.access("/usr/sbin/hostapd")

	if hostapd and supplicant then
		encr:value("psk", "WPA-PSK")
		encr:value("psk2", "WPA2-PSK")
		encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode")
		encr:value("wpa", "WPA-Radius", {mode="ap"}, {mode="sta"})
		encr:value("wpa2", "WPA2-Radius", {mode="ap"}, {mode="sta"})
	elseif hostapd and not supplicant then
		encr:value("psk", "WPA-PSK", {mode="ap"}, {mode="adhoc"})
		encr:value("psk2", "WPA2-PSK", {mode="ap"}, {mode="adhoc"})
		encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode", {mode="ap"}, {mode="adhoc"})
		encr:value("wpa", "WPA-Radius", {mode="ap"})
		encr:value("wpa2", "WPA2-Radius", {mode="ap"})
		encr.description = translate(
			"WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..
			"and ad-hoc mode) to be installed."
		)
	elseif not hostapd and supplicant then
		encr:value("psk", "WPA-PSK", {mode="sta"})
		encr:value("psk2", "WPA2-PSK", {mode="sta"})
		encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode", {mode="sta"})
		encr:value("wpa", "WPA-EAP", {mode="sta"})
		encr:value("wpa2", "WPA2-EAP", {mode="sta"})
		encr.description = translate(
			"WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..
			"and ad-hoc mode) to be installed."
		)		
	else
		encr.description = translate(
			"WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..
			"and ad-hoc mode) to be installed."
		)
	end
elseif hwtype == "broadcom" then
	encr:value("psk", "WPA-PSK")
	encr:value("psk2", "WPA2-PSK")
	encr:value("psk+psk2", "WPA-PSK/WPA2-PSK Mixed Mode")
elseif hwtype == "intel_ap" then
	encr:value("psk+tkip", "WPA - Personal")
	encr:value("wpa+tkip", "WPA - Enterprise")
	encr:value("psk2+aes", "WPA2-PSK")
	encr:value("wpa2+aes", "WPA2 - Enterprise")
	encr:value("psk-mixed+tkip+aes", "WPA-PSK/WPA2-PSK Mixed Mode - Personal")
	encr:value("wpa-mixed+tkip+aes", "WPA/WPA2 Mixed Mode - Enterprise")
end

key = s:option(Value, "key", translate("Key"))
if hwtype ~= "intel_ap" then
	key:depends("encryption", "wep")
	key:depends("encryption", "psk")
	key:depends("encryption", "psk2")
	key:depends("encryption", "psk+psk2")
	key:depends("encryption", "psk-mixed")
	key:depends({mode="ap", encryption="wpa"})
	key:depends({mode="ap", encryption="wpa2"})
else
	key:depends("encryption", "psk+tkip")
	key:depends("encryption", "psk2+aes")
	key:depends("encryption", "psk-mixed+tkip+aes")
	key.rmempty = true
end
key.password = true

if hwtype == "intel_ap" then
	key.cfgvalue = function(self, section, value)
		local old_enc = m.uci:get("wireless", section, "encryption")
		if old_enc ~= "psk2+aes"  and old_enc ~= "psk+tkip" and old_enc ~= "psk-mixed+tkip+aes" then
			return nil
		end
		local key_val = m.uci:get("wireless", section, "key")
		if key_val == "1" or key_val == "2" or key_val == "3" or key_val == "4" then
			return nil
		end
		return key_val
	end

	local slot=1
	wepkey = s:option(Value, "key" .. slot, translate("WEP Key"))
	wepkey:depends("encryption", "wep-open")
	wepkey:depends("encryption", "wep")
	wepkey.rmempty = true
	wepkey.password = true
	function wepkey.write(self, section, value)
		if value and (#value == 10 or #value == 26) then
			value = value
			--Always set key (used to indicate key index for WEP)
			--to 1. Only 1 key is supported.
			m.uci:set("wireless", section, "key", "1")
		end
		return Value.write(self, section, value)
	end
end

server = s:option(Value, "server", translate("Radius-Server"))
server:depends({mode="ap", encryption="wpa"})
server:depends({mode="ap", encryption="wpa2"})
if hwtype == "intel_ap" then
	server:depends({encryption="wpa+tkip"})
	server:depends({encryption="wpa2+aes"})
	server:depends({encryption="wpa-mixed+tkip+aes"})
end
server.rmempty = true

port = s:option(Value, "port", translate("Radius-Port"))
port:depends({mode="ap", encryption="wpa"})
port:depends({mode="ap", encryption="wpa2"})
if hwtype == "intel_ap" then
	port:depends({encryption="wpa+tkip"})
	port:depends({encryption="wpa2+aes"})
	port:depends({encryption="wpa-mixed+tkip+aes"})
end
port.rmempty = true

if hwtype == "intel_ap" then
	auth_secret = s:option(Value, "auth_secret", translate("Radius-Authentication-Secret"))
	auth_secret:depends({encryption="wpa+tkip"})
	auth_secret:depends({encryption="wpa2+aes"})
	auth_secret:depends({encryption="wpa-mixed+tkip+aes"})
	auth_secret.rmempty = true
	auth_secret.password = true
	
	--For enterprise mode 'key' is used for radius secret
	--auth_secret is just a dummy and will not be set in conf file
	auth_secret.cfgvalue = function(self, section, value)
		local old_enc = m.uci:get("wireless", section, "encryption")
		if old_enc ~= "wpa2+aes" and old_enc ~= "wpa+tkip" and old_enc ~= "wpa-mixed+tkip+aes" then
			return nil
		end
		local key_val = m.uci:get("wireless", section, "key")
		if key_val == "1" or key_val == "2" or key_val == "3" or key_val == "4" then
			return nil
		end
		return key_val
	end
	
	function auth_secret.write(self, section, value)
		m.uci:set("wireless", section, "key", value)
		self.map.uci:delete("wireless", section, "key1")
		return
	end
end

if hwtype == "atheros" or hwtype == "mac80211" then
	nasid = s:option(Value, "nasid", translate("NAS ID"))
	nasid:depends({mode="ap", encryption="wpa"})
	nasid:depends({mode="ap", encryption="wpa2"})
	nasid.rmempty = true

	eaptype = s:option(ListValue, "eap_type", translate("EAP-Method"))
	eaptype:value("TLS")
	eaptype:value("TTLS")
	eaptype:value("PEAP")
	eaptype:depends({mode="sta", encryption="wpa"})
	eaptype:depends({mode="sta", encryption="wpa2"})

	cacert = s:option(FileUpload, "ca_cert", translate("Path to CA-Certificate"))
	cacert:depends({mode="sta", encryption="wpa"})
	cacert:depends({mode="sta", encryption="wpa2"})

	privkey = s:option(FileUpload, "priv_key", translate("Path to Private Key"))
	privkey:depends({mode="sta", eap_type="TLS", encryption="wpa2"})
	privkey:depends({mode="sta", eap_type="TLS", encryption="wpa"})

	privkeypwd = s:option(Value, "priv_key_pwd", translate("Password of Private Key"))
	privkeypwd:depends({mode="sta", eap_type="TLS", encryption="wpa2"})
	privkeypwd:depends({mode="sta", eap_type="TLS", encryption="wpa"})


	auth = s:option(Value, "auth", translate("Authentication"))
	auth:value("PAP")
	auth:value("CHAP")
	auth:value("MSCHAP")
	auth:value("MSCHAPV2")
	auth:depends({mode="sta", eap_type="PEAP", encryption="wpa2"})
	auth:depends({mode="sta", eap_type="PEAP", encryption="wpa"})
	auth:depends({mode="sta", eap_type="TTLS", encryption="wpa2"})
	auth:depends({mode="sta", eap_type="TTLS", encryption="wpa"})


	identity = s:option(Value, "identity", translate("Identity"))
	identity:depends({mode="sta", eap_type="PEAP", encryption="wpa2"})
	identity:depends({mode="sta", eap_type="PEAP", encryption="wpa"})
	identity:depends({mode="sta", eap_type="TTLS", encryption="wpa2"})
	identity:depends({mode="sta", eap_type="TTLS", encryption="wpa"})

	password = s:option(Value, "password", translate("Password"))
	password:depends({mode="sta", eap_type="PEAP", encryption="wpa2"})
	password:depends({mode="sta", eap_type="PEAP", encryption="wpa"})
	password:depends({mode="sta", eap_type="TTLS", encryption="wpa2"})
	password:depends({mode="sta", eap_type="TTLS", encryption="wpa"})
end


if hwtype == "atheros" or hwtype == "broadcom" then
	iso = s:option(Flag, "isolate", translate("AP-Isolation"), translate("Prevents Client to Client communication"))
	iso.rmempty = true
	iso:depends("mode", "ap")

	hide = s:option(Flag, "hidden", translate("Hide <abbr title=\"Extended Service Set Identifier\">ESSID</abbr>"))
	hide.rmempty = true
	hide:depends("mode", "ap")
end

if hwtype == "intel_ap" then
	iso = s:option(Flag, "isolate", translate("AP-Isolation"), translate("Prevents Client to Client communication"))
	iso:depends("mode", "ap")
	iso.rmempty = false
	
	hide = s:option(Flag, "hidden", translate("Hide <abbr title=\"Extended Service Set Identifier\">ESSID</abbr>"))
	hide:depends("mode", "ap")
	hide.rmempty = false 
end

if hwtype == "mac80211" or hwtype == "atheros" then
	bssid:depends({mode="adhoc"})
end

if hwtype == "broadcom" then
	bssid:depends({mode="wds"})
	bssid:depends({mode="adhoc"})
end


return m
