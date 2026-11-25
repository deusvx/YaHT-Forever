-- The distance to your target (1.5): a band of yards worked out from "is this in reach?" answers.
local ev, mev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
for _,f in ipairs(frames) do if f.events.PLAYER_ENTER_COMBAT then mev=f end end
local db = YaHT.db.profile
local names = {[75]="Auto Shot",[2973]="Raptor Strike",[2974]="Wing Clip",[19503]="Scatter Shot"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellInfo = function(id)
  if id == 75 then return {minRange = 8, maxRange = 35} end
  if id == 2974 then return {minRange = 0, maxRange = 5} end
  if id == 19503 then return {minRange = 0, maxRange = 15} end
end
-- the world: one true distance, and the game answering only yes / no
local dist, target, itemsWork = 12, true, false
local reach = {["Wing Clip"] = {0, 5}, ["Auto Shot"] = {8, 35}, ["Scatter Shot"] = {0, 15}}
C_Spell.IsSpellInRange = function(n) local r = reach[n] if not r then return true end return dist > r[1] and dist <= r[2] end
function CheckInteractDistance(u, i) return dist <= 28 end
local itemReach = {[10645] = 20, [835] = 30, [7734] = 30, [18904] = 35}
C_Item = C_Item or {}
C_Item.IsItemInRange = function(id) if not itemsWork then return nil end return dist <= itemReach[id] end
function UnitExists() return target end
function UnitCanAttack() return target end
function InCombatLockdown() return false end
local dt = 0.01
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt) mev.scripts.OnUpdate(mev, dt) end end
db.lock = true YaHT:ApplySettings()
local y = YaHT.rangeYardsFrame
assert(y and db.rangeyards == false, "the distance should be there, and off to start with")
run(0.5) assert(not y.shown, "it showed while switched off")
db.rangeyards = true YaHT:ApplySettings()

local function at(d, lo, hi, zone)
  dist = d run(0.3)
  assert(y.shown and y.lo == lo and y.hi == hi and y.zone == zone,
    string.format("at %d yards: expected %s-%s %s, got %s-%s %s", d, tostring(lo), tostring(hi), tostring(zone), tostring(y.lo), tostring(y.hi), tostring(y.zone)))
