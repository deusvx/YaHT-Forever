-- Pack or Cheetah on in a fight (1.5): the words "Pack On!" / "Cheetah On!" bounce next to the red badge.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile local b=YaHT.aspectFrame local w=YaHT.aspectWatch
db.lock=true YaHT:ApplySettings()
local s = YaHT.aspectShoutFrame
assert(s and db.aspectpackalert == "WORDS" and db.aspectcheetahalert == "ICON", "Pack should start on words, Cheetah on the icon")
local names = {[13165]="Aspect of the Hawk",[5118]="Aspect of the Cheetah",[13159]="Aspect of the Pack"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellTexture = function(id) return "icon"..id end
local current = "Aspect of the Pack"
C_UnitAuras = {GetAuraDataBySpellName = function(unit, name) if name == current then return {icon = "buff:"..name} end end}
local inCombat = false
function InCombatLockdown() return inCombat end
local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w,dt) end
  if b.shown then b.scripts.OnUpdate(b,dt) end
  if s.shown then s.scripts.OnUpdate(s,dt) end end end
local function fire(e) w.scripts.OnEvent(w, e, "player") end

-- Pack on, out of a fight: the badge shows it quietly, no words
fire("UNIT_AURA") run(0.3)
assert(b.aspect == "PACK" and not s.shown, "no words outside a fight")
-- the fight starts: "Pack On!", and it bounces
inCombat = true fire("PLAYER_REGEN_DISABLED") run(0.3)
assert(s.shown and s.text.txt == "Pack On!", "Pack in a fight should say so: "..tostring(s.text.txt))
local lowest, highest = 1e9, -1e9
for k = 1, 60 do run(0.01) local y = s.text.point[5] lowest = math.min(lowest, y) highest = math.max(highest, y) end
assert(lowest < 1.5 and highest > 8, "the words should bounce: "..lowest.." .. "..highest)
assert(not b.bouncing, "with Pack it is the words that bounce, not the icon")
-- HIT with Pack on: the words double in size and flash for a moment, then go back
assert(db.aspecthit == true and s.text.font[2] == 22, "the words at their normal size before a hit")
w.scripts.OnEvent(w, "UNIT_COMBAT", "player", "WOUND") run(0.1)
assert(s.text.font[2] == 44, "hit: the words should double in size: "..tostring(s.text.font[2]))
local reds, whites = 0, 0
for k = 1, 40 do run(0.02) if s.text.tcolor[2] > 0.9 then whites = whites + 1 else reds = reds + 1 end end
assert(reds > 3 and whites > 3, "and flash: "..reds.." / "..whites)
run(1.2)
assert(s.text.font[2] == 22 and math.abs(s.text.tcolor[2] - 0.25) < 1e-6, "afterwards back to normal size and red")
-- a heal or a miss is not a hit
w.scripts.OnEvent(w, "UNIT_COMBAT", "player", "HEAL") run(0.1) assert(s.text.font[2] == 22, "a heal is not a hit")
-- Cheetah: no words; the icon itself bounces and glows
current = "Aspect of the Cheetah" fire("UNIT_AURA") run(0.3)
assert(not s.shown, "Cheetah should have no words")
assert(b.bouncing and b.halo.shown, "the Cheetah icon should bounce and glow in a fight")
-- smoothly: from where it stands, up and back, never a jump of more than a hair between two frames
do
  local low, high, last, worst = 1e9, -1e9, nil, 0
  for k = 1, 120 do
    run(0.01)
    local y = b.point[5]
    low, high = math.min(low, y), math.max(high, y)
    if last then worst = math.max(worst, math.abs(y - last)) end
    last = y
  end
  assert(math.abs(low - 20) < 0.3 and high > 26, "it should rise from its own spot and come back: "..low.." .. "..high)
  assert(worst < 1, "the bounce should be smooth, no jumps: "..worst)
