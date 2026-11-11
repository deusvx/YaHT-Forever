-- Quick Shots alert (1.2): Deadly Aspects talent buff, read from your buffs.
-- Shows while the buff lasts, its timer follows the buff, it catches refreshes
-- and the end, stays quiet (no errors) when the game hides buffs, and moves
-- aside when it shares a spot with the Mongoose Bite alert.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile local q=YaHT.quickShotsFrame local w=YaHT.quickShotsWatch
assert(q and w, "no Quick Shots alert")
assert(w.events.UNIT_AURA, "not watching buffs")
db.lock=true YaHT:ApplySettings()

local names = {[6150]="Quick Shots"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
local aura, byName, idCalls = nil, nil, 0
C_UnitAuras = {
  GetPlayerAuraBySpellID = function(id) idCalls=idCalls+1 assert(id==6150) return aura end,
  GetAuraDataBySpellName = function(unit, name, filter)
    assert(unit=="player" and name=="Quick Shots" and filter=="HELPFUL") return byName end,
}

local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w,dt) end
  if q.shown then q.scripts.OnUpdate(q,dt) end end end
local function fire() w.scripts.OnEvent(w,"UNIT_AURA","player") end
local function buff(left, len) local now=GetTime() return {expirationTime=now+left, duration=len or 12, icon="qsicon"} end

-- nothing up: one look per burst of events, then asleep
idCalls=0 for k=1,20 do fire() end run(0.05)
assert(not q.proc and idCalls==1, "a burst of buff events should be one check, got "..idCalls)
assert(not w.shown, "watcher should sleep while Quick Shots is down")
run(1) assert(idCalls==1, "checks while asleep")

-- proc: icon pops in, timer full, follows the buff's real time
aura = buff(12) fire() run(0.02)
assert(q.proc and q.shown, "no alert on Quick Shots")
assert(q.window==12 and math.abs(q.procStart-(GetTime()-0.02))<0.03, "timer not taken from the buff")
run(0.5) assert(q.alpha>0.99, "alert didn't fade in")
run(5.5) -- 6s into 12
local left=q.timer.width/db.procsize print(string.format("Quick Shots timer at 6s: %.0f%%", left*100))
assert(math.abs(left-0.5)<0.03, "timer not draining over the buff")

-- a new proc refreshes it: timer starts over
aura = buff(12) fire() run(0.02)
assert(q.timer.width/db.procsize > 0.98, "refresh not picked up")

-- buff ends with no event: the watcher's own check catches it
aura = nil run(0.3)
assert(not q.proc, "alert stuck after Quick Shots ended")
run(0.5) assert(not q.shown, "alert didn't go away") assert(not w.shown, "watcher still awake")

-- joined late (buff already 4s old): the timer starts at 8s left, not full
aura = buff(8) fire() run(0.02)
assert(math.abs(q.timer.width/db.procsize - 8/12)<0.03, "late proc should show the real time left")
aura=nil run(0.8)

-- game hides the time: assume 12s from now
aura = {expirationTime=SECRET, duration=SECRET, icon=SECRET} fire() run(0.02)
assert(q.proc and q.window==12, "hidden time should fall back to 12s")
aura=nil run(0.8)

-- game hides buffs entirely: quiet, no error, says so once in the debug log
YaHT.debug=true
aura = SECRET fire() run(0.1) fire() run(0.1)
assert(not q.proc, "secret buff data should keep it quiet")
YaHT.debug=false aura=nil
C_UnitAuras.GetPlayerAuraBySpellID=function() error("blocked") end fire() run(0.1)
assert(not q.proc, "blocked call should keep it quiet")
-- a new buff ID on Forever: found by name instead
C_UnitAuras.GetPlayerAuraBySpellID=function() return nil end
byName = buff(12) fire() run(0.02)
assert(q.proc, "not found by name")
byName=nil run(0.8)

