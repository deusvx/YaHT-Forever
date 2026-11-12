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
-- The game's "Resisted" message can arrive a moment BEFORE it confirms the cast
-- (seen in game: the alert then came from the slow target check instead). So a
-- resist message also counts when it comes shortly after you pressed Feign
-- Death, or just before the cast is confirmed.
local SENT_WINDOW = 1.5  -- "Resisted" this soon after pressing Feign Death counts, confirmed or not
local EARLY_WINDOW = 0.5 -- "Resisted" this soon before the cast is confirmed counts
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

-- Feign Death is used rarely and resisted more rarely still, so what happened
-- around the last few is always kept (a handful of lines each, in the saved
-- settings): a late or missing alert can then be looked into afterwards
-- without /yaht debug having been on. debugOnly: too chatty to keep.
local FD_LOG_MAX = 150
local function Log(msg, debugOnly)
	local g = YaHT.db and YaHT.db.global
	if g and not debugOnly then
		local log = g.fdlog or {}
		g.fdlog = log
		log[#log + 1] = string.format("%.3f  %s", GetTime(), msg)
		if #log > FD_LOG_MAX then table.remove(log, 1) end
	end
	if YaHT.debug then YaHT:Print("FD: " .. msg) end
end

-- What the game says about your threat on your target. A feign that worked
-- should take you off its list; if this is readable in a fight it would
-- notice a resist sooner than waiting to see whether the mob keeps coming.
-- For now it is only written down (a few looks after each feign).
-- Measured in game (2026-11-12, five feigns): threat on your target is readable
-- in a fight. A feign that works takes you off its list within about a second
-- (seen gone by 0.3s, 0.6s, 1.0s and 1.0s); a resisted one leaves you on it
-- (still tanking at 2.5s), and the game sent no "Resisted" message for it. So:
-- still on the list THREAT_WAIT after feigning = resisted. That is twice as
-- fast as waiting to see whether the mob keeps coming, and the moment you drop
-- off the list is written down so the wait can be tightened with more data.
local THREAT_POLL = 0.1
local THREAT_WAIT = 1.25
local THREAT_LOOKS = {1.5, 2.5}

-- Are you on your target's threat list? true / false, nil when the game won't say
local function OnThreatList()
	if not UnitThreatSituation then return nil end
	local ok, situation = pcall(UnitThreatSituation, "player", "target")
	if not ok or IsSecret(situation) then return nil end
	return situation ~= nil
end
local function Threat()
	local function txt(v) if IsSecret(v) then return "SECRET" end return tostring(v) end
	local parts = {}
	if UnitThreatSituation then
		local ok, situation = pcall(UnitThreatSituation, "player", "target")
		parts[#parts + 1] = "situation " .. (ok and txt(situation) or "ERR")
	else
		parts[#parts + 1] = "situation n/a"
	end
	if UnitDetailedThreatSituation then
		local ok, tanking, status, scaled = pcall(UnitDetailedThreatSituation, "player", "target")
		parts[#parts + 1] = ok and string.format("tanking %s status %s pct %s", txt(tanking), txt(status), txt(scaled)) or "detailed ERR"
	end
	return table.concat(parts, " | ")
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
	watch.threatLooks = 0
	watch.seenMsg = {}
	watch.at = GetTime()
	watch.health = Health()
	-- only a mob that had you on its list can show the feign working by dropping you
	watch.hadThreat, watch.threatGone, watch.nextThreat = OnThreatList() == true, nil, 0
	-- already alerted from the message that came right after the key press: no second alert
	if watch.alertedAt and watch.at - watch.alertedAt <= SENT_WINDOW then watch.resisted = true end
	Log(string.format("cast | health %s | feigned %s | in combat %s", tostring(watch.health),
		tostring(Feigned()), tostring(Plain(InCombatLockdown and InCombatLockdown()))))
	Log("threat at cast: " .. Threat())
	watch:Show()
	-- the message beat the cast confirmation: alert now, not after the slow checks
	if watch.msgAt and watch.at - watch.msgAt <= EARLY_WINDOW then
		watch.msgAt = nil
		Resisted("the game said resisted, just before the cast")
	end
end

local function WatchUpdate(self)
	if not self.active then self:Hide() return end
	local t = GetTime() - self.at
	-- the fast check: are you still on the mob's threat list?
	if self.hadThreat and not self.threatGone and not self.resisted and t >= (self.nextThreat or 0) then
		self.nextThreat = t + THREAT_POLL
		local on = OnThreatList()
		if on == false then
			self.threatGone = t
			Log(string.format("off the threat list %.2fs after feigning: it worked", t))
		elseif on == true and t >= THREAT_WAIT and YaHT.db.profile.feignthreatcheck then
			Log("threat " .. Threat())
			Resisted("still on your target's threat list")
		end
	end
	local look = THREAT_LOOKS[(self.threatLooks or 0) + 1]
	if look and t >= look then
		self.threatLooks = (self.threatLooks or 0) + 1
		Log(string.format("%.1fs: threat %s", t, Threat()))
	end
	local nextCheck = TARGET_CHECKS[self.targetChecks + 1]
	if nextCheck and t >= nextCheck then
		self.targetChecks = self.targetChecks + 1
		local onYou = TargetStillOnYou()
		Log(string.format("%.1fs: target on you %s | feigned %s | in combat %s", t, tostring(onYou),
			tostring(Feigned()), tostring(Plain(InCombatLockdown and InCombatLockdown()))))
		if not onYou then self.stillOnYou = false end
		-- (a mob that dropped you from its list was fooled, whoever it looks at next)
		if self.targetChecks == #TARGET_CHECKS and self.stillOnYou and not self.threatGone
			and YaHT.db.profile.feigntargetcheck then
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

local function IsFeign(spellID)
	spellID = Plain(spellID)
	if spellID == FEIGN_ID then return true end
	feignName = feignName or YaHT.GetSpellName(FEIGN_ID)
	return spellID ~= nil and feignName ~= nil and YaHT.GetSpellName(spellID) == feignName
end

local function OnEvent(self, event, ...)
	if not YaHT.db then return end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellID = ...
		if unit ~= "player" then return end
		if IsFeign(spellID) then StartWatch() end
	elseif event == "UNIT_SPELLCAST_SENT" then
		-- the key press, before the game answers: remember it for a "Resisted" that comes first
		local unit, _, _, spellID = ...
		if unit == "player" and IsFeign(spellID) then
			self.sentAt = GetTime()
			Log("pressed")
		end
	elseif (event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE") and not self.active then
		local _, msg = ...
		if not IsResistMessage(msg) then return end
		local now = GetTime()
		if self.sentAt and now - self.sentAt <= SENT_WINDOW then
			-- pressed Feign Death, and "Resisted" came before (or without) the cast confirmation
			Log(string.format("RESISTED (the game said resisted) %.2fs after the key press, before the cast was confirmed", now - self.sentAt))
			self.sentAt = nil
			self.alertedAt = now
			ShowAlert("the game said resisted")
		else
			self.msgAt = now -- counts if the cast is confirmed within a moment
		end
	elseif not self.active then
		return
	elseif event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
		local _, msg = ...
		-- The game repeats some messages every frame while a key is held ("Target
		-- too close" filled the whole record once): each is written down once a feign.
		local text = tostring(Plain(msg) or "(hidden)")
		self.seenMsg = self.seenMsg or {}
		if not self.seenMsg[text] then
			self.seenMsg[text] = true
			Log(string.format("%s: %s", event == "UI_ERROR_MESSAGE" and "error" or "info", text))
		end
		if IsResistMessage(msg) then Resisted("the game said resisted") end
	elseif event == "UNIT_HEALTH" then
		local unit = ...
		if unit ~= "player" then return end
		local h = Health()
		local t = GetTime() - self.at
		Log(string.format("health %s at %.2fs | feigned %s", tostring(h), t, tostring(Feigned())), true)
		if h and self.health and h < self.health and t > HIT_GRACE and Feigned() ~= false
			and YaHT.db.profile.feignhitcheck then
			Resisted("you were hit while feigned")
		end
		if h then self.health = h end
	elseif event == "UNIT_COMBAT" then
		local unit, action, descriptor = ...
		action = Plain(action)
		-- hits on you are too many to keep; anything else might be the game saying "resisted"
		if unit == "player" and action ~= "WOUND" and action ~= "HEAL" then
			Log(string.format("combat text on you: %s %s at %.2fs", tostring(action), tostring(Plain(descriptor)), GetTime() - self.at))
		end
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
	pcall(watch.RegisterUnitEvent, watch, "UNIT_SPELLCAST_SENT", "player")
	pcall(watch.RegisterUnitEvent, watch, "UNIT_COMBAT", "player")
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
