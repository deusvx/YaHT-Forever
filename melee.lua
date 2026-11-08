-- YaHT melee swing line: a hair-thin line under the Auto Shot bar that fills
-- with your melee swing. It fades in only while you're hitting things in
-- melee, turns gold while Raptor Strike is queued on your next swing, and a
-- small glint runs along it on every swing. Quiet on purpose: the Auto Shot
-- bar stays the main thing.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FADE_IN, FADE_OUT = 0.25, 0.6  -- seconds for a full fade
local LINGER = 0.75                   -- extra time to stay after the last swing should have landed
local GLINT_TIME = 0.35               -- how long the glint takes to cross the line
local PREVIEW_SPEED = 2.8             -- swing time shown while the bar is unlocked
-- Raptor Strike, all Classic ranks (queued "on next swing")
local RAPTOR_IDS = {2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266}

local frame, events

local function MainHandSpeed()
	if not UnitAttackSpeed then return nil end
	local ok, speed = pcall(UnitAttackSpeed, "player")
	if not ok or IsSecret(speed) or type(speed) ~= "number" or speed <= 0 then return nil end
	return speed
end

-- Is Raptor Strike waiting for the next swing? Checked a few times a second.
local function RaptorQueued()
	local fn = (C_Spell and C_Spell.IsCurrentSpell) or IsCurrentSpell
	if not fn then return false end
	for i = 1, #RAPTOR_IDS do
		local ok, cur = pcall(fn, RAPTOR_IDS[i])
		if ok and cur and not IsSecret(cur) then return true end
	end
	return false
end

-- How visible the line should be right now (0..1).
local function TargetAlpha(self, p, now)
	if not p.melee then return 0 end
	if not p.lock then return 1 end -- unlocked: always preview it
	if p.meleemode == "COMBAT" and self.inCombat then return 1 end
	-- only while meleeing: swings keep coming, or melee attack was just turned on
	local dur = self.swingDur or MainHandSpeed() or 3
	if self.lastSwing and now - self.lastSwing < dur + LINGER then return 1 end
	if self.meleeOn and self.meleeOnAt and now - self.meleeOnAt < 1.5 then return 1 end
	return 0
end

local function OnUpdate(self, elapsed)
	local p = YaHT.db.profile
	local now = GetTime()

	-- fade toward the wanted visibility
	local want = TargetAlpha(self, p, now)
	local a = self.fade or 0
	if a < want then
		a = math.min(want, a + elapsed / FADE_IN)
	elseif a > want then
		a = math.max(want, a - elapsed / FADE_OUT)
	end
	self.fade = a
	self:SetAlpha(a * (p.meleealpha or 1))
	if a <= 0 and want <= 0 then
		self:Hide() -- nothing to show: no work at all until the next swing/event
		return
	end

	local width = self.lineWidth or 1
	local frac
	if not p.lock then
		-- preview: a steady pretend swing so you can see it while placing the bar
		local t = now % PREVIEW_SPEED
		if self.previewLast and t < self.previewLast then self.glintAt = now end
		self.previewLast = t
		frac = t / PREVIEW_SPEED
	elseif self.swingStart and self.swingDur then
		frac = math.min(math.max((now - self.swingStart) / self.swingDur, 0), 1)
	else
		frac = 0
	end
	self.fill:SetWidth(math.max(width * frac, 0.01))

	-- gold while Raptor Strike is queued (checked every 0.1s, not every frame)
	self.raptorCheck = (self.raptorCheck or 0) - elapsed
	if self.raptorCheck <= 0 then
		self.raptorCheck = 0.1
		self.raptor = p.meleeraptor and p.lock and RaptorQueued() or false
	end
	local c = self.raptor and p.meleeraptorcolor or p.meleecolor
	self.fill:SetVertexColor(c.r, c.g, c.b, c.a or 1)

	-- glint running along the line right after a swing
	if p.meleeglint and self.glintAt and now - self.glintAt < GLINT_TIME then
		local g = (now - self.glintAt) / GLINT_TIME
		self.glint:ClearAllPoints()
		self.glint:SetPoint("LEFT", self, "LEFT", -12 + (width + 12) * g, 0)
		self.glint:SetAlpha(0.9 * (1 - g))
		self.glint:Show()
	else
		self.glint:Hide()
	end