end
-- with spells alone: the bands every hunter gets
at(3, 0, 5, "MELEE")
at(6, 5, 8, "DEAD")
at(12, 8, 15, "OK")
at(22, 15, 28, "OK")
at(33, 28, 35, "OK")
at(40, 35, nil, "FAR")
assert(y.text.txt == "35+ yd", "beyond the last check it should say so: "..tostring(y.text.txt))
dist = 12 run(0.3)
assert(y.text.txt == "8-15 yd" and y.text.tcolor[2] > 0.8, "the number, green while you can shoot: "..tostring(y.text.txt))
dist = 6 run(0.3)
assert(math.abs(y.text.tcolor[1] - db.meleedeadcolor.r) < 1e-6 and math.abs(y.text.tcolor[2] - db.meleedeadcolor.g) < 1e-6, "the deadzone's color in the deadzone")
-- where the game answers for items, the bands get finer
itemsWork = true
at(18, 15, 20, "OK")
at(22, 20, 28, "OK")
at(29, 28, 30, "OK")
at(33, 30, 35, "OK")
-- an item that answers nonsense is left out (it says "in reach at 20" while the spells say beyond 28)
C_Item.IsItemInRange = function(id) if id == 10645 then return true end return dist <= itemReach[id] end
at(33, 30, 35, "OK")
itemsWork = false
C_Item.IsItemInRange = function() return nil end
-- no target: nothing
target = false run(0.3) assert(not y.shown, "no target, no distance") target = true
-- only in a fight
db.rangeyardswhen = "COMBAT" run(0.3) assert(not y.shown, "set to fights only, it showed outside one")
function InCombatLockdown() return true end run(0.3) assert(y.shown, "in a fight it should show")
function InCombatLockdown() return false end
db.rangeyardswhen = "TARGET"
-- the ruler: four zones and a bright block over the band
db.rangeyardsstyle = "RULER" YaHT:ApplySettings() dist = 12 run(0.3)
assert(y.ruler.shown and not y.text.shown, "ruler alone")
-- (the shooting zone runs from 24% to 84% of the ruler: 8 yards is its start, 15 is 7/27 of the way in)
assert(math.abs(y.mark.point[4] - 0.24 * y.rulerW) < 0.01 and math.abs(y.mark.width - 0.60 * 7 / 27 * y.rulerW) < 0.01, "the block should cover 8 to 15 yards: "..tostring(y.mark.point[4]).." "..tostring(y.mark.width))
assert(math.abs(y.rulerW - db.width * db.scale) < 0.01, "the ruler should be as wide as the bar")
assert(y.tickMin.txt == "8" and y.tickMax.txt == "35", "the ruler should carry the two numbers that matter")
db.rangeyardsstyle = "BOTH" YaHT:ApplySettings() run(0.3)
assert(y.ruler.shown and y.text.shown, "number and ruler")
db.rangeyardsstyle = "NUMBER" YaHT:ApplySettings()
-- where it sits: under the bar (below the warning's words when those are there), over it, anywhere
assert(y.point[1] == "TOP" and y.point[3] == "BOTTOM", "under the bar to start with")
local plain = y.point[5]
db.rangetext = true YaHT:ApplySettings() assert(y.point[5] < plain, "it should move down to make room for the warning's words")
db.rangetext = false
db.rangeyardspos = "ABOVE" YaHT:ApplySettings() assert(y.point[1] == "BOTTOM" and y.point[3] == "TOP", "over the bar")
db.rangeyardspos = "FREE" db.lock = false YaHT:ApplySettings()
assert(y.shown and y.dragHint.shown and y.text.txt == "20-28 yd", "unlocked: a sample to drag")
y.scripts.OnDragStop(y) assert(db.rangeyardspoint == "CENTER" and db.rangeyardsx == 10, "a drag should be remembered")
db.lock = true db.rangeyardspos = "UNDER" YaHT:ApplySettings()
-- its settings are on the Range page
local page = YaHT.optionsTable.args.alerts.args.rangepage.args
for _, key in ipairs({"rangeyards", "rangeyardsstyle", "rangeyardswhen", "rangeyardspos", "rangeyardssize"}) do assert(page[key], "the Range page is missing "..key) end
assert((YaHT.errorCount or 0) == 0, "YaHT reported a problem")
-- Boxes: one box per range band with its yards, only the one the target is in lit
db.rangeyardsstyle = "BOXES" db.lock = true YaHT:ApplySettings()
local function litBox()
  local n, which = 0, 0
  for i = 1, 4 do local c = y.boxLabels[i].tcolor if c and c[1] == 1 and c[2] == 1 and c[3] == 1 then n = n + 1 which = i end end
  return n, which
end
dist = 3 run(0.3)
assert(y.shown and y.boxLabels[1].shown and not y.text.shown, "the boxes should show, without the number")
assert(y.boxLabels[1].txt == "0-5" and y.boxLabels[2].txt == "5-8" and y.boxLabels[3].txt == "8-35" and y.boxLabels[4].txt == "35+",
  "each box should carry its yards, got "..tostring(y.boxLabels[1].txt).." "..tostring(y.boxLabels[2].txt).." "..tostring(y.boxLabels[3].txt).." "..tostring(y.boxLabels[4].txt))
local wantBox = {{3, 1}, {6, 2}, {20, 3}, {40, 4}}
for _, wb in ipairs(wantBox) do
  dist = wb[1] run(0.3)
  local n, which = litBox()
  assert(n == 1 and which == wb[2], string.format("at %d yards box %d should be the only one lit, got %d lit (box %d)", wb[1], wb[2], n, which))
end
-- back to the ruler: the boxes' words go, the block and the two numbers come back
db.rangeyardsstyle = "RULER" YaHT:ApplySettings() run(0.3)
assert(not y.boxLabels[1].shown and y.mark.shown and y.tickMin.shown, "the ruler should be itself again")
print("OK48")
