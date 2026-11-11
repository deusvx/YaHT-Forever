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

local STRIPES = "Interface\\AddOns\\YaHT\\media\\Stripes"
local STRIPE_TILE = 16                 -- the stripe texture is 16x16 and repeats
local STRIPE_SPEED = 12                -- pixels per second the stripes drift
local STRIPE_GAP = {0.165, 0.141, 0.094} -- dark color between the stripes
local CHEVRON = "Interface\\AddOns\\YaHT\\media\\Chevron"
local CHEVRONS_PER_SIDE = 5            -- arrows sliding in from each end when too far
local GLOW_TEX = "Interface\\AddOns\\YaHT\\media\\Glow"
-- 9-slice pieces of the 64x64 glow texture (corners are the outer 16px)
local GLOW_PIECES = {
	{"TL", 0, .25, 0, .25}, {"T", .25, .75, 0, .25}, {"TR", .75, 1, 0, .25},
	{"L", 0, .25, .25, .75},                         {"R", .75, 1, .25, .75},
	{"BL", 0, .25, .75, 1}, {"B", .25, .75, .75, 1}, {"BR", .75, 1, .75, 1},
}
local CHEVRON_SPEED = 18               -- pixels per second toward the middle
local POSITION_EVERY = 0.15             -- how often range is read while engaged
local AUTO_SHOT, WING_CLIP = 75, 2974  -- Raptor Strike reports "in range" at any distance on Forever
local FOLLOW_RANGE = 4                 -- CheckInteractDistance index (about 28 yards)

local frame, events, overlay

-- Where the deadzone warning goes: on the line, or over the Auto Shot bar.
-- The bar version falls back to the line while the bar itself is hidden.
local function DeadOnBar(p)
	local f = YaHT.mainFrame
	return p.meleedeadstyle == "BAR" and f and f:IsShown()
end

