-- YaHT - Yet another Hunter Timer, originally by Aviana.
-- WoW Forever port: native PLAYER_SWING timing, haste-scaled wind-up,
-- secret-value safe, plus countdown text, glow and spark effects.

-- Addon Compartment (the addon button by the minimap) must exist for every class.
function YaHT_OnAddonCompartmentClick()
	if SlashCmdList and SlashCmdList["YAHT"] then
		SlashCmdList["YAHT"]("")
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cFF2150C2YaHT|r: only active on hunters.")
	end
end

if select(2,UnitClass("player")) ~= "HUNTER" then return end

YaHT = select(2, ...)

local L = YaHT.L
-- Non-English locale tables only translate some strings; fall back to the key.
setmetatable(L, {__index = function(t, k) return k end})
YaHT.version = "1.3.0-forever"

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

local AUTO_SHOT_ID = 75
local AutoShot = GetSpellName(AUTO_SHOT_ID)
local AimedShot = GetSpellName(19434)
local MultiShot = GetSpellName(2643)
local TranqShot = GetSpellName(19801)
local FeignDeath = GetSpellName(5384)
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
local currentBase, baseDirty = nil, true
local function GetBaseSpeed()
	-- cheap path: weapon unchanged since the last successful lookup
	if not baseDirty then return currentBase end
	local slot = INVSLOT_RANGED or 18
	local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
	if IsSecret(itemID) or not itemID then return nil end
	if baseSpeedCache[itemID] then
		currentBase, baseDirty = baseSpeedCache[itemID], false
		return currentBase
	end
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
					currentBase, baseDirty = num, false
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
	self.windup = SWING_TIME -- reused by the text/glow updates this frame
	-- learned per-shot delay (latency etc.) on top of the game's swing time
	local calib = (config.autocorrect and YaHT.calib) or 0
	self.swingtime = math.max(self.speed - SWING_TIME + calib, 0.1)
	self.readyMoving = false
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
		-- the game makes its first attempt now, then retries every 0.5s
		--Start Swing timer
		-- On WoW Forever Auto Shot keeps firing during Aimed Shot casts, so a
		-- cast only holds the timer if the user turns that option on.
		if self.shooting and not (self.casting and config.castholds) then
			self.texture:SetVertexColor(config.drawcolor.r,config.drawcolor.g,config.drawcolor.b)
			self:SetAlpha(config.alpha)
			self.SwingStart, self.fillFrom, self.nextAttempt = curTime, curTime, curTime
		else
			if not self.shooting then
				self:Hide()
			end
		end
	elseif self.SwingStart then
		if IsMoving() then
			self.readyMoving = true -- shot is ready, you just need to stop
			self.disturbed = true -- this cycle can't be used to learn timing
			self.wasMoving = true
			self.SwingStart, self.fillFrom = curTime, curTime
			self.texture:SetWidth(0.01)
			self:SetAlpha(config.malpha)
		else
			if self.wasMoving then
				-- Stopped: the game only retries on its 0.5s rhythm, so the
				-- wind-up starts at the next retry moment, not right now.
				self.wasMoving = false
				local tick = self.nextAttempt or curTime
				while tick < curTime - 0.001 do tick = tick + 0.5 end
				self.nextAttempt = tick
				self.SwingStart, self.fillFrom = tick, curTime
			end
			-- fill smoothly from fillFrom to the moment the shot leaves
			local shotAt = self.SwingStart + SWING_TIME
			local span = math.max(shotAt - (self.fillFrom or self.SwingStart), 0.01)
			local frac = math.min(math.max((curTime - (self.fillFrom or self.SwingStart)) / span, 0), 1)
			self.texture:SetWidth(math.max(config.width * frac, 0.01))
			self:SetAlpha(config.alpha)
		end
	else
		self.texture:SetWidth(math.max(config.width * (1 - math.min(math.max((curTime - self.lastshot) / self.swingtime, 0), 1)), 0.01))
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
	local windup = self.windup or Windup(self.speed)
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
		remaining = (self.SwingStart + windup) - GetTime()
	else
		local reload = self.swingtime - (GetTime() - self.lastshot)
		if reload > 0 then
			remaining = reload + (toShot and windup or 0)
		elseif self.shooting then
			remaining = windup
		end
	end
	-- only touch the font string when the shown value actually changes
	local tenths = remaining and math.floor(math.max(remaining, 0) * 10 + 0.5) or -1
	if tenths ~= self.lastTenths then
		self.lastTenths = tenths
		self.text:SetText(tenths >= 0 and string.format("%.1f", tenths / 10) or "")
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

