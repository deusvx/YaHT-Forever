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
YaHT.version = "1.5.7"

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

---------------------------------------------------------------------------
-- Lone Wolf mode: the bar's own look for a hunter who plays without a pet
---------------------------------------------------------------------------
-- Wanted: "Always", or "Automatic" while the game says you have Lone Wolf.
function YaHT:LoneWolfWanted()
	local p = self.db and self.db.profile
	if not p then return false end
	if p.lonewolf == "ALWAYS" then return true end
	if p.lonewolf == "AUTO" then return self.LoneWolfKnown and self.LoneWolfKnown() or false end
	return false
end
-- On: wanted, and no pet at your side. With a pet out you are hunting the
-- regular way, so everything is the regular bar and the regular pet warnings.
function YaHT:LoneWolfMode()
	if not self:LoneWolfWanted() then return false end
	local ok, out = pcall(UnitExists, "pet")
	if ok and not IsSecret(out) and out then return false end -- (a dead pet too: PET DEAD is regular news)
	return true
end
-- A colour of the bar: in Lone Wolf mode the reload colour and the glow have their own
local WOLF_COLORS = {timercolor = "lonewolfcolor", glowcolor = "lonewolfglowcolor"}
-- The cast bar style (after Bouk's Hunter Castbar, a WeakAura many hunters know): the reload in
-- blue, the stand-still part in green, always from the left, with the shot's name and its time
-- on the bar. It has its own two colours, so the regular look keeps its own.
local CASTBAR_COLORS = {timercolor = "castbarreload", drawcolor = "castbarwind"}
local function CastBar(config) return config.barstyle == "CASTBAR" end
YaHT.CastBarStyle = CastBar
-- does the bar grow from its middle? (never in the cast bar style)
local function FromMiddle(config) return config.fill and not CastBar(config) and true or false end
YaHT.FromMiddle = FromMiddle
local function Look(config, key)
	local cast = CASTBAR_COLORS[key]
	if cast and config[cast] and CastBar(config) then return config[cast] end
	local wolf = WOLF_COLORS[key]
	if wolf and config[wolf] and YaHT:LoneWolfMode() then return config[wolf] end
	return config[key]
end
YaHT.Look = Look
-- Lone Wolf "Scope": the bar as a marksman's scope. A range scale hangs under it,
-- and a crosshair locks on in the middle the moment you have to stand still.
-- (A crosshair riding the reload was tried and was too much: the reload stays plain.)
local SCOPE_ART = "Interface\\AddOns\\YaHT\\media\\WolfScope"
local SCOPE_TICKS = 8     -- the scale's parts (a longer tick at the ends and the middle)
local SCOPE_POP = 0.25    -- seconds the lock-on takes

---------------------------------------------------------------------------
-- Sounds: every sound YaHT makes is one you choose from this list
---------------------------------------------------------------------------
-- First the game's own weapon sounds, the ones a hunter already knows: they are part of the
-- game's data and are played by their file number (the same on every client that has them), so
-- nothing is shipped for them. Then three sounds made for YaHT (files in media, no recordings),
-- then three of the game's interface sounds.
local SOUND_GAME = {
	GUN1 = 567719, GUN2 = 567720, GUN3 = 567723,   -- sound/item/weapons/gun/gunload01..03
	SHOT = 567721,                                 -- .../gun/gunfire01
	BOWPULL = 567677, BOWREL = 567674,             -- sound/item/weapons/bow/bowpullback, bowrelease
	ARROW = 567672,                                -- .../bow/arrowhita
}
local SOUND_FILE = {HORN = "Sound-Horn.ogg", DRUM = "Sound-Drum.ogg", BLADE = "Sound-Blade.ogg"}
local SOUND_KIT = {PING = "MAP_PING", ALARM = "ALARM_CLOCK_WARNING_3", WARNING = "RAID_WARNING"}
-- (names an earlier test build used for sounds that were replaced by the game's own)
local SOUND_WAS = {PUMP = "GUN1", BOLT = "GUN2", BOW = "BOWREL", THUD = "ARROW"}
local SOUND_DIR = "Interface\\AddOns\\YaHT\\media\\"
YaHT.SOUND_ORDER = {"GUN1", "GUN2", "GUN3", "SHOT", "BOWPULL", "BOWREL", "ARROW", "BLADE", "HORN", "DRUM", "PING", "ALARM", "WARNING"}
YaHT.SOUND_NAME = {
	GUN1 = "Gun cocking", GUN2 = "Gun cocking (2)", GUN3 = "Gun cocking (3)", SHOT = "Gunshot",
	BOWPULL = "Bow drawn", BOWREL = "Bow released", ARROW = "Arrow hit",
	BLADE = "Blade drawn", HORN = "Hunting horn", DRUM = "Drum",
	PING = "Ping", ALARM = "Alarm", WARNING = "Raid warning",
}
function YaHT.SoundExists(id)
	if SOUND_GAME[id] or SOUND_FILE[id] then return true end
	local name = SOUND_KIT[id]
	return name ~= nil and SOUNDKIT ~= nil and SOUNDKIT[name] ~= nil
end
-- Plays the chosen sound. If it can't be played (the game doesn't have that file, a file the game
-- hasn't loaded yet, a choice from an older version), the one that sound stood for before choices existed.
function YaHT:PlayChoice(id, usual)
	id = SOUND_WAS[id] or id
	local what = SOUND_GAME[id] or (SOUND_FILE[id] and SOUND_DIR .. SOUND_FILE[id])
	local tried = ""
	if what and type(PlaySoundFile) == "function" then
		local ok, played = pcall(PlaySoundFile, what, "Master")
		if ok and played then return true, "played " .. tostring(id) end
		tried = string.format("%s would not play (%s), ", tostring(id), ok and "the game said no" or "the game raised an error")
	end
	if not (PlaySound and SOUNDKIT) then return false, tried .. "no way to play a sound" end
	local name = SOUND_KIT[id] or SOUND_KIT[usual] or "RAID_WARNING"
	local kit = SOUNDKIT[SOUND_KIT[id] or ""] or SOUNDKIT[SOUND_KIT[usual] or ""] or SOUNDKIT.RAID_WARNING
	if not kit then return false, tried .. "this game has none of the usual sounds" end
	local ok, played = pcall(PlaySound, kit, "Master")
	return true, string.format("%splayed the game's %s%s", tried, name, (ok and played == false) and " (the game said it would not play)" or "")
end

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

-- Feigning death holds the shot back just as moving does: the game keeps trying and failing until
-- you are up. The bar used to run a stand-still part the game was about to refuse (seen in game: a
-- fill to full with no shot, then an empty wait, then the real one). So for the bar, "feigned" is
-- "ready, waiting", the same as moving with the shot ready.
local function Feigning()
	if not UnitIsFeignDeath then return false end
	local ok, feigned = pcall(UnitIsFeignDeath, "player")
	if not ok or IsSecret(feigned) then return false end
	return feigned and true or false
end
local function Held() return IsMoving() or Feigning() end

-- What Auto Shot does around a Feign Death, written to the Feign Death record: when it stops and
-- starts, every failed attempt, and when the next shot leaves (after the feign, after the shot
-- before it, and how long the game says a shot takes). It answers "does the feign restart the
-- shot's timer or not", which the bar's timing after a feign depends on.
local function FeignTrace(what)
	local at = YaHT.feignAt
	if not at or not YaHT.FeignLog then return end
	local now = GetTime()
	if now - at > 10 then YaHT.feignAt = nil return end
	local f = YaHT.mainFrame
	YaHT.FeignLog(string.format("auto shot: %s at %.2fs | feigned %s | moving %s | last shot %.2fs ago | swing %.3f",
		what, now - at, tostring(Feigning()), tostring(IsMoving()), now - (YaHT.feignShot or f.lastshot), f.speed or 0))
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

-- Safety net: if something unexpected breaks, report it once in chat
-- (instead of a Lua error popup every frame) so it can be fixed.
local reportedErrors = {}
local function ReportError(where, err)
	YaHT.errorCount = (YaHT.errorCount or 0) + 1 -- (the self-test counts these)
	YaHT.lastError = where .. ": " .. tostring(err)
	local key = where..tostring(err)
	if reportedErrors[key] then return end
	reportedErrors[key] = true
	if YaHT.Record then pcall(YaHT.Record, YaHT, "error", YaHT.lastError) end -- kept in the saved record
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
		if CastBar(config) then
			-- the cast bar style, shown as it runs: the reload drains, then the stand-still part
			local full = self:GetWidth()
			if self.mockTime > self.swingtime then
				local c = Look(config, "drawcolor")
				self.texture:SetVertexColor(c.r, c.g, c.b)
				local frac = math.min(self.mockTime2 / SWING_TIME, 1)
				self.texture:SetWidth(math.max(full * (config.castbardir == "FILL" and frac or (1 - frac)), 0.01))
				self.mockTime2 = self.mockTime2 + elapsed
				if self.mockTime2 > SWING_TIME then self.mockTime = 0 end
			else
				self.mockTime2 = 0
				local c = Look(config, "timercolor")
				self.texture:SetVertexColor(c.r, c.g, c.b)
				self.texture:SetWidth(math.max(full * (1 - self.mockTime / self.swingtime), 0.01))
			end
			return
		end
		if self.mockTime > self.swingtime then
			self.texture:SetVertexColor(Look(config, "drawcolor").r,Look(config, "drawcolor").g,Look(config, "drawcolor").b)
			self.texture:SetWidth(math.max(self:GetWidth() * (1-(self.mockTime2/SWING_TIME)), 0.01))
			self.mockTime2 = self.mockTime2 + elapsed
			if self.mockTime2 > SWING_TIME then
				self.mockTime = 0
			end
		else
			self.mockTime2 = 0
			self.texture:SetVertexColor(Look(config, "timercolor").r,Look(config, "timercolor").g,Look(config, "timercolor").b)
			self.texture:SetWidth(math.max(self:GetWidth() * self.mockTime/self.swingtime, 0.01))
		end
		return
	end
	local curTime = GetTime()
	-- AUTO SHOT ENDED WITHOUT THE GAME SAYING SO (seen after walking into a dungeon: the bar then came
	-- up on every stop, winding up for a shot that never left). Auto Shot cannot run without a target,
	-- so a few seconds with none while the bar still thinks you shoot means it is over. Where the game
	-- answers the question itself, and has been seen to say "yes" during a shot run, its "no" counts too.
	if self.shooting and curTime >= (self.stillCheckAt or 0) then
		self.stillCheckAt = curTime + 0.5
		local gone
		if UnitExists then
			local ok, has = pcall(UnitExists, "target")
			if ok and not IsSecret(has) then gone = not has end
		end
		if C_Spell and C_Spell.IsAutoRepeatSpell then
			local ok, on = pcall(C_Spell.IsAutoRepeatSpell, AUTO_SHOT_ID)
			if ok and not IsSecret(on) and type(on) == "boolean" then
				if on then YaHT.autoRepeatAnswers = true gone = false
				elseif YaHT.autoRepeatAnswers then gone = true end
			end
		end
		if gone then
			self.goneSince = self.goneSince or curTime
			if curTime - self.goneSince >= 2.5 then
				self.goneSince = nil
				if YaHT.Record then YaHT:Record("bar", "Auto Shot had ended without the game saying so: bar put away") end
				YaHT:STOP_AUTOREPEAT_SPELL()
				self.lastshot = math.min(self.lastshot, curTime - self.swingtime)
				self.SwingStart = nil
				self:SetAlpha(0)
				self:Hide()
				return
			end
		else
			self.goneSince = nil
		end
	end
	-- a SENT that wasn't refused within 0.05s really started the wind-up
	if self.pendingSent and curTime - self.pendingSent > 0.05 then
		YaHT:CommitWindupStart(self.pendingSent)
	end
	if not self.SwingStart and (curTime - self.lastshot) >= self.swingtime then
		-- the game makes its first attempt now, then retries every 0.5s
		--Start Swing timer
		-- On WoW Forever Auto Shot keeps firing during Aimed Shot casts, so a
		-- cast only holds the timer if the user turns that option on.
		if self.shooting and not (self.casting and config.castholds) then
			self.texture:SetVertexColor(Look(config, "drawcolor").r,Look(config, "drawcolor").g,Look(config, "drawcolor").b)
			self:SetAlpha(config.alpha)
			self.SwingStart, self.fillFrom, self.nextAttempt = curTime, curTime, curTime
			self.fillBase, self.fillFrac = 0, 0
		else
			if not self.shooting then
				self:Hide()
			end
		end
	elseif self.SwingStart then
		if Held() then
			self.readyMoving = true -- shot is ready, you just need to stop
			self.disturbed = true -- this cycle can't be used to learn timing
			self.wasMoving = true
			self.SwingStart, self.fillFrom = curTime, curTime
			self.fillBase, self.fillFrac = 0, 0
			self.texture:SetWidth((CastBar(config) and config.castbardir ~= "FILL") and config.width or 0.01)
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
				self.fillBase = 0
			end
			-- Fill smoothly from where the bar is now (fillBase at fillFrom) to
			-- full at the moment the shot leaves. New timing info only changes
			-- the speed, so the bar never jumps backwards while you spam keys.
			local shotAt = self.SwingStart + SWING_TIME
			local base = self.fillBase or 0
			local span = math.max(shotAt - (self.fillFrom or self.SwingStart), 0.01)
			local t = math.min(math.max((curTime - (self.fillFrom or self.SwingStart)) / span, 0), 1)
			local frac = base + (1 - base) * t
			self.fillFrac = frac
			-- (the stand-still part can also be started by a failed attempt or a key press, which
			-- do not pass the place that colours it: seen in game as a white stand-still part)
			if not self.drawTinted then
				self.drawTinted = true
				local c = Look(config, "drawcolor")
				self.texture:SetVertexColor(c.r, c.g, c.b)
			end
			-- (the cast bar style can run the stand-still part down instead of up)
			local shown = (CastBar(config) and config.castbardir ~= "FILL") and (1 - frac) or frac
			self.texture:SetWidth(math.max(config.width * shown, 0.01))
			self:SetAlpha(config.alpha)
		end
	else
		self.drawTinted = nil
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

-- The cast bar style's words: the shot's name on the left, "time left / whole time" on the right
local autoShotName
local function UpdateCastText(self)
	local ct = self.castText
	if not ct or not ct.on then return end
	local config = YaHT.db.profile
	local windup = self.windup or Windup(self.speed)
	local left, whole
	if not config.lock then
		if self.mockTime > self.swingtime then left, whole = windup - self.mockTime2, windup
		else left, whole = self.swingtime - self.mockTime, self.swingtime end
	elseif self.SwingStart then
		left, whole = (self.SwingStart + windup) - GetTime(), windup
	else
		left, whole = self.swingtime - (GetTime() - self.lastshot), self.swingtime
	end
	local a = math.floor(math.max(left or 0, 0) * 10 + 0.5)
	local b = math.floor(math.max(whole or 0, 0) * 10 + 0.5)
	if a ~= ct.a or b ~= ct.b then
		ct.a, ct.b = a, b
		ct.time:SetText(string.format("%.1f / %.1f", a / 10, b / 10))
	end
end

function YaHT:ApplyCastText()
	local config = self.db.profile
	local f = self.mainFrame
	local ct = f.castText
	ct.on = CastBar(config) and config.castbartext and true or false
	ct:SetShown(ct.on)
	if not ct.on then return end
	local font = self:GetMedia("font", config.font) or STANDARD_TEXT_FONT
	local size = math.max(8, math.min(config.height - 8, 14))
	for _, fs in ipairs({ct.name, ct.time}) do
		if not fs:SetFont(font, size, "OUTLINE") then fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
		fs:SetTextColor(1, 1, 1, 1)
	end
	autoShotName = autoShotName or GetSpellName(AUTO_SHOT_ID) or "Auto Shot"
	ct.name:SetText(autoShotName)
	ct.a, ct.b = nil, nil
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
		t:SetVertexColor(Look(config, "glowcolor").r, Look(config, "glowcolor").g, Look(config, "glowcolor").b)
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
		t:SetVertexColor(Look(config, "glowcolor").r, Look(config, "glowcolor").g, Look(config, "glowcolor").b)
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
	f.sweep:SetVertexColor(Look(config, "glowcolor").r, Look(config, "glowcolor").g, Look(config, "glowcolor").b)

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
	self.sparks.LEFT:SetShown(active and FromMiddle(config))
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

local function CreateScope(f)
	local s = CreateFrame("Frame", nil, f)
	s:SetFrameLevel(f:GetFrameLevel() + 3)
	s:SetAllPoints(f)
	s.ticks = {}
	for i = 0, SCOPE_TICKS do
		s.ticks[i] = s:CreateTexture(nil, "ARTWORK")
	end
	s.shadow = s:CreateTexture(nil, "OVERLAY", nil, 1)
	s.shadow:SetTexture(SCOPE_ART .. "Shadow")
	s.shadow:SetVertexColor(0, 0, 0)
	s.reticle = s:CreateTexture(nil, "OVERLAY", nil, 2)
	s.reticle:SetTexture(SCOPE_ART)
	s.shadow:Hide()
	s.reticle:Hide()
	return s
end

local function UpdateScope(self)
	local s = self.scope
	if not self.scopeOn or not s then return end
	local config = YaHT.db.profile
	local standing = IsStanding(self) and true or false
	local now = GetTime()
	if standing and s.wasStanding == false then s.lockAt = now end
	s.wasStanding = standing
	local r, sh = s.reticle, s.shadow
	if not standing then
		r:Hide() sh:Hide()
		return
	end
	-- locked on: dead centre, white, with a short kick as it snaps in
	local size = config.lonewolfheight
	local t = s.lockAt and (now - s.lockAt) / SCOPE_POP or 1
	if t >= 1 then s.lockAt = nil else size = size * (1 + 0.45 * (1 - t)) end
	r:ClearAllPoints()
	r:SetPoint("CENTER", self, "CENTER", 0, 0)
	r:SetVertexColor(1, 1, 1)
	r:SetSize(size, size)
	r:SetAlpha(1)
	sh:ClearAllPoints()
	sh:SetPoint("CENTER", r, "CENTER", 0, 0)
	sh:SetSize(size, size)
	sh:SetAlpha(0.85)
	r:Show() sh:Show()
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
	local c = {Look(config, "glowcolor").r, Look(config, "glowcolor").g, Look(config, "glowcolor").b, 1}
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
	self.debug = self.db.global.debug and true or false -- the debug log stays on until you switch it off
	self:Load()
	-- each feature starts on its own: if one fails, the rest (and the options) still load
	for _, init in ipairs({"InitAmmo", "InitMelee", "InitProcs", "InitFeign", "InitPet", "InitHawks", "InitTracker", "InitMinimap", "InitRecord"}) do
		if self[init] then
			local ok, err = pcall(self[init], self)
			if not ok then ReportError(init, err) end
		end
	end
	self:CreateConfig()

	-- first install: the bar starts unlocked (preview mode) - say what to do
	if not self.db.global.welcomed then
		self.db.global.welcomed = true
		self.db.global.newsSeen = self.version -- (nothing is "new" to someone who just installed it)
		self:Print(L["thanks for installing! Drag the bar where you want it, then type /yaht lock. /yaht opens the options."])
	elseif self.news and self.news.version == self.version and self.db.global.newsSeen ~= self.version then
		-- an update: the options window opens on Home with a few lines of what is new, once
		self.newsDue = true
		self:Print(string.format(L["updated to %s. Type /yaht to see what is new."], self.version))
	end
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

-- Where the middle of the bar is, measured from the middle of the screen (in
-- the units its position is stored in), whichever corner it was last anchored
-- by: dragging saves whatever anchor the game picks.
function YaHT:GetBarOffset()
	local p, f = self.db.profile, self.mainFrame
	if f and f.GetCenter and UIParent.GetCenter then
		local fx, fy = f:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if fx and fy and ux and uy then
			local us = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
			local fs = f.GetEffectiveScale and f:GetEffectiveScale() or 1
			local k = us / (fs > 0 and fs or 1)
			return math.floor(fx - ux * k + 0.5), math.floor(fy - uy * k + 0.5)
		end
	end
	if p.point == "CENTER" and p.relativePoint == "CENTER" then return p.x or 0, p.y or 0 end
	return 0, -350
end

-- Puts the bar at an exact spot (either number may be left out to keep it)
function YaHT:SetBarOffset(x, y)
	local p = self.db.profile
	local cx, cy = self:GetBarOffset()
	p.point, p.relativePoint, p.x, p.y = "CENTER", "CENTER", x or cx, y or cy
	self:ApplySettings()
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
	if FromMiddle(config) then
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
			f.texture:SetVertexColor(Look(config, "drawcolor").r,Look(config, "drawcolor").g,Look(config, "drawcolor").b)
		else
			f.texture:SetVertexColor(Look(config, "timercolor").r, Look(config, "timercolor").g,Look(config, "timercolor").b)
		end
	end

	f.texture:SetTexture(self:GetMedia("statusbar", config.statusbar))
	f.texture:SetHeight(config.height)
	-- Lone Wolf "Scope": the range scale under the bar and the crosshair on it
	f.scopeOn = self:LoneWolfMode() and config.lonewolfstyle == "SCOPE" or false
	if f.scopeOn and not f.scope then f.scope = CreateScope(f) end
	if f.scope then
		local s = f.scope
		local gc = Look(config, "glowcolor")
		for i = 0, SCOPE_TICKS do
			local t = s.ticks[i]
			local long = i % (SCOPE_TICKS / 2) == 0
			t:SetColorTexture(gc.r, gc.g, gc.b, 0.75)
			t:SetSize(1, config.height + (long and 6 or 3))
			t:ClearAllPoints()
			t:SetPoint("TOP", f, "TOPLEFT", config.width * i / SCOPE_TICKS, 0)
		end
		s:SetShown(f.scopeOn)
	end
	if f.textHolder then self:ApplyTextSettings() end
	if f.castText then self:ApplyCastText() end
	if f.glow then self:ApplyGlowSettings() end
	if self.ApplyAmmoSettings then self:ApplyAmmoSettings() end
	if self.ApplyMeleeSettings then self:ApplyMeleeSettings() end
	if self.ApplyProcSettings then self:ApplyProcSettings() end
	if self.ApplyFeignSettings then self:ApplyFeignSettings() end
	if self.ApplyPetSettings then self:ApplyPetSettings() end
	if self.ApplyHawkSettings then self:ApplyHawkSettings() end
	if self.ApplyTrackerSettings then self:ApplyTrackerSettings() end
	if self.ApplyMinimapSettings then self:ApplyMinimapSettings() end
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
		-- the options window's X and Y follow a drag
		if YaHT.menu and YaHT.menu.Render then YaHT.menu.Render() end
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
		ok, err = pcall(UpdateScope, frame)
		if not ok then ReportError("UpdateScope", err) end
		ok, err = pcall(UpdateCastText, frame)
		if not ok then ReportError("UpdateCastText", err) end
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

	-- the cast bar style's words, on the bar
	local ct = CreateFrame("Frame", "YaHTMainFrameCastText", f)
	ct:SetAllPoints(f)
	ct:SetFrameLevel(f:GetFrameLevel() + 4)
	ct.name = ct:CreateFontString(nil, "OVERLAY")
	ct.name:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
	ct.name:SetPoint("LEFT", ct, "LEFT", 5, 0)
	ct.time = ct:CreateFontString(nil, "OVERLAY")
	ct.time:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
	ct.time:SetPoint("RIGHT", ct, "RIGHT", -5, 0)
	ct:Hide()
	f.castText = ct

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
-- A wind-up we already believe in has been running for a moment (and you're
-- standing still). Extra SENT/FAILED messages then are rejected duplicate
-- requests, not a new attempt (WeaponSwingTimer ignores them the same way).
local function WindupUnderway(f, now)
	-- 0.15s grace: the game's messages can arrive ~0.1s late, so a real retry
	-- can land just after the wind-up "started"; true duplicates come later
	return f.SwingStart and not Held() and now - f.SwingStart > 0.15
		and now < f.SwingStart + (f.windup or 0.5)
end

-- The wind-up really started at `at`: move the red stand-still part there.
function YaHT:CommitWindupStart(at, source)
	local f = self.mainFrame
	f.pendingSent = nil
	f.sentAt = at
	if self.debug then
		-- + means the game started the wind-up later than the bar expected
		local predicted = f.lastshot + (f.swingtime or 0)
		if at - f.lastshot < (f.speed or 3) * 1.5 then
			self:Print(string.format("%s: wind-up start %+.3fs vs bar", source or "SENT", at - predicted))
		else
			self:Print((source or "SENT")..": first shot wind-up started")
		end
	end
	-- already in the red part: carry on from the current fill (no jump back)
	f.fillBase = f.SwingStart and (f.fillFrac or 0) or 0
	f.SwingStart, f.fillFrom, f.nextAttempt = at, GetTime(), at
end

function YaHT:SyncAutoShotCast(source)
	local f = self.mainFrame
	if not f.shooting or not YaHT.db.profile.lock then return end
	local now = GetTime()
	-- the first SENT after starting Auto Shot is always the real start
	if f.awaitFirstSent then
		f.awaitFirstSent = false
		self:CommitWindupStart(now, source)
		return
	end
	-- Don't trust it yet. A request the game refuses (a key press while you
	-- reload, or a duplicate during a running wind-up) comes as SENT + FAILED
	-- together. Only a SENT that isn't refused within a moment is a real
	-- wind-up start, even one a bit after the bar's own guess (committed from
	-- OnUpdate; the FAILED handler drops refused ones).
	f.pendingSent = now