-- How strong the warning glow is right now (nil when it's switched off).
local function GlowAlpha(p, now)
	if p.meleewarnglow == "NONE" then return nil end
	local a = p.meleewarnglowalpha
	if p.meleewarnglow == "PULSE" then
		a = a * (0.55 + 0.45 * math.sin(2 * math.pi * now * p.meleewarnspeed / 1.1))
	end
	return a
end

-- Too far: arrows slide in from both ends toward the middle ("walk closer").
-- They fade in at the ends and out near the middle so nothing pops.
local BOTH_SIDES = {}
for i = 1, CHEVRONS_PER_SIDE do BOTH_SIDES[i] = {i, CHEVRONS_PER_SIDE + i} end

local function DrawChevrons(self, width, now, c, p)
	local half = width / 2
	local gap = half / CHEVRONS_PER_SIDE
	local arrowW = p.meleefarsize * 5 / 8
	local off = now * CHEVRON_SPEED * p.meleewarnspeed % gap
	for i = 1, CHEVRONS_PER_SIDE do
		local x = (i - 1) * gap + off -- distance from the end
		local a = math.min(1, x / gap, (half - x - arrowW) / gap)
		local l, r = self.chevrons[i], self.chevrons[CHEVRONS_PER_SIDE + i]
		if a > 0 then
			l:ClearAllPoints() l:SetPoint("LEFT", self, "LEFT", x, 0)
			r:ClearAllPoints() r:SetPoint("RIGHT", self, "RIGHT", -x, 0)
			l:SetVertexColor(c.r, c.g, c.b, c.a or 1) r:SetVertexColor(c.r, c.g, c.b, c.a or 1)
			l:SetAlpha(a) r:SetAlpha(a)
			l:Show() r:Show()
		else
			l:Hide() r:Hide()
		end
		local boost = p.meleewarnboost
		for _, k in ipairs(BOTH_SIDES[i]) do
			local b = self.chevronBoost[k]
			if a > 0 and boost > 0 then
				b:SetVertexColor(c.r, c.g, c.b)
				b:SetAlpha(a * boost)
				b:Show()
			else
				b:Hide()
			end
		end
	end
end

local function HideChevrons(self)
	for i = 1, #self.chevrons do self.chevrons[i]:Hide() self.chevronBoost[i]:Hide() end
end

-- Point a texture at the repeating stripes, drifting with time.
local function DrawStripes(tex, width, height, now)
	local speed = STRIPE_SPEED * YaHT.db.profile.meleewarnspeed
	local off = (now * speed % STRIPE_TILE) / STRIPE_TILE
	tex:SetTexCoord(-off, width / STRIPE_TILE - off, 0, height / STRIPE_TILE)
end

-- A soft glow around a warning (the line, or the bar's caution tape).
local function CreateWarnGlow(parent)
	local glow = {pieces = {}}
	for _, piece in ipairs(GLOW_PIECES) do
		local t = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
		t:SetTexture(GLOW_TEX)
		t:SetTexCoord(piece[2], piece[3], piece[4], piece[5])
		t:SetBlendMode("ADD")
		t:Hide()
		glow.pieces[piece[1]] = t
	end
	return glow
end

-- Wrap the glow around `target`, reaching `g` pixels out.
local function PlaceWarnGlow(glow, target, g)
	local P = glow.pieces
	for _, t in pairs(P) do t:ClearAllPoints() end
	P.TL:SetSize(g, g) P.TL:SetPoint("BOTTOMRIGHT", target, "TOPLEFT")
	P.TR:SetSize(g, g) P.TR:SetPoint("BOTTOMLEFT", target, "TOPRIGHT")
	P.BL:SetSize(g, g) P.BL:SetPoint("TOPRIGHT", target, "BOTTOMLEFT")
	P.BR:SetSize(g, g) P.BR:SetPoint("TOPLEFT", target, "BOTTOMRIGHT")
	P.T:SetHeight(g) P.T:SetPoint("BOTTOMLEFT", target, "TOPLEFT") P.T:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT")
	P.B:SetHeight(g) P.B:SetPoint("TOPLEFT", target, "BOTTOMLEFT") P.B:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT")
	P.L:SetWidth(g) P.L:SetPoint("TOPRIGHT", target, "TOPLEFT") P.L:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT")
	P.R:SetWidth(g) P.R:SetPoint("TOPLEFT", target, "TOPRIGHT") P.R:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT")
end

-- Show the glow in color c (or hide it with c = nil), soft or pulsing.
local function DrawWarnGlow(glow, c, p, now)
	local a = c and GlowAlpha(p, now)
	if not a then
		if glow.shown then
			for _, t in pairs(glow.pieces) do t:Hide() end
			glow.shown = false
		end
		return
	end
	for _, t in pairs(glow.pieces) do
		t:SetVertexColor(c.r, c.g, c.b)
		t:SetAlpha(a)
		if not glow.shown then t:Show() end
	end
	glow.shown = true
end

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

-- true / false, or nil when the game doesn't say (or hides the answer).
local function SpellInRange(spellID)
	local name = YaHT.GetSpellName(spellID)
	if not name then return nil end
	local fn = C_Spell and C_Spell.IsSpellInRange or IsSpellInRange
	if not fn then return nil end
	local ok, v = pcall(fn, name, "target")
	if not ok or IsSecret(v) or v == nil then return nil end
	return v == true or v == 1
end

-- Where you are relative to your target: "MELEE", "OK" (can shoot), "DEAD"
-- (deadzone), "FAR", or nil when that can't be known. Measured on Forever: the
-- 8-yard interact checks don't work in combat, the 28-yard one does, and that's
-- enough: not in Auto Shot range and within 28 yards can only be the deadzone.
local function ReadPosition()
	if not UnitExists or not UnitCanAttack then return nil end
	local exists, hostile = UnitExists("target"), UnitCanAttack("player", "target")
	if IsSecret(exists) or IsSecret(hostile) or not exists or not hostile then return nil end
	if UnitIsDead then
		local dead = UnitIsDead("target")
		if IsSecret(dead) or dead then return nil end
	end
	local melee = SpellInRange(WING_CLIP)
	if melee then return "MELEE" end
	local auto = SpellInRange(AUTO_SHOT)
	if auto == nil or melee == nil then return nil end
	if auto then return "OK" end
	if not CheckInteractDistance then return nil end
	local ok, near = pcall(CheckInteractDistance, "target", FOLLOW_RANGE)
	if not ok or IsSecret(near) or near == nil then return nil end
	return near and "DEAD" or "FAR"
end

-- How visible the line should be right now (0..1).
local function TargetAlpha(self, p, now)
	if not p.melee and not p.meleerange then return 0 end
	if not p.lock then return p.melee and 1 or 0 end -- unlocked: preview the swing line
	if p.meleerange then
		if self.position == "FAR" then return 1 end
		if self.position == "DEAD" and not DeadOnBar(p) then return 1 end
	end
	if not p.melee then return 0 end
	if self.position == "MELEE" then return 1 end
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
		self.fadingWarn = nil
		DrawWarnGlow(self.warnGlow, nil, p, now)
		HideChevrons(self)
		self.mode = nil
		self:Hide() -- nothing to show: no work at all until the next swing/event
		return
	end

	local width = self.lineWidth or 1
	-- Which warning to draw. When one ends (target dropped, back in range) and
	-- nothing else needs the line, keep drawing it while it fades out, so the
	-- melee line doesn't flash up underneath for a moment.
	local pos = self.position
	local live = p.lock and p.meleerange and ((pos == "DEAD" and not DeadOnBar(p)) or pos == "FAR")
	if live then
		self.fadingWarn = pos
	elseif want > 0 then
		self.fadingWarn = nil
	end
	local warnPos = live and pos or self.fadingWarn
	local deadLine = warnPos == "DEAD"
	local far = warnPos == "FAR"
	-- warnings have their own opacity, separate from the swing line's
	local opacity = (deadLine and p.meleedeadalpha) or (far and p.meleefaralpha) or p.meleealpha or 1
	self:SetAlpha(a * opacity)
	local warning = deadLine or far
	-- the deadzone gets drifting stripes, which need a few pixels to show;
	-- too far gets arrows sliding in from both ends
	local height = p.meleeheight
	if deadLine then height = p.meleedeadheight end
	if far then height = math.max(p.meleefarsize, p.meleeheight) end
	if self.drawnHeight ~= height then
		self.drawnHeight = height
		self:SetHeight(height)
		self.fill:SetHeight(height)
	end
	local frac
	if deadLine then
		frac = 1
	elseif far then
		frac = 0 -- the arrows are the whole message
	elseif not p.lock then
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
	local mode = deadLine and "STRIPES" or far and "ARROWS" or "LINE"
	if mode ~= self.mode then
		self.mode = mode
		self.striped = deadLine
		if deadLine then
			self.fill:SetTexture(STRIPES, "REPEAT", "REPEAT")
			self.fillBoost:SetTexture(STRIPES, "REPEAT", "REPEAT")
			self.track:SetVertexColor(STRIPE_GAP[1], STRIPE_GAP[2], STRIPE_GAP[3], 1)
		else
			self.fillBoost:Hide()
			self.fill:SetTexture(WHITE)
			self.fill:SetTexCoord(0, 1, 0, 1)
			self.track:SetVertexColor(0, 0, 0, far and 0 or 0.45)
		end
		if not far then HideChevrons(self) end
	end
	if deadLine then
		DrawStripes(self.fill, width, height, now)
		local boost = p.meleewarnboost
		if boost > 0 then
			-- the same stripes again, added on top: they look lit, not painted
			DrawStripes(self.fillBoost, width, height, now)
			local dc = p.meleedeadcolor
			self.fillBoost:SetVertexColor(dc.r, dc.g, dc.b)
			self.fillBoost:SetAlpha(boost)
			self.fillBoost:SetHeight(height)
			self.fillBoost:Show()
		else
			self.fillBoost:Hide()
		end
	end
	if far then DrawChevrons(self, width, now, p.meleefarcolor, p) end
	DrawWarnGlow(self.warnGlow, deadLine and p.meleedeadcolor or nil, p, now)

	-- gold while Raptor Strike is queued (checked every 0.1s, not every frame)
	self.raptorCheck = (self.raptorCheck or 0) - elapsed
	if self.raptorCheck <= 0 then
		self.raptorCheck = 0.1
		self.raptor = p.meleeraptor and p.lock and RaptorQueued() or false
	end
	local c = self.raptor and p.meleeraptorcolor or p.meleecolor
	if warning then c = deadLine and p.meleedeadcolor or p.meleefarcolor end
	self.fill:SetVertexColor(c.r, c.g, c.b, c.a or 1)

	-- glint running along the line right after a swing
	if p.meleeglint and not warning and self.glintAt and now - self.glintAt < GLINT_TIME then
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
	frame.drawnHeight = p.meleeheight
	frame.track:SetVertexColor(0, 0, 0, 0.45)
	frame.fill:SetTexture(WHITE)
	frame.fill:SetTexCoord(0, 1, 0, 1)
	frame.striped = false
	frame.mode = nil
	HideChevrons(frame)
	local arrowH = p.meleefarsize
	for i = 1, #frame.chevrons do
		frame.chevrons[i]:SetSize(arrowH * 5 / 8, arrowH)
		frame.chevronBoost[i]:SetSize(arrowH * 5 / 8, arrowH)
	end
	frame.fillBoost:Hide()
	PlaceWarnGlow(frame.warnGlow, frame, p.meleewarnglowsize)
	if overlay then
		local c = p.meleedeadcolor
		overlay.stripes:SetVertexColor(c.r, c.g, c.b, c.a or 1)
		PlaceWarnGlow(overlay.warnGlow, overlay, p.meleewarnglowsize)
	end
	frame.fill:SetHeight(p.meleeheight)
	frame.glint:SetSize(12, p.meleeheight + 2)
	if p.melee or p.meleerange then frame:Show() else frame.fade = 0 frame:SetAlpha(0) frame:Hide() end
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

local POSITION_NAMES = {MELEE = "melee", OK = "shooting range", DEAD = "deadzone", FAR = "too far"}
local pollSum = 0

-- Deadzone shown on the Auto Shot bar: caution-tape stripes over the whole bar.
local function UpdateOverlay(p, elapsed)
	local dead = p.lock and p.meleerange and frame.position == "DEAD"
	local onBar = dead and DeadOnBar(p)
	-- the bar went away while you're in the deadzone: the line takes over
	if dead and not onBar and not frame:IsShown() then frame:Show() end
	local want = onBar and 1 or 0
	local a = overlay.fade or 0
	if a == 0 and want == 0 then
		if overlay:IsShown() then overlay:Hide() end
		return
	end
	a = want > a and math.min(1, a + elapsed / 0.15) or math.max(0, a - elapsed / 0.25)
	overlay.fade = a
	-- the bar dims itself while you move with a shot ready; the warning must
	-- not, since you're usually moving to get out of the deadzone
	overlay:SetAlpha(a * (p.meleedeadalpha or 1))
	overlay:Show()
	local now = GetTime()
	DrawStripes(overlay.stripes, p.width, p.height, now)
	if p.meleewarnboost > 0 then
		DrawStripes(overlay.boost, p.width, p.height, now)
		local dc = p.meleedeadcolor
		overlay.boost:SetVertexColor(dc.r, dc.g, dc.b)
		overlay.boost:SetAlpha(p.meleewarnboost)
		overlay.boost:Show()
	else
		overlay.boost:Hide()
	end
	DrawWarnGlow(overlay.warnGlow, p.meleedeadcolor, p, now)
end

-- Reads range only while you're engaged (or always, if set so), and only with an
-- enemy targeted, so it costs next to nothing the rest of the time.
local function Poll(_, elapsed)
	local p = YaHT.db.profile
	if overlay then UpdateOverlay(p, elapsed) end
	pollSum = pollSum + elapsed
	if pollSum < POSITION_EVERY then return end
	pollSum = 0
	local engaged = p.meleerangewhen == "ALWAYS" or (InCombatLockdown and InCombatLockdown())
		or (YaHT.mainFrame and YaHT.mainFrame.shooting)
	local position
	if p.meleerange and p.lock and engaged then position = ReadPosition() end
	-- "Preview all alerts": deadzone first, then too far
	if frame.previewUntil then
		local left = frame.previewUntil - GetTime()
		if left <= 0 then
			frame.previewUntil = nil
		elseif p.meleerange then
			position = left > frame.previewHalf and "DEAD" or "FAR"
		end
	end
	if position ~= frame.position then
		frame.position = position
		if YaHT.debug then YaHT:Print("position: "..(POSITION_NAMES[position] or "unknown")) end
		if position and position ~= "OK" then frame:Show() end
	end
end

-- "Preview all alerts": show the deadzone, then the too-far warning
function YaHT:PreviewRange(seconds)
	if not frame then return end
	frame.previewUntil = GetTime() + seconds
	frame.previewHalf = seconds / 2
	frame:Show()
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
	-- "extra brightness": an added-light copy of a warning on top of it
	frame.fillBoost = frame:CreateTexture(nil, "ARTWORK", nil, 2)
	frame.fillBoost:SetBlendMode("ADD")
	frame.fillBoost:SetPoint("TOPLEFT", frame.fill, "TOPLEFT")
	frame.fillBoost:SetPoint("BOTTOMRIGHT", frame.fill, "BOTTOMRIGHT")
	frame.fillBoost:Hide()

	frame.glint = frame:CreateTexture(nil, "OVERLAY")
	frame.glint:SetTexture(WHITE)
	frame.glint:SetBlendMode("ADD")
	frame.glint:SetVertexColor(1, 1, 1)
	frame.glint:Hide()

	frame.chevrons = {}
	for i = 1, 2 * CHEVRONS_PER_SIDE do
		local t = frame:CreateTexture(nil, "OVERLAY")
		t:SetTexture(CHEVRON)
		if i > CHEVRONS_PER_SIDE then t:SetTexCoord(1, 0, 0, 1) end -- right side points left
		t:Hide()
		frame.chevrons[i] = t
	end
	frame.chevronBoost = {}
	for i = 1, #frame.chevrons do
		local b = frame:CreateTexture(nil, "OVERLAY", nil, 2)
		b:SetTexture(CHEVRON)
		b:SetBlendMode("ADD")
		if i > CHEVRONS_PER_SIDE then b:SetTexCoord(1, 0, 0, 1) end
		b:SetPoint("CENTER", frame.chevrons[i], "CENTER")
		b:Hide()
		frame.chevronBoost[i] = b
	end
	frame.warnGlow = CreateWarnGlow(frame)

	frame.fade = 0
	frame:SetAlpha(0)
	frame:SetScript("OnUpdate", function(f, elapsed)
		local ok, err = pcall(OnUpdate, f, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError("MeleeUpdate", err) end
	end)
	self.meleeFrame = frame

	-- caution tape over the Auto Shot bar (deadzone, "on the bar" option)
	local main = self.mainFrame
	if main then
		overlay = CreateFrame("Frame", "YaHTDeadzoneOverlay", main)
		overlay:SetAllPoints(main)
		overlay:SetFrameLevel(main:GetFrameLevel() + 6)
		if overlay.SetIgnoreParentAlpha then overlay:SetIgnoreParentAlpha(true) end
		overlay.base = overlay:CreateTexture(nil, "ARTWORK")
		overlay.base:SetTexture(WHITE)
		overlay.base:SetVertexColor(STRIPE_GAP[1], STRIPE_GAP[2], STRIPE_GAP[3], 1)
		overlay.base:SetAllPoints(overlay)
		overlay.stripes = overlay:CreateTexture(nil, "OVERLAY")
		overlay.stripes:SetTexture(STRIPES, "REPEAT", "REPEAT")
		overlay.stripes:SetAllPoints(overlay)
		overlay.boost = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
		overlay.boost:SetTexture(STRIPES, "REPEAT", "REPEAT")
		overlay.boost:SetBlendMode("ADD")
		overlay.boost:SetAllPoints(overlay)
		overlay.boost:Hide()
		overlay.warnGlow = CreateWarnGlow(overlay)
		overlay.fade = 0
		overlay:SetAlpha(0)
		overlay:Hide()
		self.deadOverlay = overlay
	end

	events = CreateFrame("Frame")
	for _, e in ipairs({"PLAYER_SWING", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
		pcall(events.RegisterEvent, events, e)
	end
	events:SetScript("OnUpdate", function(...)
		local ok, err = pcall(Poll, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError("MeleePosition", err) end
	end)
	events:SetScript("OnEvent", function(...)
		local ok, err = pcall(OnEvent, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError("MeleeEvent", err) end
	end)

	self:ApplyMeleeSettings()
end
