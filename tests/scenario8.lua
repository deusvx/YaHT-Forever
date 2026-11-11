local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local tabs={} for k,v in pairs(opts.args) do table.insert(tabs, (v.order or 0)..":"..k) end table.sort(tabs, function(a,b) return tonumber(a:match("^[%d.]+"))<tonumber(b:match("^[%d.]+")) end)
print("tabs:", table.concat(tabs," "))
local db=YaHT.db.profile local f=YaHT.mainFrame
local function tick(k,dt) for i=1,k do advance(dt) f.scripts.OnUpdate(f,dt) end end
-- presets
opts.args.bar.args.presetclean.func() print("clean:", db.glowlook, db.glowmode, db.sparkmode, db.glowstyle)
opts.args.bar.args.presetflashy.func() print("flashy:", db.glowlook, db.glowstyle, db.glowkeepbuiltin, db.glowsize)
opts.args.bar.args.presetminimal.func() print("minimal:", db.glow, db.sparkmode, db.readypulse)
-- reset tab
opts.args.bar.args.effectspage.args.reset.func() print("glow and spark page reset:", db.glow, db.glowsize, db.glowstyle, db.sparkmode)
db.glowcolor.r=0 opts.args.bar.args.effectspage.args.reset.func() print("color reset r:", db.glowcolor.r, "is copy:", db.glowcolor ~= YaHT.defaults.profile.glowcolor)
-- reset position
db.point="TOP" db.x=50 opts.args.bar.args.resetpos.func() print("pos reset:", db.point, db.x)
-- slash
SlashCmdList.YAHT("lock") print("lock:", db.lock) SlashCmdList.YAHT("unlock") print("unlock:", db.lock)
db.point="TOP" SlashCmdList.YAHT("reset") print("slash reset:", db.point)
SlashCmdList.YAHT("help")
SlashCmdList.YAHT("lock")
-- feign death resets timer
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.24, 2) tick(150,0.01)
local before=f.lastshot fire("UNIT_SPELLCAST_SUCCEEDED","player","g",5384) print("feign reset:", f.lastshot>before, f.SwingStart==nil)
-- text only updates on change
local n=0 local orig=f.text.SetText f.text.SetText=function(s,t) n=n+1 orig(s,t) end
tick(100,0.001) print("SetText calls over 100 frames (0.1s):", n)
-- compartment
YaHT_OnAddonCompartmentClick()
print("version", YaHT.version)
print("OK8")
