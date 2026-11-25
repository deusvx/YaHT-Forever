-- Attempt after attempt failing while you stand (feigning, in melee, in the deadzone). Each failure
-- used to carry the fill on from where it was, so the bar crept ever slower toward full and the
-- shot that finally came "went really slow". Now the bar waits empty for the game's next attempt
-- and then shows the real stand-still part at its real speed.
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
db.lock=true db.width=200 db.fill=false YaHT:ApplySettings()
local function tick(n,dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f,dt) end end
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.24, 2)
tick(190, 0.01)                                   -- the reload is over, the first attempt is due
for i = 1, 5 do                                   -- five attempts fail, half a second apart
  fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "c"..i, 75)
  tick(50, 0.01)
end
-- (the old way: the bar stood at about 97% here, creeping)
fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "c6", 75)
tick(45, 0.01)
assert(f.texture.width < 5, "while attempts keep failing the bar should wait empty, got "..f.texture.width)
tick(5, 0.01)                                     -- the next attempt: this one goes through
local wind = f.windup
tick(math.floor(wind / 2 / 0.01 + 0.5), 0.01)
local half = f.texture.width / 200
assert(half > 0.35 and half < 0.65, "half-way through the stand-still part the bar should be half full, got "..half)
fire("PLAYER_SWING", 2.24, 2)
assert(f.failRun == 0)
-- one single failure still carries on smoothly (no jump back)
tick(190, 0.01) tick(20, 0.01)
local before = f.texture.width
fire("UNIT_SPELLCAST_FAILED_QUIET", "player", "d1", 75) tick(1, 0.01)
assert(f.texture.width >= before - 1, "a single failed attempt must not make the bar jump back")
print("OK59")
