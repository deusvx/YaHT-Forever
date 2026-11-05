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
-- WoW Forever (12.x engine) can hand addons "secret values" in combat that
-- cannot be compared or used in maths. Always check before using a stat.
local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end
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

local warnedChat = {}
local function ChatWarnOnce(key, text)
	if warnedChat[key] then return end
	warnedChat[key] = true
	DEFAULT_CHAT_FRAME:AddMessage("|cFF2150C2YaHT|r: "..text)
end

local function SendChat(msg, chatType, target)
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not send then return end
	-- 12.x engine (WoW Forever): addon chat is locked down during boss
	-- encounters / M+ / PvP matches. Sending then is silently dropped or
	-- raises a "blocked action" popup, so don't try.
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
		if ok and not IsSecret(locked) and locked then
			ChatWarnOnce("lockdown", "announcements are blocked by the game during encounters.")
			return
		end
	end
	-- Say/Yell/Channel from an addon only work inside instances on modern
	-- clients; outside they trigger a "blocked action" warning.
	if chatType == "SAY" or chatType == "YELL" or chatType == "CHANNEL" then
		local inInstance = IsInInstance and IsInInstance()
		if not IsSecret(inInstance) and not inInstance then
			ChatWarnOnce("outdoor", "Say/Yell/Channel announcements only work inside instances (game restriction).")
			return
		end
	end
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
	font = {
		["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
		["Arial Narrow"] = "Fonts\\ARIALN.TTF",
		["Morpheus"] = "Fonts\\MORPHEUS.TTF",
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
	font = "Fonts\\FRIZQT__.TTF",
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
local movementDelay = 0

local AUTO_SHOT_ID = 75
local AutoShot = GetSpellName(AUTO_SHOT_ID)
local AimedShot = GetSpellName(19434)
local MultiShot = GetSpellName(2643)
local TranqShot = GetSpellName(19801)
local backdrop = {insets = {}}
local playerGUID

local lastMoving = false
local function IsMoving()
	local falling = IsFalling and IsFalling()
	if not IsSecret(falling) and falling == true then return true end
	local moving = IsPlayerMoving and IsPlayerMoving()
	if not IsSecret(moving) and moving ~= nil then
		lastMoving = moving and true or false
		return lastMoving
	end
	local speed = GetUnitSpeed and GetUnitSpeed("player")
	if not IsSecret(speed) and type(speed) == "number" then
		lastMoving = speed > 0
	end
	return lastMoving -- stat hidden: keep last known state
end

local lastRangedSpeed = 2
local function GetRangedSpeed()
	local speed = UnitRangedDamage("player")
	if not IsSecret(speed) and type(speed) == "number" and speed > 0 then
		lastRangedSpeed = speed
	end
	return lastRangedSpeed
end

-- Unhasted weapon speed, read from the ranged weapon's tooltip.
local scanTip = CreateFrame("GameTooltip", "YaHTScanningTooltip", nil, "GameTooltipTemplate")
local baseSpeedCache = {}
local function GetBaseSpeed()
	local slot = INVSLOT_RANGED or 18
	local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
	if IsSecret(itemID) or not itemID then return nil end
	if baseSpeedCache[itemID] then return baseSpeedCache[itemID] end
	scanTip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
	scanTip:ClearLines()
	scanTip:SetInventoryItem("player", slot)
	local pattern = (SPEED or "Speed") .. " (%d+[%.,]%d+)"
	for i = 1, scanTip:NumLines() do
		local fs = _G["YaHTScanningTooltipTextRight"..i]
		local text = fs and fs:GetText()
		if text and not IsSecret(text) then
			local num = text:match(pattern)
			if num then
				num = tonumber((num:gsub(",", ".")))
				if num and num > 0 then
					baseSpeedCache[itemID] = num
					return num
				end
			end
		end
	end
end

-- Auto Shot wind-up: the part of each shot where you must stand still.
-- WoW Forever: 0.5 s at base weapon speed, shortened by ranged haste
-- (0.5 * current speed / base speed), same model WeaponSwingTimer's
-- Forever build uses. Can be set manually under /yaht -> Timing.
local function Windup(speed)
	local p = YaHT.db and YaHT.db.profile
	if p and not p.windupauto then
		return p.windup or 0.5
	end
	local base = GetBaseSpeed()
	speed = speed or (YaHT.mainFrame and YaHT.mainFrame.speed) or GetRangedSpeed()
	if base and base > 1 and speed and speed > 0 then
		return math.min(0.5 * speed / base, 0.5 * 1.5)
	end
	return 0.5
end

local function GetAutoShotCooldown()
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(75)
		if info then return info.startTime, info.duration end
	elseif GetSpellCooldown then
		return GetSpellCooldown(75)
	end
end

-- Safety net: if something unexpected breaks, report it once in chat
-- (instead of a Lua error popup every frame) so it can be fixed.
local reportedErrors = {}
local function ReportError(where, err)
	local key = where..tostring(err)
	if reportedErrors[key] then return end
	reportedErrors[key] = true
	DEFAULT_CHAT_FRAME:AddMessage("|cFF2150C2YaHT|r error in "..where.." (please report): "..tostring(err))
end
YaHT.ReportError = ReportError

local function OnUpdate(self, elapsed)
	local config = YaHT.db.profile
	local SWING_TIME = Windup(self.speed)
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

---------------------------------------------------------------------------
-- Countdown text (like WeaponSwingTimer: seconds until the shot, 1 decimal)
---------------------------------------------------------------------------
local TEXT_ANCHORS = {
	-- key = {point on text, point on bar, x, y}
	INSIDE_LEFT   = {"LEFT",   "LEFT",    2, 0},
	INSIDE_CENTER = {"CENTER", "CENTER",  0, 0},
	INSIDE_RIGHT  = {"RIGHT",  "RIGHT",  -2, 0},
	OUTSIDE_LEFT  = {"RIGHT",  "LEFT",   -4, 0},
	OUTSIDE_RIGHT = {"LEFT",   "RIGHT",   4, 0},
	ABOVE         = {"BOTTOM", "TOP",     0, 2},
	BELOW         = {"TOP",    "BOTTOM",  0, -2},
}
YaHT.TEXT_ANCHORS = TEXT_ANCHORS

local function UpdateText(self)
	local config = YaHT.db.profile
	local holder = self.textHolder
	if not config.showtext then
		holder:Hide()
		return
	end
	holder:Show()
	local windup = Windup(self.speed)
	local toShot = config.textmode ~= "MOVE"
	local remaining
	if not config.lock then
		-- demo cycle while unlocked
		if self.mockTime > self.swingtime then
			remaining = windup - self.mockTime2
		else
			remaining = (self.swingtime - self.mockTime) + (toShot and windup or 0)
		end
	elseif self.SwingStart then
		-- stand-still phase (wind-up)
		remaining = (windup + movementDelay) - (GetTime() - self.SwingStart)
	else
		local reload = self.swingtime - (GetTime() - self.lastshot)
		if reload > 0 then
			remaining = reload + (toShot and windup or 0)
		elseif self.shooting then
			remaining = windup
		end
	end
	if remaining then
		self.text:SetText(string.format("%.1f", math.max(remaining, 0)))
	else
		self.text:SetText("")
	end
end

function YaHT:ApplyTextSettings()
	local config = self.db.profile
	local f = self.mainFrame
	local holder, text = f.textHolder, f.text
	local font = self:GetMedia("font", config.font) or STANDARD_TEXT_FONT
	if not text:SetFont(font, config.textsize, "OUTLINE") then
		text:SetFont(STANDARD_TEXT_FONT, config.textsize, "OUTLINE")
	end
	local c = config.textcolor
	text:SetTextColor(c.r, c.g, c.b, c.a or 1)
	local a = TEXT_ANCHORS[config.textpos] or TEXT_ANCHORS.OUTSIDE_RIGHT
	holder:ClearAllPoints()
	holder:SetPoint(a[1], f, a[2], a[3] + (config.textx or 0), a[4] + (config.texty or 0))
	holder:SetSize(math.max(config.textsize * 3, 20), config.textsize + 4)
	text:ClearAllPoints()
	text:SetPoint(a[1], holder, a[1])
	text:SetJustifyH(a[1] == "LEFT" and "LEFT" or a[1] == "RIGHT" and "RIGHT" or "CENTER")
	-- drag the number around while the bar is unlocked
	holder:EnableMouse(not config.lock and config.showtext)
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
	if f.textHolder then self:ApplyTextSettings() end
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
	f:SetScript("OnUpdate", function(frame, elapsed)
		local ok, err = pcall(OnUpdate, frame, elapsed)
		if not ok then ReportError("OnUpdate", err) end
		ok, err = pcall(UpdateText, frame)
		if not ok then ReportError("UpdateText", err) end
	end)

	f.background = f:CreateTexture("YaHTMainFrameBackground", "BACKGROUND")
	f.background:SetAllPoints(f)
	if f.background.SetHorizTile then
		f.background:SetHorizTile(true)
		f.background:SetVertTile(true)
	end

	f.texture = f:CreateTexture("YaHTMainFrameBar", "ARTWORK")

	-- countdown number, in its own small frame so it can be dragged
	local holder = CreateFrame("Frame", "YaHTMainFrameTextHolder", f)
	holder:SetFrameLevel(f:GetFrameLevel() + 5)
	holder:RegisterForDrag("LeftButton")
	f.textHolder = holder
	f.text = holder:CreateFontString("YaHTMainFrameText", "OVERLAY")
	f.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
	holder:SetScript("OnDragStart", function(h)
		local config = YaHT.db.profile
		local x, y = GetCursorPosition()
		h.dragStart = {x = x, y = y, ox = config.textx or 0, oy = config.texty or 0}
		h:SetScript("OnUpdate", function()
			local cx, cy = GetCursorPosition()
			local scale = f:GetEffectiveScale()
			config.textx = math.floor(h.dragStart.ox + (cx - h.dragStart.x) / scale + 0.5)
			config.texty = math.floor(h.dragStart.oy + (cy - h.dragStart.y) / scale + 0.5)
			YaHT:ApplyTextSettings()
		end)
	end)
	holder:SetScript("OnDragStop", function(h)
		h:SetScript("OnUpdate", nil)
		local ACR = LibStub("AceConfigRegistry-3.0", true)
		if ACR then ACR:NotifyChange("YaHT") end
	end)

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
	-- pcall: a custom message with a stray % sign must not throw an error.
	local ok, msg = pcall(string.format, msgTemplate or "", targetName or UNKNOWN or "?")
	SendChat(ok and msg or (msgTemplate or ""), config.announcetype, target)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function IsCastSpell(spellID)
	if IsSecret(spellID) then return false end
	local name = GetSpellName(spellID)
	return name and (name == AimedShot or name == MultiShot)
end

function YaHT:UNIT_SPELLCAST_START(unit, castGUID, spellID)
	if unit ~= "player" or IsSecret(spellID) then return end
	if IsCastSpell(spellID) then
		self.mainFrame.casting = true
	end
end

function YaHT:UNIT_SPELLCAST_STOP(unit, castGUID, spellID)
	if unit ~= "player" or IsSecret(spellID) then return end
	if IsCastSpell(spellID) then
		self.mainFrame.casting = nil
	end
end
YaHT.UNIT_SPELLCAST_FAILED = YaHT.UNIT_SPELLCAST_STOP
YaHT.UNIT_SPELLCAST_INTERRUPTED = YaHT.UNIT_SPELLCAST_STOP

function YaHT:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
	if unit ~= "player" or IsSecret(spellID) then return end
	local config = YaHT.db.profile
	local name = GetSpellName(spellID)

	if name and name == TranqShot then
		local target = UnitName("target")
		self.lastTranqTarget = (not IsSecret(target)) and target or nil
		-- Without the combat log we cannot tell hit from miss, so announce on cast.
		if config.tranqannounce and not self.hasCombatLog then
			Announce(config.announcemsg, self.lastTranqTarget)
		end
	end

	if IsCastSpell(spellID) then
		self.mainFrame.casting = nil
		return
	end

	-- When the client has PLAYER_SWING (WoW Forever) that event is the
	-- authoritative shot signal; this is only the fallback.
	if not self.hasNativeSwing and (spellID == AUTO_SHOT_ID or (name and name == AutoShot)) then
		if self.mainFrame.shooting then
			self:OnAutoShot(nil, "UNIT_SPELLCAST_SUCCEEDED")
		end
	end
end

-- A ranged shot just left the bow/gun. duration = full time until the next
-- shot (already includes haste) when the game tells us, nil otherwise.
function YaHT:OnAutoShot(duration, source)
	local config = YaHT.db.profile
	local f = self.mainFrame
	local now = GetTime()
	if duration then
		f.speed = duration
		f.newspeed = nil
	elseif f.newspeed then
		f.speed = f.newspeed
		f.newspeed = nil
	end
	if self.debug then
		local cdStart, cdDur = GetAutoShotCooldown()
		local function v(x) if IsSecret(x) then return "secret" end return x and string.format("%.3f", x) or "nil" end
		self:Print(string.format("%s: %.3fs since last | swing %s | ranged speed %s | base %s | windup %.3f | cd %s | casting %s",
			source or "?", now - f.lastshot, v(duration), v(GetRangedSpeed()), v(GetBaseSpeed()), Windup(f.speed),
			(cdDur and not IsSecret(cdDur)) and string.format("%.3f", cdDur) or tostring(cdDur), tostring(f.casting)))
	end
	f.lastshot = now
	f.SwingStart = nil
	f.texture:SetVertexColor(config.timercolor.r,config.timercolor.g,config.timercolor.b)
	movementDelay = 0
end

-- WoW Forever: native swing event, fires for every swing with its duration.
function YaHT:PLAYER_SWING(duration, swingType)
	if IsSecret(duration) or IsSecret(swingType) then return end
	if type(duration) ~= "number" or duration <= 0 then return end
	if Enum and Enum.PlayerSwingType and swingType ~= Enum.PlayerSwingType.Ranged then return end
	self:OnAutoShot(duration, "PLAYER_SWING")
end

-- Auto Shot tried to start but couldn't (e.g. moving); the game waits
-- ~0.5 s before retrying. The movement logic in OnUpdate models this.
function YaHT:UNIT_SPELLCAST_FAILED_QUIET(unit, castGUID, spellID)
	if unit ~= "player" or not self.debug or IsSecret(spellID) then return end
	if spellID == AUTO_SHOT_ID then self:Print("Auto Shot attempt failed (retry delay)") end
end

function YaHT:PLAYER_EQUIPMENT_CHANGED()
	self.mainFrame.newspeed = GetRangedSpeed()
end

-- Only used for Tranquilizing Shot hit/miss announcements, and only if the
-- client still lets addons read the combat log (WoW Forever does not).
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
SafeRegister("UNIT_SPELLCAST_FAILED_QUIET", "player")
SafeRegister("PLAYER_EQUIPMENT_CHANGED")
YaHT.hasNativeSwing = SafeRegister("PLAYER_SWING")
YaHT.hasCombatLog = (CombatLogGetCurrentEventInfo or (C_CombatLog and C_CombatLog.GetCurrentEventInfo)) and SafeRegister("COMBAT_LOG_EVENT_UNFILTERED") or false

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		YaHT:OnInitialize()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif YaHT.db and YaHT[event] then
		local ok, err = pcall(YaHT[event], YaHT, ...)
		if not ok then ReportError(event, err) end
	end
end)
