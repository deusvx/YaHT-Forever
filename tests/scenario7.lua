local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
R:ValidateOptionsTable(R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0"), "YaHT")
local db=YaHT.db.profile local f=YaHT.mainFrame
local function tick(k,dt) for i=1,k do advance(dt) f.scripts.OnUpdate(f,dt) end end
db.lock=true YaHT:ApplySettings()
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.24, 2)
moving=true tick(100,0.01) print("moving mid-reload: centered", f.sparksCentered, "shown", f.sparks.LEFT.shown)
tick(100,0.01)
print("moving + ready: centered", f.sparksCentered, "shown", f.sparks.LEFT.shown, f.sparks.RIGHT.shown, "ignoreBarFade", f.sparkFrame.ignore, "bar alpha", f.alpha, "anchor", f.sparks.LEFT.point[2]==f, f.sparks.LEFT.point[4], f.sparks.RIGHT.point[4])
local lo,hi=1,0 for i=1,40 do tick(1,0.01) local a=f.sparkFrame.alpha lo=math.min(lo,a) hi=math.max(hi,a) end
print(string.format("pulse range %.2f-%.2f", lo, hi))
moving=false tick(1,0.01) print("stopped: centered", f.sparksCentered, "ignore", f.sparkFrame.ignore, "spark alpha", f.sparkFrame.alpha, "anchored to bar edge", f.sparks.LEFT.point[2]==f.texture)
tick(20,0.01) print("winding up: sparks shown", f.sparks.LEFT.shown)
db.sparkmode="OFF" moving=true tick(5,0.01) print("spark OFF but ready pulse:", f.sparks.LEFT.shown)
db.readypulse=false tick(1,0.01) print("both off:", f.sparks.LEFT.shown)
print("OK7")
