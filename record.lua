-- Two tools for finding problems without anyone having to describe them:
--
--   * The record: a short diary of the things that are hard to test on purpose
--     (a pet dying, an aspect warning, anything of YaHT's that broke). It is
--     always on, only writes when something changes, keeps the last 500 lines
--     and is saved with your settings.  /yaht record  shows the newest lines.
--
--   * The self-test (/yaht selftest): checks, in the real game, that the game
--     still offers everything YaHT asks it for, that every part of YaHT started,
--     that every options page draws, and that every alert shows. The report is
--     saved with your settings (after a /reload or logging out).
--
-- Nothing here runs unless something happens or you ask for the test.
if select(2,UnitClass("player")) ~= "HUNTER" then return end

local YaHT = YaHT
local L = YaHT.L

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end
-- a value as text, without ever touching one the game hides
local function Say(v)
	if IsSecret(v) then return "hidden" end
	return tostring(v)
end

---------------------------------------------------------------------------
-- The record
---------------------------------------------------------------------------
local RECORD_MAX = 500
local TAG_MAX = {aspect = 60} -- a talkative kind of line can't push the rare ones out
local fightStart -- when the current fight began (lines written in a fight say how far in)

function YaHT:Record(tag, msg)
	if not self.db then return end
	local g = self.db.global
	local log = g.record
	if not log then
		log = {}
		g.record = log
	end
	local when = date and date("%m-%d %H:%M:%S") or string.format("%.1f", GetTime())
	local fight = fightStart and string.format(" (fight +%.1fs)", GetTime() - fightStart) or ""
	log[#log + 1] = string.format("%s [%s]%s %s", when, tostring(tag), fight, tostring(msg))
	local cap = TAG_MAX[tag]
	if cap then
		local mark, n, first = "[" .. tag .. "]", 0, nil
		for i = 1, #log do
			if log[i]:find(mark, 1, true) then
				n = n + 1
				first = first or i
			end
		end
		if n > cap then table.remove(log, first) end
	end
	if #log > RECORD_MAX then table.remove(log, 1) end
end

-- /yaht record: the newest lines; /yaht record clear: empty it
function YaHT:PrintRecord(what)
	if not self.db then return end
	if what == "clear" then
		self.db.global.record = {}
		self:Print("record cleared.", true)
		return
	end
	local log = self.db.global.record or {}
	self:Print(string.format("record: %d lines (newest last)", #log), true)
	for i = math.max(1, #log - 11), #log do self:Print(log[i], true) end
end

function YaHT:InitRecord()
	local watch = CreateFrame("Frame")
	watch:SetScript("OnEvent", function(_, event)
		fightStart = event == "PLAYER_REGEN_DISABLED" and GetTime() or nil
	end)
	pcall(watch.RegisterEvent, watch, "PLAYER_REGEN_DISABLED")
	pcall(watch.RegisterEvent, watch, "PLAYER_REGEN_ENABLED")
	if InCombatLockdown and InCombatLockdown() then fightStart = GetTime() end
	self:Record("session", "YaHT " .. tostring(self.version) .. " loaded")
end

---------------------------------------------------------------------------
-- The self-test
---------------------------------------------------------------------------
-- what YaHT asks the game for, and what it is for
local GAME = {
	{"C_Spell.GetSpellName", "spell names"},
	{"C_Spell.GetSpellTexture", "spell icons"},
	{"C_Spell.IsSpellUsable", "the Mongoose Bite alert"},
	{"C_Spell.GetSpellCooldown", "the Mongoose Bite cooldown"},
	{"C_Spell.IsSpellInRange", "range warnings"},
	{"CheckInteractDistance", "the too-far warning"},
	{"UnitThreatSituation", "the fast Feign Death check"},
	{"IsPetAttackActive", "pet not attacking"},
	{"UnitHealthPercent", "pet low"},
	{"C_CurveUtil.CreateCurve", "pet low"},
	{"C_UnitAuras.GetAuraDataByIndex", "the aspect badge and Quick Shots"},
	{"issecretvalue", "values the game hides"},
	{"Enum.PlayerSwingType.Ranged", "the Auto Shot signal"},
	{"Enum.UITextureSliceMode.Stretched", "rounded corners"},
	{"ColorPickerFrame", "picking colors"},
	{"StaticPopup_Show", "yes / no questions"},
	{"SOUNDKIT.RAID_WARNING", "warning sounds"},
}

-- YaHT's own parts: where each one keeps its frame once it has started
local PARTS = {
	{"mainFrame", "the Auto Shot bar"}, {"ammoFrame", "ammo counter"}, {"meleeFrame", "melee line and range warnings"},
	{"mongooseFrame", "Mongoose Bite icon"}, {"quickShotsFrame", "Quick Shots icon"}, {"rapidFireFrame", "Rapid Fire icon"},
	{"racialFrame", "racial icon"}, {"aspectFrame", "aspect badge"}, {"feignFrame", "Feign Death alert"},
	{"petFrame", "pet alerts"}, {"minimapButton", "minimap button"},
}

-- the alerts "Preview all alerts" brings up: setting, frame, name
local ALERTS = {
	{"mongoose", "mongooseFrame", "Mongoose Bite"}, {"quickshots", "quickShotsFrame", "Quick Shots"},
	{"rapidfire", "rapidFireFrame", "Rapid Fire"}, {"racial", "racialFrame", "racial"},
	{"aspect", "aspectFrame", "aspect badge"}, {"feign", "feignFrame", "Feign Death"}, {"pet", "petFrame", "pet"},
}

local MEDIA = {"Bar", "Glow", "Spark", "Shine", "Stripes", "Chevron", "Round", "RoundEdge", "Dot", "Arrow", "Stage"}
local MEDIA_PATH = "Interface\\AddOns\\YaHT\\media\\"

local report -- the test being written

local function Add(ok, name, detail)
	local word = ok == nil and "INFO" or (ok and "PASS" or "FAIL")
	if ok == true then report.passed = report.passed + 1 elseif ok == false then report.failed = report.failed + 1 end
	report.lines[#report.lines + 1] = string.format("%s  %s%s", word, name, detail and (": " .. tostring(detail)) or "")
end

-- one part of the test; if the part itself breaks, that is a failure too
local function Part(name, fn)
	local ok, err = pcall(fn)
	if not ok then Add(false, name, "the check itself broke: " .. tostring(err)) end
end

local function Lookup(path)
	local v = _G
	for key in path:gmatch("[^%.]+") do
		if type(v) ~= "table" then return nil end
		v = v[key]
		if v == nil then return nil end
	end
	return v
end

local function Errors() return YaHT.errorCount or 0 end

local function TestGame()
	for _, def in ipairs(GAME) do
		local have = Lookup(def[1]) ~= nil
		local detail
		if not have then detail = "missing, needed for " .. def[2] end
		Add(have, "game: " .. def[1], detail)
	end
end

local function TestParts()
	for _, def in ipairs(PARTS) do
		local detail
		if YaHT[def[1]] == nil then detail = "did not start" end
		Add(YaHT[def[1]] ~= nil, "started: " .. def[2], detail)
	end
	local detail
	if YaHT.optionsTable == nil then detail = "the settings table is missing" end
	Add(YaHT.optionsTable ~= nil, "started: settings", detail)
end

-- every saved setting is still the kind of thing it should be
local function TestSettings()
	local defaults = YaHT.defaults and YaHT.defaults.profile
	if not defaults then return Add(false, "settings", "no defaults to compare with") end
	local p, bad, n = YaHT.db.profile, {}, 0
	for key, value in pairs(defaults) do
		n = n + 1
		if type(p[key]) ~= type(value) then bad[#bad + 1] = key .. " is a " .. type(p[key]) end
	end
	table.sort(bad)
	Add(#bad == 0, "settings", #bad == 0 and (n .. " settings in order") or table.concat(bad, ", "))
end

-- every page of the options window draws, its first dropdown opens, and search finds things
local function TestWindow()
	local Menu = YaHT.menu
	if not (Menu and YaHT.OpenMenu) then return Add(false, "options window", "not loaded") end
	local wasOpen = YaHTMenuFrame and YaHTMenuFrame:IsShown() or false
	local wasPage = Menu.current
	local before = Errors()
	local ok, opened = pcall(YaHT.OpenMenu, YaHT, "home")
	if not ok or not opened or Errors() > before then
		return Add(false, "options window", "did not open: " .. tostring(not ok and opened or YaHT.lastError))
	end
	Add(true, "options window", "opens")
	for _, id in ipairs(Menu.PageIds()) do
		before = Errors()
		Menu.Show(id)
		local rows, note = #Menu.rows, ""
		for _, row in ipairs(Menu.rows) do
			if row.kind == "select" and not row.off and row.onClick then
				local opens, err = pcall(row.onClick)
				local list = Menu.List()
				if not opens then
					YaHT.ReportError("a dropdown on " .. id, err)
				elseif list and list:IsShown() then
					note = string.format(", dropdown with %d choices", #list.keys)
				end
				Menu.CloseList()
				break
			end
		end
		local broke = Errors() > before
		Add(not broke and rows > 0, "page " .. id, broke and tostring(YaHT.lastError) or (rows .. " rows" .. note))
	end
	before = Errors()
	Menu.Search("glow")
	Add(Errors() == before and #Menu.rows > 1, "search", #Menu.rows .. " rows for \"glow\"")
	Menu.Show(wasPage or "home")
	if not wasOpen then YaHT:CloseMenu() end
end

-- YaHT's own pictures: asks the game for each one. A file that isn't there is
-- asked for as well, to learn whether the game's answer means anything.
local function TestMedia()
	local holder = YaHT.selfTestFrame
	local function try(name)
		local t = holder:CreateTexture()
		t:SetTexture(MEDIA_PATH .. name)
		local got = t.GetTexture and t:GetTexture() or nil
		t:Hide()
		return got ~= nil
	end
	local control = try("NoSuchPicture")
	for _, name in ipairs(MEDIA) do
		local loaded = try(name)
		if control then
			Add(nil, "picture " .. name, "asked for (the game doesn't say whether it loaded)")
		else
			Add(loaded, "picture " .. name, loaded and "loaded" or "did not load")
		end
	end
end

-- what the game lets YaHT see right now (not pass or fail, just written down)
local function TestReadings()
	local p = YaHT.db.profile
	Add(nil, "version", tostring(YaHT.version))
	Add(nil, "screen", string.format("%s x %s, options window scale %s",
		Say(UIParent.GetWidth and math.floor(UIParent:GetWidth() + 0.5)), Say(UIParent.GetHeight and math.floor(UIParent:GetHeight() + 0.5)),
		Say(YaHTMenuFrame and YaHTMenuFrame.GetScale and YaHTMenuFrame:GetScale())))
	if UnitExists then
		Add(nil, "pet", string.format("out %s, dead %s, attacking %s, health %s",
			Say(UnitExists("pet")), Say(UnitIsDead and UnitIsDead("pet")), Say(IsPetAttackActive and IsPetAttackActive()),
			Say(UnitHealth and UnitHealth("pet"))))
		Add(nil, "target", string.format("there %s, threat %s", Say(UnitExists("target")),
			Say(UnitThreatSituation and UnitThreatSituation("player", "target"))))
	end
	if UnitHealth then Add(nil, "your health", Say(UnitHealth("player"))) end
	local badge = YaHT.aspectFrame
	Add(nil, "aspect seen", badge and Say(badge.aspect) or "no badge")
	if YaHT.ReadAmmo then
		local count, _, method = YaHT:ReadAmmo()
		Add(nil, "ammo", Say(count) .. " (read from: " .. Say(method) .. ")")
	end
	Add(nil, "learned shot delay", Say(YaHT.calib))
	Add(nil, "bar", string.format("%s x %s, locked %s, look: glow %s / %s, sparks %s", Say(p.width), Say(p.height), Say(p.lock),
		Say(p.glow), Say(p.glowlook), Say(p.sparkmode)))
	local g = YaHT.db.global
	Add(nil, "saved lines", string.format("record %d, Feign Death %d, debug log %d", #(g.record or {}), #(g.fdlog or {}), #(g.debuglog or {})))
	Add(nil, "problems this session", Errors())
end

-- the alerts were asked to show a moment ago: are they up?
local function TestAlertsShown(before)
	local p = YaHT.db.profile
	for _, def in ipairs(ALERTS) do
		local f = YaHT[def[2]]
		if not p[def[1]] then
			Add(nil, "alert " .. def[3], "switched off")
		else
			local up = f ~= nil and f:IsShown() and true or false
			Add(up, "alert " .. def[3], up and "shows" or "did not show")
		end
	end
	local detail
	if Errors() > before then detail = tostring(YaHT.lastError) end
	Add(Errors() == before, "alerts ran clean", detail)
end

local function Finish()
	local g = YaHT.db.global
	report.when = date and date("%Y-%m-%d %H:%M:%S") or nil
	report.version = YaHT.version
	g.selftest = report
	YaHT:Record("selftest", string.format("%d passed, %d failed", report.passed, report.failed))
	YaHT:Print(string.format(L["self-test: %d passed, %d failed. Type /reload to save the report."], report.passed, report.failed), true)
	local shown = 0
	for _, line in ipairs(report.lines) do
		if line:sub(1, 4) == "FAIL" and shown < 8 then
			shown = shown + 1
			YaHT:Print(line, true)
		end
	end
	report = nil
end

local runner = CreateFrame("Frame")
runner:Hide()
runner:SetScript("OnUpdate", function(self, elapsed)
	self.left = self.left - elapsed
	if self.left > 0 then return end
	self:Hide()
	self.busy = false
	local ok, err = pcall(self.finish)
	if not ok and YaHT.ReportError then YaHT.ReportError("the self-test", err) end
end)
YaHT.selfTestFrame = runner

function YaHT:SelfTest()
	if not self.db or runner.busy then return end
	if InCombatLockdown and InCombatLockdown() then
		self:Print(L["self-test: wait until you're out of combat."], true)
		return
	end
	report = {lines = {}, passed = 0, failed = 0}
	self:Print(L["self-test running: the options window flickers and every alert shows for a few seconds."], true)
	Part("game", TestGame)
	Part("started", TestParts)
	Part("settings", TestSettings)
	Part("options window", TestWindow)
	Part("pictures", TestMedia)
	Part("readings", TestReadings)
	-- the alerts need a moment to come up: look half a second later, then write the report
	local before = Errors()
	local ok, err = true, nil
	if self.PreviewAlerts then ok, err = pcall(self.PreviewAlerts, self) end
	Add(ok, "preview all alerts", ok and "started" or tostring(err))
	runner.left = 0.6
	runner.busy = true
	runner.finish = function()
		Part("alerts", function() TestAlertsShown(before) end)
		Finish()
	end
	runner:Show()
end
