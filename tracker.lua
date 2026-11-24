-- YaHT tracking wheel: a small button that shows what you are tracking. Click it
-- and the things you can track open around it as a pie, one piece each. Move the
-- mouse into the piece you want (the whole piece lights up) and on out of the
-- pie: that one is picked.
--
-- Forever keeps tracking in the minimap's own list (C_Minimap), the same list its
-- tracking button uses, so the wheel reads and sets that list. The game takes a
-- pick made by mouse movement alone (seen in game, 2026-11-24). Should a client
-- ever want a click for it, YaHT notices the pick did not take, says so once, and
-- from then on only clicks pick.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end
local function Plain(v) if IsSecret(v) then return nil end return v end
local function Try(obj, method, ...)
	if type(obj[method]) ~= "function" then return false end
	return (pcall(obj[method], obj, ...))
end

local MEDIA = "Interface\\AddOns\\YaHT\\media\\"
local NOTHING = "Interface\\Icons\\INV_Misc_Spyglass_03"  -- shown while you track nothing
local GIVE_UP = 1.2       -- no change this long after a pick made without a click: the game wants a click
local OPEN_TIME = 0.14    -- the pie opens this fast
local CLOSE_TIME = 0.1    -- and fades away this fast
local GLIDE = 0.09        -- a piece lights up (and its track grows) over this long
local GAP = 10
local GROW = 1.22         -- the track you are heading for is drawn this much bigger
local MAX_PIECES = 12     -- media has a piece of pie for 1 to 12 tracks ("Wedge<n>", pointing up)
local HOLE = 30 / 126     -- the hole in the middle of the pie (for the button), as a share of its radius
local PIE = {0.15, 0.15, 0.17, 0.72}        -- a piece of the pie: grey, see-through
local PIE_ACTIVE = {0.30, 0.25, 0.13, 0.76} -- the piece of what you track now: a breath of gold
local PIE_AIMED = {1, 0.90, 0.62, 0.50}     -- the piece you are heading for
local RIM, RIM_ACTIVE, RIM_AIMED = {0, 0, 0}, {0.72, 0.58, 0.24}, {1, 1, 1} -- (the gold is kept quiet)
local TEXT, TEXT_AIMED = {1, 1, 1}, {1, 0.90, 0.62}

local hub, wheel
local slices = {}
local moveBlocked = false -- (this session) the game ignored a pick made without a click

---------------------------------------------------------------------------
-- What the game tells us
---------------------------------------------------------------------------
-- The tracking list: {index, name, texture, active}. Spells only (Track Beasts,
-- Find Minerals...) unless "everything" is on, which adds the minimap's other filters.
local function Types()
	local list = {}
	local m = C_Minimap
	if not (m and type(m.GetNumTrackingTypes) == "function" and type(m.GetTrackingInfo) == "function") then return list end
	local ok, n = pcall(m.GetNumTrackingTypes)
	n = ok and Plain(n)
	if type(n) ~= "number" then return list end
	local all = YaHT.db.profile.trackerall
	for i = 1, n do
		local okI, info = pcall(m.GetTrackingInfo, i)
		if okI and type(info) == "table" then
			local name, kind = Plain(info.name), Plain(info.type)
			if type(name) == "string" and (all or kind == "spell") then
				list[#list + 1] = {index = i, name = name, texture = Plain(info.texture),
					active = Plain(info.active) and true or false, spell = kind == "spell"}
			end
		end
	end
	return list
end

-- What you track right now (a spell before a minimap filter), or nil
local function Current(list)
	local other
	for _, t in ipairs(list) do
		if t.active then
			if t.spell then return t end
			other = other or t
		end
	end
	return other
end

