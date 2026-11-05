local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame local a=YaHT.ammoFrame
db.lock=true YaHT:ApplySettings()
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.273, 2)
local N=60000
collectgarbage() collectgarbage() local m0=collectgarbage("count") local t0=os.clock()
for i=1,N do advance(1/60) f.scripts.OnUpdate(f,1/60) if i%137==0 then fire("PLAYER_SWING", 2.273, 2) end end
local bar=(os.clock()-t0)/N*1e6 local garb=(collectgarbage("count")-m0)/N*1024
t0=os.clock() for i=1,N do advance(1/60) a.scripts.OnUpdate(a,1/60) end local am=(os.clock()-t0)/N*1e6
print(string.format("bar (all effects on), per frame: %.1f microseconds, %.0f bytes garbage", bar, garb))
print(string.format("ammo icon, per frame: %.1f microseconds", am))
print("OK18")
