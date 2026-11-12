-- YaHT proc alerts: a small spell icon pops in next to the Auto Shot bar
-- (above, left or right) with a thin gold timer under it that drains while the
-- chance lasts. It can glow and pulse in several styles. Two alerts use it:
--   Mongoose Bite: usable for 5s after you dodge (read from spell usability)
--   Quick Shots:   +30% ranged attack speed for 12s from the Deadly Aspects
--                  talent (read from your buffs)
-- No combat log needed. Each alert's settings start with its key
-- ("mongoose", "quickshots"): pos, size, alpha, sound, glow, glowcolor, pulse.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GLOW_TEX = "Interface\\AddOns\\YaHT\\media\\Glow"
local SHINE_TEX = "Interface\\AddOns\\YaHT\\media\\Shine"
local SPARK_TEX = "Interface\\AddOns\\YaHT\\media\\Spark"
local HURRY = 1.5         -- the pulse speeds up in the last seconds of the window
local POP_TIME = 0.18     -- the icon pops in slightly big, then settles
local POP_SCALE = 1.35
local FADE_IN, FADE_OUT = 0.1, 0.25
local GAP = 6
local NUM_SPARKS = 4
local GOLD = {0.85, 0.70, 0.42}
local NO_MANA = {0.45, 0.55, 1.0}
local TWO_PI = 2 * math.pi

---------------------------------------------------------------------------
-- Pulse styles: how the icon itself moves. Each returns scale, alpha, flash.
---------------------------------------------------------------------------
local function Thump(x, at, width)
	if x < at or x >= at + width then return 0 end
	return math.sin(math.pi * (x - at) / width)
end

local PULSES = {
	BREATHE = function(ph) return 1, 0.6 + 0.4 * (0.5 + 0.5 * math.cos(TWO_PI * ph / 1.2)), 0 end,
	GROW = function(ph) return 1 + 0.09 * (0.5 - 0.5 * math.cos(TWO_PI * ph / 0.9)), 1, 0 end,
	HEARTBEAT = function(ph)
		local x = ph % 1.0
		return 1 + 0.13 * (Thump(x, 0, 0.13) + 0.6 * Thump(x, 0.2, 0.13)), 1, 0
	end,
	FLASH = function(ph) return 1, 1, 0.6 * math.max(0, 1 - (ph % 0.8) / 0.35) end,
}

-- Icons that sit around the bar, in this order. When several share a spot
-- (above, left or right), each later one moves over past the earlier ones.
local SLOT_ORDER = {"mongoose", "quickshots", "rapidfire", "racial", "aspect"}
-- the size an icon around the bar takes up (the aspect badge has its own)
local function IconSize(p, key)
	if key == "aspect" then return p.aspectsize end
	if p[key .. "own"] then return p[key .. "iconsize"] end
	return p.procsize
end

local function SlotShift(p, key)
	local pos, shift = p[key .. "pos"], 0
	if pos == "FREE" then return 0 end -- placed by hand: not in the row
	for _, other in ipairs(SLOT_ORDER) do
		if other == key then break end
		if p[other] and p[other .. "pos"] == pos then shift = shift + IconSize(p, other) + 2 + GAP end
	end
	return shift
end

-- Put an icon frame at its spot around the bar.
local function PlaceAroundBar(f, p, key)
	local main = YaHT.mainFrame
	local pos, shift = p[key .. "pos"], SlotShift(p, key)
	f:ClearAllPoints()
	-- "Anywhere": dragged by hand while unlocked; clicks pass through when locked
	local free = pos == "FREE"
	f:EnableMouse(free and not p.lock)
	if free then
		if p[key .. "point"] then
			f:SetPoint(p[key .. "point"], UIParent, p[key .. "relpoint"], p[key .. "x"], p[key .. "y"])
		else
			-- not placed yet: start above the bar, each in its own spot, ready to drag
			local slot = 0
			for i, k in ipairs(SLOT_ORDER) do if k == key then slot = i end end
			f:SetPoint("BOTTOM", main, "TOP", (slot - 3) * 44, 60)
		end
		return
	end
	if pos == "LEFT" then
		f:SetPoint("RIGHT", main, "LEFT", -GAP - shift, 0)
	elseif pos == "RIGHT" then
		f:SetPoint("LEFT", main, "RIGHT", GAP + shift, 0)
	else
		f:SetPoint("BOTTOM", main, "TOP", shift, GAP + (p.enableborder and 3 or 0))
	end
end

-- Icons set to "Anywhere" can be dragged while the bar is unlocked; the
-- spot is saved per icon (like the ammo counter).
local function MakeDraggable(f, key)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		local p = YaHT.db.profile
		if not p.lock and p[key .. "pos"] == "FREE" then self:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p = YaHT.db.profile
		if p[key .. "pos"] ~= "FREE" then return end
		local _
		p[key .. "point"], _, p[key .. "relpoint"], p[key .. "x"], p[key .. "y"] = self:GetPoint()
	end)
	f:EnableMouse(false)
end

local function GetLCG()
	return LibStub and LibStub("LibCustomGlow-1.0", true)
end

-- where a spark is on the square around the icon (d runs 0..4 around it)
local function Perimeter(d, half)
	local side = math.floor(d) % 4
	local f = d - math.floor(d)
	if side == 0 then return -half + 2 * half * f, half end
	if side == 1 then return half, half - 2 * half * f end
	if side == 2 then return half - 2 * half * f, -half end
	return -half, -half + 2 * half * f
end

---------------------------------------------------------------------------
-- One proc icon
---------------------------------------------------------------------------
local Icon = {}
Icon.__index = Icon