---------------------------------------------------------------------------
-- Glow: none while the bar is full, builds up as the reload runs out,
-- full (optionally pulsing) while you need to stand still.
---------------------------------------------------------------------------
local GLOW_TEX = "Interface\\AddOns\\YaHT\\media\\Glow"
-- 9-slice pieces of the 64x64 glow texture (corners are the outer 16px)
local GLOW_PIECES = {
	-- name, texcoords, anchor function
	{"TL", 0, .25, 0, .25}, {"T", .25, .75, 0, .25}, {"TR", .75, 1, 0, .25},
	{"L", 0, .25, .25, .75},                         {"R", .75, 1, .25, .75},
	{"BL", 0, .25, .75, 1}, {"B", .25, .75, .75, 1}, {"BR", .75, 1, .75, 1},
}

local function CreateGlow(f)
	local glow = CreateFrame("Frame", "YaHTMainFrameGlow", f)
	glow:SetAllPoints(f)
	glow:SetFrameLevel(math.max(f:GetFrameLevel() - 1, 0))
	glow.pieces = {}
	for _, piece in ipairs(GLOW_PIECES) do
		local t = glow:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(GLOW_TEX)
		t:SetTexCoord(piece[2], piece[3], piece[4], piece[5])
		t:SetBlendMode("ADD")
		glow.pieces[piece[1]] = t
	end
	-- crisp outline look
	glow.outline = {}
	for _, side in ipairs({"T", "B", "L", "R"}) do
		local t = glow:CreateTexture(nil, "BACKGROUND")
		t:SetTexture("Interface\\Buttons\\WHITE8X8")
		t:SetBlendMode("ADD")
		glow.outline[side] = t
	end
	glow:SetAlpha(0)

	-- sweep: a light streak running across the bar (clipped to the bar)
	local clip = CreateFrame("Frame", nil, f)
	clip:SetAllPoints(f)
	clip:SetFrameLevel(f:GetFrameLevel() + 2)
	if clip.SetClipsChildren then clip:SetClipsChildren(true) end
	local sweep = clip:CreateTexture(nil, "OVERLAY")
	sweep:SetTexture("Interface\\AddOns\\YaHT\\media\\Shine")
	sweep:SetBlendMode("ADD")
	sweep:Hide()
	f.sweep = sweep

	-- sparks at the moving edge(s) of the bar
	local sparkFrame = CreateFrame("Frame", nil, f)
	sparkFrame:SetAllPoints(f)
	sparkFrame:SetFrameLevel(f:GetFrameLevel() + 3)
	f.sparkFrame = sparkFrame
	f.sparks = {}
	for _, edge in ipairs({"LEFT", "RIGHT"}) do
		local sp = sparkFrame:CreateTexture(nil, "OVERLAY")
		sp:SetTexture("Interface\\AddOns\\YaHT\\media\\Spark")
		sp:SetBlendMode("ADD")
		sp:Hide()
		f.sparks[edge] = sp
	end
	return glow
end

