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
YaHT.RaptorQueued = RaptorQueued

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

---------------------------------------------------------------------------
-- The distance to your target, as a band ("20-28 yd")
---------------------------------------------------------------------------
-- The game never gives the distance itself, only "is this in reach?". Every yes puts the target within
-- that reach and every no beyond it; together they close in on a band. Spells you know are asked first
-- (their reach is read from the game). Items with a fixed reach narrow it further where the game
-- answers for them; an item's answer that disagrees with the spells is left out.
local L = YaHT.L
local SCATTER_SHOT = 19503
local RANGE_ITEMS = {{10645, 20}, {835, 30}, {7734, 30}, {18904, 35}} -- (item, yards)
local reachOf = {}

local function Reach(spellID, fallbackMin, fallbackMax)
	local known = reachOf[spellID]
	if known then return known[1], known[2] end
	local lo, hi = fallbackMin, fallbackMax
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
		if ok and type(info) == "table" and not IsSecret(info) then
			local mn, mx = info.minRange, info.maxRange
			if type(mx) == "number" and not IsSecret(mx) and mx > 0 then
				hi = mx
				if type(mn) == "number" and not IsSecret(mn) then lo = mn end
				reachOf[spellID] = {lo, hi}
			end
		end
	end
	return lo, hi
end

local function ItemInRange(itemID)
	local fn = (C_Item and C_Item.IsItemInRange) or IsItemInRange
	if not fn then return nil end
	local ok, v = pcall(fn, itemID, "target")
	if not ok or IsSecret(v) or v == nil then return nil end
	return v == true or v == 1
end

-- lo, hi, zone: the target is more than lo and at most hi yards away (hi nil = beyond everything asked);
-- zone "MELEE" / "DEAD" / "OK" / "FAR" or nil. Nothing at all when there is no enemy target or the
-- game won't say.
local function ReadRange()
	if not UnitExists or not UnitCanAttack then return nil end
	local exists, hostile = UnitExists("target"), UnitCanAttack("player", "target")
	if IsSecret(exists) or IsSecret(hostile) or not exists or not hostile then return nil end
	if UnitIsDead then
		local dead = UnitIsDead("target")
		if IsSecret(dead) or dead then return nil end
	end
	local melee, auto = SpellInRange(WING_CLIP), SpellInRange(AUTO_SHOT)
	if melee == nil and auto == nil then return nil end
	local _, meleeMax = Reach(WING_CLIP, 0, 5)
	local autoMin, autoMax = Reach(AUTO_SHOT, 8, 35)
	if not autoMin or autoMin <= meleeMax then autoMin = 8 end
	local lo, hi = 0, nil
	local function within(r) if not hi or r < hi then hi = r end end
	local function beyond(r) if r > lo then lo = r end end
	local near
	if CheckInteractDistance then
		local ok, v = pcall(CheckInteractDistance, "target", FOLLOW_RANGE)
		if ok and not IsSecret(v) and v ~= nil then near = v and true or false end
	end
	local zone
	if melee then
		within(meleeMax) zone = "MELEE"
	else
		if melee == false then beyond(meleeMax) end
		if auto then
			beyond(autoMin) within(autoMax) zone = "OK"
		elseif auto == false and melee == false then
			-- neither: too close to shoot, or too far (the 28-yard check tells which)
			if near == true then within(autoMin) zone = "DEAD"
			elseif near == false then beyond(autoMax) zone = "FAR" end
		end
	end
	if zone == "OK" or zone == nil then
		if near == true then within(28) elseif near == false then beyond(28) end
		local scatter = SpellInRange(SCATTER_SHOT)
		if scatter ~= nil then
			local _, r = Reach(SCATTER_SHOT, 0, 15)
			if scatter then within(r) else beyond(r) end
		end
		if hi and lo >= hi then lo, hi = autoMin, autoMax end -- (they disagree: the certain band)
	end
	-- items: only what agrees with the above
	for i = 1, #RANGE_ITEMS do
		local r = RANGE_ITEMS[i][2]
		local v = ItemInRange(RANGE_ITEMS[i][1])
		if v == true and r > lo then within(r)
		elseif v == false and (not hi or r < hi) then beyond(r) end
	end
	return lo, hi, zone, autoMin, autoMax, meleeMax
end

local yards -- the frame that shows it
local RULER_AT = {0, 0.12, 0.24, 0.84, 1} -- where each zone starts on the ruler (melee, deadzone, shooting, too far)
local OK_GREEN = {r = 0.40, g = 0.86, b = 0.45}
local UNKNOWN_GREY = {r = 0.8, g = 0.8, b = 0.8}
local SAMPLE = {20, 28, "OK", 8, 35, 5}

