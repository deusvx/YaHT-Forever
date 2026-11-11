-- Aspect badge (1.2): the icon of your current aspect next to the bar. Quiet
-- while fine, red + pulsing for Cheetah/Pack in a fight or no aspect, an
-- optional yellow hint (Hawk in melee, Monkey at range), quiet when hidden.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile local b=YaHT.aspectFrame local w=YaHT.aspectWatch
assert(b and w, "no aspect badge")
db.lock=true YaHT:ApplySettings()

local names = {[13165]="Aspect of the Hawk",[13163]="Aspect of the Monkey",[5118]="Aspect of the Cheetah",
  [13159]="Aspect of the Pack",[13161]="Aspect of the Beast",[20043]="Aspect of the Wild"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellTexture = function(id) return "icon"..id end
local current, calls = "Aspect of the Hawk", 0
C_UnitAuras = {GetAuraDataBySpellName = function(unit, name, filter)
  calls = calls + 1
  if current == SECRET then return SECRET end
  if name == current then return {icon = "buff:"..name} end
end}
local inCombat = false
function InCombatLockdown() return inCombat end
local main = YaHT.mainFrame

local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w,dt) end
  if b.shown then b.scripts.OnUpdate(b,dt) end end end
local function fire(e) w.scripts.OnEvent(w, e, "player") end
local function red() return math.abs(b.rim.color[1]-1)<1e-6 and math.abs(b.rim.color[2]-0.22)<1e-6 end
local function yellow() return math.abs(b.rim.color[2]-0.8)<1e-6 end

-- out of combat, not shooting: knows the aspect but shows nothing
fire("PLAYER_ENTERING_WORLD") run(0.5)
assert(b.aspect=="HAWK" and b.drawnTex=="buff:Aspect of the Hawk", "aspect not read (should use the buff's own icon)")
assert(not b.shown, "badge shows out of combat")
-- reading only happens on buff changes, not every frame
calls=0 run(2) assert(calls==0, "aspect read while nothing changed")

-- start shooting: quiet badge at the idle opacity
main.shooting=true fire("START_AUTOREPEAT_SPELL") run(0.5)
assert(b.shown and math.abs(b.alpha-db.aspectalpha)<1e-6 and not b.halo.shown, "quiet badge while shooting in Hawk")

-- a fight in Cheetah: red, full strength, pulsing
inCombat=true fire("PLAYER_REGEN_DISABLED")
current="Aspect of the Cheetah" fire("UNIT_AURA") run(0.3)
assert(b.aspect=="CHEETAH" and red() and b.halo.shown and math.abs(b.alpha-1)<1e-6, "no red warning for Cheetah in a fight")
local lo,hi=1,0 for k=1,50 do run(0.02) lo=math.min(lo,b.icon.alpha) hi=math.max(hi,b.icon.alpha) end
assert(hi-lo>0.2, "warning doesn't pulse")
-- Pack too
current="Aspect of the Pack" fire("UNIT_AURA") run(0.2) assert(b.aspect=="PACK" and red(), "no warning for Pack")
-- switched off: Pack is just shown quietly
db.aspectwarnspeed=false run(0.2) assert(not red() and not b.halo.shown, "Cheetah/Pack warning ignores its setting")
db.aspectwarnspeed=true

-- no aspect in a fight: red question mark
current=nil fire("UNIT_AURA") run(0.2)
assert(b.aspect=="NONE" and red() and b.drawnTex:find("QuestionMark"), "no warning without an aspect")
-- back to Hawk: quiet again
current="Aspect of the Hawk" fire("UNIT_AURA") run(0.3)
assert(not red() and not b.halo.shown, "warning stuck after switching to Hawk")

-- yellow hint (off by default): Hawk while in melee
YaHT.meleeFrame.position="MELEE" run(0.2) assert(not yellow(), "hint shows although switched off")
db.aspecthint=true run(0.2) assert(yellow() and b.halo.shown, "no hint for Hawk in melee")
current="Aspect of the Monkey" fire("UNIT_AURA") run(0.2) assert(not yellow(), "Monkey in melee should be fine")
YaHT.meleeFrame.position="OK" run(0.2) assert(yellow(), "no hint for Monkey while shooting at range")
db.aspecthint=false YaHT.meleeFrame.position=nil current="Aspect of the Hawk" fire("UNIT_AURA") run(0.2)

-- game hides buffs (in combat on Forever): keep the last aspect seen, no error
current=SECRET fire("UNIT_AURA") run(0.6)
assert(b.aspect=="HAWK" and b.shown, "should keep showing the last known aspect when buffs are hidden")
-- casting an aspect while buffs are hidden is still noticed: Cheetah mid-fight turns red
w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", 5118) run(0.3)
assert(b.aspect=="CHEETAH" and red() and b.drawnTex=="icon5118", "Cheetah cast in combat not noticed")
-- other spells don't change it
w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", 75) run(0.2) assert(b.aspect=="CHEETAH")
w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", 13165) run(0.3)
assert(b.aspect=="HAWK" and not red(), "switching back to Hawk in combat not noticed")
C_UnitAuras.GetAuraDataBySpellName=function() error("blocked") end fire("UNIT_AURA") run(0.3)
assert(b.aspect=="HAWK", "a blocked call should keep the last aspect")
C_UnitAuras.GetAuraDataBySpellName=function(u,n) if n==current then return {icon="buff:"..n} end end
current="Aspect of the Hawk" fire("UNIT_AURA") run(0.3)