-- def: key (settings prefix), frameName, spellID (icon), fallbackIcon,
-- window (seconds shown when the game doesn't say), label (debug log),
local function NewIcon(def)
	return setmetatable({def = def, key = def.key, lcgKey = "YaHT" .. def.key}, Icon)
end

-- The look (size, opacity, glow style, pulse, sound) is shared by all proc
-- icons ("proc" settings), unless an icon is given its own (<key>own, then
-- <key>iconsize ...); position, glow color and on/off are always per icon.
local SHARED = {size = true, alpha = true, glow = true, pulse = true, sound = true}
function Icon:Setting(p, suffix)
	if SHARED[suffix] then
		if p[self.key .. "own"] then return p[self.key .. "icon" .. suffix] end
		return p["proc" .. suffix]
	end
	return p[self.key .. suffix]
end


function Icon:HideGlows()
	local f = self.frame
	f.halo:Hide()
	for _, t in pairs(f.ring) do t:Hide() end
	f.shine:Hide()
	for i = 1, NUM_SPARKS do f.sparks[i]:Hide() end
end

function Icon:StopLibGlow()
	local f = self.frame
	if not f.libGlow then return end
	local LCG = GetLCG()
	if LCG then
		if f.libGlow == "PROC" and LCG.ProcGlow_Stop then pcall(LCG.ProcGlow_Stop, f.holder, self.lcgKey)
		elseif f.libGlow == "BUTTON" and LCG.ButtonGlow_Stop then pcall(LCG.ButtonGlow_Stop, f.holder) end
	end
	f.libGlow = nil
end

-- the two effects borrowed from LibCustomGlow (ships with WeakAuras)
function Icon:StartLibGlow(style, c)
	local f = self.frame
	if f.libGlow == style then return true end
	self:StopLibGlow()
	local LCG = GetLCG()
	if not LCG then return false end
	local color, ok = {c.r, c.g, c.b, 1}, false
	if style == "PROC" and LCG.ProcGlow_Start then
		ok = pcall(LCG.ProcGlow_Start, f.holder, {color = color, key = self.lcgKey, startAnim = true})
	elseif style == "BUTTON" and LCG.ButtonGlow_Start then
		ok = pcall(LCG.ButtonGlow_Start, f.holder, color)
	end
	if ok then f.libGlow = style end
	return ok
end

function Icon:DrawGlow(p, gp, iconSize)
	local f = self.frame
	local style = self:Setting(p, "glow")
	local c = self:Setting(p, "glowcolor")
	if style == "PROC" or style == "BUTTON" then
		self:HideGlows()
		if self:StartLibGlow(style, c) then return end
		style = "HALO" -- library missing: fall back to the built-in halo
	else
		self:StopLibGlow()
	end
	local r, g, b = c.r, c.g, c.b
	if style ~= "HALO" then f.halo:Hide() end
	if style ~= "RING" then for _, t in pairs(f.ring) do t:Hide() end end
	if style ~= "SHINE" then f.shine:Hide() end
	if style ~= "SPARKS" then for i = 1, NUM_SPARKS do f.sparks[i]:Hide() end end

	if style == "HALO" then
		local h = f.halo
		local pad = math.max(8, iconSize * 0.4)
		h:SetSize(iconSize + 2 * pad, iconSize + 2 * pad)
		h:SetVertexColor(r, g, b)
		h:SetAlpha(0.6 + 0.3 * math.sin(TWO_PI * gp / 1.6))
		h:Show()
	elseif style == "RING" then
		local a = 0.65 + 0.35 * math.sin(TWO_PI * gp / 1.2)
		for _, t in pairs(f.ring) do
			t:SetVertexColor(r, g, b)
			t:SetAlpha(a)
			t:Show()
		end
	elseif style == "SHINE" then
		local s = f.shine
		local x = (gp % 1.4) / 0.6 -- crosses in 0.6s, then rests
		if x < 1 then
			s:SetSize(iconSize * 0.6, iconSize)
			s:ClearAllPoints()
			s:SetPoint("CENTER", f.holder, "CENTER", -iconSize + 2 * iconSize * x, 0)
			s:SetVertexColor(r, g, b)
			s:SetAlpha(0.9)
			s:Show()
		else
			s:Hide()
		end
	elseif style == "SPARKS" then
		local half = iconSize / 2 + 1
		local sz = math.max(6, iconSize * 0.35)
		for i = 1, NUM_SPARKS do
			local sp = f.sparks[i]
			local x, y = Perimeter((gp / 1.6 * 4 + (i - 1)) % 4, half)
			sp:SetSize(sz, sz)
			sp:ClearAllPoints()
			sp:SetPoint("CENTER", f.holder, "CENTER", x, y)
			sp:SetVertexColor(r, g, b)
			sp:Show()
		end
	end
end

function Icon:SetIconSize(size)
	local f = self.frame
	f.border:SetSize(size + 2, size + 2)
	f.icon:SetSize(size, size)
	f.flash:SetSize(size, size)
	local th = 2
	local out = size / 2 + 1 + th -- ring sits just outside the rim
	local R = f.ring
	R.T:SetSize(size + 2 + 2 * th, th) R.T:ClearAllPoints() R.T:SetPoint("CENTER", f.holder, "CENTER", 0, out - th / 2)
	R.B:SetSize(size + 2 + 2 * th, th) R.B:ClearAllPoints() R.B:SetPoint("CENTER", f.holder, "CENTER", 0, -out + th / 2)
	R.L:SetSize(th, size + 2) R.L:ClearAllPoints() R.L:SetPoint("CENTER", f.holder, "CENTER", -out + th / 2, 0)
	R.R:SetSize(th, size + 2) R.R:ClearAllPoints() R.R:SetPoint("CENTER", f.holder, "CENTER", out - th / 2, 0)
end

function Icon:OnUpdate(elapsed)
	local f = self.frame
	local p = YaHT.db.profile
	local now = GetTime()
	local preview = not p.lock
	local start, window = f.procStart, f.window or self.def.window
	if preview then
		-- placing the bar: loop a pretend proc so you can see where it sits
		window = self.def.window
		local cycle = window + 1
		start = now - (now % cycle)
	end
	-- a preview from "Preview all alerts" ends by itself
	if f.previewUntil and now > f.previewUntil then
		f.previewUntil = nil
		f.proc = false
	end
	local want = (preview or f.proc) and 1 or 0

	local a = f.fade or 0
	if a < want then
		a = math.min(want, a + elapsed / FADE_IN)
	elseif a > want then
		a = math.max(want, a - elapsed / FADE_OUT)
	end
	f.fade = a
	f:SetAlpha(a * (self:Setting(p, "alpha") or 1))
	if a <= 0 and want <= 0 then
		self:StopLibGlow()
		self:HideGlows()
		f:Hide()
		return
	end
	if not start then return end

	local t = now - start
	local left = math.max(0, 1 - t / window)
	local size = self:Setting(p, "size")

	-- pop in, then the chosen pulse (a bit faster near the end of the window)
	local k, iconAlpha, flash = 1, 1, 0
	if t < POP_TIME then
		local g = t / POP_TIME
		k = POP_SCALE - (POP_SCALE - 1) * (1 - (1 - g) * (1 - g))
		f.pulsePhase, f.glowPhase = 0, 0
	else
		local hurry = (window - t) < HURRY and 1.8 or 1
		f.pulsePhase = (f.pulsePhase or 0) + elapsed * hurry
		local pulse = want > 0 and PULSES[self:Setting(p, "pulse")]
		if pulse then k, iconAlpha, flash = pulse(f.pulsePhase) end
	end
	f.glowPhase = (f.glowPhase or 0) + elapsed

	-- still on cooldown: grey icon, clock sweep and seconds; when it comes
	-- off cooldown during the chance, the icon pops again: press it now
	local cdLeft = (not preview and f.cdEnd) and (f.cdEnd - now) or 0
	local onCD = cdLeft > 0
	if onCD ~= f.drawnCD then
		f.drawnCD = onCD
		if f.icon.SetDesaturated then f.icon:SetDesaturated(onCD) end
		f.cdShade:SetShown(onCD)
		f.cdText:SetShown(onCD)
		if f.cd then
			if onCD and f.cd.SetCooldown then
				f.cd:SetCooldown(f.cdStart, f.cdDur)
				f.cd:Show()
			else
				f.cd:Hide()
			end
		end
		if not onCD and f.wasOnCD then f.readyAt = now end
		f.wasOnCD = onCD
		f.cdShown = nil
	end
	if onCD then
		-- whole seconds above 3, tenths below; text only changes when the number does
		local shown = cdLeft >= 3 and math.ceil(cdLeft) or math.floor(cdLeft * 10 + 0.999) / 10
		if shown ~= f.cdShown then
			f.cdShown = shown
			f.cdText:SetText(cdLeft >= 3 and string.format("%d", shown) or string.format("%.1f", shown))
		end
		if t >= POP_TIME then k, iconAlpha, flash = 1, 1, 0 end -- no pulsing while you can't press it yet
	elseif f.readyAt and now - f.readyAt < POP_TIME * 2 then
		local g = (now - f.readyAt) / (POP_TIME * 2)
		k = POP_SCALE - (POP_SCALE - 1) * (1 - (1 - g) * (1 - g))
		flash = 0.6 * (1 - g)
	end
	if f.drawnK ~= k then
		f.drawnK = k
		self:SetIconSize(size * k)
	end
	f.icon:SetAlpha(iconAlpha)
	f.flash:SetAlpha(flash)

	if want > 0 and not onCD and self:Setting(p, "glow") ~= "NONE" then
		self:DrawGlow(p, f.glowPhase, size * k)
	else
		self:HideGlows()
		self:StopLibGlow()
	end

	f.timer:SetWidth(math.max(size * left, 0.01))
	local c = (f.noMana and not preview) and NO_MANA or GOLD
	f.timer:SetVertexColor(c[1], c[2], c[3])
	f.border:SetVertexColor(c[1], c[2], c[3])
end

-- The proc just started. startedAt/window come from the game when it says
-- (a buff's real start and length), otherwise "now" and the default length.
function Icon:Start(noMana, startedAt, window, texture)
	local f = self.frame
	f.proc, f.noMana = true, noMana
	f.drawnCD, f.wasOnCD, f.readyAt, f.cdEnd = nil, false, nil, nil
	f.procStart = startedAt or GetTime()
	f.window = window or self.def.window
	f.drawnK = nil
	if texture then f.icon:SetTexture(texture) end
	f:Show()
	if self:Setting(YaHT.db.profile, "sound") and SOUNDKIT then
		local kit = SOUNDKIT.UI_COPY_SUCCESSFUL or SOUNDKIT.IG_ABILITY_ICON_DROP or SOUNDKIT.RAID_WARNING
		if kit then pcall(PlaySound, kit, "Master") end
	end
end

function Icon:End()
	local f = self.frame
	if not f.proc then return false end
	f.proc = false
	return true
end

function Icon:Apply()
	local f = self.frame
	if not f then return end
	local p = YaHT.db.profile
	f:SetScale(p.scale)
	local size = self:Setting(p, "size")
	f:SetSize(size + 2, size + 6)
	PlaceAroundBar(f, p, self.key) -- icons on the same spot sit side by side
	f.holder:SetSize(size + 2, size + 2)
	f.cdText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", math.max(9, math.floor(size * 0.45)), "OUTLINE")
	f.drawnK = nil
	self:SetIconSize(size)
	f.timer:SetHeight(2)
	f.timer:SetWidth(size)
	f.track:SetSize(size, 2)
	self:StopLibGlow() -- restarts with the new color/style on the next frame
	if not p[self.key] then
		f.proc = false
		self:HideGlows()
		f.fade = 0 f:SetAlpha(0) f:Hide()
	elseif not p.lock then
		f:Show()
	end
end

function Icon:Create()
	local def = self.def
	local f = CreateFrame("Frame", def.frameName, UIParent)
	f:SetFrameStrata("MEDIUM")
	MakeDraggable(f, def.key)
	self.frame = f

	-- the icon square (glows attach to this)
	local holder = CreateFrame("Frame", nil, f)
	holder:SetPoint("TOP", f, "TOP", 0, 0)
	f.holder = holder

	f.halo = holder:CreateTexture(nil, "BACKGROUND", nil, -1)
	f.halo:SetTexture(GLOW_TEX)
	f.halo:SetBlendMode("ADD")
	f.halo:SetPoint("CENTER", holder, "CENTER", 0, 0)
	f.halo:Hide()

	f.ring = {}
	for _, side in ipairs({"T", "B", "L", "R"}) do
		local t = holder:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(WHITE)
		t:SetBlendMode("ADD")
		t:Hide()
		f.ring[side] = t
	end

	f.border = holder:CreateTexture(nil, "BORDER")
	f.border:SetTexture(WHITE)
	f.border:SetPoint("CENTER", holder, "CENTER", 0, 0)

	f.icon = holder:CreateTexture(nil, "ARTWORK")
	local tex = def.spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(def.spellID)
	if IsSecret(tex) or not tex then tex = def.fallbackIcon end
	f.icon:SetTexture(tex)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon edge
	f.icon:SetPoint("CENTER", holder, "CENTER", 0, 0)

	f.flash = holder:CreateTexture(nil, "OVERLAY")
	f.flash:SetTexture(WHITE)
	f.flash:SetBlendMode("ADD")
	f.flash:SetPoint("CENTER", holder, "CENTER", 0, 0)
	f.flash:SetAlpha(0)

	-- cooldown look: dark shade, the game's clock sweep, and our own seconds
	f.cdShade = holder:CreateTexture(nil, "OVERLAY", nil, 2)
	f.cdShade:SetTexture(WHITE)
	f.cdShade:SetVertexColor(0, 0, 0, 0.45)
	f.cdShade:SetPoint("TOPLEFT", f.icon, "TOPLEFT")
	f.cdShade:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT")
	f.cdShade:Hide()
	local okCD, cd = pcall(CreateFrame, "Cooldown", nil, holder, "CooldownFrameTemplate")
	if okCD and cd then
		cd:SetPoint("TOPLEFT", f.icon, "TOPLEFT")
		cd:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT")
		if cd.SetDrawEdge then cd:SetDrawEdge(false) end
		if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end -- YaHT draws its own
		cd:Hide()
		f.cd = cd
	end
	local textHolder = CreateFrame("Frame", nil, holder)
	textHolder:SetAllPoints(holder)
	textHolder:SetFrameLevel(holder:GetFrameLevel() + 6)
	f.cdText = textHolder:CreateFontString(nil, "OVERLAY")
	f.cdText:SetPoint("CENTER", holder, "CENTER", 0, 0)
	f.cdText:SetTextColor(1, 1, 1)
	f.cdText:Hide()

	-- shine runs across the icon, clipped to it
	local clip = CreateFrame("Frame", nil, holder)
	clip:SetAllPoints(holder)
	if clip.SetClipsChildren then clip:SetClipsChildren(true) end
	f.shine = clip:CreateTexture(nil, "OVERLAY")
	f.shine:SetTexture(SHINE_TEX)
	f.shine:SetBlendMode("ADD")
	f.shine:Hide()

	f.sparks = {}
	for i = 1, NUM_SPARKS do
		local sp = holder:CreateTexture(nil, "OVERLAY", nil, 1)
		sp:SetTexture(SPARK_TEX)
		sp:SetBlendMode("ADD")
		sp:Hide()
		f.sparks[i] = sp
	end

	-- the gold timer under the icon
	f.track = f:CreateTexture(nil, "BACKGROUND")
	f.track:SetTexture(WHITE)
	f.track:SetVertexColor(0, 0, 0, 0.45)
	f.track:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
	f.timer = f:CreateTexture(nil, "ARTWORK")
	f.timer:SetTexture(WHITE)
	f.timer:SetPoint("LEFT", f.track, "LEFT", 0, 0)

	f.fade = 0
	f:SetAlpha(0)
	f:Hide()
	local icon = self
	f:SetScript("OnUpdate", function(_, elapsed)
		local ok, err = pcall(icon.OnUpdate, icon, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError(def.label .. "Update", err) end
	end)
	return f
end

-- A small watcher: wakes up for events, checks at most once per frame (bursts
-- of events become one check), keeps polling every `every` seconds only while
-- `awake()` says so, and otherwise sleeps (no OnUpdate at all).
-- checkOnEvent: an event alone is reason to look (else only while awake).
local function NewWatcher(name, every, events, check, awake, onEvent, checkOnEvent)
	local w = CreateFrame("Frame")
	local sum, pending = 0, false
	for _, e in ipairs(events) do
		if type(e) == "table" then
			pcall(w.RegisterUnitEvent, w, e[1], e[2])
		else
			pcall(w.RegisterEvent, w, e)
		end
	end
	local function Step(elapsed)
		sum = sum + elapsed
		if not pending and sum < every then return end
		local woken = pending
		sum, pending = 0, false
		if awake() or (woken and checkOnEvent) then check() end
		if not awake() then w:Hide() end -- nothing to follow: sleep until the next event
	end
	local function Event(event, ...)
		if onEvent then onEvent(event, ...) end
		pending = true -- something changed: look on the next frame
		w:Show()
	end
	w:SetScript("OnUpdate", function(_, elapsed)
		local ok, err = pcall(Step, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError(name .. "Poll", err) end
	end)
	w:SetScript("OnEvent", function(_, event, ...)
		if not YaHT.db then return end
		local ok, err = pcall(Event, event, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError(name .. "Event", err) end
	end)
	return w
end

local function Fighting(w)
	return w.inCombat or (InCombatLockdown and InCombatLockdown())
end

---------------------------------------------------------------------------
-- Mongoose Bite: usable for a few seconds after you dodge
---------------------------------------------------------------------------
local MONGOOSE_IDS = {1495, 14269, 14270, 14271} -- all Classic ranks
local mongoose = NewIcon({
	key = "mongoose", frameName = "YaHTMongooseFrame", label = "Mongoose",
	spellID = MONGOOSE_IDS[1], fallbackIcon = "Interface\\Icons\\Ability_Hunter_SwiftStrike", window = 5,
})

-- true / false, plus "no mana", or nil when the game hides the answer.
local function TryUsable(fn, spell)
	local ok, usable, noMana = pcall(fn, spell)
	if not ok or IsSecret(usable) or IsSecret(noMana) then return nil end
	if usable then return true, false end
	if noMana then return true, true end
	return false
end

local mongooseName -- looked up once
local function ReadMongoose()
	local fn = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
	if not fn then return nil end
	mongooseName = mongooseName or YaHT.GetSpellName(MONGOOSE_IDS[1])
	if mongooseName then
		-- the name stands for your highest rank: one question is enough
		local u, m = TryUsable(fn, mongooseName)
		if u ~= nil then return u, m end
	end
	-- name unknown or its answer hidden: ask rank by rank
	local answered = false
	for i = 1, #MONGOOSE_IDS do
		local u, m = TryUsable(fn, MONGOOSE_IDS[i])
		if u then return true, m end
		if u ~= nil then answered = true end
	end
	if answered then return false end
	return nil
end

-- Seconds of real cooldown: start and length, 0 when ready (the global
-- cooldown doesn't count), or nil when the game hides it.
local function ReadCooldown(spell)
	local s, d
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spell)
		if not ok or IsSecret(info) or type(info) ~= "table" then return nil end
		s, d = info.startTime, info.duration
	elseif GetSpellCooldown then
		local ok
		ok, s, d = pcall(GetSpellCooldown, spell)
		if not ok then return nil end
	else
		return nil
	end
	if IsSecret(s) or IsSecret(d) or type(s) ~= "number" or type(d) ~= "number" then return nil end
	if s <= 0 or d <= 1.6 or s + d <= GetTime() then return 0 end
	return s, d
end

local mongooseWatch
local function CheckMongoose()
	local p = YaHT.db.profile
	local f = mongoose.frame
	if not p.mongoose or not p.lock then mongoose:End() return end
	if f.previewUntil and GetTime() < f.previewUntil then return end -- "Preview all alerts" is showing it
	local usable, noMana = ReadMongoose()
	if usable == nil then return end -- hidden: keep what we have
	if usable then
		if not f.proc then
			mongoose:Start(noMana)
			if YaHT.debug then YaHT:Print("Mongoose Bite ready") end
		else
			f.noMana = noMana
		end
		-- on cooldown? (shown as a grey icon with a countdown)
		local s, d
		if p.mongoosecooldown then s, d = ReadCooldown(mongooseName or MONGOOSE_IDS[1]) end
		if s and s > 0 then
			if f.cdStart ~= s or not f.cdEnd then
				if YaHT.debug and not f.cdEnd then YaHT:Print(string.format("Mongoose Bite on cooldown: %.1fs left", s + d - GetTime())) end
				f.cdStart, f.cdDur, f.cdEnd = s, d, s + d
				f.drawnCD = nil
			end
		elseif f.cdEnd and s ~= nil then
			f.cdEnd = nil -- ready now
		end
	elseif mongoose:End() and YaHT.debug then
		YaHT:Print(string.format("Mongoose Bite gone after %.1fs", GetTime() - f.procStart))
	end
end

---------------------------------------------------------------------------
-- Quick Shots: +30% ranged attack speed for 12s (Deadly Aspects talent)
---------------------------------------------------------------------------
local QUICK_SHOTS_IDS = {6150} -- the Quick Shots buff (Classic's Improved Aspect of the Hawk)
local quick = NewIcon({
	key = "quickshots", frameName = "YaHTQuickShotsFrame", label = "QuickShots",
	spellID = QUICK_SHOTS_IDS[1], fallbackIcon = "Interface\\Icons\\Ability_Warrior_InnerRage", window = 12,
})

local function Readable(v)
	if IsSecret(v) or type(v) ~= "number" then return nil end
	return v
end

-- true + start, length, icon (each nil if hidden) / false / nil when the game
-- hides your buffs from addons.
local quickName -- looked up once
-- Is this buff Quick Shots? By its Classic spell number, its name, or (for a
-- new Forever version) "quick shot" anywhere in the name.
local function IsQuickShots(d)
	local id, name = d.spellId, d.name
	if not IsSecret(id) and id then
		for i = 1, #QUICK_SHOTS_IDS do if id == QUICK_SHOTS_IDS[i] then return true end end
	end
	if not IsSecret(name) and type(name) == "string" then
		quickName = quickName or YaHT.GetSpellName(QUICK_SHOTS_IDS[1]) or "Quick Shots"
		if name == quickName then return true end
		if name:lower():find("quick shot", 1, true) then return true end
	end
	return false
end

local quickFoundAs -- what the buff looked like when found (for the debug log)
local function ReadQuickShots()
	if not C_UnitAuras then return nil end
	local data, hidden = nil, false
	local function take(ok, d)
		if not ok or IsSecret(d) then hidden = true return false end
		if d then data = d return true end
		return false
	end
	-- 1. look through every buff you have
	if C_UnitAuras.GetAuraDataByIndex then
		for i = 1, 40 do
			local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
			if not ok or IsSecret(d) then hidden = true break end
			if not d then break end
			if IsQuickShots(d) then data = d break end
			if IsSecret(d.spellId) and IsSecret(d.name) then hidden = true end
		end
	end
	-- 2. ask for it directly, by spell number, then by name
	if not data and C_UnitAuras.GetPlayerAuraBySpellID then
		for i = 1, #QUICK_SHOTS_IDS do
			if take(pcall(C_UnitAuras.GetPlayerAuraBySpellID, QUICK_SHOTS_IDS[i])) then break end
		end
	end
	if not data and C_UnitAuras.GetAuraDataBySpellName then
		-- in case Forever's buff has a new spell ID: look it up by name
		quickName = quickName or YaHT.GetSpellName(QUICK_SHOTS_IDS[1]) or "Quick Shots"
		take(pcall(C_UnitAuras.GetAuraDataBySpellName, "player", quickName, "HELPFUL"))
	end
	if data then
		quickFoundAs = string.format("%s, spell %s", tostring(not IsSecret(data.name) and data.name or "?"),
			tostring(not IsSecret(data.spellId) and data.spellId or "?"))
		local expires, length = Readable(data.expirationTime), Readable(data.duration)
		local icon = data.icon
		if IsSecret(icon) then icon = nil end
		local startedAt = (expires and length and length > 0) and (expires - length) or nil
		return true, startedAt, (length and length > 0) and length or nil, icon
	end
	if hidden then return nil end
	return false
end

local quickWatch
local quickHiddenSaid = false

-- Quick Shots from your shot speed. In combat the game hides your own buffs
-- from addons (Midnight rules), but not the time between Auto Shots, and
-- Quick Shots makes it 30% faster: a swing at ~77% of your normal time.
-- Rapid Fire (40%) and Berserking are cast spells, so they're recognised
-- and not mistaken for it.
local QS_LENGTH = 12
local QS_RATIO = 1 / 1.3 -- swing time with Quick Shots, relative to normal
local RF_RATIO = 1 / 1.4 -- ... with Rapid Fire
local HASTE_SPELLS = {[3045] = "RAPID", [20554] = "OTHER", [26296] = "OTHER", [26297] = "OTHER"} -- Rapid Fire, Berserking
local HASTE_LENGTH = {RAPID = 15, OTHER = 15} -- Berserking lasts 15s in Forever
local speed = {base = nil, lastShot = nil, fast = false, fastStart = nil, rapidUntil = 0, otherUntil = 0}
YaHT.quickSpeed = speed

local QUICK_MIN, QUICK_MAX = 0.60, 0.86 -- a speed-up this big (and not Rapid Fire) counts as Quick Shots

local function OnRangedSwing(duration)
	local now = GetTime()
	local previous = speed.lastShot
	speed.lastShot = now
	if type(duration) ~= "number" or duration <= 0 then return end
	local base = speed.base
	if not base then speed.base = duration return end
	-- Two measurements: the time the game gives for the next shot, and the
	-- real time since the last one. Only a speed-up can make shots come early
	-- (moving and casting only make them late), so long gaps are ignored.
	local r = duration / base
	local gap = previous and (now - previous) or nil
	local rGap = (gap and gap < base * 1.5) and gap / base or nil
	-- Once the game's number has shown a speed-up, it's trusted on its own
	-- (exact, no lag); until then the real gap between shots is used too.
	if r >= QUICK_MIN and r <= QUICK_MAX then speed.durationWorks = true end
	local fastest = r
	if not speed.durationWorks and rGap and rGap < r then fastest = rGap end
	if now < speed.otherUntil then return end -- an unknown speed-up (Berserking): don't guess
	local rapid = now < speed.rapidUntil
	local rel = rapid and fastest / RF_RATIO or fastest -- take Rapid Fire's part out
	local quickNow = rel >= QUICK_MIN and rel <= QUICK_MAX
	-- a Rapid Fire YaHT didn't see cast (exactly 40%) isn't Quick Shots
	if not rapid and math.abs(fastest - RF_RATIO) < 0.02 then quickNow = false end
	if r >= 0.95 and r <= 1.08 and (not rGap or rGap > 0.92) then
		speed.base = base * 0.7 + duration * 0.3 -- normal speed: keep learning it (gear changes)
	end
	if quickNow then
		-- a fast shot after the 12 seconds ran out means it procced again
		if not speed.fast or (speed.fastStart and now - speed.fastStart > QS_LENGTH) then
			speed.fast = true
			speed.fastStart = previous or now -- it procced on the shot before this one
		end
		speed.lastQuick = now
	elseif rel >= 0.9 then
		speed.fast = false
	end
	if YaHT.debug and fastest < 0.95 then
		YaHT:Print(string.format("Quick Shots check: next shot %.3fs (%.0f%%), real gap %s, normal %.3fs%s -> %s",
			duration, r * 100, rGap and string.format("%.3fs (%.0f%%)", gap, rGap * 100) or "-", base,
			rapid and ", Rapid Fire up" or "", quickNow and "Quick Shots" or "not Quick Shots"))
	end
end

local function OnHasteCast(spellID)
	local kind = HASTE_SPELLS[spellID]
	if not kind then return end
	local untilT = GetTime() + HASTE_LENGTH[kind]
	if kind == "RAPID" then speed.rapidUntil = untilT else speed.otherUntil = untilT end
end

local function CheckQuickShots()
	local p = YaHT.db.profile
	local f = quick.frame
	if not p.quickshots or not p.lock then quick:End() return end
	local now = GetTime()
	local active, startedAt, length, icon = ReadQuickShots()
	local source = "buff"
	if active == nil and YaHT.debug and not quickHiddenSaid then
		quickHiddenSaid = true
		YaHT:Print("Quick Shots: the game hides your buffs right now, following your shot speed instead")
	end
	if not active then
		-- the buff can't be seen: go by shot speed
		if speed.fast and speed.fastStart and now - speed.fastStart < QS_LENGTH then
			active, startedAt, length, icon, source = true, speed.fastStart, QS_LENGTH, nil, "shot speed"
		elseif speed.fast then
			speed.fast = false -- its 12 seconds are over (and no new fast shot since)
		end
	end
	if active then
		if not f.proc then
			quick:Start(false, startedAt, length, icon)
			if YaHT.debug then
				YaHT:Print(string.format("Quick Shots on, from %s [%s] (%s)", source, source == "buff" and (quickFoundAs or "?") or "",
					length and string.format("%.1fs of %.0fs left", f.procStart + length - now, length) or "time hidden, assuming 12s"))
			end
		elseif startedAt and math.abs(startedAt - f.procStart) > 0.2 then
			f.procStart, f.window = startedAt, length or QS_LENGTH -- refreshed by a new proc
			if YaHT.debug then YaHT:Print("Quick Shots refreshed") end
		end
	elseif quick:End() and YaHT.debug then
		YaHT:Print(string.format("Quick Shots off after %.1fs", now - f.procStart))
	end
end

---------------------------------------------------------------------------
-- Rapid Fire and Elune's Light (the Night Elf active on Forever): buffs you
-- cast yourself. The game shows your casts even in combat, so these show the
-- moment you press them and are timed from the cast.
---------------------------------------------------------------------------
-- (small helpers of its own: the aspect section's come later in the file)
local function Open(v) if IsSecret(v) then return nil end return v end
local function SpellIcon(id)
	local get = C_Spell and C_Spell.GetSpellTexture
	if not get then return nil end
	local ok, t = pcall(get, id)
	if ok and t and not IsSecret(t) then return t end
end
local RAPID_FIRE_ID = 3045
local CAST_BUFF_LENGTH = 15
-- Racial actives of the races that can be Hunters in Forever (Human, Dwarf,
-- Night Elf, Orc, Tauren, Troll, Skyborne) that give you a buff worth timing
-- (Forever reworked several
-- and added new ones). Matched by Classic spell number or by name; seconds
-- are the known length, or nil = learned from the buff the first time it can
-- be read (out of combat), and remembered.
local RACIALS = {
	{name = "Elune's Light", length = 15},                        -- Night Elf (new in Forever)
	{name = "Blood Fury", ids = {20572, 23234}, length = 15},     -- Orc
	{name = "Berserking", ids = {20554, 26296, 26297}, length = 15}, -- Troll (15s in Forever)
	{name = "Stoneform", ids = {20594}, length = 8},             -- Dwarf
	{name = "Perception", ids = {20600}, length = 20},           -- Human
	{name = "Plainsrunning"},                                    -- Tauren (new in Forever)
	{name = "Skysight"},                                         -- Skyborne (new in Forever)
}
local RACIAL_GUESS = 10 -- seconds shown until a new racial's real length is learned
local rapid = NewIcon({
	key = "rapidfire", frameName = "YaHTRapidFireFrame", label = "RapidFire",
	spellID = RAPID_FIRE_ID, fallbackIcon = "Interface\\Icons\\Ability_Hunter_RunningShot", window = CAST_BUFF_LENGTH,
})
local racial = NewIcon({
	key = "racial", frameName = "YaHTRacialFrame", label = "Racial",
	spellID = nil, fallbackIcon = "Interface\\Icons\\Spell_Holy_ElunesGrace", window = CAST_BUFF_LENGTH,
})

-- which racial a cast is (its table entry), from its spell number or name
local racialByID, racialByName
local function WhichRacial(spellID, name)
	if not racialByID then
		racialByID, racialByName = {}, {}
		for _, r in ipairs(RACIALS) do
			racialByName[r.name] = r
			for _, id in ipairs(r.ids or {}) do
				racialByID[id] = r
				local localName = YaHT.GetSpellName(id) -- the name in your game's language
				if localName and not IsSecret(localName) then racialByName[localName] = r end
			end
		end
	end
	return racialByID[spellID] or (name and racialByName[name])
end

-- its length: known, learned earlier, or a guess for now
local function RacialLength(r)
	local learned = YaHT.db.global.racialLength
	return r.length or (learned and learned[r.name]) or RACIAL_GUESS
end

-- the buff can be read (out of combat): take its real length and remember it
local function LearnRacialLength(r, spellName)
	if r.length or not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return end
	local ok, d = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", spellName, "HELPFUL")
	if not ok or IsSecret(d) or type(d) ~= "table" then return end
	local length = Open(d.duration)
	if type(length) ~= "number" or length <= 0 then return end
	YaHT.db.global.racialLength = YaHT.db.global.racialLength or {}
	if YaHT.db.global.racialLength[r.name] ~= length then
		YaHT.db.global.racialLength[r.name] = length
		if YaHT.debug then YaHT:Print(string.format("%s lasts %.0fs (learned)", r.name, length)) end
	end
	return length
end

local castWatch
local function OnCast(spellID)
	spellID = Open(spellID)
	if not spellID then return end
	local p = YaHT.db.profile
	if not p.lock then return end
	local name = YaHT.GetSpellName(spellID)
	if spellID == RAPID_FIRE_ID or (name and name == YaHT.GetSpellName(RAPID_FIRE_ID)) then
		if p.rapidfire then
			rapid:Start(false, GetTime(), CAST_BUFF_LENGTH)
			if YaHT.debug then YaHT:Print("Rapid Fire on (15s)") end
		end
		return
	end
	local r = WhichRacial(spellID, name)
	if r and p.racial then
		local length = RacialLength(r)
		racial:Start(false, GetTime(), length, SpellIcon(spellID))
		racial.current = {r = r, spellName = name or r.name, learning = not r.length}
		if YaHT.debug then YaHT:Print(string.format("%s on (%.0fs)", r.name, length)) end
	end
end

-- ends each one when its time is up (and learns a new racial's real length)
local function CheckCastBuffs()
	local now = GetTime()
	local cur = racial.current
	if racial.frame.proc and cur and cur.learning then
		local length = LearnRacialLength(cur.r, cur.spellName)
		if length then
			racial.frame.window = length
			cur.learning = false
		end
	end
	for _, icon in ipairs({rapid, racial}) do
		local f = icon.frame
		if f.proc and now - f.procStart >= (f.window or CAST_BUFF_LENGTH) then
			icon:End()
			if YaHT.debug then
				YaHT:Print((icon == racial and cur and cur.r.name or "Rapid Fire") .. " off")
			end
		end
	end
end

---------------------------------------------------------------------------
-- Aspect badge: your current aspect as a small icon next to the bar. Quiet
-- while it's fine; red and pulsing when it's risky (Cheetah or Pack in a
-- fight: one hit dazes you; or no aspect at all); optionally a yellow hint
-- for the wrong one for what you're doing (Hawk in melee, Monkey at range).
---------------------------------------------------------------------------
local ASPECTS = { -- every aspect a Forever hunter may have, with all their Classic ranks
	{"HAWK", 13165, 14318, 14319, 14320, 14321, 14322, 25296}, {"MONKEY", 13163}, {"CHEETAH", 5118},
	{"PACK", 13159}, {"BEAST", 13161}, {"WILD", 20043, 20190}, {"VIPER", 34074}, {"DRAGONHAWK", 61846, 61847},
}
-- last resort for unknown spell numbers: the English word in the buff's name
-- (Dragonhawk before Hawk, since "Dragonhawk" contains "hawk")
local ASPECT_WORDS = {{"dragonhawk", "DRAGONHAWK"}, {"hawk", "HAWK"}, {"monkey", "MONKEY"}, {"cheetah", "CHEETAH"},
	{"pack", "PACK"}, {"beast", "BEAST"}, {"wild", "WILD"}, {"viper", "VIPER"}}
local NO_ASPECT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local LEVEL_COLOR = {OK = {0.16, 0.14, 0.10}, HINT = {1, 0.8, 0.16}, DANGER = {1, 0.22, 0.16}}
local ASPECT_CHECK = 0.1 -- how often the badge re-judges while it's up
local NONE_GRACE = 0.5   -- "no aspect" must last this long before it warns
local MAX_BUFFS = 40

local aspectByID, aspectByName, aspectNames -- built once the game knows the names
local function BuildAspectLookup()
	if aspectByName and next(aspectByName) then return end
	aspectByID, aspectByName, aspectNames = {}, {}, {}
	for _, a in ipairs(ASPECTS) do
		for i = 2, #a do
			aspectByID[a[i]] = a[1]
			local name = YaHT.GetSpellName(a[i])
			if name and not IsSecret(name) and not aspectByName[name] then
				aspectByName[name] = a[1]
				aspectNames[#aspectNames + 1] = name
			end
		end
	end
end

local function Plain(v) if IsSecret(v) then return nil end return v end

-- which aspect a buff (or stance) is, from its spell number or its name
local function WhichAspect(spellID, name)
	spellID, name = Plain(spellID), Plain(name)
	if spellID and aspectByID[spellID] then return aspectByID[spellID] end
	if type(name) == "string" then
		if aspectByName[name] then return aspectByName[name] end
		local low = name:lower()
		if low:find("aspect", 1, true) then
			for _, w in ipairs(ASPECT_WORDS) do
				if low:find(w[1], 1, true) then return w[2] end
			end
		end
	end
	return nil
end

local function IconFor(icon, spellID, name)
	icon = Plain(icon)
	if icon then return icon end
	local get = C_Spell and C_Spell.GetSpellTexture
	if not get then return nil end
	local ok, t = pcall(get, Plain(spellID) or Plain(name))
	if ok and t and not IsSecret(t) then return t end
	return nil
end

-- For the debug log when nothing matched: what the game did show us.
local function DescribeBuffs()
	local seen = {}
	local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if byIndex then
		for i = 1, MAX_BUFFS do
			local ok, d = pcall(byIndex, "player", i, "HELPFUL")
			if not ok or not d then break end
			if IsSecret(d) then seen[#seen + 1] = "(hidden)" break end
			seen[#seen + 1] = string.format("%s(%s)", tostring(Plain(d.name) or "?"), tostring(Plain(d.spellId) or "?"))
		end
	end
	local stances = {}
	if GetNumShapeshiftForms and GetShapeshiftFormInfo then
		local ok, n = pcall(GetNumShapeshiftForms)
		if ok and Plain(n) then
			for i = 1, n do
				local ok2, _, active, _, spellID = pcall(GetShapeshiftFormInfo, i)
				if ok2 then stances[#stances + 1] = string.format("%s%s", tostring(Plain(spellID) or "?"), Plain(active) and "*" or "") end
			end
		end
	end
	return string.format("buffs: %s | stances: %s", #seen > 0 and table.concat(seen, ", ") or "none",
		#stances > 0 and table.concat(stances, ", ") or "none")
end

-- The aspect you're in ("HAWK", ..., "NONE") and its icon, or nil if hidden.
-- Looks three ways, since Forever may differ from Classic: through all your
-- buffs, on the stance bar, and by each aspect's name.
local function ReadAspect()
	BuildAspectLookup()
	local hidden = false
	-- 1. every buff you have
	local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if byIndex then
		for i = 1, MAX_BUFFS do
			local ok, d = pcall(byIndex, "player", i, "HELPFUL")
			if not ok or IsSecret(d) then hidden = true break end
			if not d then break end
			local key = WhichAspect(d.spellId, d.name)
			if key then return key, IconFor(d.icon, d.spellId, d.name) end
			if IsSecret(d.spellId) and IsSecret(d.name) then hidden = true end
		end
	end
	-- 2. the stance bar
	if GetNumShapeshiftForms and GetShapeshiftFormInfo then
		local ok, n = pcall(GetNumShapeshiftForms)
		if ok and Plain(n) then
			for i = 1, n do
				local ok2, icon, active, _, spellID = pcall(GetShapeshiftFormInfo, i)
				if ok2 and Plain(active) then
					local name = Plain(spellID) and YaHT.GetSpellName(spellID)
					local key = WhichAspect(spellID, name)
					if key then return key, IconFor(icon, spellID, name) end
				end
			end
		end
	end
	-- 3. each aspect by name
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
	if get then
		for _, name in ipairs(aspectNames) do
			local ok, d = pcall(get, "player", name, "HELPFUL")
			if not ok or IsSecret(d) then
				hidden = true
			elseif d then
				return aspectByName[name], IconFor(d.icon, d.spellId, name)
			end
		end
	elseif not byIndex then
		return nil
	end
	if hidden then return nil end
	return "NONE"
end

local badge, aspectWatch
local ASPECT_NAMES = {HAWK = "Hawk", MONKEY = "Monkey", CHEETAH = "Cheetah", PACK = "Pack", BEAST = "Beast",
	WILD = "Wild", VIPER = "Viper", DRAGONHAWK = "Dragonhawk", NONE = "none"}

-- Should the badge show, and how: "OK", "HINT" or "DANGER" (nil = hidden)
local function AspectLevel(p)
	if not p.aspect then return nil end
	if not p.lock then return "OK" end -- unlocked: preview it
	if badge.previewUntil then
		if GetTime() < badge.previewUntil then return "DANGER" end -- "Preview all alerts": show the warning look
		badge.previewUntil = nil
	end
	local fighting = aspectWatch.inCombat or (InCombatLockdown and InCombatLockdown())
	local shooting = YaHT.mainFrame and YaHT.mainFrame.shooting
	local engaged = fighting or shooting
	local a = badge.aspect
	if a ~= "NONE" then badge.noneSince = nil end
	if a == nil then return nil end -- the game hides it: show nothing rather than guess
	if a == "NONE" then
		-- no aspect at all: red in a fight; out of one, a yellow reminder whenever the
		-- badge would be showing (while shooting, or set to show always)
		if not p.aspectwarnnone then return nil end
		local warn = fighting and "DANGER" or ((shooting or p.aspectwhen == "ALWAYS") and "HINT" or nil)
		if warn then
			-- Switching aspects can leave you without one for an instant (seen in
			-- game as a warning that came and went within a second): it only
			-- counts once it has lasted. Until then the badge just shows, quietly.
			local now = GetTime()
			badge.noneSince = badge.noneSince or now
			if now - badge.noneSince < NONE_GRACE then return "OK" end
		end
		return warn
	end
	local speed = a == "CHEETAH" or a == "PACK"
	-- Cheetah and Pack show any time, so you don't forget you're in them
	if p.aspectwhen ~= "ALWAYS" and not engaged and not (speed and p.aspectspeedalways) then return nil end
	if fighting and p.aspectwarnspeed and speed then return "DANGER" end
	if p.aspecthint and engaged then
		local pos = YaHT.meleeFrame and YaHT.meleeFrame.position
		if a == "HAWK" and pos == "MELEE" then return "HINT" end
		if a == "MONKEY" and shooting and pos and pos ~= "MELEE" then return "HINT" end
	end
	return "OK"
end

local function SetBadgeIcon()
	local tex = badge.iconTex
	if badge.aspect == nil then
		-- not known yet (or hidden): the preview shows Aspect of the Hawk's icon
		tex = IconFor(nil, 13165, YaHT.GetSpellName(13165))
	end
	if badge.aspect == "NONE" or not tex then tex = NO_ASPECT_ICON end
	if badge.drawnTex ~= tex then
		badge.drawnTex = tex
		badge.icon:SetTexture(tex)
	end
end

local function BadgeUpdate(self, elapsed)
	local p = YaHT.db.profile
	self.judge = (self.judge or 0) - elapsed
	if self.judge <= 0 then
		self.judge = ASPECT_CHECK
		local level = AspectLevel(p)
		if level == "DANGER" and self.level ~= "DANGER" and p.aspectsound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
			pcall(PlaySound, SOUNDKIT.RAID_WARNING, "Master")
		end
		self.level = level
		-- the saved record notes each real warning as it starts (not previews, and not the
		-- Hawk / Monkey hints, which come and go all fight long)
		if p.lock and not self.previewUntil then
			local warn
			if level == "DANGER" then
				warn = "red warning, aspect " .. (ASPECT_NAMES[self.aspect] or "unknown")
			elseif level == "HINT" and self.aspect == "NONE" then
				warn = "yellow reminder: no aspect"
			end
			if warn ~= self.recWarn then
				self.recWarn = warn
				if warn and YaHT.Record then YaHT:Record("aspect", warn) end
			end
		end
	end
	local level = self.level
	local want = level and 1 or 0
	local a = self.fade or 0
	if a < want then
		a = math.min(want, a + elapsed / FADE_IN)
	elseif a > want then
		a = math.max(want, a - elapsed / FADE_OUT)
	end
	self.fade = a
	if a <= 0 and want <= 0 then
		self:Hide() -- wakes again on the next aspect / combat / Auto Shot change
		return
	end
	local shown = level or self.lastLevel or "OK"
	self.lastLevel = shown
	local c = LEVEL_COLOR[shown]
	self.rim:SetVertexColor(c[1], c[2], c[3])
	if shown == "OK" then
		self:SetAlpha(a * p.aspectalpha)
		self.icon:SetAlpha(1)
		self.halo:Hide()
	else
		-- warnings are always full strength, and pulse
		self.phase = (self.phase or 0) + elapsed
		local pulse = 0.5 + 0.5 * math.sin(TWO_PI * self.phase / 0.8)
		self:SetAlpha(a)
		self.icon:SetAlpha(0.65 + 0.35 * pulse)
		self.halo:SetVertexColor(c[1], c[2], c[3])
		self.halo:SetAlpha(0.35 + 0.55 * pulse)
		self.halo:Show()
	end
end

local function CheckAspect()
	local key, icon = ReadAspect()
	if key == nil then
		-- hidden (in combat): keep the aspect we last saw; casting one is still noticed
		if not badge.hidden and YaHT.debug then
			YaHT:Print("Aspect: the game hides your buffs right now, keeping " .. (ASPECT_NAMES[badge.aspect] or "unknown"))
		end
		badge.hidden = true
	else
		badge.hidden = false
		if key ~= badge.aspect and YaHT.debug then
			YaHT:Print("Aspect: " .. ASPECT_NAMES[key] .. (key == "NONE" and (" (" .. DescribeBuffs() .. ")") or ""))
		end
		badge.aspect, badge.iconTex = key, icon
	end
	SetBadgeIcon()
	badge.judge = 0 -- judge right away
	if AspectLevel(YaHT.db.profile) then badge:Show() end
end

local function ApplyAspect()
	if not badge then return end
	local p = YaHT.db.profile
	badge:SetScale(p.scale)
	local size = p.aspectsize
	badge:SetSize(size + 2, size + 2)
	PlaceAroundBar(badge, p, "aspect")
	badge.rim:SetAllPoints(badge)
	badge.icon:SetSize(size, size)
	local pad = math.max(6, size * 0.45)
	badge.halo:SetSize(size + 2 * pad, size + 2 * pad)
	badge.judge = 0
	if not p.aspect then
		badge.fade = 0 badge:SetAlpha(0) badge:Hide()
	else
		badge:Show() -- judges itself on the next frame and hides if it isn't needed
	end
end

local function CreateBadge()
	local f = CreateFrame("Frame", "YaHTAspectFrame", UIParent)
	f:SetFrameStrata("MEDIUM")
	MakeDraggable(f, "aspect")
	f.halo = f:CreateTexture(nil, "BACKGROUND", nil, -1)
	f.halo:SetTexture(GLOW_TEX)
	f.halo:SetBlendMode("ADD")
	f.halo:SetPoint("CENTER", f, "CENTER")
	f.halo:Hide()
	f.rim = f:CreateTexture(nil, "BORDER")
	f.rim:SetTexture(WHITE)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.icon:SetPoint("CENTER", f, "CENTER")
	f.fade = 0
	f:SetAlpha(0)
	f:Hide()
	f:SetScript("OnUpdate", function(self, elapsed)
		local ok, err = pcall(BadgeUpdate, self, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError("AspectUpdate", err) end
	end)
	return f
end

-- /yaht buffs: every buff exactly as the game shows it to addons, and what
-- YaHT makes of it. Type it while Quick Shots (or an aspect) is up.
function YaHT:ReportBuffs()
	self:Print(DescribeBuffs())
	local active, _, length = ReadQuickShots()
	if active == nil then
		self:Print("Quick Shots: the game hides your buffs from addons right now")
	elseif active then
		self:Print(string.format("Quick Shots: found [%s]%s", quickFoundAs or "?", length and string.format(", lasts %.0fs", length) or ""))
	else
		self:Print("Quick Shots: not found")
	end
	local key = ReadAspect()
	self:Print("Aspect: " .. (key and ASPECT_NAMES[key] or "hidden by the game"))
end

-- "Preview all alerts" (Alerts page): every alert shows for a few seconds.
local PREVIEW_TIME = 6
function YaHT:PreviewAlerts()
	local now = GetTime()
	local p = self.db.profile
	for _, icon in ipairs({mongoose, quick, rapid, racial}) do
		if p[icon.key] then
			icon:Start(false, now, PREVIEW_TIME)
			icon.frame.previewUntil = now + PREVIEW_TIME
		end
	end
	if p.aspect and badge then
		badge.previewUntil = now + PREVIEW_TIME
		badge.judge = 0
		badge:Show()
	end
	if self.TestFeignAlert then self:TestFeignAlert() end
	if self.PreviewRange then self:PreviewRange(PREVIEW_TIME) end
	if self.PreviewPet then self:PreviewPet(PREVIEW_TIME) end
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
function YaHT:ApplyProcSettings()
	mongoose:Apply()
	quick:Apply()
	rapid:Apply()
	racial:Apply()
	ApplyAspect()
end

function YaHT:InitProcs()
	-- Earlier 1.2 test builds had a separate look per proc icon: carry it over
	-- to the shared look (from Mongoose Bite, the first one), then drop the old
	-- per-icon settings (and the Elune's Light ones, now the racial alert).
	local p = self.db.profile
	for _, suffix in ipairs({"size", "alpha", "glow", "pulse", "sound"}) do
		for _, key in ipairs({"mongoose", "quickshots", "rapidfire", "racial", "elune"}) do
			local old = rawget(p, key .. suffix)
			if old ~= nil then
				-- (defaults are filled in at login, so "untouched" means "still the default")
				if key == "mongoose" and p["proc" .. suffix] == self.defaults.profile["proc" .. suffix] then p["proc" .. suffix] = old end
				p[key .. suffix] = nil
			end
		end
	end
	for _, k in ipairs({"elune", "elunepos", "eluneglowcolor", "elunepoint", "elunerelpoint", "elunex", "eluney"}) do
		if rawget(p, k) ~= nil then p[k] = nil end
	end

	self.mongooseFrame = mongoose:Create()
	self.quickShotsFrame = quick:Create()

	mongooseWatch = NewWatcher("Mongoose", 0.1,
		{"SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_USABLE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"},
		CheckMongoose,
		function() return Fighting(mongooseWatch) or mongoose.frame.proc end,
		function(event)
			if event == "PLAYER_REGEN_DISABLED" then mongooseWatch.inCombat = true
			elseif event == "PLAYER_REGEN_ENABLED" then mongooseWatch.inCombat = false end
		end)
	self.mongooseWatch = mongooseWatch

	-- buffs change rarely, so this one wakes on UNIT_AURA and only keeps
	-- polling while Quick Shots is up (to catch its end)
	quickWatch = NewWatcher("QuickShots", 0.2,
		{{"UNIT_AURA", "player"}, "PLAYER_REGEN_DISABLED", "PLAYER_SWING", {"UNIT_SPELLCAST_SUCCEEDED", "player"}},
		CheckQuickShots,
		function() return quick.frame.proc or speed.fast end,
		function(event, ...)
			if event == "PLAYER_REGEN_DISABLED" then
				quickHiddenSaid = false
			elseif event == "PLAYER_SWING" then
				local duration, swingType = ...
				if IsSecret(duration) or IsSecret(swingType) then return end
				local ranged = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.Ranged or 2
				if swingType == ranged then OnRangedSwing(duration) end
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				local unit, _, spellID = ...
				if unit == "player" and not IsSecret(spellID) then OnHasteCast(spellID) end
			end
		end,
		true)
	self.quickShotsWatch = quickWatch

	-- Rapid Fire / your racial: start on your cast, end when their time is up
	self.rapidFireFrame = rapid:Create()
	self.racialFrame = racial:Create()
	-- show your own race's icon (for the preview), if one of yours is in your spellbook
	for _, r in ipairs(RACIALS) do
		local get = C_Spell and C_Spell.GetSpellInfo
		local ok, info = false, nil
		if get then ok, info = pcall(get, r.name) end
		if ok and type(info) == "table" and not IsSecret(info) and Open(info.iconID) then
			racial.frame.icon:SetTexture(info.iconID)
			break
		end
	end
	castWatch = NewWatcher("CastBuffs", 0.2,
		{{"UNIT_SPELLCAST_SUCCEEDED", "player"}},
		CheckCastBuffs,
		function() return rapid.frame.proc or racial.frame.proc end,
		function(event, unit, _, spellID) if unit == "player" then OnCast(spellID) end end)
	self.castBuffWatch = castWatch

	-- aspect badge: re-reads your aspect only when your buffs change, and
	-- re-judges when a fight or Auto Shot starts or stops
	badge = CreateBadge()
	self.aspectFrame = badge
	aspectWatch = NewWatcher("Aspect", 1,
		{{"UNIT_AURA", "player"}, "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
			"START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTERING_WORLD", {"UNIT_SPELLCAST_SUCCEEDED", "player"}},
		CheckAspect,
		function() return false end, -- nothing to poll: events are enough
		function(event, ...)
			if event == "PLAYER_REGEN_DISABLED" then aspectWatch.inCombat = true
			elseif event == "PLAYER_REGEN_ENABLED" then aspectWatch.inCombat = false
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				-- you cast an aspect: the game shows that even when it hides buffs
				local unit, _, spellID = ...
				spellID = Plain(spellID)
				if unit ~= "player" or not spellID then return end
				BuildAspectLookup()
				local name = YaHT.GetSpellName(spellID)
				local key = WhichAspect(spellID, name)
				if key then
					if YaHT.debug and key ~= badge.aspect then YaHT:Print("Aspect cast: " .. ASPECT_NAMES[key]) end
					badge.aspect, badge.iconTex = key, IconFor(nil, spellID, name)
				end
			end
		end,
		true)
	self.aspectWatch = aspectWatch

	self:ApplyProcSettings()
end
