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

local function ApplyPreset(name)
	local profile = YaHT.db.profile
	for k, v in pairs(PRESETS[name]) do profile[k] = v end
	-- Flashy uses the WeakAuras-style pixel effect when it's available
	if name == "FLASHY" and YaHT:GetLCG() then profile.glowstyle = "PIXEL" end
	YaHT:ApplySettings()
	AceConfigRegistry:NotifyChange(Addon)
end

local TAB_KEYS = {
	general = {"lock", "width", "height", "scale", "alpha", "malpha"},
	bar = {"statusbar", "timercolor", "drawcolor", "fill", "enablebackground", "background",
		"backgroundcolor", "enableborder", "border", "bordercolor"},
	text = {"showtext", "textmode", "textpos", "textsize", "textx", "texty", "font", "textcolor"},
	glow = {"glow", "glowmode", "glowlook", "glowstyle", "glowkeepbuiltin", "glowpulse", "glowramp",
		"glowintensity", "glowsize", "glowcolor"},
	spark = {"sparkmode", "readypulse", "sparksize", "sparkcolor"},
	timing = {"windupauto", "windup", "castholds", "autocorrect"},
	ammo = {"ammo", "ammosize", "ammofadestart", "ammolow", "ammocrit", "ammofullalpha", "ammoflash", "ammosound"},
	announce = {"tranqannounce", "tranqannouncefail", "announcetype", "targetchannel",
		"announcemsg", "announcefailmsg"},
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
			name = L["Reset this tab"],
			desc = L["Put every setting on this tab back to its default."],
			type = "execute",
			order = order or 100,
			confirm = true,
			confirmText = L["Reset this tab to defaults?"],
			func = function() ResetKeys(TAB_KEYS[tab]) end,
		}
	end

	local function textOff() return not YaHT.db.profile.showtext end
	local function glowOff() return not YaHT.db.profile.glow end
	local function sparkOff() local p = YaHT.db.profile return p.sparkmode == "OFF" and not p.readypulse end
	local tranq = YaHT.GetSpellName(19801) or "Tranquilizing Shot"

	local aceoptions = {
		name = "YaHT - Yet another Hunter Timer",
		type = "group",
		childGroups = "tab",
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
							.."  ·  "..L["Original addon by Aviana"].."|r",
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
					resetpos = {
						name = L["Reset position"],
						desc = L["Move the bar back to the middle of the screen."],
						type = "execute",
						order = 3,
						func = function()
							local p = YaHT.db.profile
							p.point, p.relativePoint, p.x, p.y = nil, nil, nil, nil
							YaHT:ApplySettings()
						end,
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
						name = L["Size & visibility"],
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
						type = "range",
						order = 23,
						isPercent = true,
						min = 0.1,
						max = 3,
						step = 0.05,
					},
					alpha = {
						name = L["Alpha"],
						type = "range",
						order = 24,
						isPercent = true,
						min = 0.1,
						max = 1,
						step = 0.05,
					},
					malpha = {
						name = L["Movement alpha"],
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
						type = "color",
						order = 3,
						get = getColor,
						set = setColor,
					},
					drawcolor = {
						name = L["Stand-still color"],
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
						name = L["Background Color"],
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
						name = L["Border Color"],
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
						name = L["Text Color"],
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
					glow = {
						name = L["Glow"],
						desc = L["Glow around the bar: none when the bar is full, building up as the reload runs out, full when you need to stand still."],
						type = "toggle",
						order = 1,
					},
					glowmode = {
						name = L["When"],
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
						name = L["Stand-still effect"],
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
						name = L["Pulse when standing"],
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
						name = L["Glow Color"],
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
						name = L["Spark"],
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
						name = L["Spark Color"],
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
						name = L["Visibility when plenty"],
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
					tranqannouncefail = {
						name = string.format(L["Announce failed %s"], tranq),
						desc = L["Only works where the game lets addons read the combat log (not on WoW Forever)."],
						type = "toggle",
						order = 3,
						width = "double",
						disabled = function() return not YaHT.hasCombatLog end,
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
						name = L["Channel/Playername"],
						desc = L["Set the channel or player for whisper."],
						type = "input",
						order = 5,
						hidden = function() local t = YaHT.db.profile.announcetype return not (t == "WHISPER" or t == "CHANNEL") end,
					},
					announcemsg = {
						name = L["Announce Message"],
						desc = L["Set the message to be broadcasted. %s is replaced by the target's name."],
						type = "input",
						order = 6,
						width = "full",
					},
					announcefailmsg = {
						name = L["Announce Fail Message"],
						desc = L["Set the message to be broadcasted. %s is replaced by the target's name."],
						type = "input",
						order = 7,
						width = "full",
						disabled = function() return not YaHT.hasCombatLog end,
					},
					reset = resetButton("announce"),
				},
			},
		},
	}

	aceoptions.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	aceoptions.args.profile.order = 100
	AceConfigRegistry:RegisterOptionsTable(Addon, aceoptions, true)

	-- also listed in the game's Settings > AddOns panel
	AceConfigDialog:AddToBlizOptions(Addon, "YaHT")
	AceConfigDialog:SetDefaultSize(Addon, 720, 560)
end
