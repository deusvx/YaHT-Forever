-- YaHT alignment grid: thin lines over the whole screen, measured out from the
-- middle (which is marked in gold), to line the bar and the alerts up exactly.
-- Switched with the Grid switch in the options window's header or /yaht grid.
-- It only draws once, when first shown, and does nothing while hidden; clicks
-- pass straight through it.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT

local STEP = 32   -- distance between lines
local STRONG = 4  -- every fourth line is a little brighter
local grid

-- one screen pixel, in the game's own units, so lines stay hair-thin and never vanish
local function Pixel()
	local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
	local height = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize())
	if not height or height <= 0 or scale <= 0 then return 1 end
	return 768 / height / scale
end

local function Build()
	local g = CreateFrame("Frame", "YaHTGridFrame", UIParent)
	g:SetAllPoints(UIParent)
	g:SetFrameStrata("BACKGROUND")
	local w = UIParent.GetWidth and UIParent:GetWidth() or 1920
	local h = UIParent.GetHeight and UIParent:GetHeight() or 1080
	local px = Pixel()
	g.lines = 0
	local function line(vertical, offset, n)
		local t = g:CreateTexture(nil, "BACKGROUND")
		local middle = n == 0
		if middle then
			t:SetColorTexture(0.91, 0.70, 0.20, 0.9)
		else
			t:SetColorTexture(1, 1, 1, n % STRONG == 0 and 0.34 or 0.16)
		end
		local thick = middle and 2 * px or px
		if vertical then
			t:SetSize(thick, h)
			t:SetPoint("CENTER", g, "CENTER", offset, 0)
		else
			t:SetSize(w, thick)
			t:SetPoint("CENTER", g, "CENTER", 0, offset)
		end
		g.lines = g.lines + 1
	end
	for n = 0, math.floor(w / 2 / STEP) do
		line(true, n * STEP, n)
		if n > 0 then line(true, -n * STEP, n) end
	end
	for n = 0, math.floor(h / 2 / STEP) do
		line(false, n * STEP, n)
		if n > 0 then line(false, -n * STEP, n) end
	end
	g:Hide()
	return g
end

function YaHT:GridShown()
	return grid ~= nil and grid:IsShown() and true or false
end

function YaHT:ShowGrid(on)
	if on then
		grid = grid or Build()
		grid:Show()
	elseif grid then
		grid:Hide()
	end
end

function YaHT:ToggleGrid()
	self:ShowGrid(not self:GridShown())
	if self.menu and self.menu.Render then self.menu.Render() end
end
