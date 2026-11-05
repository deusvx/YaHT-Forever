local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
R:ValidateOptionsTable(R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0"), "YaHT")
print("options valid; nativeSwing", YaHT.hasNativeSwing, "combatlog", YaHT.hasCombatLog)
local db=YaHT.db.profile db.lock=true
local f=YaHT.mainFrame
local function tick(n,dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f,dt) end end
SlashCmdList.YAHT("debug")
fire("START_AUTOREPEAT_SPELL")
-- hasted swing: 2.24s on a 2.80 bow (25% haste) -> windup 0.4
fire("PLAYER_SWING", 2.24, 2)
print("speed", f.speed, "swingtime(after tick)") tick(1,0.01) print(f.swingtime)
fire("PLAYER_SWING", 1.9, 0) print("melee swing ignored, speed still", f.speed)
-- the fallback path must not double-trigger
local before=f.lastshot advance(0.3) fire("UNIT_SPELLCAST_SUCCEEDED","player","g",75) print("spellcast ignored with native swing:", f.lastshot==before)
-- combat: stats hidden
hideStats=true
tick(300,0.01)
fire("PLAYER_SWING", SECRET, 2)
fire("UNIT_RANGEDDAMAGE","player")
fire("UNIT_SPELLCAST_SUCCEEDED","player","g",19801)
tick(100,0.01)
print("survived secret values; draw started:", f.SwingStart~=nil)
hideStats=false
db.windupauto=false db.windup=0.65 tick(1,0.01) print("manual windup swingtime", f.swingtime)
print("OK2")
