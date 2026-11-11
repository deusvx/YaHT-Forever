-- Feign Death resist alert (1.2): a separate, movable icon with RESIST and a
-- sound. Triggered by the game's "Resisted" message, by losing health while
-- feigned, or by your target still targeting you; quiet on a clean feign.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile local a=YaHT.feignFrame local w=YaHT.feignWatch
assert(a and w, "no Feign Death alert")
db.lock=true YaHT:ApplySettings()
assert(a.text.txt=="RESIST", "alert should say RESIST")

local health, feigned, targetOnYou = 1000, false, false
function UnitHealth() return health end
function UnitIsFeignDeath() return feigned end
function UnitExists(u) return true end
function UnitCanAttack() return true end
function UnitIsDead() return false end
function UnitIsUnit(a1, a2) return targetOnYou end
ERR_FEIGN_DEATH_RESISTED = "Resisted"

local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w,dt) end
  if a.shown then a.scripts.OnUpdate(a,dt) end end end
local function fire(e,...) w.scripts.OnEvent(w,e,...) end
local function feign() feigned=true fire("UNIT_SPELLCAST_SUCCEEDED","player","guid",5384) end

-- a clean feign: no alert, and the watcher stops after a few seconds
sounds = {}
feign() run(0.5)
assert(w.active and not a.shown, "alert on a clean feign")
run(3) assert(not w.active and not w.shown, "watcher should stop after a few seconds")
feigned=false

-- 1. the game's own message
feign() run(0.2) fire("UI_ERROR_MESSAGE", 1, "Resisted") run(0.05)
assert(a.shown and a.alpha>0.5 and w.resisted, "no alert on the game's Resisted message")
assert(#sounds>=1, "no warning sound")
run(0.05) assert(a.icon.w > 40, "should pop in a bit big") run(0.4)
assert(math.abs(a.icon.w-40)<1e-6, "icon should settle at its size")
-- only once per feign
local n=#sounds fire("UI_ERROR_MESSAGE", 1, "Resisted") assert(#sounds==n, "alerted twice for one feign")
run(db.feigntime + 1) assert(not a.shown, "alert didn't go away")
run(3) feigned=false

-- 2. hit while feigned (off by default: Forever hides your health in combat, so this only
--    helps on clients that show it; tested here with it switched on)
assert(db.feignhitcheck==false, "the health signal should be off by default on Forever")
db.feignhitcheck=true
feign() run(0.4) health=900 fire("UNIT_HEALTH","player") run(0.05)
assert(a.shown and w.resisted, "no alert when hit while feigned")
run(4) health=1000 feigned=false
-- ... but health moving right as you feign doesn't count
feign() health=950 fire("UNIT_HEALTH","player") run(0.05)
assert(not w.resisted, "a hit right as you feigned counted as a resist")
run(4) health=1000 feigned=false
-- ... and it can be switched off (damage-over-time false alarms)
db.feignhitcheck=false feign() run(0.4) health=900 fire("UNIT_HEALTH","player") run(0.05)
assert(not w.resisted, "hit check ignores its setting")
run(4) db.feignhitcheck=true health=1000 feigned=false

-- 3. your target still targets you, at 1.5s and again at 2.5s
targetOnYou=true feign() run(1.0) assert(not w.resisted, "decided too early (a slow mob looks the same at 1s)")
run(1.6) assert(w.resisted and a.shown, "no alert when the target stays on you")
run(4) feigned=false
-- a mob that's just slow to turn away: on you at 1.5s, gone by 2.5s -> no alert
targetOnYou=true feign() run(1.6) targetOnYou=false run(1.2)
assert(not w.resisted, "a slow-turning mob counted as a resist")
run(4) targetOnYou=false feigned=false

-- hidden values: no alert, no error
function UnitHealth() return SECRET end
function UnitIsUnit() return SECRET end
feign() run(0.4) fire("UNIT_HEALTH","player") fire("UI_ERROR_MESSAGE", 1, SECRET) run(1)
assert(not w.resisted, "secret values should never cause an alert")
run(4) feigned=false
function UnitHealth() return health end
function UnitIsUnit() return targetOnYou end

-- other spells don't start the watch
fire("UNIT_SPELLCAST_SUCCEEDED","player","guid",19434) run(0.1)
assert(not w.active, "watching after a different spell")

-- movable: unlocked it shows (with a drag hint) and can be dragged; spot is saved
db.lock=false YaHT:ApplySettings() run(0.3)
assert(a.shown and a.alpha>0.9 and a.dragHint.shown and a.mouse, "can't place it while unlocked")
a.GetPoint=function() return "TOPLEFT", UIParent, "TOPLEFT", 300, -200 end
a.scripts.OnDragStop(a)
assert(db.feignpoint=="TOPLEFT" and db.feignx==300 and db.feigny==-200, "dragged spot not saved")
YaHT:ApplySettings() assert(a.point[1]=="TOPLEFT" and a.point[4]==300, "saved spot not used")
db.lock=true YaHT:ApplySettings() run(1) assert(not a.shown and not a.mouse, "still shown/clickable after locking")

-- test button + slash command
sounds={} SlashCmdList["YAHT"]("feign") run(0.1) assert(a.shown and #sounds==1, "/yaht feign didn't play it")
run(4)
-- switched off: never shows
db.feign=false YaHT:ApplySettings() feign() run(0.2) fire("UI_ERROR_MESSAGE",1,"Resisted") run(0.1)
assert(not a.shown, "shows although switched off")
db.feign=true run(4)

-- options: valid, with a working reset (also puts the alert back in the middle)
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local fa = opts.args.alerts.args.feignpage.args
assert(fa.feign and fa.feigntest and not fa.feignhitcheck and fa.reset, "Feign Death section incomplete (or still shows the dead health option)")
db.feignscale=2 fa.reset.func()
assert(db.feignscale==1 and db.feignpoint==nil, "reset didn't restore size and position")
print("OK29")
