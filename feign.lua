-- YaHT Feign Death resist alert: a separate, movable warning (the red-rimmed Feign Death
-- icon with "RESIST" under it) with a warning sound, for the moment a mob
-- doesn't fall for it. Forever blocks the combat log, so three other signals
-- are watched for a few seconds after you feign:
--   1. the game's own "Resisted" message (the red text in the middle)
--   2. you lose health while lying there (something is still hitting you)
--   3. your target is still targeting you a moment later
-- With /yaht debug on, every signal is logged, so a test shows which ones
-- Forever really sends.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end
local function Plain(v) if IsSecret(v) then return nil end return v end

local FEIGN_ID = 5384
local FALLBACK_ICON = "Interface\\Icons\\Ability_Rogue_FeignDeath"
local WATCH = 3          -- seconds after feigning to watch for a resist
local HIT_GRACE = 0.25   -- health changes this soon after feigning still count as before it
-- your target must still be on you at both moments (a mob that's only slow to
-- turn away after a good feign has let go by the second look)
local TARGET_CHECKS = {1.5, 2.5}
local ICON = 40          -- icon size at 100% scale
local SHAKE_TIME = 0.35
local FADE_IN, FADE_OUT = 0.08, 0.5

local alert, watch
local feignName

-- the global "Resisted" message for Feign Death, when the client has it
local function IsResistMessage(msg)
	msg = Plain(msg)
	if type(msg) ~= "string" then return false end
	if ERR_FEIGN_DEATH_RESISTED and msg == ERR_FEIGN_DEATH_RESISTED then return true end
	return msg:lower():find("resist", 1, true) ~= nil
end

local function Health()
	if not UnitHealth then return nil end
	local ok, h = pcall(UnitHealth, "player")
	if not ok then return nil end
	return Plain(h)
end

local function Feigned()
	if not UnitIsFeignDeath then return nil end
	local ok, v = pcall(UnitIsFeignDeath, "player")
	if not ok then return nil end
	return Plain(v)
end

local function TargetStillOnYou()
	if not (UnitExists and UnitCanAttack and UnitIsUnit) then return nil end
	local exists = Plain(UnitExists("target"))
	local hostile = Plain(UnitCanAttack("player", "target"))
	if not exists or not hostile then return nil end
	if UnitIsDead then
		local dead = UnitIsDead("target")
		if IsSecret(dead) or dead then return nil end
	end
	local ok, onYou = pcall(UnitIsUnit, "targettarget", "player")
	if not ok then return nil end
	return Plain(onYou)
end

local function Log(msg)
	if YaHT.debug then YaHT:Print("FD: " .. msg) end
end

---------------------------------------------------------------------------
-- The alert
---------------------------------------------------------------------------
local function ShowAlert(reason)
	local p = YaHT.db.profile
	if not p.feign then return end
	alert.shownAt = GetTime()
	alert.reason = reason
	alert:Show()
	if p.feignsound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING, "Master") end
end

local function AlertUpdate(self, elapsed)
	local p = YaHT.db.profile
	local now = GetTime()
	local preview = not p.lock
	local want, t = 0, nil
	if preview then
		want = 1
	elseif self.shownAt then
		t = now - self.shownAt
		if t < p.feigntime then want = 1 end
	end
	local a = self.fade or 0
	if a < want then
		a = math.min(want, a + elapsed / FADE_IN)
	elseif a > want then
		a = math.max(want, a - elapsed / FADE_OUT)
	end
	self.fade = a
	self:SetAlpha(a)
	self.dragHint:SetShown(preview)
	if a <= 0 and want <= 0 then
		self.shownAt = nil
		self:Hide()
		return
	end
	-- one shake and a pop as it appears, then the text pulses
	local shake, k = 0, 1
	if t and t < SHAKE_TIME then
		local g = 1 - t / SHAKE_TIME
		shake = math.sin(t * 70) * 7 * g
		k = 1 + 0.3 * g
	end
	self.content:ClearAllPoints()
	self.content:SetPoint("CENTER", self, "CENTER", shake, 0)
	if self.drawnK ~= k then
		self.drawnK = k
		local s = ICON * p.feignscale * k
		self.icon:SetSize(s, s)
		self.rim:SetSize(s + 3, s + 3)
	end
	local pulse = t and (0.7 + 0.3 * math.sin(t * 9)) or 1
	self.text:SetAlpha(pulse)
	self.halo:SetAlpha(0.4 + 0.4 * pulse)
