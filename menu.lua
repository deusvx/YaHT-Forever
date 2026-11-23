-- YaHT's own options window (/yaht). It is drawn from the very same settings
-- table the Ace3 dialog uses (options.lua), so every setting, reset button and
-- profile works exactly as before; only the window is new:
--   * a header with a search box
--   * a live preview of the bar and icons that follows your settings, in a
--     box at the top of the right column
--   * three columns: the pages on the left; in the middle the page itself
--     (a Home page with the quick looks and the main switches, otherwise one
--     row per setting, grouped in boxes); on the right what the setting under
--     the mouse does
--   * rounded corners from YaHT's own artwork (media/Round, RoundEdge, Dot)
-- Nothing here runs while the window is closed, and the window is only built
-- the first time it is opened. If it ever fails, /yaht falls back to the Ace3
-- dialog (/yaht classic opens that one on purpose).
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, HEIGHT = 1120, 700
local EDGE = 10            -- between the window's edge and its panels, and between panels
local HEAD_H, NAV_W, HELP_W = 44, 184, 296
local PREVIEW_H = 176      -- the live preview's box, at the top of the right column
local PREVIEW_DY = -26     -- the bar stands below the middle of the box: the icons and hawk circles need the room above it
local PREVIEW_BOX_W = HELP_W - 20
local BODY_TOP = HEAD_H + 6
local VIEW_W, VIEW_H = WIDTH - NAV_W - HELP_W - 4 * EDGE, HEIGHT - BODY_TOP - EDGE
local ROW_H, ROW_GAP, PAD = 32, 4, 12
local ROW_STEP = ROW_H + ROW_GAP
local BOX_PAD, BOX_GAP = 8, 10 -- inside a section's box, and between two boxes
local MARK_W = 10          -- kept free on the right of the page for the scroll marker
local NAV_ROW = 24
local LIST_ROWS = 12       -- a dropdown shows this many choices, then scrolls
local SLIDER_W = 170
local CARD_H = 142         -- a look's card: its small live preview, its name and one line of text
local CARD_STAGE_H = 92    -- the preview on a card
local GLOW_TEX = "Interface\\AddOns\\YaHT\\media\\Glow"
local SHINE_TEX = "Interface\\AddOns\\YaHT\\media\\Shine"
local SPARK_TEX = "Interface\\AddOns\\YaHT\\media\\Spark"
local ROUND_TEX = "Interface\\AddOns\\YaHT\\media\\Round"     -- a filled rounded rectangle
local EDGE_TEX = "Interface\\AddOns\\YaHT\\media\\RoundEdge"  -- its one-pixel outline
local DOT_TEX = "Interface\\AddOns\\YaHT\\media\\Dot"         -- a filled circle
local DISC_TEX = "Interface\\AddOns\\YaHT\\media\\Disc"       -- a larger filled circle (the hawk circles)
local RING_TEX = "Interface\\AddOns\\YaHT\\media\\Ring"       -- its ring
local STRIPES_TEX = "Interface\\AddOns\\YaHT\\media\\Stripes"   -- the deadzone's stripes (16x16, repeats)
local CHEVRON_TEX = "Interface\\AddOns\\YaHT\\media\\Chevron"   -- a too-far arrow
local GEAR_TEX = "Interface\\AddOns\\YaHT\\media\\Gear"         -- the "open its page" button beside a switch
local RINGFLAT_TEX = "Interface\\AddOns\\YaHT\\media\\RingFlat" -- the plain ring (the standard look)
local RINGLINE_TEX = "Interface\\AddOns\\YaHT\\media\\RingLine" -- the ring's fine edge lines
local GLOSS_TEX = "Interface\\AddOns\\YaHT\\media\\Gloss"     -- a soft light on an icon
local HALO_TEX = "Interface\\AddOns\\YaHT\\media\\Halo"       -- a soft round glow (and, in black, a shadow)
local SQRING_TEX = "Interface\\AddOns\\YaHT\\media\\SquareRing"  -- a square icon's polished look: its bevelled frame,
local SQLINE_TEX = "Interface\\AddOns\\YaHT\\media\\SquareLine"  -- the frame's fine edge lines,
local SQGLOSS_TEX = "Interface\\AddOns\\YaHT\\media\\SquareGloss" -- a soft light on the icon
local SQHALO_TEX = "Interface\\AddOns\\YaHT\\media\\SquareHalo"  -- and its shadow
local STAGE_TEX = "Interface\\AddOns\\YaHT\\media\\Stage"     -- a soft pool of light (the preview's stage)
-- rounded shapes are drawn "nine-sliced": the corners keep their size, the rest stretches
local SLICE = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
local PREVIEW_ROOM = PREVIEW_BOX_W - 28 -- the room in the box for the bar and what sits beside it
local PREVIEW_CYCLE = 2.6  -- seconds per shot in the preview
local PREVIEW_WINDUP = 0.82 -- the last part of the cycle is the wind-up

local C = {
	bg = {0.05, 0.05, 0.055, 1},      -- the window (solid: nothing behind it shows through)
	panel = {0.095, 0.09, 0.08, 1},   -- the boxes on it (page list, sections, help)
	plate = {0.15, 0.14, 0.12, 1},    -- a setting's row inside a box
	field = {0.06, 0.058, 0.052, 1},  -- something you type in or pick from
	line = {0.54, 0.46, 0.27, 1},
	soft = {0.26, 0.23, 0.17, 1},
	hover = {1, 1, 1, 0.05},
	navOn = {0.20, 0.165, 0.10, 1},
	preview = {0.04, 0.036, 0.032, 1}, -- the preview's box: darker than the panel it sits in
	edge = {0.2, 0.175, 0.13, 1},      -- the thin outline of a panel
	gold = {0.91, 0.70, 0.20},
	goldDim = {0.72, 0.57, 0.18, 1},
	text = {0.92, 0.87, 0.75},
	muted = {0.66, 0.62, 0.50},
	white = {1, 1, 1},
}

local Menu = {}
YaHT.menu = Menu

local frame            -- the window, once built
local content, scroll  -- the page (scrolls inside the window)
local contentH = 0
local pages, pageById
local live, pool = {}, {}
local Make, Fill = {}, {}
Menu.rows = live -- the rows now on the page (for tests and debugging)

---------------------------------------------------------------------------
-- Small drawing helpers
---------------------------------------------------------------------------
local function Tex(parent, layer, c)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	return t
end

local function Text(parent, template, c)
	local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
	if c then fs:SetTextColor(c[1], c[2], c[3]) end
	fs:SetJustifyH("LEFT")
	return fs
end

-- A small arrow head pointing up (dir 1) or down (-1): YaHT's own smooth
-- artwork (media/Arrow), tinted. Returns what TintArrow recolours on hover.
local ARROW_TEX = "Interface\\AddOns\\YaHT\\media\\Arrow"
local function TintArrow(arrow, c)
	for _, t in ipairs(arrow) do t:SetVertexColor(c[1], c[2], c[3], 1) end
end
local function Arrow(parent, dir, x, y)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture(ARROW_TEX)
	t:SetSize(10, 5)
	if dir < 0 then t:SetTexCoord(0, 1, 1, 0) end -- the same picture upside down
	t:SetPoint("CENTER", parent, "CENTER", x or 0, y or 0)
	local arrow = {t}
	TintArrow(arrow, C.muted)
	return arrow
end

-- a one-pixel outline
local function Outline(f, c)
	local top, bottom, left, right = Tex(f, "BORDER", c), Tex(f, "BORDER", c), Tex(f, "BORDER", c), Tex(f, "BORDER", c)
	top:SetPoint("TOPLEFT", f, "TOPLEFT") top:SetPoint("TOPRIGHT", f, "TOPRIGHT") top:SetHeight(1)
	bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT") bottom:SetHeight(1)
	left:SetPoint("TOPLEFT", f, "TOPLEFT") left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT") left:SetWidth(1)
	right:SetPoint("TOPRIGHT", f, "TOPRIGHT") right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT") right:SetWidth(1)
	return {top, bottom, left, right}
end

-- Rounded shapes. A texture made here is white artwork tinted with a colour;
-- Paint recolours anything made by Tex, Plate, Rim or Dot. If the game can't
-- nine-slice a texture, everything falls back to plain square shapes.
local function Paint(t, c)
	if t.shaped then
		t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
	else
		t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	end
end

local function CanRound(t)
	return SLICE and t.SetTextureSliceMargins and t.SetTextureSliceMode and true or false
end

local function Shape(t, file)
	t:SetTexture(file)
	t:SetTextureSliceMargins(8, 8, 8, 8)
	t:SetTextureSliceMode(SLICE)
	t.shaped = true
end

-- a filled rounded rectangle
local function Plate(parent, layer, c)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	if CanRound(t) then Shape(t, ROUND_TEX) end
	Paint(t, c)
	return t
end

-- a rounded one-pixel outline around f; PaintRim recolours it
local function Rim(f, c, layer)
	local t = f:CreateTexture(nil, layer or "BORDER")
	if not CanRound(t) then
		t:Hide()
		return Outline(f, c)
	end
	Shape(t, EDGE_TEX)
	t:SetAllPoints(f)
	Paint(t, c)
	return {t}
end
local function PaintRim(rim, c)
	for _, t in ipairs(rim) do Paint(t, c) end
end

-- a filled circle
local function Dot(parent, layer, c)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetTexture(DOT_TEX)
	t.shaped = true
	Paint(t, c)
	return t
end

-- Runs a handler; if it breaks, says so once in chat instead of failing silently
local function Guard(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok and YaHT.ReportError then YaHT.ReportError("the options window", err) end
	end
end
local function On(widget, script, fn)
	widget:SetScript(script, Guard(fn))
end

-- The column on the right explains the setting under the mouse. At rest it
-- says what the page is for (Menu.helpTitle / helpText, set when a page is drawn).
local function SetHelp(title, text)
	local help = frame and frame.help
	if not help then return end
	help.title:SetText(title or "")
	help.text:SetText(text or "")
end
local function ShowTip(row)
	if not row.tip then return end
	SetHelp(row.tipTitle, row.tip)
end
local function HideTip()
	SetHelp(Menu.helpTitle, Menu.helpText)
end

---------------------------------------------------------------------------
-- Reading the settings table (the same rules the Ace3 dialog follows)
---------------------------------------------------------------------------
-- A setting is addressed by its path from the top: {{key=, opt=}, ...}
local function Root() return YaHT.optionsTable end

-- the nearest value of a member, from the setting itself up to the top
local function Inherit(path, member)
	for i = #path, 1, -1 do
		local v = path[i].opt[member]
		if v ~= nil then return v end
	end
	return Root()[member]
end

local function Info(path)
	local info = {}
	for i, node in ipairs(path) do info[i] = node.key end
	local opt = path[#path].opt
	info.options, info.appName, info.option, info.arg, info.type = Root(), "YaHT", opt, opt.arg, opt.type
	info.handler = Inherit(path, "handler")
	info.uiType, info.uiName = "dialog", "YaHTMenu"
	return info
end

-- get / set / func: a function, or the name of a method on the handler
local function Call(path, member, ...)
	local fn = Inherit(path, member)
	if not fn then return nil end
	local info = Info(path)
	if type(fn) == "string" then
		local handler = info.handler
		return handler[fn](handler, info, ...)
	end
	return fn(info, ...)
end

-- a member of the setting itself that may be a plain value, a function, or
-- (values / disabled / hidden only) the name of a method on the handler
local function Value(path, member)
	local v = path[#path].opt[member]
	if type(v) == "function" then return v(Info(path)) end
	if type(v) == "string" and (member == "values" or member == "disabled" or member == "hidden") then
		local handler = Inherit(path, "handler")
		if handler and handler[v] then return handler[v](handler, Info(path)) end
		return nil
	end
	return v
end

-- disabled / hidden also count when a group above says so
local function Flag(path, member)
	local prefix = {}
	for i, node in ipairs(path) do
		prefix[i] = node
		if Value(prefix, member) then return true end
	end
	return false
end

-- the children of a group, in menu order
local function Sorted(args)
	local list = {}
	for key, opt in pairs(args or {}) do list[#list + 1] = {key = key, opt = opt} end
	table.sort(list, function(a, b)
		local oa, ob = a.opt.order or 100, b.opt.order or 100
		if oa ~= ob then return oa < ob end
		return tostring(a.key) < tostring(b.key)
	end)
	return list
end

local function Extend(path, node)
	local p = {}
	for i, n in ipairs(path) do p[i] = n end
	p[#p + 1] = node
	return p
end

-- the path of a setting given its keys from the top, or nil
local function Find(keys)
	local path, args = {}, Root().args
	for _, key in ipairs(keys) do
		local opt = args and args[key]
		if not opt then return nil end
		path[#path + 1] = {key = key, opt = opt}
		args = opt.args
	end
	return path
end

-- every group is a page; the list on the left shows them in order
local function BuildPages()
	pages, pageById = {{id = "home", name = L["Home"], depth = 1}}, {}
	pageById.home = pages[1]
	local function walk(args, path, depth, parent)
		for _, node in ipairs(Sorted(args)) do
			if node.opt.type == "group" then
				local p = Extend(path, node)
				local keys = {}
				for i, n in ipairs(p) do keys[i] = n.key end
				local page = {id = table.concat(keys, "/"), name = node.opt.name, path = p, depth = depth, parent = parent}
				pages[#pages + 1] = page
				pageById[page.id] = page
				walk(node.opt.args, p, depth + 1, page)
			end
		end
	end
	walk(Root().args, {}, 1, nil)
end

---------------------------------------------------------------------------
-- What a page holds
---------------------------------------------------------------------------
local function OptionItem(path)
	return {path = path, opt = path[#path].opt}
end

-- What each quick look shows in its preview card: the same things it switches on
local CARD_LOOK = {
	presetminimal = {preset = "MINIMAL"},
	presetclean = {preset = "CLEAN"},
	presetflashy = {preset = "FLASHY"},
}

local function PageItems(page)
	local items, cards = {}, false
	for _, node in ipairs(Sorted(page.path[#page.path].opt.args)) do
		if node.opt.type == "execute" and CARD_LOOK[node.key] then
			-- the quick looks show as one row of preview cards, not three buttons
			-- (not on a page that leaves them to Home)
			if not cards and not Flag(Extend(page.path, node), "hidden") then
				cards = true
				items[#items + 1] = {custom = "cards"}
			end
		elseif node.opt.type ~= "group" then
			items[#items + 1] = OptionItem(Extend(page.path, node))
		end
	end
	return items
end

local HOME_SWITCHES = { -- (Lock bar is in the window's header, on every page)
	{"alerts", "aspect"}, {"alerts", "feign"}, {"alerts", "pet"}, {"alerts", "hawk"},
	{"alerts", "meleerange"}, {"alerts", "melee"}, {"alerts", "ammo"}, {"alerts", "multicast"}, {"bar", "minimap"},
	{"alerts", "roundall"}, {"alerts", "polishall"},
}
local HOME_BUTTONS = {{"alerts", "preview"}}
local HOME_CARDS = {"presetminimal", "presetclean", "presetflashy"}

local function HomeItems()
	local items = { -- (the welcome text is in the help column on the right)
		{custom = "section", text = L["Quick looks"]},
		{custom = "cards"},
		{custom = "section", text = L["Main switches"]},
	}
	for _, keys in ipairs(HOME_SWITCHES) do
		local path = Find(keys)
		if path then items[#items + 1] = OptionItem(path) end
	end
	items[#items + 1] = {custom = "gap"}
	for _, keys in ipairs(HOME_BUTTONS) do
		local path = Find(keys)
		if path then items[#items + 1] = OptionItem(path) end
	end
	return items -- (the credits are at the foot of the help column, on every page)
end

local function Trail(page)
	local names = {}
	while page do
		table.insert(names, 1, page.name)
		page = page.parent
	end
	return table.concat(names, "  >  ")
end

local SEARCHABLE = {toggle = true, range = true, select = true, color = true, execute = true, input = true}
local function SearchItems(query)
	local items = {}
	for _, page in ipairs(pages) do
		if page.path then
			local first = true
			for _, item in ipairs(PageItems(page)) do
				if item.opt and SEARCHABLE[item.opt.type] then -- (the quick-look cards aren't a setting)
					local name, desc = Value(item.path, "name"), Value(item.path, "desc")
					local hit = type(name) == "string" and name:lower():find(query, 1, true)
						or type(desc) == "string" and desc:lower():find(query, 1, true)
					if hit then
						if first then
							items[#items + 1] = {custom = "section", text = Trail(page)}
							first = false
						end
						items[#items + 1] = item
					end
				end
			end
		end
	end
	if #items == 0 then
		items[1] = {custom = "note", text = string.format(L["Nothing found for \"%s\"."], query)}
	end
	return items
end

function Menu.PageIds()
	local ids = {}
	for i, page in ipairs(pages or {}) do ids[i] = page.id end
	return ids
end

function Menu.Items()
	if Menu.query and #Menu.query >= 2 then return SearchItems(Menu.query) end
	local page = pageById[Menu.current] or pages[1]
	if not page.path then return HomeItems() end
	return PageItems(page)
end

---------------------------------------------------------------------------
-- Popups: yes/no, the colour picker, and the dropdown list
---------------------------------------------------------------------------
local function Confirm(text, fn)
	if not (StaticPopupDialogs and StaticPopup_Show) then return fn() end
	StaticPopupDialogs["YAHT_MENU_CONFIRM"] = StaticPopupDialogs["YAHT_MENU_CONFIRM"] or {
		text = "%s", button1 = YES or "Yes", button2 = NO or "No",
		timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
		OnAccept = function(_, data) if data then data() end end,
	}
	StaticPopup_Show("YAHT_MENU_CONFIRM", text, nil, fn)
end

local function PickColor(path)
	local picker = ColorPickerFrame
	if not picker then return end
	local r, g, b, a = Call(path, "get")
	r, g, b, a = r or 1, g or 1, b or 1, a or 1
	local hasAlpha = path[#path].opt.hasAlpha and true or false
	local function apply(nr, ng, nb, na)
		Call(path, "set", nr, ng, nb, hasAlpha and na or 1)
		Menu.Changed()
	end
	if picker.SetupColorPickerAndShow then
		picker:SetupColorPickerAndShow({
			r = r, g = g, b = b, opacity = a, hasOpacity = hasAlpha,
			swatchFunc = function()
				local nr, ng, nb = picker:GetColorRGB()
				apply(nr, ng, nb, picker.GetColorAlpha and picker:GetColorAlpha() or a)
			end,
			opacityFunc = function()
				local nr, ng, nb = picker:GetColorRGB()
				apply(nr, ng, nb, picker.GetColorAlpha and picker:GetColorAlpha() or a)
			end,
			cancelFunc = function() apply(r, g, b, a) end,
		})
	else
		-- older colour picker
		picker.hasOpacity, picker.opacity = hasAlpha, 1 - a
		picker.previousValues = {r, g, b, a}
		local function read()
			local nr, ng, nb = picker:GetColorRGB()
			local na = (hasAlpha and OpacitySliderFrame) and (1 - OpacitySliderFrame:GetValue()) or a
			apply(nr, ng, nb, na)
		end
		picker.func, picker.opacityFunc = read, read
		picker.cancelFunc = function() apply(r, g, b, a) end
		picker:SetColorRGB(r, g, b)
		picker:Hide()
		picker:Show()
	end
end

-- which kind of media a dropdown lists, so its choices can show what they are
local MEDIA_OF = {statusbar = "statusbar", background = "background", font = "font"}

local list -- the one dropdown list, shared by every dropdown
local function BuildList()
	local f = CreateFrame("Frame", nil, frame)
	f:SetFrameLevel(frame:GetFrameLevel() + 60)
	Plate(f, "BACKGROUND", C.field):SetAllPoints(f)
	Rim(f, C.line)
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	-- a click anywhere else closes it
	f.catcher = CreateFrame("Button", nil, frame)
	f.catcher:SetAllPoints(UIParent)
	f.catcher:SetFrameLevel(frame:GetFrameLevel() + 55)
	On(f.catcher, "OnClick", function() Menu.CloseList() end)
	f.rows = {}
	for i = 1, LIST_ROWS do
		local b = CreateFrame("Button", nil, f)
		b:SetHeight(20)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4 - (i - 1) * 20)
		b:SetPoint("RIGHT", f, "RIGHT", -4, 0)
		-- (a texture's sample sits at the right end of its line, so its name stays easy to read)
		b.sample = b:CreateTexture(nil, "BACKGROUND")
		b.sample:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)
		b.sample:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
		b.sample:SetWidth(40)
		b.hover = Tex(b, "BORDER", {1, 1, 1, 0.08})
		b.hover:SetAllPoints(b)
		b.hover:Hide()
		b.text = Text(b, "GameFontHighlightSmall", C.text)
		b.text:SetPoint("LEFT", b, "LEFT", 6, 0)
		On(b, "OnEnter", function(self) self.hover:Show() end)
		On(b, "OnLeave", function(self) self.hover:Hide() end)
		On(b, "OnClick", function(self)
			local pick, key = f.pick, self.key
			Menu.CloseList()
			if pick and key ~= nil then pick(key) end
		end)
		f.rows[i] = b
	end
	On(f, "OnMouseWheel", function(self, delta)
		local max = math.max(0, #self.keys - LIST_ROWS)
		self.offset = math.min(max, math.max(0, self.offset - delta))
		Menu.DrawList()
	end)
	f:Hide()
	f.catcher:Hide()
	return f
end

function Menu.DrawList()
	local f = list
	for i, b in ipairs(f.rows) do
		local key = f.keys[i + f.offset]
		if key == nil then
			b:Hide()
		else
			b.key = key
			b.text:SetText(tostring(f.values[key]))
			local c = key == f.current and C.gold or C.text
			b.text:SetTextColor(c[1], c[2], c[3])
			local media = f.media
			if media == "statusbar" or media == "background" then
				b.sample:SetTexture(YaHT:GetMedia(media, key))
				b.sample:Show()
			else
				b.sample:Hide()
			end
			b:Show()
		end
	end
end

function Menu.OpenList(anchor, values, sorting, current, media, pick)
	list = list or BuildList()
	local keys = {}
	if sorting then
		for _, k in ipairs(sorting) do if values[k] ~= nil then keys[#keys + 1] = k end end
	else
		for k in pairs(values) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(values[a]):lower() < tostring(values[b]):lower() end)
	end
	list.keys, list.values, list.current, list.media, list.pick, list.offset = keys, values, current, media, pick, 0
	-- start with the current choice in view
	for i, k in ipairs(keys) do
		if k == current then list.offset = math.max(0, math.min(i - 1, #keys - LIST_ROWS)) end
	end
	list:ClearAllPoints()
	list:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	list:SetSize(math.max(180, anchor:GetWidth()), math.min(#keys, LIST_ROWS) * 20 + 8)
	Menu.DrawList()
	list.catcher:Show()
	list:Show()
end

function Menu.List() return list end

function Menu.CloseList()
	if list then
		list:Hide()
		list.catcher:Hide()
		list.pick = nil
	end
end

---------------------------------------------------------------------------
-- Rows: one per setting
---------------------------------------------------------------------------
-- reserve: the width kept free on the right for the row's control
-- bare: no plate behind it (a button is its own shape)
local function NewRow(parent, reserve, bare)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_STEP)
	-- the row's plate; the label and the control sit on it
	row.plate = Plate(row, "BACKGROUND", C.plate)
	row.plate:SetPoint("TOPLEFT", row, "TOPLEFT", BOX_PAD, 0)
	row.plate:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(MARK_W + BOX_PAD), ROW_GAP)
	row.hover = Plate(row, "BORDER", C.hover)
	row.hover:SetAllPoints(row.plate)
	row.hover:Hide()
	if bare then
		row.plate:SetAlpha(0)
		row.hover:SetAlpha(0)
	end
	row.label = Text(row, "GameFontHighlight", C.text)
	row.label:SetPoint("LEFT", row.plate, "LEFT", PAD, 0)
	row.label:SetPoint("RIGHT", row.plate, "RIGHT", -(PAD + (reserve or 0) + 10), 0)
	row.label:SetWordWrap(false)
	row:EnableMouse(true)
	On(row, "OnEnter", function(self)
		self.hover:Show()
		ShowTip(self)
	end)
	On(row, "OnLeave", function(self)
		self.hover:Hide()
		HideTip()
	end)
	return row
end

-- the control inside a row shows the row's tooltip and highlight too
local function Hook(row, widget)
	On(widget, "OnEnter", function() row.hover:Show() ShowTip(row) end)
	On(widget, "OnLeave", function() row.hover:Hide() HideTip() end)
end

-- A small picture in front of the switches people look for most, so they are found at a glance
-- without reading: the spell's own icon (asked from the game), else a stand-in. It is in colour
-- while the switch is on and grey while it is off.
local SWITCH_PICTURES = {
	aspect = {spell = 13165, file = "Interface\\Icons\\Spell_Nature_RavenForm"},
	feign = {spell = 5384, file = "Interface\\Icons\\Ability_Rogue_FeignDeath"},
	pet = {spell = 883, file = "Interface\\Icons\\Ability_Hunter_BeastCall"},
	hawk = {spell = 1293241, file = "Interface\\Icons\\Spell_Nature_RavenForm"},
	meleerange = {spell = 1130, file = "Interface\\Icons\\Ability_Hunter_SniperShot"},
	melee = {spell = 2973, file = "Interface\\Icons\\Ability_MeleeDamage"},
	ammo = {file = "Interface\\Icons\\INV_Ammo_Arrow_02"},
	multicast = {spell = 2643, file = "Interface\\Icons\\Ability_UpgradeMoonGlaive"},
	minimap = {file = "Interface\\Icons\\INV_Weapon_Bow_07"},
	mongoose = {spell = 1495, file = "Interface\\Icons\\Ability_Hunter_SwiftStrike"},
	quickshots = {spell = 6150, file = "Interface\\Icons\\Ability_Warrior_InnerRage"},
	rapidfire = {spell = 3045, file = "Interface\\Icons\\Ability_Hunter_RunningShot"},
	bestial = {spell = 19574, file = "Interface\\Icons\\Ability_Druid_FerociousBite"},
	racial = {spell = 20572, file = "Interface\\Icons\\Racial_Orc_BerserkerStrength"},
	-- the switch for every icon's polished look shows what it does: its picture wears the frame while it is on
	polishall = {spell = 3045, file = "Interface\\Icons\\Ability_Hunter_RunningShot", polished = true},
	-- and the switch for every icon's shape: its picture is round while it is on, square while it is off
	roundall = {spell = 6197, file = "Interface\\Icons\\Ability_Hunter_EagleEye", round = true}, -- (Eagle Eye: reads well square and round)
}

local function SwitchPicture(key)
	local def = key and SWITCH_PICTURES[key]
	if not def then return nil end
	if def.tex == nil then
		local tex
		-- your own race's active, as the racial alert shows it
		local racial = key == "racial" and YaHT.racialFrame and YaHT.racialFrame.icon
		if racial and type(racial.GetTexture) == "function" then
			local ok, v = pcall(racial.GetTexture, racial)
			if ok and v and not (issecretvalue and issecretvalue(v)) then tex = v end
		end
		if not tex and def.spell and C_Spell and C_Spell.GetSpellTexture then
			local ok, v = pcall(C_Spell.GetSpellTexture, def.spell)
			if ok and v and not (issecretvalue and issecretvalue(v)) then tex = v end
		end
		def.tex = tex or def.file
	end
	return def
end

Make.toggle = function(parent)
	local row = NewRow(parent, 36)
	row.picRim = row:CreateTexture(nil, "ARTWORK", nil, -1)
	row.picRim:SetColorTexture(0, 0, 0, 1)
	row.pic = row:CreateTexture(nil, "ARTWORK")
	row.pic:SetSize(20, 20)
	row.pic:SetPoint("LEFT", row.plate, "LEFT", PAD - 2, 0)
	row.pic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.picRim:SetPoint("TOPLEFT", row.pic, "TOPLEFT", -1, 1)
	row.picRim:SetPoint("BOTTOMRIGHT", row.pic, "BOTTOMRIGHT", 1, -1)
	row.picGloss = row:CreateTexture(nil, "ARTWORK", nil, 1)
	row.picGloss:SetTexture(SQGLOSS_TEX)
	row.picGloss:SetBlendMode("ADD")
	row.picGloss:SetAllPoints(row.pic)
	row.picFrame = row:CreateTexture(nil, "ARTWORK", nil, 2)
	row.picFrame:SetTexture(SQRING_TEX)
	row.picFrame:SetVertexColor(0.85, 0.70, 0.42)
	row.picFrame:SetPoint("TOPLEFT", row.pic, "TOPLEFT", -1, 1)
	row.picFrame:SetPoint("BOTTOMRIGHT", row.pic, "BOTTOMRIGHT", 1, -1)
	row.picRing = row:CreateTexture(nil, "ARTWORK", nil, 2)
	row.picRing:SetTexture(RINGFLAT_TEX)
	row.picRing:SetVertexColor(0.85, 0.70, 0.42)
	row.picRing:SetPoint("TOPLEFT", row.pic, "TOPLEFT", -2, 2)
	row.picRing:SetPoint("BOTTOMRIGHT", row.pic, "BOTTOMRIGHT", 2, -2)
	if type(row.CreateMaskTexture) == "function" then
		local ok, mask = pcall(row.CreateMaskTexture, row)
		if ok and mask and pcall(function()
			mask:SetTexture(DISC_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(row.pic)
		end) then row.picMask = mask end
	end
	row.pic:Hide() row.picRim:Hide() row.picGloss:Hide() row.picFrame:Hide() row.picRing:Hide()
	local b = CreateFrame("Button", nil, row)
	b:SetSize(36, 18)
	b:SetPoint("RIGHT", row.plate, "RIGHT", -PAD, 0)
	b.bg = Plate(b, "BACKGROUND", C.soft)
	b.bg:SetAllPoints(b)
	b.knob = Dot(b, "ARTWORK", C.muted)
	b.knob:SetSize(14, 14)
	On(b, "OnClick", function() if row.onClick then row.onClick() end end)
	On(row, "OnMouseUp", function() if not row.off and row.onClick then row.onClick() end end)
	Hook(row, b)
	row.widget = b
	-- "Edit": a switch that has a page of its own (Home, Alerts, Procs) leads straight to it
	-- (a small gear: quiet until you point at it, then gold, with a line of help)
	local e = CreateFrame("Button", nil, row)
	e:SetSize(22, 22)
	e:SetPoint("RIGHT", b, "LEFT", -8, 0)
	e.icon = e:CreateTexture(nil, "ARTWORK")
	e.icon:SetTexture(GEAR_TEX)
	e.icon:SetSize(15, 15)
	e.icon:SetPoint("CENTER", e, "CENTER", 0, 0)
	e.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.85)
	On(e, "OnClick", function() if row.editPage then Menu.Show(row.editPage) end end)
	On(e, "OnEnter", function(self)
		self.icon:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
		self.icon:SetSize(17, 17)
		row.hover:Show()
		SetHelp(row.tipTitle, L["Opens this feature's own page, with all of its settings."])
	end)
	On(e, "OnLeave", function(self)
		self.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.85)
		self.icon:SetSize(15, 15)
		row.hover:Hide()
		HideTip()
	end)
	e:Hide()
	row.edit = e
	return row
end
-- the page a switch's feature has to itself, if any (and it is not the page you are on)
local EDIT_PAGE = {meleerange = "alerts/rangepage"}
local function EditPage(key)
	if type(key) ~= "string" then return nil end
	local id = EDIT_PAGE[key]
	if not (id and pageById[id]) then id = "alerts/" .. key .. "page" end
	if not pageById[id] then id = "alerts/procspage/" .. key .. "page" end
	if pageById[id] and id ~= Menu.current then return id end
end
Fill.toggle = function(row, item)
	local on = Call(item.path, "get") and true or false
	local b = row.widget
	row.on = on
	Paint(b.bg, on and C.goldDim or C.soft)
	Paint(b.knob, on and C.white or C.muted)
	b.knob:ClearAllPoints()
	if on then b.knob:SetPoint("RIGHT", b, "RIGHT", -2, 0) else b.knob:SetPoint("LEFT", b, "LEFT", 2, 0) end
	row.onClick = function()
		Call(item.path, "set", not on)
		Menu.Changed()
	end
	-- its picture, when it has one (rows are reused, so it is set or cleared every time)
	local def = SwitchPicture(item.path and item.path[#item.path].key)
	local pic = def ~= nil
	local framed = pic and def.polished and on or false
	local rounded = pic and def.round and on or false
	row.pic:SetShown(pic)
	row.picRim:SetShown(pic and not framed and not rounded)
	row.picRing:SetShown(rounded)
	if row.picMask then
		if rounded and not row.picMasked then
			row.picMasked = pcall(row.pic.AddMaskTexture, row.pic, row.picMask) or nil
		elseif not rounded and row.picMasked then
			pcall(row.pic.RemoveMaskTexture, row.pic, row.picMask)
			row.picMasked = nil
		end
	end
	row.picGloss:SetShown(framed)
	row.picFrame:SetShown(framed)
	if pic then
		row.pic:SetTexture(def.tex)
		-- grey while the switch is off; the polish switch shows the flat look instead, in colour
		local grey = not on and not def.polished and not def.round
		if row.pic.SetDesaturated then row.pic:SetDesaturated(grey) end
		row.pic:SetAlpha(grey and 0.75 or 1)
	end
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", row.plate, "LEFT", PAD + (pic and 26 or 0), 0)
	row.editPage = EditPage(item.path and item.path[#item.path].key)
	row.edit:SetShown(row.editPage ~= nil)
	row.label:SetPoint("RIGHT", row.plate, "RIGHT", -(PAD + 36 + 10 + (row.editPage and 30 or 0)), 0)
	return ROW_STEP
end

local function FormatNumber(opt, x)
	if opt.isPercent then return string.format("%d%%", math.floor(x * 100 + 0.5)) end
	local step = opt.step or 1
	if step >= 1 then return string.format("%d", math.floor(x + 0.5)) end
	return string.format(step < 0.1 and "%.2f" or "%.1f", x)
end

-- A slider row: drag the slider, nudge it one step with the small arrows, or
-- double-click the number to type a value.
local ARROW_W, VALUE_W = 16, 46
Make.range = function(parent)
	local row = NewRow(parent, SLIDER_W + 8 + VALUE_W + 4 + ARROW_W)
	-- the two arrows, stacked at the right edge
	local function arrow(dir, y)
		local b = CreateFrame("Button", nil, row)
		b:SetSize(ARROW_W, ROW_H / 2 - 1)
		b:SetPoint("RIGHT", row.plate, "RIGHT", -PAD, y)
		b.bars = Arrow(b, dir)
		On(b, "OnClick", function() if row.onNudge then row.onNudge(dir) end end)
		On(b, "OnEnter", function(self)
			TintArrow(self.bars, C.gold)
			row.hover:Show()
			ShowTip(row)
		end)
		On(b, "OnLeave", function(self)
			TintArrow(self.bars, C.muted)
			row.hover:Hide()
			HideTip()
		end)
		return b
	end
	row.up = arrow(1, 7)
	row.down = arrow(-1, -7)
	-- the number; double-click it to type
	row.value = Text(row, "GameFontHighlightSmall", C.white)
	row.value:SetPoint("RIGHT", row.plate, "RIGHT", -(PAD + ARROW_W + 4), 0)
	row.value:SetWidth(VALUE_W)
	row.value:SetJustifyH("RIGHT")
	local vb = CreateFrame("Button", nil, row)
	vb:SetSize(VALUE_W, ROW_H - 6)
	vb:SetPoint("RIGHT", row.value, "RIGHT", 0, 0)
	row.valueBtn = vb
	local e = CreateFrame("EditBox", nil, row)
	e:SetSize(VALUE_W + 4, 18)
	e:SetPoint("RIGHT", row.value, "RIGHT", 2, 0)
	Plate(e, "BACKGROUND", C.field):SetAllPoints(e)
	Rim(e, C.line)
	e:SetFontObject(GameFontHighlightSmall)
	e:SetAutoFocus(false)
	e:SetTextInsets(3, 3, 0, 0)
	e:SetJustifyH("RIGHT")
	e:Hide()
	row.edit = e
	local function stopTyping()
		e:Hide()
		row.value:Show()
	end
	On(vb, "OnDoubleClick", function()
		if row.off or not row.typed then return end
		e:SetText(row.typed())
		row.value:Hide()
		e:Show()
		e:SetFocus()
		e:HighlightText()
	end)
	Hook(row, vb)
	On(e, "OnEnterPressed", function(self)
		local text = self:GetText() or ""
		stopTyping()
		self:ClearFocus()
		if row.onType then row.onType(text) end
	end)
	On(e, "OnEscapePressed", function(self)
		stopTyping()
		self:ClearFocus()
	end)
	On(e, "OnEditFocusLost", stopTyping)

	local s = CreateFrame("Slider", nil, row)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(SLIDER_W, 14)
	s:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
	s.track = Tex(s, "BACKGROUND", C.soft)
	s.track:SetPoint("LEFT", s, "LEFT")
	s.track:SetPoint("RIGHT", s, "RIGHT")
	s.track:SetHeight(4)
	s.fill = Tex(s, "BORDER", C.goldDim)
	s.fill:SetPoint("LEFT", s, "LEFT")
	s.fill:SetHeight(4)
	s:SetThumbTexture(DOT_TEX)
	local thumb = s:GetThumbTexture()
	if thumb then
		thumb:SetSize(14, 14)
		thumb:SetVertexColor(C.gold[1], C.gold[2], C.gold[3])
	end
	s:EnableMouse(true)
	On(s, "OnValueChanged", function(self, value)
		if self.silent or not row.onSlide then return end
		row.onSlide(value)
	end)
	-- the page is only redrawn once you let go, so the drag isn't interrupted
	On(s, "OnMouseUp", function() if row.onDone then row.onDone() end end)
	Hook(row, s)
	row.widget = s
	row.extras = {row.up, row.down, vb}
	return row
end
Fill.range = function(row, item)
	local opt, s = item.opt, row.widget
	local min, max, step = opt.min or 0, opt.max or 100, opt.step or 0
	local nudge = step > 0 and step or (max - min) / 100
	-- a typed value may be finer than the slider's steps: whole percents, whole numbers, or hundredths
	local fine = opt.isPercent and 0.01 or (nudge >= 1 and 1 or math.min(nudge, 0.01))
	local v = tonumber(Call(item.path, "get")) or min
	v = math.min(max, math.max(min, v))
	local function show(x)
		row.value:SetText(FormatNumber(opt, x))
		s.fill:SetWidth(math.max(1, SLIDER_W * (x - min) / math.max(max - min, 1e-9)))
	end
	local function snap(x, grid)
		x = math.floor((x - min) / grid + 0.5) * grid + min
		return math.min(max, math.max(min, x))
	end
	row.edit:Hide()
	row.value:Show()
	s.silent = true
	s:SetMinMaxValues(min, max)
	s:SetValueStep(nudge)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	s:SetValue(v)
	s.silent = false
	show(v)
	row.last = v
	row.tip = (row.tip and (row.tip .. "\n\n") or "") .. L["Double-click the number to type a value."]
	row.onSlide = function(x)
		x = snap(x, nudge)
		if x == row.last then return end
		row.last = x
		Call(item.path, "set", x)
		show(x)
		Menu.DrawPreview()
	end
	row.onDone = function() Menu.Changed() end
	-- the arrows: one step up or down
	row.onNudge = function(dir)
		local x = snap(row.last + dir * nudge, nudge)
		if x == row.last then return end
		Call(item.path, "set", x)
		Menu.Changed()
	end
	-- typing: what the box starts with, and what happens with what you typed
	row.typed = function()
		local x = opt.isPercent and row.last * 100 or row.last
		local text = string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", "")
		return text
	end
	row.onType = function(text)
		local n = tonumber((text:gsub("%%", ""):gsub(",", "."):gsub("%s", "")))
		if not n then return end
		if opt.isPercent then n = n / 100 end
		local x = snap(math.min(max, math.max(min, n)), fine)
		if x == row.last then return end
		Call(item.path, "set", x)
		Menu.Changed()
	end
	return ROW_STEP
end

Make.select = function(parent)
	local row = NewRow(parent, 190)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(190, 22)
	b:SetPoint("RIGHT", row.plate, "RIGHT", -PAD, 0)
	Plate(b, "BACKGROUND", C.field):SetAllPoints(b)
	Rim(b, C.soft)
	b.text = Text(b, "GameFontHighlightSmall", C.white)
	b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
	b.text:SetPoint("RIGHT", b, "RIGHT", -20, 0)
	b.text:SetWordWrap(false)
	b.arrow = Arrow(b, -1, 190 / 2 - 12, 0)
	On(b, "OnClick", function() if row.onClick then row.onClick() end end)
	Hook(row, b)
	row.widget = b
	return row
end
Fill.select = function(row, item)
	local values = Value(item.path, "values") or {}
	local current = Call(item.path, "get")
	local shown = values[current]
	row.widget.text:SetText(shown ~= nil and tostring(shown) or "")
	row.values = values
	row.onPick = function(key)
		Call(item.path, "set", key)
		Menu.Changed()
	end
	row.onClick = function()
		if list and list:IsShown() and list.owner == row then return Menu.CloseList() end
		Menu.OpenList(row.widget, values, Value(item.path, "sorting"), current, MEDIA_OF[item.path[#item.path].key], row.onPick)
		list.owner = row
	end
	return ROW_STEP
end

Make.color = function(parent)
	local row = NewRow(parent, 36)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(36, 18)
	b:SetPoint("RIGHT", row.plate, "RIGHT", -PAD, 0)
	b.swatch = Plate(b, "ARTWORK", C.white)
	b.swatch:SetAllPoints(b)
	Rim(b, C.line, "OVERLAY")
	On(b, "OnClick", function() if row.onClick then row.onClick() end end)
	Hook(row, b)
	row.widget = b
	return row
end
Fill.color = function(row, item)
	local r, g, b = Call(item.path, "get")
	Paint(row.widget.swatch, {r or 1, g or 1, b or 1, 1})
	row.onClick = function() PickColor(item.path) end
	return ROW_STEP
end

Make.execute = function(parent)
	local row = NewRow(parent, 0, true)
	row.label:Hide()
	local b = CreateFrame("Button", nil, row)
	b:SetHeight(24)
	b:SetPoint("LEFT", row.plate, "LEFT", 0, 0)
	b.bg = Plate(b, "BACKGROUND", C.plate)
	b.bg:SetAllPoints(b)
	Rim(b, C.line)
	b.text = Text(b, "GameFontHighlightSmall", C.white)
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	On(b, "OnClick", function() if row.onClick then row.onClick() end end)
	On(b, "OnEnter", function(self)
		Paint(self.bg, C.navOn)
		ShowTip(row)
	end)
	On(b, "OnLeave", function(self)
		Paint(self.bg, C.plate)
		HideTip()
	end)
	row.widget = b
	return row
end
Fill.execute = function(row, item)
	local b = row.widget
	b.text:SetText(row.tipTitle or "")
	b:SetWidth(math.max(130, (b.text:GetStringWidth() or 0) + 32))
	row.onClick = function()
		local function run()
			Call(item.path, "func")
			Menu.Changed()
		end
		local confirm = Value(item.path, "confirm")
		if confirm then
			local text = type(confirm) == "string" and confirm or Value(item.path, "confirmText") or row.tipTitle
			Confirm(text, run)
		else
			run()
		end
	end
	return ROW_STEP
end

Make.input = function(parent)
	local row = NewRow(parent, 230)
	local e = CreateFrame("EditBox", nil, row)
	e:SetSize(230, 22)
	e:SetPoint("RIGHT", row.plate, "RIGHT", -PAD, 0)
	Plate(e, "BACKGROUND", C.field):SetAllPoints(e)
	Rim(e, C.soft)
	e:SetFontObject(GameFontHighlightSmall)
	e:SetAutoFocus(false)
	e:SetTextInsets(8, 8, 0, 0)
	local function commit(self)
		local text = self:GetText() or ""
		if row.onText and text ~= row.shownText then row.onText(text) end
	end
	On(e, "OnEnterPressed", function(self) self:ClearFocus() end)
	On(e, "OnEscapePressed", function(self)
		self:SetText(row.shownText or "")
		self:ClearFocus()
	end)
	On(e, "OnEditFocusLost", commit)
	Hook(row, e)
	row.widget = e
	return row
end
Fill.input = function(row, item)
	local text = Call(item.path, "get")
	text = type(text) == "string" and text or ""
	row.shownText = text
	row.widget:SetText(text)
	row.onText = function(new)
		row.shownText = new
		Call(item.path, "set", new)
		Menu.Changed()
	end
	return ROW_STEP
end

-- plain text across the page (descriptions, and the notes on Home)
local NOTE_X = BOX_PAD + 4
local function MakeNote(template, color, pad)
	return function(parent)
		local row = CreateFrame("Frame", nil, parent)
		row.text = Text(row, template, color)
		row.text:SetPoint("TOPLEFT", row, "TOPLEFT", NOTE_X, -pad)
		row.text:SetWidth(VIEW_W - MARK_W - 2 * NOTE_X)
		row.text:SetJustifyV("TOP")
		row.text:SetWordWrap(true)
		if row.text.SetSpacing then row.text:SetSpacing(3) end
		row.pad = pad
		return row
	end
end
local function FillNote(row, text)
	row.text:SetText(text or "")
	return math.max(14, row.text:GetStringHeight() or 14) + 2 * row.pad
end
Make.description = MakeNote("GameFontHighlight", C.muted, 6)
Fill.description = function(row, item) return FillNote(row, Value(item.path, "name")) end
Make.note = MakeNote("GameFontHighlight", C.muted, 6)
Fill.note = function(row, item) return FillNote(row, item.text) end
Make.title = MakeNote("GameFontNormalLarge", C.white, 8)
Fill.title = function(row, item) return FillNote(row, item.text) end

-- a section's name, at the top of the box that holds its settings
local SECTION_H = 32
local function MakeSection(parent)
	local row = CreateFrame("Frame", nil, parent)
	row.text = Text(row, "GameFontNormal", C.gold)
	row.text:SetPoint("LEFT", row, "LEFT", NOTE_X, -1)
	return row
end
Make.header = MakeSection
Fill.header = function(row, item)
	row.text:SetText(Value(item.path, "name") or "")
	return SECTION_H
end
Make.section = MakeSection
Fill.section = function(row, item)
	row.text:SetText(item.text or "")
	return SECTION_H
end

-- The quick looks as cards, each with a small live preview of what it does:
-- your bar (texture and colours) running through a shot, with that look's
-- glow, light sweep and sparks. Shown on Home and on The bar page.
local function IsLookInUse(name)
	local preset = YaHT.presets and YaHT.presets[name]
	if not preset then return false end
	local p = YaHT.db.profile
	for k, v in pairs(preset) do
		-- Flashy takes the WeakAuras pixel glow instead of the sweep when it is available
		if p[k] ~= v and not (name == "FLASHY" and k == "glowstyle" and p[k] == "PIXEL") then return false end
	end
	return true
end

-- (the live preview's own code, further down, also draws the small preview on each card)
local BuildPreview, LayoutPreview

-- what stands under each card's preview: one short line (the full text shows in the help column)
local CARD_LINE = {
	presetminimal = L["Just the bar."],
	presetclean = L["The bar with its icons."],
	presetflashy = L["Everything, with every effect."],
}

Make.cards = function(parent)
	local row = CreateFrame("Frame", nil, parent)
	row.cards = {}
	local gap = 10
	local w = (VIEW_W - MARK_W - 2 * BOX_PAD - 2 * gap) / 3
	local scale = (w - 12) / PREVIEW_BOX_W -- the live preview, drawn this much smaller
	for i = 1, 3 do
		local b = CreateFrame("Button", nil, row)
		b:SetSize(w, CARD_H)
		b:SetPoint("TOPLEFT", row, "TOPLEFT", BOX_PAD + (i - 1) * (w + gap), 0)
		b.bg = Plate(b, "BACKGROUND", C.plate)
		b.bg:SetAllPoints(b)
		b.edge = Rim(b, C.soft)
		-- the look itself: a small copy of the live preview, your bar and icons with this look's settings
		b.stage = Plate(b, "BORDER", C.preview)
		b.stage:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -6)
		b.stage:SetSize(w - 12, CARD_STAGE_H)
		b.strip = CreateFrame("Frame", nil, b)
		b.strip:SetScale(scale)
		b.strip:SetSize(PREVIEW_BOX_W, CARD_STAGE_H / scale)
		b.strip:SetPoint("TOPLEFT", b, "TOPLEFT", 6 / scale, -6 / scale)
		if b.strip.SetClipsChildren then b.strip:SetClipsChildren(true) end
		b.pv = BuildPreview(b.strip)
		b.pv.mini = true
		b.pv.phase:Hide()
		b.name = Text(b, "GameFontHighlight", C.white)
		b.name:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -(CARD_STAGE_H + 13))
		b.tag = Text(b, "GameFontHighlightSmall", C.gold)
		b.tag:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10, -(CARD_STAGE_H + 14))
		b.desc = Text(b, "GameFontHighlightSmall", C.muted)
		b.desc:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
		b.desc:SetWidth(w - 20)
		b.desc:SetWordWrap(true)
		b.desc:SetJustifyV("TOP")
		if b.desc.SetSpacing then b.desc:SetSpacing(2) end
		local function tint(self, hover)
			local c = (hover or self.current or self.viewing) and C.gold or C.soft
			PaintRim(self.edge, c)
		end
		b.tint = tint
		On(b, "OnClick", function(self) if self.onClick then self.onClick() end end)
		On(b, "OnEnter", function(self)
			tint(self, true)
			if self.helpTitle then SetHelp(self.helpTitle, self.helpText) end
		end)
		On(b, "OnLeave", function(self)
			tint(self, false)
			HideTip()
		end)
		row.cards[i] = b
	end
	-- while a look is being viewed: a line that says so, with "Use this look" and "Cancel"
	row.viewBar = CreateFrame("Frame", nil, row)
	row.viewBar:SetHeight(26)
	row.viewBar:SetPoint("TOPLEFT", row, "TOPLEFT", BOX_PAD, -(CARD_H + 6))
	row.viewBar:SetPoint("RIGHT", row, "RIGHT", -(MARK_W + BOX_PAD), 0)
	local function button(text, wide)
		local bt = CreateFrame("Button", nil, row.viewBar)
		bt:SetSize(wide, 24)
		bt.bg = Plate(bt, "BACKGROUND", C.plate)
		bt.bg:SetAllPoints(bt)
		Rim(bt, C.line)
		bt.text = Text(bt, "GameFontHighlightSmall", C.white)
		bt.text:SetPoint("CENTER", bt, "CENTER", 0, 0)
		bt.text:SetText(text)
		On(bt, "OnClick", function(self) if self.onClick then self.onClick() end end)
		On(bt, "OnEnter", function(self) Paint(self.bg, C.navOn) end)
		On(bt, "OnLeave", function(self) Paint(self.bg, C.plate) end)
		return bt
	end
	row.cancel = button(L["Cancel"], 80)
	row.cancel:SetPoint("RIGHT", row.viewBar, "RIGHT", 0, 0)
	row.use = button(L["Use this look"], 130)
	row.use:SetPoint("RIGHT", row.cancel, "LEFT", -8, 0)
	row.viewText = Text(row.viewBar, "GameFontHighlightSmall", C.gold)
	row.viewText:SetPoint("LEFT", row.viewBar, "LEFT", 4, 0)
	row.viewBar:Hide()
	return row
end

Fill.cards = function(row)
	local profile = YaHT.db.profile
	local viewName, viewPath
	for i, key in ipairs(HOME_CARDS) do
		local b, path = row.cards[i], Find({"bar", key})
		if path then
			b.look = CARD_LOOK[key]
			-- your own bar and icons, with this look's settings laid over yours
			LayoutPreview(b.pv, setmetatable(YaHT:LookValues(b.look.preset), {__index = profile}))
			b.name:SetText(Value(path, "name") or "")
			b.desc:SetText(CARD_LINE[key] or "")
			b.helpTitle, b.helpText = Value(path, "name"), Value(path, "desc")
			b.current = IsLookInUse(b.look.preset)
			b.viewing = Menu.viewing == b.look.preset
			b.tag:SetText(b.viewing and L["Viewing"] or L["In use"])
			b.tag:SetShown(b.current or b.viewing)
			b.tint(b, false)
			if b.viewing then viewName, viewPath = Value(path, "name"), path end
			-- a click shows the look in the live preview; nothing changes until "Use this look"
			b.onClick = function()
				if b.viewing or b.current then Menu.viewing = nil else Menu.viewing = b.look.preset end
				Menu.Changed()
			end
			b:Show()
		else
			b:Hide()
		end
	end
	-- a look is being viewed: say so, and offer to keep it
	row.viewBar:SetShown(viewPath ~= nil)
	if viewPath then
		row.viewText:SetText(string.format(L["Viewing %s. Nothing has changed yet."], viewName or ""))
		row.use.onClick = function()
			Menu.viewing = nil
			Call(viewPath, "func")
			Menu.Changed()
		end
		row.cancel.onClick = function()
			Menu.viewing = nil
			Menu.Changed()
		end
		return CARD_H + ROW_GAP + 34
	end
	return CARD_H + ROW_GAP
end

---------------------------------------------------------------------------
-- Drawing the page
---------------------------------------------------------------------------
local function ReleaseAll()
	for i = #live, 1, -1 do
		local row = live[i]
		row:Hide()
		row:ClearAllPoints()
		local free = pool[row.kind]
		free[#free + 1] = row
		live[i] = nil
	end
end

local function Acquire(kind)
	pool[kind] = pool[kind] or {}
	local row = table.remove(pool[kind]) or Make[kind](content)
	row.kind = kind
	row:Show()
	return row
end

local function ClampScroll()
	local max = math.max(0, contentH - VIEW_H)
	Menu.scrollY = math.min(max, math.max(0, Menu.scrollY or 0))
	scroll:SetVerticalScroll(Menu.scrollY)
	-- the thin marker on the right shows there is more below
	local bar = frame.scrollMark
	if max <= 0 then
		bar:Hide()
	else
		local h = math.max(24, VIEW_H * VIEW_H / contentH)
		bar:SetHeight(h)
		bar:ClearAllPoints()
		bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -2, -(VIEW_H - h) * Menu.scrollY / max)
		bar:Show()
	end
end

local function SetOff(row, off)
	row.off = off
	row:SetAlpha(off and 0.4 or 1)
	if row.widget then row.widget:EnableMouse(not off) end
	for _, extra in ipairs(row.extras or {}) do extra:EnableMouse(not off) end
end

-- settings sit in a box: under their section's heading, or in one of their own
local BOXED = {toggle = true, range = true, select = true, color = true, input = true, cards = true}

function Menu.Render()
	if not frame or not frame:IsShown() then return end
	Menu.CloseList()
	ReleaseAll()
	local page = pageById[Menu.current] or pages[1]
	local searching = Menu.query ~= nil and #Menu.query >= 2
	local intro, lead = {}, not searching -- a page's opening paragraphs go to the help column
	local y, used, box, boxTop = -2, 0, nil, 0
	local function endBox()
		if not box then return end
		box:SetSize(VIEW_W - MARK_W, boxTop - y + BOX_PAD - ROW_GAP)
		y = y - (BOX_PAD - ROW_GAP) - BOX_GAP
		box = nil
	end
	local function startBox(pad)
		used = used + 1
		box = frame.boxes[used]
		if not box then
			box = Plate(content, "BACKGROUND", C.panel)
			frame.boxes[used] = box
		end
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
		box:Show()
		boxTop = y
		y = y - pad
	end
	for _, item in ipairs(Menu.Items()) do
		local kind = item.custom or item.opt.type
		if item.path and Flag(item.path, "hidden") then
			-- doesn't apply right now
		elseif kind == "gap" then
			lead = false
			if box then endBox() else y = y - BOX_GAP end
		elseif kind == "description" and item.path[#item.path].key == "about" then
			-- the credits: at the foot of the help column instead
		elseif lead and kind == "description" then
			local text = Value(item.path, "name")
			if type(text) == "string" and text ~= "" then intro[#intro + 1] = text end
			lead = false -- only the opening paragraph; later ones belong to what follows them
		elseif Make[kind] then
			lead = false
			if kind == "header" or kind == "section" then
				endBox()
				startBox(0)
			elseif kind == "title" or (kind == "execute" and item.path[#item.path].key == "reset") then
				endBox() -- (Reset this page is about the whole page, not its last section)
			elseif BOXED[kind] and not box then
				startBox(BOX_PAD)
			end
			local row = Acquire(kind)
			row.item = item
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
			row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
			if item.path then
				local name, desc = Value(item.path, "name"), Value(item.path, "desc")
				row.tipTitle = type(name) == "string" and name or ""
				row.tip = type(desc) == "string" and desc or nil
				if row.label then row.label:SetText(row.tipTitle) end
				SetOff(row, Flag(item.path, "disabled"))
			else
				row.tipTitle, row.tip = nil, nil
			end
			local h = Fill[kind](row, item)
			row:SetHeight(h)
			y = y - h
			live[#live + 1] = row
		end
	end
	endBox()
	for i = used + 1, #frame.boxes do frame.boxes[i]:Hide() end
	contentH = -y + 8
	content:SetHeight(contentH)
	ClampScroll()
	-- what the help column says while the mouse isn't on a setting
	local hint = L["Point at a setting to see what it does."]
	if searching then
		Menu.helpTitle, Menu.helpText = L["Search settings"], hint
	elseif not page.path then
		Menu.helpTitle = L["Welcome"]
		Menu.helpText = L["Pick a look, then switch alerts on or off. Everything else is optional."] .. "\n\n" .. hint
	else
		Menu.helpTitle = page.name
		Menu.helpText = #intro > 0 and table.concat(intro, "\n\n") or hint
	end
	HideTip()
	local about = Find({"bar", "about"})
	local credits = about and Value(about, "name")
	frame.help.foot:SetText(type(credits) == "string" and credits or "")
	Menu.DrawNav()
	Menu.DrawLock()
	Menu.DrawPreview()
end

Menu.Render = Guard(Menu.Render) -- also called from outside (a reset, a profile switch)

-- a setting changed: draw the page again (other settings may have become
-- available or greyed out) and let the preview follow
function Menu.Changed()
	Menu.Render()
end

function Menu.Show(id)
	Menu.current = pageById[id] and id or "home"
	Menu.viewing = nil -- (a look is viewed on the page where it was clicked)
	Menu.query = nil
	Menu.scrollY = 0
	if frame and frame.search and (frame.search:GetText() or "") ~= "" then
		frame.search.silent = true
		frame.search:SetText("")
		frame.search.silent = false
		frame.search.hint:Show()
	end
	Menu.Render()
end

function Menu.Search(text)
	text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	Menu.query = #text >= 2 and text or nil
	Menu.scrollY = 0
	Menu.Render()
end

---------------------------------------------------------------------------
-- The Lock bar switch in the header
---------------------------------------------------------------------------
local function FillHeadSwitch(b, name, tip, on, onClick)
	b.on = on
	b.tipTitle, b.tip = name, tip
	b.label:SetText(name)
	b:SetWidth((b.label:GetStringWidth() or 0) + 8 + 36)
	Paint(b.bg, on and C.goldDim or C.soft)
	Paint(b.knob, on and C.white or C.muted)
	b.knob:ClearAllPoints()
	if on then b.knob:SetPoint("RIGHT", b.bg, "RIGHT", -2, 0) else b.knob:SetPoint("LEFT", b.bg, "LEFT", 2, 0) end
	b.onClick = onClick
	b:Show()
end

function Menu.DrawLock()
	local path = Find({"bar", "lock"})
	if not path then
		frame.lock:Hide()
	else
		local on = Call(path, "get") and true or false
		local name, desc = Value(path, "name"), Value(path, "desc")
		FillHeadSwitch(frame.lock, type(name) == "string" and name or "", type(desc) == "string" and desc or nil, on, function()
			Call(path, "set", not on)
			Menu.Changed()
		end)
	end
	-- the alignment grid (grid.lua); not a saved setting, it stays on until switched off
	if YaHT.ToggleGrid then
		FillHeadSwitch(frame.grid, L["Grid"],
			L["Shows a grid over the whole screen, with the middle marked in gold, to line things up exactly. It stays on until you switch it off (also /yaht grid)."],
			YaHT:GridShown(), function() YaHT:ToggleGrid() end)
	else
		frame.grid:Hide()
	end
end

---------------------------------------------------------------------------
-- The list of pages on the left
---------------------------------------------------------------------------
function Menu.DrawNav()
	local current = pageById[Menu.current] or pages[1]
	local searching = Menu.query ~= nil
	local n = 0
	for _, page in ipairs(pages) do
		-- third-level pages (the single procs) only show inside their own section
		local open = page.depth < 3 or page.parent == current or (current.depth == 3 and current.parent == page.parent)
		if open then
			n = n + 1
			local b = frame.nav[n]
			if not b then
				b = CreateFrame("Button", nil, frame.navHolder)
				b:SetHeight(NAV_ROW)
				b:SetPoint("TOPLEFT", frame.navHolder, "TOPLEFT", 6, -8 - (n - 1) * NAV_ROW)
				b:SetPoint("RIGHT", frame.navHolder, "RIGHT", -6, 0)
				b.bg = Plate(b, "BACKGROUND", C.navOn)
				b.bg:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -1)
				b.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 1)
				b.mark = Tex(b, "ARTWORK", C.gold)
				b.mark:SetPoint("LEFT", b, "LEFT", 4, 0)
				b.mark:SetSize(2, NAV_ROW - 12)
				b.text = Text(b, "GameFontHighlightSmall", C.muted)
				-- ("Alerts" has no page of its own to show: its switches are on Home, so it opens its first page)
				On(b, "OnClick", function(self) Menu.Show(self.page == "alerts" and "alerts/procspage" or self.page) end)
				On(b, "OnEnter", function(self) if not self.on then self.text:SetTextColor(1, 1, 1) end end)
				On(b, "OnLeave", function(self)
					if not self.on then self.text:SetTextColor(self.rest[1], self.rest[2], self.rest[3]) end
				end)
				frame.nav[n] = b
			end
			b.page = page.id
			b.on = (page == current) and not searching
			b.rest = page.depth == 1 and C.text or C.muted
			b.text:ClearAllPoints()
			b.text:SetPoint("LEFT", b, "LEFT", 13 + (page.depth - 1) * 13, 0)
			if b.text.SetFontObject then
				b.text:SetFontObject(page.depth == 1 and GameFontHighlight or GameFontHighlightSmall)
			end
			b.text:SetText(page.name)
			local c = b.on and C.white or b.rest
			b.text:SetTextColor(c[1], c[2], c[3])
			b.bg:SetShown(b.on)
			b.mark:SetShown(b.on)
			b:Show()
		end
	end
	for i = n + 1, #frame.nav do frame.nav[i]:Hide() end
end

---------------------------------------------------------------------------
-- The live preview: a small copy of the bar and its icons, drawn from the
-- settings, looping through a shot. Only runs while the window is open.
---------------------------------------------------------------------------
local PREVIEW_ICONS = { -- key, a spell whose icon stands in for it; in the order they line up around the bar
	{"bestial", 19574}, {"mongoose", 1495}, {"quickshots", 6150}, {"rapidfire", 3045}, {"racial", 20572}, {"aspect", 13165},
}
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local HAWK_ICON = "Interface\\Icons\\Spell_Nature_RavenForm"
local HAWK_SAMPLE = {14, 5} -- the seconds the two sample hawks have left
local HAWK_GOLD, HAWK_RED = {1.0, 0.80, 0.30}, {1.0, 0.33, 0.28}
local HAWK_PLAIN_GOLD, HAWK_PLAIN_RED = {0.91, 0.70, 0.24}, {0.93, 0.30, 0.27}
local PROC_GOLD = {0.85, 0.70, 0.42} -- a proc icon's rim in the game

local function SpellTexture(id)
	local get = C_Spell and C_Spell.GetSpellTexture
	if not get then return FALLBACK_ICON end
	local ok, tex = pcall(get, id)
	if not ok or not tex or (issecretvalue and issecretvalue(tex)) then return FALLBACK_ICON end
	return tex
end

-- One square icon of the preview: a dark rim, a halo when its glow is on, the timer line that runs
-- down under it, and the parts of the polished look (shadow, gloss, bevelled frame, edge lines)
local function PreviewSquare(strip)
	local ic = {}
	ic.tex = strip:CreateTexture(nil, "ARTWORK")
	ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	ic.halo = strip:CreateTexture(nil, "BORDER")
	ic.halo:SetTexture(GLOW_TEX)
	ic.halo:SetBlendMode("ADD")
	ic.halo:SetPoint("TOPLEFT", ic.tex, "TOPLEFT", -7, 7)
	ic.halo:SetPoint("BOTTOMRIGHT", ic.tex, "BOTTOMRIGHT", 7, -7)
	ic.rim = strip:CreateTexture(nil, "ARTWORK", nil, -1)
	ic.rim:SetColorTexture(0, 0, 0, 1)
	ic.rim:SetPoint("TOPLEFT", ic.tex, "TOPLEFT", -1, 1)
	ic.rim:SetPoint("BOTTOMRIGHT", ic.tex, "BOTTOMRIGHT", 1, -1)
	ic.bar = Tex(strip, "ARTWORK", C.gold)
	ic.bar:SetPoint("TOPLEFT", ic.tex, "BOTTOMLEFT", 0, -3)
	ic.bar:SetHeight(3)
	ic.shadow = strip:CreateTexture(nil, "BORDER", nil, -3)
	ic.shadow:SetTexture(SQHALO_TEX)
	ic.shadow:SetVertexColor(0, 0, 0)
	ic.shadow:SetAlpha(0.7)
	ic.shadow:SetPoint("TOPLEFT", ic.tex, "TOPLEFT", -6, 5)
	ic.shadow:SetPoint("BOTTOMRIGHT", ic.tex, "BOTTOMRIGHT", 6, -7)
	ic.gloss = strip:CreateTexture(nil, "ARTWORK", nil, 1)
	ic.gloss:SetTexture(SQGLOSS_TEX)
	ic.gloss:SetBlendMode("ADD")
	ic.gloss:SetAllPoints(ic.tex)
	ic.frame = strip:CreateTexture(nil, "ARTWORK", nil, 2)
	ic.frame:SetTexture(SQRING_TEX)
	ic.frame:SetPoint("TOPLEFT", ic.tex, "TOPLEFT", -1, 1)
	ic.frame:SetPoint("BOTTOMRIGHT", ic.tex, "BOTTOMRIGHT", 1, -1)
	ic.line = strip:CreateTexture(nil, "ARTWORK", nil, 3)
	ic.line:SetTexture(SQLINE_TEX)
	ic.line:SetVertexColor(0, 0, 0)
	ic.line:SetAllPoints(ic.frame)
	-- the round shape: a dark disc, the ring (the timer), and for the polished look a shadow, a soft
	-- light and the ring's fine edge lines; the picture itself is cut round with a mask
	ic.rshadow = strip:CreateTexture(nil, "BORDER", nil, -3)
	ic.rshadow:SetTexture(HALO_TEX)
	ic.rshadow:SetVertexColor(0, 0, 0)
	ic.rshadow:SetAlpha(0.75)
	ic.rback = strip:CreateTexture(nil, "BORDER", nil, 1)
	ic.rback:SetTexture(DISC_TEX)
	ic.rback:SetVertexColor(0.05, 0.045, 0.04)
	ic.rgloss = strip:CreateTexture(nil, "ARTWORK", nil, 1)
	ic.rgloss:SetTexture(GLOSS_TEX)
	ic.rgloss:SetBlendMode("ADD")
	ic.rgloss:SetAllPoints(ic.tex)
	ic.rring = strip:CreateTexture(nil, "ARTWORK", nil, 2)
	ic.rline = strip:CreateTexture(nil, "ARTWORK", nil, 3)
	ic.rline:SetTexture(RINGLINE_TEX)
	ic.rline:SetVertexColor(0, 0, 0)
	if type(strip.CreateMaskTexture) == "function" then
		local ok, mask = pcall(strip.CreateMaskTexture, strip)
		if ok and mask and pcall(function()
			mask:SetTexture(DISC_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(ic.tex)
		end) then ic.mask = mask end
	end
	ic.rshadow:Hide() ic.rback:Hide() ic.rgloss:Hide() ic.rring:Hide() ic.rline:Hide()
	return ic
end

-- Shows a preview icon round (in its ring, in this colour) or takes the round parts away again.
-- size: the whole icon's, ring included (the picture inside was sized to 80% of it)
local function DressRound(ic, on, polished, size, c)
	if ic.mask then
		if on and not ic.masked then
			ic.masked = pcall(ic.tex.AddMaskTexture, ic.tex, ic.mask) or nil
		elseif not on and ic.masked then
			pcall(ic.tex.RemoveMaskTexture, ic.tex, ic.mask)
			ic.masked = nil
		end
	end
	ic.rback:SetShown(on)
	ic.rring:SetShown(on)
	ic.rshadow:SetShown(on and polished or false)
	ic.rgloss:SetShown(on and polished or false)
	ic.rline:SetShown(on and polished or false)
	if not on then return end
	local d = size * 0.1
	for _, part in ipairs({ic.rback, ic.rring, ic.rline}) do
		part:ClearAllPoints()
		part:SetPoint("TOPLEFT", ic.tex, "TOPLEFT", -d, d)
		part:SetPoint("BOTTOMRIGHT", ic.tex, "BOTTOMRIGHT", d, -d)
	end
	ic.rshadow:ClearAllPoints()
	ic.rshadow:SetPoint("TOPLEFT", ic.tex, "TOPLEFT", -d - 6, d + 5)
	ic.rshadow:SetPoint("BOTTOMRIGHT", ic.tex, "BOTTOMRIGHT", d + 6, -d - 7)
	ic.rring:SetTexture(polished and RING_TEX or RINGFLAT_TEX)
	ic.rring:SetVertexColor(c[1], c[2], c[3])
end

-- Shows a preview square in the standard look (its dark rim) or the polished one (its frame in
-- this colour), or not at all
local SQUARE_POLISH = {"shadow", "gloss", "frame", "line"}
local function DressSquare(ic, on, polished, c)
	ic.tex:SetShown(on)
	ic.rim:SetShown(on and not polished)
	for _, part in ipairs(SQUARE_POLISH) do ic[part]:SetShown(on and polished or false) end
	if on and polished and c then ic.frame:SetVertexColor(c[1], c[2], c[3]) end
end

BuildPreview = function(strip)
	local pv = CreateFrame("Frame", nil, strip)
	pv.box = strip
	pv:SetPoint("CENTER", strip, "CENTER", 0, PREVIEW_DY)
	-- behind the bar: a soft shadow on the stage, then the soft glow
	pv.shadow = pv:CreateTexture(nil, "BACKGROUND", nil, -2)
	pv.shadow:SetTexture(STAGE_TEX)
	pv.shadow:SetVertexColor(0, 0, 0, 0.7)
	pv.glow = pv:CreateTexture(nil, "BACKGROUND")
	pv.glow:SetTexture(GLOW_TEX)
	pv.glow:SetBlendMode("ADD")
	pv.glow:Hide()
	pv.back = pv:CreateTexture(nil, "BORDER")
	pv.back:SetAllPoints(pv)
	-- the bar itself; it clips the light sweep to its own shape
	pv.well = CreateFrame("Frame", nil, pv)
	pv.well:SetAllPoints(pv)
	if pv.well.SetClipsChildren then pv.well:SetClipsChildren(true) end
	pv.fill = pv.well:CreateTexture(nil, "ARTWORK")
	pv.shine = pv.well:CreateTexture(nil, "OVERLAY")
	pv.shine:SetTexture(SHINE_TEX)
	pv.shine:SetBlendMode("ADD")
	pv.shine:Hide()
	-- over the bar: its border, the outline glow and the sparks
	pv.over = CreateFrame("Frame", nil, pv)
	pv.over:SetAllPoints(pv)
	pv.over:SetFrameLevel(pv.well:GetFrameLevel() + 2)
	pv.edge = Outline(pv.over, C.white)
	pv.rimBox = CreateFrame("Frame", nil, pv.over)
	pv.rim = Outline(pv.rimBox, C.gold)
	pv.sparks = {}
	for n = 1, 2 do
		local spark = pv.over:CreateTexture(nil, "OVERLAY")
		spark:SetTexture(SPARK_TEX)
		spark:SetBlendMode("ADD")
		spark:Hide()
		pv.sparks[n] = spark
	end
	pv.num = Text(strip, "GameFontHighlightSmall", C.white)
	-- which part of the shot is showing
	pv.phase = Text(strip, "GameFontHighlight", C.muted)
	pv.phase:SetPoint("BOTTOM", strip, "BOTTOM", 0, 9)
	pv.phase:SetJustifyH("CENTER")
	-- the icons around the bar: a dark rim, a halo when its glow is on, and
	-- (for the procs) the gold timer line that runs down under it
	pv.icons = {}
	for i, def in ipairs(PREVIEW_ICONS) do
		local ic = PreviewSquare(strip)
		ic.key, ic.spell, ic.timed = def[1], def[2], def[1] ~= "aspect"
		pv.icons[i] = ic
	end
	-- the hawk circles: the Summon Hawk icon cut round, the ring around it and the seconds left
	pv.hawks = {}
	for i = 1, 2 do
		local hk = {}
		hk.shadow = strip:CreateTexture(nil, "BORDER", nil, -3)
		hk.shadow:SetTexture(HALO_TEX)
		hk.shadow:SetVertexColor(0, 0, 0)
		hk.shadow:SetAlpha(0.75)
		hk.halo = strip:CreateTexture(nil, "BORDER", nil, -2)
		hk.halo:SetTexture(HALO_TEX)
		hk.halo:SetBlendMode("ADD")
		hk.back = strip:CreateTexture(nil, "BORDER")
		hk.back:SetTexture(DISC_TEX)
		hk.back:SetVertexColor(0.05, 0.045, 0.04)
		hk.icon = strip:CreateTexture(nil, "ARTWORK")
		hk.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		hk.icon:SetPoint("CENTER", hk.back, "CENTER", 0, 0)
		if type(strip.CreateMaskTexture) == "function" then
			local ok, mask = pcall(strip.CreateMaskTexture, strip)
			if ok and mask then
				pcall(function()
					mask:SetTexture(DISC_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
					mask:SetAllPoints(hk.icon)
					hk.icon:AddMaskTexture(mask)
				end)
			end
		end
		hk.gloss = strip:CreateTexture(nil, "ARTWORK", nil, 1)
		hk.gloss:SetTexture(GLOSS_TEX)
		hk.gloss:SetBlendMode("ADD")
		hk.gloss:SetAllPoints(hk.icon)
		hk.ring = strip:CreateTexture(nil, "ARTWORK", nil, 2)
		hk.ring:SetTexture(RING_TEX)
		hk.ring:SetAllPoints(hk.back)
		hk.line = strip:CreateTexture(nil, "ARTWORK", nil, 3)
		hk.line:SetTexture(RINGLINE_TEX)
		hk.line:SetVertexColor(0, 0, 0)
		hk.line:SetAllPoints(hk.back)
		hk.shadow:SetPoint("CENTER", hk.back, "CENTER", 0, -1.5)
		hk.halo:SetPoint("CENTER", hk.back, "CENTER", 0, 0)
		hk.num = Text(strip, "GameFontHighlightSmall", C.white)
		hk.num:SetJustifyH("CENTER")
		hk.sq = PreviewSquare(strip) -- the same hawk in the square shape
		pv.hawks[i] = hk
	end
	pv.hawkBadge = strip:CreateTexture(nil, "ARTWORK", nil, 3)
	pv.hawkBadge:SetTexture(DISC_TEX)
	pv.hawkBadge:SetVertexColor(0.05, 0.045, 0.04)
	pv.hawkBadgeRim = strip:CreateTexture(nil, "ARTWORK", nil, 4)
	pv.hawkBadgeRim:SetTexture(RING_TEX)
	pv.hawkBadgeRim:SetVertexColor(HAWK_GOLD[1], HAWK_GOLD[2], HAWK_GOLD[3])
	pv.hawkBadgeRim:SetAllPoints(pv.hawkBadge)
	pv.hawkCount = Text(strip, "GameFontHighlightSmall", C.white)
	pv.hawkCount:SetJustifyH("CENTER")
	pv.hawkCount:SetPoint("CENTER", pv.hawkBadge, "CENTER", 0, 0)
	-- (on a square hawk the count sits on a small square)
	pv.hawkBadgeSqRim = strip:CreateTexture(nil, "ARTWORK", nil, 5)
	pv.hawkBadgeSqRim:SetColorTexture(PROC_GOLD[1], PROC_GOLD[2], PROC_GOLD[3], 1)
	pv.hawkBadgeSq = strip:CreateTexture(nil, "ARTWORK", nil, 6)
	pv.hawkBadgeSq:SetColorTexture(0.05, 0.045, 0.04, 1)
	pv.hawkBadgeSq:SetPoint("TOPLEFT", pv.hawkBadgeSqRim, "TOPLEFT", 1, -1)
	pv.hawkBadgeSq:SetPoint("BOTTOMRIGHT", pv.hawkBadgeSqRim, "BOTTOMRIGHT", -1, 1)
	-- (icons dragged anywhere on the screen show apart, in the box's corner, with this next to them)
	pv.freeNote = Text(strip, "GameFontDisableSmall", C.muted)
	pv.freeNote:SetJustifyH("RIGHT")
	pv.freeNote:SetText(L["Placed by hand"])
	pv.freeNote:Hide()
	-- shown on their own pages: Multi-Shot's cast line, and the range warnings (stripes, arrows, words)
	pv.mcBack = pv:CreateTexture(nil, "ARTWORK", nil, 5)
	pv.mcBack:SetColorTexture(0, 0, 0, 0.6)
	pv.mcBack:Hide()
	pv.mcFill = pv:CreateTexture(nil, "OVERLAY", nil, 5)
	pv.mcFill:SetColorTexture(1, 1, 1, 1)
	pv.mcFill:Hide()
	pv.warnStripes = pv:CreateTexture(nil, "OVERLAY", nil, 4)
	pv.warnStripes:SetTexture(STRIPES_TEX, "REPEAT", "REPEAT")
	pv.warnStripes:Hide()
	pv.warnArrows = {}
	for i = 1, 6 do
		local a = pv:CreateTexture(nil, "OVERLAY", nil, 4)
		a:SetTexture(CHEVRON_TEX)
		if i > 3 then a:SetTexCoord(1, 0, 0, 1) end -- (the right side's point left)
		a:Hide()
		pv.warnArrows[i] = a
	end
	pv.warnText = pv:CreateFontString(nil, "OVERLAY")
	pv.warnText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	pv.warnText:Hide()
	pv.t = 0
	-- One shot, over and over, drawn the way the real bar draws it: the fill, the
	-- glow building up and pulsing, the light sweep and the sparks while you
	-- stand still, and the proc timers running down.
	On(pv, "OnUpdate", function(self, elapsed)
		local p = self.p or YaHT.db.profile
		self.t = (self.t + elapsed) % PREVIEW_CYCLE
		local t = self.t
		local part = t / PREVIEW_CYCLE
		local standing = part >= PREVIEW_WINDUP
		self.fill:SetWidth(math.max(1, self.w * part))
		local c = standing and p.drawcolor or p.timercolor
		self.fill:SetVertexColor(c.r, c.g, c.b)
		local tenth = math.floor((PREVIEW_CYCLE - t) * 10)
		if tenth ~= self.tenth then
			self.tenth = tenth
			self.num:SetText(string.format("%.1f", tenth / 10))
		end
		if standing ~= self.standing then
			self.standing = standing
			self.phase:SetText(standing and L["Stand still"] or L["Reloading"])
			if standing then
				-- the stand-still color, lightened enough to read on the dark stage
				local c = p.drawcolor
				self.phase:SetTextColor(c.r + (1 - c.r) * 0.4, c.g + (1 - c.g) * 0.4, c.b + (1 - c.b) * 0.4)
			else
				self.phase:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
			end
		end
		-- the glow: off, building up through the reload, full (or pulsing) while you stand still
		local level = 0
		if p.glow then
			if standing then
				level = p.glowpulse and (0.8 + 0.2 * math.sin(t * math.pi * 4)) or 1
			elseif p.glowmode ~= "STAND" then
				local reload = part / PREVIEW_WINDUP
				level = reload * reload * (p.glowramp or 0.7)
			end
			level = math.min(1, level * (p.glowintensity or 1))
		end
		local lit = level > 0.01
		self.glow:SetShown(self.soft and lit)
		if self.soft then self.glow:SetAlpha(level) end
		for _, line in ipairs(self.rim) do
			line:SetShown(self.outlined and lit)
			line:SetAlpha(level)
		end
		-- the light sweep across the bar
		if p.glow and standing and p.glowstyle == "SWEEP" then
			local sw = self.shine
			local span = self.w + sw:GetWidth()
			sw:ClearAllPoints()
			sw:SetPoint("CENTER", self.well, "LEFT", ((t * 1.6) % 1) * span - sw:GetWidth() / 2, 0)
			sw:SetAlpha(p.glowintensity or 1)
			sw:Show()
		else
			self.shine:Hide()
		end
		-- sparks at the moving edge (both edges when the bar fills from the middle)
		local sparking = p.sparkmode == "ALWAYS" or (p.sparkmode == "STAND" and standing)
		local right, left = self.sparks[1], self.sparks[2]
		right:SetShown(sparking)
		left:SetShown(sparking and p.fill and true or false)
		if sparking then
			right:ClearAllPoints()
			if p.fill then
				local half = self.w * part / 2
				right:SetPoint("CENTER", self, "CENTER", half, 0)
				left:ClearAllPoints()
				left:SetPoint("CENTER", self, "CENTER", -half, 0)
			else
				right:SetPoint("CENTER", self, "LEFT", self.w * part, 0)
			end
		end
		-- ON ITS OWN PAGE: Multi-Shot's cast line, filling over and over as its settings say
		local page, k = Menu.current, self.k or 1
		if page == "alerts/multicastpage" and p.multicast then
			local above = p.multicastpos == "ABOVE"
			local mw = math.max(4, self.w * (p.multicastwidth or 1))
			local mh = math.max(2, math.min(9, (p.multicastheight or 4) * k))
			self.mcT = ((self.mcT or 0) + elapsed) % 1.4
			local c = p.multicastcolor or {r = 1, g = 0.82, b = 0.2, a = 1}
			local alpha = self.mcT < 0.75 and (p.multicastalpha or 1) or 0
			self.mcBack:ClearAllPoints()
			self.mcBack:SetPoint(above and "BOTTOM" or "TOP", self, above and "TOP" or "BOTTOM", 0, above and 2 or -2)
			self.mcBack:SetSize(mw, mh)
			self.mcBack:SetShown(p.multicastback ~= false and alpha > 0)
			self.mcFill:ClearAllPoints()
			self.mcFill:SetPoint("LEFT", self.mcBack, "LEFT", 0, 0)
			self.mcFill:SetSize(math.max(1, mw * math.min(1, self.mcT / 0.5)), mh)
			self.mcFill:SetVertexColor(c.r, c.g, c.b, (c.a or 1) * alpha)
			self.mcFill:SetShown(alpha > 0)
			self.mcOn = true
		elseif self.mcOn then
			self.mcOn = nil
			self.mcBack:Hide()
			self.mcFill:Hide()
		end
		-- ON THE RANGE PAGE: the deadzone warning, then the too-far warning, each the way it is set to show
		if page == "alerts/rangepage" and p.meleerange and YaHT.RangeShows then
			self.warnT = ((self.warnT or 0) + elapsed) % 6
			local which = self.warnT < 3 and "dead" or "far"
			local pics, text = YaHT.RangeShows(which)
			if not (pics or text) then -- (that one is off: the other one all the time)
				which = which == "dead" and "far" or "dead"
				pics, text = YaHT.RangeShows(which)
			end
			local dead = which == "dead"
			local c = dead and p.meleedeadcolor or p.meleefarcolor
			local now = GetTime()
			local stripH = 0
			-- the stripes: a line under the bar, or caution tape over the bar itself
			if pics and dead then
				local onBar = p.meleedeadstyle == "BAR"
				local h = onBar and self:GetHeight() or math.max(3, math.min(9, (p.meleedeadheight or 5) * k))
				local st = self.warnStripes
				st:ClearAllPoints()
				if onBar then
					st:SetAllPoints(self)
				else
					st:SetPoint("TOP", self, "BOTTOM", 0, -2)
					st:SetSize(self.w, h)
					stripH = h + 2
				end
				local off = (now * 0.75) % 1
				st:SetTexCoord(-off, self.w / 16 - off, 0, h / 16)
				st:SetVertexColor(c.r, c.g, c.b, (p.meleedeadalpha or 1))
				st:Show()
			else
				self.warnStripes:Hide()
			end
			-- the arrows: sliding in from both ends, under the bar
			if pics and not dead then
				local size = math.max(6, math.min(12, (p.meleefarsize or 8) * k))
				local half = self.w / 2
				local gap = half / 3
				local off = (now * 14) % gap
				for i = 1, 3 do
					local x = (i - 1) * gap + off
					local a = math.max(0, math.min(1, x / gap, (half - x - size) / gap))
					local l, r = self.warnArrows[i], self.warnArrows[3 + i]
					l:ClearAllPoints() l:SetPoint("LEFT", self, "BOTTOMLEFT", x, -2 - size / 2)
					r:ClearAllPoints() r:SetPoint("RIGHT", self, "BOTTOMRIGHT", -x, -2 - size / 2)
					l:SetSize(size * 5 / 8, size) r:SetSize(size * 5 / 8, size)
					l:SetVertexColor(c.r, c.g, c.b, a * (p.meleefaralpha or 1))
					r:SetVertexColor(c.r, c.g, c.b, a * (p.meleefaralpha or 1))
					l:Show() r:Show()
				end
				stripH = size + 2
			else
				for _, a in ipairs(self.warnArrows) do a:Hide() end
			end
			-- the words
			if text then
				local msg = dead and p.rangetextdeadmsg or p.rangetextfarmsg
				if type(msg) ~= "string" or msg:gsub("%s", "") == "" then msg = dead and L["DEADZONE"] or L["TOO FAR"] end
				local tc = (dead and p.rangetextdeadcolor or p.rangetextfarcolor) or c
				local wt = self.warnText
				if wt.shownMsg ~= msg then wt.shownMsg = msg wt:SetText(msg) end
				wt:SetTextColor(tc.r, tc.g, tc.b)
				wt:ClearAllPoints()
				if p.rangetextpos == "ABOVE" then
					wt:SetPoint("BOTTOM", self, "TOP", 0, 3)
				else
					wt:SetPoint("TOP", self, "BOTTOM", 0, -(stripH + 4))
				end
				wt:Show()
			else
				self.warnText:Hide()
			end
			self.warnOn = which
			self.phase:Hide() -- (the warning's own words stand there)
		elseif self.warnOn then
			self.warnOn = nil
			self.phase:Show()
			self.warnStripes:Hide()
			self.warnText:Hide()
			for _, a in ipairs(self.warnArrows) do a:Hide() end
		end
		-- the proc icons: timers run down, halos breathe
		for _, ic in ipairs(self.icons) do
			if ic.on and ic.timed then
				ic.bar:SetWidth(math.max(1, ic.size * (1 - part)))
				if ic.glowing then ic.halo:SetAlpha(0.45 + 0.25 * math.sin(t * 5)) end
			end
		end
	end)
	return pv
end

-- Lays the preview out from the current settings (called after every change)
-- Lays a preview out from these settings: the live preview, and the small one on each look's card
LayoutPreview = function(pv, p)
	pv.p = p
	Menu.previewIcons = pv.icons -- (for tests and debugging)
	-- fit the bar, with the icons and the countdown that sit beside it, into the box
	local beside = 0
	if p.showtext and (p.textpos == "OUTSIDE_LEFT" or p.textpos == "OUTSIDE_RIGHT" or p.textpos == nil) then beside = beside + 30 end
	for _, ic in ipairs(pv.icons) do
		local side = p[ic.key .. "pos"]
		if p[ic.key] and (side == "LEFT" or side == "RIGHT") then
			local own = ic.key == "aspect" and p.aspectsize or (p[ic.key .. "own"] and p[ic.key .. "iconsize"]) or p.procsize
			beside = beside + math.max(20, (own or 20) * 0.6) + 6
		end
	end
	local k = math.min(1, math.max(0.2, (PREVIEW_ROOM - beside) / math.max(1, p.width)))
	local w, h = p.width * k, math.min(26, math.max(4, p.height * k))
	pv.w = w
	pv.k = k
	pv:SetSize(w, h)
	pv.standing = nil -- (the phase label takes its color again)
	pv.shadow:ClearAllPoints()
	pv.shadow:SetPoint("TOPLEFT", pv, "TOPLEFT", -26, 5)
	pv.shadow:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", 26, -14)
	pv.fill:SetTexture(YaHT:GetMedia("statusbar", p.statusbar))
	pv.fill:ClearAllPoints()
	pv.fill:SetPoint(p.fill and "CENTER" or "LEFT", pv, p.fill and "CENTER" or "LEFT")
	pv.fill:SetHeight(h)
	if p.enablebackground then
		local bc = p.backgroundcolor
		pv.back:SetTexture(YaHT:GetMedia("background", p.background))
		pv.back:SetVertexColor(bc.r, bc.g, bc.b, bc.a or 1)
		pv.back:Show()
	else
		pv.back:Hide()
	end
	for _, t in ipairs(pv.edge) do
		t:SetShown(p.enableborder and true or false)
		t:SetColorTexture(p.bordercolor.r, p.bordercolor.g, p.bordercolor.b, 1)
	end
	-- the glow, soft or as an outline, in its own color and size
	local gc = p.glowcolor or {r = 1, g = 0.82, b = 0.3}
	local g = math.max(4, (p.glowsize or 10) * k)
	pv.soft = p.glow and p.glowlook ~= "OUTLINE" or false
	pv.outlined = p.glow and p.glowlook == "OUTLINE" or false
	pv.glow:ClearAllPoints()
	pv.glow:SetPoint("TOPLEFT", pv, "TOPLEFT", -g, g)
	pv.glow:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", g, -g)
	pv.glow:SetVertexColor(gc.r, gc.g, gc.b)
	local th = math.max(1, math.floor(g / 4))
	pv.rimBox:ClearAllPoints()
	pv.rimBox:SetPoint("TOPLEFT", pv, "TOPLEFT", -th - 1, th + 1)
	pv.rimBox:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", th + 1, -th - 1)
	for i, line in ipairs(pv.rim) do
		line:SetColorTexture(gc.r, gc.g, gc.b, 1)
		if i <= 2 then line:SetHeight(th) else line:SetWidth(th) end
	end
	pv.shine:SetSize(math.max(w * 0.25, 30), h * 3)
	pv.shine:SetVertexColor(gc.r, gc.g, gc.b)
	local sc = p.sparkcolor or gc
	for _, spark in ipairs(pv.sparks) do
		spark:SetSize(math.max(h * 1.2, 8), h * (p.sparksize or 2))
		spark:SetVertexColor(sc.r, sc.g, sc.b)
	end
	-- the countdown number, where its Position setting puts it
	pv.num:SetShown(p.showtext and true or false)
	pv.num:ClearAllPoints()
	local tc, pos = p.textcolor, p.textpos
	local font = YaHT:GetMedia("font", p.font) or STANDARD_TEXT_FONT
	local size = math.min(16, math.max(8, (p.textsize or 12) * k))
	if not pv.num:SetFont(font, size, "OUTLINE") then pv.num:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
	if tc then pv.num:SetTextColor(tc.r, tc.g, tc.b) end
	if pos == "OUTSIDE_LEFT" then pv.num:SetPoint("RIGHT", pv, "LEFT", -5, 0)
	elseif pos == "INSIDE_LEFT" then pv.num:SetPoint("LEFT", pv, "LEFT", 3, 0)
	elseif pos == "INSIDE_CENTER" then pv.num:SetPoint("CENTER", pv, "CENTER", 0, 0)
	elseif pos == "INSIDE_RIGHT" then pv.num:SetPoint("RIGHT", pv, "RIGHT", -3, 0)
	elseif pos == "ABOVE" then pv.num:SetPoint("BOTTOM", pv, "TOP", 0, 2)
	elseif pos == "BELOW" then pv.num:SetPoint("TOP", pv, "BOTTOM", 0, -2)
	else pv.num:SetPoint("LEFT", pv, "RIGHT", 5, 0) end
	-- the icons that sit around the bar, each on its side
	local used = {LEFT = 0, RIGHT = 0, ABOVE = 0}
	if p.showtext and pos == "OUTSIDE_LEFT" then used.LEFT = 28 end
	if p.showtext and (pos == "OUTSIDE_RIGHT" or pos == nil) then used.RIGHT = 28 end
	local GAP = 6
	for _, ic in ipairs(pv.icons) do
		local side = p[ic.key .. "pos"]
		ic.on = p[ic.key] and (used[side] ~= nil or side == "FREE") or false
		-- (Bestial Wrath's prime spot is only kept for a hunter who has it)
		if ic.key == "bestial" and YaHT.BestialKnown and not YaHT.BestialKnown() then ic.on = false end
		if ic.on then
			local own = ic.key == "aspect" and p.aspectsize or (p[ic.key .. "own"] and p[ic.key .. "iconsize"]) or p.procsize
			-- (to the bar's own scale, so the size you set is the size you see next to the bar)
			ic.size = math.min(side == "ABOVE" and 44 or (side == "FREE" and 26 or 34), math.max(7, own * k))
		end
	end
	-- Above the bar the game stands the first icon centred over it and the others to its right
	local aboveX = 0
	-- An icon set to "Anywhere" was dragged somewhere on the screen: it shows apart, in the box's top right corner
	local freeX = 0
	for _, ic in ipairs(pv.icons) do
		if ic.on then
			local side, size = p[ic.key .. "pos"], ic.size
			if not ic.loaded then
				ic.loaded = true
				ic.tex:SetTexture(SpellTexture(ic.spell))
			end
			-- square or round: the aspect badge's own shape, an icon's own, or the shared one
			local round = p.procshape == "CIRCLE"
			if ic.key == "aspect" then
				round = p.aspectshape == "CIRCLE"
			elseif p[ic.key .. "own"] then
				round = p[ic.key .. "iconshape"] == "CIRCLE"
			end
			ic.round = round
			local inner = round and size * 0.8 or size -- (a round picture sits inside its ring)
			ic.tex:SetSize(inner, inner)
			ic.tex:ClearAllPoints()
			if side == "FREE" then
				ic.tex:SetPoint("TOPRIGHT", pv.box, "TOPRIGHT", -8 - freeX, -8)
				freeX = freeX + size + 5
			elseif side == "LEFT" then
				ic.tex:SetPoint("RIGHT", pv, "LEFT", -GAP - used.LEFT, 0)
				used.LEFT = used.LEFT + size + GAP
			elseif side == "RIGHT" then
				ic.tex:SetPoint("LEFT", pv, "RIGHT", GAP + used.RIGHT, 0)
				used.RIGHT = used.RIGHT + size + GAP
			else
				ic.tex:SetPoint("BOTTOM", pv, "TOP", aboveX, 10)
				aboveX = aboveX + size + GAP
			end
			local glow = ic.timed and ((p[ic.key .. "own"] and p[ic.key .. "iconglow"]) or p.procglow) or "NONE"
			local hc = p[ic.key .. "glowcolor"] or gc
			ic.glowing = glow ~= "NONE"
			ic.halo:SetTexture(ic.round and HALO_TEX or GLOW_TEX) -- (a round glow behind a round icon)
			ic.halo:SetVertexColor(hc.r or 1, hc.g or 0.82, hc.b or 0.3)
			ic.halo:SetShown(ic.glowing)
			ic.bar:SetShown(ic.timed)
			-- the polished look or the standard one: the aspect badge's own, an icon's own, or the shared one
			local polished = p.procpolish
			if ic.key == "aspect" then
				polished = p.aspectpolish
			elseif p[ic.key .. "own"] then
				polished = p[ic.key .. "iconpolish"]
			end
			polished = polished and true or false
			DressSquare(ic, true, polished and not ic.round, PROC_GOLD)
			DressRound(ic, ic.round, polished, size, PROC_GOLD)
			if ic.round then -- (its ring is its rim and its timer)
				ic.rim:Hide()
				ic.bar:Hide()
			end
		else
			DressSquare(ic, false)
			DressRound(ic, false)
			ic.halo:Hide()
			ic.bar:Hide()
		end
	end
	-- the hawks, where their own settings put them (two sample hawks; one when the layout is a count):
	-- circles with a ring that runs down, or squares that look like the proc icons
	local hpos = p.hawkpos
	local hawkOn = p.hawk and true or false
	local hawkFree = hpos == "FREE"
	local one = p.hawkmode == "COUNT"
	local square = p.hawkshape == "SQUARE"
	local inRow = hpos == "ABOVE" or hpos == "LEFT" or hpos == "RIGHT"
	local hs
	if square then
		local own = p.hawkown and p.hawkiconsize or p.procsize
		hs = math.min(hawkFree and 26 or ((hpos == "LEFT" or hpos == "RIGHT") and 34 or 44), math.max(7, (own or 30) * k))
	else
		hs = math.min(hawkFree and 26 or 44, math.max(8, (p.hawksize or 26) * k))
	end
	local numPos = p.hawknumbers and p.hawknumpos or nil
	local numSize = math.max(8, math.floor(hs * (numPos == "MIDDLE" and 0.5 or 0.42) + 0.5))
	local numRow = (numPos == "BOTTOM") and (numSize + 2) or 0
	local under = square and 6 or 0 -- (a square's timer line)
	local shownHawks = hawkOn and (one and 1 or 2) or 0
	local step = hs + ((square or inRow) and GAP or 4)
	-- a square's look: the one all proc icons share, or the hawks' own
	local squarePolished, squareGlow = p.procpolish, p.procglow
	if p.hawkown then squarePolished, squareGlow = p.hawkiconpolish, p.hawkiconglow end
	squarePolished = squarePolished and true or false
	for i, hk in ipairs(pv.hawks) do
		local on = i <= shownHawks
		local round = on and not square
		local polished = p.hawkpolish and true or false
		hk.back:SetShown(round)
		hk.icon:SetShown(round)
		hk.ring:SetShown(round)
		hk.shadow:SetShown(round and polished)
		hk.halo:SetShown(round and polished)
		hk.gloss:SetShown(round and polished)
		hk.line:SetShown(round and polished)
		hk.num:SetShown(on and numPos ~= nil)
		local sq = hk.sq
		if not (on and square) then
			DressSquare(sq, false)
			sq.halo:Hide()
			sq.bar:Hide()
		end
		if on then
			local left = HAWK_SAMPLE[one and 2 or i] -- (a count shows the hawk that ends first)
			local warn = (p.hawkwarn or 0) > 0 and left < p.hawkwarn
			local spot = square and sq.tex or hk.back -- what stands on this hawk's spot
			spot:SetSize(hs, hs)
			spot:ClearAllPoints()
			if hawkFree then
				-- placed by hand: in the box's corner, after any other icon that is
				spot:SetPoint("TOPRIGHT", pv.box, "TOPRIGHT", -8 - freeX - (shownHawks - i) * step, -8 - (numPos == "TOP" and (numSize + 2) or 0))
			elseif hpos == "TOPRIGHT" then
				spot:SetPoint("BOTTOMRIGHT", pv, "TOPRIGHT", -(shownHawks - i) * step, 4 + numRow + under)
			elseif hpos == "ABOVE" then
				spot:SetPoint("BOTTOM", pv, "TOP", aboveX + (i - 1) * step, 10 + numRow)
			elseif hpos == "LEFT" then
				spot:SetPoint("RIGHT", pv, "LEFT", -GAP - used.LEFT - (shownHawks - i) * step, 0)
			elseif hpos == "RIGHT" then
				spot:SetPoint("LEFT", pv, "RIGHT", GAP + used.RIGHT + (i - 1) * step, 0)
			else
				spot:SetPoint("BOTTOMLEFT", pv, "TOPLEFT", (i - 1) * step, 4 + numRow + under)
			end
			if square then
				if not sq.loaded then
					sq.loaded = true
					local tex = SpellTexture(1293241)
					sq.tex:SetTexture(tex ~= FALLBACK_ICON and tex or HAWK_ICON)
				end
				local c = warn and HAWK_RED or PROC_GOLD
				DressSquare(sq, true, squarePolished, c)
				sq.bar:SetColorTexture(c[1], c[2], c[3], 1)
				sq.bar:SetWidth(math.max(1, hs * left / 18))
				sq.bar:Show()
				sq.warn = warn
				local hc = p.hawkglowcolor or gc
				if warn then
					sq.halo:SetVertexColor(HAWK_RED[1], HAWK_RED[2], HAWK_RED[3])
				else
					sq.halo:SetVertexColor(hc.r or 1, hc.g or 0.82, hc.b or 0.3)
				end
				sq.halo:SetAlpha(0.6)
				sq.halo:SetShown(squareGlow ~= nil and squareGlow ~= "NONE")
			else
				if not hk.loaded then
					hk.loaded = true
					local tex = SpellTexture(1293241)
					hk.icon:SetTexture(tex ~= FALLBACK_ICON and tex or HAWK_ICON)
				end
				hk.icon:SetSize(hs * (polished and 0.78 or 0.80), hs * (polished and 0.78 or 0.80))
				hk.ring:SetTexture(polished and RING_TEX or RINGFLAT_TEX)
				hk.shadow:SetSize(hs * 1.62, hs * 1.62)
				hk.halo:SetSize(hs * 1.62, hs * 1.62)
				local hc = polished and (warn and HAWK_RED or HAWK_GOLD) or (warn and HAWK_PLAIN_RED or HAWK_PLAIN_GOLD)
				hk.ring:SetVertexColor(hc[1], hc[2], hc[3])
				hk.halo:SetVertexColor(hc[1], hc[2], hc[3])
				local a = p.hawkalpha or 1
				hk.back:SetAlpha(a) hk.icon:SetAlpha(a) hk.ring:SetAlpha(a) hk.num:SetAlpha(a)
				hk.shadow:SetAlpha(0.75 * a) hk.halo:SetAlpha(0.34 * a) hk.gloss:SetAlpha(a) hk.line:SetAlpha(a)
			end
			if square then hk.num:SetAlpha(1) end
			if numPos then
				if not hk.num:SetFont(font, numSize, "OUTLINE") then hk.num:SetFont(STANDARD_TEXT_FONT, numSize, "OUTLINE") end
				hk.num:SetText(tostring(left))
				hk.num:SetTextColor(warn and 1 or 0.95, warn and 0.55 or 0.89, warn and 0.5 or 0.71)
				hk.num:ClearAllPoints()
				if numPos == "MIDDLE" then
					hk.num:SetPoint("CENTER", spot, "CENTER", 0, 0)
				elseif numPos == "TOP" then
					hk.num:SetPoint("BOTTOM", spot, "TOP", 0, 1)
				else
					hk.num:SetPoint("TOP", spot, "BOTTOM", 0, -1 - under)
				end
			end
		end
	end
	-- (in a row beside the bar, the hawks take their room after the other icons)
	if hpos == "LEFT" then used.LEFT = used.LEFT + shownHawks * step end
	if hpos == "RIGHT" then used.RIGHT = used.RIGHT + shownHawks * step end
	if hawkFree then freeX = freeX + shownHawks * step end
	-- a word next to what was placed by hand, while there is room for it beside the caption
	local note = freeX > 0 and freeX <= 70 and not pv.mini
	pv.freeNote:SetShown(note)
	if note then
		pv.freeNote:ClearAllPoints()
		pv.freeNote:SetPoint("TOPRIGHT", pv.box, "TOPRIGHT", -8 - freeX - 2, -11)
	end
	local badge = hawkOn and one
	pv.hawkBadge:SetShown(badge and not square)
	pv.hawkBadgeRim:SetShown(badge and not square)
	pv.hawkBadgeSq:SetShown(badge and square)
	pv.hawkBadgeSqRim:SetShown(badge and square)
	pv.hawkCount:SetShown(badge)
	if badge then
		local bs = math.max(10, math.floor(hs * 0.46 + 0.5))
		local spot = square and pv.hawks[1].sq.tex or pv.hawks[1].back
		for _, t in ipairs({pv.hawkBadge, pv.hawkBadgeSqRim}) do -- a round badge on a circle, a square one on a square
			t:SetSize(bs, bs)
			t:ClearAllPoints()
			t:SetPoint("CENTER", spot, "BOTTOMRIGHT", -3, 3)
		end
		if not pv.hawkCount:SetFont(font, math.max(8, bs - 3), "OUTLINE") then pv.hawkCount:SetFont(STANDARD_TEXT_FONT, math.max(8, bs - 3), "OUTLINE") end
		pv.hawkCount:SetText("2")
	end
	-- the bar and what sits beside it, centered in the box as one group
	pv:ClearAllPoints()
	pv:SetPoint("CENTER", pv.box, "CENTER", (used.LEFT - used.RIGHT) / 2, PREVIEW_DY)
end

-- The live preview, from the current settings (called after every change)
function Menu.DrawPreview()
	local pv = frame and frame.preview
	if not pv then return end
	local p = YaHT.db.profile
	-- a look being viewed: the preview shows your settings with that look's laid over them
	if Menu.viewing and YaHT.LookValues then
		p = setmetatable(YaHT:LookValues(Menu.viewing), {__index = YaHT.db.profile})
	end
	if pv.box.caption then pv.box.caption:SetText(Menu.viewing and L["Preview of the look"] or L["Live preview"]) end
	LayoutPreview(pv, p)
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
-- The window never has to be bigger than the screen: on a small one it is drawn smaller
local function FitScale()
	local w = UIParent.GetWidth and UIParent:GetWidth() or 0
	local h = UIParent.GetHeight and UIParent:GetHeight() or 0
	local s = 1
	if w > 0 and h > 0 then s = math.min(1, (w - 40) / WIDTH, (h - 40) / HEIGHT) end
	frame:SetScale(math.max(0.6, s))
end

local function Build()
	BuildPages()
	local f = CreateFrame("Frame", "YaHTMenuFrame", UIParent)
	frame = f
	f:SetSize(WIDTH, HEIGHT)
	f:SetFrameStrata("HIGH") -- under the game's yes/no and colour windows, which this one opens
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	local saved = YaHT.db.global.menupos
	if saved then
		f:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	end
	Plate(f, "BACKGROUND", C.bg):SetAllPoints(f)
	Rim(f, C.line)
	f.boxes = {} -- the section boxes on the page (reused from page to page)

	-- header: drag it to move the window
	local head = CreateFrame("Frame", nil, f)
	head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	head:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	head:SetHeight(HEAD_H)
	head:EnableMouse(true)
	head:RegisterForDrag("LeftButton")
	On(head, "OnDragStart", function() f:StartMoving() end)
	On(head, "OnDragStop", function()
		f:StopMovingOrSizing()
		local point, _, rel, x, y = f:GetPoint()
		YaHT.db.global.menupos = {point, rel, x, y}
	end)
	local icon = head:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Weapon_Bow_07")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetSize(24, 24)
	icon:SetPoint("LEFT", head, "LEFT", 14, 0)
	local title = Text(head, "GameFontNormalLarge", C.white)
	title:SetPoint("LEFT", icon, "RIGHT", 9, 0)
	title:SetText("YaHT Forever")
	local version = Text(head, "GameFontHighlightSmall", C.muted)
	version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
	version:SetText(YaHT.version or "")

	-- Lock bar and Grid: the two switches you reach for while placing things, in view on every page
	local function headSwitch(anchor, gap)
		local sw = CreateFrame("Button", nil, head)
		sw:SetHeight(24)
		sw:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
		sw.label = Text(sw, "GameFontHighlight", C.text)
		sw.label:SetPoint("LEFT", sw, "LEFT", 0, 0)
		sw.bg = Plate(sw, "BACKGROUND", C.soft)
		sw.bg:SetSize(36, 18)
		sw.bg:SetPoint("LEFT", sw.label, "RIGHT", 8, 0)
		sw.knob = Dot(sw, "ARTWORK", C.muted)
		sw.knob:SetSize(14, 14)
		On(sw, "OnClick", function(self) if self.onClick then self.onClick() end end)
		On(sw, "OnEnter", function(self) ShowTip(self) end)
		On(sw, "OnLeave", HideTip)
		return sw
	end
	f.lock = headSwitch(title, 70)
	f.grid = headSwitch(f.lock, 24)

	local close = CreateFrame("Button", nil, head)
	close:SetSize(24, 24)
	close:SetPoint("RIGHT", head, "RIGHT", -12, 0)
	close.text = Text(close, "GameFontNormalLarge", C.muted)
	close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
	close.text:SetText("x")
	On(close, "OnClick", function() f:Hide() end)
	On(close, "OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
	On(close, "OnLeave", function(self) self.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)

	local search = CreateFrame("EditBox", nil, head)
	f.search = search
	search:SetSize(200, 24)
	search:SetPoint("RIGHT", close, "LEFT", -10, 0)
	Plate(search, "BACKGROUND", C.field):SetAllPoints(search)
	Rim(search, C.soft)
	search:SetFontObject(GameFontHighlightSmall)
	search:SetAutoFocus(false)
	search:SetTextInsets(10, 10, 0, 0)
	search.hint = Text(search, "GameFontHighlightSmall", C.muted)
	search.hint:SetPoint("LEFT", search, "LEFT", 10, 0)
	search.hint:SetText(L["Search settings"])
	On(search, "OnTextChanged", function(self)
		local text = self:GetText() or ""
		self.hint:SetShown(text == "")
		if not self.silent then Menu.Search(text) end
	end)
	On(search, "OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	On(search, "OnEnterPressed", function(self) self:ClearFocus() end)

	-- left: the pages
	f.navHolder = CreateFrame("Frame", nil, f)
	f.navHolder:SetPoint("TOPLEFT", f, "TOPLEFT", EDGE, -BODY_TOP)
	f.navHolder:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", EDGE, EDGE)
	f.navHolder:SetWidth(NAV_W)
	Plate(f.navHolder, "BACKGROUND", C.panel):SetAllPoints(f.navHolder)
	Rim(f.navHolder, C.edge)
	f.nav = {}

	-- middle: the page
	scroll = CreateFrame("ScrollFrame", nil, f)
	scroll:SetPoint("TOPLEFT", f.navHolder, "TOPRIGHT", EDGE, 0)
	scroll:SetPoint("BOTTOMLEFT", f.navHolder, "BOTTOMRIGHT", EDGE, 0)
	scroll:SetWidth(VIEW_W)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(VIEW_W, VIEW_H)
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	On(scroll, "OnMouseWheel", function(_, delta)
		Menu.CloseList()
		Menu.scrollY = (Menu.scrollY or 0) - delta * 48
		ClampScroll()
	end)
	f.scrollMark = Tex(f, "OVERLAY", C.soft)
	f.scrollMark:SetWidth(3)
	f.scrollMark:Hide()

	-- right: what the setting under the mouse does (at rest: what this page is for)
	local help = CreateFrame("Frame", nil, f)
	f.help = help
	help:SetPoint("TOPRIGHT", f, "TOPRIGHT", -EDGE, -BODY_TOP)
	help:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -EDGE, EDGE)
	help:SetWidth(HELP_W)
	Plate(help, "BACKGROUND", C.panel):SetAllPoints(help)
	Rim(help, C.edge)
	-- at its top, the live preview in a dark box: your bar and icons, drawn from the settings
	local strip = CreateFrame("Frame", nil, help)
	strip:SetPoint("TOPLEFT", help, "TOPLEFT", 10, -10)
	strip:SetSize(PREVIEW_BOX_W, PREVIEW_H)
	Plate(strip, "BACKGROUND", C.preview):SetAllPoints(strip)
	Rim(strip, C.soft)
	-- a pool of warm light where the bar stands, fading out before the edges
	f.stageLight = strip:CreateTexture(nil, "BACKGROUND", nil, 2)
	f.stageLight:SetTexture(STAGE_TEX)
	f.stageLight:SetBlendMode("ADD")
	f.stageLight:SetVertexColor(1, 0.82, 0.52, 0.17)
	f.stageLight:SetSize(PREVIEW_BOX_W * 1.25, PREVIEW_H * 1.5)
	f.stageLight:SetPoint("CENTER", strip, "CENTER", 0, PREVIEW_DY)
	if strip.SetClipsChildren then strip:SetClipsChildren(true) end
	local caption = Text(strip, "GameFontHighlightSmall", C.goldDim)
	caption:SetPoint("TOPLEFT", strip, "TOPLEFT", 10, -7)
	caption:SetText(L["Live preview"])
	strip.caption = caption
	f.preview = BuildPreview(strip)
	f.previewBox = strip
	help.title = Text(help, "GameFontNormal", C.gold)
	help.title:SetPoint("TOPLEFT", help, "TOPLEFT", 14, -(PREVIEW_H + 26))
	help.title:SetWidth(HELP_W - 28)
	help.title:SetWordWrap(true)
	help.rule = Tex(help, "ARTWORK", C.soft)
	help.rule:SetPoint("TOPLEFT", help.title, "BOTTOMLEFT", 0, -8)
	help.rule:SetSize(HELP_W - 28, 1)
	help.text = Text(help, "GameFontHighlight", C.text)
	help.text:SetPoint("TOPLEFT", help.rule, "BOTTOMLEFT", 0, -10)
	help.text:SetWidth(HELP_W - 28)
	help.text:SetJustifyV("TOP")
	help.text:SetWordWrap(true)
	if help.text.SetSpacing then help.text:SetSpacing(4) end
	-- the credits, small, at the foot
	help.foot = Text(help, "GameFontHighlightSmall", C.muted)
	help.foot:SetPoint("BOTTOMLEFT", help, "BOTTOMLEFT", 14, 12)
	help.foot:SetWidth(HELP_W - 28)
	help.foot:SetJustifyV("BOTTOM")
	help.foot:SetWordWrap(true)
	if help.foot.SetSpacing then help.foot:SetSpacing(3) end

	On(f, "OnHide", function()
		Menu.CloseList()
		HideTip()
	end)
	-- Escape closes it
	if UISpecialFrames then table.insert(UISpecialFrames, "YaHTMenuFrame") end
	-- resets, presets and profile switches tell the settings table it changed
	local registry = LibStub("AceConfigRegistry-3.0", true)
	if registry and registry.RegisterCallback then
		registry.RegisterCallback(Menu, "ConfigTableChange", function(_, app)
			if app == "YaHT" then Menu.Render() end
		end)
	end
	f:Hide()
end

-- Opens the window (on a page, by id such as "alerts/petpage"); a second call closes it.
function YaHT:OpenMenu(page)
	if not Root() then return false end
	if not frame then Build() end
	if frame:IsShown() and not page then
		frame:Hide()
		return true
	end
	FitScale()
	frame:Show()
	Menu.Show(page or Menu.current or "home")
	return true
end

function YaHT:CloseMenu()
	if frame then frame:Hide() end
end
