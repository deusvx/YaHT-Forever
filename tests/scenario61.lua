-- Weave cues: "Walk in" when your bow has just fired, "Walk out" when your melee weapon has swung.
local ev, mev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
for _,f in ipairs(frames) do if f.events.PLAYER_ENTER_COMBAT then mev=f end end
local db = YaHT.db.profile
local names = {[75]="Auto Shot",[2973]="Raptor Strike",[2974]="Wing Clip",[19434]="Aimed Shot",[3044]="Arcane Shot"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
local dist = 20
local reach = {["Wing Clip"] = {0, 5}, ["Auto Shot"] = {8, 35}}
C_Spell.IsSpellInRange = function(n) local r = reach[n] if not r then return true end return dist > r[1] and dist <= r[2] end
function CheckInteractDistance() return dist <= 28 end
function UnitExists() return true end
function UnitCanAttack() return true end
function InCombatLockdown() return true end
-- your shots' cooldowns: seconds left for each (nil = you do not have it)
local cd = {["Aimed Shot"] = 5, ["Arcane Shot"] = 5}
C_Spell.GetSpellCooldown = function(n) local left = cd[n] if not left then return {startTime = 0, duration = 0} end
  if left <= 0 then return {startTime = 0, duration = 0} end return {startTime = GetTime() - (6 - left), duration = 6} end
C_Spell.IsSpellUsable = function(n) return cd[n] ~= nil end
local w = YaHT.weaveFrame
assert(w and db.weave == false and not w.shown, "the weave cues should be there, and off to start with")
db.lock = true YaHT:ApplySettings()
local function run(sec) for k = 1, math.floor(sec/0.01 + 0.5) do advance(0.01) if w.shown then w.scripts.OnUpdate(w, 0.01) end end end
local function shot() fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.4, 2) end
local function swing() mev.scripts.OnEvent(mev, "PLAYER_SWING", 3.4, 0) end

-- off: nothing
shot() run(0.2) assert(not w.shown, "switched off, no cue")
db.weave = true YaHT:ApplySettings()
-- 1) at range, your shots on cooldown, the bow fires: Walk in. It goes once you are in melee.
shot() run(0.2)
assert(w.shown and w.cue == "IN" and w.text.txt == "Walk in", "a shot at range should say Walk in")
dist = 3 run(0.3) assert(not w.shown, "in melee the Walk in should go")
-- 2) the swing: Walk out. It goes once you are out of melee.
swing() run(0.2)
assert(w.shown and w.cue == "OUT" and w.text.txt == "Walk out", "a swing in melee should say Walk out")
run(2.5) assert(w.shown and w.cue == "OUT", "Walk out should stay while you stand in melee")
dist = 6.5 run(1.5) assert(w.shown and w.cue == "OUT", "in the deadzone you are not out yet: Walk out should stay")
dist = 12 run(0.3) assert(not w.shown, "past the deadzone the Walk out should go")
-- 3) a Walk in not acted on goes by itself
shot() run(0.2) assert(w.shown) run(2.2) assert(not w.shown, "a Walk in you ignore should not stay")
-- 4) a shot about to come off cooldown comes first: no Walk in ... unless you switch that off
cd["Aimed Shot"] = 1.0 shot() run(0.2) assert(not w.shown, "with Aimed Shot a second away there should be no Walk in")
cd["Aimed Shot"] = 0 shot() run(0.2) assert(not w.shown, "with Aimed Shot ready there should be no Walk in")
db.weavesmart = false shot() run(0.2) assert(w.shown and w.cue == "IN", "with 'Shots come first' off it should show") run(2.2)
db.weavesmart = true
-- a shot you do not have never holds it back
cd["Aimed Shot"] = nil cd["Arcane Shot"] = 5 shot() run(0.2) assert(w.shown and w.cue == "IN", "a shot you do not have must not hold Walk in back") run(2.2)
-- 5) already in melee when the bow fires: no Walk in; too far: none either
dist = 3 shot() run(0.2) assert(not w.shown, "in melee there is nowhere to walk in to")
dist = 40 shot() run(0.2) assert(not w.shown, "too far to shoot: no Walk in")
-- 6) placing it: a sample to drag while the bar is unlocked
-- linked to the bar by default: above it; the sample shows but is not dragged
assert(db.weavepos == "ABOVE" and w.point[2] == YaHT.mainFrame, "by default the cue is linked to the bar")
db.lock = false YaHT:ApplySettings() assert(w.shown and not w.mouse and not w.hint.shown, "linked to the bar, the sample is not dragged")
for _, where in ipairs({"BELOW", "LEFT", "RIGHT"}) do db.weavepos = where YaHT:ApplySettings() assert(w.point[2] == YaHT.mainFrame, where.." should be linked to the bar") end
db.weavepos = "FREE" YaHT:ApplySettings() assert(w.shown and w.mouse and w.hint.shown and w.point[2] ~= YaHT.mainFrame, "placed by hand, a sample should show to drag")
db.lock = true YaHT:ApplySettings() assert(not w.shown and not w.mouse)
-- the cue is a picture: three arrows, pointing up for in and down for out; or the word alone, or the arrows alone
shot() run(0.2)
assert(w.arrows[1].shown and w.arrows[3].shown and w.text.shown, "arrows and the word by default")
assert(w.pointing == "UP" and w.glow.shown, "Walk in points up, with its glow")
swing_ok = pcall(function() dist = 3 run(0.3) swing() run(0.2) end)
assert(w.cue == "OUT" and w.pointing == "DOWN", "Walk out should turn the arrows round")
dist = 20 run(0.4)
db.weavelook = "WORDS" YaHT:ApplySettings() assert(not w.arrows[1].shown and w.text.shown)
db.weavelook = "ARROWS" YaHT:ApplySettings() assert(w.arrows[1].shown and not w.text.shown)
db.weavelook = "BOTH" YaHT:ApplySettings()
assert((YaHT.errorCount or 0) == 0, tostring(YaHT.lastError))
local page = YaHT.optionsTable.args.alerts.args.weavepage.args
assert(not YaHT.optionsTable.args.alerts.args.meleepage.args.weave, "the weave settings have their own page now")
assert(page.weave and page.weavesize and page.weavesmart and page.weaveinsound and page.weaveoutsound, "the weave settings should be on the Melee weaving page")
assert(page.weaveinsound.type == "select" and YaHT.soundKeys.weaveinsound == "weaveinsoundkit", "each cue's sound should be a choice")
-- the page: what goes with weaving is there too, and its preview shows the rhythm
assert(page.melee and page.weaveboxes and page.weavemacro, "the Melee weaving page should offer what goes with it")
db.rangeyards = false page.weaveboxes.set(nil, true)
assert(db.rangeyards == true and db.rangeyardsstyle == "BOXES" and page.weaveboxes.get() == true, "Range boxes should switch the distance boxes on")
page.weaveboxes.set(nil, false) assert(db.rangeyards == false)
-- THE GAME'S OWN SWAP of Auto Attack and Auto Shot gets in the way of weaving: the page has a switch for
-- it, always there (so it can be put back), and its heading warns while it is on and weaving is.
do
  local cvar = "1"
  local oldC = C_CVar
  C_CVar = {GetCVar = function(n) if n == "autoRangedCombat" then return cvar end end,
            SetCVar = function(n, v) if n == "autoRangedCombat" then cvar = tostring(v) end end}
  db.weave = true
  assert(page.autoswap.type == "toggle" and not page.autoswap.hidden() and page.autoswap.get() == true, "the game's swap should be a switch on the page")
  assert(page.swaphead.name():find("best off", 1, true), "on, with weaving on: the heading warns")
  db.weave = false assert(not page.autoswap.hidden() and not page.swaphead.name():find("best off", 1, true), "the switch stays with weaving off, without the warning") db.weave = true
  page.autoswap.set(nil, false)
  assert(cvar == "0" and page.autoswap.get() == false and not page.autoswap.hidden(), "switching it off sets the game's setting; the switch stays")
  assert(not page.swaphead.name():find("best off", 1, true))
  page.autoswap.set(nil, true) assert(cvar == "1" and page.autoswap.get() == true, "and it can be put back")
  page.autoswap.set(nil, false)
  -- a game that does not have the setting: nothing shows, nothing breaks
  C_CVar = {GetCVar = function() error("no such setting") end}
  assert(YaHT:AutoSwapOn() == nil and page.autoswap.hidden() and page.swaphead.hidden())
  C_CVar = oldC
  assert(YaHT:IsNew("key", "autoswap"), "made new, so marked New")
  assert(page.swapnote and page.swapnote.type == "description" and page.swapnote.name:find("normal play", 1, true), "a small note under the switch says when it matters")
  assert((YaHT.errorCount or 0) == 0, tostring(YaHT.lastError))