function YaHT:ApplyGlowSettings()
	local config = self.db.profile
	local f = self.mainFrame
	local glow, P = f.glow, f.glow.pieces
	local g = config.glowsize
	for _, t in pairs(P) do
		t:ClearAllPoints()
		t:SetVertexColor(config.glowcolor.r, config.glowcolor.g, config.glowcolor.b)
	end
	P.TL:SetSize(g, g) P.TL:SetPoint("BOTTOMRIGHT", f, "TOPLEFT")
	P.TR:SetSize(g, g) P.TR:SetPoint("BOTTOMLEFT", f, "TOPRIGHT")
	P.BL:SetSize(g, g) P.BL:SetPoint("TOPRIGHT", f, "BOTTOMLEFT")
	P.BR:SetSize(g, g) P.BR:SetPoint("TOPLEFT", f, "BOTTOMRIGHT")
	P.T:SetHeight(g) P.T:SetPoint("BOTTOMLEFT", f, "TOPLEFT") P.T:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT")
	P.B:SetHeight(g) P.B:SetPoint("TOPLEFT", f, "BOTTOMLEFT") P.B:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT")
	P.L:SetWidth(g) P.L:SetPoint("TOPRIGHT", f, "TOPLEFT") P.L:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT")
	P.R:SetWidth(g) P.R:SetPoint("TOPLEFT", f, "TOPRIGHT") P.R:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT")
	local soft = config.glowlook ~= "OUTLINE"
	for _, t in pairs(P) do t:SetShown(soft) end
	local o, th = glow.outline, math.max(1, math.floor(g / 4))
	for _, t in pairs(o) do
		t:ClearAllPoints()
		t:SetVertexColor(config.glowcolor.r, config.glowcolor.g, config.glowcolor.b)
		t:SetShown(not soft)
	end
	o.T:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -th - 1, 1) o.T:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", th + 1, 1) o.T:SetHeight(th)
	o.B:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -th - 1, -1) o.B:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", th + 1, -1) o.B:SetHeight(th)
	o.L:SetPoint("TOPRIGHT", f, "TOPLEFT", -1, 1) o.L:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -1, -1) o.L:SetWidth(th)
	o.R:SetPoint("TOPLEFT", f, "TOPRIGHT", 1, 1) o.R:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 1, -1) o.R:SetWidth(th)

	local sc = config.sparkcolor
	for edge, sp in pairs(f.sparks) do
		sp:ClearAllPoints()
		sp:SetPoint("CENTER", f.texture, edge)
		f.sparksCentered = false
		sp:SetSize(math.max(config.height * 1.2, 8), config.height * config.sparksize)
		sp:SetVertexColor(sc.r, sc.g, sc.b, sc.a or 1)
	end
	f.sweep:SetSize(math.max(config.width * 0.25, 30), config.height * 3)
	f.sweep:SetVertexColor(config.glowcolor.r, config.glowcolor.g, config.glowcolor.b)

	if config.glow then glow:Show() else glow:Hide() self:StopFancyGlow() end
	-- restart the animated effect so color/style changes apply
	if self.fancyGlow then self:StopFancyGlow() end
end

local function AnchorSparks(self, centered)
	if self.sparksCentered == centered then return end
	self.sparksCentered = centered
	for edge, sp in pairs(self.sparks) do
		sp:ClearAllPoints()
		if centered then
			sp:SetPoint("CENTER", self, "CENTER", edge == "LEFT" and -3 or 3, 0)
		else
			sp:SetPoint("CENTER", self.texture, edge)
		end
	end
end

local function SetSparkFrameAlpha(self, alpha, ignoreBarFade)
	local sf = self.sparkFrame
	if sf.SetIgnoreParentAlpha then
		sf:SetIgnoreParentAlpha(ignoreBarFade)
		sf:SetAlpha(alpha)
	elseif ignoreBarFade then
		-- older clients: undo the bar's fade by hand
		sf:SetAlpha(math.min(alpha / math.max(self:GetAlpha(), 0.05), 1))
	else
		sf:SetAlpha(alpha)
	end
end