local function ZoneColor(p, zone)
	if zone == "OK" then return OK_GREEN end
	if zone == "DEAD" then return p.meleedeadcolor end
	if zone == "FAR" then return p.meleefarcolor end
	if zone == "MELEE" then return p.meleecolor end
	return UNKNOWN_GREY
end

local function YardsUpdate()
	local f = yards
	if not f then return end
	local p = YaHT.db.profile
	if not p.rangeyards then f:Hide() return end
	local lo, hi, zone, autoMin, autoMax, meleeMax
	local sample = not p.lock
	if sample then
		lo, hi, zone, autoMin, autoMax, meleeMax = SAMPLE[1], SAMPLE[2], SAMPLE[3], SAMPLE[4], SAMPLE[5], SAMPLE[6]
		-- (while placing things the warning's words show "Deadzone" as their sample: the distance agrees)
		if p.meleerange and p.rangetext then lo, hi, zone = meleeMax, autoMin, "DEAD" end
	else
		local fighting = (InCombatLockdown and InCombatLockdown()) or (YaHT.mainFrame and YaHT.mainFrame.shooting)
		if p.rangeyardswhen ~= "COMBAT" or fighting then
			lo, hi, zone, autoMin, autoMax, meleeMax = ReadRange()
		end
	end
	f.lo, f.hi, f.zone = lo, hi, zone
	if not lo then f:Hide() return end
	local c = ZoneColor(p, zone)
	local style = p.rangeyardsstyle or "NUMBER"
	local boxes = style == "BOXES"
	local showNum, showRuler = (style == "NUMBER" or style == "BOTH"), style ~= "NUMBER"
	if showNum then
		local text = hi and string.format(L["%d-%d yd"], lo, hi) or string.format(L["%d+ yd"], lo)
		if f.shownText ~= text then f.shownText = text f.text:SetText(text) end
		f.text:SetTextColor(c.r, c.g, c.b)
	end
	f.text:SetShown(showNum)
	f.ruler:SetShown(showRuler)
	if f.boxLabels then for i = 1, 4 do f.boxLabels[i]:SetShown(showRuler and boxes) end end
	f.mark:SetShown(not boxes)
	f.tickMin:SetShown(not boxes)
	f.tickMax:SetShown(not boxes)
	if showRuler and boxes then
		-- Boxes: one box per range band, each with its yards, and only the one your target is in is
		-- lit (asked for by weavers who knew this from a WeakAura of the first Classic).
		local w, gap = f.rulerW, 3
		local bw = (w - gap * 3) / 4
		local cols = {p.meleecolor, p.meleedeadcolor, OK_GREEN, p.meleefarcolor}
		local lit = zone == "MELEE" and 1 or zone == "DEAD" and 2 or zone == "OK" and 3 or zone == "FAR" and 4 or 0
		local words = {string.format("0-%d", meleeMax), string.format("%d-%d", meleeMax, autoMin),
			string.format("%d-%d", autoMin, autoMax), string.format("%d+", autoMax)}
		for i = 1, 4 do
			local seg, on = f.segs[i], i == lit
			seg:ClearAllPoints()
			seg:SetPoint("LEFT", f.ruler, "LEFT", (i - 1) * (bw + gap), 0)
			seg:SetSize(bw, f.rulerH)
			local col = cols[i]
			if on then
				seg:SetVertexColor(col.r + (1 - col.r) * 0.25, col.g + (1 - col.g) * 0.25, col.b + (1 - col.b) * 0.25, 1)
			else
				seg:SetVertexColor(col.r * 0.45, col.g * 0.45, col.b * 0.45, 0.35)
			end
			local label = f.boxLabels[i]
			if label.shownText ~= words[i] then label.shownText = words[i] label:SetText(words[i]) end
			label:ClearAllPoints()
			label:SetPoint("CENTER", seg, "CENTER", 0, 0)
			if on then label:SetTextColor(1, 1, 1, 1) else label:SetTextColor(0.75, 0.75, 0.75, 0.6) end
		end
	elseif showRuler then
		-- The zones as a strip (melee, deadzone, shooting, too far) and a bright block over the band the
		-- target is in. Not to scale: the two short zones are drawn wide enough to see (RULER_AT), with
		-- the yards spread evenly inside each zone.
		local span = autoMax + 10
		local w = f.rulerW
		local edges = {0, meleeMax, autoMin, autoMax, span}
		local function X(d)
			d = math.max(0, math.min(d, span))
			for i = 1, 4 do
				if d <= edges[i + 1] or i == 4 then
					local part = (d - edges[i]) / math.max(0.001, edges[i + 1] - edges[i])
					return (RULER_AT[i] + (RULER_AT[i + 1] - RULER_AT[i]) * part) * w
				end
			end
		end
		local cols = {p.meleecolor, p.meleedeadcolor, OK_GREEN, p.meleefarcolor}
		for i = 1, 4 do
			local seg = f.segs[i]
			local x0, x1 = RULER_AT[i] * w, RULER_AT[i + 1] * w
			seg:ClearAllPoints()
			seg:SetPoint("LEFT", f.ruler, "LEFT", x0, 0)
			seg:SetSize(math.max(1, x1 - x0 - 1), f.rulerH)
			seg:SetVertexColor(cols[i].r, cols[i].g, cols[i].b, 0.7)
		end
		local m0, m1 = X(lo), X(hi or span)
		f.mark:ClearAllPoints()
		f.mark:SetPoint("LEFT", f.ruler, "LEFT", m0, 0)
		f.mark:SetSize(math.max(3, m1 - m0), f.rulerH + 6)
		-- (the band in its own color, lightened: it has to stand out from the zone under it)
		f.mark:SetVertexColor(c.r + (1 - c.r) * 0.55, c.g + (1 - c.g) * 0.55, c.b + (1 - c.b) * 0.55, 1)
		-- the two numbers that matter, under their edges: where shooting starts and where it ends
		if f.tickMin.shownN ~= autoMin then f.tickMin.shownN = autoMin f.tickMin:SetText(string.format("%d", autoMin)) end
		if f.tickMax.shownN ~= autoMax then f.tickMax.shownN = autoMax f.tickMax:SetText(string.format("%d", autoMax)) end
		f.tickMin:ClearAllPoints()
		f.tickMin:SetPoint("TOP", f.ruler, "BOTTOMLEFT", RULER_AT[3] * w, -2)
		f.tickMax:ClearAllPoints()
		f.tickMax:SetPoint("TOP", f.ruler, "BOTTOMLEFT", RULER_AT[4] * w, -2)
	end
	f.dragHint:SetShown(sample and f.free and true or false)
	f:Show()
end
YaHT.RangeYardsUpdate = YardsUpdate
YaHT.ReadRange = ReadRange

local function LayoutYards(p)
	local f = yards
	if not f then
		f = CreateFrame("Frame", "YaHTRangeYardsFrame", UIParent)
		yards = f
		YaHT.rangeYardsFrame = f
		f:SetFrameStrata("HIGH")
		f:SetClampedToScreen(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", function(self) self:StartMoving() end)
		f:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local q = YaHT.db.profile
			local _
			q.rangeyardspoint, _, q.rangeyardsrelpoint, q.rangeyardsx, q.rangeyardsy = self:GetPoint()
		end)
		local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
		f.text = f:CreateFontString(nil, "OVERLAY")
		f.text:SetFont(font, 14, "OUTLINE")
		f.ruler = CreateFrame("Frame", nil, f)
		-- a dark plate behind the strip, so it reads on any ground
		f.plate = f.ruler:CreateTexture(nil, "BACKGROUND")
		f.plate:SetTexture(WHITE)
		f.plate:SetVertexColor(0, 0, 0, 0.75)
		f.plate:SetPoint("TOPLEFT", f.ruler, "TOPLEFT", -2, 2)
		f.plate:SetPoint("BOTTOMRIGHT", f.ruler, "BOTTOMRIGHT", 2, -2)
		f.tickMin = f.ruler:CreateFontString(nil, "OVERLAY")
		f.tickMin:SetFont(font, 9, "OUTLINE")
		f.tickMin:SetTextColor(0.85, 0.85, 0.85)
		f.tickMax = f.ruler:CreateFontString(nil, "OVERLAY")
		f.tickMax:SetFont(font, 9, "OUTLINE")
		f.tickMax:SetTextColor(0.85, 0.85, 0.85)
		f.segs = {}
		for i = 1, 4 do
			f.segs[i] = f.ruler:CreateTexture(nil, "ARTWORK")
			f.segs[i]:SetTexture(WHITE)
		end
		f.mark = f.ruler:CreateTexture(nil, "OVERLAY")
		f.mark:SetTexture(WHITE)
		f.boxLabels = {}
		for i = 1, 4 do
			f.boxLabels[i] = f.ruler:CreateFontString(nil, "OVERLAY")
			f.boxLabels[i]:SetFont(font, 9, "OUTLINE")
			f.boxLabels[i]:Hide()
		end
		f.dragHint = f:CreateFontString(nil, "OVERLAY")
		f.dragHint:SetPoint("TOP", f, "BOTTOM", 0, -2)
		f.dragHint:SetFont(font, 11, "OUTLINE")
		f.dragHint:SetTextColor(0.8, 0.8, 0.8)
		f.dragHint:SetText(L["Distance (drag me)"])
		f.dragHint:Hide()
		f:Hide()
	end
	local size = p.rangeyardssize or 14
	local style = p.rangeyardsstyle or "NUMBER"
	local font = YaHT:GetMedia("font", p.font) or STANDARD_TEXT_FONT
	if not f.text:SetFont(font, size, "OUTLINE") then f.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
	local where = p.rangeyardspos or "UNDER"
	local main = YaHT.mainFrame
	f.free = where == "FREE"
	-- the ruler is as wide as the bar (its zones then line up with something you already look at)
	local barW = (p.width or 200) * (p.scale or 1)
	f.rulerW, f.rulerH = math.max(size * 9, barW), math.max(5, math.floor(size * 0.55))
	local tick = math.max(8, math.floor(size * 0.7))
	if not f.tickMin:SetFont(font, tick, "OUTLINE") then f.tickMin:SetFont(STANDARD_TEXT_FONT, tick, "OUTLINE") end
	if not f.tickMax:SetFont(font, tick, "OUTLINE") then f.tickMax:SetFont(STANDARD_TEXT_FONT, tick, "OUTLINE") end
	if style == "BOXES" then
		f.rulerH = math.max(13, size + 2) -- (tall enough for the yards inside each box)
		for i = 1, 4 do
			if not f.boxLabels[i]:SetFont(font, tick, "OUTLINE") then f.boxLabels[i]:SetFont(STANDARD_TEXT_FONT, tick, "OUTLINE") end
		end
	end
	local textH = (style == "NUMBER" or style == "BOTH") and (size + 4) or 0
	local rulerH = style == "BOXES" and (f.rulerH + 6) or style ~= "NUMBER" and (f.rulerH + 8 + tick) or 0
	f:SetSize(f.rulerW, textH + rulerH)
	-- (the ruler on top, next to the bar; the number under it)
	f.ruler:ClearAllPoints()
	f.ruler:SetPoint("TOP", f, "TOP", 0, -3)
	f.ruler:SetSize(f.rulerW, f.rulerH)
	f.text:ClearAllPoints()
	f.text:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
	f:ClearAllPoints()
	if f.free or not main then
		if p.rangeyardspoint then
			f:SetPoint(p.rangeyardspoint, UIParent, p.rangeyardsrelpoint, p.rangeyardsx, p.rangeyardsy)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
		end
	elseif where == "ABOVE" then
		f:SetPoint("BOTTOM", main, "TOP", 0, 4)
	else
		-- under the bar, below the warning line and (when they sit there too) the warning's words
		local s = p.scale or 1
		local gap = p.enableborder and 5 or 2
		local pics = math.max((p.meleedeadheight or 5) + 1, p.meleefarsize or 8)
		local words = (p.rangetext and (p.rangetextpos or "UNDER") == "UNDER") and ((p.rangetextsize or 14) + 6) or 0
		f:SetPoint("TOP", main, "BOTTOM", 0, -((gap + pics + 5) * s + words))
	end
	f:EnableMouse((f.free and not p.lock and p.rangeyards) and true or false)
	YardsUpdate()
end

-- How visible the line should be right now (0..1).
local function TargetAlpha(self, p, now)
	if not p.melee and not p.meleerange then return 0 end
	if not p.lock then return p.melee and 1 or 0 end -- unlocked: preview the swing line
	if p.meleerange and p.rangepics ~= false then
		if self.position == "FAR" and p.rangefarpics ~= false then return 1 end
		if self.position == "DEAD" and p.rangedeadpics ~= false and not DeadOnBar(p) then return 1 end
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

-- Is a range warning (deadzone stripes, too-far arrows) due on the line right now?
local function WarnLive(self, p)
	local pos = self.position
	return (p.lock and p.meleerange and p.rangepics ~= false
		and ((pos == "DEAD" and p.rangedeadpics ~= false and not DeadOnBar(p)) or (pos == "FAR" and p.rangefarpics ~= false))) and true or false
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
		if self.fadingWarn and not WarnLive(self, p) then
			-- a range warning that no longer applies is gone at once: you moved to get rid of it,
			-- and a warning still fading says you haven't. (The swing line keeps its gentle fade.)
			a = want
		else
			a = math.max(want, a - elapsed / FADE_OUT)
		end
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
	local live = WarnLive(self, p)
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

local LayoutRangeText -- (the warning text, further down)
local LayoutWeave -- (the weave cues: made further down)
function YaHT:ApplyMeleeSettings()
	if not frame then return end
	local p = self.db.profile
	local f = self.mainFrame
	LayoutRangeText(p)
	LayoutYards(p)
	LayoutWeave(p)
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
---------------------------------------------------------------------------
-- Weave cues: "Walk in" and "Walk out", for hunters who weave melee between their shots.
-- The rhythm: you walk in when your bow has just fired (and no shot of yours is about to come off
-- cooldown), and you walk out when your melee weapon has swung. YaHT knows all three: the shot, the
-- swing and where you stand. Small words, off unless you switch them on, dragged where you like.
---------------------------------------------------------------------------
local weave
local WEAVE_IN_TIME = 1.8    -- how long "Walk in" stays if you do not act on it
local WEAVE_OUT_MAX = 8.0    -- "Walk out" stays until you are out of the deadzone; this is only a last resort
local WEAVE_SOON = 1.5                          -- a shot this close to ready comes first
local WEAVE_SHOTS = {19434, 3044}               -- Aimed Shot, Arcane Shot (looked up by name: every rank)
local WEAVE_IN_COLOR, WEAVE_OUT_COLOR = {0.40, 0.90, 0.45}, {1.00, 0.72, 0.25}

-- is one of your shots ready, or about to be? (then that comes before walking in)
local function ShotComingUp()
	if not (C_Spell and C_Spell.GetSpellCooldown) then return false end
	for _, id in ipairs(WEAVE_SHOTS) do
		local name = YaHT.GetSpellName and YaHT.GetSpellName(id)
		if name then
			local ok, info = pcall(C_Spell.GetSpellCooldown, name)
			if ok and type(info) == "table" then
				local s, d = info.startTime, info.duration
				if not IsSecret(s) and not IsSecret(d) and type(s) == "number" and type(d) == "number" then
					local left = d > 0 and math.max(0, s + d - GetTime()) or 0
					if left > 0 and left <= WEAVE_SOON then return true end
					if left == 0 and C_Spell.IsSpellUsable then
						-- (ready counts only for a shot you really have: one you could cast now)
						local ok2, usable = pcall(C_Spell.IsSpellUsable, name)
						if ok2 and not IsSecret(usable) and usable then return true end
					end
				end
			end
		end
	end
	return false
end

-- The cue as a picture: three arrows, one above the other, a light running through them the way
-- you should go: up (forward, at the enemy) for Walk in, down (back) for Walk out. Green in, amber
-- out. With the word beside them, or without it, or the word alone.
local WEAVE_ARROW = "Interface\\AddOns\\YaHT\\media\\WeaveArrow" -- (a bold chevron pointing up, YaHT's own)
local WEAVE_HALO = "Interface\\AddOns\\YaHT\\media\\Halo"         -- (the soft round glow behind them)
local function WeavePaint(f, which)
	local c = which == "IN" and WEAVE_IN_COLOR or WEAVE_OUT_COLOR
	f.text:SetText(which == "IN" and L["Walk in"] or L["Walk out"])
	f.text:SetTextColor(c[1], c[2], c[3])
	for _, a in ipairs(f.arrows) do
		a:SetVertexColor(c[1], c[2], c[3])
		if which == "IN" then a:SetTexCoord(0, 1, 0, 1) else a:SetTexCoord(0, 1, 1, 0) end
	end
	f.glow:SetVertexColor(c[1], c[2], c[3])
	f.painted = which
	f.pointing = which == "IN" and "UP" or "DOWN"
	f.popAt = GetTime() -- (it pops in: a moment larger and brighter, so a new cue is never missed)
end
-- the light running through the arrows (every frame while a cue shows: three alphas, nothing more)
local function WeaveMarch(f)
	if not f.arrows[1]:IsShown() then return end
	local now = GetTime()
	-- the pop: larger for a blink, easing back
	local pop = f.popAt and math.max(0, 1 - (now - f.popAt) / 0.22) or 0
	local k = 1 + 0.35 * pop * pop
	-- a wave of light running through the three: upward for in, downward for out
	local phase = (now * 1.6) % 1
	for i = 1, 3 do
		local place = (f.cue == "IN") and (3 - i) or (i - 1)       -- 0, 1, 2 along the way to go
		local d = math.abs(((phase * 3 - place + 1.5) % 3) - 1.5)   -- how far the light is from this arrow
		f.arrows[i]:SetAlpha(0.28 + 0.72 * math.max(0, 1 - d / 1.1))
		f.arrows[i]:SetSize(f.aw * k, f.ah * k)
	end
	f.glow:SetAlpha(0.30 + 0.12 * math.sin(now * 5) + 0.5 * pop)
end

local function WeaveShow(which)
	local f = weave
	if not f then return end
	local p = YaHT.db.profile
	f.cue = which
	if not which then f:Hide() return end
	WeavePaint(f, which)
	f.untilT = GetTime() + (which == "IN" and WEAVE_IN_TIME or WEAVE_OUT_MAX)
	f.sum = 0
	f:Show()
	if p.lock then
		-- each cue has its own sound, a choice like every sound here
		if which == "IN" and p.weaveinsound then YaHT:PlayChoice(p.weaveinsoundkit, "BLADE")
		elseif which == "OUT" and p.weaveoutsound then YaHT:PlayChoice(p.weaveoutsoundkit, "BOWPULL") end
	end
end

local function WeaveFighting()
	return (InCombatLockdown and InCombatLockdown()) or (YaHT.mainFrame and YaHT.mainFrame.shooting) or false
end

-- your bow just fired
-- THE GAME'S OWN SWAP. Forever has a Combat setting (its name inside the game: autoRangedCombat) that
-- switches between Auto Attack and Auto Shot for you. For weaving it gets in the way: stepping into
-- melee with it on can hold back your next swing. So the Melee weaving page says when it is on and
-- offers to switch it off, and the first cue of a session says so once in chat.
local SWAP_CVAR = "autoRangedCombat"
-- true: the game is swapping; false: it is not; nil: this game does not say
function YaHT:AutoSwapOn()
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if not get then return nil end
	local ok, v = pcall(get, SWAP_CVAR)
	if not ok or v == nil then return nil end
	if IsSecret(v) then return nil end
	return v == "1" or v == 1 or v == true
end
-- switch the game's swap on or off; says whether it took
function YaHT:AutoSwapSet(want)
	want = want and true or false
	local set = (C_CVar and C_CVar.SetCVar) or SetCVar
	if set then pcall(set, SWAP_CVAR, want and "1" or "0") end
	local on = self:AutoSwapOn()
	if on ~= want then
		self:Print(L["That setting could not be changed from here (in a fight, perhaps). It is in the game's Options, under Combat."])
	end
	return on == want
end

function YaHT:WeaveShot()
	local p = self.db.profile
	if not weave or not p.weave or not p.lock or not WeaveFighting() then return end
	if not self.saidSwap and self:AutoSwapOn() then
		self.saidSwap = true
		self:Print(L["The game is swapping Auto Attack and Auto Shot for you, which slows weaving. /yaht, Melee weaving has a switch for it."])
	end
	local pos = ReadPosition()
	if pos ~= "OK" and pos ~= "DEAD" then return end       -- (in melee already, too far, or nothing to hit)
	if p.weavesmart and ShotComingUp() then return end
	WeaveShow("IN")
end

-- your melee weapon just swung
function YaHT:WeaveSwing()
	local p = self.db.profile
	if not weave or not p.weave or not p.lock or not WeaveFighting() then return end
	local pos = ReadPosition()
	if pos ~= nil and pos ~= "MELEE" then return end        -- (already out)
	WeaveShow("OUT")
end

local function WeaveUpdate(self, elapsed)
	local p = YaHT.db.profile
	WeaveMarch(self)
	if not p.lock then return end -- (placing it: the sample stays)
	self.sum = (self.sum or 0) + elapsed
	if self.sum < 0.1 then return end
	self.sum = 0
	local pos = ReadPosition()
	-- "Walk out" is not done when you leave melee: between melee and shooting range lies the deadzone,
	-- where you can do neither. It stays until you can shoot again (or there is nothing left to
	-- shoot at).
	local done = GetTime() >= (self.untilT or 0)
		or (self.cue == "IN" and pos == "MELEE")                                   -- you are in
		or (self.cue == "OUT" and pos ~= "MELEE" and pos ~= "DEAD")                -- you are out, past the deadzone
	if done then WeaveShow(nil) end
end

LayoutWeave = function(p)
	local f = weave
	if not f then
		f = CreateFrame("Frame", "YaHTWeaveFrame", UIParent)
		weave = f
		YaHT.weaveFrame = f
		f:SetFrameStrata("HIGH")
		f:SetClampedToScreen(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", function(self) self:StartMoving() end)
		f:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local q = YaHT.db.profile
			local _
			q.weavepoint, _, q.weaverelpoint, q.weavex, q.weavey = self:GetPoint()
		end)
		f:SetScript("OnUpdate", function(self, elapsed)
			local ok, err = pcall(WeaveUpdate, self, elapsed)
			if not ok and YaHT.ReportError then YaHT.ReportError("weave cues", err) end
		end)
		local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
		f.text = f:CreateFontString(nil, "OVERLAY")
		f.text:SetFont(font, 18, "OUTLINE")
		f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
		f.hint = f:CreateFontString(nil, "OVERLAY")
		f.hint:SetFont(font, 11, "OUTLINE")
		f.hint:SetPoint("TOP", f, "BOTTOM", 0, -2)
		f.hint:SetTextColor(0.8, 0.8, 0.8)
		f.hint:SetText(L["Weave cues (drag me)"])
		f.glow = f:CreateTexture(nil, "BACKGROUND")
		f.glow:SetTexture(WEAVE_HALO)
		f.glow:SetBlendMode("ADD")
		f.arrows = {}
		for i = 1, 3 do
			f.arrows[i] = f:CreateTexture(nil, "ARTWORK")
			f.arrows[i]:SetTexture(WEAVE_ARROW)
		end
		f:Hide()
	end
	local size = p.weavesize or 18
	local font = YaHT:GetMedia("font", p.font) or STANDARD_TEXT_FONT
	if not f.text:SetFont(font, size, "OUTLINE") then f.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
	-- what shows: the arrows, the word, or both (the arrows on the left, the word beside them)
	local look = p.weavelook or "BOTH"
	local arrows, words = look ~= "WORDS", look ~= "ARROWS"
	-- three chevrons, each twice as wide as tall, set close so they read as one arrow in motion
	local aw, ah = math.floor(size * 1.7), math.floor(size * 0.85)
	local stepY = math.floor(ah * 0.62)
	f.aw, f.ah = aw, ah
	local colH = arrows and (stepY * 2 + ah) or 0
	local textW = words and size * 5 or 0
	local w = (arrows and aw or 0) + ((arrows and words) and 6 or 0) + textW
	local h = math.max(colH, words and (size + 6) or 0)
	f:SetSize(math.max(w, 10), math.max(h, 10))
	for i = 1, 3 do
		local a = f.arrows[i]
		a:SetShown(arrows)
		a:SetSize(aw, ah)
		a:ClearAllPoints()
		a:SetPoint("CENTER", f, "TOPLEFT", aw / 2, -((h - colH) / 2 + ah / 2 + (i - 1) * stepY))
	end
	f.glow:SetShown(arrows)
	f.glow:ClearAllPoints()
	f.glow:SetPoint("CENTER", f, "TOPLEFT", aw / 2, -h / 2)
	f.glow:SetSize(aw * 2.4, math.max(colH, ah) * 2.0)
	f.text:SetShown(words)
	f.text:ClearAllPoints()
	if arrows then f.text:SetPoint("LEFT", f, "LEFT", aw + 6, 0) else f.text:SetPoint("CENTER", f, "CENTER", 0, 0) end
	-- where: linked to the bar (above, below, left or right of it), or anywhere you drag it
	local where = p.weavepos or "ABOVE"
	local main = YaHT.mainFrame
	local s = p.scale or 1
	f.free = where == "FREE" or not main
	f:ClearAllPoints()
	if f.free then
		if p.weavepoint then
			f:SetPoint(p.weavepoint, UIParent, p.weaverelpoint, p.weavex, p.weavey)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
		end
	elseif where == "BELOW" then
		f:SetPoint("TOP", main, "BOTTOM", 0, -30 * s)   -- (under the warning line and its words)
	elseif where == "LEFT" then
		f:SetPoint("RIGHT", main, "LEFT", -44 * s, 0)   -- (past an icon standing on that side)
	elseif where == "RIGHT" then
		f:SetPoint("LEFT", main, "RIGHT", 44 * s, 0)
	else
		f:SetPoint("BOTTOM", main, "TOP", 0, 58 * s)    -- (above the row of icons, clear of a large one)
	end
	local placing = p.weave and not p.lock
	f:EnableMouse((placing and f.free) and true or false)
	f.hint:SetShown((placing and f.free) and true or false)
	if placing then
		-- a sample (to drag, when it is placed by hand)
		f.cue = "IN"
		WeavePaint(f, "IN")
		f:Show()
	elseif not p.weave or not (f.untilT and GetTime() < f.untilT) then
		f.cue = nil
		f:Hide()
	end
end

function YaHT:OnMeleeSwing(duration)
	if not frame then return end
	local now = GetTime()
	frame.swingStart = now
	frame.swingDur = duration or MainHandSpeed() or frame.swingDur or 3
	frame.lastSwing = now
	frame.glintAt = now
	if self.db.profile.melee then frame:Show() end
	if self.WeaveSwing then self:WeaveSwing() end
	if self.MeleeSwung then self:MeleeSwung() end -- (on Forever a melee swing restarts the shot's reload)
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

---------------------------------------------------------------------------
-- The warnings as words: "DEADZONE" / "TOO FAR", small text you can drag anywhere
---------------------------------------------------------------------------
local rangeText
local L = YaHT.L

local function RangeTextUpdate()
	local f = rangeText
	if not f then return end
	local p = YaHT.db.profile
	local which
	if p.meleerange and p.rangetext then
		local pos = frame and frame.position
		if not p.lock then
			which = "DEAD" -- unlocked: a sample to drag
		elseif pos == "DEAD" and p.rangetextdead then
			which = "DEAD"
		elseif pos == "FAR" and p.rangetextfar then
			which = "FAR"
		end
	end
	f.which = which
	if not which then f:Hide() return end
	local msg = which == "DEAD" and p.rangetextdeadmsg or p.rangetextfarmsg
	if type(msg) ~= "string" or msg:gsub("%s", "") == "" then msg = which == "DEAD" and L["DEADZONE"] or L["TOO FAR"] end
	local c = (which == "DEAD" and p.rangetextdeadcolor or p.rangetextfarcolor) or {r = 1, g = 1, b = 1}
	f.text:SetText(msg)
	f.text:SetTextColor(c.r, c.g, c.b)
	f.dragHint:SetShown(not p.lock and f.free and true or false)
	f:Show()
end
YaHT.RangeTextUpdate = RangeTextUpdate

LayoutRangeText = function(p)
	local f = rangeText
	if not f then
		f = CreateFrame("Frame", "YaHTRangeTextFrame", UIParent)
		rangeText = f
		YaHT.rangeTextFrame = f
		f:SetFrameStrata("HIGH")
		f:SetClampedToScreen(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", function(self) self:StartMoving() end)
		f:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local q = YaHT.db.profile
			local _
			q.rangetextpoint, _, q.rangetextrelpoint, q.rangetextx, q.rangetexty = self:GetPoint()
		end)
		local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
		f.text = f:CreateFontString(nil, "OVERLAY")
		f.text:SetFont(font, 14, "OUTLINE")
		f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
		f.dragHint = f:CreateFontString(nil, "OVERLAY")
		f.dragHint:SetPoint("TOP", f, "BOTTOM", 0, -2)
		f.dragHint:SetFont(font, 11, "OUTLINE")
		f.dragHint:SetTextColor(0.8, 0.8, 0.8)
		f.dragHint:SetText(L["Range text (drag me)"])
		f.dragHint:Hide()
		f:Hide()
	end
	local size = p.rangetextsize or 14
	local where = p.rangetextpos or "UNDER"
	local main = YaHT.mainFrame
	f:ClearAllPoints()
	if where == "FREE" or not main then
		if p.rangetextpoint then
			f:SetPoint(p.rangetextpoint, UIParent, p.rangetextrelpoint, p.rangetextx, p.rangetexty)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", 0, 130)
		end
	elseif where == "ABOVE" then
		f:SetPoint("BOTTOM", main, "TOP", 0, 4)
	else
		-- under the bar, clear of the warning line with its stripes or arrows (as the live preview shows it)
		local s = p.scale or 1
		local gap = p.enableborder and 5 or 2
		local pics = math.max((p.meleedeadheight or 5) + 1, p.meleefarsize or 8)
		f:SetPoint("TOP", main, "BOTTOM", 0, -(gap + pics + 5) * s)
	end
	local font = YaHT:GetMedia("font", p.font) or STANDARD_TEXT_FONT
	if not f.text:SetFont(font, size, "OUTLINE") then f.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
	f:SetSize(size * 14, size + 4)
	f.free = where == "FREE"
	f:EnableMouse((f.free and not p.lock and p.meleerange and p.rangetext) and true or false)
	RangeTextUpdate()
end
local pollSum = 0

-- Deadzone shown on the Auto Shot bar: caution-tape stripes over the whole bar.
local function UpdateOverlay(p, elapsed)
	local dead = p.lock and p.meleerange and p.rangepics ~= false and p.rangedeadpics ~= false and frame.position == "DEAD"
	local onBar = dead and DeadOnBar(p)
	-- the bar went away while you're in the deadzone: the line takes over
	if dead and not onBar and not frame:IsShown() then frame:Show() end
	local want = onBar and 1 or 0
	local a = overlay.fade or 0
	if a == 0 and want == 0 then
		if overlay:IsShown() then overlay:Hide() end
		return
	end
	-- in: a quick fade. Out: at once (out of the deadzone means out of the warning)
	if want > a then a = math.min(1, a + elapsed / 0.15) elseif want < a then a = 0 end
	overlay.fade = a
	if a == 0 then
		overlay:Hide()
		return
	end
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
	if p.rangeyards then YardsUpdate() end
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
			position = frame.previewWhich or (left > frame.previewHalf and "DEAD" or "FAR")
		end
	end
	-- each warning has a switch of its own: one that is off counts as nothing to say
	if (position == "DEAD" and p.rangedead == false) or (position == "FAR" and p.rangefar == false) then position = "OK" end
	if position ~= frame.position then
		frame.position = position
		if YaHT.debug then YaHT:Print("position: "..(POSITION_NAMES[position] or "unknown")) end
		if position and position ~= "OK" then frame:Show() end
		RangeTextUpdate()
	end
end

-- "Preview all alerts": show the deadzone, then the too-far warning
function YaHT:PreviewRange(seconds, which)
	if not frame then return end
	frame.previewWhich = which -- ("DEAD" or "FAR": that one alone, for its Test button)
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