end

function YaHT:ApplyFeignSettings()
	if not alert then return end
	local p = self.db.profile
	local s = p.feignscale
	alert:ClearAllPoints()
	if p.feignpoint then
		alert:SetPoint(p.feignpoint, UIParent, p.feignrelpoint, p.feignx, p.feigny)
	else
		alert:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	end
	-- the icon, with "RESIST" right under it
	local c = p.feigncolor
	local font = self:GetMedia("font", p.font) or STANDARD_TEXT_FONT
	local size = math.max(10, math.floor(15 * s))
	if not alert.text:SetFont(font, size, "OUTLINE") then alert.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
	alert.text:SetTextColor(c.r, c.g, c.b)
	alert.rim:SetVertexColor(c.r, c.g, c.b)
	alert.halo:SetVertexColor(c.r, c.g, c.b)
	alert.halo:SetSize(ICON * s * 2.4, ICON * s * 2.4)
	alert.icon:ClearAllPoints()
	alert.icon:SetPoint("TOP", alert.content, "TOP", 0, 0)
	alert.text:ClearAllPoints()
	alert.text:SetPoint("TOP", alert.icon, "BOTTOM", 0, -3)
	local w, h = math.max(ICON * s, size * 4), ICON * s + 3 + size + 2
	alert:SetSize(w, h)
	alert.content:SetSize(w, h)
	alert.drawnK = nil
	alert:EnableMouse(not p.lock)
	if not p.feign then
		alert.fade = 0 alert:SetAlpha(0) alert:Hide()
	elseif not p.lock then
		alert:Show() -- unlocked: show it so you can drag it into place
	end
end

-- /yaht feign or the options' Test button: play the alert once
function YaHT:TestFeignAlert()
	if alert then ShowAlert("test") end
end

