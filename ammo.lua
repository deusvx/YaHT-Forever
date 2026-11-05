-- YaHT ammo counter: a movable icon that stays faded out while you have
-- plenty of ammo, fades in as it runs down, and flashes when it's low.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

local function IsSecret(v)
	return issecretvalue and issecretvalue(v) or false
end

local AMMO_SLOT = INVSLOT_AMMO or 0
local RANGED_SLOT = INVSLOT_RANGED or 18
-- Item class / subclass IDs (stable since Classic)
local CLASS_WEAPON, CLASS_PROJECTILE = 2, 6
local WEAPON_BOW, WEAPON_GUN, WEAPON_CROSSBOW, WEAPON_THROWN, WEAPON_WAND = 2, 3, 18, 16, 19
local PROJ_ARROW, PROJ_BULLET = 2, 3

local function ItemInfo(itemID)
	if not itemID or IsSecret(itemID) then return end
	if C_Item and C_Item.GetItemInfoInstant then
		local _, _, _, _, icon, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
		return classID, subclassID, icon
	elseif GetItemInfoInstant then
		local _, _, _, _, icon, classID, subclassID = GetItemInfoInstant(itemID)
		return classID, subclassID, icon
	end
end

local function ItemCount(itemID)
	local n = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(itemID)) or (GetItemCount and GetItemCount(itemID))
	if IsSecret(n) then return nil end
	return n
end

local function ContainerSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
	return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

local function ContainerItem(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then return info.itemID, info.stackCount, info.iconFileID end
	elseif GetContainerItemInfo then
		local icon, count, _, _, _, _, _, _, _, id = GetContainerItemInfo(bag, slot)
		return id, count, icon
	end
end

-- Which projectile does the equipped ranged weapon use?
-- returns PROJ_ARROW / PROJ_BULLET, false for thrown/wand (no ammo), nil if no weapon.
local function NeededAmmo()
	local id = GetInventoryItemID("player", RANGED_SLOT)
	if not id or IsSecret(id) then return nil end
	local classID, sub = ItemInfo(id)
	if classID ~= CLASS_WEAPON then return PROJ_ARROW end -- unknown: assume it needs ammo
	if sub == WEAPON_GUN then return PROJ_BULLET end
	if sub == WEAPON_BOW or sub == WEAPON_CROSSBOW then return PROJ_ARROW end
	if sub == WEAPON_THROWN or sub == WEAPON_WAND then return false end
	return PROJ_ARROW
end

-- Returns count, icon, method. count nil = nothing to track.
function YaHT:ReadAmmo()
	local need = NeededAmmo()
	if need == nil or need == false then return nil, nil, need == nil and "no ranged weapon" or "weapon uses no ammo" end

	-- 1) Classic-style ammo slot
	local ammoID = GetInventoryItemID("player", AMMO_SLOT)
	if ammoID and not IsSecret(ammoID) then
		local n = GetInventoryItemCount and GetInventoryItemCount("player", AMMO_SLOT)
		if IsSecret(n) or not n or n <= 1 then n = ItemCount(ammoID) end
		local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", AMMO_SLOT)
		if not icon or IsSecret(icon) then icon = select(3, ItemInfo(ammoID)) end
		return n or 0, icon, "ammo slot"
	end

	-- 2) No ammo slot: count matching arrows/bullets in the bags
	local total, icon = 0, nil
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, lastBag do
		for slot = 1, ContainerSlots(bag) or 0 do
			local id, count, tex = ContainerItem(bag, slot)
			if id and not IsSecret(id) and not IsSecret(count) then
				local classID, sub = ItemInfo(id)
				if classID == CLASS_PROJECTILE and sub == need then
					total = total + (count or 0)
					icon = icon or tex
				end
			end
		end
	end
	return total, icon, "bags"
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local frame -- created in InitAmmo
local FALLBACK_ICON = {[PROJ_ARROW] = "Interface\\Icons\\INV_Ammo_Arrow_01", [PROJ_BULLET] = "Interface\\Icons\\INV_Ammo_Bullet_01"}

local function PlayWarning(level)
	if not YaHT.db.profile.ammosound then return end
	local kit = SOUNDKIT and (level == "CRIT" and SOUNDKIT.RAID_WARNING or SOUNDKIT.ALARM_CLOCK_WARNING_3)
	if kit then pcall(PlaySound, kit, "Master") end
end