-- Forever's own version: found in the buff list by name, whatever its spell number
local list = {}
C_UnitAuras.GetAuraDataByIndex = function(u, i, f) return list[i] end
C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
C_UnitAuras.GetAuraDataBySpellName = function() return nil end
local now=GetTime()
list = {{name="Aspect of the Hawk", spellId=13165}, {name="Quick Shots", spellId=1234567, expirationTime=now+12, duration=12, icon="qs"}}
YaHT.debug=true fire() run(0.05) YaHT.debug=false
assert(q.proc and q.window==12, "Quick Shots with a new spell number not found in the buff list")
local log=YaHT.db.global.debuglog
local seen=false for i=#log-3,#log do if log[i] and log[i]:find("Quick Shots on, from buff %[Quick Shots, spell 1234567%]") then seen=true end end
assert(seen, "debug log should say what the buff looked like")
list = {} run(0.8) assert(not q.proc, "didn't end")
list = {{name="Improved Quick Shots", spellId=7654321}} fire() run(0.05)
assert(q.proc, "a renamed Quick Shots not recognised")
list = {} run(0.8)
-- /yaht buffs lists what the game shows
list = {{name="Battle Shout", spellId=6673}, {name="Quick Shots", spellId=1234567, duration=12, expirationTime=GetTime()+12}}
YaHT.debug=true SlashCmdList["YAHT"]("buffs") YaHT.debug=false
local lines = {} for i=#log-2,#log do lines[#lines+1]=log[i] or "" end
print("buffs:", table.concat(lines, " || "))
list = {} run(0.8)
C_UnitAuras.GetAuraDataByIndex = nil