local function Set(index, on)
	local m = C_Minimap
	if not (m and type(m.SetTracking) == "function") then return false end
	return (pcall(m.SetTracking, index, on and true or false))
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- A round icon: a disc behind it as its rim, the picture cut round by the game
-- (square where the game has no masks), and a soft light on its upper half.
local function Icon(parent, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.rim = b:CreateTexture(nil, "BACKGROUND")
	b.rim:SetTexture(MEDIA .. "Disc")
	b.rim:SetPoint("TOPLEFT", b, "TOPLEFT", -1.5, 1.5)
	b.rim:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1.5, -1.5)
	b.rim:SetVertexColor(0, 0, 0)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints(b)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if type(b.CreateMaskTexture) == "function" then
		local ok, mask = pcall(b.CreateMaskTexture, b)
		if ok and mask then
			Try(mask, "SetTexture", MEDIA .. "Disc", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			Try(mask, "SetAllPoints", b.icon)
			if Try(b.icon, "AddMaskTexture", mask) then b.mask = mask end
		end
	end
	b.gloss = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.gloss:SetTexture(MEDIA .. "Gloss")
	Try(b.gloss, "SetBlendMode", "ADD")
	b.gloss:SetAllPoints(b.icon)
	b.gloss:SetAlpha(0.5)
	return b
end

local function Mix(a, b, k)
	return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * k
end

-- A track and its piece of the pie, from "resting" (glow 0) to "heading for it" (glow 1)
local function Paint(s)
	local k = s.glow or 0
	local r, g, b = Mix(s.active and RIM_ACTIVE or RIM, RIM_AIMED, k)
	s.rim:SetVertexColor(r, g, b)
	if s.piece then
		-- (a texture has one alpha: SetAlpha would overwrite this one, so the pie's fade-in is part of it)
		local a
		r, g, b, a = Mix(s.active and PIE_ACTIVE or PIE, PIE_AIMED, k)
		s.piece:SetVertexColor(r, g, b, a * (s.fade or 1))
	end
end

local function Refresh()
	if not hub then return end
	local list = Types()
	local now = Current(list)
	hub.icon:SetTexture(now and now.texture or NOTHING)
	hub.icon:SetDesaturated(not now)
	local c = now and RIM_ACTIVE or RIM
	hub.rim:SetVertexColor(c[1], c[2], c[3])
	hub.current = now and now.name or nil
	for _, s in ipairs(slices) do
		s.active = false
		for _, t in ipairs(list) do
			if t.index == s.index then s.active = t.active end
		end
		Paint(s)
	end
	-- a pick made without a click went through
	if hub.pending then
		for _, t in ipairs(list) do
			if t.index == hub.pending and t.active then hub.pending = nil end
		end
	end
end

-- Closes the pie (it fades away; at once when told to)
local function Close(atOnce)
	if not wheel or not wheel:IsShown() then return end
	wheel.open = false
	if wheel.aimed then wheel.aimed.lit = false end
	wheel.aimed = nil
	if atOnce then
		wheel:Hide()
		hub.layer = "LOW" hub:SetFrameStrata("LOW")
	else
		wheel.closingAt = wheel.closingAt or GetTime()
	end
end

-- byClick: a real click on a track (the game always takes that)
local function Pick(s, byClick)
	if byClick and s.active then
		Set(s.index, false) -- a click on the one you track switches it off
	elseif not s.active then
		Set(s.index, true)
		if not byClick then hub.pending, hub.pendingSince = s.index, GetTime() end
	end
	Close()
	Refresh()
end

-- how far from the middle the tracks sit
local function Radius(n, size)
	return math.max(size * 2.1, n * (size + GAP) / (2 * math.pi) * 1.2)
end

local function Open()
	local p = YaHT.db.profile
	local list = Types()
	if #list == 0 then
		YaHT:Print(L["Nothing to track yet: the game lists no tracking for this character."])
		return
	end
	local size = p.trackersize
	for i, t in ipairs(list) do
		local s = slices[i]
		if not s then
			s = Icon(wheel, size)
			s.piece = wheel:CreateTexture(nil, "BACKGROUND")
			s.piece:SetPoint("CENTER", hub, "CENTER", 0, 0)
			s:RegisterForClicks("LeftButtonUp")
			s:SetScript("OnClick", function(self) if wheel.open then Pick(self, true) end end)
			slices[i] = s
		end
		s.index, s.name, s.active, s.lit, s.glow, s.fade = t.index, t.name, t.active, false, 0, 0
		s.angle = (i - 1) / #list * 2 * math.pi -- the first one on top, then clockwise
		-- its piece of the pie: the picture points up, turned to where this track sits
		s.piece:SetTexture(MEDIA .. "Wedge" .. math.min(#list, MAX_PIECES))
		Try(s.piece, "SetRotation", -s.angle)
		s.piece:Show()
		s.icon:SetTexture(t.texture or NOTHING)
		Paint(s)
		s:Show()
	end
	for i = #list + 1, #slices do slices[i]:Hide() slices[i].piece:Hide() end
	wheel.count, wheel.radius = #list, Radius(#list, size)
	wheel.edge = wheel.radius + size * 1.3 -- the pie's edge: past it, the track you headed for is picked
	wheel.openedAt, wheel.closingAt, wheel.open = GetTime(), nil, true
	wheel.aimed = nil
	wheel.label:ClearAllPoints() -- the name sits under the pie, clear of the tracks
	wheel.label:SetPoint("TOP", hub, "CENTER", 0, -wheel.edge - 8)
	wheel.label:SetText(hub.current or L["No tracking"])
	wheel.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
	hub.layer = "DIALOG" hub:SetFrameStrata("DIALOG") -- in front while its pie is open, so a click in the middle closes it
	wheel:SetAlpha(1)
	wheel:Show()
end

-- Which track the mouse is heading for (nil while it is still in the middle), and how far out it is
local function Aim(self)
	local x, y = GetCursorPosition()
	local cx, cy = hub:GetCenter()
	local scale = hub:GetEffectiveScale()
	if not (x and cx and scale and scale > 0) then return nil, 0 end
	local dx, dy = x / scale - cx, y / scale - cy
	local far = math.sqrt(dx * dx + dy * dy)
	if far < self.edge * HOLE then return nil, far end -- still on the button in the middle
	local turn = math.atan2(dx, dy) -- 0 = straight up, growing clockwise, like the tracks are laid out
	if turn < 0 then turn = turn + 2 * math.pi end
	local i = math.floor(turn / (2 * math.pi / self.count) + 0.5) % self.count + 1
	return slices[i], far
end

local function Step(self, elapsed)
	local now = GetTime()
	-- fading away
	if self.closingAt then
		local left = 1 - (now - self.closingAt) / CLOSE_TIME
		if left <= 0 then
			self.closingAt = nil
			self:Hide()
			hub.layer = "LOW" hub:SetFrameStrata("LOW")
		else
			self:SetAlpha(left)
		end
		return
	end
	local p = YaHT.db.profile
	local size = p.trackersize
	-- the pie opens from the middle
	local t = math.min(1, (now - self.openedAt) / OPEN_TIME)
	local ease = 1 - (1 - t) * (1 - t)
	local r = self.radius * ease
	local aimed, far = Aim(self)
	if aimed ~= self.aimed then
		if self.aimed then self.aimed.lit = false end
		if aimed then aimed.lit = true end
		self.aimed = aimed
		self.label:SetText(aimed and aimed.name or hub.current or L["No tracking"])
		local c = aimed and TEXT_AIMED or TEXT
		self.label:SetTextColor(c[1], c[2], c[3])
	end
	local step = math.min(1, (elapsed or 0.016) / GLIDE)
	for i = 1, self.count do
		local s = slices[i]
		-- the light glides on and off instead of jumping
		local goal = s.lit and 1 or 0
		if s.glow ~= goal or s.fade ~= t then
			if s.glow ~= goal then
				s.glow = s.glow + (goal - s.glow) * step
				if math.abs(goal - s.glow) < 0.02 then s.glow = goal end
			end
			s.fade = t
			Paint(s)
		end
		local big = size * (1 + (GROW - 1) * s.glow)
		s:SetSize(big, big)
		s:ClearAllPoints()
		s:SetPoint("CENTER", hub, "CENTER", math.sin(s.angle) * r, math.cos(s.angle) * r)
		s:SetAlpha(t)
		s.piece:SetSize(self.edge * 2 * ease, self.edge * 2 * ease)
	end
	-- out of the pie: the one you headed for is picked (or, set to clicks, the wheel just closes)
	if t >= 1 and far > self.edge then
		if aimed and p.trackerpick ~= "CLICK" and not moveBlocked then
			Pick(aimed, false)
		else
			Close()
		end
	end
end

-- The game ignored a pick made without a click: say so once, and leave picking to clicks
local function Watch(self)
	if not self.pending or GetTime() - self.pendingSince < GIVE_UP then return end
	self.pending = nil
	moveBlocked = true
	YaHT:Print(L["The game only switches tracking on a click: click a track in the wheel instead of moving out past it."])
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
function YaHT:ApplyTrackerSettings()
	if not hub then return end
	local p = self.db.profile
	hub:SetSize(p.trackersize, p.trackersize)
	hub:ClearAllPoints()
	if p.trackerpoint then
		hub:SetPoint(p.trackerpoint, UIParent, p.trackerrelpoint, p.trackerx, p.trackery)
	else
		hub:SetPoint("CENTER", UIParent, "CENTER", -230, -350)
	end
	hub:SetMovable(not p.lock)
	hub.dragHint:SetShown(not p.lock and p.tracker)
	Close(true)
	hub:SetShown(p.tracker and true or false)
	Refresh()
end

-- /yaht track: what YaHT sees of the game's tracking list
function YaHT:ReportTracker()
	local all = self.db.profile.trackerall
	self.db.profile.trackerall = true
	local list = Types()
	self.db.profile.trackerall = all
	if #list == 0 then
		self:Print("Tracking: the game lists nothing (no tracking list on this client, or nothing learned).")
		return
	end
	for _, t in ipairs(list) do
		self:Print(string.format("Tracking %d: %s%s%s", t.index, t.name, t.spell and " (spell)" or "", t.active and " - ON" or ""))
	end
	self:Print("Picks without a click: " .. (moveBlocked and "the game ignored one, clicks only this session" or "not refused so far"))
end

function YaHT:InitTracker()
	hub = Icon(UIParent, 36)
	hub.layer = "LOW" hub:SetFrameStrata("LOW") -- behind your bags and other windows while it is closed
	hub:SetClampedToScreen(true)
	hub:RegisterForClicks("LeftButtonUp")
	hub:RegisterForDrag("LeftButton")
	hub:SetScript("OnDragStart", function(self)
		if YaHT.db.profile.lock then return end
		Close(true)
		self:StartMoving()
	end)
	hub:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p = YaHT.db.profile
		local _
		p.trackerpoint, _, p.trackerrelpoint, p.trackerx, p.trackery = self:GetPoint()
	end)
	hub:SetScript("OnClick", function()
		if wheel.open then Close() else Open() end
	end)
	hub:SetScript("OnUpdate", function(self)
		local ok, err = pcall(Watch, self)
		if not ok and YaHT.ReportError then YaHT.ReportError("TrackerWatch", err) end
	end)
	hub.dragHint = hub:CreateFontString(nil, "OVERLAY")
	hub.dragHint:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
	hub.dragHint:SetPoint("TOP", hub, "BOTTOM", 0, -4)
	hub.dragHint:SetTextColor(0.8, 0.8, 0.8)
	hub.dragHint:SetText(L["Tracking wheel (drag me)"])
	hub.dragHint:Hide()
	self.trackerFrame = hub

	wheel = CreateFrame("Frame", "YaHTTrackerWheel", UIParent)
	wheel:SetFrameStrata("HIGH") -- (under the button, so a click in the middle still closes it)
	wheel:SetSize(1, 1)
	wheel:SetPoint("CENTER", hub, "CENTER", 0, 0)
	wheel.label = wheel:CreateFontString(nil, "OVERLAY")
	wheel.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
	wheel.count, wheel.radius, wheel.edge, wheel.openedAt, wheel.open = 0, 0, 0, 0, false
	wheel:Hide()
	wheel:SetScript("OnUpdate", function(self, elapsed)
		local ok, err = pcall(Step, self, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError("TrackerWheel", err) end
	end)
	self.trackerWheel = wheel
	self.trackerSlices = slices

	local watch = CreateFrame("Frame")
	for _, e in ipairs({"MINIMAP_UPDATE_TRACKING", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED"}) do
		pcall(watch.RegisterEvent, watch, e)
	end
	watch:SetScript("OnEvent", function()
		if not YaHT.db then return end
		local ok, err = pcall(Refresh)
		if not ok and YaHT.ReportError then YaHT.ReportError("TrackerEvent", err) end
	end)
	self.trackerWatch = watch
	self:ApplyTrackerSettings()
end