end

---------------------------------------------------------------------------
-- Multi-Shot's short cast: a thin line under the bar that fills until the shot leaves
---------------------------------------------------------------------------
local MULTI_CAST = 0.5 -- (used until a real cast has been timed)
local castLine

local function IsMultiShot(spellID)
	if IsSecret(spellID) then return false end
	local name = GetSpellName(spellID)
	return name ~= nil and name == MultiShot
end

local function CastLine()
	if castLine then return castLine end
	local main = YaHT.mainFrame
	if not main then return nil end
	local f = CreateFrame("Frame", "YaHTCastLine", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetHeight(4)
	f:SetWidth(100)
	f.back = f:CreateTexture(nil, "BACKGROUND")
	f.back:SetAllPoints()
	f.back:SetColorTexture(0, 0, 0, 0.6)
	f.fill = f:CreateTexture(nil, "ARTWORK")
	f.fill:SetPoint("TOPLEFT")
	f.fill:SetPoint("BOTTOMLEFT")
	f.fill:SetColorTexture(1, 0.82, 0.2, 1)
	f.fill:SetWidth(0.01)
	f:Hide()
	f:SetScript("OnUpdate", function(self)
		local now = GetTime()
		if self.doneAt then -- the shot left: full for a blink, then gone
			if now - self.doneAt > 0.15 then self:Hide() end
			return
		end
		local t = now - self.from
		if self.sample and t >= self.length then -- (a sample ends by itself)
			self.doneAt = now
			self.fill:SetWidth(math.max(self.width, 0.01))
			return
		end
		if t > self.length + 1 then self:Hide() return end -- (never heard how it ended)
		-- (a request the game refuses is over before the line shows)
		self:SetAlpha(t < 0.05 and 0 or (self.alphaOn or 1))
		self.fill:SetWidth(math.max(self.width * math.min(t / self.length, 1), 0.01))
	end)
	castLine = f
	YaHT.castLine = f
	return f
end

-- The line as its settings say: where it sits, how thick and wide, its color
local function LayoutCastLine(f)
	local p, main = YaHT.db.profile, YaHT.mainFrame
	local above = p.multicastpos == "ABOVE"
	f:ClearAllPoints()
	f:SetPoint(above and "BOTTOM" or "TOP", main, above and "TOP" or "BOTTOM", p.multicastx or 0, (above and 1 or -1) + (p.multicasty or 0))
	f:SetScale(main.GetScale and main:GetScale() or 1)
	f:SetHeight(p.multicastheight or 4)
	f.width = math.max((main:GetWidth() or 100) * (p.multicastwidth or 1), 1)
	f:SetWidth(f.width)
	local c = p.multicastcolor or {r = 1, g = 0.82, b = 0.2, a = 1}
	f.fill:SetColorTexture(c.r, c.g, c.b, c.a or 1)
	f.back:SetShown(p.multicastback ~= false)
	f.alphaOn = p.multicastalpha or 1
end

-- "Show a sample" on its page: the line plays once
function YaHT:MultiCastSample()
	local f = CastLine()
	if not f then return end
	LayoutCastLine(f)
	f.from, f.doneAt, f.guid, f.sawStart, f.sample = GetTime() - 0.05, nil, nil, false, true
	f.length = self.db.char.multicastLen or MULTI_CAST
	f.fill:SetWidth(0.01)
	f:SetAlpha(f.alphaOn)
	f:Show()
end

-- how long the game says the cast is, when it says
local function CastLength()
	if not UnitCastingInfo then return nil end
	local ok, _, _, _, startMS, endMS = pcall(UnitCastingInfo, "player")
	if not ok or IsSecret(startMS) or IsSecret(endMS) then return nil end
	if type(startMS) ~= "number" or type(endMS) ~= "number" then return nil end
	local len = (endMS - startMS) / 1000
	if len >= 0.1 and len <= 3 then return len end
end

function YaHT:MultiCastStart(castGUID, source)
	if not self.db.profile.multicast then return end
	local f = CastLine()
	if not f then return end
	local now = GetTime()
	local guid = (not IsSecret(castGUID)) and castGUID or nil
	local running = f:IsShown() and not f.sample and not f.doneAt and now - f.from < f.length + 0.3
	if running then
		-- the same cast heard a second time (SENT, then START): keep the line, take what is new
		if source == "START" and (not f.guid or not guid or f.guid == guid) then
			f.sawStart = true
			f.length = CastLength() or f.length
		end
		return -- (a key press during the cast starts nothing)
	end
	LayoutCastLine(f)
	f.from, f.doneAt, f.guid, f.sawStart, f.sample = now, nil, guid, source == "START", nil
	f.length = (source == "START" and CastLength()) or self.db.char.multicastLen or MULTI_CAST
	f.fill:SetWidth(0.01)
	f:SetAlpha(0)
	f:Show()
end

-- ended = the shot left; otherwise it was refused or broken off
function YaHT:MultiCastEnd(castGUID, left)
	local f = castLine
	if not f or not f:IsShown() or f.doneAt or f.sample then return end
	local guid = (not IsSecret(castGUID)) and castGUID or nil
	if not left then
		if f.guid and guid and f.guid ~= guid then return end -- (another key press was refused, not this cast)
		f:Hide()
		return
	end
	local now = GetTime()
	local took = now - f.from
	if took >= 0.15 and took <= 2 then
		-- learn how long it really takes, for the next one
		local old = self.db.char.multicastLen
		self.db.char.multicastLen = old and (old + 0.3 * (took - old)) or took
		if not self.multicastNoted then
			self.multicastNoted = true
			self:Record("multishot", string.format("cast took %.3fs | game said %s | START seen %s", took, tostring(f.length), tostring(f.sawStart)))
		end
	end
	if self.debug then self:Print(string.format("Multi-Shot left %.3fs after the key", took)) end
	f.doneAt = now
	f:SetAlpha(took < 0.05 and 0 or (f.alphaOn or 1))
	f.fill:SetWidth(math.max(f.width, 0.01))
end

-- Forever doesn't send UNIT_SPELLCAST_START for Auto Shot, but it does send
-- SENT when the shot attempt begins (WeaponSwingTimer uses the same signal).
---------------------------------------------------------------------------
-- WHAT RESTARTS THE SHOT'S RELOAD ON FOREVER (besides a shot): a melee swing, and Feign Death.
-- From the Forever Hunter Wiki (Shot Mechanics, Melee Weaving, Ability Mechanics): "a melee swing
-- resets the ranged swing timer" (a shot does not reset the melee one), and "Feign Death resets
-- both the ranged and melee swing timers". The bar did not know either: after a melee swing or a
-- feign it showed a shot as due while the game made the whole reload run again ("the shot after
-- a feign or melee goes really slow on the bar").
-- For the feign, the reload restarts when the feign ENDS: the one feign whose next shot was timed
-- (cast 0.46 s after a shot, up about 1.3 s later, shot 3.68 s after the cast, reload 1.94 s) fits
-- that and not a restart at the cast. (A fixed three seconds after the cast was tried first: it
-- only fitted a short feign with that bow.)
---------------------------------------------------------------------------
function YaHT:RestartReload(why, at)
	local f = self.mainFrame
	if not f then return end
	local now = GetTime()
	f.lastshot = at or now
	f.SwingStart, f.fillFrom, f.nextAttempt = nil, nil, nil
	f.fillBase, f.fillFrac, f.failRun = 0, 0, 0
	f.pendingSent, f.sentAt = nil, nil
	f.disturbed = true -- (this cycle teaches the timing nothing)
	f.drawTinted = nil
	local c = Look(self.db.profile, "timercolor")
	f.texture:SetVertexColor(c.r, c.g, c.b)
	if self.Record then
		-- (the first few each session are written down, so the rule can be checked against real play)
		self.restartsSaid = (self.restartsSaid or 0) + 1
		if self.restartsSaid <= 6 then self:Record("bar", "reload restarted: " .. tostring(why)) end
	end
	if self.debug then self:Print("reload restarted: " .. tostring(why)) end
end

-- your melee weapon swung (called by the melee line's swing handler, main hand only)
function YaHT:MeleeSwung()
	if self.db.profile.meleeresets == false then return end
	self:RestartReload("melee swing")
end

-- Feign Death was cast: watch for the moment it ends (the bar's own clock does not run while the
-- bar is hidden, and Auto Shot stops at a feign, so this has a small clock of its own)
local feignEnd
function YaHT:WatchFeignEnd()
	if not feignEnd then
		feignEnd = CreateFrame("Frame")
		feignEnd:Hide()
		feignEnd:SetScript("OnUpdate", function(self, elapsed)
			self.sum = (self.sum or 0) + elapsed
			if self.sum < 0.05 then return end
			self.sum = 0
			local ok, err = pcall(function()
				local now = GetTime()
				local down = Feigning()
				if down then
					self.seen = true
				elseif self.seen then
					-- up again: the reload starts over from here
					FeignTrace("feign ended")
					YaHT:RestartReload(string.format("Feign Death ended %.2fs after its cast", now - self.castAt))
					self:Hide()
				elseif now - self.castAt > 0.6 then
					-- never seen lying down (up at once, or the game does not say): count from the cast
					FeignTrace("feign not seen: counting from the cast")
					YaHT:RestartReload("Feign Death (its end was not seen)", self.castAt)
					self:Hide()
				end
				if now - self.castAt > 370 then self:Hide() end -- (a feign lasts six minutes at most)
			end)
			if not ok then self:Hide() ReportError("WatchFeignEnd", err) end
		end)
		self.feignEndWatch = feignEnd
	end
	feignEnd.castAt, feignEnd.seen, feignEnd.sum = GetTime(), false, 0
	feignEnd:Show()
end

function YaHT:UNIT_SPELLCAST_SENT(unit, target, castGUID, spellID)
	if unit == "player" and IsMultiShot(spellID) then self:MultiCastStart(castGUID, "SENT") return end
	if unit ~= "player" or IsSecret(spellID) or spellID ~= AUTO_SHOT_ID then return end
	self:SyncAutoShotCast("SENT")
end

function YaHT:UNIT_SPELLCAST_START(unit, castGUID, spellID)
	if unit ~= "player" or IsSecret(spellID) then return end
	if IsMultiShot(spellID) then self:MultiCastStart(castGUID, "START") end
	if IsCastSpell(spellID) then
		self.mainFrame.casting = true
		self.mainFrame.disturbed = true
		if self.debug then self:Print(GetSpellName(spellID).." cast started") end
	end
end

function YaHT:UNIT_SPELLCAST_STOP(unit, castGUID, spellID)
	if unit ~= "player" or IsSecret(spellID) then return end
	if IsMultiShot(spellID) then self:MultiCastEnd(castGUID, false) end
	if IsCastSpell(spellID) then
		if self.debug and self.mainFrame.casting then self:Print(GetSpellName(spellID).." cast ended") end
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
		-- Forever blocks the combat log, so hit/miss can't be told apart: announce on cast.
		if config.tranqannounce then
			Announce(config.announcemsg, self.lastTranqTarget)
		end
	end

	if IsMultiShot(spellID) then self:MultiCastEnd(castGUID, true) end
	if IsCastSpell(spellID) then
		if self.debug and self.mainFrame.casting then self:Print(name.." cast finished") end
		self.mainFrame.casting = nil
		return
	end

	-- Feign Death does NOT restart the ranged swing on Forever. (Classic addons assume it does, and
	-- YaHT did too: the bar then showed a whole new reload while the game was already trying to
	-- shoot. Seen in the Feign Death log: Auto Shot attempts 1.2 s and 1.6 s after the feign, every
	-- half second from there, far sooner than a new reload would allow.) The reload carries on
	-- from the last shot; the cycle is only kept out of the learned delay.
	if name and name == FeignDeath then
		self.mainFrame.disturbed = true
		self.feignAt, self.feignShot = GetTime(), self.mainFrame.lastshot
		FeignTrace("feign cast, shooting " .. tostring(self.mainFrame.shooting and true or false))
		if YaHT.db.profile.feignresets ~= false then self:WatchFeignEnd() end
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
	-- Your attack speed just changed (Rapid Fire, Quick Shots, a haste buff
	-- coming or going): this cycle and the next are irregular, so neither
	-- may teach the learned delay (seen in a log: +0.10 and +0.17s samples).
	local speedChanged = expected and duration and math.abs(duration - expected) > 0.005
	local clean = expected and f.shooting and not f.disturbed and not f.casting
		and not speedChanged and not f.speedSettling
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
	f.sentAt, f.pendingSent = nil, nil
	f.failRun = 0
	f.cycleSpeed = f.speed
	f.speedSettling = speedChanged and true or false
	-- An Aimed/Multi-Shot cast still running pushes the next shot back a bit
	-- on Forever, so that cycle mustn't teach the learned delay either.
	f.disturbed = f.casting and true or false

	if self.debug then
		local function v(x) if IsSecret(x) then return "secret" end return x and string.format("%.3f", x) or "nil" end
		self:Print(string.format("%s: %.3fs since last | swing %s | windup %.3f | learned delay %+.3f (%d shots) | jitter %s | casting %s",
			source or "?", interval, v(duration), Windup(f.speed), self.calib or 0, self.calibSamples or 0,
			jitter and string.format("%+.3f", jitter) or "-", tostring(f.casting)))
	end
	f.lastshot = anchor
	if self.WeaveShot then self:WeaveShot() end -- (weave cues: your bow just fired)
	f.SwingStart, f.fillFrom, f.nextAttempt, f.wasMoving = nil, nil, nil, false
	f.fillBase, f.fillFrac = 0, 0
	f.awaitFirstSent = false -- a shot went out, so later SENTs aren't "the first"
	f.texture:SetVertexColor(Look(config, "timercolor").r,Look(config, "timercolor").g,Look(config, "timercolor").b)
end

-- WoW Forever: native swing event, fires for every swing with its duration.
function YaHT:PLAYER_SWING(duration, swingType)
	if IsSecret(duration) or IsSecret(swingType) then return end
	if type(duration) ~= "number" or duration <= 0 then return end
	if Enum and Enum.PlayerSwingType and swingType ~= Enum.PlayerSwingType.Ranged then return end
	if self.feignAt then
		FeignTrace(string.format("SHOT LEFT (next shot in %.3f)", duration))
		self.feignAt = nil
	end
	self:OnAutoShot(duration, "PLAYER_SWING")
end

-- Auto Shot tried to start but couldn't (e.g. moving); the game waits
-- ~0.5 s before retrying. The movement logic in OnUpdate models this.
function YaHT:UNIT_SPELLCAST_FAILED_QUIET(unit, castGUID, spellID)
	if unit ~= "player" or IsSecret(spellID) or spellID ~= AUTO_SHOT_ID then return end
	-- the attempt didn't start: the game retries after 0.5s, then winds up
	local f = self.mainFrame
	local now = GetTime()
	FeignTrace("attempt failed")
	-- the game often sends FAILED twice for one refused request
	if f.refusedAt and now - f.refusedAt < 0.05 then return end
	if f.pendingSent and now - f.pendingSent < 0.05 then
		-- SENT + FAILED together: the game refused a request (usually a key
		-- press). While the bow is still reloading, or during a wind-up we
		-- already track, that changes nothing: keep the bar as it is.
		f.pendingSent = nil
		local reloading = not f.SwingStart and now < f.lastshot + (f.swingtime or 0) - 0.25
		local inWindup = f.SwingStart and not Held() and now >= f.SwingStart - 0.05
			and now < f.SwingStart + (f.windup or 0.5) + 0.05
		if reloading or inWindup then
			f.refusedAt = now
			if self.debug then self:Print("Auto Shot: key press refused ("..(reloading and "reloading" or "wind-up running").."), bar unchanged") end
			return
		end
	end
	f.disturbed = true
	if WindupUnderway(f, now) then
		if self.debug then self:Print("Auto Shot: extra request rejected during wind-up, ignored") end
		return
	end
	-- The failure often arrives a few ms BEFORE the bar reaches the red
	-- part, so also accept it near the end of the reload.
	local nearReady = f.SwingStart or (now >= f.lastshot + (f.swingtime or 0) - 0.25)
	if f.shooting and nearReady and YaHT.db.profile.lock then
		f.nextAttempt = now + 0.5
		-- (only the game's own retries count, half a second apart: failures from hammering a
		-- key come faster, and for those the bar must never jump back)
		local since = f.lastFail and (now - f.lastFail)
		f.failRun = (since and since > 0.4 and since < 0.7) and ((f.failRun or 0) + 1) or 1
		f.lastFail = now
		if not Held() then
			-- The same when the stand-still part had not really begun (the failure comes right as the
			-- reload ends): there is nothing to jump back from, and stretching the fill over the
			-- retry made that shot's bar run at half speed.
			local sofar = f.SwingStart and (f.fillFrac or 0) or 0
			if f.failRun >= 3 or sofar < 0.04 then
				-- Attempt after attempt fails while you stand (feigning, in melee, in the deadzone, no
				-- line of sight): no shot is winding up. Carrying the fill on from where it was made
				-- the bar creep ever slower toward full (half of what was left with each failure), and
				-- the shot that finally came had nothing left to show. So: empty until the game's
				-- next attempt, and from there the real stand-still part, at its real speed.
				f.fillBase, f.fillFrac = 0, 0
				f.SwingStart, f.fillFrom = now + 0.5, now + 0.5
			else
				f.fillBase = f.SwingStart and (f.fillFrac or 0) or 0
				f.SwingStart, f.fillFrom = now + 0.5, now
			end
		end
	end
	if self.debug then self:Print("Auto Shot attempt failed (retry delay)") end
end

function YaHT:PLAYER_EQUIPMENT_CHANGED()
	baseDirty = true
	self.mainFrame.newspeed = GetRangedSpeed()
end

function YaHT:START_AUTOREPEAT_SPELL()
	local config = YaHT.db.profile
	if self.debug then self:Print("START_AUTOREPEAT_SPELL") end
	FeignTrace("started")
	local f = self.mainFrame
	local curTime = GetTime()
	f.shooting = true
	f.disturbed = true -- a restart never counts toward learning the delay
	f.awaitFirstSent = true
	if curTime - f.lastshot < f.swingtime then
		f.texture:SetVertexColor(Look(config, "timercolor").r,Look(config, "timercolor").g,Look(config, "timercolor").b)
	else
		f.texture:SetVertexColor(Look(config, "drawcolor").r,Look(config, "drawcolor").g,Look(config, "drawcolor").b)
		f.SwingStart, f.fillFrom, f.nextAttempt = curTime, curTime, curTime
		f.fillBase, f.fillFrac = 0, 0
		if Held() then
			f.lastshot = curTime - f.swingtime
		end
	end
	f:SetAlpha(config.alpha)
	f:Show()
end

function YaHT:STOP_AUTOREPEAT_SPELL()
	local f = self.mainFrame
	if self.debug then self:Print("STOP_AUTOREPEAT_SPELL") end
	FeignTrace("stopped")
	f.shooting = nil
	f.disturbed = true
	f.pendingSent = nil
	if YaHT.db.profile.lock and (GetTime() - f.lastshot) >= f.swingtime then
		f:SetAlpha(0)
		f:Hide()
	end
end

function YaHT:UNIT_RANGEDDAMAGE(unit)
	if unit and unit ~= "player" then return end
	self.mainFrame.newspeed = GetRangedSpeed()
end

local DEBUG_LOG_MAX = 800 -- lines kept (and saved); the oldest drop off

-- direct: an answer to something you just asked for; always in the main chat.
-- Everything else printed while the debug log is on is a debug line, and goes
-- where "Show its lines in" says: the main chat, another chat tab, or nowhere
-- (the log keeps every line either way). YaHT's lines aren't a chat channel,
-- so the game's own chat settings can't move them.
function YaHT:Print(msg, direct)
	local chat = DEFAULT_CHAT_FRAME
	if self.debug and self.db and not direct and not self.replying then
		local where = self.db.global.debugwindow or 0
		if where == -1 then
			chat = nil
		elseif where > 0 then
			chat = _G["ChatFrame" .. where] or chat
		end
	end
	if chat then chat:AddMessage("|cFF2150C2YaHT|cFFFFFFFF: ".. msg) end
	-- while debugging, keep a copyable log (also saved to SavedVariables)
	if self.debug and self.db then
		local log = self.db.global.debuglog or {}
		self.db.global.debuglog = log
		log[#log + 1] = string.format("%.3f  %s", GetTime(), msg)
		if #log > DEBUG_LOG_MAX then table.remove(log, 1) end
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
		title:SetText("YaHT Forever debug log  -  "..L["press Ctrl+C to copy, Esc to close"])

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
local function HandleSlash(msg)
	local cmd = (msg or ""):lower():match("^%s*(%S*)")
	if not YaHT.db then return end
	local p = YaHT.db.profile
	if cmd == "debug" then
		YaHT.debug = not YaHT.debug
		YaHT.db.global.debug = YaHT.debug
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
	elseif cmd == "feign" then
		if YaHT.TestFeignAlert then YaHT:TestFeignAlert() end
	elseif cmd == "buffs" then
		if YaHT.ReportBuffs then YaHT:ReportBuffs() end
	elseif cmd == "pet" then
		if YaHT.ReportPet then YaHT:ReportPet() end
	elseif cmd == "track" or cmd == "tracking" then
		if YaHT.ReportTracker then YaHT:ReportTracker() end
	elseif cmd == "hawk" or cmd == "hawks" then
		if YaHT.ReportHawks then YaHT:ReportHawks() end
	elseif cmd == "minimap" then
		if YaHT.ToggleMinimapButton then YaHT:ToggleMinimapButton() end
	elseif cmd == "new" or cmd == "news" then
		YaHT.newsDue = YaHT.news ~= nil
		if YaHT.OpenMenu then
			YaHT:CloseMenu()
			YaHT:OpenMenu("news")
		end
	elseif cmd == "grid" then
		if YaHT.ToggleGrid then YaHT:ToggleGrid() end
	elseif cmd == "selftest" or cmd == "test" or cmd == "record" then
		if not YaHT.SelfTest then
			-- a file added by an update only loads when the game itself starts
			YaHT:Print(L["that part of YaHT isn't loaded yet: quit the game completely and start it again."])
		elseif cmd == "record" then
			YaHT:PrintRecord((msg or ""):lower():match("^%s*%S+%s+(%S+)"))
		else
			YaHT:SelfTest()
		end
	elseif cmd == "help" or cmd == "?" then
		YaHT:Print("/yaht - "..L["open options"])
		YaHT:Print("/yaht lock | unlock - "..L["lock or unlock (move + preview) the bar"])
		YaHT:Print("/yaht reset - "..L["move the bar back to the middle"])
		YaHT:Print("/yaht debug - "..L["print shot timings after every Auto Shot"])
		YaHT:Print("/yaht copy - "..L["open the debug log so you can copy it"])
		YaHT:Print("/yaht clear - "..L["empty the debug log"])
		YaHT:Print("/yaht ammo - "..L["show how much ammo YaHT counts"])
		YaHT:Print("/yaht buffs - "..L["list your buffs as YaHT sees them (Quick Shots, aspect)"])
		YaHT:Print("/yaht feign - "..L["play the Feign Death resist alert once"])
		YaHT:Print("/yaht pet - "..L["show what YaHT sees of your pet"])
		YaHT:Print("/yaht hawk - "..L["show what YaHT sees of your hawks"])
		YaHT:Print("/yaht grid - "..L["show or hide the alignment grid"])
		YaHT:Print("/yaht minimap - "..L["show or hide the minimap button"])
		YaHT:Print("/yaht selftest - "..L["run a self-test in the game and save a report"])
		YaHT:Print("/yaht record - "..L["show the newest lines of the record (pet, aspect, problems)"])
		YaHT:Print("/yaht classic - "..L["open the old options window"])
	elseif cmd == "classic" then
		LibStub("AceConfigDialog-3.0"):Open("YaHT")
	else
		-- YaHT's own window; if it can't be built, the Ace3 dialog still works
		local ok, opened = false, false
		if YaHT.OpenMenu then ok, opened = pcall(YaHT.OpenMenu, YaHT) end
		if not ok or not opened then
			if YaHT.OpenMenu and not ok then ReportError("the options window", opened) end
			LibStub("AceConfigDialog-3.0"):Open("YaHT")
		end
	end
end

-- What a /yaht command prints is an answer to you: it always shows in the main chat
SlashCmdList["YAHT"] = function(msg)
	YaHT.replying = true
	local ok, err = pcall(HandleSlash, msg)
	YaHT.replying = false
	if not ok then ReportError("/yaht", err) end
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

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		YaHT:OnInitialize()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif YaHT.db and YaHT[event] then
		local ok, err = pcall(YaHT[event], YaHT, ...)
		if not ok then ReportError(event, err) end
	end
end)
