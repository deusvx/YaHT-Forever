-- Pet alerts (1.3): small warning text you can drag anywhere. PET DEAD / NO PET
-- in a fight, PET NOT ATTACKING after 3s of shooting, and PET LOW, which the
-- game draws itself from the pet's hidden health (YaHT only hands the value on).
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end

-- the game: a pet whose health is hidden from addons, like on Forever
local exists, dead, attacking, mounted = false, false, true, false
local lastCurve
C_CurveUtil = {CreateCurve = function() return {pts = {}, AddPoint = function(c, x, y) c.pts[#c.pts + 1] = {x, y} end} end}
function UnitHealthPercent(u, predicted, curve) lastCurve = curve return SECRET end
function UnitExists(u) if u == "pet" then return exists end return true end
function UnitIsDead(u) if u == "pet" then return dead end return false end
function UnitIsDeadOrGhost() return false end
function IsMounted() return mounted end
function IsPetAttackActive() return attacking end

ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local a, w = YaHT.petFrame, YaHT.petWatch
assert(a and w, "no pet alert")

local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  if w.shown then w.scripts.OnUpdate(w, dt) end end end
local function fire(e, ...) w.scripts.OnEvent(w, e, ...) end
local function near(x, y) return math.abs(x - y) < 1e-6 end

-- unlocked (a fresh install): the warnings show so you can drag them into place
run(0.1)
assert(a.shown and a.text.shown and a.text.txt == "PET DEAD", "no preview while unlocked")
assert(a.low.shown and a.low.alpha == 1 and a.lowText.txt == "PET LOW", "low warning not previewed")
assert(a.dragHint.shown and a.mouse == true, "can't be dragged while unlocked")
assert(a.pulse and a.pulse.playing, "pulse not running")
-- the pulse runs on the first line only; the low line never takes a fading parent's alpha
-- (in game it then showed for one frame a second instead of steadily)
assert(a.text.pulse == a.pulse and a.low.ignore == true, "PET LOW must not sit under the pulse")
a.scripts.OnDragStop(a)
assert(db.petpoint == "CENTER" and db.petx == 10 and db.pety == 20, "dragged spot not saved")

db.lock = true YaHT:ApplySettings() run(0.1)
assert(not a.shown and a.mouse == false and not w.shown, "should be away and asleep when locked out of a fight")

-- a hunter who never had a pet out isn't nagged about a missing one
sounds = {}
fire("PLAYER_REGEN_DISABLED") run(4)
assert(not a.shown and #sounds == 0, "NO PET for a hunter without a pet")
fire("PLAYER_REGEN_ENABLED") run(0.1)

-- pet out, in a fight: the low line is switched on and handed the hidden health through a curve
exists = true
fire("UNIT_PET", "player") fire("PLAYER_REGEN_DISABLED") run(0.1)
assert(a.shown and a.low.shown and not a.text.shown, "low line should be on in a fight")
assert(a.low.alpha == SECRET, "the hidden health wasn't handed to the low line")
assert(lastCurve and #lastCurve.pts == 4 and near(lastCurve.pts[2][1], 0.33) and near(lastCurve.pts[3][1], 0.37)
  and lastCurve.pts[2][2] == 1 and lastCurve.pts[3][2] == 0, "low curve isn't built around 35%")
assert(#sounds == 0, "sound for the low line")
db.petlowat = 50 YaHT:ApplySettings() run(0.1)
assert(near(lastCurve.pts[2][1], 0.48), "low curve didn't follow the setting")

-- the pet dies: PET DEAD at once, with one warning sound, and no low line
dead = true fire("UNIT_HEALTH", "pet") run(0.1)
assert(a.text.shown and a.text.txt == "PET DEAD" and not a.low.shown, "no PET DEAD")
local function recorded(what) for _, l in ipairs(YaHT.db.global.record or {}) do if l:find(what, 1, true) then return true end end end
assert(recorded("[pet]") and recorded("dead | pet out true, dead true"), "the pet dying wasn't written to the record")
assert(a.text.tcolor[1] == 1 and a.text.tcolor[2] < 0.5, "PET DEAD should be red")
assert(#sounds == 1, "expected one warning sound, got "..#sounds)
run(3) assert(#sounds == 1, "sound repeated")
-- its body goes away: straight on to NO PET, no flicker and no second sound
exists = false fire("UNIT_PET", "player") run(0.1)
assert(a.text.shown and a.text.txt == "NO PET" and #sounds == 1, "dead pet's body leaving should read NO PET quietly")
-- revived
exists, dead = true, false fire("UNIT_PET", "player") run(0.1)
assert(not a.text.shown and a.low.shown, "warning stayed after the pet came back")

-- pet goes missing mid-fight (dismissed): NO PET after a moment, with the sound
exists = false fire("UNIT_PET", "player") run(1)
assert(not a.text.shown, "NO PET too early")
run(1.6)
assert(a.text.shown and a.text.txt == "NO PET" and #sounds == 2, "no NO PET for a pet missing in a fight")
-- mounted: no pet is expected
mounted = true run(0.3) assert(not a.shown, "NO PET while mounted")
mounted = false exists = true fire("UNIT_PET", "player") run(0.1)

-- not attacking: only after 3 seconds of shooting
attacking = false
YaHT.mainFrame.shooting = true fire("START_AUTOREPEAT_SPELL") run(2.5)
assert(not a.text.shown, "PET NOT ATTACKING too early")
run(1)
assert(a.text.shown and a.text.txt == "PET NOT ATTACKING", "no PET NOT ATTACKING")
assert(a.text.tcolor[2] > 0.7, "PET NOT ATTACKING should be yellow")
assert(#sounds == 2, "sound for a pet that isn't attacking")
attacking = true fire("PET_ATTACK_START") run(0.1)
assert(not a.text.shown, "warning stayed once the pet attacked")
-- ... and never while you aren't shooting
attacking = false YaHT.mainFrame.shooting = false fire("STOP_AUTOREPEAT_SPELL") run(5)
assert(not a.text.shown, "PET NOT ATTACKING while not shooting")

-- the fight ends: everything goes away and the watcher sleeps
fire("PLAYER_REGEN_ENABLED") run(0.1)
assert(not a.shown and not w.shown, "should be away and asleep out of a fight")
-- "Always": the low line also works out of a fight, still without polling
db.petwhen = "ALWAYS" YaHT:ApplySettings() run(0.1)
assert(a.shown and a.low.shown and not w.shown, "low line should work out of a fight when set to Always")
db.petwhen = "COMBAT" YaHT:ApplySettings() run(0.1)
assert(not a.shown, "low line stayed out of a fight")

-- each warning can be switched off, and so can all of them
fire("PLAYER_REGEN_DISABLED") dead = true fire("UNIT_HEALTH", "pet") run(0.1)
assert(a.text.shown, "setup: PET DEAD")
db.petdead = false YaHT:ApplySettings() run(0.1) assert(not a.text.shown, "PET DEAD ignores its switch")
db.petdead = true dead = false YaHT:ApplySettings() run(0.1) assert(a.low.shown, "setup: low line")
db.petlow = false YaHT:ApplySettings() run(0.1) assert(not a.low.shown and not a.shown, "low line ignores its switch")
db.petlow = true db.pet = false dead = true YaHT:ApplySettings() run(0.1)
assert(not a.shown and not a.pulse.playing, "pet alerts ignore their main switch")
db.pet = true dead = false YaHT:ApplySettings() run(0.1)
db.petpulse = false YaHT:ApplySettings() assert(not a.pulse.playing, "pulse ignores its switch")

-- answers the game hides: nothing shows, nothing breaks
function UnitExists(u) if u == "pet" then return SECRET end return true end
fire("UNIT_PET", "player") run(3)
assert(not a.shown, "a hidden answer was taken for something")
function UnitExists(u) if u == "pet" then return exists end return true end
-- a game without curves: the low line just never shows
C_CurveUtil = nil db.petlowat = 40 YaHT:ApplySettings() run(0.1)
assert(a.low.shown and a.low.alpha == 0, "low line should stay invisible without curves")

-- the Pet page: its slider reads as a share, and Reset puts everything back (also the dragged spot)
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
local page = opts.args.alerts.args.petpage
assert(page and opts.args.alerts.args.pet, "no Pet page / switch in the menu")
assert(near(page.args.petlowat.get(), 0.4), "slider should read 40%")
page.args.petlowat.set(nil, 0.25) assert(db.petlowat == 25, "slider didn't set 25%")
page.args.reset.func()
assert(db.petlowat == 35 and db.petpoint == nil and db.petpulse == true, "Reset this page left something behind")

-- /yaht pet says what YaHT sees
local line
local add = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, msg) if msg:find("Pet: out", 1, true) then line = msg end end
SlashCmdList["YAHT"]("pet")
DEFAULT_CHAT_FRAME.AddMessage = add
assert(line and line:find("out true | dead false", 1, true), "/yaht pet: "..tostring(line))
print("OK35")
