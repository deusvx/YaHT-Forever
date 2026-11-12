-- YaHT pet alerts: small warning text you can put anywhere on the screen.
--   PET DEAD / NO PET     in a fight, when your pet is dead or not out
--   PET NOT ATTACKING     when you've been shooting a few seconds and it attacks nothing
--   PET LOW               when its health is under a share you choose
--
-- What Forever shows addons about the pet (measured in game, 2026-11-11):
--   * readable, also in a fight: whether it exists, is dead, has a target, is attacking
--   * hidden, in and out of a fight: its health (the maximum is readable)
-- A hidden value can't be read or compared, but the game can still draw with
-- it: UnitHealthPercent(pet, true, curve) hands back "1 below the threshold,
-- 0 above" as another hidden value, and SetAlpha takes that. So PET LOW is a
-- line of text whose visibility the game sets itself; YaHT never learns
-- whether it is showing (which is why that warning has no sound).
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end
local function Plain(v) if IsSecret(v) then return nil end return v end

local POLL = 0.25        -- how often things are re-judged while you fight or shoot
local IDLE_DELAY = 3     -- seconds of shooting without the pet attacking before the warning
local GONE_GRACE = 2     -- a pet must be missing this long in a fight before NO PET (it may just be on its way)
local LOW_EDGE = 0.02    -- the low warning fades in over this much health around the threshold
local LINE_GAP = 2
local PULSE_LOW, PULSE_TIME = 0.45, 0.5
local RED = {1, 0.27, 0.2}
local YELLOW = {1, 0.8, 0.16}
local STATE_TEXT = {DEAD = "PET DEAD", NONE = "NO PET", IDLE = "PET NOT ATTACKING"}
local STATE_COLOR = {DEAD = RED, NONE = RED, IDLE = YELLOW}
local STATE_LOG = {DEAD = "dead", NONE = "not out", IDLE = "not attacking"}

local alert, watch
local lowCurve, lowCurveAt   -- the curve for the low warning, and the threshold it was built for

---------------------------------------------------------------------------
-- What the game tells us
---------------------------------------------------------------------------
-- true / false, or nil when the game hides the answer or has no such function
local function Ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok or IsSecret(v) then return nil end
	return v and true or false
end

-- Is there a pet, and is it dead? (nil = hidden)
local function PetState()
	local exists = Ask(UnitExists, "pet")
	if not exists then return exists, nil end
	return true, Ask(UnitIsDead, "pet")
end

-- Is the pet attacking something? (nil = hidden)
local function PetAttacking()
	local attacking = Ask(IsPetAttackActive)
	if attacking == nil then attacking = Ask(UnitExists, "pettarget") end
	return attacking
end

-- Dead, a ghost, mounted or on a flight path: no pet is expected at your side
local function PlayerAway()
	return Ask(UnitIsDeadOrGhost, "player") or Ask(IsMounted) or Ask(UnitOnTaxi, "player") or false
end

