local ev = frames[1] -- event frame created first? find the one with PLAYER_LOGIN
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
print("hasCombatLog:", YaHT.hasCombatLog)
fire("PLAYER_LOGIN")
-- validate options table with the real AceConfigRegistry
local R = LibStub("AceConfigRegistry-3.0")
R:ValidateOptionsTable(R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0"), "YaHT")
print("options valid")
local db=YaHT.db.profile
db.lock = true
local f = YaHT.mainFrame
local function tick(n,dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f,dt) end end
fire("START_AUTOREPEAT_SPELL")
tick(10,0.1)
print("draw phase started:", f.SwingStart ~= nil, "width", f.texture.width)
fire("UNIT_SPELLCAST_SUCCEEDED","player","g",75)
print("after autoshot SwingStart nil:", f.SwingStart==nil, "lastshot", f.lastshot)
tick(10,0.1)
print("reload bar width (should shrink from 300):", f.texture.width)
-- aimed shot casting blocks draw phase
fire("UNIT_SPELLCAST_START","player","g",19434)
tick(30,0.1)
print("Forever default: casting does NOT hold, draw started:", f.SwingStart~=nil, f.casting)
fire("UNIT_SPELLCAST_SUCCEEDED","player","g",75) db.castholds=true tick(30,0.1) print("castholds on: SwingStart nil:", f.SwingStart==nil) db.castholds=false
fire("UNIT_SPELLCAST_SUCCEEDED","player","g",19434)
fire("UNIT_SPELLCAST_STOP","player","g",19434)
tick(1,0.1)
print("after aimed, draw started:", f.SwingStart~=nil, f.casting)
moving=true tick(3,0.1) print("moving alpha", f.alpha) moving=false
fire("UNIT_RANGEDDAMAGE","player")
print("newspeed", f.newspeed) fire("UNIT_SPELLCAST_SUCCEEDED","player","g",75) print("speed applied", f.speed)
SlashCmdList.YAHT("debug") fire("UNIT_SPELLCAST_SUCCEEDED","player","g",75) db.windup=0.65 tick(1,0.1) print("swingtime w/ 0.65:", f.swingtime)
db.tranqannounce=true db.tranqannouncefail=true
fire("UNIT_SPELLCAST_SUCCEEDED","player","g",19801)
fire("STOP_AUTOREPEAT_SPELL")
db.lock=false YaHT:ApplySettings() tick(50,0.1) print("unlocked mock ok, width", f.texture.width)
SlashCmdList.YAHT("")
for _,m in ipairs(sent) do print("SENT", m) end
print("OK")
if YaHT.hasCombatLog then
  CLEU={0,"SPELL_MISSED",false,"Player-1",nil,nil,nil,"Creature-1","Flamegor",nil,nil,19801,"Tranquilizing Shot"}
  fire("COMBAT_LOG_EVENT_UNFILTERED")
  for _,m in ipairs(sent) do print("SENT2", m) end
end
