local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
R:ValidateOptionsTable(R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0"), "YaHT")
print("options valid")
local db=YaHT.db.profile local a=YaHT.ammoFrame
db.lock=true YaHT:ApplySettings()
local function step(n) for i=1,(n or 1) do advance(0.05) a.scripts.OnUpdate(a,0.05) end end
local function set(c) AMMO.count=c a.dirty=true step(1) end
set(1500) print("1500 (plenty):", "alpha", a.alpha, "text", a.text.txt, "icon", a.icon.texture or "?")
set(800) print("800 (fade start):", string.format("%.2f", a.alpha))
set(500) print("500:", string.format("%.2f", a.alpha))
set(250) print("250:", string.format("%.2f", a.alpha))
set(200) local lo,hi=1,0 for i=1,30 do step() lo=math.min(lo,a.alpha) hi=math.max(hi,a.alpha) end
print(string.format("200 LOW: flash %.2f-%.2f color %.2f,%.2f,%.2f sounds %d", lo, hi, a.text.tcolor[1], a.text.tcolor[2], a.text.tcolor[3], #sounds))
set(150) print("150 still low, no repeat sound:", #sounds)
set(40) print("40 CRIT: color", a.text.tcolor[1], a.text.tcolor[2], "sounds", #sounds, "last", sounds[#sounds])
set(1000) print("restocked 1000: alpha", a.alpha, "color", a.text.tcolor[2]) set(190) print("drop to low again -> sound re-armed:", #sounds)
-- bag mode (no ammo slot)
AMMO.slotID=nil AMMO.bags={[0]={{2512,200},{999,1},{2512,150}}, [1]={{3030,200}}} a.dirty=true step()
print("bag mode (arrows only):", a.text.txt, select(3, YaHT:ReadAmmo()))
-- gun -> bullets
AMMO.weaponSub=3 a.dirty=true step() print("gun -> bullets:", a.text.txt)
-- thrown / wand -> hidden
AMMO.weaponSub=16 a.dirty=true step() print("thrown: count", a.count, "alpha", a.alpha)
AMMO.weaponSub=2 AMMO.noweapon=true a.dirty=true step() print("no weapon:", select(3, YaHT:ReadAmmo()))
AMMO.noweapon=nil
-- unlocked: visible + draggable
db.lock=false YaHT:ApplySettings() a.dirty=true step() print("unlocked: alpha", a.alpha, "mouse", a.mouse)
db.ammo=false YaHT:ApplySettings() print("ammo off shown:", a.shown)
SlashCmdList.YAHT("ammo")
print("OK9")
