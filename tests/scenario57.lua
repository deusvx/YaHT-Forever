-- The cast bar style (after Bouk's Hunter Castbar): blue reload running down, green stand-still
-- part, always from the left, with the shot's name and "time left / whole time" on the bar.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local db=YaHT.db.profile local f=YaHT.mainFrame
local function near(c, r, g, b) return math.abs(c[1]-r)<0.02 and math.abs(c[2]-g)<0.02 and math.abs(c[3]-b)<0.02 end
local function tick(n, dt) for i=1,n do advance(dt) f.scripts.OnUpdate(f, dt) end end

-- off by default: the regular bar, no words
assert(db.barstyle == "YAHT" and not f.castText.shown, "the regular style should be the default")
db.lock = true db.fill = true db.width = 200
db.barstyle = "CASTBAR" YaHT:ApplySettings()
assert(f.castText.shown, "the cast bar style should show its words")
assert(not YaHT.FromMiddle(db), "the cast bar style always runs from the left")

-- a shot: the reload is blue and runs down
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.24, 2)
tick(20, 0.01)
local w1 = f.texture.width
assert(near(f.texture.color, 0.33, 0.35, 1), "the reload should be blue")
tick(60, 0.01)
assert(f.texture.width < w1 - 20, "the reload should run down")
assert(f.castText.time.txt and f.castText.time.txt:find(" / ", 1, true), "the time should read 'left / whole', got "..tostring(f.castText.time.txt))
-- the stand-still part is green and (by default) runs down from full
tick(110, 0.01)
assert(f.SwingStart, "the stand-still part should have started")
assert(near(f.texture.color, 0.18, 1, 0.16), "the stand-still part should be green")
local w2 = f.texture.width
tick(10, 0.01)
assert(f.texture.width < w2, "by default the stand-still part runs down")
-- ... or fills up, when chosen
db.castbardir = "FILL"
local w3 = f.texture.width
tick(1, 0.01) local a = f.texture.width tick(5, 0.01)
assert(f.texture.width > a, "with 'Fills up' the stand-still part should grow")

-- words off; and back to the regular style: its own colours and "from the middle" again
db.castbartext = false YaHT:ApplySettings() assert(not f.castText.shown)
db.barstyle = "YAHT" YaHT:ApplySettings()
assert(YaHT.FromMiddle(db) and not f.castText.shown, "the regular style should be untouched")
assert(YaHT.Look(db, "drawcolor") == db.drawcolor and YaHT.Look(db, "timercolor") == db.timercolor)

-- the placing demo runs in the style too, without a problem
db.lock = false db.barstyle = "CASTBAR" db.castbartext = true YaHT:ApplySettings()
tick(400, 0.01)
assert((YaHT.errorCount or 0) == 0, "problem: "..tostring(YaHT.lastError))
-- the options page: the style's rows only while it is chosen, the regular colours only otherwise
local look = YaHT.optionsTable.args.bar.args.lookpage.args
assert(look.barstyle, "no Bar style on the bar's look page")
assert(not look.castbardir.hidden() and look.timercolor.hidden() and look.fill.hidden())
db.barstyle = "YAHT"
assert(look.castbardir.hidden() and not look.timercolor.hidden())
print("OK57")
