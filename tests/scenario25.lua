-- Position line (1.2), using the range answers measured in game:
--   melee: Wing Clip in range | shooting: Auto Shot in range
--   deadzone: neither, 28-yard check true | too far: neither, 28-yard check false
-- Raptor Strike reports "in range" everywhere, so it must not be what decides melee.
local ev, mev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end
ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
for _,f in ipairs(frames) do if f.events.PLAYER_ENTER_COMBAT then mev=f end end
local db=YaHT.db.profile local f=YaHT.mainFrame local m=YaHT.meleeFrame
db.lock=true YaHT:ApplySettings()

local names = {[75]="Auto Shot",[2973]="Raptor Strike",[2974]="Wing Clip"}
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return names[id] or oldName(id) end
local auto, wing, near, hostile, inCombat = true, false, true, true, false
local interactCalls = 0
C_Spell.IsSpellInRange = function(n) if n=="Auto Shot" then return auto elseif n=="Wing Clip" then return wing else return true end end
function CheckInteractDistance(u,i) interactCalls=interactCalls+1 assert(i==4,"expected the 28-yard check") return near end
function UnitExists() return hostile ~= nil end
function UnitCanAttack() return hostile end
function InCombatLockdown() return inCombat end

local dt=0.01
local function run(sec) for k=1,math.floor(sec/dt+0.5) do advance(dt)
  mev.scripts.OnUpdate(mev,dt) if m.shown then m.scripts.OnUpdate(m,dt) end end end
local function col(c) return math.abs(m.fill.color[1]-c.r)<1e-6 and math.abs(m.fill.color[2]-c.g)<1e-6 end

-- not fighting: range isn't read at all, nothing shows
auto,wing,near=false,false,true run(1)
assert(m.position==nil and interactCalls==0 and (not m.shown or m.alpha==0), "works while not engaged")

-- "Always": also out of combat, as long as an enemy is targeted
db.meleerangewhen="ALWAYS" YaHT:ApplySettings() run(0.6)
assert(m.position=="DEAD" and m.striped and m.alpha>0.9, "always mode doesn't show out of combat")
hostile=false run(1)
assert(m.position==nil and (not m.shown or m.alpha<0.05), "always mode shows without an enemy targeted")
hostile=true
db.meleerangewhen="COMBAT" YaHT:ApplySettings() run(1)
assert(m.position==nil and (not m.shown or m.alpha<0.05), "back to combat only still shows out of combat")
interactCalls=0

inCombat=true
auto,wing,near=true,false,true run(1)
assert(m.position=="OK", "shooting range") print("shooting: shown",m.shown)
assert(not m.shown or m.alpha==0, "something shows in shooting range")

auto,wing,near=false,false,true run(0.6)
assert(m.position=="DEAD" and m.alpha>0.9, "deadzone not shown")
db.meleealpha=0.4 run(0.3) assert(math.abs(m.alpha-1)<1e-6, "deadzone faded with the melee line alpha")
db.meleedeadalpha=0.5 run(0.3) assert(math.abs(m.alpha-0.5)<1e-6, "deadzone opacity ignored")
db.meleealpha=1 db.meleedeadalpha=1
assert(col(db.meleedeadcolor) and m.fill.width==db.width, "deadzone must be a full striped line")
assert(m.striped and m.drawnHeight==math.max(5, db.meleeheight+3), "deadzone line should be striped and thick enough to show it")
assert(math.abs(db.meleedeadcolor.r-1)<1e-6 and math.abs(db.meleedeadcolor.g-0.8)<1e-6, "deadzone default should be bright yellow")
-- extra brightness: a lit copy of the stripes on top, in the deadzone color
assert(m.fillBoost.shown and math.abs(m.fillBoost.alpha-db.meleewarnboost)<1e-6 and math.abs(m.fillBoost.color[2]-0.8)<1e-6, "no brightness layer on the stripes")
db.meleewarnboost=0 run(0.05) assert(not m.fillBoost.shown, "brightness 0% should hide the extra layer")
db.meleewarnboost=0.5
local ov=YaHT.deadOverlay
assert(ov and not ov.shown, "bar overlay shows in line mode")

