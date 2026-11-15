-- YaHT hawk circles: your Summon Hawk hawks as small round icons at the top left of the bar.
-- (Or as squares, a setting: then they are drawn by the proc icon code in procs.lua and look and
-- behave like Rapid Fire's icon and the others, with the same settings.)
--
-- Summon Hawk (Beast Mastery, new in Forever): a hawk attacks your target for 18 seconds, up to
-- two can be out, and a third cast replaces the older one. Each circle is the spell's icon with
-- a ring that runs down over that hawk's time; under 6 seconds (a setting) it turns red, the
-- point below which guides say not to spend the shared cooldown on Arcane Shot.
--
-- How YaHT knows: your own cast is always visible to addons, so every hawk gets an 18 second
-- timer from the cast. If the game also lists the hawks in its summon slots (the ones totems
-- use), their real start and length are taken from there, and a hawk that dies early is noticed.
-- Whether Forever does that in a fight is written to the record on the first casts.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end
local function Plain(v) if IsSecret(v) then return nil end return v end
local function S(v) if IsSecret(v) then return "HIDDEN" end return tostring(v) end

local HAWK_IDS = {[1293241] = true, [1293527] = true} -- rank 1 and rank 4; the others are matched by name
local HAWK_TIME = 18     -- seconds a hawk stays
local MAX_HAWKS = 2
local POLL = 0.1         -- how often the numbers are redrawn while a hawk is out
local SLOT_GRACE = 1     -- a new hawk may take this long to show in the game's summon slots
local GAP = 4            -- between the circles, and between them and the bar
local MEDIA = "Interface\\AddOns\\YaHT\\media\\"
local FALLBACK_ICON = "Interface\\Icons\\Spell_Nature_RavenForm"
local GOLD = {1.0, 0.80, 0.30}
local RED = {1.0, 0.33, 0.28}
local TRACK = {0.34, 0.27, 0.13}
local GLOW_ALPHA = 0.34  -- the soft glow around a circle
-- the plain look ("Polished look" switched off): a flat ring and nothing else
local PLAIN_GOLD = {0.91, 0.70, 0.24}
local PLAIN_RED = {0.93, 0.30, 0.27}
local PLAIN_TRACK = {0.32, 0.26, 0.12}
local SAMPLE_LEFT = {14, 5} -- what the two circles show while you place them
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROW_GAP = 6        -- the square shape: between the squares and from the bar, as for every proc icon
local SQUARE_GOLD = {0.85, 0.70, 0.42} -- a proc icon's rim
-- a square's rim, timer line and glow once its hawk is under the warning time
local SQUARE_WARN = {1.0, 0.33, 0.28, r = 1.0, g = 0.33, b = 0.28}

local holder, watch
local icons = {}          -- the square shape: two proc icons (procs.lua), one per hawk
local slots = {}          -- [1], [2]: a hawk that is out ({start, dur}) or nil. A hawk keeps its circle.
local slotsWork = false   -- the game has listed a hawk in its summon slots this session
local hawkName, hawkIcon
local recorded = 0

---------------------------------------------------------------------------
-- What the game tells us
---------------------------------------------------------------------------
local function Try(obj, method, ...)
	local fn = obj and obj[method]
	if type(fn) ~= "function" then return false end
	return pcall(fn, obj, ...)
end

local function SpellName(id)
	local ok, name = pcall(YaHT.GetSpellName, id)
	if ok then return Plain(name) end
end

local function SpellIcon(id)
	local icon
	if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
		local ok, v = pcall(C_Spell.GetSpellTexture, id)
		if ok then icon = Plain(v) end
	end
	if not icon and type(GetSpellTexture) == "function" then
		local ok, v = pcall(GetSpellTexture, id)
		if ok then icon = Plain(v) end
	end
	return icon
end

local function LearnSpell()
	hawkName = hawkName or SpellName(1293241) or SpellName(1293527)
	hawkIcon = hawkIcon or SpellIcon(1293241) or SpellIcon(1293527)
end

local function IsHawkSpell(spellID)
	spellID = Plain(spellID)
	if not spellID then return false end
	if HAWK_IDS[spellID] then return true end
	local name = SpellName(spellID)
	if type(name) ~= "string" then return false end
	LearnSpell()
	return name == hawkName or name == "Summon Hawk"
end

-- Is this entry in the game's summon slots one of your hawks?
local function LooksLikeHawk(name, icon)
	if icon ~= nil and hawkIcon ~= nil and icon == hawkIcon then return true end
	if type(name) ~= "string" then return false end
	if hawkName and name == hawkName then return true end
	return name:lower():find("hawk", 1, true) ~= nil
end

-- The hawks the game lists in its summon slots, in slot order, and whether the slots could be read at all
local function ReadSlots()
	if type(GetTotemInfo) ~= "function" then return nil, false end
	local found, readable = {}, false
	for slot = 1, (Plain(MAX_TOTEMS) or 4) do
		local ok, have, name, start, dur, icon = pcall(GetTotemInfo, slot)
		if ok then
			have, name, start, dur, icon = Plain(have), Plain(name), Plain(start), Plain(dur), Plain(icon)
			if have ~= nil then readable = true end
			if have and type(start) == "number" and type(dur) == "number" and start > 0 and dur > 0 and LooksLikeHawk(name, icon) then
				found[#found + 1] = {start = start, dur = dur}
			end
		end
	end
	return found, readable
end

local function SlotsForRecord()
	if type(GetTotemInfo) ~= "function" then return "no summon slots in this game" end
	local parts = {}
	for slot = 1, (Plain(MAX_TOTEMS) or 4) do
		local ok, have, name, start, dur = pcall(GetTotemInfo, slot)
		parts[#parts + 1] = ok and string.format("%d: %s %s start %s for %s", slot, S(have), S(name), S(start), S(dur)) or (slot .. ": refused")
	end
	return table.concat(parts, " | ")
end

local function Count()
	return (slots[1] and 1 or 0) + (slots[2] and 1 or 0)
end

local function IsSquare(p)
	return p.hawkshape == "SQUARE" and icons[1] ~= nil
end

---------------------------------------------------------------------------
-- Keeping track
---------------------------------------------------------------------------
local function Wake()
	watch.sum = POLL -- look at once
	watch:Show()
end

-- You cast Summon Hawk: the new hawk takes a free circle, or the older hawk's when both are out
local function Cast(spellID)
	local now = GetTime()
	local at = (not slots[1] and 1) or (not slots[2] and 2) or ((slots[1].start <= slots[2].start) and 1 or 2)
	slots[at] = {start = now, dur = HAWK_TIME}
	local icon = SpellIcon(Plain(spellID))
	if icon then hawkIcon = icon end
	watch.lookAt = now + 0.5 -- what the game's summon slots say about it
	local p = YaHT.db.profile
	if p.hawk and IsSquare(p) then icons[1]:Chime() end -- (a sound per cast, when the squares' look has one)
	if YaHT.debug then YaHT:Print(string.format("Hawk %d out (%d of %d)", at, Count(), MAX_HAWKS)) end
	Wake()
end

-- The game's own word on the hawks, when it gives one
local function Sync(now)
	local found, readable = ReadSlots()
	if found and #found > 0 then
		slotsWork = true
		slots[1], slots[2] = found[1], found[2]
	elseif readable and slotsWork then
		-- the game lists hawks and lists none now: one that has been out a moment has died or left
		for i = 1, MAX_HAWKS do
			if slots[i] and now - slots[i].start > SLOT_GRACE then slots[i] = nil end
		end
	end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function Paint(c, warn, polished)
	local color = polished and (warn and RED or GOLD) or (warn and PLAIN_RED or PLAIN_GOLD)
	if c.color == color then return end
	c.color = color
	Try(c.cd, "SetSwipeColor", color[1], color[2], color[3], 1)
	c.full:SetVertexColor(color[1], color[2], color[3])
	-- the soft glow takes the ring's colour, and breathes once the ring is red
	c.halo:SetVertexColor(color[1], color[2], color[3])
	if warn and polished then
		Try(c.pulse, "Play")
	else
		Try(c.pulse, "Stop")
		c.halo:SetAlpha(GLOW_ALPHA)
	end
	c.num:SetTextColor(warn and 1 or 0.95, warn and 0.55 or 0.89, warn and 0.5 or 0.71)
end

-- A hawk in this circle. start = nil: a sample that stands still.
local function Fill(c, left, start, dur, p)
	c:Show()
	c.icon:SetAlpha(1)
	Try(c.icon, "SetDesaturated", false)
	c.track:Show()
	c.halo:SetShown(p.hawkpolish and true or false)
	c.gloss:SetAlpha(1)
	if start then
		c.full:Hide()
		if c.cdStart ~= start or c.cdDur ~= dur then
			c.cdStart, c.cdDur = start, dur
			Try(c.cd, "SetCooldown", start, dur)
		end
		c.cd:Show()
	else
		c.cd:Hide()
		c.cdStart, c.cdDur = nil, nil
		c.full:Show()
	end
	Paint(c, p.hawkwarn > 0 and left < p.hawkwarn, p.hawkpolish)
	local text = p.hawknumbers and tostring(math.max(0, math.ceil(left))) or ""
	if c.shownText ~= text then c.shownText = text c.num:SetText(text) end
end

-- An empty circle next to a hawk: there is room for another
local function Dim(c)
	c:Show()
	c.icon:SetAlpha(0.3)
	Try(c.icon, "SetDesaturated", true)
	Try(c.pulse, "Stop")
	c.halo:Hide()
	c.gloss:SetAlpha(0.2)
	c.color = nil
	c.cd:Hide()
	c.cdStart, c.cdDur = nil, nil
	c.full:Hide()
	c.track:Show()
	if c.shownText ~= "" then c.shownText = "" c.num:SetText("") end
end

-- The square shape. Each hawk that is out runs one proc icon: its rim, its timer line, its glow
-- and pulse are the icon code's; the seconds, the red warning and the count are ours.
local function DrawSquares(p, show, sample, out, visible, Left)
	local want = {} -- the hawk each square shows
	if visible then
		if p.hawkmode == "COUNT" then
			local first = show[1]
			if show[2] and (not first or Left(show[2]) < Left(first)) then first = show[2] end
			want[1] = first
			local n = tostring(out)
			if holder.countShown ~= n then holder.countShown = n holder.count:SetText(n) end
		elseif p.hawkempty then
			want[1], want[2] = show[1], show[2]
		else
			for i = 1, MAX_HAWKS do
				if show[i] then want[#want + 1] = show[i] end
			end
		end
	end
	for i, icon in ipairs(icons) do
		local f, h = icon.frame, want[i]
		if h and h.start then
			if not f.proc or f.hawkStart ~= h.start or f.hawkDur ~= h.dur then
				f.hawkStart, f.hawkDur = h.start, h.dur
				icon:Start(false, h.start, h.dur, hawkIcon, true)
			end
		elseif f.proc then
			-- (a sample without a start is the looping one the icon shows by itself while you place it)
			f.hawkStart, f.hawkDur = nil, nil
			icon:End()
		end
		holder.ghosts[i]:SetShown(visible and not sample and not h and p.hawkmode ~= "COUNT" and p.hawkempty and true or false)
		local text, warn = "", false
		if h and p.hawknumbers then
			local left = (not p.lock and f.secondsLeft) or Left(h)
			warn = p.hawkwarn > 0 and left < p.hawkwarn
			text = tostring(math.max(0, math.ceil(left)))
		end
		if f.numText ~= text then f.numText = text f.num:SetText(text) end
		if f.numWarn ~= warn then
			f.numWarn = warn
			f.num:SetTextColor(warn and 1 or 0.95, warn and 0.55 or 0.89, warn and 0.5 or 0.71)
		end
	end
end

local function Draw()
	local p = YaHT.db.profile
	local now = GetTime()
	for i = 1, MAX_HAWKS do
		if slots[i] and now >= slots[i].start + slots[i].dur then slots[i] = nil end
	end
	if holder.previewUntil and now >= holder.previewUntil then holder.previewUntil, holder.previewAt = nil, nil end
	local out = Count()
	-- nothing out, but you are placing things (unlocked) or asked for a preview: two samples
	local show, sample = {slots[1], slots[2]}, false
	if out == 0 and p.hawk and (holder.previewUntil or not p.lock) then
		sample = true
		if holder.previewAt then
			show = {{start = holder.previewAt - (HAWK_TIME - SAMPLE_LEFT[1]), dur = HAWK_TIME}, {start = holder.previewAt - (HAWK_TIME - SAMPLE_LEFT[2]), dur = HAWK_TIME}}
		else
			show = {{left = SAMPLE_LEFT[1]}, {left = SAMPLE_LEFT[2]}}
		end
		out = 2
	end
	local visible = p.hawk and out > 0
	holder.sample = sample
	holder.dragHint:SetShown(p.hawk and not p.lock and p.hawkpos == "FREE")
	holder:SetShown(visible and true or false)
	holder.badge:SetShown(visible and p.hawkmode == "COUNT" or false)
	local function Left(h) return h.left or (h.start + h.dur - now) end
	if IsSquare(p) then return DrawSquares(p, show, sample, out, visible, Left) end
	if not visible then return end

	local c1, c2 = holder.circles[1], holder.circles[2]
	if p.hawkmode == "COUNT" then
		-- one circle: the hawk that ends first, and how many are out
		local first = show[1]
		if show[2] and (not first or Left(show[2]) < Left(first)) then first = show[2] end
		Fill(c1, Left(first), first.start, first.dur, p)
		c2:Hide()
		local n = tostring(out)
		if holder.countShown ~= n then holder.countShown = n holder.count:SetText(n) end
	elseif p.hawkempty then
		-- a hawk keeps its circle; a free one shows greyed out
		for i, c in ipairs({c1, c2}) do
			if show[i] then Fill(c, Left(show[i]), show[i].start, show[i].dur, p) else Dim(c) end
		end
	else
		-- only the hawks that are out, from the left
		local n = 0
		for i = 1, MAX_HAWKS do
			if show[i] then
				n = n + 1
				Fill(holder.circles[n], Left(show[i]), show[i].start, show[i].dur, p)
			end
		end
		for i = n + 1, MAX_HAWKS do holder.circles[i]:Hide() end
	end
end

local function Awake()
	if Count() > 0 or holder.previewUntil ~= nil then return true end
	-- placing the squares: their sample timers run, and the numbers follow them
	local p = YaHT.db.profile
	return p.hawk and not p.lock and p.hawknumbers and IsSquare(p) or false
end

local function Step(self, elapsed)
	self.sum = self.sum + elapsed
	if self.sum < POLL then return end
	self.sum = 0
	local now = GetTime()
	if self.lookAt and now >= self.lookAt then
		self.lookAt = nil
		Sync(now)
		if recorded < 6 and YaHT.Record then
			recorded = recorded + 1
			YaHT:Record("hawk", "cast seen, " .. Count() .. " out | summon slots: " .. SlotsForRecord())
		end
	end
	Draw()
	if not Awake() and not self.lookAt then self:Hide() end -- nothing to time: sleep until the next cast
end

local function OnEvent(self, event, unit, _, spellID)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if Plain(unit) ~= "player" or not IsHawkSpell(spellID) then return end
		Cast(spellID)
	elseif event == "PLAYER_TOTEM_UPDATE" then
		if Count() == 0 and not slotsWork then return end
		Sync(GetTime())
		Wake()
	elseif event == "PLAYER_DEAD" then
		slots[1], slots[2] = nil, nil
		Wake()
	else -- entering the world: whatever was out before a loading screen
		Sync(GetTime())
		Wake()
	end
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local function SetFont(fs, font, size)
	if not fs:SetFont(font, size, "OUTLINE") then fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
end

function YaHT:ApplyHawkSettings()
	if not holder then return end
	local p = self.db.profile
	LearnSpell()
	-- a circle is as wide and high as its size; a square is built like every proc icon: the icon,
	-- a rim around it and the timer line under it
	local square = IsSquare(p)
	local size = square and icons[1]:Setting(p, "size") or p.hawksize
	local wide, tall, between = size, size, GAP
	if square then wide, tall, between = size + 2, size + 6, ROW_GAP end
	local font = self:GetMedia("font", p.font) or STANDARD_TEXT_FONT
	-- the seconds: under the circle (a row between it and the bar), in the middle over the icon, or above
	local numPos = p.hawknumbers and p.hawknumpos or nil
	local numSize = math.max(9, math.floor(size * (numPos == "MIDDLE" and 0.50 or 0.42) + 0.5))
	local numRow = (numPos == "BOTTOM" or numPos == "TOP") and (numSize + 2) or 0
	local topPad = (numPos == "TOP") and numRow or 0
	local n = (p.hawkmode == "COUNT") and 1 or MAX_HAWKS
	holder:SetSize(wide * n + between * (n - 1), tall + numRow)
	holder:SetScale(p.scale or 1) -- (with the bar, like every icon around it)
	holder:SetAlpha(square and 1 or p.hawkalpha) -- (a square has its opacity from its look, like every proc icon)
	holder:ClearAllPoints()
	local bar = self.mainFrame
	local pos = p.hawkpos
	-- above, left or right of the bar the hawks stand in the row of the other icons, after the last of them
	local inRow = pos == "ABOVE" or pos == "LEFT" or pos == "RIGHT"
	local shift = (inRow and self.ProcSlotShift) and self.ProcSlotShift(p, "hawk") or 0
	if pos == "FREE" and p.hawkpoint then
		holder:SetPoint(p.hawkpoint, UIParent, p.hawkrelpoint, p.hawkx, p.hawky)
	elseif not bar then
		holder:SetPoint("CENTER", UIParent, "CENTER", -120, -60)
	elseif pos == "TOPRIGHT" then
		holder:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, GAP)
	elseif pos == "ABOVE" then
		holder:SetPoint("BOTTOMLEFT", bar, "TOP", shift - wide / 2, ROW_GAP + (p.enableborder and 3 or 0))
	elseif pos == "LEFT" then
		holder:SetPoint("RIGHT", bar, "LEFT", -ROW_GAP - shift, 0)
	elseif pos == "RIGHT" then
		holder:SetPoint("LEFT", bar, "RIGHT", ROW_GAP + shift, 0)
	else
		holder:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, GAP)
	end
	for i, c in ipairs(holder.circles) do
		c:SetSize(size, size)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * (size + GAP), -topPad)
		c.num:ClearAllPoints()
		if numPos == "MIDDLE" then
			c.num:SetPoint("CENTER", c, "CENTER", 0, 0)
		elseif numPos == "TOP" then
			c.num:SetPoint("BOTTOM", c, "TOP", 0, 1)
		else
			c.num:SetPoint("TOP", c, "BOTTOM", 0, -1)
		end
		-- the polished look, or the plain one: a flat ring and nothing else
		local polished = p.hawkpolish and true or false
		local ringTex = MEDIA .. (polished and "Ring" or "RingFlat")
		local track = polished and TRACK or PLAIN_TRACK
		c.track:SetTexture(ringTex)
		c.track:SetVertexColor(track[1], track[2], track[3])
		c.full:SetTexture(ringTex)
		Try(c.cd, "SetSwipeTexture", ringTex)
		c.shadow:SetShown(polished)
		c.gloss:SetShown(polished)
		c.line:SetShown(polished)
		if not polished then Try(c.pulse, "Stop") c.halo:Hide() end
		c.icon:SetSize(size * (polished and 0.78 or 0.80), size * (polished and 0.78 or 0.80))
		c.shadow:SetSize(size * 1.62, size * 1.62)
		c.shadow:ClearAllPoints()
		c.shadow:SetPoint("CENTER", c, "CENTER", 0, -size * 0.06)
		c.halo:SetSize(size * 1.62, size * 1.62)
		c.icon:SetTexture(hawkIcon or FALLBACK_ICON)
		SetFont(c.num, font, numSize)
		c.color, c.shownText = nil, nil -- draw the colour and the number again
		if square then c:Hide() end
	end
	-- the squares: each a proc icon standing in the holder, with our number on it
	for i, icon in ipairs(icons) do
		icon.slotX, icon.slotY = (i - 1) * (wide + between), -topPad
		icon:Apply()
		local f = icon.frame
		f.icon:SetTexture(hawkIcon or FALLBACK_ICON)
		f.num:ClearAllPoints()
		if numPos == "MIDDLE" then
			f.num:SetPoint("CENTER", f.holder, "CENTER", 0, 0)
		elseif numPos == "TOP" then
			f.num:SetPoint("BOTTOM", f.holder, "TOP", 0, 1)
		else
			f.num:SetPoint("TOP", f, "BOTTOM", 0, -1)
		end
		SetFont(f.num, font, numSize)
		f.numText, f.numWarn = nil, nil
		local ghost = holder.ghosts[i]
		ghost:SetSize(wide, wide)
		ghost:ClearAllPoints()
		ghost:SetPoint("TOPLEFT", holder, "TOPLEFT", icon.slotX, icon.slotY)
		ghost.icon:SetTexture(hawkIcon or FALLBACK_ICON)
		if not square then ghost:Hide() end
	end
	local badge = math.max(11, math.floor(size * 0.46 + 0.5))
	holder.badge:SetSize(badge, badge)
	-- the count: a small round badge on a circle, a small square one on a square
	holder.badge:ClearAllPoints()
	if square then
		holder.badge:SetPoint("CENTER", icons[1].frame.holder, "BOTTOMRIGHT", -2, 2)
		Try(holder.badge, "SetFrameLevel", (icons[1].frame.holder:GetFrameLevel() or 1) + 12)
	else
		holder.badge:SetPoint("CENTER", holder.circles[1], "BOTTOMRIGHT", -3, 3)
		Try(holder.badge, "SetFrameLevel", (holder.circles[1]:GetFrameLevel() or 1) + 5)
	end
	holder.badgeBack:SetShown(not square)
	holder.badgeRim:SetShown(not square)
	holder.badgeSq:SetShown(square)
	holder.badgeSqRim:SetShown(square)
	SetFont(holder.count, font, math.max(8, badge - 3))
	holder.countShown = nil
	holder:EnableMouse(p.hawk and not p.lock and p.hawkpos == "FREE")
	Draw()
	if Awake() then Wake() end
end

-- "Preview all alerts": two sample hawks, their rings running, for a few seconds
function YaHT:PreviewHawks(seconds)
	if not holder or not self.db.profile.hawk then return end
	holder.previewAt = GetTime()
	holder.previewUntil = holder.previewAt + seconds
	Wake()
end

-- /yaht hawk: what YaHT sees of your hawks right now
function YaHT:ReportHawks()
	if not holder then return end
	local now = GetTime()
	local parts = {}
	for i = 1, MAX_HAWKS do
		parts[#parts + 1] = slots[i] and string.format("%d: %.0fs left", i, math.max(0, slots[i].start + slots[i].dur - now)) or (i .. ": none")
	end
	self:Print("Hawks: " .. table.concat(parts, ", ") .. " | the game lists hawks in its summon slots: " .. (slotsWork and "yes" or "not seen yet"))
	self:Print("Summon slots now: " .. SlotsForRecord())
	self:PreviewHawks(6)
end

local function CreateCircle(parent)
	local c = CreateFrame("Frame", nil, parent)
	-- under everything: a soft shadow, and a soft glow in the ring's colour
	c.shadow = c:CreateTexture(nil, "BACKGROUND", nil, -3)
	c.shadow:SetTexture(MEDIA .. "Halo")
	c.shadow:SetVertexColor(0, 0, 0)
	c.shadow:SetAlpha(0.75)
	c.halo = c:CreateTexture(nil, "BACKGROUND", nil, -2)
	c.halo:SetTexture(MEDIA .. "Halo")
	Try(c.halo, "SetBlendMode", "ADD")
	c.halo:SetAlpha(GLOW_ALPHA)
	c.halo:SetPoint("CENTER", c, "CENTER", 0, 0)
	c.halo:Hide()
	if type(c.halo.CreateAnimationGroup) == "function" then
		local ok, group = pcall(c.halo.CreateAnimationGroup, c.halo)
		if ok and group then
			local okA, a = pcall(group.CreateAnimation, group, "Alpha")
			if okA and a and pcall(function()
				a:SetFromAlpha(0.62)
				a:SetToAlpha(0.20)
				a:SetDuration(0.45)
				a:SetSmoothing("IN_OUT")
				group:SetLooping("BOUNCE")
			end) then c.pulse = group end
		end
	end
	c.back = c:CreateTexture(nil, "BACKGROUND")
	c.back:SetTexture(MEDIA .. "Disc")
	c.back:SetVertexColor(0.05, 0.045, 0.04)
	c.back:SetAllPoints(c)
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetPoint("CENTER", c, "CENTER", 0, 0)
	Try(c.icon, "SetTexCoord", 0.08, 0.92, 0.08, 0.92)
	-- a round icon: the game cuts it with a round mask (a square one is the fallback)
	if type(c.CreateMaskTexture) == "function" then
		local ok, mask = pcall(c.CreateMaskTexture, c)
		if ok and mask then
			Try(mask, "SetTexture", MEDIA .. "Disc", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			Try(mask, "SetAllPoints", c.icon)
			if Try(c.icon, "AddMaskTexture", mask) then c.mask = mask end
		end
	end
	c.gloss = c:CreateTexture(nil, "ARTWORK", nil, 1) -- a soft light on the upper half of the icon
	c.gloss:SetTexture(MEDIA .. "Gloss")
	Try(c.gloss, "SetBlendMode", "ADD")
	c.gloss:SetAllPoints(c.icon)
	c.track = c:CreateTexture(nil, "BORDER")
	c.track:SetTexture(MEDIA .. "Ring")
	c.track:SetVertexColor(TRACK[1], TRACK[2], TRACK[3])
	c.track:SetAllPoints(c)
	-- the ring that runs down is the game's own cooldown sweep, drawn with a ring instead of a
	-- square: no work per frame for YaHT
	c.cd = CreateFrame("Cooldown", nil, c, "CooldownFrameTemplate")
	c.cd:SetAllPoints(c)
	Try(c.cd, "SetSwipeTexture", MEDIA .. "Ring")
	Try(c.cd, "SetDrawEdge", false)
	Try(c.cd, "SetDrawBling", false)
	Try(c.cd, "SetHideCountdownNumbers", true)
	Try(c.cd, "SetReverse", false)
	c.cd.noCooldownCount = true -- (other addons' cooldown numbers stay off it)
	c.cd:Hide()
	c.full = c:CreateTexture(nil, "OVERLAY") -- the whole ring, for a sample that stands still
	c.full:SetTexture(MEDIA .. "Ring")
	c.full:SetAllPoints(c)
	c.full:Hide()
	c.top = CreateFrame("Frame", nil, c) -- above the ring, so the number reads in the middle of the circle too
	c.top:SetAllPoints(c)
	Try(c.top, "SetFrameLevel", (c.cd:GetFrameLevel() or 1) + 2)
	c.line = c.top:CreateTexture(nil, "ARTWORK") -- fine dark lines along the ring's two edges
	c.line:SetTexture(MEDIA .. "RingLine")
	c.line:SetVertexColor(0, 0, 0)
	c.line:SetAllPoints(c)
	c.num = c.top:CreateFontString(nil, "OVERLAY")
	c.num:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE") -- (text needs a font first)
	c.num:SetPoint("TOP", c, "BOTTOM", 0, -1)
	return c
end

local function CreateHolder()
	local f = CreateFrame("Frame", "YaHTHawkFrame", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		local p = YaHT.db.profile
		if not p.lock and p.hawkpos == "FREE" then self:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p = YaHT.db.profile
		if p.hawkpos ~= "FREE" then return end
		local _
		p.hawkpoint, _, p.hawkrelpoint, p.hawkx, p.hawky = self:GetPoint()
	end)
	f.circles = {CreateCircle(f), CreateCircle(f)}
	-- "one circle with a count": the number of hawks out, on a small dark disc at the circle's corner
	f.badge = CreateFrame("Frame", nil, f)
	f.badge:SetPoint("CENTER", f.circles[1], "BOTTOMRIGHT", -3, 3)
	Try(f.badge, "SetFrameLevel", (f.circles[1]:GetFrameLevel() or 1) + 5)
	f.badgeBack = f.badge:CreateTexture(nil, "BACKGROUND")
	f.badgeBack:SetTexture(MEDIA .. "Disc")
	f.badgeBack:SetVertexColor(0.05, 0.045, 0.04)
	f.badgeBack:SetAllPoints(f.badge)
	f.badgeRim = f.badge:CreateTexture(nil, "BORDER")
	f.badgeRim:SetTexture(MEDIA .. "Ring")
	f.badgeRim:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
	f.badgeRim:SetAllPoints(f.badge)
	f.badgeSqRim = f.badge:CreateTexture(nil, "BACKGROUND")
	f.badgeSqRim:SetTexture(WHITE)
	f.badgeSqRim:SetVertexColor(SQUARE_GOLD[1], SQUARE_GOLD[2], SQUARE_GOLD[3])
	f.badgeSqRim:SetAllPoints(f.badge)
	f.badgeSqRim:Hide()
	f.badgeSq = f.badge:CreateTexture(nil, "BORDER")
	f.badgeSq:SetTexture(WHITE)
	f.badgeSq:SetVertexColor(0.05, 0.045, 0.04)
	f.badgeSq:SetPoint("TOPLEFT", f.badge, "TOPLEFT", 1, -1)
	f.badgeSq:SetPoint("BOTTOMRIGHT", f.badge, "BOTTOMRIGHT", -1, 1)
	f.badgeSq:Hide()
	-- the square shape's free spot, greyed out (a free circle greys itself)
	f.ghosts = {}
	for i = 1, MAX_HAWKS do
		local g = CreateFrame("Frame", nil, f)
		g.rim = g:CreateTexture(nil, "BACKGROUND")
		g.rim:SetTexture(WHITE)
		g.rim:SetVertexColor(TRACK[1], TRACK[2], TRACK[3])
		g.rim:SetAllPoints(g)
		g.back = g:CreateTexture(nil, "BORDER")
		g.back:SetTexture(WHITE)
		g.back:SetVertexColor(0.05, 0.045, 0.04)
		g.back:SetPoint("TOPLEFT", g, "TOPLEFT", 1, -1)
		g.back:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -1, 1)
		g.icon = g:CreateTexture(nil, "ARTWORK")
		Try(g.icon, "SetTexCoord", 0.08, 0.92, 0.08, 0.92)
		g.icon:SetAllPoints(g.back)
		g.icon:SetAlpha(0.3)
		Try(g.icon, "SetDesaturated", true)
		g:Hide()
		f.ghosts[i] = g
	end
	f.count = f.badge:CreateFontString(nil, "OVERLAY")
	f.count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	f.count:SetPoint("CENTER", f.badge, "CENTER", 0, 0)
	f.count:SetTextColor(0.95, 0.89, 0.71)
	f.badge:Hide()
	f.dragHint = f:CreateFontString(nil, "OVERLAY")
	f.dragHint:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
	f.dragHint:SetPoint("BOTTOM", f, "TOP", 0, 2)
	f.dragHint:SetTextColor(0.8, 0.8, 0.8)
	f.dragHint:SetText(L["Hawks (drag me)"])
	f.dragHint:Hide()
	f:Hide()
	return f
end

-- The square shape: two proc icons from procs.lua, so a square hawk looks and behaves like Rapid
-- Fire's icon (shared or own look, glow, pulse, sound, polished or standard). Ours: where they
-- stand (in the holder), when they are out, the red warning and the seconds.
local function CreateSquares()
	if type(YaHT.NewProcIcon) ~= "function" then return end
	for i = 1, MAX_HAWKS do
		local def = {
			key = "hawk", frameName = "YaHTHawkIcon" .. i, label = "Hawk" .. i,
			shape = "SQUARE", -- (round hawks are the circles above, not these)
			spellID = 1293241, fallbackIcon = FALLBACK_ICON, window = HAWK_TIME,
			ahead = (i - 1) * 9, -- while you place them, the two samples run half a turn apart
			on = function(p) return p.hawk and p.hawkshape == "SQUARE" and (i == 1 or p.hawkmode ~= "COUNT") or false end,
			tint = function(left, p) if p.hawkwarn > 0 and left < p.hawkwarn then return SQUARE_WARN end end,
		}
		local icon = YaHT.NewProcIcon(def)
		def.place = function(f)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", holder, "TOPLEFT", icon.slotX or 0, icon.slotY or 0)
		end
		local f = icon:Create()
		f.top = CreateFrame("Frame", nil, f) -- above the icon's own cooldown number
		f.top:SetAllPoints(f)
		Try(f.top, "SetFrameLevel", (f.holder:GetFrameLevel() or 1) + 8)
		f.num = f.top:CreateFontString(nil, "OVERLAY")
		f.num:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
		f.num:SetPoint("TOP", f, "BOTTOM", 0, -1)
		icons[i] = icon
	end
end

function YaHT:InitHawks()
	holder = CreateHolder()
	self.hawkFrame = holder
	self.hawkSlots = slots
	local ok, err = pcall(CreateSquares)
	if not ok then
		icons = {} -- (the circles work without them)
		if self.ReportError then self.ReportError("HawkSquares", err) end
	end
	self.hawkIcons = icons
	watch = CreateFrame("Frame")
	self.hawkWatch = watch
	watch.sum = 0
	pcall(watch.RegisterUnitEvent, watch, "UNIT_SPELLCAST_SUCCEEDED", "player")
	for _, e in ipairs({"PLAYER_TOTEM_UPDATE", "PLAYER_DEAD", "PLAYER_ENTERING_WORLD"}) do
		pcall(watch.RegisterEvent, watch, e)
	end
	watch:SetScript("OnEvent", function(self, event, ...)
		if not YaHT.db then return end
		local ok, err = pcall(OnEvent, self, event, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError("HawkEvent", err) end
	end)
	watch:SetScript("OnUpdate", function(self, elapsed)
		local ok, err = pcall(Step, self, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError("HawkWatch", err) end
	end)
	watch:Hide()
	self:ApplyHawkSettings()
end