local function UpdateSpark(self, standing)
	local config = YaHT.db.profile
	-- Moving while the shot is ready: two lines pulse in the middle of the
	-- bar, bright even though the bar itself is faded, until you stop.
	if config.readypulse and config.lock and self.readyMoving then
		AnchorSparks(self, true)
		local pulse = 0.5 + 0.5 * math.sin(GetTime() * math.pi * 2 * 2.5) -- 2.5 pulses/sec
		SetSparkFrameAlpha(self, 0.35 + 0.65 * pulse, true)
		self.sparks.LEFT:Show()
		self.sparks.RIGHT:Show()
		return
	end
	AnchorSparks(self, false)
	SetSparkFrameAlpha(self, 1, false)
	local mode = config.sparkmode
	local active = mode == "ALWAYS" or (mode == "STAND" and standing)
	if active and not config.lock then active = true end
	if active and config.lock and not self.shooting and not self.SwingStart then active = false end
	local w = self.texture:GetWidth()
	if w and w < 1 then active = false end -- nothing to put a spark on yet
	self.sparks.RIGHT:SetShown(active)
	-- with "fill from middle" the bar grows both ways, so both edges spark
	self.sparks.LEFT:SetShown(active and config.fill)
end

local function IsStanding(self)
	local config = YaHT.db.profile
	if not config.lock then return self.mockTime > self.swingtime end
	return self.SwingStart ~= nil
end

local function UpdateGlow(self)
	local config = YaHT.db.profile
	local standing = IsStanding(self)
	UpdateSpark(self, standing)
	local now = GetTime()
	-- built-in sweep for the stand-still part
	if config.glow and standing and config.glowstyle == "SWEEP" then
		local sw = self.sweep
		local span = self:GetWidth() + sw:GetWidth()
		local pos = ((now * 1.6) % 1) * span - sw:GetWidth() / 2
		sw:ClearAllPoints()
		sw:SetPoint("CENTER", self, "LEFT", pos, 0)
		sw:SetAlpha(config.glowintensity)
		sw:Show()
	else
		self.sweep:Hide()
	end
	if not config.glow then return end
	local level -- 0..1
	if standing then
		level = 1
	elseif not config.lock then
		level = self.mockTime / self.swingtime
	elseif self.shooting then
		level = math.min(math.max((now - self.lastshot) / self.swingtime, 0), 1)
	else
		level = 0
	end
	if not standing then
		if config.glowmode == "STAND" then
			level = 0
		else
			-- ease in: barely visible early, ramps up near the end of the reload
			level = (level ^ 2) * config.glowramp
		end
	elseif config.glowpulse then
		level = 0.8 + 0.2 * math.sin(now * math.pi * 2 * 2) -- 2 pulses/sec, never dims much
	end
	-- Fancy animated effect from LibCustomGlow (shipped inside many glow
	-- addons, WeakAuras, ElvUI...) for the stand-still part, if chosen.
	local fancy = config.glowstyle ~= "BUILTIN" and config.glowstyle ~= "SWEEP" and standing
	if fancy and not YaHT:StartFancyGlow() then fancy = false end
	if not fancy then YaHT:StopFancyGlow() end
	if fancy and not config.glowkeepbuiltin then level = 0 end
	self.glow:SetAlpha(level * config.glowintensity)
end

local LCG_KEY = "YaHT"
function YaHT:GetLCG()
	return LibStub and LibStub("LibCustomGlow-1.0", true)
end

function YaHT:StartFancyGlow()
	local config = self.db.profile
	local LCG = self:GetLCG()
	if not LCG then return false end
	if self.fancyGlow == config.glowstyle then return true end
	self:StopFancyGlow()
	local f = self.mainFrame
	local c = {config.glowcolor.r, config.glowcolor.g, config.glowcolor.b, 1}
	local ok
	if config.glowstyle == "PIXEL" and LCG.PixelGlow_Start then
		ok = pcall(LCG.PixelGlow_Start, f, c, 12, 0.25, nil, 2, 2, 2, false, LCG_KEY)
	elseif config.glowstyle == "AUTOCAST" and LCG.AutoCastGlow_Start then
		ok = pcall(LCG.AutoCastGlow_Start, f, c, 8, 0.25, 1, 0, 0, LCG_KEY)
	elseif config.glowstyle == "PROC" and LCG.ProcGlow_Start then
		ok = pcall(LCG.ProcGlow_Start, f, {color = c, key = LCG_KEY, startAnim = true, xOffset = 4, yOffset = 4})
	elseif config.glowstyle == "BUTTON" and LCG.ButtonGlow_Start then
		ok = pcall(LCG.ButtonGlow_Start, f, c)
	end
	if ok then self.fancyGlow = config.glowstyle end
	return ok and true or false
