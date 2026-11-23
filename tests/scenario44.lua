-- Multi-Shot's short cast (1.5): a thin line under the bar fills from the key press until the shot leaves.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
assert(db.multicast == true, "it should start out switched on")
local function fire(...) ev.scripts.OnEvent(ev, ...) end
local line
local function run(sec) local dt = 0.01 for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  line = YaHT.castLine if line and line.shown then line.scripts.OnUpdate(line, dt) end end end

-- you press Multi-Shot: the line starts, fills over half a second, is full as the shot leaves, then goes
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-1", 2643)
line = YaHT.castLine
assert(line and line.shown and line.alpha == 0, "the line should start (unseen for the first instant)")
fire("UNIT_SPELLCAST_START", "player", "cast-1", 2643)
run(0.25)
assert(line.shown and line.alpha == 1 and math.abs(line.fill.width - line.width * 0.5) < line.width * 0.05, "halfway through it should be half full: "..tostring(line.fill.width))
run(0.2)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 2643)
assert(line.shown and line.fill.width == line.width, "full as the shot leaves")
fire("UNIT_SPELLCAST_STOP", "player", "cast-1", 2643)
assert(line.shown, "the STOP after the shot must not cut the full line short")
run(0.3) assert(not line.shown, "and then it goes")
-- it timed the real cast (0.45s) for the next one
assert(math.abs(YaHT.db.char.multicastLen - 0.45) < 0.02, "the real length should be learned: "..tostring(YaHT.db.char.multicastLen))

-- a key press the game refuses (still on cooldown): SENT and FAILED together, nothing to see
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-2", 2643)
fire("UNIT_SPELLCAST_FAILED", "player", "cast-2", 2643)
assert(not line.shown, "a refused Multi-Shot should show nothing")

-- pressing the key again during the cast: the refused second press must not stop or restart the line
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-3", 2643)
run(0.2)
local from = line.from
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-4", 2643)
fire("UNIT_SPELLCAST_FAILED", "player", "cast-4", 2643)
assert(line.shown and line.from == from, "a second key press during the cast changed the line")
-- the cast is broken off (you moved): the line goes at once
fire("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-3", 2643)
assert(not line.shown, "a broken-off cast should take the line away")

-- other spells and hidden ones start nothing; switched off, nothing shows
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-5", 19434)
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-6", SECRET)
assert(not line.shown, "only Multi-Shot starts the line")
db.multicast = false
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-7", 2643)
assert(not line.shown, "switched off it should not show")
db.multicast = true
-- never told how it ended: it does not stay forever
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-8", 2643)
run(2) assert(not line.shown, "a line nobody ended should go by itself")
-- ITS OWN PAGE: a switch on the Alerts page and on Home, and a page laid out like the others
local alerts = YaHT.optionsTable.args.alerts.args
local page = alerts.multicastpage and alerts.multicastpage.args
assert(alerts.multicast and page, "no Multi-Shot cast page")
for _, key in ipairs({"multicast", "multicastpos", "multicastheight", "multicastwidth", "multicastcolor", "multicastalpha", "multicastback", "multicastsample", "multicastmore", "multicastx", "multicasty", "reset"}) do
  assert(page[key], "the page is missing "..key)
end
-- its settings shape the line: over the bar, thicker, half as wide, red, see-through, no background
local main = YaHT.mainFrame
db.multicastpos, db.multicastheight, db.multicastwidth, db.multicastalpha, db.multicastback = "ABOVE", 9, 0.5, 0.6, false
db.multicastcolor = {r = 1, g = 0, b = 0, a = 1}
fire("UNIT_SPELLCAST_SENT", "player", "Some Boar", "cast-9", 2643)
run(0.2)
assert(line.point[1] == "BOTTOM" and line.point[3] == "TOP", "over the bar: "..tostring(line.point[1]))
assert(math.abs(line.width - main:GetWidth() * 0.5) < 0.01 and line.alpha == 0.6, "width and opacity should follow the settings: "..tostring(line.width).." "..tostring(line.alpha))
assert(not line.back.shown, "the background should be off")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-9", 2643) run(0.3)
-- "Show a sample" plays the line once and ends by itself; a real cast's events don't touch it
local learned = YaHT.db.char.multicastLen
page.multicastsample.func()
assert(line.shown and line.sample, "the sample should show the line")
run(1.2) assert(not line.shown, "the sample should end by itself")
assert(YaHT.db.char.multicastLen == learned, "a sample must not teach the cast length")
-- the page's Reset puts its settings back
page.reset.func()
assert(db.multicastpos == "BELOW" and db.multicastheight == 4 and db.multicastwidth == 1 and db.multicastback == true and db.multicastcolor.g == 0.82, "Reset should put the line's settings back")
assert((YaHT.errorCount or 0) == 0, "YaHT reported a problem")
print("OK44")
