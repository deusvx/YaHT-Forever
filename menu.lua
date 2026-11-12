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
local PREVIEW_H = 132      -- the live preview's box, at the top of the right column
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
local CARD_H = 118         -- a quick-look card: live preview, name and up to four lines of text
local GLOW_TEX = "Interface\\AddOns\\YaHT\\media\\Glow"
local SHINE_TEX = "Interface\\AddOns\\YaHT\\media\\Shine"
local SPARK_TEX = "Interface\\AddOns\\YaHT\\media\\Spark"
local ROUND_TEX = "Interface\\AddOns\\YaHT\\media\\Round"     -- a filled rounded rectangle
local EDGE_TEX = "Interface\\AddOns\\YaHT\\media\\RoundEdge"  -- its one-pixel outline
local DOT_TEX = "Interface\\AddOns\\YaHT\\media\\Dot"         -- a filled circle
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
	presetclean = {preset = "CLEAN", outline = true, sparks = true},
	presetflashy = {preset = "FLASHY", soft = true, sweep = true, sparks = true},
}

local function PageItems(page)
	local items, cards = {}, false
	for _, node in ipairs(Sorted(page.path[#page.path].opt.args)) do
		if node.opt.type == "execute" and CARD_LOOK[node.key] then
			-- the quick looks show as one row of preview cards, not three buttons
			if not cards then
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
	{"alerts", "aspect"}, {"alerts", "feign"}, {"alerts", "pet"},
	{"alerts", "meleerange"}, {"alerts", "melee"}, {"alerts", "ammo"}, {"bar", "minimap"},
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
		b.sample = b:CreateTexture(nil, "BACKGROUND")
		b.sample:SetAllPoints(b)
		b.sample:SetAlpha(0.55)
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

Make.toggle = function(parent)
	local row = NewRow(parent, 36)
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
	return row
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

-- one frame of a card's preview. t: seconds into the shot
local function CardTick(b, t)
	local p, look = YaHT.db.profile, b.look
	if not look then return end
	local part = t / PREVIEW_CYCLE
	local winding = part >= PREVIEW_WINDUP
	local k = winding and (part - PREVIEW_WINDUP) / (1 - PREVIEW_WINDUP) or 0 -- how far through the wind-up
	b.fill:SetWidth(math.max(1, b.barW * part))
	local c = winding and p.drawcolor or p.timercolor
	b.fill:SetVertexColor(c.r, c.g, c.b)
	local tenth = math.floor((PREVIEW_CYCLE - t) * 10)
	if tenth ~= b.tenth then
		b.tenth = tenth
		b.num:SetText(string.format("%.1f", tenth / 10))
	end
	-- Clean: a crisp outline while you must stand still
	for _, line in ipairs(b.rim) do line:SetShown(look.outline and winding or false) end
	-- Flashy: a soft glow that builds up as the shot gets close, then pulses
	if look.soft then
		local a
		if winding then
			a = 0.75 + 0.25 * math.sin(t * 12)
		else
			a = 0.75 * math.max(0, (part - 0.45) / (PREVIEW_WINDUP - 0.45))
		end
		b.glow:SetAlpha(a)
		b.glow:Show()
	else
		b.glow:Hide()
	end
	-- Flashy: a light sweeps across the bar
	if look.sweep and winding then
		b.shine:ClearAllPoints()
		b.shine:SetPoint("CENTER", b.well, "LEFT", -14 + (b.barW + 28) * k, 0)
		b.shine:Show()
	else
		b.shine:Hide()
	end
	-- Clean and Flashy: two sparks race out from the middle
	for i, spark in ipairs(b.sparks) do
		if look.sparks and winding then
			spark:ClearAllPoints()
			spark:SetPoint("CENTER", b.well, "CENTER", (i == 1 and -1 or 1) * b.barW / 2 * k, 0)
			spark:SetAlpha(1 - 0.4 * k)
			spark:Show()
		else
			spark:Hide()
		end
	end
end

Make.cards = function(parent)
	local row = CreateFrame("Frame", nil, parent)
	row.cards = {}
	row.t = 0
	local gap = 10
	local w = (VIEW_W - MARK_W - 2 * BOX_PAD - 2 * gap) / 3
	local barW = w - 20 - 30
	for i = 1, 3 do
		local b = CreateFrame("Button", nil, row)
		b:SetSize(w, CARD_H)
		b:SetPoint("TOPLEFT", row, "TOPLEFT", BOX_PAD + (i - 1) * (w + gap), 0)
		b.bg = Plate(b, "BACKGROUND", C.plate)
		b.bg:SetAllPoints(b)
		b.edge = Rim(b, C.soft)
		b.barW = barW
		-- the soft glow sits behind the bar
		b.glow = b:CreateTexture(nil, "BORDER")
		b.glow:SetTexture(GLOW_TEX)
		b.glow:SetBlendMode("ADD")
		b.glow:Hide()
		-- the bar; it clips the light sweep to its own shape
		b.well = CreateFrame("Frame", nil, b)
		b.well:SetSize(barW, 10)
		b.well:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -18)
		if b.well.SetClipsChildren then b.well:SetClipsChildren(true) end
		Tex(b.well, "BACKGROUND", {0, 0, 0, 1}):SetAllPoints(b.well)
		b.fill = b.well:CreateTexture(nil, "ARTWORK")
		b.fill:SetHeight(10)
		b.shine = b.well:CreateTexture(nil, "OVERLAY")
		b.shine:SetTexture(SHINE_TEX)
		b.shine:SetBlendMode("ADD")
		b.shine:SetSize(28, 10)
		b.shine:Hide()
		b.glow:SetPoint("TOPLEFT", b.well, "TOPLEFT", -9, 9)
		b.glow:SetPoint("BOTTOMRIGHT", b.well, "BOTTOMRIGHT", 9, -9)
		-- the outline and the sparks draw over the bar
		b.over = CreateFrame("Frame", nil, b)
		b.over:SetPoint("TOPLEFT", b.well, "TOPLEFT", -1, 1)
		b.over:SetPoint("BOTTOMRIGHT", b.well, "BOTTOMRIGHT", 1, -1)
		b.over:SetFrameLevel(b.well:GetFrameLevel() + 2)
		b.rim = Outline(b.over, C.gold)
		b.sparks = {}
		for n = 1, 2 do
			local spark = b.over:CreateTexture(nil, "OVERLAY")
			spark:SetTexture(SPARK_TEX)
			spark:SetBlendMode("ADD")
			spark:SetSize(12, 22)
			spark:Hide()
			b.sparks[n] = spark
		end
		b.num = Text(b, "GameFontHighlightSmall", C.white)
		b.num:SetPoint("LEFT", b.well, "RIGHT", 6, 0)
		b.name = Text(b, "GameFontHighlight", C.white)
		b.name:SetPoint("TOPLEFT", b.well, "BOTTOMLEFT", 0, -12)
		b.tag = Text(b, "GameFontHighlightSmall", C.gold)
		b.tag:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10, -38)
		b.tag:SetText(L["In use"])
		b.desc = Text(b, "GameFontHighlightSmall", C.muted)
		b.desc:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
		b.desc:SetWidth(w - 20)
		b.desc:SetWordWrap(true)
		b.desc:SetJustifyV("TOP")
		if b.desc.SetSpacing then b.desc:SetSpacing(2) end
		local function tint(self, hover)
			local c = (hover or self.current) and C.gold or C.soft
			PaintRim(self.edge, c)
		end
		b.tint = tint
		On(b, "OnClick", function(self) if self.onClick then self.onClick() end end)
		On(b, "OnEnter", function(self) tint(self, true) end)
		On(b, "OnLeave", function(self) tint(self, false) end)
		row.cards[i] = b
	end
	-- one clock runs all three previews (only while the cards are on the page)
	On(row, "OnUpdate", function(self, elapsed)
		self.t = (self.t + elapsed) % PREVIEW_CYCLE
		for _, b in ipairs(self.cards) do CardTick(b, self.t) end
	end)
	return row
end
Fill.cards = function(row)
	local p = YaHT.db.profile
	local gc = p.glowcolor or {r = 1, g = 0.82, b = 0.3}
	local sc = p.sparkcolor or gc
	for i, key in ipairs(HOME_CARDS) do
		local b, path = row.cards[i], Find({"bar", key})
		if path then
			b.look = CARD_LOOK[key]
			b.fill:SetTexture(YaHT:GetMedia("statusbar", p.statusbar))
			b.fill:ClearAllPoints()
			b.fill:SetPoint(p.fill and "CENTER" or "LEFT", b.well, p.fill and "CENTER" or "LEFT")
			b.glow:SetVertexColor(gc.r, gc.g, gc.b)
			for _, line in ipairs(b.rim) do line:SetColorTexture(gc.r, gc.g, gc.b, 1) end
			for _, spark in ipairs(b.sparks) do spark:SetVertexColor(sc.r, sc.g, sc.b) end
			b.name:SetText(Value(path, "name") or "")
			b.desc:SetText(Value(path, "desc") or "")
			b.current = IsLookInUse(b.look.preset)
			b.tag:SetShown(b.current)
			b.tint(b, false)
			b.onClick = function()
				Call(path, "func")
				Menu.Changed()
			end
			CardTick(b, row.t)
			b:Show()
		else
			b:Hide()
		end
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
				On(b, "OnClick", function(self) Menu.Show(self.page) end)
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
local PREVIEW_ICONS = { -- key, a spell whose icon stands in for it
	{"aspect", 13165}, {"mongoose", 1495}, {"quickshots", 6150}, {"rapidfire", 3045}, {"racial", 20572},
}
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function SpellTexture(id)
	local get = C_Spell and C_Spell.GetSpellTexture
	if not get then return FALLBACK_ICON end
	local ok, tex = pcall(get, id)
	if not ok or not tex or (issecretvalue and issecretvalue(tex)) then return FALLBACK_ICON end
	return tex
end

local function BuildPreview(strip)
	local pv = CreateFrame("Frame", nil, strip)
	pv.box = strip
	pv:SetPoint("CENTER", strip, "CENTER", 0, -12)
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
		local ic = {key = def[1], spell = def[2], timed = def[1] ~= "aspect"}
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
		pv.icons[i] = ic
	end
	pv.t = 0
	-- One shot, over and over, drawn the way the real bar draws it: the fill, the
	-- glow building up and pulsing, the light sweep and the sparks while you
	-- stand still, and the proc timers running down.
	On(pv, "OnUpdate", function(self, elapsed)
		local p = YaHT.db.profile
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
function Menu.DrawPreview()
	local pv = frame and frame.preview
	if not pv then return end
	local p = YaHT.db.profile
	-- fit the bar, with the icons and the countdown that sit beside it, into the box
	local beside = 0
	if p.showtext and (p.textpos == "OUTSIDE_LEFT" or p.textpos == "OUTSIDE_RIGHT" or p.textpos == nil) then beside = beside + 30 end
	for _, ic in ipairs(pv.icons) do
		local side = p[ic.key .. "pos"]
		if p[ic.key] and (side == "LEFT" or side == "RIGHT") then beside = beside + 24 end
	end
	local k = math.min(1, math.max(0.2, (PREVIEW_ROOM - beside) / math.max(1, p.width)))
	local w, h = p.width * k, math.min(26, math.max(4, p.height * k))
	pv.w = w
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
	local aboveW = 0
	for _, ic in ipairs(pv.icons) do
		local side = p[ic.key .. "pos"]
		ic.on = p[ic.key] and used[side] ~= nil or false
		if ic.on then
			local own = ic.key == "aspect" and p.aspectsize or (p[ic.key .. "own"] and p[ic.key .. "iconsize"]) or p.procsize
			ic.size = math.min(side == "ABOVE" and 24 or 18, math.max(12, own * k))
			if side == "ABOVE" then aboveW = aboveW + ic.size + (aboveW > 0 and GAP or 0) end
		end
	end
	local aboveX = -aboveW / 2 -- the icons above the bar are centered over it
	for _, ic in ipairs(pv.icons) do
		if ic.on then
			local side, size = p[ic.key .. "pos"], ic.size
			if not ic.loaded then
				ic.loaded = true
				ic.tex:SetTexture(SpellTexture(ic.spell))
			end
			ic.tex:SetSize(size, size)
			ic.tex:ClearAllPoints()
			if side == "LEFT" then
				ic.tex:SetPoint("RIGHT", pv, "LEFT", -GAP - used.LEFT, 0)
				used.LEFT = used.LEFT + size + GAP
			elseif side == "RIGHT" then
				ic.tex:SetPoint("LEFT", pv, "RIGHT", GAP + used.RIGHT, 0)
				used.RIGHT = used.RIGHT + size + GAP
			else
				ic.tex:SetPoint("BOTTOMLEFT", pv, "TOP", aboveX, 10)
				aboveX = aboveX + size + GAP
			end
			local glow = ic.timed and ((p[ic.key .. "own"] and p[ic.key .. "iconglow"]) or p.procglow) or "NONE"
			local hc = p[ic.key .. "glowcolor"] or gc
			ic.glowing = glow ~= "NONE"
			ic.halo:SetVertexColor(hc.r or 1, hc.g or 0.82, hc.b or 0.3)
			ic.halo:SetShown(ic.glowing)
			ic.bar:SetShown(ic.timed)
			ic.rim:Show()
			ic.tex:Show()
		else
			ic.tex:Hide()
			ic.rim:Hide()
			ic.halo:Hide()
			ic.bar:Hide()
		end
	end
	-- the bar and what sits beside it, centered in the box as one group
	pv:ClearAllPoints()
	pv:SetPoint("CENTER", pv.box, "CENTER", (used.LEFT - used.RIGHT) / 2, -12)
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
	f.stageLight:SetPoint("CENTER", strip, "CENTER", 0, -12)
	if strip.SetClipsChildren then strip:SetClipsChildren(true) end
	local caption = Text(strip, "GameFontHighlightSmall", C.goldDim)
	caption:SetPoint("TOPLEFT", strip, "TOPLEFT", 10, -7)
	caption:SetText(L["Live preview"])
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
