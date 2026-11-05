local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
R:ValidateOptionsTable(R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0"), "YaHT")
print("options valid")
local db=YaHT.db.profile local f=YaHT.mainFrame
local function tick(k,dt) for i=1,k do advance(dt) f.scripts.OnUpdate(f,dt) end end
db.lock=true YaHT:ApplySettings()
print("spark anchors:", f.sparks.LEFT.point[1], f.sparks.LEFT.point[3], f.sparks.RIGHT.point[3], "size", f.sparks.RIGHT.w, f.sparks.RIGHT.h)
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.24, 2)
tick(100,0.01) print("reload: sparks", f.sparks.LEFT.shown, f.sparks.RIGHT.shown, "sweep", f.sweep.shown)
tick(95,0.01) print("standing: sparks", f.sparks.LEFT.shown, f.sparks.RIGHT.shown, "bar width", string.format("%.0f",f.texture.width))
db.fill=false tick(1,0.01) print("fill-left: sparks", f.sparks.LEFT.shown, f.sparks.RIGHT.shown) db.fill=true
db.sparkmode="ALWAYS" fire("PLAYER_SWING", 2.24, 2) tick(50,0.01) print("ALWAYS during reload:", f.sparks.RIGHT.shown)
db.sparkmode="OFF" tick(1,0.01) print("OFF:", f.sparks.RIGHT.shown)
db.glowstyle="SWEEP" tick(150,0.01) print("sweep standing:", f.sweep.shown, "pos", string.format("%.0f", f.sweep.point[4]))
tick(10,0.01) print("sweep moved to", string.format("%.0f", f.sweep.point[4]))
fire("PLAYER_SWING", 2.24, 2) tick(1,0.01) print("sweep after shot:", f.sweep.shown)
db.glowlook="OUTLINE" YaHT:ApplySettings() print("outline shown", f.glow.outline.T.shown, "soft shown", f.glow.pieces.TL.shown)
db.glow=false YaHT:ApplySettings() tick(200,0.01) print("glow off: sweep", f.sweep.shown)
db.lock=false YaHT:ApplySettings() db.sparkmode="STAND" tick(300,0.01) print("unlocked demo ok")
print("OK6")