end

function YaHT:ApplyMeleeSettings()
	if not frame then return end
	local p = self.db.profile
	local f = self.mainFrame
	frame:SetScale(p.scale)
	frame:ClearAllPoints()
	-- sit just under the bar, clear of its border when that is shown
	local gap = p.enableborder and 5 or 2
	frame:SetPoint("TOP", f, "BOTTOM", 0, -gap)
	frame.lineWidth = p.width
	frame:SetWidth(p.width)
	frame:SetHeight(p.meleeheight)
	frame.track:SetVertexColor(0, 0, 0, 0.45)
	frame.fill:SetHeight(p.meleeheight)
	frame.glint:SetSize(12, p.meleeheight + 2)
	if p.melee then frame:Show() else frame.fade = 0 frame:SetAlpha(0) frame:Hide() end
end

-- A melee swing just landed (or was swung).
function YaHT:OnMeleeSwing(duration)
	if not frame then return end
	local now = GetTime()
	frame.swingStart = now
	frame.swingDur = duration or MainHandSpeed() or frame.swingDur or 3
	frame.lastSwing = now
	frame.glintAt = now
	if self.db.profile.melee then frame:Show() end
end

local function OnEvent(_, event, ...)
	if not YaHT.db then return end
	local now = GetTime()
	if event == "PLAYER_SWING" then
		local duration, swingType = ...
		if IsSecret(duration) or IsSecret(swingType) then return end
		local mainHand = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.MainHand or 0
		if swingType ~= mainHand then return end
		if type(duration) ~= "number" or duration <= 0 then duration = nil end
		YaHT:OnMeleeSwing(duration)
	elseif event == "PLAYER_ENTER_COMBAT" then -- melee auto-attack switched on
		frame.meleeOn, frame.meleeOnAt = true, now
		if YaHT.db.profile.melee then frame:Show() end
	elseif event == "PLAYER_LEAVE_COMBAT" then -- melee auto-attack switched off
		frame.meleeOn = false
	elseif event == "PLAYER_REGEN_DISABLED" then
		frame.inCombat = true
		if YaHT.db.profile.melee and YaHT.db.profile.meleemode == "COMBAT" then frame:Show() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		frame.inCombat = false
	end
end

function YaHT:InitMelee()
	frame = CreateFrame("Frame", "YaHTMeleeFrame", UIParent)
	frame:SetFrameStrata("MEDIUM")

	frame.track = frame:CreateTexture(nil, "BACKGROUND")
	frame.track:SetTexture(WHITE)
	frame.track:SetAllPoints(frame)

	frame.fill = frame:CreateTexture(nil, "ARTWORK")
	frame.fill:SetTexture(WHITE)
	frame.fill:SetPoint("LEFT", frame, "LEFT")

	frame.glint = frame:CreateTexture(nil, "OVERLAY")
	frame.glint:SetTexture(WHITE)
	frame.glint:SetBlendMode("ADD")
	frame.glint:SetVertexColor(1, 1, 1)
	frame.glint:Hide()

	frame.fade = 0
	frame:SetAlpha(0)
	frame:SetScript("OnUpdate", function(f, elapsed)
		local ok, err = pcall(OnUpdate, f, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError("MeleeUpdate", err) end
	end)
	self.meleeFrame = frame

	events = CreateFrame("Frame")
	for _, e in ipairs({"PLAYER_SWING", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
		pcall(events.RegisterEvent, events, e)
	end
	events:SetScript("OnEvent", function(...)
		local ok, err = pcall(OnEvent, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError("MeleeEvent", err) end
	end)

	self:ApplyMeleeSettings()
end