local function Refresh()
	local p = YaHT.db.profile
	local count, icon = YaHT:ReadAmmo()
	frame.count = count
	if count == nil then
		frame.level = "NONE"
		return
	end
	if not icon then icon = FALLBACK_ICON[NeededAmmo() or PROJ_ARROW] end
	frame.icon:SetTexture(icon)
	frame.text:SetText(count)

	local level
	if count <= p.ammocrit then level = "CRIT"
	elseif count <= p.ammolow then level = "LOW"
	else level = "OK" end
	-- sound once per step down; re-arms after you restock
	if level ~= frame.level then
		if (level == "LOW" and frame.level == "OK") or (level == "CRIT" and frame.level ~= "CRIT" and frame.level ~= "NONE") then
			PlayWarning(level)
		end
		frame.level = level
	end
	if level == "CRIT" then
		frame.text:SetTextColor(1, 0.15, 0.15)
		frame.glow:SetVertexColor(1, 0.1, 0.1)
	elseif level == "LOW" then
		frame.text:SetTextColor(1, 0.85, 0.1)
		frame.glow:SetVertexColor(1, 0.75, 0.1)
	else
		frame.text:SetTextColor(1, 1, 1)
	end
end

local function OnUpdate(self, elapsed)
	local p = YaHT.db.profile
	if self.dirty then
		self.dirty = false
		local ok, err = pcall(Refresh)
		if not ok and YaHT.ReportError then YaHT.ReportError("Ammo", err) end
	end
	local count, level = self.count, self.level
	if not p.ammo or count == nil then
		self:SetAlpha(not p.lock and p.ammo and 1 or 0)
		self.glow:SetAlpha(0)
		return
	end
	if not p.lock then -- unlocked: always visible so it can be placed
		self:SetAlpha(1)
		self.glow:SetAlpha(level ~= "OK" and 0.8 or 0)
		return
	end
	if level == "OK" then
		-- faded out while full, fading in as it approaches the low mark
		local top, low = math.max(p.ammofadestart, p.ammolow + 1), p.ammolow
		local t = math.min(math.max((top - count) / (top - low), 0), 1)
		self:SetAlpha(p.ammofullalpha + (1 - p.ammofullalpha) * t)
		self.glow:SetAlpha(0)
	else
		local speed = level == "CRIT" and 3 or 1.5 -- flashes per second
		local wave = 0.5 + 0.5 * math.sin(GetTime() * math.pi * 2 * speed)
		self:SetAlpha(p.ammoflash and (0.35 + 0.65 * wave) or 1)
		self.glow:SetAlpha(p.ammoflash and wave or 0.8)
	end
end

function YaHT:ApplyAmmoSettings()
	if not frame then return end
	local p = self.db.profile
	frame:SetSize(p.ammosize, p.ammosize)
	frame:ClearAllPoints()
	if p.ammopoint then
		frame:SetPoint(p.ammopoint, UIParent, p.ammorelpoint, p.ammox, p.ammoy)
	else
		frame:SetPoint("BOTTOM", self.mainFrame, "TOP", 0, 20)
	end
	frame.glow:SetSize(p.ammosize * 1.9, p.ammosize * 1.9)
	local font = self:GetMedia("font", p.font) or STANDARD_TEXT_FONT
	if not frame.text:SetFont(font, math.max(8, math.floor(p.ammosize * 0.38)), "OUTLINE") then
		frame.text:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(p.ammosize * 0.38)), "OUTLINE")
	end
	frame:EnableMouse(not p.lock)
	frame:SetMovable(true)
	frame:SetShown(p.ammo)
	frame.dirty = true
end

function YaHT:InitAmmo()
	frame = CreateFrame("Frame", "YaHTAmmoFrame", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
	frame:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		local p = YaHT.db.profile
		local _
		p.ammopoint, _, p.ammorelpoint, p.ammox, p.ammoy = f:GetPoint()
	end)

	frame.glow = frame:CreateTexture(nil, "BACKGROUND")
	frame.glow:SetTexture("Interface\\AddOns\\YaHT\\media\\Glow")
	frame.glow:SetTexCoord(0, 1, 0, 1)
	frame.glow:SetBlendMode("ADD")
	frame.glow:SetPoint("CENTER")
	frame.glow:SetAlpha(0)

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetAllPoints()
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	frame.text = frame:CreateFontString(nil, "OVERLAY")
	frame.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
	frame.text:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)

	frame.level = "NONE"
	frame.dirty = true
	frame:SetScript("OnUpdate", OnUpdate)
	self.ammoFrame = frame

	-- recount only when bags / gear change (applied on the next frame, so a
	-- burst of bag events costs one count)
	local events = CreateFrame("Frame")
	for _, e in ipairs({"BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED", "PLAYER_SWING"}) do
		pcall(events.RegisterEvent, events, e)
	end
	pcall(events.RegisterUnitEvent or events.RegisterEvent, events, "UNIT_INVENTORY_CHANGED", "player")
	events:SetScript("OnEvent", function() frame.dirty = true end)

	self:ApplyAmmoSettings()
end