local function CreateAlert()
	local f = CreateFrame("Frame", "YaHTFeignFrame", UIParent)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p = YaHT.db.profile
		local _
		p.feignpoint, _, p.feignrelpoint, p.feignx, p.feigny = self:GetPoint()
	end)
	f.content = CreateFrame("Frame", nil, f)
	f.content:SetPoint("CENTER")
	local c = f.content
	f.halo = c:CreateTexture(nil, "BACKGROUND")
	f.halo:SetTexture("Interface\\AddOns\\YaHT\\media\\Glow")
	f.halo:SetBlendMode("ADD")
	f.rim = c:CreateTexture(nil, "BORDER")
	f.rim:SetTexture("Interface\\Buttons\\WHITE8X8")
	f.icon = c:CreateTexture(nil, "ARTWORK")
	local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(FEIGN_ID)
	if IsSecret(tex) or not tex then tex = FALLBACK_ICON end
	f.icon:SetTexture(tex)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.rim:SetPoint("CENTER", f.icon, "CENTER")
	f.halo:SetPoint("CENTER", f.icon, "CENTER")
	f.text = c:CreateFontString(nil, "OVERLAY")
	-- WoW refuses text on a font string without a font: set one first (Apply picks the real one)
	f.text:SetFont(STANDARD_TEXT_FONT or "Fonts\FRIZQT__.TTF", 15, "OUTLINE")
	f.text:SetText(L["RESIST"])
	-- shown only while unlocked, so you know what you're dragging
	f.dragHint = f:CreateFontString(nil, "OVERLAY")
	f.dragHint:SetPoint("TOP", f, "BOTTOM", 0, -2)
	f.dragHint:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
	f.dragHint:SetTextColor(0.8, 0.8, 0.8)
	f.dragHint:SetText(L["Feign Death resist alert (drag me)"])
	f.dragHint:Hide()
	f.fade = 0
	f:SetAlpha(0)
	f:Hide()
	f:SetScript("OnUpdate", function(self, elapsed)
		local ok, err = pcall(AlertUpdate, self, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError("FeignUpdate", err) end
	end)
	return f
end

---------------------------------------------------------------------------
-- Watching for a resist, for a few seconds after each Feign Death
---------------------------------------------------------------------------
local function Resisted(reason)
	if not watch.active or watch.resisted then return end
	watch.resisted = true
	Log(string.format("RESISTED (%s) %.2fs after feigning", reason, GetTime() - watch.at))
	ShowAlert(reason)
end

local function StartWatch()
	watch.active, watch.resisted, watch.targetChecks, watch.stillOnYou = true, false, 0, true
	watch.at = GetTime()
	watch.health = Health()
	Log(string.format("cast | health %s | feigned %s | in combat %s", tostring(watch.health),
		tostring(Feigned()), tostring(Plain(InCombatLockdown and InCombatLockdown()))))
	watch:Show()
end

local function WatchUpdate(self)
	if not self.active then self:Hide() return end
	local t = GetTime() - self.at
	local nextCheck = TARGET_CHECKS[self.targetChecks + 1]
	if nextCheck and t >= nextCheck then
		self.targetChecks = self.targetChecks + 1
		local onYou = TargetStillOnYou()
		Log(string.format("%.1fs: target on you %s | feigned %s | in combat %s", t, tostring(onYou),
			tostring(Feigned()), tostring(Plain(InCombatLockdown and InCombatLockdown()))))
		if not onYou then self.stillOnYou = false end
		if self.targetChecks == #TARGET_CHECKS and self.stillOnYou and YaHT.db.profile.feigntargetcheck then
			Resisted("your target stayed on you")
		end
	end
	if t >= WATCH then
		Log(string.format("%.0fs: done | %s | in combat %s", WATCH, self.resisted and "resisted" or "no resist seen",
			tostring(Plain(InCombatLockdown and InCombatLockdown()))))
		self.active = false
		self:Hide()
	end
end

local function OnEvent(self, event, ...)
	if not YaHT.db then return end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellID = ...
		if unit ~= "player" then return end
		spellID = Plain(spellID)
		feignName = feignName or YaHT.GetSpellName(FEIGN_ID)
		local isFeign = spellID == FEIGN_ID
		if not isFeign and spellID and feignName then isFeign = YaHT.GetSpellName(spellID) == feignName end
		if isFeign then StartWatch() end
	elseif not self.active then
		return
	elseif event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
		local _, msg = ...
		Log(string.format("%s: %s", event == "UI_ERROR_MESSAGE" and "error" or "info", tostring(Plain(msg) or "(hidden)")))
		if IsResistMessage(msg) then Resisted("the game said resisted") end
	elseif event == "UNIT_HEALTH" then
		local unit = ...
		if unit ~= "player" then return end
		local h = Health()
		local t = GetTime() - self.at
		Log(string.format("health %s at %.2fs | feigned %s", tostring(h), t, tostring(Feigned())))
		if h and self.health and h < self.health and t > HIT_GRACE and Feigned() ~= false
			and YaHT.db.profile.feignhitcheck then
			Resisted("you were hit while feigned")
		end
		if h then self.health = h end
	elseif event == "PLAYER_REGEN_ENABLED" then
		Log(string.format("left combat %.2fs after feigning", GetTime() - self.at))
	end
end

function YaHT:InitFeign()
	alert = CreateAlert()
	self.feignFrame = alert
	watch = CreateFrame("Frame")
	self.feignWatch = watch
	for _, e in ipairs({"UI_ERROR_MESSAGE", "UI_INFO_MESSAGE", "PLAYER_REGEN_ENABLED"}) do
		pcall(watch.RegisterEvent, watch, e)
	end
	pcall(watch.RegisterUnitEvent, watch, "UNIT_SPELLCAST_SUCCEEDED", "player")
	pcall(watch.RegisterUnitEvent, watch, "UNIT_HEALTH", "player")
	watch:SetScript("OnEvent", function(self, event, ...)
		local ok, err = pcall(OnEvent, self, event, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError("FeignEvent", err) end
	end)
	watch:SetScript("OnUpdate", function(self)
		local ok, err = pcall(WatchUpdate, self)
		if not ok and YaHT.ReportError then YaHT.ReportError("FeignWatch", err) end
	end)
	watch:Hide() -- only runs for a few seconds after each Feign Death
	self:ApplyFeignSettings()
end