---------------------------------------------------------------------------
-- The low warning: drawn by the game from the hidden health
---------------------------------------------------------------------------
-- 1 below the threshold, 0 above, with a short ramp between
local function BuildLowCurve(threshold)
	if lowCurve and lowCurveAt == threshold then return lowCurve end
	lowCurve, lowCurveAt = nil, threshold
	if not (C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function") then return nil end
	local ok, curve = pcall(C_CurveUtil.CreateCurve)
	if not ok or not curve then return nil end
	local t = threshold / 100
	for _, pt in ipairs({{0, 1}, {math.max(0, t - LOW_EDGE), 1}, {math.min(1, t + LOW_EDGE), 0}, {1, 0}}) do
		if not pcall(curve.AddPoint, curve, pt[1], pt[2]) then return nil end
	end
	lowCurve = curve
	return curve
end

-- Can this game draw the low warning at all?
local function LowPossible()
	return lowCurve ~= nil and type(UnitHealthPercent) == "function"
end

-- Hands the pet's health to the low line. preview: just show it.
local function DrawLow(preview)
	local holder = alert.low
	if preview then
		holder:SetAlpha(1)
		return
	end
	if LowPossible() then
		local ok, v = pcall(UnitHealthPercent, "pet", true, lowCurve)
		if ok and (IsSecret(v) or type(v) == "number") and pcall(holder.SetAlpha, holder, v) then return end
	end
	holder:SetAlpha(0)
end

---------------------------------------------------------------------------
-- Judging
---------------------------------------------------------------------------
local function Awake()
	if alert.previewUntil then return true end
	if watch.inCombat or (InCombatLockdown and InCombatLockdown()) then return true end
	return YaHT.mainFrame and YaHT.mainFrame.shooting or false
end

-- Decides what shows: the first line (dead / no pet / not attacking) is
-- YaHT's call, the second (low) is switched on here and drawn by the game.
local function Judge()
	local p = YaHT.db.profile
	local now = GetTime()
	if alert.previewUntil and now >= alert.previewUntil then alert.previewUntil = nil end
	local preview = not p.lock or alert.previewUntil ~= nil
	local state, low = nil, false
	if not p.pet then
		watch.idleSince = nil
	elseif preview then
		state = (p.petdead and "DEAD") or (p.petidle and "IDLE") or nil
		low = p.petlow
	else
		local fighting = watch.inCombat or (InCombatLockdown and InCombatLockdown()) or false
		local shooting = YaHT.mainFrame and YaHT.mainFrame.shooting or false
		local exists, dead = PetState()
		local alive = exists and dead == false
		if alive then YaHT.db.char.petSeen = true end
		local missing = exists == false and fighting
		if not missing then watch.goneSince = nil end
		if PlayerAway() then
			watch.idleSince, watch.goneSince = nil, nil
		else
			if p.petdead and fighting then
				if exists and dead then
					state = "DEAD"
				elseif missing and YaHT.db.char.petSeen then
					watch.goneSince = watch.goneSince or now
					-- a dead pet's body going away needs no second look
					local wasGone = alert.stateReal and (alert.state == "DEAD" or alert.state == "NONE")
					if wasGone or now - watch.goneSince >= GONE_GRACE then state = "NONE" end
				end
			end
			if p.petidle and alive and shooting and PetAttacking() == false then
				watch.idleSince = watch.idleSince or now
				if now - watch.idleSince >= IDLE_DELAY then state = state or "IDLE" end
			else
				watch.idleSince = nil
			end
			low = p.petlow and alive and (fighting or shooting or p.petwhen == "ALWAYS")
		end
	end

	local changed = state ~= alert.state
	local was, wasReal = alert.state, alert.stateReal
	alert.stateReal = not preview
	if changed or alert.redraw then
		alert.state, alert.redraw = state, false
		if state then
			local c = STATE_COLOR[state]
			alert.text:SetText(L[STATE_TEXT[state]])
			alert.text:SetTextColor(c[1], c[2], c[3])
			alert.text:Show()
		else
			alert.text:Hide()
		end
		if changed and not preview and wasReal then
			if YaHT.debug then YaHT:Print("Pet: " .. (state and STATE_LOG[state] or "fine again")) end
			if YaHT.Record then
				local out, isDead = PetState()
				YaHT:Record("pet", string.format("%s | pet out %s, dead %s, attacking %s", state and STATE_LOG[state] or "fine again",
					tostring(out), tostring(isDead), tostring(PetAttacking())))
			end
			local gone = state == "DEAD" or state == "NONE"
			if gone and was ~= "DEAD" and was ~= "NONE" and p.petsound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
				pcall(PlaySound, SOUNDKIT.RAID_WARNING, "Master")
			end
		end
	end
	alert.low:SetShown(low and true or false)
	if low then DrawLow(preview) end
	alert.dragHint:SetShown(not p.lock and p.pet)
	alert:SetShown((state or low or (not p.lock and p.pet)) and true or false)
end

local function Step(self, elapsed)
	self.sum = self.sum + elapsed
	if not self.pending and self.sum < POLL then return end
	self.sum, self.pending = 0, false
	Judge()
	if not Awake() then self:Hide() end -- nothing to time: sleep until the next event
end

local function OnEvent(self, event, unit)
	if event == "PLAYER_REGEN_DISABLED" then
		self.inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		self.inCombat = false
	end
	self.pending = true -- look on the next frame (bursts of events become one look)
	self:Show()
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local function SetFont(fs, font, size)
	if not fs:SetFont(font, size, "OUTLINE") then fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
end

function YaHT:ApplyPetSettings()
	if not alert then return end
	local p = self.db.profile
	alert:ClearAllPoints()
	if p.petpoint then
		alert:SetPoint(p.petpoint, UIParent, p.petrelpoint, p.petx, p.pety)
	else
		alert:SetPoint("CENTER", UIParent, "CENTER", 0, 90)
	end
	local font = self:GetMedia("font", p.font) or STANDARD_TEXT_FONT
	local size = p.pettextsize
	SetFont(alert.text, font, size)
	SetFont(alert.lowText, font, size)
	alert.lowText:SetTextColor(RED[1], RED[2], RED[3])
	-- two lines: dead / no pet / not attacking on top, low under it
	local w, h = size * 14, size * 2 + LINE_GAP
	alert:SetSize(w, h)
	alert.low:SetSize(w, size)
	alert.low:ClearAllPoints()
	alert.low:SetPoint("TOP", alert, "TOP", 0, -(size + LINE_GAP))
	alert:EnableMouse(not p.lock and p.pet)
	BuildLowCurve(p.petlowat)
	if alert.pulse then
		if p.petpulse and p.pet then pcall(alert.pulse.Play, alert.pulse) else pcall(alert.pulse.Stop, alert.pulse) end
	end
	alert.redraw = true -- draw the first line again with the new look
	watch.pending = true
	watch:Show()
end

-- "Preview all alerts": the pet warnings show for a few seconds
function YaHT:PreviewPet(seconds)
	if not alert or not self.db.profile.pet then return end
	alert.previewUntil = GetTime() + seconds
	watch.pending = true
	watch:Show()
end

-- /yaht pet: what YaHT sees of your pet right now
function YaHT:ReportPet()
	if not alert then return end
	local exists, dead = PetState()
	self:Print(string.format("Pet: out %s | dead %s | attacking %s | low warning %s | shown: %s",
		tostring(exists), tostring(dead), tostring(PetAttacking()),
		LowPossible() and ("drawn by the game below " .. tostring(lowCurveAt) .. "%") or "not possible in this game",
		alert.state and STATE_LOG[alert.state] or "nothing"))
end

local function CreateAlert()
	local f = CreateFrame("Frame", "YaHTPetFrame", UIParent)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p = YaHT.db.profile
		local _
		p.petpoint, _, p.petrelpoint, p.petx, p.pety = self:GetPoint()
	end)
	local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	-- WoW refuses text on a font string without a font: set one first (Apply picks the real one)
	f.text = f:CreateFontString(nil, "OVERLAY")
	f.text:SetFont(font, 12, "OUTLINE")
	f.text:SetPoint("TOP", f, "TOP", 0, 0)
	f.text:Hide()
	-- the low line sits in its own frame: the game sets that frame's visibility
	f.low = CreateFrame("Frame", nil, f)
	f.lowText = f.low:CreateFontString(nil, "OVERLAY")
	f.lowText:SetFont(font, 12, "OUTLINE")
	f.lowText:SetPoint("CENTER", f.low, "CENTER", 0, 0)
	f.lowText:SetText(L["PET LOW"])
	f.low:SetAlpha(0)
	f.low:Hide()
	-- Its visibility is a hidden value, which the game can only use as it is: under a
	-- parent that is fading (the pulse) the line showed for a single frame each time
	-- the fade passed full strength (seen in a clip, pet at 4% health). So it never
	-- takes anyone else's fade, and the pulse runs on the first line only.
	if f.low.SetIgnoreParentAlpha then f.low:SetIgnoreParentAlpha(true) end
	-- shown only while unlocked, so you know what you're dragging
	f.dragHint = f:CreateFontString(nil, "OVERLAY")
	f.dragHint:SetPoint("TOP", f, "BOTTOM", 0, -2)
	f.dragHint:SetFont(font, 11, "OUTLINE")
	f.dragHint:SetTextColor(0.8, 0.8, 0.8)
	f.dragHint:SetText(L["Pet alerts (drag me)"])
	f.dragHint:Hide()
	-- A slow pulse run by the game itself (no work per frame), on the first line of
	-- text only: PET LOW can't pulse (see above) and stays steady.
	if f.text.CreateAnimationGroup then
		local ok, group = pcall(f.text.CreateAnimationGroup, f.text)
		if ok and group then
			local okA, a = pcall(group.CreateAnimation, group, "Alpha")
			if okA and a and pcall(function()
				a:SetFromAlpha(1)
				a:SetToAlpha(PULSE_LOW)
				a:SetDuration(PULSE_TIME)
				a:SetSmoothing("IN_OUT")
				group:SetLooping("BOUNCE")
			end) then
				f.pulse = group
				f.text.pulse = group
			end
		end
	end
	f.stateReal = true
	f:Hide()
	return f
end

function YaHT:InitPet()
	alert = CreateAlert()
	self.petFrame = alert
	watch = CreateFrame("Frame")
	self.petWatch = watch
	watch.sum, watch.pending = 0, false
	watch.inCombat = (InCombatLockdown and InCombatLockdown()) and true or false
	for _, e in ipairs({"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
		"START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PET_ATTACK_START", "PET_ATTACK_STOP"}) do
		pcall(watch.RegisterEvent, watch, e)
	end
	for _, e in ipairs({"UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FLAGS"}) do
		pcall(watch.RegisterUnitEvent, watch, e, "pet")
	end
	pcall(watch.RegisterUnitEvent, watch, "UNIT_PET", "player")
	watch:SetScript("OnEvent", function(self, event, ...)
		if not YaHT.db then return end
		local ok, err = pcall(OnEvent, self, event, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError("PetEvent", err) end
	end)
	watch:SetScript("OnUpdate", function(self, elapsed)
		local ok, err = pcall(Step, self, elapsed)
		if not ok and YaHT.ReportError then YaHT.ReportError("PetWatch", err) end
	end)
	self:ApplyPetSettings()
end