end

function YaHT:StopFancyGlow()
	if not self.fancyGlow then return end
	local LCG = self:GetLCG()
	local f = self.mainFrame
	if LCG then
		if self.fancyGlow == "PIXEL" and LCG.PixelGlow_Stop then pcall(LCG.PixelGlow_Stop, f, LCG_KEY)
		elseif self.fancyGlow == "AUTOCAST" and LCG.AutoCastGlow_Stop then pcall(LCG.AutoCastGlow_Stop, f, LCG_KEY)
		elseif self.fancyGlow == "PROC" and LCG.ProcGlow_Stop then pcall(LCG.ProcGlow_Stop, f, LCG_KEY)
		elseif self.fancyGlow == "BUTTON" and LCG.ButtonGlow_Stop then pcall(LCG.ButtonGlow_Stop, f)
		end
	end
	self.fancyGlow = nil
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

	self.calib = self.db.char.calib -- learned shot delay from last session
	self:Load()
	if self.InitAmmo then self:InitAmmo() end
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
	if f.glow then self:ApplyGlowSettings() end
	if self.ApplyAmmoSettings then self:ApplyAmmoSettings() end
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
		ok, err = pcall(UpdateGlow, frame)
		if not ok then ReportError("UpdateGlow", err) end
	end)

	f.background = f:CreateTexture("YaHTMainFrameBackground", "BACKGROUND")
	f.background:SetAllPoints(f)
	if f.background.SetHorizTile then
		f.background:SetHorizTile(true)
		f.background:SetVertTile(true)
	end

	f.texture = f:CreateTexture("YaHTMainFrameBar", "ARTWORK")

	f.glow = CreateGlow(f)

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

-- The game reports the Auto Shot wind-up actually starting: restart the
-- red stand-still part from that exact moment (only once per shot).
function YaHT:SyncAutoShotCast(source)
	local f = self.mainFrame
	if not f.shooting or f.castSynced or not YaHT.db.profile.lock then return end
	f.castSynced = true
	local now = GetTime()
	f.sentAt = now
	if self.debug then
		-- + means the game started the wind-up later than the bar expected
		local predicted = f.lastshot + (f.swingtime or 0)
		if now - f.lastshot < (f.speed or 3) * 1.5 then
			self:Print(string.format("%s: wind-up start %+.3fs vs bar", source, now - predicted))
		else
			self:Print(source..": first shot wind-up started")
		end
	end
	f.SwingStart, f.fillFrom, f.nextAttempt = now, now, now
end

-- Forever doesn't send UNIT_SPELLCAST_START for Auto Shot, but it does send
-- SENT when the shot attempt begins (WeaponSwingTimer uses the same signal).
function YaHT:UNIT_SPELLCAST_SENT(unit, target, castGUID, spellID)
	if unit ~= "player" or IsSecret(spellID) or spellID ~= AUTO_SHOT_ID then return end
	self:SyncAutoShotCast("SENT")
end

