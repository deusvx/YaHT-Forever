-- YaHT's minimap button.
--   left-click   opens (or closes) the options window
--   right-click  a quick menu: lock / unlock the bar, preview all alerts,
--                options, hide this button
--   drag         moves it around the minimap
-- It can be switched off in the options (Home, or The bar) or with
-- /yaht minimap. It is YaHT's own small button (no extra library), so it
-- costs nothing while you aren't touching it.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

local SIZE = 31
local EDGE = 5 -- how far outside the minimap's rim the button's middle sits
local ICON = "Interface\\Icons\\INV_Weapon_Bow_07"
local ROW_H, MENU_W = 22, 190
local GOLD = {0.91, 0.70, 0.20}
local TEXT = {0.92, 0.87, 0.75}

local button, quick

local function Guard(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError("the minimap button", err) end
	end
end

-- Puts the button on the minimap's rim at an angle (degrees, 0 = right, 90 = top)
local function Place(angle)
	local r = (Minimap:GetWidth() or 140) / 2 + EDGE
	local rad = math.rad(angle or 215)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end

-- while dragging: follow the mouse around the minimap
local function Follow()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale() or 1
	if not (mx and my and px and py) then return end
	local angle = math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360
	YaHT.db.profile.minimapangle = angle
	Place(angle)
end

---------------------------------------------------------------------------
-- The quick menu
---------------------------------------------------------------------------
local function CloseQuick()
	if quick then
		quick:Hide()
		quick.catcher:Hide()
	end
end

local QUICK = {
	{
		text = function() return YaHT.db.profile.lock and L["Unlock bar (move things)"] or L["Lock bar"] end,
		run = function()
			local p = YaHT.db.profile
			p.lock = not p.lock
			YaHT:ApplySettings()
			if YaHT.menu and YaHT.menu.Render then YaHT.menu.Render() end
		end,
	},
	{text = function() return L["Preview all alerts"] end, run = function() if YaHT.PreviewAlerts then YaHT:PreviewAlerts() end end},
	{text = function() return L["Options"] end, run = function() SlashCmdList["YAHT"]("") end},
	{
		text = function() return L["Hide this button"] end,
		run = function()
			YaHT.db.profile.minimap = false
			YaHT:ApplySettings()
			YaHT:Print(L["minimap button hidden. Type /yaht minimap to bring it back."], true)
		end,
	},
}

local function BuildQuick()
	local f = CreateFrame("Frame", "YaHTQuickMenu", UIParent)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetSize(MENU_W, #QUICK * ROW_H + 26)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetColorTexture(0.07, 0.07, 0.07, 0.97)
	for _, side in ipairs({{"TOPLEFT", "TOPRIGHT", true}, {"BOTTOMLEFT", "BOTTOMRIGHT", true}, {"TOPLEFT", "BOTTOMLEFT"}, {"TOPRIGHT", "BOTTOMRIGHT"}}) do
		local t = f:CreateTexture(nil, "BORDER")
		t:SetColorTexture(0.54, 0.46, 0.27, 1)
		t:SetPoint(side[1], f, side[1])
		t:SetPoint(side[2], f, side[2])
		if side[3] then t:SetHeight(1) else t:SetWidth(1) end
	end
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
	title:SetText("YaHT Forever")
	f:EnableMouse(true)
	-- a click anywhere else closes it
	f.catcher = CreateFrame("Button", nil, UIParent)
	f.catcher:SetFrameStrata("DIALOG")
	f.catcher:SetAllPoints(UIParent)
	f.catcher:SetScript("OnClick", Guard(CloseQuick))
	f.catcher:Hide()
	f:SetFrameLevel(f.catcher:GetFrameLevel() + 5)
	f.rows = {}
	for i, item in ipairs(QUICK) do
		local b = CreateFrame("Button", nil, f)
		b:SetHeight(ROW_H)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -22 - (i - 1) * ROW_H)
		b:SetPoint("RIGHT", f, "RIGHT", -1, 0)
		b.hover = b:CreateTexture(nil, "BACKGROUND")
		b.hover:SetAllPoints(b)
		b.hover:SetColorTexture(1, 1, 1, 0.08)
		b.hover:Hide()
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.text:SetPoint("LEFT", b, "LEFT", 10, 0)
		b.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
		b:SetScript("OnEnter", function(self) self.hover:Show() end)
		b:SetScript("OnLeave", function(self) self.hover:Hide() end)
		b:SetScript("OnClick", Guard(function()
			CloseQuick()
			item.run()
		end))
		f.rows[i] = b
	end
	f:Hide()
	return f
end

local function OpenQuick()
	quick = quick or BuildQuick()
	if quick:IsShown() then return CloseQuick() end
	for i, item in ipairs(QUICK) do quick.rows[i].text:SetText(item.text()) end
	quick:ClearAllPoints()
	quick:SetPoint("TOPRIGHT", button, "BOTTOMLEFT", 6, 6)
	quick.catcher:Show()
	quick:Show()
end

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------
local function CreateButton()
	local b = CreateFrame("Button", "YaHTMinimapButton", Minimap)
	b:SetSize(SIZE, SIZE)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local back = b:CreateTexture(nil, "BACKGROUND")
	back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	back:SetSize(24, 24)
	back:SetPoint("CENTER", b, "CENTER")
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	icon:SetSize(18, 18)
	icon:SetPoint("CENTER", b, "CENTER")
	local ring = b:CreateTexture(nil, "OVERLAY")
	ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	ring:SetSize(50, 50)
	ring:SetPoint("TOPLEFT", b, "TOPLEFT")
	b:SetScript("OnClick", Guard(function(_, mouse)
		if GameTooltip then GameTooltip:Hide() end
		if mouse == "RightButton" then
			OpenQuick()
		else
			CloseQuick()
			SlashCmdList["YAHT"]("")
		end
	end))
	b:SetScript("OnDragStart", Guard(function(self)
		CloseQuick()
		self:SetScript("OnUpdate", Guard(Follow))
	end))
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnEnter", Guard(function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("YaHT Forever", 1, 1, 1)
		GameTooltip:AddLine(L["Left-click: options"], GOLD[1], GOLD[2], GOLD[3])
		GameTooltip:AddLine(L["Right-click: quick menu"], GOLD[1], GOLD[2], GOLD[3])
		GameTooltip:AddLine(L["Drag: move this button"], TEXT[1], TEXT[2], TEXT[3])
		GameTooltip:Show()
	end))
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	return b
end

function YaHT:ApplyMinimapSettings()
	if not button then return end
	local p = self.db.profile
	if p.minimap then
		Place(p.minimapangle)
		button:Show()
	else
		CloseQuick()
		button:Hide()
	end
end

-- /yaht minimap: show or hide the button
function YaHT:ToggleMinimapButton()
	local p = self.db.profile
	p.minimap = not p.minimap
	self:ApplySettings()
	if self.menu and self.menu.Render then self.menu.Render() end
	self:Print(p.minimap and L["minimap button shown."] or L["minimap button hidden. Type /yaht minimap to bring it back."], true)
end

function YaHT:InitMinimap()
	if not Minimap then return end -- no minimap to sit on
	button = CreateButton()
	self.minimapButton = button
	self:ApplyMinimapSettings()
end
