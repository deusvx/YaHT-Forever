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

-- One-click looks. Only touch the "effects" settings, never size/position.
local PRESETS = {
	MINIMAL = {
		glow = false, sparkmode = "OFF", readypulse = true,
		showtext = true, textpos = "OUTSIDE_RIGHT", textx = 0, texty = 0,
	},
	CLEAN = {
		glow = true, glowlook = "OUTLINE", glowmode = "STAND", glowpulse = false,
		glowstyle = "BUILTIN", glowkeepbuiltin = false, glowintensity = 0.9,
		sparkmode = "STAND", readypulse = true, showtext = true,
	},
	FLASHY = {
		glow = true, glowlook = "SOFT", glowmode = "RAMP", glowpulse = true, glowramp = 0.7,
		glowstyle = "SWEEP", glowkeepbuiltin = true, glowintensity = 1, glowsize = 14,
		sparkmode = "STAND", readypulse = true, showtext = true,
	},
}

YaHT.presets = PRESETS

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
	bar = {"statusbar", "timercolor", "drawcolor", "fill", "enablebackground", "background",
		"backgroundcolor", "enableborder", "border", "bordercolor"},
	text = {"showtext", "textmode", "textpos", "textsize", "textx", "texty", "font", "textcolor"},
	glow = {"glow", "glowmode", "glowlook", "glowstyle", "glowkeepbuiltin", "glowpulse", "glowramp",
		"glowintensity", "glowsize", "glowcolor"},
	spark = {"sparkmode", "readypulse", "sparksize", "sparkcolor"},
	effects = {"glow", "glowmode", "glowlook", "glowstyle", "glowkeepbuiltin", "glowpulse", "glowramp",
		"glowintensity", "glowsize", "glowcolor", "sparkmode", "readypulse", "sparksize", "sparkcolor"},
	timing = {"windupauto", "windup", "castholds", "autocorrect", "smooth"},
	ammo = {"ammo", "ammosize", "ammofadestart", "ammolow", "ammocrit", "ammofullalpha", "ammoflash", "ammosound"},
	melee = {"melee", "meleemode", "meleeheight", "meleealpha", "meleeglint", "meleeraptor", "meleecolor", "meleeraptorcolor"},
	feign = {"feign", "feignscale", "feigntime", "feignsound", "feigntargetcheck", "feignthreatcheck", "feigncolor",
		"feignpoint", "feignrelpoint", "feignx", "feigny"},
	pet = {"pet", "petlow", "petlowat", "petwhen", "petdead", "petidle", "petsound", "petpulse", "pettextsize",
		"petpoint", "petrelpoint", "petx", "pety"},
	aspect = {"aspect", "aspectwhen", "aspectpos", "aspectsize", "aspectalpha", "aspectwarnspeed", "aspectspeedalways",
		"aspectwarnnone", "aspecthint", "aspectsound", "aspectpoint", "aspectrelpoint", "aspectx", "aspecty"},
	procs = {"procsize", "procalpha", "procglow", "procpulse", "procsound", "mongoosecooldown", "mongoose", "mongoosepos", "mongooseglowcolor", "mongoosepoint", "mongooserelpoint", "mongoosex", "mongoosey", "quickshots", "quickshotspos", "quickshotsglowcolor", "quickshotspoint", "quickshotsrelpoint", "quickshotsx", "quickshotsy", "rapidfire", "rapidfirepos", "rapidfireglowcolor", "rapidfirepoint", "rapidfirerelpoint", "rapidfirex", "rapidfirey", "racial", "racialpos", "racialglowcolor", "racialpoint", "racialrelpoint", "racialx", "racialy",
		"mongooseown", "mongooseownset", "mongooseiconsize", "mongooseiconalpha", "mongooseiconglow", "mongooseiconpulse", "mongooseiconsound", "quickshotsown", "quickshotsownset", "quickshotsiconsize", "quickshotsiconalpha", "quickshotsiconglow", "quickshotsiconpulse", "quickshotsiconsound", "rapidfireown", "rapidfireownset", "rapidfireiconsize", "rapidfireiconalpha", "rapidfireiconglow", "rapidfireiconpulse", "rapidfireiconsound", "racialown", "racialownset", "racialiconsize", "racialiconalpha", "racialiconglow", "racialiconpulse", "racialiconsound"},
	range = {"meleerange", "meleerangewhen", "meleedeadstyle", "meleedeadcolor", "meleedeadheight", "meleedeadalpha", "meleefarcolor", "meleefarsize", "meleefaralpha",
		"meleewarnspeed", "meleewarnboost", "meleewarnglow", "meleewarnglowsize", "meleewarnglowalpha"},
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
	local function glowWarnOff() local p = YaHT.db.profile return not p.meleerange or p.meleewarnglow == "NONE" end
	local mongoose = YaHT.GetSpellName(1495) or "Mongoose Bite"
	local quickshots = YaHT.GetSpellName(6150) or "Quick Shots"
	local function aspectOff() return not YaHT.db.profile.aspect end
	local function feignOff() return not YaHT.db.profile.feign end
	local function petOff() return not YaHT.db.profile.pet end
	local function petLowOff() local p = YaHT.db.profile return not p.pet or not p.petlow end

	local rapidfire = YaHT.GetSpellName(3045) or "Rapid Fire"
	local hasLCG = function() return LibStub and LibStub("LibCustomGlow-1.0", true) end
	local function procsOff() local p = YaHT.db.profile return not (p.mongoose or p.quickshots or p.rapidfire or p.racial) end
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
	local OWN_LOOK = {"size", "alpha", "glow", "pulse", "sound"}

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
			[key .. "iconsize"] = {name = L["Icon size"], type = "range", order = 11, min = 16, max = 64, step = 1, hidden = ownOff, disabled = off},
			[key .. "iconalpha"] = {name = L["Opacity"], type = "range", order = 12, min = 0.2, max = 1, step = 0.05, isPercent = true, hidden = ownOff, disabled = off},
			[key .. "iconglow"] = {name = L["Glow style"], type = "select", order = 13, values = glowValues, sorting = glowSorting, hidden = ownOff, disabled = off},
			[key .. "iconpulse"] = {name = L["Pulse style"], type = "select", order = 14, values = PULSE_VALUES, sorting = PULSE_SORTING, hidden = ownOff, disabled = off},
			[key .. "iconsound"] = {name = L["Play a sound when it pops up"], type = "toggle", width = "double", order = 15, hidden = ownOff, disabled = off},
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
		rapidfire = {name = rapidfire, type = "toggle", order = 13},
		racial = {name = L["Racial ability"], type = "toggle", order = 14},
		lookheader = {name = L["Look of all proc icons"], type = "header", order = 20},
		procsize = {name = L["Icon size"], type = "range", order = 21, min = 16, max = 64, step = 1, disabled = procsOff},
		procalpha = {name = L["Opacity"], type = "range", order = 22, min = 0.2, max = 1, step = 0.05, isPercent = true, disabled = procsOff},
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
		rapidfirepage = procPage("rapidfire", rapidfire,
			string.format(L["Shows while %s lasts (15 seconds), from the moment you cast it."], rapidfire), 3),
		racialpage = procPage("racial", L["Racial ability"],
			L["Your race's active (Night Elf Elune's Light, Orc Blood Fury, Troll Berserking, Dwarf Stoneform, Human Perception, Tauren Plainsrunning, Skyborne Skysight) shows while it lasts, from the moment you use it. YaHT recognises it by itself; for a new racial it learns the length the first time you use it out of combat."], 4),
	}

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
						name = L["One click sets the countdown, glow and spark. Size, position and colors are kept."],
						type = "description",
						order = 11,
					},
					presetminimal = {
						name = L["Minimal"],
						desc = L["Just the bar and the countdown, plus the ready pulse."],
						type = "execute",
						order = 12,
						func = function() ApplyPreset("MINIMAL") end,
					},
					presetclean = {
						name = L["Clean"],
						desc = L["Crisp outline glow while standing still, sparks from the middle."],
						type = "execute",
						order = 13,
						func = function() ApplyPreset("CLEAN") end,
					},
					presetflashy = {
						name = L["Flashy"],
						desc = L["Soft glow that builds up, pulse, sparks and a light sweep (or a WeakAuras pixel glow if available)."],
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
					},
					timercolor = {
						name = L["Reload color"],
						desc = L["Color of the bar while you reload."],
						type = "color",
						order = 3,
						get = getColor,
						set = setColor,
					},
					drawcolor = {
						name = L["Stand-still color"],
						desc = L["Color of the part where you must stand still for the shot."],
						type = "color",
						order = 4,
						get = getColor,
						set = setColor,
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
			onheader = {name = L["Turn alerts on or off"], type = "header", order = 10},
			aspect = {name = L["Aspect badge"], type = "toggle", order = 11},
			feign = {name = L["Feign Death resist"], type = "toggle", order = 12},
			pet = {name = L["Pet alerts"], type = "toggle", order = 12.5},
			meleerange = {name = L["Range warnings"], type = "toggle", order = 13},
			melee = {name = L["Melee swing line"], type = "toggle", order = 14},
			ammo = {name = L["Ammo counter"], type = "toggle", order = 15},
			procsnote = {name = L["The proc icons are switched on and off on the Procs page."], type = "description", order = 16},
			procspage = A.procs,
			aspectpage = A.aspect,
			feignpage = A.feign,
			petpage = A.pet,
			rangepage = A.range,
			meleepage = A.melee,
			ammopage = A.ammo,
		},
	}
	A.procs.order, A.aspect.order, A.feign.order, A.pet.order, A.range.order, A.melee.order, A.ammo.order = 1, 2, 3, 4, 5, 6, 7
	A.melee.name = L["Melee line"]

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
			announcepage = A.announce,
		},
	}
	A.timing.order, A.announce.order = 1, 2

	aceoptions.args = {bar = bar, alerts = alerts, advanced = advanced}

	aceoptions.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	aceoptions.args.profile.order = 100
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