-- "on the Auto Shot bar": caution tape over the bar, the line stays quiet
db.meleedeadstyle="BAR" YaHT:ApplySettings()
f.shown=true -- Auto Shot on: the bar is up
run(0.6)
assert(ov.shown and ov.alpha>0.99, "no caution tape over the bar")
assert(ov.boost.shown and math.abs(ov.boost.alpha-0.5)<1e-6, "no brightness layer on the caution tape")
assert(ov.ignore==true, "caution tape must not copy the bar's fade")
-- moving with a shot ready dims the bar; the tape stays at the normal bar alpha
-- and it ignores the bar's own transparency: only its Opacity setting counts
db.alpha=0.5 f:SetAlpha(db.malpha or 0.3) run(0.3)
assert(math.abs(ov.alpha-1)<1e-6, string.format("caution tape faded with the bar (%.2f)", ov.alpha))
db.meleedeadalpha=0.6 run(0.3)
assert(math.abs(ov.alpha-0.6)<1e-6, "deadzone opacity ignored on the bar")
db.alpha=1 db.meleedeadalpha=1
assert(not m.shown or m.alpha<0.05, "line should stay quiet in bar mode")
-- bar hidden (Auto Shot off): falls back to the line
f.shown=false run(0.6)
assert(not ov.shown and m.striped and m.alpha>0.9, "no fallback to the line while the bar is hidden")
f.shown=true run(0.6)
assert(ov.shown and (not m.shown or m.alpha<0.05), "back to the bar")
db.meleedeadstyle="LINE" YaHT:ApplySettings() run(0.6)
assert(not ov.shown and m.striped, "back to the line")

auto,wing,near=false,false,false run(0.6)
assert(m.position=="FAR" and m.fill.width<1 and not m.striped, "too far: no line, just arrows")
local function shownArrows() local n=0 for i=1,#m.chevrons do if m.chevrons[i].shown then n=n+1 end end return n end
assert(shownArrows()>=6, "too far: arrows missing")
-- target dropped: the arrows fade out as arrows, the melee line never flashes up
hostile=nil
for k=1,40 do run(0.02)
  if m.shown and m.alpha>0 then
    assert(m.fill.width<1 and m.mode=="ARROWS", string.format("melee line showed while fading (%.2fs, alpha %.2f)", k*0.02, m.alpha))
  end
end
run(0.5) assert(not m.shown, "should be gone after the fade")
hostile=true run(0.6)
assert(m.position=="FAR" and shownArrows()>=6, "arrows back when re-targeting")
assert(math.abs(m.chevrons[1].color[1]-1)<1e-6 and math.abs(m.chevrons[1].color[2]-0.22)<1e-6, "too far arrows should be bright red")
assert(not m.fillBoost.shown, "stripe brightness layer left on when too far")
for i=1,#m.chevrons do assert(m.chevronBoost[i].shown==m.chevrons[i].shown, "arrow brightness layer out of step with its arrow") end
db.meleewarnboost=0 run(0.05) for i=1,#m.chevrons do assert(not m.chevronBoost[i].shown, "arrow brightness at 0% still shown") end
db.meleewarnboost=0.5
assert(m.drawnHeight==8, "line should be tall enough for the arrows")
-- too far has its own opacity, not the swing line's
db.meleealpha=0.4 run(0.3) assert(math.abs(m.alpha-1)<1e-6, "too far faded with the melee line alpha")
db.meleefaralpha=0.7 run(0.3) assert(math.abs(m.alpha-0.7)<1e-6, "too far opacity ignored")
db.meleealpha=1 db.meleefaralpha=1
local x1=m.chevrons[2].point[4] run(0.1)
assert(m.chevrons[2].point[4]>x1, "left arrows should slide toward the middle")
assert(m.chevrons[7].point[4]<0 and m.chevrons[7].point[1]=="RIGHT", "right arrows come from the right end")
auto,wing,near=false,false,true run(0.6)
assert(shownArrows()==0 and m.striped, "arrows left behind in the deadzone")
auto,wing,near=false,false,false run(0.6)

auto,wing,near=false,true,true run(0.6)
assert(m.position=="MELEE" and col(db.meleecolor), "melee should be the normal line")
assert(m.drawnHeight==db.meleeheight, "melee line back to normal thickness")
assert(shownArrows()==0, "arrows left behind in melee")
mev.scripts.OnEvent(mev,"PLAYER_SWING",2.8,0) run(1.4)
local frac=m.fill.width/db.width print(string.format("melee swing: %.0f%%",frac*100))
assert(math.abs(frac-0.5)<0.06, "melee swing fill broken")