-- buffs hidden in combat (Midnight rules): Quick Shots is worked out from shot speed
C_UnitAuras = {GetPlayerAuraBySpellID=function() return SECRET end, GetAuraDataBySpellName=function() return SECRET end}
local spd = YaHT.quickSpeed
spd.base=nil spd.fast=false spd.rapidUntil=0 spd.otherUntil=0
local function swing(d) w.scripts.OnEvent(w, "PLAYER_SWING", d, 2) end
local function cast(id) w.scripts.OnEvent(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", id) end
-- a real shot: the game says how long until the next one, and that's when it comes
local function shot(d, gap) swing(d) run(gap or d) end
local N = 2.636
for k=1,4 do shot(N) end
assert(not q.proc and math.abs(spd.base-N)<0.01, "normal shots shouldn't show it")
local procAt = GetTime() shot(N/1.3, 0.05) -- this shot came with a 30% faster next swing
assert(q.proc, "Quick Shots not noticed from the faster shot")
assert(math.abs(q.procStart-(procAt-N))<0.06, "timer should start at the shot it procced on (the one before the first fast one)")
run(N/1.3-0.05) for k=1,3 do shot(N/1.3) end
assert(q.proc, "dropped while still fast")
shot(N, 0.3) -- back to normal speed
assert(not q.proc, "still shown after the speed went back to normal")
run(N-0.3)
-- a client where the game's number doesn't change, but shots really come sooner: still noticed
spd.durationWorks=false shot(N) shot(N, N/1.3) swing(N) run(0.05)
assert(q.proc, "not noticed from the real time between shots")
run(N) shot(N) shot(N) run(0.3) assert(not q.proc, "gap-based alert stuck")
spd.durationWorks=true
-- Forever's version may not be exactly 30%: a 25% speed-up also counts
shot(N) shot(N/1.25, 0.05) assert(q.proc, "a 25% speed-up not counted") run(N/1.25) shot(N) shot(N) run(0.3)
-- Rapid Fire alone (40%) is not Quick Shots ...
cast(3045) shot(N) shot(N/1.4) shot(N/1.4, 0.3)
assert(not q.proc, "Rapid Fire mistaken for Quick Shots")
run(N/1.4-0.3)
-- ... but Quick Shots during Rapid Fire is
shot(N/1.4/1.3, 0.3)
assert(q.proc, "Quick Shots during Rapid Fire not noticed")
spd.rapidUntil=0 run(N/1.4/1.3) shot(N) shot(N, 0.3) assert(not q.proc, "didn't end after Rapid Fire + Quick Shots")
run(N)
-- a Rapid Fire YaHT didn't see cast (exactly 40%) isn't taken for Quick Shots
shot(N) shot(N/1.4, 0.3) assert(not q.proc, "an unseen Rapid Fire counted as Quick Shots") run(N/1.4) shot(N) shot(N)
-- Berserking: unknown speed-up, don't guess
cast(26296) shot(N/1.3, 0.3) assert(not q.proc, "guessed during Berserking")
spd.otherUntil=0 run(N/1.3) shot(N) shot(N)
-- stopped shooting while fast (like in the owner's log): gone when its 12s are up, not later
local procShot=GetTime() shot(N) shot(N/1.3, 0.1) assert(q.proc) -- procced on the first of these two shots
run(12 - (GetTime()-procShot) - 0.3) assert(q.proc, "ended before its 12 seconds")
run(0.6) assert(not q.proc and not spd.fast, "stayed after its 12 seconds although you stopped shooting")
run(1)
-- still shooting fast after 12s: that's a new proc, the timer starts over
shot(N) shot(N/1.3) for k=1,6 do shot(N/1.3) end -- about 12s of fast shots
assert(q.proc, "a new proc right after the first one was missed")
shot(N) shot(N, 0.3) assert(not q.proc) run(N)
-- replay of the owner's fight (log 770011-770026): proc on the 770011.115 shot, stopped shooting at
-- 770019.188. The alert must end 12s after the proc shot (770023.1), with no false "refresh".
run(20) spd.base=2.589 spd.fast=false spd.durationWorks=true spd.lastShot=nil
local t0=GetTime()
swing(2.589) run(3.685) swing(1.992) run(2.016) swing(1.992) run(2.058) swing(1.992)
assert(q.proc, "replay: Quick Shots not shown")
local refreshed=false
local function until_(t) while GetTime()-t0 < t do run(0.05) if math.abs(q.procStart-t0)>0.01 then refreshed=true end end end
until_(11.9) assert(q.proc, "replay: ended early")
until_(12.3) assert(not q.proc, "replay: still shown after the 12s (the old bug)")
assert(not refreshed, "replay: falsely refreshed")
run(1)
-- moving (late shots) and small changes (gear, a slow) are not Quick Shots
shot(N, 3.5) shot(N*0.97) shot(N) run(0.3) assert(not q.proc, "late shots or a 3% change triggered it")
spd.base=nil

-- placement: both alerts on the same spot sit side by side
db.mongoosepos="RIGHT" db.quickshotspos="RIGHT" YaHT:ApplySettings()
assert(q.point[1]=="LEFT" and q.point[4]==6+db.procsize+2+6, "Quick Shots should move over next to Mongoose Bite")
db.quickshotspos="LEFT" YaHT:ApplySettings()
assert(q.point[1]=="RIGHT" and q.point[4]==-6, "different spots: no shift")
db.mongoosepos="ABOVE" db.quickshotspos="ABOVE" YaHT:ApplySettings()
assert(q.point[1]=="BOTTOM" and q.point[4]==db.procsize+2+6, "above: should sit beside Mongoose Bite")
db.mongoose=false YaHT:ApplySettings()
assert(q.point[4]==0, "Mongoose Bite off: Quick Shots takes the middle")
db.mongoose=true db.mongoosepos="ABOVE" db.quickshotspos="RIGHT" YaHT:ApplySettings()

-- switched off: never shows
db.quickshots=false YaHT:ApplySettings()
aura = buff(12) fire() run(0.3)
assert(not q.proc and not q.shown, "shows although switched off")
db.quickshots=true aura=nil run(0.5)

-- options: a Procs section with both alerts; Melee no longer has Mongoose Bite
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local pa = opts.args.alerts.args.procspage.args
assert(pa.quickshots and pa.procglow and pa.mongoose and pa.procpulse and pa.reset and pa.quickshotspage and pa.mongoosepage, "Procs section incomplete")
assert(not opts.args.alerts.args.meleepage.args.mongoose, "Mongoose Bite still on the Melee page")
db.procglow="RING" db.procsize=40 pa.reset.func()
assert(db.procglow=="HALO" and db.procsize==30, "Procs reset didn't restore defaults")

-- unlocked: preview loops so you can place it
db.lock=false YaHT:ApplySettings() run(0.5)
assert(q.shown and q.alpha>0.9, "no preview while unlocked")
print("OK27")
