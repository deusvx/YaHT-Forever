-- Quick Strikes: the melee twin of Quick Shots (Deadly Aspects under Aspect of the Beast): +30% melee
-- attack speed for 12 seconds. In a fight your buffs are hidden, so it is told from your main hand's
-- swings coming 30% faster; out of a fight from the buff itself.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local NORMAL = 2.80
local inFight, buffEnds = false, nil
function UnitAttackSpeed() if inFight then return SECRET end return NORMAL end
function UnitAffectingCombat() return inFight end
local function buff()
  if inFight then return SECRET end
  if not buffEnds or GetTime() >= buffEnds then return nil end
  return {spellId = 1299999, name = "Quick Strikes", expirationTime = buffEnds, duration = 12}
end
C_UnitAuras = {GetAuraDataBySpellName = function(u, name) if name == "Quick Strikes" then return buff() end return nil end,
  GetPlayerAuraBySpellID = function() return nil end}
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db=YaHT.db.profile local q=YaHT.quickStrikesFrame local w=YaHT.quickStrikesWatch
local strike = YaHT.strikeSpeed
assert(q and w and db.quickstrikes == true, "the Quick Strikes icon should be there, and on")
db.lock=true db.procsound=true YaHT:ApplySettings()
local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w,dt) end
  if q.shown then q.scripts.OnUpdate(q,dt) end end end
local function swing(d, hand) w.scripts.OnEvent(w,"PLAYER_SWING", d, hand or 0) run(0.05) end
local function fight(on) if on then w.scripts.OnEvent(w, "PLAYER_REGEN_DISABLED") inFight = true else inFight = false w.scripts.OnEvent(w, "PLAYER_REGEN_ENABLED") end end

YaHT.aspectFrame.aspect = "BEAST"
-- 1) a fight: normal swings, then one 30% faster -> the icon, for its 12 seconds
fight(true)
assert(strike.seed == NORMAL, "the normal swing speed should be read before the fight")
swing(NORMAL) run(2.8) swing(NORMAL) assert(not q.proc, "normal swings must not show it")
run(2.8) swing(NORMAL / 1.3)
assert(q.proc, "a swing 30% faster should show Quick Strikes")
run(2.1) swing(NORMAL / 1.3) run(2.1) swing(NORMAL / 1.3)
assert(q.proc)
run(9) assert(not q.proc, "it should end after its 12 seconds")
-- 2) Auto Shots and the off hand say nothing about it
swing(NORMAL) run(1)
swing(NORMAL / 1.3, 2) swing(1.2, 1) run(0.2)
assert(not q.proc, "only the main hand's swings count")
-- 3) another weapon: a new normal speed, no false alarm; and Berserking is not Quick Strikes
swing(3.6) run(3.6) swing(3.6) assert(not q.proc and math.abs(strike.base - 3.6) < 0.01, "a new weapon's speed must not be read as Quick Strikes")
YaHT.quickSpeed.otherUntil = GetTime() + 15
swing(3.6 / 1.3) run(0.2) assert(not q.proc, "an unknown speed-up must not be guessed at")
YaHT.quickSpeed.otherUntil = 0
-- 4) found as a buff when the fight ends (it procced on the last swing)
buffEnds = GetTime() + 12
run(1) fight(false) run(0.3)
assert(q.proc, "Quick Strikes should show when the fight ends and the buff can be read")
-- 5) the next fight hides the buff: the icon carries on; then it ends with the buff
fight(true) run(0.5) assert(q.proc, "the icon should carry on into the next fight")
fight(false) run(12) assert(not q.proc, "it should end with the buff")
-- 5b) without Aspect of the Beast a faster swing is not Quick Strikes (Hawk on, or no aspect at all);
-- when the aspect is not known, the swing is believed
fight(true) swing(3.6) run(3.6) swing(3.6)
YaHT.aspectFrame.aspect = "HAWK" swing(3.6 / 1.3) run(0.3) assert(not q.proc, "Hawk is on: a fast swing is not Quick Strikes")
assert(math.abs(strike.base - 3.6) < 0.01, "and the normal speed stays what it was")
YaHT.aspectFrame.aspect = "NONE" swing(3.6 / 1.3) run(0.3) assert(not q.proc, "no aspect: not Quick Strikes")
YaHT.aspectFrame.aspect = nil swing(3.6 / 1.3) run(0.3) assert(q.proc, "aspect unknown: believed, as before")
run(13) fight(false) YaHT.aspectFrame.aspect = "BEAST"
-- 6) switched off: nothing
db.quickstrikes = false YaHT:ApplySettings()
fight(true) swing(NORMAL) run(2.8) swing(NORMAL / 1.3) run(0.3)
assert(not q.proc, "switched off, it must stay away")
-- 7) its page is with the other icons
assert(YaHT.optionsTable.args.alerts.args.procspage.args.quickstrikespage, "no Quick Strikes page")
print("OK60")