end
local M = YaHT.menu
SlashCmdList["YAHT"]("")
M.Show("alerts/weavepage")
local demo = M.weaveDemo
assert(demo and demo.shown, "the weaving page's preview should show the rhythm")
local seen = {}
for i = 1, 600 do advance(0.01) demo.scripts.OnUpdate(demo, 0.01) seen[demo.step.txt or ""] = true end
assert(seen["1. Your bow fires: walk in"] and seen["2. Swing"] and seen["3. Your weapon swings: walk out"] and seen["4. Shoot, and again"], "the demo should walk through its four steps")
M.Show("bar/lookpage") assert(not demo.shown, "the demo belongs to its own page")
-- "New": this version's new pages and settings carry it; a page's goes once it has been opened
assert(YaHT:IsNew("page", "alerts/macrospage") and YaHT:IsNew("key", "cuehead") and not YaHT:IsNew("key", "lock"))
local f = YaHTMenuFrame
local function navNew(id) for _, b in ipairs(f.nav) do if b.shown and b.page == id and not b.group then return b.isNew end end end
assert(navNew("alerts/macrospage") == true, "a new page should carry New in the list")
assert(navNew("alerts/weavepage") == true, "a new page keeps its New after you have opened it")
assert(navNew("bar/lookpage") == true and navNew("alerts/rangepage") == true and navNew("bar/textpage") == false, "pages with something new carry New, the others do not")
M.Show("alerts/weavepage")
local tagged = 0
for _, r in ipairs(M.rows) do if r.newTag and r.newTag.shown then tagged = tagged + 1 end end
assert(tagged >= 3, "the new cards and settings on the page should carry New, "..tagged.." do")
for _, r in ipairs(M.rows) do if r.newTag and r.newTag.shown then assert(r.newTag.text.txt == "New" and not r.newTag.glow and not r.newTag.plate, "New should be the word alone") end end
M.Show("bar/textpage")
for _, r in ipairs(M.rows) do assert(not (r.newTag and r.newTag.shown), "nothing on an older page carries New") end
M.Show("bar/lookpage")
local barNew = 0
for _, r in ipairs(M.rows) do if r.newTag and r.newTag.shown then barNew = barNew + 1 end end
assert(barNew >= 1, "the bar style, made today, should carry New")
YaHT.version = "9.9.9" assert(not YaHT:IsNew("key", "cuehead"), "the marks belong to one version only")
print("OK61")
