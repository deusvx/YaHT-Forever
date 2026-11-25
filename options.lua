if select(2,UnitClass("player")) ~= "HUNTER" then return end
local Addon = select(1, ...)

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local L = YaHT.L

-- Copy default values back for a list of settings (one tab's "Reset" button).
local function ResetKeys(keys)
	local defaults, profile = YaHT.defaults.profile, YaHT.db.profile
	for _, key in ipairs(keys) do
		local v = defaults[key]
		if type(v) == "table" then
			local copy = {}
			for k, x in pairs(v) do copy[k] = x end
			profile[key] = copy
		else
			profile[key] = v
		end
	end
	YaHT:ApplySettings()
	AceConfigRegistry:NotifyChange(Addon)
end

-- The three looks. Each says what is on: Minimal is just the bar, Clean adds the icons, Flashy is
-- everything with every effect. They never touch size, position, colours or the countdown.
local LOOK_ICONS = {"raptor", "bestial", "mongoose", "quickshots", "rapidfire", "racial", "aspect", "hawk", "ammo", "feign"}
local LOOK_WARNINGS = {"pet", "meleerange", "melee"}
local LOOK_POLISH = {"procpolish", "raptoriconpolish", "bestialiconpolish", "mongooseiconpolish", "quickshotsiconpolish", "rapidfireiconpolish", "racialiconpolish",
	"aspectpolish", "hawkpolish", "hawkiconpolish"}
local function Look(t, icons, warnings, polish)
	for _, key in ipairs(LOOK_ICONS) do t[key] = icons end
	for _, key in ipairs(LOOK_WARNINGS) do t[key] = warnings end
	for _, key in ipairs(LOOK_POLISH) do t[key] = polish end
	return t
end
local PRESETS = {
	MINIMAL = Look({glow = false, sparkmode = "OFF", readypulse = true}, false, false, false),
	CLEAN = Look({glow = false, sparkmode = "OFF", readypulse = true, procglow = "NONE", procpulse = "NONE"}, true, false, false),
	FLASHY = Look({
		glow = true, glowlook = "SOFT", glowmode = "RAMP", glowpulse = true, glowramp = 0.7,
		glowstyle = "SWEEP", glowkeepbuiltin = true, glowintensity = 1, glowsize = 14,
		sparkmode = "STAND", readypulse = true, procglow = "HALO", procpulse = "BREATHE",
	}, true, true, true),
}

YaHT.presets = PRESETS

-- what a look would set, for showing it in the options window before it is used
function YaHT:LookValues(name)
	local t = {}
	for k, v in pairs(PRESETS[name] or {}) do t[k] = v end
	if name == "FLASHY" and self:GetLCG() then t.glowstyle = "PIXEL" end
	return t
end

local function ApplyPreset(name)
	local profile = YaHT.db.profile
	for k, v in pairs(PRESETS[name]) do profile[k] = v end
	-- Flashy uses the WeakAuras-style pixel effect when it's available
	if name == "FLASHY" and YaHT:GetLCG() then profile.glowstyle = "PIXEL" end
	YaHT:ApplySettings()
	AceConfigRegistry:NotifyChange(Addon)
end

local TAB_KEYS = {
	general = {"lock", "width", "height", "scale", "alpha", "malpha", "minimap", "minimapangle"},
	lonewolf = {"lonewolf", "lonewolfstyle", "lonewolfheight", "lonewolfpet", "lonewolfcolor", "lonewolfglowcolor"},
	bar = {"barstyle", "castbardir", "castbartext", "castbarreload", "castbarwind", "statusbar", "timercolor", "drawcolor", "fill", "enablebackground", "background",
		"backgroundcolor", "enableborder", "border", "bordercolor"},
	text = {"showtext", "textmode", "textpos", "textsize", "textx", "texty", "font", "textcolor"},
	glow = {"glow", "glowmode", "glowlook", "glowstyle", "glowkeepbuiltin", "glowpulse", "glowramp",
		"glowintensity", "glowsize", "glowcolor"},
	spark = {"sparkmode", "readypulse", "sparksize", "sparkcolor"},
	effects = {"glow", "glowmode", "glowlook", "glowstyle", "glowkeepbuiltin", "glowpulse", "glowramp",
		"glowintensity", "glowsize", "glowcolor", "sparkmode", "readypulse", "sparksize", "sparkcolor"},
	multicast = {"multicast", "multicastpos", "multicastheight", "multicastwidth", "multicastalpha", "multicastback", "multicastx", "multicasty", "multicastcolor"},
	timing = {"windupauto", "windup", "castholds", "autocorrect", "smooth"},
	ammo = {"ammo", "ammosize", "ammofadestart", "ammolow", "ammocrit", "ammofullalpha", "ammoflash", "ammosound"},
	melee = {"melee", "meleemode", "meleeheight", "meleealpha", "meleeglint", "meleeraptor", "meleecolor", "meleeraptorcolor"},
	feign = {"feign", "feignscale", "feigntime", "feignsound", "feigntargetcheck", "feignthreatcheck", "feigncolor",
		"feignpoint", "feignrelpoint", "feignx", "feigny"},
	tracker = {"tracker", "trackerpick", "trackersize", "trackerall", "trackerlayer", "trackerpolish", "trackerpoint", "trackerrelpoint", "trackerx", "trackery"},
	pet = {"pet", "petlow", "petlowat", "petwhen", "petdead", "petidle", "petsound", "petpulse", "pettextsize",
		"petpoint", "petrelpoint", "petx", "pety"},
	hawk = {"hawksoundat", "hawk", "hawkmode", "hawkpos", "hawksize", "hawkalpha", "hawknumbers", "hawknumpos", "hawkempty", "hawkpolish", "hawkwarn",
		"hawkpoint", "hawkrelpoint", "hawkx", "hawky", "hawkshape", "hawkglowcolor", "hawkown", "hawkownset",
		"hawkiconsize", "hawkiconalpha", "hawkiconglow", "hawkiconpulse", "hawkiconsound", "hawkiconpolish"},
	aspect = {"aspecthit", "aspectpackalert", "aspectcheetahalert", "aspectshoutsize", "aspectshoutpoint", "aspectshoutrelpoint", "aspectshoutx", "aspectshouty", "aspect", "aspectwhen", "aspectpos", "aspectsize", "aspectalpha", "aspectpolish", "aspectshape", "aspectwarnspeed", "aspectspeedalways",
		"aspectwarnnone", "aspecthint", "aspectsound", "aspectpoint", "aspectrelpoint", "aspectx", "aspecty"},
	procs = {"raptor", "raptorpos", "raptornumbers", "raptorsoundat", "raptorglowcolor", "raptorpoint", "raptorrelpoint", "raptorx", "raptory", "raptorown", "raptorownset", "raptoriconsize", "raptoriconalpha", "raptoriconglow", "raptoriconpulse", "raptoriconsound", "raptoriconpolish", "raptoriconshape", "bestialsoundat", "mongoosesoundat", "quickshotssoundat", "rapidfiresoundat", "racialsoundat", "mongoosenumbers", "quickshotsnumbers", "rapidfirenumbers", "racialnumbers", "bestial", "bestialpos", "bestialnumbers", "bestialcooldown", "bestialglowcolor", "bestialpoint", "bestialrelpoint", "bestialx", "bestialy", "bestialown", "bestialownset",
		"bestialiconsize", "bestialiconalpha", "bestialiconglow", "bestialiconpulse", "bestialiconsound", "bestialiconpolish", "bestialiconshape",
		"procshape", "mongooseiconshape", "quickshotsiconshape", "rapidfireiconshape", "racialiconshape", "procpolish", "mongooseiconpolish", "quickshotsiconpolish", "rapidfireiconpolish", "racialiconpolish", "procsize", "procalpha", "procglow", "procpulse", "procsound", "mongoosecooldown", "mongoose", "mongoosepos", "mongooseglowcolor", "mongoosepoint", "mongooserelpoint", "mongoosex", "mongoosey", "quickshots", "quickshotspos", "quickshotsglowcolor", "quickshotspoint", "quickshotsrelpoint", "quickshotsx", "quickshotsy", "rapidfire", "rapidfirepos", "rapidfireglowcolor", "rapidfirepoint", "rapidfirerelpoint", "rapidfirex", "rapidfirey", "racial", "racialpos", "racialglowcolor", "racialpoint", "racialrelpoint", "racialx", "racialy",
		"mongooseown", "mongooseownset", "mongooseiconsize", "mongooseiconalpha", "mongooseiconglow", "mongooseiconpulse", "mongooseiconsound", "quickshotsown", "quickshotsownset", "quickshotsiconsize", "quickshotsiconalpha", "quickshotsiconglow", "quickshotsiconpulse", "quickshotsiconsound", "rapidfireown", "rapidfireownset", "rapidfireiconsize", "rapidfireiconalpha", "rapidfireiconglow", "rapidfireiconpulse", "rapidfireiconsound", "racialown", "racialownset", "racialiconsize", "racialiconalpha", "racialiconglow", "racialiconpulse", "racialiconsound"},
	range = {"meleerange", "meleerangewhen", "meleedeadstyle", "meleedeadcolor", "meleedeadheight", "meleedeadalpha", "meleefarcolor", "meleefarsize", "meleefaralpha",
		"meleewarnspeed", "meleewarnboost", "meleewarnglow", "meleewarnglowsize", "meleewarnglowalpha",
		"rangeyards", "rangeyardsstyle", "rangeyardswhen", "rangeyardssize", "rangeyardspos", "rangeyardspoint", "rangeyardsrelpoint",
		"rangeyardsx", "rangeyardsy", "rangetextpos", "rangepics", "rangedead", "rangefar", "rangedeadpics", "rangefarpics", "rangetext", "rangetextdead", "rangetextfar", "rangetextdeadmsg", "rangetextfarmsg", "rangetextsize",
		"rangetextdeadcolor", "rangetextfarcolor", "rangetextpoint", "rangetextrelpoint", "rangetextx", "rangetexty"},
	announce = {"tranqannounce", "announcetype", "targetchannel",
		"announcemsg"},
}

function YaHT:CreateConfig()

	local function get(info)
		return YaHT.db.profile[info[#info]]
	end

	local function set(info, value)
		YaHT.db.profile[info[#info]] = value
		YaHT:ApplySettings()
	end

	local function getColor(info)
		local db = YaHT.db.profile[info[#info]]
		return db.r, db.g, db.b, db.a
	end

	local function setColor(info, r, g, b, a)
		local db = YaHT.db.profile[info[#info]]
		db.r, db.g, db.b, db.a = r, g, b, a
		YaHT:ApplySettings()
	end

	local function getMediaData(info)
		return YaHT:ListMedia(info[#info])
	end

	-- Use the fancy texture-preview dropdowns only if a SharedMedia widget
	-- addon is loaded; otherwise fall back to a plain dropdown.
	local AceGUI = LibStub("AceGUI-3.0", true)
	local function widget(name)
		if AceGUI and AceGUI.WidgetRegistry and AceGUI.WidgetRegistry[name] then
			return name
		end
	end

	local function resetButton(tab, order)
		return {
			name = L["Reset this page"],
			desc = L["Put every setting on this page back to its default."],
			type = "execute",
			order = order or 100,
			confirm = true,
			confirmText = L["Reset this page to defaults?"],
			func = function() ResetKeys(TAB_KEYS[tab]) end,
		}
	end

	local function textOff() return not YaHT.db.profile.showtext end
	local function glowOff() return not YaHT.db.profile.glow end
	local function sparkOff() local p = YaHT.db.profile return p.sparkmode == "OFF" and not p.readypulse end
	local tranq = YaHT.GetSpellName(19801) or "Tranquilizing Shot"
	local raptor = YaHT.GetSpellName(2973) or "Raptor Strike"
	local function meleeOff() return not YaHT.db.profile.melee end
	local function raptorOff() local p = YaHT.db.profile return not p.melee or not p.meleeraptor end
	local function rangeOff() return not YaHT.db.profile.meleerange end
	local SPEED_ALERT_VALUES = {OFF = L["Nothing extra"], WORDS = L["Bouncing words"], ICON = L["Bouncing icon"], BOTH = L["Words and icon"]}
	local SPEED_ALERT_SORTING = {"OFF", "WORDS", "ICON", "BOTH"}
	local function rangeTextOff() local p = YaHT.db.profile return not (p.meleerange and p.rangetext) end
	local function glowWarnOff() local p = YaHT.db.profile return not p.meleerange or p.meleewarnglow == "NONE" end
	local mongoose = YaHT.GetSpellName(1495) or "Mongoose Bite"
	local quickshots = YaHT.GetSpellName(6150) or "Quick Shots"
	local function aspectOff() return not YaHT.db.profile.aspect end
	local function feignOff() return not YaHT.db.profile.feign end
	local function petOff() return not YaHT.db.profile.pet end
	local function petLowOff() local p = YaHT.db.profile return not p.pet or not p.petlow end
	local function hawkOff() return not YaHT.db.profile.hawk end
	local function hawkNumOff() local p = YaHT.db.profile return not p.hawk or not p.hawknumbers end
	local function hawkEachOff() local p = YaHT.db.profile return not p.hawk or p.hawkmode == "COUNT" end
	-- the hawks as circles have their own few settings; as squares they have a proc icon's
	local function hawkSquare() return YaHT.db.profile.hawkshape == "SQUARE" end
	local function hawkRound() return YaHT.db.profile.hawkshape ~= "SQUARE" end
	local function hawkOwnOff() local p = YaHT.db.profile return p.hawkshape ~= "SQUARE" or not p.hawkown end

	local rapidfire = YaHT.GetSpellName(3045) or "Rapid Fire"
	local bestial = YaHT.GetSpellName(19574) or "Bestial Wrath"
	local hasLCG = function() return LibStub and LibStub("LibCustomGlow-1.0", true) end
	local function procsOff() local p = YaHT.db.profile return not (p.bestial or p.mongoose or p.quickshots or p.rapidfire or p.racial or p.raptor) end
	-- the glow and pulse choices, used by the shared look and by an icon's own look
	local function glowValues()
		local v = {NONE = L["None"], HALO = L["Soft halo"], RING = L["Bright ring"],
			SHINE = L["Shine (light sweeps across)"], SPARKS = L["Sparks (circle the icon)"]}
		if hasLCG() then
			v.PROC = L["Proc (spell alert)"]
			v.BUTTON = L["Button (action bar glow)"]
		end
		return v
	end
	local function glowSorting()
		local list = {"NONE", "HALO", "RING", "SHINE", "SPARKS"}
		if hasLCG() then list[#list + 1] = "PROC" list[#list + 1] = "BUTTON" end
		return list
	end
	local PULSE_VALUES = {NONE = L["None"], BREATHE = L["Breathe (fades in and out)"], GROW = L["Grow and shrink"],
		HEARTBEAT = L["Heartbeat"], FLASH = L["Flash"]}
	local PULSE_SORTING = {"NONE", "BREATHE", "GROW", "HEARTBEAT", "FLASH"}
	local OWN_LOOK = {"size", "alpha", "glow", "pulse", "sound", "polish", "shape"}
	-- every "Shape" setting there is (the "Round icons" switch on the Home and Alerts pages sets them all)
	YaHT.shapeKeys = {"procshape", "raptoriconshape", "bestialiconshape", "mongooseiconshape", "quickshotsiconshape", "rapidfireiconshape", "racialiconshape",
		"aspectshape", "hawkshape"}
	local SHAPE_VALUES = {SQUARE = L["Square"], CIRCLE = L["Circle"]}
	local SHAPE_SORTING = {"SQUARE", "CIRCLE"}
	local SHAPE_DESC = L["Square: the icon with a rim and a timer line under it. Circle: the icon cut round inside a ring, and the ring runs down as the timer."]
	-- every "Polished look" setting there is (the one switch on the Home and Alerts pages sets them all)
	YaHT.polishKeys = {"trackerpolish", "procpolish", "raptoriconpolish", "bestialiconpolish", "mongooseiconpolish", "quickshotsiconpolish", "rapidfireiconpolish", "racialiconpolish",
		"aspectpolish", "hawkpolish", "hawkiconpolish"}
	local SQUARE_POLISH = L["A bevelled frame with fine edges in place of the flat rim, a soft light on the icon and a shadow under it. Off: the standard look, a plain flat rim."]

	-- one small page per proc icon: on/off, position, glow color (+ extras)
	local function procPage(key, name, desc, order, extra)
		local function off() return not YaHT.db.profile[key] end
		local function ownOff() return not YaHT.db.profile[key .. "own"] end
		local args = {
			about = {name = desc, type = "description", order = 1},
			[key] = {name = string.format(L["Show %s alert"], name), type = "toggle", width = "double", order = 2},
			[key .. "pos"] = {
				name = L["Position"],
				desc = L["Anywhere: unlock the bar (/yaht unlock) and drag the icon where you want it."],
				type = "select",
				order = 3,
				values = {ABOVE = L["Above the bar"], LEFT = L["Left of the bar"], RIGHT = L["Right of the bar"], FREE = L["Anywhere (drag it)"]},
				sorting = {"ABOVE", "LEFT", "RIGHT", "FREE"},
				disabled = off,
			},
			[key .. "glowcolor"] = {
				name = L["Glow color"],
				type = "color",
				order = 4,
				get = getColor,
				set = setColor,
				disabled = function()
					local p = YaHT.db.profile
					local glow = p[key .. "own"] and p[key .. "iconglow"] or p.procglow
					return not p[key] or glow == "NONE"
				end,
			},
			-- its own look, instead of the one all proc icons share
			[key .. "own"] = {
				name = L["Its own look"],
				desc = L["Give this icon its own size, opacity, glow, pulse and sound, instead of the look all proc icons share. It starts out as a copy of the shared look."],
				type = "toggle",
				width = "double",
				order = 10,
				set = function(info, value)
					local p = YaHT.db.profile
					if value and not p[key .. "ownset"] then
						-- the first time: start from what the icon looks like now
						for _, part in ipairs(OWN_LOOK) do p[key .. "icon" .. part] = p["proc" .. part] end
						p[key .. "ownset"] = true
					end
					p[key .. "own"] = value
					YaHT:ApplySettings()
				end,
				disabled = off,
			},
			[key .. "iconshape"] = {name = L["Shape"], desc = SHAPE_DESC, type = "select", order = 10.5, values = SHAPE_VALUES, sorting = SHAPE_SORTING, hidden = ownOff, disabled = off},
			[key .. "iconsize"] = {name = L["Icon size"], type = "range", order = 11, min = 16, max = 64, step = 1, hidden = ownOff, disabled = off},
			[key .. "iconalpha"] = {name = L["Opacity"], type = "range", order = 12, min = 0.2, max = 1, step = 0.05, isPercent = true, hidden = ownOff, disabled = off},
			[key .. "iconglow"] = {name = L["Glow style"], type = "select", order = 13, values = glowValues, sorting = glowSorting, hidden = ownOff, disabled = off},
			[key .. "iconpulse"] = {name = L["Pulse style"], type = "select", order = 14, values = PULSE_VALUES, sorting = PULSE_SORTING, hidden = ownOff, disabled = off},
			[key .. "iconsound"] = {name = L["Play a sound when it pops up"], type = "toggle", width = "double", order = 15, hidden = ownOff, disabled = off},
			[key .. "iconpolish"] = {name = L["Polished look"], desc = SQUARE_POLISH, type = "toggle", order = 16, hidden = ownOff, disabled = off},
		}
		for k, v in pairs(extra or {}) do args[k] = v end
		return {name = name, type = "group", order = order, args = args}
	end

	local procsArgs = {
		procsdesc = {
			name = L["Small spell icons that pop in next to the bar while a proc lasts, with a gold timer underneath. Unlock the bar to see where they sit. Two alerts set to the same spot sit side by side."],
			type = "description",
			order = 1,
		},
		showheader = {name = L["Show"], type = "header", order = 10},
		mongoose = {name = mongoose, type = "toggle", order = 11},
		quickshots = {name = quickshots, type = "toggle", order = 12},
		bestial = {name = bestial, type = "toggle", order = 10.5},
		rapidfire = {name = rapidfire, type = "toggle", order = 13},
		racial = {name = L["Racial ability"], type = "toggle", order = 14},
		raptor = {name = raptor, type = "toggle", order = 11.5},
		lookheader = {name = L["Look of all proc icons"], type = "header", order = 20},
		procshape = {name = L["Shape"], desc = SHAPE_DESC, type = "select", order = 20.5, values = SHAPE_VALUES, sorting = SHAPE_SORTING, disabled = procsOff},
		procsize = {name = L["Icon size"], type = "range", order = 21, min = 16, max = 64, step = 1, disabled = procsOff},
		procalpha = {name = L["Opacity"], type = "range", order = 22, min = 0.2, max = 1, step = 0.05, isPercent = true, disabled = procsOff},
		procpolish = {name = L["Polished look"], desc = SQUARE_POLISH, type = "toggle", order = 25.5, disabled = procsOff},
		procglow = {
			name = L["Glow style"],
			desc = L["Light around the icon while you can use it. Proc and Button are borrowed from LibCustomGlow and only appear when WeakAuras (or another addon that includes it) is installed."],
			type = "select",
			order = 23,
			values = glowValues,
			sorting = glowSorting,
			disabled = procsOff,
		},
		procpulse = {
			name = L["Pulse style"],
			desc = L["How the icon moves while you can use it. It speeds up in the last moments of the window."],
			type = "select",
			order = 24,
			values = PULSE_VALUES,
			sorting = PULSE_SORTING,
			disabled = procsOff,
		},
		procsound = {desc = L["Plays a short sound each time a proc icon appears."], name = L["Play a sound when one pops up"], type = "toggle", width = "double", order = 25, disabled = procsOff},
		reset = resetButton("procs"),
		mongoosepage = procPage("mongoose", mongoose,
			string.format(L["After you dodge, %s can be used for a few seconds. Its icon pops in next to the bar with a gold timer that drains while the chance lasts. The rim turns blue if you're short on mana. Unlock the bar to see where it sits."], mongoose), 1, {
			mongoosecooldown = {
				name = L["Show its cooldown"],
				desc = string.format(L["If %s is still on cooldown when you dodge, the icon is grey with a clock sweep and a countdown, then pops back in color the moment you can press it."], mongoose),
				type = "toggle",
				width = "double",
				order = 5,
				disabled = function() return not YaHT.db.profile.mongoose end,
			},
		}),
		quickshotspage = procPage("quickshots", quickshots,
			string.format(L["With the Deadly Aspects talent, your Auto Shots can trigger %s: 30%% faster ranged attacks for 12 seconds. Its icon shows while it lasts, and the timer follows the buff."], quickshots), 2),
		bestialpage = procPage("bestial", bestial,
			string.format(L["Shows while %s lasts (18 seconds), from the moment you cast it. It has the prime spot: first in the row of icons, so above the bar it stands centered over it."], bestial), 0.5, {
			bestialnumbers = {
				name = L["Show seconds left"],
				desc = L["The seconds it has left, as a number on the icon."],
				type = "toggle",
				order = 5,
				disabled = function() return not YaHT.db.profile.bestial end,
			},
			bestialcooldown = {
				name = L["Show its cooldown"],
				desc = string.format(L["After %s ends, its icon stays: grey, with a clock sweep and a countdown, until you can cast it again. Then it flashes once and goes away."], bestial),
				type = "toggle",
				order = 5.5,
				disabled = function() return not YaHT.db.profile.bestial end,
			},
		}),
		raptorpage = procPage("raptor", raptor,
			string.format(L["%s does not hit right away: it waits for your next melee swing. While it is waiting, its icon shows next to the bar, like the lit-up button on your action bar, and the timer under it runs down to the swing. It goes away when the swing lands or you cancel it."], raptor), 1.5),
		rapidfirepage = procPage("rapidfire", rapidfire,
			string.format(L["Shows while %s lasts (15 seconds), from the moment you cast it."], rapidfire), 3),
		racialpage = procPage("racial", L["Racial ability"],
			L["Your race's active (Night Elf Elune's Light, Orc Blood Fury, Troll Berserking, Dwarf Stoneform, Human Perception, Tauren Plainsrunning, Skyborne Skysight) shows while it lasts, from the moment you use it. YaHT recognises it by itself; for a new racial it learns the length the first time you use it out of combat."], 4),
	}

	-- BASICS FIRST. A page shows what most people want (on / off, position, size, its one or two
	-- special switches). The fine settings are tucked under "More options", which starts closed each
	-- time (it is not a saved setting, only how much of the page is showing).
	local more = {}
	YaHT.optionsMore = more
	local function Tuck(args, id, keys, order)
		for _, key in ipairs(keys) do
			local opt = args[key]
			if opt then
				local was = opt.hidden
				opt.hidden = function(...)
					if not more[id] then return true end
					if type(was) == "function" then return was(...) end
					return was
				end
			end
		end
		args[id .. "more"] = {
			name = L["More options"],
			desc = L["The fine settings: glow, pulse, sound, shape, the polished look and this icon's own look. Most people never need them."],
			type = "toggle",
			width = "double",
			order = order,
			get = function() return more[id] and true or false end,
			set = function(info, value)
				more[id] = value and true or nil
				AceConfigRegistry:NotifyChange(Addon)
			end,
		}
	end
	for _, key in ipairs({"bestial", "mongoose", "raptor", "quickshots", "rapidfire", "racial"}) do
		local args = procsArgs[key .. "page"].args
		-- its size, among the basics: the shared size until you change it here
		args[key .. "size"] = {
			name = L["Icon size"],
			desc = L["How big this icon is. Changing it gives the icon its own size; the others keep theirs."],
			type = "range",
			order = 3.5,
			min = 16, max = 64, step = 1,
			get = function()
				local p = YaHT.db.profile
				return p[key .. "own"] and p[key .. "iconsize"] or p.procsize
			end,
			set = function(info, value)
				local p = YaHT.db.profile
				if not p[key .. "own"] then
					if not p[key .. "ownset"] then
						for _, part in ipairs(OWN_LOOK) do p[key .. "icon" .. part] = p["proc" .. part] end
						p[key .. "ownset"] = true
					end
					p[key .. "own"] = true
				end
				p[key .. "iconsize"] = value
				YaHT:ApplySettings()
			end,
			disabled = function() return not YaHT.db.profile[key] end,
		}
		args[key .. "iconsize"].hidden = true -- (the size is among the basics now)
		-- its shape, among the basics too: the shared shape until you change it here
		args[key .. "shape"] = {
			name = L["Shape"],
			desc = L["Square, or round inside a ring that runs down as its timer. Changing it here changes this icon only."],
			type = "select",
			order = 2.5,
			values = SHAPE_VALUES,
			sorting = SHAPE_SORTING,
			get = function()
				local p = YaHT.db.profile
				return p[key .. "own"] and p[key .. "iconshape"] or p.procshape
			end,
			set = function(info, value)
				local p = YaHT.db.profile
				if not p[key .. "own"] then
					if not p[key .. "ownset"] then
						for _, part in ipairs(OWN_LOOK) do p[key .. "icon" .. part] = p["proc" .. part] end
						p[key .. "ownset"] = true
					end
					p[key .. "own"] = true
				end
				p[key .. "iconshape"] = value
				YaHT:ApplySettings()
			end,
			disabled = function() return not YaHT.db.profile[key] end,
		}
		args[key .. "iconshape"].hidden = true
		-- the seconds left as a number on the icon: the same switch on every icon's page
		args[key .. "numbers"] = args[key .. "numbers"] or {
			name = L["Show seconds left"],
			desc = L["The seconds it has left, as a number on the icon."],
			type = "toggle",
			disabled = function() return not YaHT.db.profile[key] end,
		}
		args[key .. "numbers"].order = 4.2
		-- a warning sound as its time runs low
		args[key .. "soundat"] = {
			name = L["Sound at seconds left"],
			desc = L["Plays a warning sound once when this many seconds are left. 0 = never."],
			type = "range",
			order = 4.25,
			min = 0, max = 15, step = 1,
			disabled = function() return not YaHT.db.profile[key] end,
		}
		-- three cards: the icon itself, its time, and the fine tuning
		args[key .. "cardicon"] = {name = L["Icon"], type = "header", order = 1.5}
		args[key .. "cardtime"] = {name = L["Time"], type = "header", order = 4.1}
		args[key .. "cardmore"] = {name = L["Fine tuning"], type = "header", order = 8.9}
		Tuck(args, key, {key .. "glowcolor", key .. "own", key .. "iconalpha", key .. "iconglow",
			key .. "iconpulse", key .. "iconsound", key .. "iconpolish"}, 9)
	end

	-- Multi-Shot's cast line: a page of its own, laid out like the icons' pages
	local function multiOff() return not YaHT.db.profile.multicast end
	local multicastPage = {
		name = L["Multi-Shot cast"],
		type = "group",
		order = 9,
		args = {
			multicastdesc = {name = L["Multi-Shot does not leave right away: it has a short cast the game shows no bar for. With this on, a thin line under the bar fills while it casts, so you see the moment it goes out."], type = "description", order = 1},
			multicastcardline = {name = L["Line"], type = "header", order = 1.5},
			multicast = {name = L["Show Multi-Shot's cast"], type = "toggle", width = "double", order = 2},
			multicastpos = {
				name = L["Position"], desc = L["Where the line sits."], type = "select", order = 3,
				values = {BELOW = L["Under the bar"], ABOVE = L["Over the bar"]}, sorting = {"BELOW", "ABOVE"},
				disabled = multiOff,
			},
			multicastheight = {name = L["Line thickness"], type = "range", order = 4, min = 1, max = 20, step = 1, disabled = multiOff},
			multicastwidth = {
				name = L["Width"], desc = L["How wide the line is, as a share of the bar's width."],
				type = "range", order = 5, min = 0.2, max = 1, step = 0.05, isPercent = true, disabled = multiOff,
			},
			multicastcardlook = {name = L["Look"], type = "header", order = 5.5},
			multicastcolor = {name = L["Line color"], type = "color", hasAlpha = true, order = 6, get = getColor, set = setColor, disabled = multiOff},
			multicastalpha = {name = L["Opacity"], type = "range", order = 7, min = 0.2, max = 1, step = 0.05, isPercent = true, disabled = multiOff},
			multicastback = {
				name = L["Dark background"], desc = L["A dark strip behind the line, so you see how far it has to go."],
				type = "toggle", order = 8, disabled = multiOff,
			},
			multicastsample = {
				name = L["Show a sample"], desc = L["Plays the line once, so you see your settings without casting."],
				type = "execute", order = 8.5, func = function() YaHT:MultiCastSample() end, disabled = multiOff,
			},
			multicastcardmore = {name = L["Fine tuning"], type = "header", order = 8.9},
			multicastx = {name = L["Sideways"], desc = L["Moves the line a little from its place."], type = "range", order = 10, min = -100, max = 100, step = 1, disabled = multiOff},
			multicasty = {name = L["Up or down"], desc = L["Moves the line a little from its place."], type = "range", order = 11, min = -100, max = 100, step = 1, disabled = multiOff},
			reset = resetButton("multicast"),
		},
	}
	Tuck(multicastPage.args, "multicast", {"multicastx", "multicasty"}, 9)

	local aceoptions = {
		name = "YaHT Forever - Yet another Hunter Timer",
		type = "group",
		childGroups = "tree", -- sections listed on the left
		get = get,
		set = set,
		args = {
			------------------------------------------------------------------
			general = {
				name = L["General"],
				type = "group",
				order = 1,
				args = {
					about = {
						name = L["Auto Shot timer for WoW Forever."].."  |cff888888"..L["Version"].." "..YaHT.version
							.."  ·  "..L["Original addon by Aviana"].."  ·  "..string.format(L["Improved by %s"], "Tk Deadeye").."|r",
						type = "description",
						fontSize = "medium",
						order = 1,
					},
					lock = {
						name = L["Lock bar"],
						desc = L["Unlock to drag the bar (and the countdown number) and to see a looping preview of every effect."],
						type = "toggle",
						order = 2,
					},
					posheader = {name = L["Position"], type = "header", order = 5},
					barx = {
						name = L["Left / right (X)"],
						desc = L["Where the middle of the bar sits, measured from the middle of the screen (0). The arrows move it one step."],
						type = "range",
						order = 6,
						min = -2000, max = 2000, step = 1,
						get = function() local x = YaHT:GetBarOffset() return x end,
						set = function(_, value) YaHT:SetBarOffset(value, nil) end,
					},
					bary = {
						name = L["Up / down (Y)"],
						desc = L["Where the middle of the bar sits, measured from the middle of the screen (0). The arrows move it one step."],
						type = "range",
						order = 7,
						min = -1200, max = 1200, step = 1,
						get = function() local _, y = YaHT:GetBarOffset() return y end,
						set = function(_, value) YaHT:SetBarOffset(nil, value) end,
					},
					resetpos = {
						name = L["Reset position"],
						desc = L["Move the bar back to the middle of the screen."],
						type = "execute",
						order = 8,
						func = function()
							local p = YaHT.db.profile
							p.point, p.relativePoint, p.x, p.y = nil, nil, nil, nil
							YaHT:ApplySettings()
						end,
					},
					minimap = {
						name = L["Minimap button"],
						desc = L["A YaHT button on the minimap: left-click opens the options, right-click a quick menu, drag to move it."],
						type = "toggle",
						order = 4,
					},
					presetheader = {
						name = L["Quick looks"],
						type = "header",
						order = 10,
					},
					presetdesc = {
						name = L["Click a look to see it in the live preview, then Use this look to keep it. Size, position, colors and the countdown stay as they are."],
						type = "description",
						order = 11,
					},
					presetminimal = {
						name = L["Minimal"],
						desc = L["Just the bar. Every icon and warning is switched off."],
						type = "execute",
						order = 12,
						func = function() ApplyPreset("MINIMAL") end,
					},
					presetclean = {
						name = L["Clean"],
						desc = L["The bar with its icons: procs, aspect, hawks, ammo and Feign Death. No glow."],
						type = "execute",
						order = 13,
						func = function() ApplyPreset("CLEAN") end,
					},
					presetflashy = {
						name = L["Flashy"],
						desc = L["Everything on, with glow, sparks, a light sweep and glowing polished icons."],
						type = "execute",
						order = 14,
						func = function() ApplyPreset("FLASHY") end,
					},
					sizeheader = {
						name = L["Size and opacity"],
						type = "header",
						order = 20,
					},
					width = {
						name = L["Width"],
						type = "range",
						order = 21,
						min = 10,
						max = 600,
						step = 1,
					},
					height = {
						name = L["Height"],
						desc = L["Tip: 14 or more if you want the countdown inside the bar."],
						type = "range",
						order = 22,
						min = 3,
						max = 50,
						step = 1,
					},
					scale = {
						name = L["Scale"],
						desc = L["Size of the bar and everything attached to it."],
						type = "range",
						order = 23,
						isPercent = true,
						min = 0.1,
						max = 3,
						step = 0.05,
					},
					alpha = {
						name = L["Opacity"],
						type = "range",
						order = 24,
						isPercent = true,
						min = 0.1,
						max = 1,
						step = 0.05,
					},
					malpha = {
						name = L["Opacity while moving"],
						desc = L["How faded the bar is while you move. Lower makes the ready pulse stand out more."],
						type = "range",
						order = 25,
						isPercent = true,
						min = 0,
						max = 1,
						step = 0.05,
					},
					reset = resetButton("general"),
				},
			},
			------------------------------------------------------------------
			bar = {
				name = L["Bar"],
				type = "group",
				order = 2,
				args = {
					lookintro = {
						name = L["How the bar itself looks: its texture, colors, background and border."],
						type = "description",
						order = 0,
					},
					barstyle = {
						name = L["Bar style"],
						desc = L["YaHT: the regular bar. Cast bar: the look of Bouk's Hunter Castbar, a WeakAura many hunters know. The reload runs down in blue, then the part where you stand still shows in green, with the shot's name and its time on the bar."],
						type = "select",
						order = 0.5,
						values = {YAHT = L["YaHT"], CASTBAR = L["Cast bar (Bouk's)"]},
						sorting = {"YAHT", "CASTBAR"},
					},
					castbardir = {
						name = L["Stand-still part"],
						desc = L["Whether the green part runs down to empty or fills up to the shot."],
						type = "select",
						order = 0.6,
						values = {DRAIN = L["Runs down"], FILL = L["Fills up"]},
						sorting = {"DRAIN", "FILL"},
						hidden = function() return YaHT.db.profile.barstyle ~= "CASTBAR" end,
					},
					castbarreload = {
						name = L["Reload color"],
						desc = L["Color of the bar while you reload."],
						type = "color",
						order = 0.7,
						get = getColor,
						set = setColor,
						hidden = function() return YaHT.db.profile.barstyle ~= "CASTBAR" end,
					},
					castbarwind = {
						name = L["Stand-still color"],
						desc = L["Color of the part where you must stand still for the shot."],
						type = "color",
						order = 0.8,
						get = getColor,
						set = setColor,
						hidden = function() return YaHT.db.profile.barstyle ~= "CASTBAR" end,
					},
					castbartext = {
						name = L["Name and time on the bar"],
						desc = L["The shot's name on the left of the bar, and the time left of the whole time on the right."],
						type = "toggle",
						order = 0.9,
						hidden = function() return YaHT.db.profile.barstyle ~= "CASTBAR" end,
					},
					statusbar = {
						name = L["Bar texture"],
						type = "select",
						order = 1,
						dialogControl = widget("LSM30_Statusbar"),
						values = getMediaData,
					},
					fill = {
						name = L["Fill from middle"],
						desc = L["Extend the bar from the middle outwards."],
						type = "toggle",
						order = 2,
						hidden = function() return YaHT.db.profile.barstyle == "CASTBAR" end,
					},
					timercolor = {
						name = L["Reload color"],
						desc = L["Color of the bar while you reload."],
						type = "color",
						order = 3,
						get = getColor,
						set = setColor,
						hidden = function() return YaHT.db.profile.barstyle == "CASTBAR" end,
					},
					drawcolor = {
						name = L["Stand-still color"],
						desc = L["Color of the part where you must stand still for the shot."],
						type = "color",
						order = 4,
						get = getColor,
						set = setColor,
						hidden = function() return YaHT.db.profile.barstyle == "CASTBAR" end,
					},
					lonewolfheader = {
						name = L["Lone Wolf"],
						type = "header",
						order = 5,
					},
					lonewolf = {
						name = L["Lone Wolf look"],
						desc = L["For hunters who play without a pet. While no pet is out, the bar turns moonlight silver and becomes a marksman's scope, pet warnings go quiet and Bestial Wrath's place is freed. With a pet out, everything is regular. Automatic: while you have the Lone Wolf talent. Always: switch it on yourself."],
						type = "select",
						order = 5.1,
						values = {AUTO = L["Automatic"], ALWAYS = L["Always"], OFF = L["Off"]},
						sorting = {"AUTO", "ALWAYS", "OFF"},
					},
					lonewolfcolor = {
						name = L["Lone Wolf bar color"],
						type = "color",
						order = 5.2,
						get = getColor,
						set = setColor,
						disabled = function() return YaHT.db.profile.lonewolf == "OFF" end,
					},
					lonewolfglowcolor = {
						name = L["Lone Wolf glow color"],
						type = "color",
						order = 5.3,
						get = getColor,
						set = setColor,
						disabled = function() return YaHT.db.profile.lonewolf == "OFF" end,
					},
					lonewolfstyle = {
						name = L["Bar design"],
						desc = L["Scope: a range scale under the bar, and a crosshair that locks on in the middle when you have to stand still. Plain bar: only the Lone Wolf colors."],
						type = "select",
						order = 5.15,
						values = {SCOPE = L["Scope"], PLAIN = L["Plain bar"]},
						sorting = {"SCOPE", "PLAIN"},
						disabled = function() return YaHT.db.profile.lonewolf == "OFF" end,
					},
					lonewolfheight = {
						name = L["Crosshair size"],
						type = "range",
						order = 5.4,
						min = 12, max = 48, step = 1,
						disabled = function() local p = YaHT.db.profile return p.lonewolf == "OFF" or p.lonewolfstyle == "PLAIN" end,
					},
					lonewolfpet = {
						name = L["Warn: PET OUT"],
						desc = L["You have the Lone Wolf talent and a pet is out in a fight: you lose its bonus. Shows PET OUT where your pet alerts are."],
						type = "toggle",
						order = 5.5,
						disabled = function() return YaHT.db.profile.lonewolf == "OFF" end,
					},
					backgroundheader = {
						name = L["Background"],
						type = "header",
						order = 10,
					},
					enablebackground = {
						name = L["Show background"],
						type = "toggle",
						order = 11,
					},
					background = {
						name = L["Background texture"],
						type = "select",
						order = 12,
						dialogControl = widget("LSM30_Background"),
						values = getMediaData,
						disabled = function() return not YaHT.db.profile.enablebackground end,
					},
					backgroundcolor = {
						name = L["Background color"],
						type = "color",
						order = 13,
						hasAlpha = true,
						get = getColor,
						set = setColor,
						disabled = function() return not YaHT.db.profile.enablebackground end,
					},
					borderheader = {
						name = L["Border"],
						type = "header",
						order = 20,
					},
					enableborder = {
						name = L["Show border"],
						type = "toggle",
						order = 21,
					},
					border = {
						name = L["Border texture"],
						type = "select",
						order = 22,
						dialogControl = widget("LSM30_Border"),
						values = getMediaData,
						disabled = function() return not YaHT.db.profile.enableborder end,
					},
					bordercolor = {
						name = L["Border color"],
						type = "color",
						order = 23,
						get = getColor,
						set = setColor,
						disabled = function() return not YaHT.db.profile.enableborder end,
					},
					reset = resetButton("bar"),
				},
			},
			------------------------------------------------------------------
			text = {
				name = L["Countdown"],
				type = "group",
				order = 3,
				args = {
					textintro = {
						name = L["The number that counts down to your shot, or to when you must stand still."],
						type = "description",
						order = 0,
					},
					showtext = {
						name = L["Show countdown"],
						desc = L["Show the time left as a number with one decimal, like WeaponSwingTimer."],
						type = "toggle",
						order = 1,
					},
					textmode = {
						name = L["Count down to"],
						desc = L["Shot: time until the Auto Shot fires. Stand still: time until you must stop moving."],
						type = "select",
						order = 2,
						values = {SHOT = L["Shot fires"], MOVE = L["Stand still"]},
						disabled = textOff,
					},
					textpos = {
						name = L["Position"],
						desc = L["Snap the number to a spot on the bar. Unlock the bar to drag it freely."],
						type = "select",
						order = 3,
						values = {
							INSIDE_LEFT = L["Inside left"], INSIDE_CENTER = L["Inside center"], INSIDE_RIGHT = L["Inside right"],
							OUTSIDE_LEFT = L["Outside left"], OUTSIDE_RIGHT = L["Outside right"],
							ABOVE = L["Above"], BELOW = L["Below"],
						},
						sorting = {"OUTSIDE_LEFT", "INSIDE_LEFT", "INSIDE_CENTER", "INSIDE_RIGHT", "OUTSIDE_RIGHT", "ABOVE", "BELOW"},
						set = function(info, value)
							local p = YaHT.db.profile
							p.textpos, p.textx, p.texty = value, 0, 0
							YaHT:ApplySettings()
						end,
						disabled = textOff,
					},
					textsize = {
						name = L["Font size"],
						type = "range",
						order = 4,
						min = 6,
						max = 32,
						step = 1,
						disabled = textOff,
					},
					font = {
						name = L["Font"],
						type = "select",
						order = 5,
						dialogControl = widget("LSM30_Font"),
						values = getMediaData,
						disabled = textOff,
					},
					textcolor = {
						name = L["Text color"],
						type = "color",
						hasAlpha = true,
						order = 6,
						get = getColor,
						set = setColor,
						disabled = textOff,
					},
					offsetheader = {
						name = L["Fine-tune"],
						type = "header",
						order = 10,
					},
					textx = {
						name = L["X offset"],
						desc = L["Fine-tune the position. You can also drag the number while the bar is unlocked."],
						type = "range",
						order = 11,
						min = -300,
						max = 300,
						step = 1,
						disabled = textOff,
					},
					texty = {
						name = L["Y offset"],
						desc = L["Fine-tune the position. You can also drag the number while the bar is unlocked."],
						type = "range",
						order = 12,
						min = -100,
						max = 100,
						step = 1,
						disabled = textOff,
					},
					reset = resetButton("text"),
				},
			},
			------------------------------------------------------------------
			glow = {
				name = L["Glow"],
				type = "group",
				order = 4,
				args = {
					glowintro = {
						name = L["Effects that help you feel the rhythm: a glow as the shot gets close, and sparks at the moving edge of the bar."],
						type = "description",
						order = 0,
					},
					glow = {
						name = L["Show glow"],
						desc = L["Glow around the bar: none when the bar is full, building up as the reload runs out, full when you need to stand still."],
						type = "toggle",
						order = 1,
					},
					glowmode = {
						name = L["Light up"],
						desc = L["Build up: glow grows during the reload. Stand still only: glow appears just for the stand-still part."],
						type = "select",
						order = 2,
						values = {RAMP = L["Build up"], STAND = L["Stand still only"]},
						disabled = glowOff,
					},
					glowlook = {
						name = L["Glow look"],
						desc = L["Soft: blurry halo. Outline: crisp bright border."],
						type = "select",
						order = 3,
						values = {SOFT = L["Soft"], OUTLINE = L["Outline"]},
						disabled = glowOff,
					},
					glowstyle = {
						name = L["Extra effect while you stand still"],
						desc = L["Extra effect while you need to stand still. Pixel/Autocast/Proc/Button are borrowed from LibCustomGlow and only appear when WeakAuras (or another addon that includes it) is installed."],
						type = "select",
						order = 4,
						values = function()
							local v = {BUILTIN = L["Glow only"], SWEEP = L["Sweep (light runs across the bar)"]}
							if YaHT:GetLCG() then
								v.PIXEL = L["Pixel (animated lines)"]
								v.AUTOCAST = L["Autocast (sparkles)"]
								v.PROC = L["Proc (spell alert)"]
								v.BUTTON = L["Button (action bar glow)"]
							end
							return v
						end,
						disabled = glowOff,
					},
					glowkeepbuiltin = {
						name = L["Keep soft glow too"],
						desc = L["Show the built-in glow underneath the animated effect."],
						type = "toggle",
						order = 5,
						hidden = function() local st = YaHT.db.profile.glowstyle return st == "BUILTIN" or st == "SWEEP" end,
						disabled = glowOff,
					},
					glowpulse = {
						name = L["Pulse while you stand still"],
						desc = L["Pulse the glow during the stand-still part."],
						type = "toggle",
						order = 6,
						disabled = glowOff,
					},
					tuneheader = {
						name = L["Fine-tune"],
						type = "header",
						order = 10,
					},
					glowramp = {
						name = L["Build-up strength"],
						desc = L["How bright the glow gets by the end of the reload, before you stand still."],
						type = "range",
						order = 11,
						isPercent = true,
						min = 0.1,
						max = 1,
						step = 0.05,
						disabled = function() return glowOff() or YaHT.db.profile.glowmode == "STAND" end,
					},
					glowintensity = {
						name = L["Glow brightness"],
						type = "range",
						order = 12,
						isPercent = true,
						min = 0.1,
						max = 1,
						step = 0.05,
						disabled = glowOff,
					},
					glowsize = {
						name = L["Glow size"],
						type = "range",
						order = 13,
						min = 2,
						max = 40,
						step = 1,
						disabled = glowOff,
					},
					glowcolor = {
						name = L["Glow color"],
						type = "color",
						order = 14,
						get = getColor,
						set = setColor,
						disabled = glowOff,
					},
					reset = resetButton("glow"),
				},
			},
			------------------------------------------------------------------
			spark = {
				name = L["Spark"],
				type = "group",
				order = 5,
				args = {
					sparkmode = {
						name = L["Sparks"],
						desc = L["A bright line at the moving edge of the bar. In the stand-still part the bar grows out from the middle, so the sparks start in the centre and race to the ends as the shot fires."],
						type = "select",
						order = 1,
						values = {OFF = L["Off"], STAND = L["Stand-still part only"], ALWAYS = L["Always"]},
						sorting = {"OFF", "STAND", "ALWAYS"},
					},
					readypulse = {
						name = L["Ready pulse while moving"],
						desc = L["When the shot is ready but you're moving, two lines pulse in the middle of the bar until you stop. Works even with the spark set to Off."],
						type = "toggle",
						width = "double",
						order = 2,
					},
					sparksize = {
						name = L["Spark height"],
						desc = L["Spark height compared to the bar height."],
						type = "range",
						order = 3,
						min = 1,
						max = 8,
						step = 0.5,
						disabled = sparkOff,
					},
					sparkcolor = {
						name = L["Spark color"],
						type = "color",
						hasAlpha = true,
						order = 4,
						get = getColor,
						set = setColor,
						disabled = sparkOff,
					},
					reset = resetButton("spark"),
				},
			},
			------------------------------------------------------------------
			melee = {
				name = L["Melee"],
				type = "group",
				order = 5.7,
				args = {
					meleedesc = {
						name = string.format(L["A hair-thin line under the Auto Shot bar that fills with your melee swing. It fades in only while you're hitting things in melee, turns gold while %s is queued for your next swing, and a small glint runs along it on every swing."], raptor),
						type = "description",
						order = 1,
					},
					melee = {
						name = L["Show melee swing line"],
						type = "toggle",
						width = "double",
						order = 2,
					},
					meleemode = {
						name = L["Show the line"],
						desc = L["Only while meleeing: the line appears when you swing in melee. The whole fight: it stays up for the whole fight."],
						type = "select",
						order = 3,
						values = {MELEE = L["Only while meleeing"], COMBAT = L["The whole fight"]},
						sorting = {"MELEE", "COMBAT"},
						disabled = meleeOff,
					},
					meleeheight = {
						name = L["Line thickness"],
						type = "range",
						order = 4,
						min = 1,
						max = 6,
						step = 1,
						disabled = meleeOff,
					},
					meleealpha = {
						name = L["Opacity"],
						type = "range",
						order = 5,
						min = 0.2,
						max = 1,
						step = 0.05,
						isPercent = true,
						disabled = meleeOff,
					},
					meleecolor = {
						name = L["Line color"],
						type = "color",
						hasAlpha = true,
						order = 6,
						get = getColor,
						set = setColor,
						disabled = meleeOff,
					},
					meleeglint = {
						name = L["Glint on each swing"],
						desc = L["A small light runs along the line on every swing."],
						type = "toggle",
						order = 7,
						disabled = meleeOff,
					},
					raptorheader = {
						name = raptor,
						type = "header",
						order = 10,
					},
					meleeraptor = {
						name = string.format(L["Gold while %s is queued"], raptor),
						desc = string.format(L["%s hits on your next swing. The line turns this color while it's waiting, so you can see it's loaded."], raptor),
						type = "toggle",
						width = "double",
						order = 11,
						disabled = meleeOff,
					},
					meleeraptorcolor = {
						name = L["Highlight color"],
						type = "color",
						hasAlpha = true,
						order = 12,
						get = getColor,
						set = setColor,
						disabled = raptorOff,
					},
					reset = resetButton("melee"),
				},
			},
			------------------------------------------------------------------
			procs = {
				name = L["Procs"],
				type = "group",
				order = 5.72,
				args = procsArgs,
			},
			------------------------------------------------------------------
			pet = {
				name = L["Pet"],
				type = "group",
				order = 5.745,
				args = {
					petdesc = {
						name = L["Small warning text for your pet: when it's low on health, dead or missing in a fight, or not attacking while you shoot. It's a separate alert: unlock the bar to drag it anywhere on your screen."],
						type = "description",
						order = 1,
					},
					pet = {
						name = L["Show pet alerts"],
						type = "toggle",
						width = "double",
						order = 2,
					},
					warnheader = {name = L["Warn me when my pet is"], type = "header", order = 10},
					petdead = {
						name = L["Dead or missing"],
						desc = L["In a fight, when your pet is dead or not out."],
						type = "toggle",
						order = 11,
						disabled = petOff,
					},
					petidle = {
						name = L["Not attacking"],
						desc = L["When you've been shooting for 3 seconds and your pet isn't attacking anything."],
						type = "toggle",
						order = 12,
						disabled = petOff,
					},
					petlow = {
						name = L["Low on health"],
						desc = L["The game hides your pet's exact health from addons, so this warning can't play a sound."],
						type = "toggle",
						order = 13,
						disabled = petOff,
					},
					petlowat = {
						name = L["Low means below"],
						type = "range",
						order = 14,
						min = 0.1, max = 0.6, step = 0.05,
						isPercent = true,
						get = function() return YaHT.db.profile.petlowat / 100 end,
						set = function(_, v) YaHT.db.profile.petlowat = math.floor(v * 100 + 0.5) YaHT:ApplySettings() end,
						disabled = petLowOff,
					},
					petwhen = {
						name = L["Low health shows"],
						desc = L["In combat or while shooting: only then. Always: whenever your pet is out."],
						type = "select",
						order = 15,
						values = {COMBAT = L["In combat or while shooting"], ALWAYS = L["Always"]},
						sorting = {"COMBAT", "ALWAYS"},
						disabled = petLowOff,
					},
					lookheader = {name = L["Look"], type = "header", order = 20},
					pettextsize = {name = L["Font size"], type = "range", order = 21, min = 8, max = 24, step = 1, disabled = petOff},
					petpulse = {
						name = L["Pulse"],
						desc = L["The dead, missing and not-attacking warnings pulse. PET LOW stays steady."],
						type = "toggle",
						order = 22,
						disabled = petOff,
					},
					petsound = {
						name = L["Play a warning sound"],
						desc = L["Plays when your pet dies or is missing in a fight."],
						type = "toggle",
						order = 23,
						disabled = petOff,
					},
					reset = resetButton("pet"),
				},
			},
			------------------------------------------------------------------
			hawk = {
				name = L["Hawks"],
				type = "group",
				order = 5.746,
				args = {
					hawkdesc = {
						name = L["Your Summon Hawk hawks as small round icons at the top left of the bar. The ring around each one runs down over the hawk's 18 seconds. Up to two hawks can be out at once."],
						type = "description",
						order = 1,
					},
					hawk = {
						name = L["Show hawk circles"],
						type = "toggle",
						width = "double",
						order = 2,
					},
					hawkshape = {
						name = L["Shape"],
						desc = L["Circle: a round icon whose ring runs down. Square: the hawks look like the other proc icons, a square icon with a gold timer line under it, and take the same settings: the shared look or their own, a glow, a pulse and a sound."],
						type = "select",
						order = 2.5,
						values = {CIRCLE = L["Circle"], SQUARE = L["Square (like the other icons)"]},
						sorting = {"CIRCLE", "SQUARE"},
						disabled = hawkOff,
					},
					hawkmode = {
						name = L["Layout"],
						desc = L["One per hawk shows each hawk's own time. One with a count is smaller: it follows the hawk that ends first, and a number says how many are out."],
						type = "select",
						order = 3,
						values = {EACH = L["One per hawk"], COUNT = L["One with a count"]},
						sorting = {"EACH", "COUNT"},
						disabled = hawkOff,
					},
					hawkpos = {
						name = L["Position"],
						desc = L["Anywhere: unlock the bar, then drag the circles where you want them."],
						type = "select",
						order = 4,
						values = {TOPLEFT = L["Top left of the bar"], TOPRIGHT = L["Top right of the bar"],
							ABOVE = L["Above the bar"], LEFT = L["Left of the bar"], RIGHT = L["Right of the bar"], FREE = L["Anywhere (drag it)"]},
						sorting = {"TOPLEFT", "TOPRIGHT", "ABOVE", "LEFT", "RIGHT", "FREE"},
						disabled = hawkOff,
					},
					hawkglowcolor = {
						name = L["Glow color"],
						type = "color",
						order = 4.5,
						get = getColor,
						set = setColor,
						hidden = hawkRound,
						disabled = function()
							local p = YaHT.db.profile
							local glow = p.hawkown and p.hawkiconglow or p.procglow
							return not p.hawk or glow == "NONE"
						end,
					},
					lookheader = {name = L["Look"], type = "header", order = 10},
					hawkpolish = {
						name = L["Polished look"],
						desc = L["A bevelled ring with fine edges, a soft light on the icon, a glow around the circle that breathes when the ring is red, and a shadow under it. Off: the standard look, a plain flat ring."],
						type = "toggle",
						order = 10.5,
						hidden = hawkSquare,
						disabled = hawkOff,
					},
					hawksize = {name = L["Size"], type = "range", order = 11, min = 16, max = 48, step = 1, hidden = hawkSquare, disabled = hawkOff},
					hawkalpha = {name = L["Opacity"], type = "range", order = 12, min = 0.2, max = 1, step = 0.05, isPercent = true, hidden = hawkSquare, disabled = hawkOff},
					-- as squares: the look all proc icons share, or their own (exactly as on a proc icon's page)
					hawksharednote = {
						name = L["In the square shape the hawks take the look all proc icons share (size, opacity, glow, pulse, sound and the polished look). Change it under the look of all proc icons, or give the hawks their own look here."],
						type = "description",
						order = 10.1,
						hidden = function() local p = YaHT.db.profile return p.hawkshape ~= "SQUARE" or p.hawkown end,
					},
					hawkown = {
						name = L["Its own look"],
						desc = L["Give this icon its own size, opacity, glow, pulse and sound, instead of the look all proc icons share. It starts out as a copy of the shared look."],
						type = "toggle",
						width = "double",
						order = 10.2,
						set = function(info, value)
							local p = YaHT.db.profile
							if value and not p.hawkownset then
								-- the first time: start from what the squares look like now
								for _, part in ipairs(OWN_LOOK) do p["hawkicon" .. part] = p["proc" .. part] end
								p.hawkownset = true
							end
							p.hawkown = value
							YaHT:ApplySettings()
						end,
						hidden = hawkRound,
						disabled = hawkOff,
					},
					hawkiconsize = {name = L["Icon size"], type = "range", order = 10.31, min = 16, max = 64, step = 1, hidden = hawkOwnOff, disabled = hawkOff},
					hawkiconalpha = {name = L["Opacity"], type = "range", order = 10.32, min = 0.2, max = 1, step = 0.05, isPercent = true, hidden = hawkOwnOff, disabled = hawkOff},
					hawkiconglow = {name = L["Glow style"], type = "select", order = 10.33, values = glowValues, sorting = glowSorting, hidden = hawkOwnOff, disabled = hawkOff},
					hawkiconpulse = {name = L["Pulse style"], type = "select", order = 10.34, values = PULSE_VALUES, sorting = PULSE_SORTING, hidden = hawkOwnOff, disabled = hawkOff},
					hawkiconsound = {name = L["Play a sound when it pops up"], type = "toggle", width = "double", order = 10.35, hidden = hawkOwnOff, disabled = hawkOff},
					hawkiconpolish = {name = L["Polished look"], desc = SQUARE_POLISH, type = "toggle", order = 10.36, hidden = hawkOwnOff, disabled = hawkOff},
					hawknumbers = {
						name = L["Show seconds left"],
						desc = L["The seconds each hawk has left, as a number by its circle."],
						type = "toggle",
						order = 13,
						disabled = hawkOff,
					},
					hawknumpos = {
						name = L["Number position"],
						desc = L["Where the seconds are written: under the circle, in the middle of it over the icon, or above it."],
						type = "select",
						order = 13.5,
						values = {BOTTOM = L["Under the icon"], MIDDLE = L["In the middle"], TOP = L["Above the icon"]},
						sorting = {"BOTTOM", "MIDDLE", "TOP"},
						disabled = hawkNumOff,
					},
					hawkempty = {
						name = L["Show a free spot greyed out"],
						desc = L["With one hawk out, the second circle shows greyed out, so you see there is room for another. Off: only the hawks that are out are shown."],
						type = "toggle",
						order = 13.7,
						disabled = hawkEachOff,
					},
					hawkwarn = {
						name = L["Turn red below (seconds)"],
						desc = L["The ring and the number turn red when a hawk has fewer seconds left than this. Summon Hawk shares its cooldown with Arcane Shot, so a red ring means: summon again before you spend it. 0 switches the red off."],
						type = "range",
						order = 14,
						min = 0, max = 12, step = 1,
						disabled = hawkOff,
					},
					reset = resetButton("hawk"),
				},
			},
			------------------------------------------------------------------
			feign = {
				name = L["Feign Death"],
				type = "group",
				order = 5.74,
				args = {
					feigndesc = {
						name = L["When a mob resists your Feign Death, the Feign Death icon pops up with RESIST under it and a warning sound plays. It's a separate alert: unlock the bar to drag it anywhere on your screen."],
						type = "description",
						order = 1,
					},
					feign = {
						name = L["Show the resist alert"],
						type = "toggle",
						width = "double",
						order = 2,
					},
					feigntest = {
						name = L["Test it"],
						desc = L["Plays the alert once, so you can see and hear it."],
						type = "execute",
						order = 3,
						func = function() YaHT:TestFeignAlert() end,
						disabled = feignOff,
					},
					feignscale = {name = L["Size"], type = "range", order = 4, min = 0.5, max = 3, step = 0.05, isPercent = true, disabled = feignOff},
					feigntime = {name = L["Seconds on screen"], type = "range", order = 5, min = 1, max = 6, step = 0.5, disabled = feignOff},
					feigncolor = {
						name = L["Color"],
						type = "color",
						order = 6,
						get = getColor,
						set = setColor,
						disabled = feignOff,
					},
					feignsound = {name = L["Play a warning sound"], type = "toggle", order = 7, disabled = feignOff},
					detectheader = {name = L["How a resist is noticed"], type = "header", order = 10},
					feignthreatcheck = {
						name = L["You're still on the mob's threat list"],
						desc = L["A feign that works takes you off your target's threat list within about a second. If you're still on it after that, it counts as resisted. This is the fastest sign when the game shows no \"Resisted\" message."],
						type = "toggle",
						width = "double",
						order = 12,
						disabled = feignOff,
					},
					feigntargetcheck = {
						name = L["Your target still targets you"],
						desc = L["Also counts a resist when the mob still targets you 1.5 and 2.5 seconds after you feign. The game's own \"Resisted\" message always counts."],
						type = "toggle",
						width = "double",
						order = 13,
						disabled = feignOff,
					},
					reset = resetButton("feign"),
				},
			},
			------------------------------------------------------------------
			aspect = {
				name = L["Aspect"],
				type = "group",
				order = 5.73,
				args = {
					aspectdesc = {
						name = L["A small icon of the aspect you're in, next to the bar. It stays quiet while it's fine and turns red and pulses when it's risky: Cheetah or Pack in a fight (one hit dazes you), or no aspect at all."],
						type = "description",
						order = 1,
					},
					aspect = {
						name = L["Show your aspect"],
						type = "toggle",
						width = "double",
						order = 2,
					},
					aspectwhen = {
						name = L["When"],
						desc = L["In combat or while shooting: the badge shows only then. Always: also out of combat."],
						type = "select",
						order = 3,
						values = {COMBAT = L["In combat or while shooting"], ALWAYS = L["Always"]},
						sorting = {"COMBAT", "ALWAYS"},
						disabled = aspectOff,
					},
					aspectpos = {
						name = L["Position"],
						desc = L["Anywhere: unlock the bar (/yaht unlock) and drag the icon where you want it."],
						type = "select",
						order = 4,
						values = {ABOVE = L["Above the bar"], LEFT = L["Left of the bar"], RIGHT = L["Right of the bar"], FREE = L["Anywhere (drag it)"]},
						sorting = {"ABOVE", "LEFT", "RIGHT", "FREE"},
						disabled = aspectOff,
					},
					aspectsize = {name = L["Icon size"], type = "range", order = 5, min = 14, max = 48, step = 1, disabled = aspectOff},
					aspectpolish = {name = L["Polished look"], desc = SQUARE_POLISH, type = "toggle", order = 6.5, disabled = aspectOff},
					aspectshape = {name = L["Shape"], type = "select", order = 4.5, values = SHAPE_VALUES, sorting = SHAPE_SORTING, disabled = aspectOff},
					aspectalpha = {
						name = L["Opacity while it's fine"],
						desc = L["Warnings always show at full strength."],
						type = "range",
						order = 6,
						min = 0.2,
						max = 1,
						step = 0.05,
						isPercent = true,
						disabled = aspectOff,
					},
					warnheader = {name = L["Warnings"], type = "header", order = 10},
					aspectwarnspeed = {
						name = L["Red: Cheetah or Pack in a fight"],
						desc = L["Getting hit while in Aspect of the Cheetah or the Pack dazes you."],
						type = "toggle",
						width = "double",
						order = 11,
						disabled = aspectOff,
					},
					aspectpackalert = {
						name = L["Pack in a fight"],
						desc = L["How this aspect gets your attention when a fight starts with it on, besides the red badge: its name in bouncing words (unlock the bar to drag them), its icon bouncing and glowing, or both."],
						type = "select",
						order = 11.1,
						values = SPEED_ALERT_VALUES,
						sorting = SPEED_ALERT_SORTING,
						disabled = function() local p = YaHT.db.profile return not p.aspect or not p.aspectwarnspeed end,
					},
					aspectcheetahalert = {
						name = L["Cheetah in a fight"],
						desc = L["How this aspect gets your attention when a fight starts with it on, besides the red badge: its name in bouncing words (unlock the bar to drag them), its icon bouncing and glowing, or both."],
						type = "select",
						order = 11.15,
						values = SPEED_ALERT_VALUES,
						sorting = SPEED_ALERT_SORTING,
						disabled = function() local p = YaHT.db.profile return not p.aspect or not p.aspectwarnspeed end,
					},
					aspecthit = {
						name = L["Bigger and flashing when you are hit"],
						desc = L["While Pack or Cheetah is on in a fight: each time you take a hit, the kind that can daze you, the warning doubles in size and flashes for a moment. (The game hides the Dazed effect itself from addons in a fight, so this goes by the hits.)"],
						type = "toggle",
						width = "double",
						order = 11.17,
						disabled = function()
							local p = YaHT.db.profile
							return not p.aspect or not p.aspectwarnspeed or (p.aspectpackalert == "OFF" and p.aspectcheetahalert == "OFF")
						end,
					},
					aspectshoutsize = {
						name = L["Size of the words"],
						type = "range",
						order = 11.2,
						min = 10, max = 48, step = 1,
						disabled = function()
							local p = YaHT.db.profile
							local function words(v) return v == "WORDS" or v == "BOTH" end
							return not p.aspect or not p.aspectwarnspeed or not (words(p.aspectpackalert) or words(p.aspectcheetahalert))
						end,
					},
					aspectspeedalways = {
						name = L["Always show Cheetah and Pack"],
						desc = L["Shows the icon any time you're in Aspect of the Cheetah or the Pack, also out of combat, so you don't forget you're in them."],
						type = "toggle",
						width = "double",
						order = 11.5,
						disabled = aspectOff,
					},
					aspectwarnnone = {
						name = L["Warn when you have no aspect"],
						desc = L["Red when you're in a fight without any aspect. Out of a fight it's a yellow reminder, while you shoot or when the badge is set to show always."],
						type = "toggle",
						width = "double",
						order = 12,
						disabled = aspectOff,
					},
					aspecthint = {
						name = L["Yellow hint: Hawk in melee, Monkey at range"],
						desc = L["Uses the range warnings to know where you are, so those need to be switched on."],
						type = "toggle",
						width = "double",
						order = 13,
						disabled = aspectOff,
					},
					aspectsound = {
						name = L["Sound on a red warning"],
						desc = L["Plays a warning sound the moment the badge turns red."],
						type = "toggle",
						order = 14,
						disabled = aspectOff,
					},
					reset = resetButton("aspect"),
				},
			},
			------------------------------------------------------------------
			range = {
				name = L["Range"],
				type = "group",
				order = 5.75,
				args = {
					rangedesc = {
						name = L["While you're fighting, you see when you can't shoot: yellow stripes in the deadzone, red arrows pointing you closer when you're too far away. Nothing shows in normal shooting range."],
						type = "description",
						order = 1,
					},
					meleerange = {
						name = L["Show deadzone and too-far warnings"],
						desc = L["Yellow stripes in the deadzone, red arrows when you're too far. Nothing shows in normal shooting range."],
						type = "toggle",
						width = "double",
						order = 2,
					},
					meleerangewhen = {
						name = L["When"],
						desc = L["In combat: while you're fighting or Auto Shot is on. Always: any time you have an enemy targeted, also out of combat (handy for pulling from the right spot)."],
						type = "select",
						order = 3,
						values = {COMBAT = L["In combat only"], ALWAYS = L["Always (enemy targeted)"]},
						sorting = {"COMBAT", "ALWAYS"},
						disabled = rangeOff,
					},
					rangepics = {
						name = L["Show the stripes and arrows"],
						desc = L["The pictures: yellow stripes in the deadzone, red arrows when you're too far. Switch them off to have the warning as text only."],
						type = "toggle",
						width = "double",
						order = 3.5,
						disabled = rangeOff,
					},
					textheader = {name = L["Warning text"], type = "header", order = 4},
					rangetext = {
						name = L["Show the warning as text"],
						desc = L["Small text that says it in words. It is not attached to the bar: unlock the bar and drag the text where you want it."],
						type = "toggle",
						width = "double",
						order = 4.1,
						disabled = rangeOff,
						-- text needs no moving pictures: switching it on switches the stripes and arrows off,
						-- switching it off brings them back (they keep their own switch, for having both)
						set = function(info, value)
							local p = YaHT.db.profile
							p.rangetext = value and true or false
							p.rangepics = not value
							YaHT:ApplySettings()
						end,
					},
					rangetextsize = {name = L["Font size"], type = "range", order = 4.2, min = 8, max = 40, step = 1, disabled = rangeTextOff},
					rangetextdead = {name = L["Text in the deadzone"], type = "toggle", order = 4.3, disabled = rangeTextOff},
					rangetextdeadmsg = {
						name = L["Deadzone wording"], desc = L["What the text says. Leave it empty for the usual words."],
						type = "input", order = 4.4, disabled = rangeTextOff,
					},
					rangetextdeadcolor = {name = L["Deadzone text color"], type = "color", order = 4.5, get = getColor, set = setColor, disabled = rangeTextOff},
					rangetextfar = {name = L["Text when too far"], type = "toggle", order = 4.6, disabled = rangeTextOff},
					rangetextfarmsg = {
						name = L["Too far wording"], desc = L["What the text says. Leave it empty for the usual words."],
						type = "input", order = 4.7, disabled = rangeTextOff,
					},
					rangetextfarcolor = {name = L["Too far text color"], type = "color", order = 4.8, get = getColor, set = setColor, disabled = rangeTextOff},
					deadheader = {
						name = L["Deadzone"],
						type = "header",
						order = 10,
					},
					meleedeadstyle = {
						name = L["Deadzone warning on"],
						desc = L["Line: the thin line under the bar turns into drifting stripes. Bar: the Auto Shot bar itself turns into caution tape (you can't see the reload behind it while you're in the deadzone)."],
						type = "select",
						order = 11,
						values = {LINE = L["The line under the bar"], BAR = L["The Auto Shot bar"]},
						sorting = {"LINE", "BAR"},
						disabled = rangeOff,
					},
					meleedeadcolor = {
						name = L["Deadzone color"],
						type = "color",
						hasAlpha = true,
						order = 12,
						get = getColor,
						set = setColor,
						disabled = rangeOff,
					},
					meleedeadalpha = {
						name = L["Opacity"],
						type = "range",
						order = 13.5,
						min = 0.2,
						max = 1,
						step = 0.05,
						isPercent = true,
						disabled = rangeOff,
					},
					meleedeadheight = {
						name = L["Stripe thickness"],
						desc = L["How tall the striped line is. Only used when the warning is on the line."],
						type = "range",
						order = 13,
						min = 3,
						max = 14,
						step = 1,
						disabled = function() local p = YaHT.db.profile return not p.meleerange or p.meleedeadstyle == "BAR" end,
					},
					farheader = {
						name = L["Too far"],
						type = "header",
						order = 20,
					},
					meleefarcolor = {
						name = L["Too far color"],
						type = "color",
						hasAlpha = true,
						order = 21,
						get = getColor,
						set = setColor,
						disabled = rangeOff,
					},
					meleefaralpha = {
						name = L["Opacity"],
						type = "range",
						order = 23,
						min = 0.2,
						max = 1,
						step = 0.05,
						isPercent = true,
						disabled = rangeOff,
					},
					meleefarsize = {
						name = L["Arrow size"],
						type = "range",
						order = 22,
						min = 6,
						max = 20,
						step = 1,
						disabled = rangeOff,
					},
					lookheader = {
						name = L["Motion"],
						type = "header",
						order = 30,
					},
					meleewarnspeed = {
						name = L["Animation speed"],
						desc = L["How fast the stripes drift and the arrows slide (and the deadzone glow pulses)."],
						type = "range",
						order = 31,
						min = 0.25,
						max = 2.5,
						step = 0.05,
						isPercent = true,
						disabled = rangeOff,
					},
					meleewarnboost = {
						name = L["Extra brightness"],
						desc = L["Adds a lit-up copy of the stripes and arrows on top, so they look bright instead of painted on. 0% is the plain color."],
						type = "range",
						order = 32,
						min = 0,
						max = 1,
						step = 0.05,
						isPercent = true,
						disabled = rangeOff,
					},
					meleewarnglow = {
						name = L["Deadzone glow"],
						desc = L["A soft light around the deadzone stripes, in the deadzone color. Around the whole bar when the warning is on the bar."],
						type = "select",
						order = 14,
						values = {NONE = L["None"], SOFT = L["Soft"], PULSE = L["Pulsing"]},
						sorting = {"NONE", "SOFT", "PULSE"},
						disabled = rangeOff,
					},
					meleewarnglowsize = {
						name = L["Glow size"],
						type = "range",
						order = 15,
						min = 4,
						max = 30,
						step = 1,
						disabled = glowWarnOff,
					},
					meleewarnglowalpha = {
						name = L["Glow strength"],
						type = "range",
						order = 16,
						min = 0.1,
						max = 1,
						step = 0.05,
						isPercent = true,
						disabled = glowWarnOff,
					},
					reset = resetButton("range"),
				},
			},
			------------------------------------------------------------------
			ammo = {
				name = L["Ammo"],
				type = "group",
				order = 5.5,
				args = {
					ammodesc = {
						name = L["A movable ammo icon: invisible while you have plenty, fading in as it runs down, flashing yellow when low and red when almost out. Unlock the bar to drag it."],
						type = "description",
						order = 1,
					},
					ammo = {
						name = L["Show ammo counter"],
						type = "toggle",
						order = 2,
					},
					ammosize = {
						name = L["Icon size"],
						type = "range",
						order = 3,
						min = 16,
						max = 80,
						step = 1,
						disabled = function() return not YaHT.db.profile.ammo end,
					},
					levelsheader = {
						name = L["Warning levels"],
						type = "header",
						order = 10,
					},
					ammofadestart = {
						name = L["Start fading in at"],
						desc = L["Above this many the icon stays at its 'plenty' visibility; below it, it fades in."],
						type = "range",
						order = 11,
						min = 100,
						max = 4000,
						softMax = 2000,
						step = 50,
						disabled = function() return not YaHT.db.profile.ammo end,
					},
					ammolow = {
						name = L["Low at"],
						desc = L["Flashes yellow at or below this many."],
						type = "range",
						order = 12,
						min = 10,
						max = 1000,
						step = 10,
						disabled = function() return not YaHT.db.profile.ammo end,
					},
					ammocrit = {
						name = L["Almost out at"],
						desc = L["Flashes red, faster, at or below this many."],
						type = "range",
						order = 13,
						min = 0,
						max = 500,
						step = 5,
						disabled = function() return not YaHT.db.profile.ammo end,
					},
					ammofullalpha = {
						name = L["Opacity when you have plenty"],
						desc = L["0% = completely hidden while you have plenty of ammo."],
						type = "range",
						order = 14,
						isPercent = true,
						min = 0,
						max = 1,
						step = 0.05,
						disabled = function() return not YaHT.db.profile.ammo end,
					},
					ammoflash = {
						name = L["Flash when low"],
						desc = L["The icon flashes yellow when you're low and red when you're almost out."],
						type = "toggle",
						order = 15,
						disabled = function() return not YaHT.db.profile.ammo end,
					},
					ammosound = {
						name = L["Warning sound"],
						desc = L["Play a sound once when you drop to low, and again at almost out."],
						type = "toggle",
						order = 16,
						disabled = function() return not YaHT.db.profile.ammo end,
					},
					ammoresetpos = {
						name = L["Reset position"],
						desc = L["Put the ammo icon back above the bar."],
						type = "execute",
						order = 20,
						func = function()
							local p = YaHT.db.profile
							p.ammopoint, p.ammorelpoint, p.ammox, p.ammoy = nil, nil, nil, nil
							YaHT:ApplySettings()
						end,
					},
					reset = resetButton("ammo"),
				},
			},
			------------------------------------------------------------------
			timing = {
				name = L["Timing"],
				type = "group",
				order = 6,
				args = {
					timingdesc = {
						name = L["The defaults match WoW Forever. Only change these if the bar is early or late; /yaht debug prints the real timings after each shot."],
						type = "description",
						order = 1,
					},
					windupauto = {
						name = L["Automatic wind-up"],
						desc = L["Wind-up = 0.5s scaled by your ranged haste (WoW Forever behaviour). Turn off to set it by hand."],
						type = "toggle",
						order = 2,
					},
					windup = {
						name = L["Wind-up time"],
						desc = L["How long you must stand still before each Auto Shot fires. WoW Forever base: 0.5. Original Classic addon: 0.65."],
						type = "range",
						order = 3,
						min = 0.2,
						max = 1.0,
						step = 0.05,
						disabled = function() return YaHT.db.profile.windupauto end,
					},
					autocorrect = {
						name = L["Self-correcting timing"],
						desc = L["Learns the small extra delay between shots (latency etc.) while you stand still and shoot, and syncs the red part to the moment the game starts the shot."],
						type = "toggle",
						width = "double",
						order = 3.5,
					},
					smooth = {
						name = L["Smooth out network jitter"],
						desc = L["Shots are evenly spaced, but the game's message about each one arrives a little early or late. Keeps the bar on a steady rhythm instead of jumping with every message."],
						type = "toggle",
						width = "double",
						order = 3.55,
					},
					relearn = {
						name = L["Relearn timing"],
						desc = L["Forget the learned delay and measure it again from your next shots."],
						type = "execute",
						order = 3.6,
						func = function()
							YaHT.calib, YaHT.calibSamples = nil, nil
							YaHT.db.char.calib = nil
						end,
						disabled = function() return not YaHT.db.profile.autocorrect end,
					},
					castholds = {
						name = L["Casts hold Auto Shot"],
						desc = L["Pause the timer during Aimed Shot / Multi-Shot casts (old Classic behaviour). Leave off on WoW Forever, where Auto Shot keeps firing during casts."],
						type = "toggle",
						width = "double",
						order = 4,
					},
					reset = resetButton("timing"),
				},
			},
			------------------------------------------------------------------
			announce = {
				name = L["Announce"],
				type = "group",
				order = 7,
				args = {
					announcedesc = {
						name = L["WoW Forever blocks addon chat during boss fights, and Say/Yell/Channel outside instances; YaHT skips those quietly."],
						type = "description",
						order = 1,
					},
					tranqannounce = {
						name = string.format(L["Announce %s"], tranq),
						desc = L["Enable / disable the announcement."],
						type = "toggle",
						order = 2,
						width = "double",
					},
					announcetype = {
						name = L["Announce in"],
						desc = L["The channel in which to announce."],
						type = "select",
						order = 4,
						values = {["WHISPER"] = L["Whisper"], ["CHANNEL"] = L["Channel"], ["RAID_WARNING"] = L["Raid Warning"], ["SAY"] = L["Say"], ["YELL"] = L["Yell"], ["PARTY"] = L["Party"], ["RAID"] = L["Raid"]},
						set = function(info, value) set(info, value) AceConfigRegistry:NotifyChange(Addon) end,
					},
					targetchannel = {
						name = L["Channel or player name"],
						desc = L["Set the channel or player for whisper."],
						type = "input",
						order = 5,
						hidden = function() local t = YaHT.db.profile.announcetype return not (t == "WHISPER" or t == "CHANNEL") end,
					},
					announcemsg = {
						name = L["Message"],
						desc = L["Set the message to be broadcasted. %s is replaced by the target's name."],
						type = "input",
						order = 6,
						width = "full",
					},
					reset = resetButton("announce"),
				},
			},
		},
	}

	-- Three groups instead of one long list: The bar / Alerts / Advanced.
	local A = aceoptions.args
	-- the Hawks page: shape, layout, position, size and the seconds are the basics
	do
		local args = A.hawk.args
		args.hawksize.order, args.hawknumbers.order = 5, 6
		args.hawksoundat = {
			name = L["Sound at seconds left"],
			desc = L["Plays a warning sound once when a hawk has this many seconds left, in time to summon again. 0 = never."],
			type = "range",
			order = 6.5,
			min = 0, max = 17, step = 1,
			disabled = function() return not YaHT.db.profile.hawk end,
		}
		args.hawkcardicon = {name = L["Icon"], type = "header", order = 1.5}
		args.hawkcardtime = {name = L["Time"], type = "header", order = 5.5}
		args.hawkcardmore = {name = L["Fine tuning"], type = "header", order = 8.9}
		args.lookheader.hidden = true -- (the Fine tuning card holds what stood under "Look")
		Tuck(args, "hawk", {"hawkpolish", "hawkalpha", "hawknumpos", "hawkempty", "hawkwarn", "hawkglowcolor",
			"hawksharednote", "hawkown", "hawkiconsize", "hawkiconalpha", "hawkiconglow", "hawkiconpulse", "hawkiconsound",
			"hawkiconpolish"}, 9)
	end
	-- THE RANGE PAGE. Each warning is one dropdown (off / pictures / text / both), its color, its text and a
	-- Test button; nothing on the page depends on a switch somewhere else.
	do
		local args = A.range.args
		local function off() return not YaHT.db.profile.meleerange end
		-- what a warning shows, read from the settings ("dead" or "far")
		local function Shows(which)
			local p = YaHT.db.profile
			local on = p["range" .. which] ~= false
			local pics = on and p.rangepics ~= false and p["range" .. which .. "pics"] ~= false
			local text = on and p.rangetext and p["rangetext" .. which] and true or false
			return pics, text
		end
		YaHT.RangeShows = Shows
		local function anyText() local _, d = Shows("dead") local _, f = Shows("far") return d or f end
		local function anyPics() local d = Shows("dead") local f = Shows("far") return d or f end
		local function Choose(which, value)
			local p = YaHT.db.profile
			-- (the two all-in-one switches of before, written out per warning first)
			local dp, dt = Shows("dead")
			local fp, ft = Shows("far")
			p.rangepics = true
			p.rangedeadpics, p.rangefarpics, p.rangetextdead, p.rangetextfar = dp, fp, dt, ft
			if value == "OFF" then
				p["range" .. which] = false
			else
				p["range" .. which] = true
				p["range" .. which .. "pics"] = value ~= "TEXT"
				p["rangetext" .. which] = value ~= "PICS"
			end
			p.rangetext = (p.rangetextdead or p.rangetextfar) and true or false
			YaHT:ApplySettings()
			AceConfigRegistry:NotifyChange(Addon)
		end
		local function showAs(which, order, picsName, bothName, desc)
			return {
				name = L["Show as"], desc = desc, type = "select", order = order,
				values = {OFF = L["Off"], PICS = picsName, TEXT = L["Text"], BOTH = bothName},
				sorting = {"OFF", "PICS", "TEXT", "BOTH"},
				get = function()
					local pics, text = Shows(which)
					return (pics and text and "BOTH") or (pics and "PICS") or (text and "TEXT") or "OFF"
				end,
				set = function(info, value) Choose(which, value) end,
				disabled = off,
			}
		end
		-- one color per warning: it colors the stripes or arrows and the text alike
		local function oneColor(which, picKey, textKey, order)
			return {
				name = L["Color"], type = "color", order = order,
				get = function()
					local p = YaHT.db.profile
					local pics = Shows(which)
					local c = pics and p[picKey] or p[textKey]
					return c.r, c.g, c.b, 1
				end,
				set = function(info, r, g, b)
					local p = YaHT.db.profile
					p[picKey].r, p[picKey].g, p[picKey].b = r, g, b
					p[textKey].r, p[textKey].g, p[textKey].b = r, g, b
					YaHT:ApplySettings()
				end,
				disabled = function() local pics, text = Shows(which) return off() or not (pics or text) end,
			}
		end
		local function test(which, order)
			return {
				name = L["Test"], desc = L["Shows this warning for a few seconds, so you see your settings."],
				type = "execute", order = order,
				func = function() YaHT:PreviewRange(4, which == "dead" and "DEAD" or "FAR") end,
				disabled = function() local pics, text = Shows(which) return off() or not (pics or text) or not YaHT.db.profile.lock end,
			}
		end
		local function noTextFor(which) return function() local _, text = Shows(which) return not text end end
		local function noPicsFor(which) return function() local pics = Shows(which) return not pics end end
		for _, key in ipairs({"rangepics", "rangetext", "rangetextdead", "rangetextfar", "deadheader", "farheader", "lookheader",
			"textheader", "meleedeadcolor", "meleefarcolor", "rangetextdeadcolor", "rangetextfarcolor", "rangedesc"}) do
			args[key].hidden = true -- (the dropdowns and the two cards stand in for these)
		end
		-- the top card: on or off, when, and the text's size
		args.rangecardwarn = {name = L["Range warnings"], type = "header", order = 1.5}
		args.rangetextsize.name, args.rangetextsize.order = L["Text size"], 3.5
		args.rangetextsize.hidden = function() return not anyText() end
		args.rangetextsize.disabled = off
		args.rangetextpos = {
			name = L["Text position"],
			desc = L["Under the bar: just below the stripes or arrows. Over the bar: just above it. Anywhere: unlock the bar and drag the text where you want it."],
			type = "select", order = 3.55,
			values = {UNDER = L["Under the bar"], ABOVE = L["Over the bar"], FREE = L["Anywhere (drag it)"]},
			sorting = {"UNDER", "ABOVE", "FREE"},
			hidden = function() return not anyText() end,
			disabled = off,
		}
		args.rangetextnote = {name = L["To move the text, unlock the bar and drag it."], type = "description", order = 3.6,
			hidden = function() return not anyText() or YaHT.db.profile.rangetextpos ~= "FREE" end}
		-- Deadzone
		args.rangecarddead = {name = L["Deadzone"], type = "header", order = 5}
		args.rangedeadshow = showAs("dead", 5.1, L["Stripes"], L["Stripes and text"],
			L["How this warning shows: moving stripes on the bar, words you can drag anywhere, both, or not at all."])
		args.rangedeadcolor = oneColor("dead", "meleedeadcolor", "rangetextdeadcolor", 5.2)
		args.rangetextdeadmsg.name, args.rangetextdeadmsg.order = L["Text"], 5.3
		args.rangetextdeadmsg.hidden, args.rangetextdeadmsg.disabled = noTextFor("dead"), off
		args.meleedeadstyle.name, args.meleedeadstyle.order = L["Stripes on"], 5.4
		args.meleedeadstyle.hidden, args.meleedeadstyle.disabled = noPicsFor("dead"), off
		args.rangedeadtest = test("dead", 5.5)
		-- Too far
		args.rangecardfar = {name = L["Too far"], type = "header", order = 6}
		args.rangefarshow = showAs("far", 6.1, L["Arrows"], L["Arrows and text"],
			L["How this warning shows: red arrows on the bar, words you can drag anywhere, both, or not at all."])
		args.rangefarcolor = oneColor("far", "meleefarcolor", "rangetextfarcolor", 6.2)
		args.rangetextfarmsg.name, args.rangetextfarmsg.order = L["Text"], 6.3
		args.rangetextfarmsg.hidden, args.rangetextfarmsg.disabled = noTextFor("far"), off
		args.rangefartest = test("far", 6.5)
		-- Distance: how far the target is, as a band of yards
		local function yardsOff() return not YaHT.db.profile.rangeyards end
		args.rangecardyards = {name = L["Distance"], type = "header", order = 7}
		args.rangeyards = {
			name = L["Show the distance to your target"],
			desc = L["How far your target is, as a range of yards (for example 20-28 yd). The game does not give addons the exact distance, only whether something is in reach, so this is the narrowest band those answers allow. Green when you can shoot, the deadzone and too-far colors otherwise."],
			type = "toggle", width = "double", order = 7.1,
		}
		args.rangeyardsstyle = {
			name = L["Show as"],
			desc = L["Number: the yards in one color. Ruler: a strip of the zones (melee, deadzone, shooting, too far) with a bright block where your target is."]
				.. " " .. L["Boxes: one box per range band with its yards, and the one your target is in lights up."],
			type = "select", order = 7.2,
			values = {NUMBER = L["Number"], RULER = L["Ruler"], BOTH = L["Number and ruler"], BOXES = L["Boxes"]},
			sorting = {"NUMBER", "RULER", "BOTH", "BOXES"},
			disabled = yardsOff,
		}
		args.rangeyardswhen = {
			name = L["When"], type = "select", order = 7.3,
			values = {TARGET = L["Whenever an enemy is targeted"], COMBAT = L["Only in a fight"]},
			sorting = {"TARGET", "COMBAT"},
			disabled = yardsOff,
		}
		args.rangeyardspos = {
			name = L["Position"], type = "select", order = 7.4,
			values = {UNDER = L["Under the bar"], ABOVE = L["Over the bar"], FREE = L["Anywhere (drag it)"]},
			sorting = {"UNDER", "ABOVE", "FREE"},
			disabled = yardsOff,
		}
		args.rangeyardssize = {name = L["Size"], type = "range", order = 7.5, min = 8, max = 32, step = 1, disabled = yardsOff}
		-- the rest: More options (all of it is about the stripes and arrows)
		for key, order in pairs({meleedeadheight = 11, meleedeadalpha = 11.1, meleewarnglow = 11.6, meleewarnglowsize = 11.7, meleewarnglowalpha = 11.8}) do
			args[key].order, args[key].hidden = order, noPicsFor("dead")
		end
		for key, order in pairs({meleefarsize = 11.2, meleefaralpha = 11.3}) do
			args[key].order, args[key].hidden = order, noPicsFor("far")
		end
		for key, order in pairs({meleewarnspeed = 11.4, meleewarnboost = 11.5}) do
			args[key].order, args[key].hidden = order, function() return not anyPics() end
		end
		args.meleedeadalpha.name, args.meleefaralpha.name = L["Deadzone opacity"], L["Too far opacity"]
		args.rangecardmore = {name = L["Fine tuning"], type = "header", order = 8.9, hidden = function() return not anyPics() end}
		Tuck(args, "range", {"meleedeadheight", "meleedeadalpha", "meleefarsize", "meleefaralpha", "meleewarnspeed", "meleewarnboost",
			"meleewarnglow", "meleewarnglowsize", "meleewarnglowalpha"}, 9)
		args.rangemore.hidden = function() return not anyPics() end
	end
	-- glow and spark on one page
	local effects = A.glow
	effects.name = L["Glow and spark"]
	effects.args.sparkheader = {name = L["Spark"], type = "header", order = 50}
	for k, v in pairs(A.spark.args) do
		if k ~= "reset" then
			v.order = 50 + (v.order or 0)
			effects.args[k] = v
		end
	end
	effects.args.reset = resetButton("effects")
	A.bar.name = L["Look"]

	local bar = A.general
	bar.name = L["The bar"]
	bar.order = 1
	bar.args.lookpage = A.bar
	bar.args.textpage = A.text
	bar.args.effectspage = effects
	A.bar.order, A.text.order, effects.order = 1, 2, 3
	-- Lone Wolf has a page of its own under the bar
	local wolf = {name = L["Lone Wolf"], type = "group", order = 4, args = {}}
	for _, key in ipairs({"lonewolf", "lonewolfstyle", "lonewolfcolor", "lonewolfglowcolor", "lonewolfheight", "lonewolfpet"}) do
		wolf.args[key], A.bar.args[key] = A.bar.args[key], nil
	end
	A.bar.args.lonewolfheader = nil
	wolf.args.lonewolfintro = {
		name = L["A look of its own for hunters who play without a pet. It shows while no pet is out; with a pet out, the bar and your pet warnings are regular."],
		type = "description",
		order = 0,
	}
	wolf.args.lonewolf.width = "double"
	wolf.args.reset = resetButton("lonewolf")
	bar.args.lonewolfpage = wolf

	local alerts = {
		name = L["Alerts"],
		type = "group",
		order = 2,
		args = {
			about = {
				name = L["Everything that warns or informs you while you fight. Each one has its own page below."],
				type = "description",
				order = 1,
			},
			preview = {
				name = L["Preview all alerts"],
				desc = L["Shows every alert for a few seconds so you can see how they look."],
				type = "execute",
				order = 2,
				func = function() YaHT:PreviewAlerts() end,
			},
			-- one switch for every icon's shape (each also has its own Shape setting, on its page)
			roundall = {
				name = L["Round icons"],
				desc = L["One switch for the shape of every icon at once: the proc icons, the aspect badge and the hawks. On: round icons inside a ring. Off: square icons. Each icon also has its own Shape setting on its page."],
				type = "toggle",
				width = "double",
				order = 2.9,
				get = function()
					local p = YaHT.db.profile
					for _, key in ipairs(YaHT.shapeKeys) do
						if p[key] ~= "CIRCLE" then return false end
					end
					return true
				end,
				set = function(info, value)
					local p = YaHT.db.profile
					for _, key in ipairs(YaHT.shapeKeys) do p[key] = value and "CIRCLE" or "SQUARE" end
					YaHT:ApplySettings()
				end,
			},
			-- one switch for every icon's polished look (each also has its own, on its page)
			polishall = {
				name = L["Polished look on every icon"],
				desc = L["One switch for the polished look of every icon at once: the proc icons (their shared look and each one's own look), the aspect badge and the hawks. On: bevelled frames and rings with fine edges, a soft light on the icon and a shadow under it. Off: the standard flat look. Each icon also has its own switch on its page."],
				type = "toggle",
				width = "double",
				order = 3,
				get = function()
					local p = YaHT.db.profile
					for _, key in ipairs(YaHT.polishKeys) do
						if not p[key] then return false end
					end
					return true
				end,
				set = function(info, value)
					local p = YaHT.db.profile
					for _, key in ipairs(YaHT.polishKeys) do p[key] = value and true or false end
					YaHT:ApplySettings()
				end,
			},
			onheader = {name = L["Turn alerts on or off"], type = "header", order = 10},
			aspect = {name = L["Aspect badge"], type = "toggle", order = 11},
			feign = {name = L["Feign Death resist"], type = "toggle", order = 12},
			pet = {name = L["Pet alerts"], type = "toggle", order = 12.5},
			hawk = {name = L["Hawk circles"], type = "toggle", order = 12.7},
			meleerange = {name = L["Range warnings"], type = "toggle", order = 13},
			melee = {name = L["Melee swing line"], type = "toggle", order = 14},
			ammo = {name = L["Ammo counter"], type = "toggle", order = 15},
			multicast = {name = L["Multi-Shot cast"], type = "toggle", order = 15.5},
			tracker = {name = L["Tracking wheel"], type = "toggle", order = 15.7},
			procsnote = {name = L["The proc icons are switched on and off on the Procs page."], type = "description", order = 16},
			procspage = A.procs,
			aspectpage = A.aspect,
			feignpage = A.feign,
			petpage = A.pet,
			hawkpage = A.hawk,
			rangepage = A.range,
			meleepage = A.melee,
			ammopage = A.ammo,
			multicastpage = multicastPage,
			announcepage = A.announce, -- (a feature like the others, not an advanced setting)
			trackerpage = {
				name = L["Tracking wheel"],
				type = "group",
				order = 10,
				args = {
					trackerdesc = {
						name = L["A small button that shows what you are tracking. Click it and everything you can track opens around it as a pie, one piece each: move the mouse into the piece you want and on out of the pie, and you track it. Unlock the bar to drag the button anywhere on your screen."],
						type = "description",
						order = 1,
					},
					cardtitle = {name = L["Wheel"], type = "header", order = 1.5},
					tracker = {
						name = L["Show the tracking wheel"],
						desc = L["The button and its wheel. Off: YaHT leaves tracking alone."],
						type = "toggle",
						width = "double",
						order = 1.6,
					},
					trackerpick = {
						name = L["Choose by"],
						desc = L["Moving out past it: move into the piece you want and on out of the pie, and it is picked. Clicking: nothing changes until you click one; leaving the pie just closes the wheel. Either way, a click on the one you track switches tracking off, and a click in the middle closes the wheel."],
						type = "select",
						order = 2,
						values = {MOVE = L["Moving out of the pie past it"], CLICK = L["Clicking it"]},
						sorting = {"MOVE", "CLICK"},
						disabled = function() return not YaHT.db.profile.tracker end,
					},
					trackersize = {
						name = L["Size"], type = "range", order = 3, min = 20, max = 64, step = 1,
						disabled = function() return not YaHT.db.profile.tracker end,
					},
					trackerlayer = {
						name = L["Layer"],
						desc = L["Where the button sits among the game's windows while its wheel is closed. Behind windows: your bags, the map and other windows cover it. Above the minimap: for a button placed on a minimap. In front: nothing covers it. While the wheel is open it is always in front."],
						type = "select",
						order = 3.3,
						values = {BACK = L["Behind windows"], MIDDLE = L["Above the minimap"], FRONT = L["In front of everything"]},
						sorting = {"BACK", "MIDDLE", "FRONT"},
						disabled = function() return not YaHT.db.profile.tracker end,
					},
					trackerpolish = {
						name = L["Polished look"],
						desc = L["A bevelled ring with fine edges and a shadow, like the polished hawk circles. Off: the standard flat look."],
						type = "toggle",
						order = 3.6,
						disabled = function() return not YaHT.db.profile.tracker end,
					},
					trackerall = {
						name = L["Also the minimap's other filters"],
						desc = L["Off: only what you track with a spell (Track Beasts, Find Minerals...). On: also the minimap's own filters, where the game has them."],
						type = "toggle",
						width = "double",
						order = 4,
						disabled = function() return not YaHT.db.profile.tracker end,
					},
					reset = resetButton("tracker"),
				},
			},
		},
	}
	-- The list on the left, in three groups (menu.lua puts a small heading above the first page of
	-- each): what warns you, what times things for you, and tools.
	A.range.order, A.feign.order, A.pet.order, A.aspect.order, A.ammo.order = 1, 2, 3, 4, 5
	A.procs.order, A.hawk.order, multicastPage.order, A.melee.order = 6, 7, 8, 9
	A.announce.order = 11 -- (the tracking wheel is 10)
	A.melee.name = L["Melee line"]

	-- POLISH PASS. Nothing twice, every card has a title, the same word for the same thing.
	do
		-- on its own page a setting that Home (or the window's header) already has is left out;
		-- a search still finds it
		local function onlyElsewhere(pageId)
			return function()
				local m = YaHT.menu
				return (m and m.current == pageId and not m.query) and true or false
			end
		end
		local g = bar.args
		for _, key in ipairs({"lock", "minimap", "presetheader", "presetdesc", "presetminimal", "presetclean", "presetflashy"}) do
			if g[key] then g[key].hidden = onlyElsewhere("bar") end
		end
		for _, key in ipairs({"roundall", "polishall", "preview"}) do
			if alerts.args[key] then alerts.args[key].hidden = onlyElsewhere("alerts") end
		end
		-- a title on every first card
		local function title(args, name, order) args.cardtitle = {name = name, type = "header", order = order} end
		title(A.bar.args, L["Bar"], 0.5)
		title(A.text.args, L["Countdown"], 0.5)
		title(effects.args, L["Glow"], 0.5)
		title(A.aspect.args, L["Icon"], 1.5)
		title(A.feign.args, L["Alert"], 1.5)
		title(A.pet.args, L["Pet alerts"], 1.5)
		title(A.melee.args, L["Line"], 1.5)
		title(A.ammo.args, L["Icon"], 1.5)
		title(A.timing.args, L["Timing"], 1.5)
		title(A.announce.args, tranq, 1.5)
		-- one name for the fine settings, one name for trying something out
		A.text.args.offsetheader.name = L["Fine tuning"]
		effects.args.tuneheader.name = L["Fine tuning"]
		A.feign.args.feigntest.name, A.feign.args.feigntest.order = L["Test"], 7.5 -- (at the end of its card)
		multicastPage.args.multicastsample.name = L["Test"]
		A.ammo.args.ammoresetpos.order = 3.5 -- (with the icon it moves, not under the warning levels)
		-- the aspect icon: its two fine settings out of the way
		A.aspect.args.aspectcardmore = {name = L["Fine tuning"], type = "header", order = 20}
		A.aspect.args.aspectalpha.order, A.aspect.args.aspectpolish.order = 21, 22
		Tuck(A.aspect.args, "aspect", {"aspectalpha", "aspectpolish"}, 20.5)
	end

	local advanced = {
		name = L["Advanced"],
		type = "group",
		order = 3,
		args = {
			about = {
				name = L["Rarely needed: the defaults match WoW Forever."],
				type = "description",
				order = 1,
			},
			debugheader = {name = L["Debug log"], type = "header", order = 10},
			debugdesc = {
				name = L["For bug reports: writes down every shot and alert while it is on. /yaht copy opens the log so you can copy it."],
				type = "description",
				order = 11,
			},
			debug = {
				name = L["Write the debug log"],
				type = "toggle",
				order = 12,
				get = function() return YaHT.debug and true or false end,
				set = function(_, value)
					YaHT.debug = value and true or false
					YaHT.db.global.debug = YaHT.debug -- stays on (or off) after you log out
				end,
			},
			debugwindow = {
				name = L["Show its lines in"],
				desc = L["Where the debug lines appear while the log is on. The log itself keeps every line either way. To give them their own tab, make a new chat window in the game first, then pick it here."],
				type = "select",
				order = 13,
				values = function()
					local v = {[0] = L["The main chat window"], [-1] = L["Nowhere (only the log)"]}
					for i = 2, (NUM_CHAT_WINDOWS or 10) do
						local name = GetChatWindowInfo and GetChatWindowInfo(i)
						if type(name) == "string" and name ~= "" then v[i] = string.format(L["Chat tab: %s"], name) end
					end
					return v
				end,
				sorting = function()
					local list = {0}
					for i = 2, (NUM_CHAT_WINDOWS or 10) do
						local name = GetChatWindowInfo and GetChatWindowInfo(i)
						if type(name) == "string" and name ~= "" then list[#list + 1] = i end
					end
					list[#list + 1] = -1
					return list
				end,
				get = function() return YaHT.db.global.debugwindow or 0 end,
				set = function(_, value) YaHT.db.global.debugwindow = value end,
			},
			timingpage = A.timing,
		},
	}
	A.timing.order = 1

	aceoptions.args = {bar = bar, alerts = alerts, advanced = advanced}

	aceoptions.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	aceoptions.args.profile.order = 100
	-- the Profiles page: the same controls, without the paragraphs between them (each control still
	-- explains itself when you point at it), in two titled cards, Reset last
	do
		local pa = aceoptions.args.profile.args
		if type(pa) == "table" then
			for _, key in ipairs({"descreset", "choosedesc", "copydesc", "deldesc"}) do
				if pa[key] then pa[key].hidden = true end
			end
			pa.cardprofile = {name = L["Profile"], type = "header", order = 10.5}
			if pa.current then pa.current.order = 11 end
			if pa.choose then pa.choose.order = 12 end
			if pa.new then pa.new.order = 13 end
			pa.cardcopy = {name = L["Copy or delete"], type = "header", order = 50}
			if pa.reset then pa.reset.order = 95 end
			-- everything you changed, in one list (YaHT's own window has a page for it)
			pa.changesheader = {name = L["What you changed"], type = "header", order = 190}
			pa.showchanges = {
				name = function()
					local m = YaHT.menu
					local n = m and m.ChangedCount and m.ChangedCount() or 0
					return n > 0 and string.format(L["Show my changes (%d)"], n) or L["Show my changes"]
				end,
				desc = L["Every setting you changed from how YaHT comes, in one list. Right-click one to put it back. A gold dot marks the same settings on their own pages."],
				type = "execute",
				order = 191,
				func = function() if YaHT.menu and YaHT.menu.Show then YaHT.menu.Show("changed") end end,
			}
			-- sharing a setup belongs with the profiles: both are about your settings as a whole
			pa.shareheader = {name = L["Share your setup"], type = "header", order = 200}
			pa.sharedesc = {
				name = L["Your setup as one line of text: everything you changed from the defaults, without the places things sit on your screen. Click into the box, press Ctrl+A and Ctrl+C to copy it. To take someone else's, paste theirs into the second box and press Enter."],
				type = "description",
				order = 201,
			}
			pa.exportsetup = {
				name = L["Your setup"],
				desc = L["Copy this and send it to someone. It changes nothing here."],
				type = "input",
				order = 202,
				get = function() return YaHT:ExportSetup() end,
				set = function() end,
			}
			pa.importsetup = {
				name = L["Paste a setup"],
				desc = L["Paste a setup someone sent you and press Enter. This profile's settings are replaced by it; the places things sit on your screen stay. You can undo it afterwards."],
				type = "input",
				order = 203,
				get = function() return "" end,
				set = function(_, text)
					if type(text) ~= "string" or text:gsub("%s", "") == "" then return end
					local ok, result = YaHT:ImportSetup(text)
					if ok then
						YaHT:Print(string.format(L["Setup taken over (%d settings). \"Undo the import\" on the Profiles page puts yours back."], result))
					else
						YaHT:Print(result)
					end
				end,
			}
			pa.importundo = {
				name = L["Undo the import"],
				desc = L["Puts back the settings you had before you pasted a setup."],
				type = "execute",
				order = 204,
				hidden = function() return not YaHT.importBackup end,
				func = function() YaHT:UndoImport() end,
			}
		end
	end
	-- SOUNDS. Every sound is a choice: its switch becomes one list, "No sound" first, then the
	-- sounds to pick from (picking one plays it; YaHT's own window has a "Hear it" button too).
	-- The switch's setting stays as it is (on or off); the sound picked is kept beside it.
	do
		local function choices(none)
			return function()
				local v = {}
				if none then v.NONE = L["No sound"] end
				for _, id in ipairs(YaHT.SOUND_ORDER) do
					if YaHT.SoundExists(id) then v[id] = L[YaHT.SOUND_NAME[id]] end
				end
				return v
			end
		end
		local function order(none)
			return function()
				local list = {}
				if none then list[1] = "NONE" end
				for _, id in ipairs(YaHT.SOUND_ORDER) do
					if YaHT.SoundExists(id) then list[#list + 1] = id end
				end
				return list
			end
		end
		-- the sound each one made before there was a choice
		local USUAL = {procsound = "PING", hawkiconsound = "PING", ammosound = "ALARM", feignsound = "WARNING",
			petsound = "WARNING", aspectsound = "WARNING"}
		local function usual(key)
			return USUAL[key] or (key:find("iconsound$") and "PING") or nil
		end
		local added = {}
		local function walk(args)
			local more = {}
			for key, opt in pairs(args) do
				if opt.type == "group" then
					walk(opt.args)
				elseif opt.type == "toggle" and usual(key) then
					-- a switch for a sound: now the list of sounds
					local kit, was = key .. "kit", usual(key)
					opt.type, opt.arg, opt.width = "select", "sound", nil
					opt.values, opt.sorting = choices(true), order(true)
					opt.get = function()
						local p = YaHT.db.profile
						return p[key] and (p[kit] or was) or "NONE"
					end
					opt.set = function(_, v)
						local p = YaHT.db.profile
						if v == "NONE" then
							p[key] = false
						else
							p[key], p[kit] = true, v
							YaHT:PlayChoice(v, was)
						end
						YaHT:ApplySettings()
					end
					added[key] = kit
				elseif opt.type == "range" and key:find("soundat$") then
					-- "sound at seconds left": which sound, right under how many seconds
					local kit = key .. "kit"
					more[kit] = {
						name = L["Sound for seconds left"],
						desc = L["The sound that plays when that much time is left."],
						type = "select", arg = "sound",
						order = (opt.order or 0) + 0.01,
						values = choices(false), sorting = order(false),
						hidden = opt.hidden,
						disabled = function() return (YaHT.db.profile[key] or 0) <= 0 end,
						get = function() return YaHT.db.profile[kit] or "ALARM" end,
						set = function(_, v)
							YaHT.db.profile[kit] = v
							YaHT:PlayChoice(v, "ALARM")
						end,
					}
					added[key] = kit
				end
			end
			for kit, opt in pairs(more) do args[kit] = opt end
			-- the ammo counter has two sounds: running low, and nearly out
			if args.ammosound and not args.ammocritkit then
				args.ammosound.name = L["Sound when ammo runs low"]
				args.ammocritkit = {
					name = L["Sound when ammo is nearly out"],
					type = "select", arg = "sound",
					order = (args.ammosound.order or 0) + 0.01,
					values = choices(false), sorting = order(false),
					disabled = function() return not YaHT.db.profile.ammosound end,
					get = function() return YaHT.db.profile.ammocritkit or "WARNING" end,
					set = function(_, v)
						YaHT.db.profile.ammocritkit = v
						YaHT:PlayChoice(v, "WARNING")
					end,
				}
				added.ammocrit = "ammocritkit"
			end
		end
		walk(aceoptions.args)
		-- "Reset this page" puts the chosen sounds back too
		for _, keys in pairs(TAB_KEYS) do
			local extra = {}
			for _, key in ipairs(keys) do
				if added[key] then extra[#extra + 1] = added[key] end
				if key == "ammosound" then extra[#extra + 1] = "ammocritkit" end
			end
			for _, kit in ipairs(extra) do keys[#keys + 1] = kit end
		end
		YaHT.soundKeys = added -- (for tests: every sound setting and where its choice is kept)
	end
	AceConfigRegistry:RegisterOptionsTable(Addon, aceoptions, true)
	self.optionsTable = aceoptions -- YaHT's own window (menu.lua) is drawn from this same table

	-- also listed in the game's Settings > AddOns panel
	AceConfigDialog:AddToBlizOptions(Addon, "YaHT")
	AceConfigDialog:SetDefaultSize(Addon, 860, 560)
	-- open the groups (and Procs) in the list by default, so every page is one click away
	local status = AceConfigDialog.GetStatusTable and AceConfigDialog:GetStatusTable(Addon)
	if status then
		status.groups = status.groups or {}
		status.groups.groups = status.groups.groups or {}
		for _, node in ipairs({"bar", "alerts", "alerts\001procspage", "advanced"}) do
			if status.groups.groups[node] == nil then status.groups.groups[node] = true end
		end
	end
end
