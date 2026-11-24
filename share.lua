-- YaHT settings helpers for the options window:
--   which settings you changed, and putting one back,
--   your setup as a line of text to share, and reading one in,
--   the few lines of "what's new" for this version.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

---------------------------------------------------------------------------
-- What's new (a few short lines; the full list is in CHANGELOG.md)
---------------------------------------------------------------------------
YaHT.news = {
	version = "1.5.2",
	lines = {
		"Tracking wheel: a small button shows what you track. Click it, move into a piece of the pie and on out, and you track it. (Tools, Tracking wheel)",
		"The deadzone and too-far warnings are gone the moment you are out of them.",
		"Options: a gold dot marks a setting you changed. Right-click the setting to put it back.",
		"Options: a page shows only what you can use. Switch a feature off and its settings step aside until you switch it on again.",
		"Options: \"What's new\" and \"Back\" sit next to the search box. The alerts are three sections: Warnings, Timers and icons, Tools. \"Show my changes\" on the Profiles page lists everything you changed.",
		"Options: share your setup as a line of text (Profiles), and the window opens on the page you left.",
	},
}

---------------------------------------------------------------------------
-- Changed settings
---------------------------------------------------------------------------
local function Same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local function Copy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = Copy(x) end
	return t
end

-- true / false for a setting that has a default; nil for anything else (a dragged spot, a button)
function YaHT:IsChanged(key)
	local d = self.defaults and self.defaults.profile[key]
	if d == nil then return nil end
	return not Same(self.db.profile[key], d)
end

function YaHT:ResetSetting(key)
	local d = self.defaults and self.defaults.profile[key]
	if d == nil then return false end
	self.db.profile[key] = Copy(d)
	self:ApplySettings()
	return true
end

---------------------------------------------------------------------------
-- A setup as text: "YaHT1:key=value;key=value". Only what differs from the
-- defaults, and no screen positions (they fit one screen, not the next).
--   b0 / b1 a switch | n12.5 a number | sWORD a choice or text | c1,0.5,0,1 a color
---------------------------------------------------------------------------
local PREFIX = "YaHT1:"
local MAX_TEXT = 200

local function Esc(s) return (s:gsub("[%%;=,]", function(c) return string.format("%%%02X", c:byte()) end)) end
local function Unesc(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
local function Num(n) return (string.format("%.4f", n):gsub("0+$", ""):gsub("%.$", "")) end

function YaHT:ExportSetup()
	local keys, parts = {}, {}
	for k in pairs(self.defaults.profile) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		if self:IsChanged(k) then
			local v = self.db.profile[k]
			local t, out = type(v), nil
			if t == "boolean" then out = v and "b1" or "b0"
			elseif t == "number" then out = "n" .. Num(v)
			elseif t == "string" then out = "s" .. Esc(v)
			elseif t == "table" then
				out = "c" .. Num(v.r or 1) .. "," .. Num(v.g or 1) .. "," .. Num(v.b or 1) .. "," .. (v.a and Num(v.a) or "")
			end
			if out then parts[#parts + 1] = k .. "=" .. out end
		end
	end
	return PREFIX .. table.concat(parts, ";")
end

-- every setting in the options, by its key (to check what a pasted setup asks for)
local byKey
local function Options()
	if byKey then return byKey end
	byKey = {}
	local function walk(args)
		for key, opt in pairs(args or {}) do
			if type(opt) == "table" then
				if opt.type == "group" then walk(opt.args) elseif byKey[key] == nil then byKey[key] = opt end
			end
		end
	end
	walk(YaHT.optionsTable and YaHT.optionsTable.args)
	return byKey
end

-- Reads a pasted setup. Only settings YaHT has, of the kind it expects, within what its
-- options allow: anything else in the text is left out. Returns the settings, or nil and why.
function YaHT:ReadSetup(text)
	text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if text:sub(1, #PREFIX) ~= PREFIX then
		return nil, L["That is not a YaHT setup: it should start with YaHT1:"]
	end
	local defaults, opts = self.defaults.profile, Options()
	local set, n = {}, 0
	for pair in text:sub(#PREFIX + 1):gmatch("[^;]+") do
		local k, v = pair:match("^([%w_]+)=(.+)$")
		local d = k and defaults[k]
		if d ~= nil then
			local tag, body, opt, value = v:sub(1, 1), v:sub(2), opts[k], nil
			if tag == "b" and type(d) == "boolean" then
				if body == "1" or body == "0" then value = body == "1" end
			elseif tag == "n" and type(d) == "number" then
				local x = tonumber(body)
				if x and x == x and x > -1e6 and x < 1e6 then
					-- a slider that stores its own number is kept within the slider's ends
					if opt and opt.type == "range" and opt.get == nil and opt.min and opt.max then
						x = math.min(opt.max, math.max(opt.min, x))
					end
					value = x
				end
			elseif tag == "s" and type(d) == "string" then
				local s = Unesc(body)
				if #s <= MAX_TEXT then
					-- a choice must be one the menu offers (lists the game builds, like fonts, are taken as they are)
					if opt and opt.type == "select" and type(opt.values) == "table" then
						if opt.values[s] ~= nil then value = s end
					else
						value = s
					end
				end
			elseif tag == "c" and type(d) == "table" then
				local r, g, b, a = body:match("^([%d%.]+),([%d%.]+),([%d%.]+),([%d%.]*)$")
				r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
				if r and g and b then
					local function unit(x) return math.min(1, math.max(0, x)) end
					value = {r = unit(r), g = unit(g), b = unit(b), a = a and unit(a) or nil}
				end
			end
			if value ~= nil and set[k] == nil then set[k] = value n = n + 1 end
		end
	end
	return set, n
end

-- Takes a pasted setup: everything goes back to its default, then the setup's settings go on
-- top (screen positions stay as they are). What you had is kept for "Undo the import".
function YaHT:ImportSetup(text)
	local set, n = self:ReadSetup(text)
	if not set then return false, n end
	local p, before = self.db.profile, {}
	for k, d in pairs(self.defaults.profile) do
		before[k] = Copy(p[k])
		if set[k] ~= nil then p[k] = Copy(set[k]) else p[k] = Copy(d) end
	end
	self.importBackup = before
	self:ApplySettings()
	return true, n
end

function YaHT:UndoImport()
	local before = self.importBackup
	if not before then return false end
	local p = self.db.profile
	for k, v in pairs(before) do p[k] = Copy(v) end
	self.importBackup = nil
	self:ApplySettings()
	return true
end
