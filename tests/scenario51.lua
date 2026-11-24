-- Lone Wolf mode (1.5.1): the bar's own look for a hunter without a pet. Its own
-- reload and glow colour, a wolf's head on the bar, pet warnings quiet except
-- PET OUT (a pet out costs the bonus), and Bestial Wrath's place freed.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end

local exists, dead = false, false
function UnitExists(u) if u == "pet" then return exists end return true end
function UnitIsDead(u) if u == "pet" then return dead end return false end
function UnitIsDeadOrGhost() return false end
function IsMounted() return false end
function IsPetAttackActive() return true end

ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local a, w, m = YaHT.petFrame, YaHT.petWatch, YaHT.mainFrame
local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w, dt) end end end
local function fire(e, ...) w.scripts.OnEvent(w, e, ...) end

-- off to start with for a hunter without the talent: nothing changes
assert(db.lonewolf == "AUTO" and YaHT:LoneWolfMode() == false, "the mode should be off without Lone Wolf")
assert(YaHT.Look(db, "timercolor") == db.timercolor and not m.scope, "the normal look changed")

-- Always: the bar takes its Lone Wolf colours and the wolf's head shows
db.lock = true db.lonewolf = "ALWAYS" YaHT:ApplySettings() run(0.1)
assert(YaHT:LoneWolfMode() == true, "Always should switch the mode on")
assert(YaHT.Look(db, "timercolor") == db.lonewolfcolor and YaHT.Look(db, "glowcolor") == db.lonewolfglowcolor, "no Lone Wolf colours")
assert(YaHT.Look(db, "drawcolor") == db.drawcolor, "the stand-still colour should stay")
-- Scope: the plain bar stays, with a range scale under it and a crosshair on it
local c = m.scope
assert(c and c.shown and m.background.shown, "no scope on the bar")
assert(#c.ticks == 8 and c.ticks[0] and c.ticks[4].h > c.ticks[1].h, "the range scale should have longer ticks at the ends and the middle")
-- reloading: the bar stays plain, no crosshair on it
db.lock = false YaHT:ApplySettings()
m.mockTime = m.swingtime * 0.5
m.scripts.OnUpdate(m, 0.01)
assert(not c.reticle.shown and not c.shadow.shown, "no crosshair while reloading")
-- stand still: it locks on in the middle with a short kick, then rests at its size
m.mockTime = m.swingtime + 0.05
m.scripts.OnUpdate(m, 0.01)
assert(c.reticle.w > db.lonewolfheight, "no kick when the crosshair locks on")
advance(0.5) m.scripts.OnUpdate(m, 0.01)
assert(math.abs(c.reticle.w - db.lonewolfheight) < 0.01 and c.reticle.alpha == 1, "the locked crosshair should rest at its size")
db.lonewolfheight = 30 YaHT:ApplySettings() m.scripts.OnUpdate(m, 0.01)
assert(math.abs(c.reticle.w - 30) < 0.01, "the crosshair ignores its size")
-- Plain bar: only the colours
db.lonewolfstyle = "PLAIN" YaHT:ApplySettings()
assert(not c.shown and YaHT.Look(db, "timercolor") == db.lonewolfcolor, "Plain should be the normal bar in Lone Wolf colours")
db.lonewolfstyle = "SCOPE" YaHT:ApplySettings()
assert(c.shown, "the scope didn't come back")
db.lock = true YaHT:ApplySettings()
-- Bestial Wrath needs a pet: its place is freed
YaHT.db.char.bestialSeen = true
assert(YaHT.BestialKnown() == false, "Bestial Wrath's place should be freed in Lone Wolf mode")

-- no pet in a fight: quiet, however often a pet was out before
YaHT.db.char.petSeen = true
sounds = {}
fire("PLAYER_REGEN_DISABLED") run(4)
assert(not a.shown and #sounds == 0, "NO PET in Lone Wolf mode")
-- a pet out: you're hunting the regular way, so everything is regular (bar, colours, Bestial Wrath, pet warnings)
exists = true fire("UNIT_PET", "player") run(0.1)
assert(YaHT:LoneWolfMode() == false and not c.shown, "the Lone Wolf look should step aside while a pet is out")
assert(YaHT.Look(db, "timercolor") == db.timercolor and YaHT.BestialKnown() == true, "the bar isn't regular with a pet out")
assert(not a.text.shown and a.low.shown and #sounds == 0, "with the look on Always a pet out is not a warning")
dead = true fire("UNIT_HEALTH", "pet") run(0.1)
assert(a.text.shown and a.text.txt == "PET DEAD", "regular pet warnings should work with a pet out")
dead = false fire("UNIT_HEALTH", "pet") run(0.1)
-- the pet leaves: the look is back
exists = false fire("UNIT_PET", "player") run(0.1)
assert(YaHT:LoneWolfMode() and c.shown and not a.text.shown, "the Lone Wolf look didn't come back without the pet")
fire("PLAYER_REGEN_ENABLED") run(0.1)

-- Off: everything back to normal
db.lonewolf = "OFF" YaHT:ApplySettings() run(0.1)
assert(not YaHT:LoneWolfMode() and not c.shown and YaHT.Look(db, "timercolor") == db.timercolor, "Off left something behind")
assert(YaHT.BestialKnown() == true, "Bestial Wrath should count again")

-- Automatic: on by itself once the game says you have Lone Wolf, off again when you drop it
db.lonewolf = "AUTO" YaHT:ApplySettings() run(0.1)
assert(not c.shown, "Automatic switched on without the talent")
local oldInfo, oldKnown = C_Spell and C_Spell.GetSpellInfo, IsPlayerSpell
C_Spell = C_Spell or {}
C_Spell.GetSpellInfo = function(x) if x == "Lone Wolf" then return {spellID = 155228} end return oldInfo and oldInfo(x) end
IsPlayerSpell = function(id) if id == 155228 then return true end return oldKnown and oldKnown(id) end
fire("PLAYER_TALENT_UPDATE") run(0.1)
assert(YaHT:LoneWolfMode() and c.shown, "Automatic didn't switch on with Lone Wolf")
-- with the talent itself, a pet out in a fight costs the bonus: PET OUT (on the regular bar), with one sound
sounds = {}
exists = true fire("UNIT_PET", "player") fire("PLAYER_REGEN_DISABLED") run(0.1)
assert(not c.shown and a.text.shown and a.text.txt == "PET OUT" and #sounds == 1, "no PET OUT with the talent and a pet out")
db.lonewolfpet = false YaHT:ApplySettings() run(0.1) assert(not a.text.shown, "PET OUT ignores its switch")
db.lonewolfpet = true YaHT:ApplySettings() run(0.1) assert(a.text.shown, "PET OUT didn't come back")
fire("PLAYER_REGEN_ENABLED") run(0.1) assert(not a.text.shown, "PET OUT out of a fight")
exists = false fire("UNIT_PET", "player") run(0.1)
assert(YaHT:LoneWolfMode() and c.shown, "setup: the look is back")
C_Spell.GetSpellInfo, IsPlayerSpell = oldInfo, oldKnown
fire("PLAYER_TALENT_UPDATE") run(0.1)
assert(not YaHT:LoneWolfMode() and not c.shown, "Automatic stayed on after dropping Lone Wolf")

-- Lone Wolf has its own page under the bar, and Reset puts it back
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
assert(not opts.args.bar.args.lookpage.args.lonewolf and not opts.args.bar.args.lookpage.args.lonewolfheader, "Lone Wolf should have left the Look page")
local page = opts.args.bar.args.lonewolfpage.args
assert(page.lonewolf and page.lonewolfcolor and page.lonewolfglowcolor and page.lonewolfstyle and page.lonewolfheight and page.lonewolfpet, "the Lone Wolf settings are missing")
db.lonewolf = "ALWAYS" db.lonewolfcolor.r = 0
page.reset.func()
assert(db.lonewolf == "AUTO" and db.lonewolfcolor.r ~= 0, "Reset this page left the Lone Wolf settings")
-- YaHT's own window draws the page, with every setting on it
SlashCmdList["YAHT"]("")
local M = YaHT.menu
M.Show("bar/lonewolfpage")
local function row(key) for _, r in ipairs(M.rows) do local pth = r.item and r.item.path if pth and pth[#pth].key == key then return r end end end
assert(M.helpTitle == "Lone Wolf", "the Lone Wolf page didn't open: "..tostring(M.helpTitle))
for _, key in ipairs({"lonewolf", "lonewolfstyle", "lonewolfcolor", "lonewolfglowcolor", "lonewolfheight", "lonewolfpet"}) do
  assert(row(key), "the Lone Wolf page is missing "..key)
end
-- the preview on that page shows the look you are setting (even with a pet out or without the talent):
-- the scale, and the crosshair once the preview's shot is at "stand still"
local pv
for _, fr in ipairs(frames) do if fr.reticle and fr.ticks and fr ~= m.scope then pv = fr end end
assert(pv and pv.wolf and pv.scope and pv.ticks[4].shown, "the preview doesn't show the scope on the Lone Wolf page")
local seen = false
for i = 1, 200 do pv.scripts.OnUpdate(pv, 0.05) if pv.reticle.shown then seen = true end end
assert(seen, "the preview never showed the crosshair")
exists = true
db.lonewolfstyle = "PLAIN" M.Show("bar/lonewolfpage") YaHT:ApplySettings() M.Render()
assert(pv.wolf and not pv.scope and not pv.ticks[4].shown, "Plain bar: the preview should drop the scope, keep the colours")
db.lonewolfstyle = "SCOPE" db.lonewolf = "OFF" M.Render()
assert(not pv.wolf and not pv.ticks[4].shown, "Off: the preview should be regular")
db.lonewolf = "AUTO" exists = false
M.Show("bar/lookpage")
assert(not row("lonewolf") and row("timercolor"), "the Look page should no longer carry Lone Wolf")
assert(not pv.wolf, "other pages preview the bar as it really is")
print("OK51")
