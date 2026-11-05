-- fake LibCustomGlow
local LCG = LibStub:NewLibrary("LibCustomGlow-1.0", 1)
calls = {}
function LCG.PixelGlow_Start(f,c,...) table.insert(calls,"pixel start") end
function LCG.PixelGlow_Stop(f,k) table.insert(calls,"pixel stop") end
function LCG.ProcGlow_Start(f,o) table.insert(calls,"proc start "..tostring(o.key)) end
function LCG.ProcGlow_Stop(f,k) table.insert(calls,"proc stop") end
local ev for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
local function fire(e,...) ev.scripts.OnEvent(ev,e,...) end
fire("PLAYER_LOGIN")
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
local vals = opts.args.glow.args.glowstyle.values()
local n=0 for k in pairs(vals) do n=n+1 end print("styles offered:", n)
local db=YaHT.db.profile local f=YaHT.mainFrame
local function tick(k,dt) for i=1,k do advance(dt) f.scripts.OnUpdate(f,dt) end end
db.lock=true db.glowstyle="PIXEL" YaHT:ApplySettings()
fire("START_AUTOREPEAT_SPELL") fire("PLAYER_SWING", 2.24, 2)
tick(100,0.01) print("reload glow", string.format("%.2f",f.glow.alpha), table.concat(calls,","))
tick(100,0.01) print("standing builtin alpha", f.glow.alpha, table.concat(calls,","))
fire("PLAYER_SWING", 2.24, 2) tick(1,0.01) print("after shot:", table.concat(calls,","))
calls={} db.glowstyle="PROC" tick(200,0.01) print("proc:", table.concat(calls,","))
calls={} db.glowstyle="AUTOCAST" tick(1,0.01) print("autocast missing in lib -> fallback, alpha", string.format("%.2f",f.glow.alpha), table.concat(calls,","))
print("OK5")