end
-- HIT with Cheetah on: the icon doubles in size where it stands, and flashes
w.scripts.OnEvent(w, "UNIT_COMBAT", "player", "WOUND") run(0.1)
assert(math.abs(b.scale - db.scale * 2) < 1e-6, "hit: the icon should double in size: "..tostring(b.scale))
assert(math.abs(b.point[4] - 5) < 1e-6 and b.point[5] <= 20, "it should grow where it stands (its place halved in the doubled measure): "..tostring(b.point[4]))
run(1.4)
assert(math.abs(b.scale - db.scale) < 1e-6 and b.icon.color[2] == 1, "afterwards back to its own size, picture in its own colors")
db.aspecthit = false w.scripts.OnEvent(w, "UNIT_COMBAT", "player", "WOUND") run(0.1)
assert(math.abs(b.scale - db.scale) < 1e-6, "switched off, a hit changes nothing") db.aspecthit = true
-- you switch to Hawk: it stops
current = "Aspect of the Hawk" fire("UNIT_AURA") run(0.3)
assert(not s.shown and not b.bouncing, "everything should stop once you switch")
assert(b.point[5] == 20, "the icon should be back exactly where it stood: "..tostring(b.point[5]))
-- Cheetah outside a fight does not bounce
inCombat = false fire("PLAYER_REGEN_ENABLED") current = "Aspect of the Cheetah" fire("UNIT_AURA") run(0.3)
assert(not b.bouncing, "Cheetah outside a fight must not bounce")
inCombat = true fire("PLAYER_REGEN_DISABLED") run(0.3) assert(b.bouncing, "and it starts with the fight")
db.aspectcheetahalert = "OFF" run(0.3) assert(not b.bouncing and not s.shown, "set to nothing extra, the icon keeps still")
-- options: Cheetah as words, or both
db.aspectcheetahalert = "WORDS" YaHT:ApplySettings() run(0.3)
assert(s.shown and s.text.txt == "Cheetah On!" and not b.bouncing, "Cheetah as words: "..tostring(s.text.txt))
db.aspectcheetahalert = "BOTH" run(0.3)
assert(s.shown and b.bouncing, "Cheetah as words and icon")
db.aspectcheetahalert = "ICON" run(0.3)
current = "Aspect of the Hawk" fire("UNIT_AURA") run(0.3)
-- back in Pack; the fight ends: gone
current = "Aspect of the Pack" fire("UNIT_AURA") run(0.3) assert(s.shown)
inCombat = false fire("PLAYER_REGEN_ENABLED") run(0.3)
assert(not s.shown, "no words once the fight is over")
-- switched off: the red badge without words
db.aspectpackalert = "OFF" YaHT:ApplySettings()
inCombat = true fire("PLAYER_REGEN_DISABLED") run(0.3)
assert(not s.shown and b.shown and not b.bouncing, "Pack set to nothing extra: the red badge alone")
db.aspectpackalert = "ICON" run(0.3) assert(not s.shown and b.bouncing, "Pack as a bouncing icon")
db.aspectpackalert = "WORDS" YaHT:ApplySettings() run(0.3) assert(s.shown and not b.bouncing, "Pack back on words")
inCombat = false fire("PLAYER_REGEN_ENABLED") run(0.3)
-- unlocked: a sample to drag, and a drag is remembered
db.lock = false YaHT:ApplySettings()
assert(s.shown and s.dragHint.shown and s.text.txt == "Pack On!", "unlocked: a sample to drag")
s.scripts.OnDragStop(s) assert(db.aspectshoutpoint == "CENTER" and db.aspectshoutx == 10, "a drag should be remembered")
db.lock = true YaHT:ApplySettings() run(0.3)
assert(not s.shown, "locked again outside a fight: the sample goes")
local page = YaHT.optionsTable.args.alerts.args.aspectpage.args
assert(page.aspectpackalert and page.aspectcheetahalert and page.aspectshoutsize and not page.aspectshout, "the Aspect page should have one choice for each aspect")
assert((YaHT.errorCount or 0) == 0, "YaHT reported a problem")
print("OK49")
