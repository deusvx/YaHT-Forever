-- YaHT - Yet another Hunter Timer by Aviana
-- WoW Forever port: works without LibSharedMedia, uses only cast events that
-- exist on both the old (Classic Era) and new (Midnight-based) client APIs,
-- and no longer rewires Blizzard's cast bar internals.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

YaHT = select(2, ...)

local L = YaHT.L
-- Non-English locale tables only translate some strings; fall back to the key.
setmetatable(L, {__index = function(t, k) return k end})
YaHT.version = "2140-forever1"

---------------------------------------------------------------------------
-- API compatibility helpers
---------------------------------------------------------------------------
local function GetSpellName(spellID)
	if not spellID then return nil end
	if C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(spellID)
	elseif C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		return info and info.name
	elseif GetSpellInfo then
		return (GetSpellInfo(spellID))
	end
end
YaHT.GetSpellName = GetSpellName

local function SendChat(msg, chatType, target)
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not send then return end
	-- pcall: SAY/YELL outside instances need a hardware event on modern clients
	-- and must never break the timer if blocked.
	local ok, err = pcall(send, msg, chatType, nil, target)
	if not ok then YaHT:Print("Announce blocked: "..tostring(err)) end
end

local function GetCombatLogInfo()
	if CombatLogGetCurrentEventInfo then
		return CombatLogGetCurrentEventInfo()
	elseif C_CombatLog and C_CombatLog.GetCurrentEventInfo then
		return C_CombatLog.GetCurrentEventInfo()
	end
end

---------------------------------------------------------------------------
-- Media (LibSharedMedia is optional)
---------------------------------------------------------------------------
local SML = LibStub:GetLibrary("LibSharedMedia-3.0", true)
YaHT.SML = SML