function YaHT:UNIT_SPELLCAST_START(unit, castGUID, spellID)
	if unit ~= "player" or IsSecret(spellID) then return end
	if IsCastSpell(spellID) then
		self.mainFrame.casting = true
		self.mainFrame.disturbed = true
	elseif spellID == AUTO_SHOT_ID then
		self:SyncAutoShotCast("UNIT_SPELLCAST_START")
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

	-- Feign Death restarts the ranged swing (same as WeaponSwingTimer)
	if name and name == FeignDeath then
		local f = self.mainFrame
		f.lastshot = GetTime()
		f.SwingStart = nil
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
	-- Self-calibration: compare the real time since the last shot with what
	-- the game said that cycle would take. Only clean cycles count (standing
	-- still, no casts, continuous Auto Shot).
	local interval = now - f.lastshot
	local expected = f.cycleSpeed
	local clean = expected and f.shooting and not f.disturbed and not f.casting
		and interval > expected * 0.8 and interval < expected * 1.5
	-- Jitter smoothing: the real shots are evenly spaced but the message
	-- reporting each one arrives a little early/late. Keep a steady rhythm
	-- and only nudge it 30% toward each message; snap on big differences.
	local anchor, jitter = now, nil
	if clean then
		local predicted = f.lastshot + expected + ((config.autocorrect and self.calib) or 0)
		jitter = now - predicted
		if config.smooth and math.abs(jitter) < 0.15 then
			anchor = predicted + 0.3 * jitter
		end
	end
	if clean then
		local sample = math.min(math.max(interval - expected, -0.15), 0.6)
		-- slow average: learn the steady delay, ignore the per-shot jitter
		self.calib = (self.calib or 0) + 0.1 * (sample - (self.calib or 0))
		self.calibSamples = (self.calibSamples or 0) + 1
		self.db.char.calib = self.calib -- remembered for next login
	end
	if self.debug and f.sentAt then
		self:Print(string.format("shot left %.3fs after SENT (wind-up %.3f)", now - f.sentAt, Windup(f.speed)))
	end
	f.sentAt = nil
	f.cycleSpeed = f.speed
	f.disturbed = false
	f.castSynced = false

	if self.debug then
		local cdStart, cdDur = GetAutoShotCooldown()
		local function v(x) if IsSecret(x) then return "secret" end return x and string.format("%.3f", x) or "nil" end
		self:Print(string.format("%s: %.3fs since last | swing %s | windup %.3f | learned delay %+.3f (%d shots) | jitter %s | casting %s",
			source or "?", interval, v(duration), Windup(f.speed), self.calib or 0, self.calibSamples or 0,
			jitter and string.format("%+.3f", jitter) or "-", tostring(f.casting)))
	end
	f.lastshot = anchor
	f.SwingStart, f.fillFrom, f.nextAttempt, f.wasMoving = nil, nil, nil, false
	f.texture:SetVertexColor(config.timercolor.r,config.timercolor.g,config.timercolor.b)
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
	if unit ~= "player" or IsSecret(spellID) or spellID ~= AUTO_SHOT_ID then return end
	-- the attempt didn't start: the game retries after 0.5s, then winds up
	local f = self.mainFrame
	f.castSynced = false
	f.disturbed = true
	-- The failure often arrives a few ms BEFORE the bar reaches the red
	-- part, so also accept it near the end of the reload.
	local now = GetTime()
	local nearReady = f.SwingStart or (now >= f.lastshot + (f.swingtime or 0) - 0.25)
	if f.shooting and nearReady and YaHT.db.profile.lock then
		f.nextAttempt = now + 0.5
		if not IsMoving() then
			f.SwingStart, f.fillFrom = now + 0.5, now
		end
	end
	if self.debug then self:Print("Auto Shot attempt failed (retry delay)") end
end

