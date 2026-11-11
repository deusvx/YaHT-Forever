-- Rapid Fire and the racial alert (1.2): shown from the moment you cast them,
-- for their length, lined up next to Quick Shots. The racial alert knows every
-- race's active (by Classic number or name) and learns new ones' lengths.
local names = {[3045]="Rapid Fire", [6150]="Quick Shots", [990001]="Elune's Light", [19434]="Aimed Shot", [20572]="Blood Fury", [20594]="Stoneform", [990002]="Skysight"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
C_Spell.GetSpellInfo = function(n) if n=="Elune's Light" then return {spellID=990001, iconID="eluneicon"} end end
C_Spell.GetSpellTexture = function(id) return "icon"..tostring(id) end

local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile local r=YaHT.rapidFireFrame local e=YaHT.racialFrame local w=YaHT.castBuffWatch
assert(r and e and w, "no Rapid Fire / racial alerts")
assert(r.icon.tex=="icon3045", "Rapid Fire should use its own icon")
assert(e.icon.tex=="eluneicon", "the racial preview should use your race's icon from the spellbook")
db.lock=true YaHT:ApplySettings()

local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w,dt) end
  if r.shown then r.scripts.OnUpdate(r,dt) end
  if e.shown then e.scripts.OnUpdate(e,dt) end end end
local function cast(id) w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", id) end

-- other spells: nothing
cast(19434) run(0.3) assert(not r.shown and not e.shown, "shown for another spell")

-- Rapid Fire: shows at once, timer from the cast, gone after 15s
local t0=GetTime() cast(3045) run(0.3)
assert(r.proc and r.shown and r.alpha>0.99 and math.abs(r.procStart-t0)<0.02 and r.window==15, "Rapid Fire not shown from the cast")
run(7.2) local left=r.timer.width/db.procsize
assert(math.abs(left-0.5)<0.03, "Rapid Fire timer not draining over 15s")
run(7.6) assert(not r.proc, "Rapid Fire stayed past 15s") run(0.5) assert(not r.shown, "Rapid Fire icon didn't go away")
assert(not w.shown, "watcher should sleep when nothing is up")

-- Elune's Light: same, with its own icon
cast(990001) run(0.3)
assert(e.proc and e.shown and e.icon.tex=="icon990001" and e.window==15, "Elune's Light not shown")
run(15) assert(not e.proc, "Elune's Light stayed past 15s") run(0.5)

-- other Hunter races: Blood Fury (Orc) 15s, Stoneform (Dwarf) 8s, by their Classic spell numbers;
-- Undead / Gnome racials (not Hunter races) are ignored
names[7744]="Will of the Forsaken" cast(7744) run(0.2) assert(not e.proc, "a non-Hunter racial was shown")
cast(20572) run(0.2) assert(e.proc and e.window==15 and e.icon.tex=="icon20572", "Blood Fury not shown") run(15.2) assert(not e.proc)
cast(20594) run(0.2) assert(e.proc and e.window==8, "Stoneform not shown for 8s") run(8.2) assert(not e.proc, "Stoneform stayed past 8s") run(0.5)
-- a new Forever racial with no known length (Skysight): a 10s guess, then the real length is
-- read from the buff (out of combat) and remembered for next time
C_UnitAuras = {GetAuraDataBySpellName=function(u,n) if n=="Skysight" then return {duration=12} end end}
cast(990002) run(0.5) assert(e.proc and e.window==12, "new racial's length not learned from the buff")
assert(YaHT.db.global.racialLength["Skysight"]==12, "learned length not remembered")
run(12) assert(not e.proc) run(0.5)
C_UnitAuras = {GetAuraDataBySpellName=function() return SECRET end} -- in combat: hidden
cast(990002) run(0.5) assert(e.window==12, "should use the remembered length when the buff is hidden") run(12.5)
C_UnitAuras = nil
-- recast during: the timer starts over
cast(3045) run(5) local t1=GetTime() cast(3045) run(0.1)
assert(math.abs(r.procStart-t1)<0.02, "recast didn't restart the timer") run(16)

-- all three on the right: Quick Shots, then Rapid Fire, then Elune's Light, side by side
db.mongoosepos="ABOVE" db.quickshotspos="RIGHT" db.rapidfirepos="RIGHT" db.racialpos="RIGHT" YaHT:ApplySettings()
assert(r.point[1]=="LEFT" and r.point[4]==6+(db.procsize+2+6), "Rapid Fire should sit past Quick Shots")
assert(e.point[4]==6+(db.procsize+2+6)+(db.procsize+2+6), "the racial icon should sit past both")
db.quickshots=false YaHT:ApplySettings()
assert(r.point[4]==6, "Quick Shots off: Rapid Fire takes its place")
db.quickshots=true YaHT:ApplySettings()

-- switched off: never shows
db.rapidfire=false db.racial=false YaHT:ApplySettings()
cast(3045) cast(990001) run(0.3) assert(not r.shown and not e.shown, "shown although switched off")
db.rapidfire=true db.racial=true run(16)

-- options: both in the Procs section, valid
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local pa = opts.args.alerts.args.procspage.args
assert(pa.rapidfire and pa.rapidfirepage and pa.racial and pa.racialpage, "Rapid Fire / racial settings missing")
db.racialpos="LEFT" pa.reset.func() assert(db.racialpos=="RIGHT", "Procs reset didn't cover the racial alert")

-- unlocked: previews so you can place them
db.lock=false YaHT:ApplySettings() run(0.3)
assert(r.shown and e.shown, "no preview while unlocked")
print("OK32")
