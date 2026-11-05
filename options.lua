if select(2,UnitClass("player")) ~= "HUNTER" then return end
local Addon = select(1, ...)

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")


local L = YaHT.L

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
		return db.r, db.g ,db.b, db.a
	end
	
	local function setColor(info, r, g, b, a)
		local db = YaHT.db.profile[info[#info]]
		db.r = r
		db.g = g
		db.b = b
		db.a = a
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

	local aceoptions = {
		name = "Yet another Hunter Timer",
		type = "group",
		get = get,
		set = set,
		icon = "",
		args = {
			general = {
				name = L["Overview"],
				type = "group",
				order = 1,
				args = {
					descriptiontext = {
						name = "Yet another Hunter Timer by Aviana\nDonate: paypal.me/LunaUnitFrames\n".."Version: "..YaHT.version.."\nWoW Forever port",
						type = "description",
						width = "full",
						order = 1,
					},
					optionsheader = {
						name = L["Options"],
						type = "header",
						order = 2,
					},
					lock = {
						name = L["Lock"],
						desc = L["Lock / Unlock the timer bar for drag."],
						type = "toggle",
						order = 3,
					},
					width = {
						name = L["Width"],
						desc = L["Set the width."],
						width = "full",
						type = "range",
						order = 4,
						min = 10,
						max = 600,
						step = 1,
					},
					height = {
						name = L["Height"],
						desc = L["Set the height."],
						width = "full",
						type = "range",
						order = 5,
						min = 5,
						max = 50,
						step = 1,
					},
					scale = {
						name = L["Scale"],
						desc = L["Set the scale."],
						type = "range",
						order = 6,
						isPercent = true,
						min = 0.1,
						max = 3,
						step = 0.1,
					},
					alpha = {
						name = L["Alpha"],
						desc = L["Set the alpha."],
						type = "range",
						order = 6.1,
						isPercent = true,
						min = 0.1,
						max = 1,
						step = 0.1,
					},
					malpha = {
						name = L["Movement alpha"],
						desc = L["Set the alpha while moving."],
						type = "range",
						order = 6.2,
						isPercent = true,
						min = 0.1,
						max = 1,
						step = 0.1,
					},
					timingheader = {
						name = L["Timing"],
						type = "header",
						order = 6.5,
					},
					windupauto = {
						name = L["Automatic wind-up"],
						desc = L["Wind-up = 0.5s scaled by your ranged haste (WoW Forever behaviour). Turn off to set it by hand."],
						type = "toggle",
						order = 6.55,
					},
					windup = {
						name = L["Wind-up time"],
						desc = L["How long you must stand still before each Auto Shot fires. WoW Forever base: 0.5. Original Classic addon: 0.65."],
						type = "range",
						order = 6.6,
						min = 0.2,
						max = 1.0,
						step = 0.05,
						disabled = function() return YaHT.db.profile.windupauto end,
					},
					castholds = {
						name = L["Casts hold Auto Shot"],
						desc = L["Pause the timer during Aimed Shot / Multi-Shot casts (old Classic behaviour). Leave off on WoW Forever, where Auto Shot keeps firing during casts."],
						type = "toggle",
						width = "double",
						order = 6.7,
					},
					barheader = {
						name = L["Bar options"],
						type = "header",
						order = 7,
					},
					statusbar = {
						order = 8,
						type = "select",
						name = L["Bar texture"],
						dialogControl = widget("LSM30_Statusbar"),
						values = getMediaData,
					},
					timercolor = {
						name = L["Timer Color"],
						type = "color",
						order = 9,
						get = getColor,
						set = setColor,
					},
					drawcolor = {
						name = L["Draw Color"],
						type = "color",
						order = 10,
						get = getColor,
						set = setColor,
					},
					fill = {
						name = L["Fill from middle"],
						desc = L["Extend the bar from the middle outwards."],
						type = "toggle",
						order = 11,
					},
					textheader = {
						name = L["Countdown text"],
						type = "header",
						order = 11.1,
					},
					showtext = {
						name = L["Show countdown"],
						desc = L["Show the time left as a number with one decimal, like WeaponSwingTimer."],
						type = "toggle",
						order = 11.2,
					},
					textmode = {
						name = L["Count down to"],
						desc = L["Shot: time until the Auto Shot fires. Stand still: time until you must stop moving."],
						type = "select",
						order = 11.3,
						values = {SHOT = L["Shot fires"], MOVE = L["Stand still"]},
						disabled = function() return not YaHT.db.profile.showtext end,
					},
					textpos = {
						name = L["Position"],
						desc = L["Snap the number to a spot on the bar. Unlock the bar to drag it freely."],
						type = "select",
						order = 11.4,
						values = {
							INSIDE_LEFT = L["Inside left"], INSIDE_CENTER = L["Inside center"], INSIDE_RIGHT = L["Inside right"],
							OUTSIDE_LEFT = L["Outside left"], OUTSIDE_RIGHT = L["Outside right"],
							ABOVE = L["Above"], BELOW = L["Below"],
						},
						sorting = {"OUTSIDE_LEFT", "INSIDE_LEFT", "INSIDE_CENTER", "INSIDE_RIGHT", "OUTSIDE_RIGHT", "ABOVE", "BELOW"},
						set = function(info, value)
							YaHT.db.profile.textpos = value
							YaHT.db.profile.textx = 0
							YaHT.db.profile.texty = 0
							YaHT:ApplySettings()
						end,
						disabled = function() return not YaHT.db.profile.showtext end,
					},
					textsize = {
						name = L["Font size"],
						type = "range",
						order = 11.5,
						min = 6,
						max = 32,
						step = 1,
						disabled = function() return not YaHT.db.profile.showtext end,
					},
					textx = {
						name = L["X offset"],
						desc = L["Fine-tune the position. You can also drag the number while the bar is unlocked."],
						type = "range",
						order = 11.6,
						min = -300,
						max = 300,
						step = 1,
						disabled = function() return not YaHT.db.profile.showtext end,
					},
					texty = {
						name = L["Y offset"],
						desc = L["Fine-tune the position. You can also drag the number while the bar is unlocked."],
						type = "range",
						order = 11.7,
						min = -100,
						max = 100,
						step = 1,
						disabled = function() return not YaHT.db.profile.showtext end,
					},
					font = {
						name = L["Font"],
						type = "select",
						order = 11.8,
						dialogControl = widget("LSM30_Font"),
						values = getMediaData,
						disabled = function() return not YaHT.db.profile.showtext end,
					},
					textcolor = {
						name = L["Text Color"],
						type = "color",
						hasAlpha = true,
						order = 11.9,
						get = getColor,
						set = setColor,
						disabled = function() return not YaHT.db.profile.showtext end,
					},
					glowheader = {
						name = L["Glow"],
						type = "header",
						order = 11.91,
					},
					glow = {
						name = L["Glow"],
						desc = L["Glow around the bar: none when the bar is full, building up as the reload runs out, full when you need to stand still."],
						type = "toggle",
						order = 11.92,
					},
					glowmode = {
						name = L["Glow style"],
						desc = L["Build up: glow grows during the reload. Stand still only: glow appears just for the stand-still part."],
						type = "select",
						order = 11.93,
						values = {RAMP = L["Build up"], STAND = L["Stand still only"]},
						disabled = function() return not YaHT.db.profile.glow end,
					},
					glowlook = {
						name = L["Glow look"],
						desc = L["Soft: blurry halo. Outline: crisp bright border."],
						type = "select",
						order = 11.932,
						values = {SOFT = L["Soft"], OUTLINE = L["Outline"]},
						disabled = function() return not YaHT.db.profile.glow end,
					},
					glowstyle = {
						name = L["Stand-still effect"],
						desc = L["Extra effect while you need to stand still. Pixel/Autocast/Proc/Button are borrowed from LibCustomGlow and only appear when WeakAuras (or another addon that includes it) is installed."],
						type = "select",
						order = 11.935,
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
						disabled = function() return not YaHT.db.profile.glow end,
					},
					glowkeepbuiltin = {
						name = L["Keep soft glow too"],
						desc = L["Show the built-in glow underneath the animated effect."],
						type = "toggle",
						order = 11.937,
						hidden = function() local st = YaHT.db.profile.glowstyle return st == "BUILTIN" or st == "SWEEP" end,
						disabled = function() return not YaHT.db.profile.glow end,
					},
					glowpulse = {
						name = L["Pulse when standing"],
						desc = L["Pulse the glow during the stand-still part."],
						type = "toggle",
						order = 11.94,
						disabled = function() return not YaHT.db.profile.glow end,
					},
					glowramp = {
						name = L["Build-up strength"],
						desc = L["How bright the glow gets by the end of the reload, before you stand still."],
						type = "range",
						order = 11.95,
						isPercent = true,
						min = 0.1,
						max = 1,
						step = 0.05,
						disabled = function() return not YaHT.db.profile.glow or YaHT.db.profile.glowmode == "STAND" end,
					},
					glowintensity = {
						name = L["Glow brightness"],
						type = "range",
						order = 11.96,
						isPercent = true,
						min = 0.1,
						max = 1,
						step = 0.05,
						disabled = function() return not YaHT.db.profile.glow end,
					},
					glowsize = {
						name = L["Glow size"],
						type = "range",
						order = 11.97,
						min = 2,
						max = 40,
						step = 1,
						disabled = function() return not YaHT.db.profile.glow end,
					},
					glowcolor = {
						name = L["Glow Color"],
						type = "color",
						order = 11.98,
						get = getColor,
						set = setColor,
						disabled = function() return not YaHT.db.profile.glow end,
					},
					sparkheader = {
						name = L["Spark"],
						type = "header",
						order = 11.991,
					},
					sparkmode = {
						name = L["Spark"],
						desc = L["A bright line at the moving edge of the bar. In the stand-still part the bar grows out from the middle, so the sparks start in the centre and race to the ends as the shot fires."],
						type = "select",
						order = 11.992,
						values = {OFF = L["Off"], STAND = L["Stand-still part only"], ALWAYS = L["Always"]},
						sorting = {"OFF", "STAND", "ALWAYS"},
					},
					sparksize = {
						name = L["Spark height"],
						desc = L["Spark height compared to the bar height."],
						type = "range",
						order = 11.993,
						min = 1,
						max = 8,
						step = 0.5,
						disabled = function() return YaHT.db.profile.sparkmode == "OFF" end,
					},
					sparkcolor = {
						name = L["Spark Color"],
						type = "color",
						hasAlpha = true,
						order = 11.994,
						get = getColor,
						set = setColor,
						disabled = function() return YaHT.db.profile.sparkmode == "OFF" end,
					},
					backgroundheader = {
						name = L["Background options"],
						type = "header",
						order = 12,
					},
					enablebackground = {
						name = L["Background"],
						desc = L["Show a background."],
						type = "toggle",
						order = 13,
					},
					background = {
						order = 14,
						type = "select",
						name = L["Background texture"],
						dialogControl = widget("LSM30_Background"),
						values = getMediaData,
					},
					backgroundcolor = {
						name = L["Background Color"],
						type = "color",
						order = 15,
						hasAlpha = true,
						get = getColor,
						set = setColor,
					},
					borderheader = {
						name = L["Border options"],
						type = "header",
						order = 16,
					},
					enableborder = {
						name = L["Border"],
						desc = L["Show a border."],
						type = "toggle",
						order = 17,
					},
					border = {
						order = 18,
						type = "select",
						name = L["Border texture"],
						dialogControl = widget("LSM30_Border"),
						values = getMediaData,
					},
					bordercolor = {
						name = L["Border Color"],
						type = "color",
						order = 19,
						get = getColor,
						set = setColor,
					},
					announceheader = {
						name = L["Announce options"],
						type = "header",
						order = 23,
					},
					tranqannounce = {
						name = string.format(L["Announce %s"],(YaHT.GetSpellName(19801) or "Tranquilizing Shot")),
						desc = L["Enable / disable the announcement."],
						type = "toggle",
						order = 24,
						width = "double",
					},
					tranqannouncefail = {
						name = string.format(L["Announce failed %s"],(YaHT.GetSpellName(19801) or "Tranquilizing Shot")),
						desc = L["Enable / disable the announcement."],
						type = "toggle",
						order = 25,
						width = "double",
					},
					announcetype = {
						name = L["Announce in"],
						desc = L["The channel in which to announce."],
						type = "select",
						order = 26,
						values = {["WHISPER"] = L["Whisper"], ["CHANNEL"] = L["Channel"], ["RAID_WARNING"] = L["Raid Warning"], ["SAY"] = L["Say"], ["YELL"] = L["Yell"], ["PARTY"] = L["Party"], ["RAID"] = L["Raid"]},
						set = function(info, value) set(info,value) LibStub("AceConfigRegistry-3.0", true):NotifyChange("YaHT") end
					},
					targetchannel = {
						name = L["Channel/Playername"],
						desc = L["Set the channel or player for whisper."],
						type = "input",
						order = 27,
						hidden = function() return not (YaHT.db.profile.announcetype == "WHISPER" or YaHT.db.profile.announcetype == "CHANNEL") end,
					},
					announcemsg = {
						name = L["Announce Message"],
						desc = L["Set the message to be broadcasted."],
						type = "input",
						order = 28,
						width = "full",
					},
					announcefailmsg = {
						name = L["Announce Fail Message"],
						desc = L["Set the message to be broadcasted."],
						type = "input",
						order = 29,
						width = "full",
					},
				}
			}
		}
	}

	AceConfigRegistry:RegisterOptionsTable(Addon, aceoptions, true)
	aceoptions.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	
	AceConfigDialog:AddToBlizOptions(Addon, nil, nil, "general")
	AceConfigDialog:AddToBlizOptions(Addon, L["Profiles"], Addon, "profile")
	
	AceConfigDialog:SetDefaultSize(Addon, 895, 570)
end