-- fight over, Auto Shot off: hides
inCombat=false fire("PLAYER_REGEN_ENABLED") main.shooting=false fire("STOP_AUTOREPEAT_SPELL") run(0.6)
assert(not b.shown, "badge stays after the fight")
-- "Always": shows out of combat too
db.aspectwhen="ALWAYS" fire("UNIT_AURA") run(0.3) assert(b.shown and b.alpha>0.5, "always mode hidden out of combat")
db.aspectwhen="COMBAT" run(0.6) assert(not b.shown, "combat mode shows out of combat")

-- placement: lines up with the other icons on the same spot
db.mongoosepos="LEFT" db.quickshotspos="LEFT" db.aspectpos="LEFT" YaHT:ApplySettings()
local want = -6 - (db.procsize+2+6) - (db.procsize+2+6)
assert(b.point[1]=="RIGHT" and b.point[4]==want, "aspect badge should sit past both proc icons, got "..tostring(b.point[4]))
db.mongoosepos="ABOVE" db.quickshotspos="RIGHT" YaHT:ApplySettings()
assert(b.point[4]==-6, "alone on its side: no shift")

-- switched off
db.aspect=false YaHT:ApplySettings() inCombat=true fire("PLAYER_REGEN_DISABLED") run(0.3)
assert(not b.shown, "shows although switched off")
db.aspect=true

-- Cheetah / Pack show any time (also out of combat), quietly; red once a fight starts
inCombat=false fire("PLAYER_REGEN_ENABLED") main.shooting=false
current="Aspect of the Cheetah" fire("UNIT_AURA") run(0.4)
assert(b.shown and b.alpha>0.5 and not red(), "Cheetah should show (quietly) out of combat")
inCombat=true fire("PLAYER_REGEN_DISABLED") run(0.2) assert(red(), "Cheetah not red when the fight starts")
inCombat=false fire("PLAYER_REGEN_ENABLED") db.aspectspeedalways=false run(0.6)
assert(not b.shown, "Cheetah out of combat should hide when that option is off")
db.aspectspeedalways=true current="Aspect of the Hawk" fire("UNIT_AURA") run(0.6)

-- Forever may differ from Classic: find the aspect in the buff list ...
local buffs = {}
C_UnitAuras.GetAuraDataByIndex = function(u, i, f) assert(u=="player" and f=="HELPFUL") return buffs[i] end
C_UnitAuras.GetAuraDataBySpellName = function() return nil end
main.shooting=true
buffs = {{name="Battle Shout", spellId=6673, icon="x"}, {name="Aspect of the Monkey", spellId=987654, icon="realmonkey"}}
fire("UNIT_AURA") run(0.3)
assert(b.aspect=="MONKEY" and b.drawnTex=="realmonkey", "aspect with a new spell number not found by its name")
-- ... by a Classic rank number
buffs = {{name=SECRET, spellId=14322, icon="hawk8"}} fire("UNIT_AURA") run(0.2)
assert(b.aspect=="HAWK" and b.drawnTex=="hawk8", "aspect not found by its rank number")
-- ... by the word in a name YaHT has never seen
buffs = {{name="Improved Aspect of the Cheetah", spellId=555555, icon="ch"}} fire("UNIT_AURA") run(0.2)
assert(b.aspect=="CHEETAH", "aspect not recognised from its name")
buffs = {{name="Aspect of the Dragonhawk", spellId=444444, icon="dh"}} fire("UNIT_AURA") run(0.2)
assert(b.aspect=="DRAGONHAWK", "Dragonhawk mistaken for Hawk")
-- ... or on the stance bar
buffs = {}
function GetNumShapeshiftForms() return 2 end
function GetShapeshiftFormInfo(i) if i==1 then return "s1", false, true, 13165 else return "stanceicon", true, true, 13163 end end
fire("UNIT_AURA") run(0.2)
assert(b.aspect=="MONKEY" and b.drawnTex=="stanceicon", "aspect on the stance bar not found")
-- nothing anywhere: "none", and the debug log lists what it saw
function GetShapeshiftFormInfo(i) return "s", false, true, 13165 end
YaHT.debug=true buffs = {{name="Battle Shout", spellId=6673, icon="x"}} fire("UNIT_AURA") run(0.2) YaHT.debug=false
assert(b.aspect=="NONE", "should be none")
local log=YaHT.db.global.debuglog local last=log[#log]
print("debug line:", last)
assert(last:find("Battle Shout%(6673%)") and last:find("stances: 13165"), "debug log doesn't list what it saw")
GetNumShapeshiftForms=nil GetShapeshiftFormInfo=nil C_UnitAuras.GetAuraDataByIndex=nil
C_UnitAuras.GetAuraDataBySpellName=function(u,n) if n==current then return {icon="buff:"..n} end end
main.shooting=false fire("UNIT_AURA") run(0.6)

-- options: own Aspect section, valid, with a working reset
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local aa = opts.args.alerts.args.aspectpage.args
assert(aa.aspect and aa.aspectwarnspeed and aa.aspecthint and aa.reset, "Aspect section incomplete")
db.aspectsize=40 db.aspecthint=true aa.reset.func()
assert(db.aspectsize==22 and db.aspecthint==false, "Aspect reset didn't restore defaults")

-- unlocked: preview
inCombat=false db.lock=false YaHT:ApplySettings() run(0.3)
assert(b.shown and b.alpha>0.5, "no preview while unlocked")
print("OK28")
