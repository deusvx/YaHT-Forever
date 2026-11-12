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
-- "Resisted" arriving just BEFORE the cast is confirmed (seen in game: the alert was 2.5s late)
run(6) feigned=false sounds = {}
assert(not a.shown and not w.active, "setup: quiet before the early-message tests")
fire("UI_ERROR_MESSAGE", 1, "Resisted") assert(not a.shown, "a stray Resisted message alone must not alert")
feign() run(0.05)
assert(a.shown and w.resisted and #sounds == 1, "Resisted just before the cast wasn't alerted at once")
run(6) feigned=false
-- ... or right after the key press, with the cast confirmed later or never
fire("UNIT_SPELLCAST_SENT", "player", "target", "guid", 5384)
fire("UI_ERROR_MESSAGE", 1, "Resisted") run(0.05)
assert(a.shown and #sounds == 2, "Resisted right after pressing Feign Death wasn't alerted at once")
feign() run(3.5)
assert(#sounds == 2, "alerted twice for one resisted feign")
run(6) feigned=false
-- a Resisted message long before a feign has nothing to do with it
fire("UI_ERROR_MESSAGE", 1, "Resisted") run(2) feign() run(0.5)
assert(not w.resisted and #sounds == 2, "an old Resisted message was pinned on a later feign")
run(6) feigned=false

-- THREAT (measured in game: readable in a fight; a working feign drops you off the list within
-- about a second, a resisted one doesn't, and the game may send no "Resisted" message at all)
local threat = 3
function UnitThreatSituation() return threat end
sounds = {}
-- resisted: still on the list -> alerted after 1.25s, not 2.5s
targetOnYou = true feign() run(1.15)
assert(not w.resisted and not a.shown, "the threat check fired too early")
run(0.2)
assert(w.resisted and a.shown and #sounds == 1, "still on the threat list should alert after about 1.25s")
run(6) feigned = false
-- worked: you drop off the list -> no alert, even if the mob is still looking your way for a moment
feign() run(0.5) threat = nil run(3)
assert(not w.resisted and #sounds == 1 and w.threatGone and w.threatGone < 0.65, "a feign that took you off the threat list was called resisted")
run(4) feigned = false threat = 3
-- the mob never had you on its list (pet was tanking, no target): fall back to the old check
threat = nil targetOnYou = true feign() run(2.0)
assert(not w.resisted, "without threat to read the alert should wait for the target check")
run(0.7) assert(w.resisted and #sounds == 2, "the target check should still work when threat can't tell")
run(6) feigned = false
-- threat the game hides: also the old check; and the new check can be switched off
threat = SECRET feign() run(2.0) assert(not w.resisted, "a hidden threat value was taken for something")
run(4.5) feigned = false threat = 3
db.feignthreatcheck = false feign() run(1.6) assert(not w.resisted, "the threat check ignores its switch")
run(5) feigned = false db.feignthreatcheck = true targetOnYou = false
function UnitThreatSituation() return nil end

-- a message the game repeats every frame is written down once a feign, not a hundred times
targetOnYou = false feign()
for i = 1, 100 do fire("UI_ERROR_MESSAGE", 57, "Target too close") end
fire("UI_ERROR_MESSAGE", 58, "Out of range.")
local close, far = 0, 0
for _, l in ipairs(YaHT.db.global.fdlog) do
  if l:find("Target too close", 1, true) then close = close + 1 end
  if l:find("Out of range", 1, true) then far = far + 1 end
end
assert(close == 1 and far == 1, "repeated messages flooded the record: " .. close .. " / " .. far)
run(4) feigned = false
feign() fire("UI_ERROR_MESSAGE", 57, "Target too close") run(4) feigned = false
close = 0 for _, l in ipairs(YaHT.db.global.fdlog) do if l:find("Target too close", 1, true) then close = close + 1 end end
assert(close == 2, "the next feign should write the message down again")

-- the last feigns are always written down (debug off), so a late alert can be looked into
local fd = YaHT.db.global.fdlog
assert(not YaHT.debug and fd and #fd > 10 and #fd <= 150, "no record of the last feigns")
local resisted, threat = false, false
for _, line in ipairs(fd) do
  if line:find("RESISTED", 1, true) then resisted = true end
  if line:find("threat", 1, true) then threat = true end
  assert(not line:find("health", 1, true) or line:find("cast |", 1, true), "chatty health lines kept: "..line)
end
assert(resisted and threat, "the record misses the resist or the threat looks")
print("OK29")