local MEDIA = {
	statusbar = {
		["YaHT Bar"] = "Interface\\AddOns\\YaHT\\media\\Bar",
		["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
		["Solid"] = "Interface\\Buttons\\WHITE8X8",
	},
	background = {
		["Chat Frame"] = "Interface\\ChatFrame\\ChatFrameBackground",
		["Blizzard Tooltip"] = "Interface\\Tooltips\\UI-Tooltip-Background",
		["Solid"] = "Interface\\Buttons\\WHITE8X8",
	},
	border = {
		["None"] = "Interface\\None",
		["Blizzard Dialog"] = "Interface\\DialogFrame\\UI-DialogBox-Border",
		["Blizzard Tooltip"] = "Interface\\Tooltips\\UI-Tooltip-Border",
	},
}
local defaultMedia = {
	statusbar = MEDIA.statusbar["YaHT Bar"],
	background = MEDIA.background["Chat Frame"],
	border = MEDIA.border["None"],
}
local mediaRequired

function YaHT:ListMedia(mediaType)
	local list = {}
	for name in pairs(MEDIA[mediaType] or {}) do list[name] = name end
	if SML then
		for _, name in pairs(SML:List(mediaType) or {}) do list[name] = name end
	end
	return list
end

function YaHT:GetMedia(mediaType, mediaName)
	local media = SML and SML:Fetch(mediaType, mediaName, true)
	if not media then media = MEDIA[mediaType] and MEDIA[mediaType][mediaName] end
	if not media then
		if SML then
			mediaRequired = mediaRequired or {}
			mediaRequired[mediaType] = mediaName
		end
		return defaultMedia[mediaType]
	end
	return media
end

---------------------------------------------------------------------------
-- Timer logic
---------------------------------------------------------------------------
-- Auto Shot wind-up: the part of each shot where you must stand still.
-- WoW Forever: Blizzard states it is 0.5 s (same as 1.12). The original
-- Classic 1.13 addon used 0.65 s. Configurable under /yaht -> "Wind-up time".
local DEFAULT_WINDUP = 0.5
local function Windup()
	return (YaHT.db and YaHT.db.profile.windup) or DEFAULT_WINDUP
end
local movementDelay = 0

local AUTO_SHOT_ID = 75
local AutoShot = GetSpellName(AUTO_SHOT_ID)
local AimedShot = GetSpellName(19434)
local MultiShot = GetSpellName(2643)
local TranqShot = GetSpellName(19801)
local backdrop = {insets = {}}
local playerGUID

local function IsMoving()
	return (IsPlayerMoving and IsPlayerMoving()) or (GetUnitSpeed and GetUnitSpeed("player") > 0) or (IsFalling and IsFalling())
end

local function GetRangedSpeed()
	return (UnitRangedDamage("player")) or 2
end

local function GetAutoShotCooldown()
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(75)
		if info then return info.startTime, info.duration end
	elseif GetSpellCooldown then
		return GetSpellCooldown(75)
	end
end

local function OnUpdate(self, elapsed)
	local config = YaHT.db.profile
	local SWING_TIME = Windup()
	self.swingtime = math.max(self.speed - SWING_TIME, 0.1)
	if not config.lock then
		self.mockTime = self.mockTime + elapsed
		if self.mockTime > self.swingtime then
			self.texture:SetVertexColor(config.drawcolor.r,config.drawcolor.g,config.drawcolor.b)
			self.texture:SetWidth(math.max(self:GetWidth() * (1-(self.mockTime2/SWING_TIME)), 0.01))
			self.mockTime2 = self.mockTime2 + elapsed
			if self.mockTime2 > SWING_TIME then
				self.mockTime = 0
			end
		else
			self.mockTime2 = 0
			self.texture:SetVertexColor(config.timercolor.r,config.timercolor.g,config.timercolor.b)
			self.texture:SetWidth(math.max(self:GetWidth() * self.mockTime/self.swingtime, 0.01))
		end
		return
	end
	local curTime = GetTime()
	if not self.SwingStart and (curTime - self.lastshot) >= self.swingtime then
		--Start Swing timer
		-- On WoW Forever Auto Shot keeps firing during Aimed Shot casts, so a
		-- cast only holds the timer if the user turns that option on.
		if self.shooting and not (self.casting and config.castholds) then
			self.texture:SetVertexColor(config.drawcolor.r,config.drawcolor.g,config.drawcolor.b)
			self:SetAlpha(config.alpha)
			self.SwingStart = curTime
		else
			if not self.shooting then
				self:Hide()
			end
		end
	elseif self.SwingStart then
		if IsMoving() then
			self.SwingStart = curTime
			self.texture:SetWidth(0.01)
			self:SetAlpha(config.malpha)
			local timeSinceReadyToFire = curTime - self.lastshot + self.swingtime
			if timeSinceReadyToFire > 0 then
				while timeSinceReadyToFire > 0.5 do
					timeSinceReadyToFire = timeSinceReadyToFire - 0.5
				end
				movementDelay = 0.5 - timeSinceReadyToFire
			end
		else
			self.texture:SetWidth(math.max(config.width * math.min(((curTime - self.SwingStart) / (SWING_TIME + movementDelay)),1), 0.01))
			self:SetAlpha(config.alpha)
		end
	else
		self.texture:SetWidth(math.max(config.width * (1 - math.min(((curTime - self.lastshot) / self.swingtime),1)), 0.01))
		self:SetAlpha(config.alpha)
	end
end

function YaHT:OnInitialize()
	playerGUID = UnitGUID("player")
	self:LoadDefaults()

	self.db = LibStub:GetLibrary("AceDB-3.0"):New("YaHTdb", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileReset")
	if SML then
		SML.RegisterCallback(self, "LibSharedMedia_Registered", "MediaRegistered")
		SML:Register(SML.MediaType.STATUSBAR, "YaHT Bar", MEDIA.statusbar["YaHT Bar"])
	end

	self:Load()
	self:CreateConfig()
end

local resetTimer
function YaHT:ProfilesChanged()
	if resetTimer then resetTimer:Hide() end
	self.db:RegisterDefaults(self.defaults)
	self:ApplySettings()
end

function YaHT:ProfileReset()
	if not resetTimer then
		resetTimer = CreateFrame("Frame")
		resetTimer:SetScript("OnUpdate", function(self)
			YaHT:ProfilesChanged()
			self:Hide()
		end)
	end
	resetTimer:Show()
end

function YaHT:MediaRegistered(event, mediaType, key)
	if mediaRequired and mediaRequired[mediaType] and mediaRequired[mediaType] == key then
		mediaRequired[mediaType] = nil
		self:ApplySettings()
	end
end

function YaHT:ApplySettings()
	local config = YaHT.db.profile
	local f = self.mainFrame
	f:SetWidth(config.width)
	f:SetHeight(config.height)
	f:SetScale(config.scale)
	f:ClearAllPoints()
	if config.point then
		f:SetPoint(config.point, UIParent, config.relativePoint, config.x, config.y)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, -350)
	end
	f:EnableMouse(not config.lock)
	f:SetMovable(not config.lock)

	backdrop.edgeFile = config.enableborder and self:GetMedia("border", config.border) or nil
	backdrop.tile = true
	backdrop.edgeSize = 10
	backdrop.tileSize = 1
	backdrop.insets.left = 3
	backdrop.insets.right = 3
	backdrop.insets.top = 3
	backdrop.insets.bottom = 3

	if f.border.SetBackdrop then
		f.border:SetBackdrop(backdrop)
		f.border:SetBackdropBorderColor(config.bordercolor.r, config.bordercolor.g, config.bordercolor.b)
	end
	f.border:SetHeight(config.height + 6)
	f.border:SetWidth(config.width + 6)

	if config.enablebackground then
		f.background:Show()
	else
		f.background:Hide()
	end
	f.background:SetTexture(self:GetMedia("background", config.background))
	f.background:SetVertexColor(config.backgroundcolor.r, config.backgroundcolor.g, config.backgroundcolor.b, config.backgroundcolor.a)

	f.texture:ClearAllPoints()
	if config.fill then
		f.texture:SetPoint("CENTER", f, "CENTER")
	else
		f.texture:SetPoint("LEFT", f, "LEFT")
	end

	if config.lock and not f.shooting then
		f:Hide()
	else
		f:Show()
		f:SetAlpha(config.alpha)
		if f.SwingStart then
			f.texture:SetVertexColor(config.drawcolor.r,config.drawcolor.g,config.drawcolor.b)
		else
			f.texture:SetVertexColor(config.timercolor.r, config.timercolor.g,config.timercolor.b)
		end
	end

	f.texture:SetTexture(self:GetMedia("statusbar", config.statusbar))
	f.texture:SetHeight(config.height)
end

function YaHT:Load()
	local f = CreateFrame("Frame", "YaHTMainFrame", UIParent)
	self.mainFrame = f
	f:SetFrameStrata("MEDIUM")
	f:RegisterForDrag("LeftButton")
	f:SetClampedToScreen(true)
	f:SetScript("OnDragStart", function() f:StartMoving() end)
	f:SetScript("OnDragStop", function()
		local config, _ = YaHT.db.profile
		f:StopMovingOrSizing()
		config.point, _, config.relativePoint, config.x, config.y = f:GetPoint()
	end)
	f.mockTime = 0
	f.mockTime2 = 0
	f.lastshot = GetTime()
	f.speed = GetRangedSpeed()
	f.swingtime = math.max(f.speed - Windup(), 0.1)
	f:SetScript("OnUpdate", OnUpdate)

	f.background = f:CreateTexture("YaHTMainFrameBackground", "BACKGROUND")
	f.background:SetAllPoints(f)
	if f.background.SetHorizTile then
		f.background:SetHorizTile(true)
		f.background:SetVertTile(true)
	end

	f.texture = f:CreateTexture("YaHTMainFrameBar", "ARTWORK")

	f.border = CreateFrame("Frame", "YaHTMainFrameBorder", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.border:SetPoint("CENTER", f, "CENTER")

	self:ApplySettings()
end

---------------------------------------------------------------------------
-- Announcements
---------------------------------------------------------------------------
local function Announce(msgTemplate, targetName)
	local config = YaHT.db.profile
	local target = config.targetchannel
	if config.announcetype == "CHANNEL" then
		target = GetChannelName(config.targetchannel)
	end
	SendChat(string.format(msgTemplate, targetName or UNKNOWN or "?"), config.announcetype, target)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function IsCastSpell(spellID)
	local name = GetSpellName(spellID)
	return name and (name == AimedShot or name == MultiShot)
end

function YaHT:UNIT_SPELLCAST_START(unit, castGUID, spellID)
	if unit ~= "player" then return end
	if IsCastSpell(spellID) then
		self.mainFrame.casting = true
	end
end

function YaHT:UNIT_SPELLCAST_STOP(unit, castGUID, spellID)
	if unit ~= "player" then return end
	if IsCastSpell(spellID) then
		self.mainFrame.casting = nil
	end
end
YaHT.UNIT_SPELLCAST_FAILED = YaHT.UNIT_SPELLCAST_STOP
YaHT.UNIT_SPELLCAST_INTERRUPTED = YaHT.UNIT_SPELLCAST_STOP

function YaHT:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
	if unit ~= "player" then return end
	local config = YaHT.db.profile
	local name = GetSpellName(spellID)

	if name and name == TranqShot then
		self.lastTranqTarget = UnitName("target")
		-- Without the combat log we cannot tell hit from miss, so announce on cast.
		if config.tranqannounce and not self.hasCombatLog then
			Announce(config.announcemsg, self.lastTranqTarget)
		end
	end

	if IsCastSpell(spellID) then
		self.mainFrame.casting = nil
		return
	end

	if spellID == AUTO_SHOT_ID or (name and name == AutoShot) then
		local f = self.mainFrame
		if f.shooting then
			local now = GetTime()
			if self.debug then
				local cdStart, cdDur = GetAutoShotCooldown()
				self:Print(string.format("Auto Shot: %.3fs since last | ranged speed %.3f | cooldown start %s dur %s | windup %.2f | casting %s",
					now - f.lastshot, GetRangedSpeed(), tostring(cdStart and cdStart - now), tostring(cdDur), Windup(), tostring(f.casting)))
			end
			f.lastshot = now
			f.SwingStart = nil
			if f.newspeed then
				f.speed = f.newspeed
				f.newspeed = nil
			end
			f.texture:SetVertexColor(config.timercolor.r,config.timercolor.g,config.timercolor.b)
			movementDelay = 0
		end
	end
end

-- Only used for Tranquilizing Shot hit/miss announcements, and only if the
-- client still lets addons read the combat log.
function YaHT:COMBAT_LOG_EVENT_UNFILTERED()
	local _, event, _, casterID, _, _, _, _, targetName, _, _, _, name = GetCombatLogInfo()
	if casterID ~= playerGUID or name ~= TranqShot then return end
	local config = YaHT.db.profile
	if event == "SPELL_CAST_SUCCESS" and config.tranqannounce then
		Announce(config.announcemsg, targetName)
	elseif event == "SPELL_MISSED" and config.tranqannouncefail then
		Announce(config.announcefailmsg, targetName)
	end
end

function YaHT:START_AUTOREPEAT_SPELL()
	local config = YaHT.db.profile
	if self.debug then self:Print("START_AUTOREPEAT_SPELL") end
	local f = self.mainFrame
	local curTime = GetTime()
	f.shooting = true
	if curTime - f.lastshot < f.swingtime then
		f.texture:SetVertexColor(config.timercolor.r,config.timercolor.g,config.timercolor.b)
	else
		f.texture:SetVertexColor(config.drawcolor.r,config.drawcolor.g,config.drawcolor.b)
		f.SwingStart = curTime
		if IsMoving() then
			f.lastshot = curTime - f.swingtime
		end
	end
	f:SetAlpha(config.alpha)
	f:Show()
end

function YaHT:STOP_AUTOREPEAT_SPELL()
	local f = self.mainFrame
	if self.debug then self:Print("STOP_AUTOREPEAT_SPELL") end
	f.shooting = nil
	if YaHT.db.profile.lock and (GetTime() - f.lastshot) >= f.swingtime then
		f:SetAlpha(0)
		f:Hide()
	end
end

function YaHT:UNIT_RANGEDDAMAGE(unit)
	if unit and unit ~= "player" then return end
	self.mainFrame.newspeed = GetRangedSpeed()
end

function YaHT:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cFF2150C2YaHT|cFFFFFFFF: ".. msg)
end

SLASH_YAHT1 = "/yaht"
SLASH_YAHT2 = "/huntertimer"
SLASH_YAHT3 = "/yetanotherhuntertimer"
SlashCmdList["YAHT"] = function(msg)
	if msg and msg:lower():match("^%s*debug") then
		YaHT.debug = not YaHT.debug
		YaHT:Print("debug "..(YaHT.debug and "ON: shoot a target dummy standing still, then paste the lines" or "OFF"))
		return
	end
	LibStub("AceConfigDialog-3.0"):Open("YaHT")
end

local frame = CreateFrame("Frame")

-- Register safely: an event the client doesn't know (or forbids) is skipped
-- instead of throwing an error and killing the whole addon.
local function SafeRegister(event, unit)
	local ok
	if unit and frame.RegisterUnitEvent then
		ok = pcall(frame.RegisterUnitEvent, frame, event, unit)
	else
		ok = pcall(frame.RegisterEvent, frame, event)
	end
	return ok
end

SafeRegister("PLAYER_LOGIN")
SafeRegister("UNIT_SPELLCAST_START", "player")
SafeRegister("UNIT_SPELLCAST_STOP", "player")
SafeRegister("UNIT_SPELLCAST_FAILED", "player")
SafeRegister("UNIT_SPELLCAST_INTERRUPTED", "player")
SafeRegister("UNIT_SPELLCAST_SUCCEEDED", "player")
SafeRegister("UNIT_RANGEDDAMAGE", "player")
SafeRegister("START_AUTOREPEAT_SPELL")
SafeRegister("STOP_AUTOREPEAT_SPELL")
YaHT.hasCombatLog = (CombatLogGetCurrentEventInfo or (C_CombatLog and C_CombatLog.GetCurrentEventInfo)) and SafeRegister("COMBAT_LOG_EVENT_UNFILTERED") or false

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		YaHT:OnInitialize()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif YaHT.db and YaHT[event] then
		YaHT[event](YaHT, ...)
	end
end)
