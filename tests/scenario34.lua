-- Rebuilt options menu (1.2): three groups (The bar / Alerts / Advanced) plus
-- Profiles; proc icons share one look (an old per-icon Mongoose Bite look is
-- carried over); "Preview all alerts" shows every alert, then they go away.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
-- an earlier test build saved a per-icon look for Mongoose Bite (size 40, Grow pulse)
YaHTdb = {profiles = {Default = {mongoosesize = 40, mongoosepulse = "GROW", quickshotsglow = "RING"}}}
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
assert(db.procsize == 40 and db.procpulse == "GROW", "your Mongoose Bite look wasn't carried over to the shared look")
assert(rawget(db, "mongoosesize") == nil and rawget(db, "quickshotsglow") == nil, "old per-icon look settings left behind")

-- the menu: three groups and Profiles, in that order
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local top = {}
for k, v in pairs(opts.args) do top[#top+1] = {k = k, o = v.order or 0} end
table.sort(top, function(a, b) return a.o < b.o end)
local order = {} for _, t in ipairs(top) do order[#order+1] = t.k end
assert(table.concat(order, ",") == "bar,alerts,advanced,profile", "menu groups: "..table.concat(order, ","))
local bar, alerts, adv = opts.args.bar.args, opts.args.alerts.args, opts.args.advanced.args
assert(bar.lookpage and bar.textpage and bar.effectspage and bar.presetclean, "The bar group incomplete")
assert(bar.effectspage.args.glowstyle and bar.effectspage.args.sparkmode, "glow and spark should share one page")
assert(alerts.procspage and alerts.aspectpage and alerts.feignpage and alerts.rangepage and alerts.meleepage and alerts.ammopage, "Alerts group incomplete")
assert(adv.timingpage and adv.announcepage, "Advanced group incomplete")
-- the Procs page is short: one shared look, small pages per proc
local n = 0
for _, v in pairs(alerts.procspage.args) do if v.type ~= "group" and v.type ~= "header" and v.type ~= "description" then n = n + 1 end end
assert(n <= 11, "Procs page has "..n.." controls")
-- wording: no "Alpha", consistent sentence case on the pages that had it
local function names(g, out) for _, v in pairs(g.args or {}) do
  if v.type == "group" then names(v, out) elseif type(v.name) == "string" then out[#out+1] = v.name end end return out end
for _, label in ipairs(names(opts.args.bar, names(opts.args.alerts, {}))) do
  assert(label ~= "Alpha" and not label:find(" Color$") and not label:find(" Texture$"), "inconsistent label: "..label)
end
-- the glow and spark page's reset covers both
db.glowsize = 30 db.sparksize = 7 bar.effectspage.args.reset.func()
assert(db.glowsize == YaHT.defaults.profile.glowsize and db.sparksize == YaHT.defaults.profile.sparksize, "glow and spark reset incomplete")

-- Preview all alerts: every alert shows, then goes away by itself
db.lock = true YaHT:ApplySettings()
local frs = {YaHT.mongooseFrame, YaHT.quickShotsFrame, YaHT.rapidFireFrame, YaHT.racialFrame}
local fa, m, b = YaHT.feignFrame, YaHT.meleeFrame, YaHT.aspectFrame
local mev for _,f in ipairs(frames) do if f.events.PLAYER_ENTER_COMBAT then mev=f end end
YaHT.aspectFrame.aspect = "HAWK"
local dt = 0.02
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  mev.scripts.OnUpdate(mev, dt)
  for _, f in ipairs(frs) do if f.shown then f.scripts.OnUpdate(f, dt) end end
  for _, f in ipairs({fa, m, b}) do if f.shown then f.scripts.OnUpdate(f, dt) end end end end
sounds = {}
alerts.preview.func() run(0.5)
for i, f in ipairs(frs) do assert(f.shown and f.alpha > 0.9, "proc icon "..i.." not previewed") end
assert(fa.shown, "Feign Death alert not previewed")
assert(b.shown and b.level == "DANGER", "aspect badge warning not previewed")
assert(m.position == "DEAD" and m.striped, "deadzone not previewed")
run(3) assert(m.position == "FAR", "too far not previewed after the deadzone")
run(4)
for i, f in ipairs(frs) do assert(not f.shown, "proc icon "..i.." still shown after the preview") end
assert(not fa.shown and m.position == nil, "preview didn't end")
run(1) assert(not b.shown or b.alpha < 0.05, "aspect preview didn't end")
print("OK34")
