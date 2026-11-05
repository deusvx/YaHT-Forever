local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
R:ValidateOptionsTable(R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0"), "YaHT")
print("options valid")
local db=YaHT.db.profile
local f=YaHT.mainFrame
local function tick(n,dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f,dt) end end
local function g() return string.format("%.2f", f.glow.alpha) end
print("glow pieces:", f.glow.pieces.TL ~= nil, "shown", f.glow.shown)
db.lock=true YaHT:ApplySettings()
fire("START_AUTOREPEAT_SPELL")
fire("PLAYER_SWING", 2.24, 2)  -- reload 1.84, windup 0.4
tick(1,0.001) io.write("start:",g(),"  ")
tick(46,0.01) io.write("25%:",g(),"  ")
tick(46,0.01) io.write("50%:",g(),"  ")
tick(46,0.01) io.write("75%:",g(),"  ")
tick(44,0.01) io.write("end reload:",g(),"  ")
tick(5,0.01) print("standing(pulse):",g(), "SwingStart", f.SwingStart~=nil)
db.glowpulse=false tick(1,0.01) print("standing no pulse:", g())
db.glowmode="STAND" fire("PLAYER_SWING", 2.24, 2) tick(100,0.01) print("STAND mode mid-reload:", g())
db.glow=false YaHT:ApplySettings() print("glow off shown:", f.glow.shown)
print("OK4")