function YaHT:PLAYER_EQUIPMENT_CHANGED()
	baseDirty = true
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
		f.SwingStart, f.fillFrom, f.nextAttempt = curTime, curTime, curTime
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
	-- while debugging, keep a copyable log (also saved to SavedVariables)
	if self.debug and self.db then
		local log = self.db.global.debuglog or {}
		self.db.global.debuglog = log
		log[#log + 1] = string.format("%.3f  %s", GetTime(), msg)
		if #log > 300 then table.remove(log, 1) end
	end
end

-- WoW chat can't be copied, so show the debug log in a selectable box.
function YaHT:ShowCopyWindow()
	local log = self.db.global.debuglog or {}
	local f = self.copyFrame
	if not f then
		f = CreateFrame("Frame", "YaHTCopyFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		f:SetSize(620, 420)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		if f.SetBackdrop then
			f:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true, tileSize = 32, edgeSize = 32,
				insets = {left = 8, right = 8, top = 8, bottom = 8},
			})
		end
		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", 0, -14)
		title:SetText("YaHT debug log  -  "..L["press Ctrl+C to copy, Esc to close"])

		local ok, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
		if ok and close then close:SetPoint("TOPRIGHT", -4, -4) end

		local okScroll, scroll = pcall(CreateFrame, "ScrollFrame", "YaHTCopyScroll", f, "UIPanelScrollFrameTemplate")
		if not okScroll then scroll = CreateFrame("ScrollFrame", "YaHTCopyScroll", f) end
		scroll:SetPoint("TOPLEFT", 18, -38)
		scroll:SetPoint("BOTTOMRIGHT", -36, 18)

		local eb = CreateFrame("EditBox", nil, scroll)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
		eb:SetWidth(560)
		eb:SetScript("OnEscapePressed", function() f:Hide() end)
		-- keep the text read-only: any typing just restores the log
		eb:SetScript("OnTextChanged", function(box, user)
			if user then box:SetText(f.logText or "") box:HighlightText() end
		end)
		scroll:SetScrollChild(eb)
		f.editBox = eb
		self.copyFrame = f
	end
	f.logText = #log > 0 and table.concat(log, "\n") or L["The log is empty. Turn on /yaht debug and shoot a few times first."]
	f.editBox:SetText(f.logText)
	f:Show()
	f.editBox:SetFocus()
	f.editBox:HighlightText()
end

SLASH_YAHT1 = "/yaht"
SLASH_YAHT2 = "/huntertimer"
SLASH_YAHT3 = "/yetanotherhuntertimer"
SlashCmdList["YAHT"] = function(msg)
	local cmd = (msg or ""):lower():match("^%s*(%S*)")
	if not YaHT.db then return end
	local p = YaHT.db.profile
	if cmd == "debug" then
		YaHT.debug = not YaHT.debug
		YaHT:Print("debug "..(YaHT.debug and "ON: shoot a target dummy standing still, then type /yaht copy" or "OFF"))
	elseif cmd == "lock" or cmd == "unlock" then
		p.lock = (cmd == "lock")
		YaHT:ApplySettings()
		YaHT:Print(p.lock and L["bar locked."] or L["bar unlocked: drag it, preview runs."])
	elseif cmd == "reset" then
		p.point, p.relativePoint, p.x, p.y = nil, nil, nil, nil
		YaHT:ApplySettings()
		YaHT:Print(L["bar moved back to the middle of the screen."])
	elseif cmd == "copy" then
		YaHT:ShowCopyWindow()
	elseif cmd == "clear" then
		YaHT.db.global.debuglog = {}
		YaHT:Print(L["debug log cleared."])
	elseif cmd == "ammo" then
		local count, icon, method = YaHT:ReadAmmo()
		YaHT:Print(string.format("ammo: %s (read from: %s)", tostring(count), tostring(method)))
	elseif cmd == "help" or cmd == "?" then
		YaHT:Print("/yaht - "..L["open options"])
		YaHT:Print("/yaht lock | unlock - "..L["lock or unlock (move + preview) the bar"])
		YaHT:Print("/yaht reset - "..L["move the bar back to the middle"])
		YaHT:Print("/yaht debug - "..L["print shot timings after every Auto Shot"])
		YaHT:Print("/yaht copy - "..L["open the debug log so you can copy it"])
		YaHT:Print("/yaht clear - "..L["empty the debug log"])
		YaHT:Print("/yaht ammo - "..L["show how much ammo YaHT counts"])
	else
		local ACR = LibStub("AceConfigRegistry-3.0", true)
		if ACR then ACR:NotifyChange("YaHT") end
		LibStub("AceConfigDialog-3.0"):Open("YaHT")
	end
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
SafeRegister("UNIT_SPELLCAST_SENT", "player")
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