-- back to shooting range: fades away once swings stop
auto,wing,near=true,false,true run(5)
assert(not m.shown, "line should go idle in shooting range")

-- friendly / no attackable target: quiet
hostile=false auto,wing=nil,nil run(0.5)
assert(m.position==nil, "friendly target should be quiet") hostile=true

-- hidden answers (bosses, PvP): stay quiet, never an error
auto,wing=SECRET,SECRET run(0.5)
assert(m.position==nil and not m.shown, "secret values should keep it quiet")
auto,wing,near=false,false,SECRET run(0.5)
assert(m.position==nil, "secret interact should keep it quiet")
near=true C_Spell.IsSpellInRange=function() error("blocked") end run(0.5)
assert(m.position==nil, "a blocked call should keep it quiet")
C_Spell.IsSpellInRange=function(n) if n=="Auto Shot" then return false elseif n=="Wing Clip" then return false else return true end end

-- Range tab options (now in a deadzone: neither in range, 28-yard check true)
C_Spell.IsSpellInRange = function(n) if n=="Auto Shot" then return auto elseif n=="Wing Clip" then return wing else return true end end
local G=m.warnGlow
assert(not G.shown, "warning glow should be off by default")
auto,wing,near=false,false,true run(0.6)
assert(m.position=="DEAD" and m.striped, "setup: deadzone")
db.meleedeadheight=9 YaHT:ApplySettings() run(0.3)
assert(m.drawnHeight==9, "stripe thickness option ignored")
-- soft glow: steady, in the deadzone color
db.meleewarnglow="SOFT" db.meleewarnglowalpha=0.6 YaHT:ApplySettings() run(0.3)
assert(G.shown and G.pieces.T.shown and math.abs(G.pieces.T.alpha-0.6)<1e-6, "soft glow not shown")
assert(math.abs(G.pieces.T.color[1]-db.meleedeadcolor.r)<1e-6, "glow should use the deadzone color")
-- pulsing glow: alpha moves
db.meleewarnglow="PULSE" YaHT:ApplySettings()
local lo,hi=1,0 for k=1,60 do run(0.02) lo=math.min(lo,G.pieces.T.alpha) hi=math.max(hi,G.pieces.T.alpha) end
assert(hi-lo>0.15, "pulsing glow doesn't pulse")
-- too far: no glow (it is a deadzone-only setting), arrow size option works
db.meleefarsize=14 YaHT:ApplySettings()
auto,wing,near=false,false,false run(0.6)
assert(m.position=="FAR" and m.drawnHeight==14 and m.chevrons[1].h==14, "arrow size option ignored")
assert(not G.shown, "too far should have no glow")
-- bar mode: the glow goes around the caution tape instead
auto,wing,near=false,false,true db.meleedeadstyle="BAR" YaHT:ApplySettings() f.shown=true run(0.6)
assert(ov.shown and ov.warnGlow.shown and not G.shown, "bar mode glow should be on the bar, not the line")
-- melee swing line switched off: warnings still work on their own
db.meleedeadstyle="LINE" db.melee=false YaHT:ApplySettings() run(0.6)
assert(m.shown and m.alpha>0.9 and m.striped, "warnings need the melee line switched on")
auto,wing,near=true,false,true run(1)
assert(not m.shown or m.alpha<0.05, "line shows in shooting range with melee line off")
db.melee=true
-- Range tab reset puts everything back
local reset
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
R:ValidateOptionsTable(opts, "YaHT")
reset = opts.args.alerts.args.rangepage.args.reset.func
assert(reset, "no Range tab reset button")
reset()
assert(db.meleedeadheight==5 and db.meleefarsize==8 and db.meleewarnglow=="NONE", "range defaults wrong")
run(0.6) assert(not G.shown, "glow left on after switching it off")

-- switched off: no reading, no warning
db.meleerange=false YaHT:ApplySettings() interactCalls=0 run(0.5)
assert(m.position==nil and interactCalls==0, "range warnings switched off still run")
print("OK25")
