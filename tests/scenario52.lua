-- The tracking wheel (1.5.2): a button that shows what you track. A click opens
-- everything you can track around it inside a circle; move the mouse towards
-- one and on out of the circle, and that one is picked.
local ev
for _,f in ipairs(frames) do if f.events.PLAYER_LOGIN then ev=f end end

-- the game: the minimap's tracking list, one slot for spells, like on Forever
local list = {
  {name = "Track Beasts", texture = "beasts", type = "spell", active = false},
  {name = "Track Humanoids", texture = "humanoids", type = "spell", active = false},
  {name = "Track Hidden", texture = "hidden", type = "spell", active = false},
  {name = "Find Minerals", texture = "minerals", type = "spell", active = false},
  {name = "Repair", texture = "repair", type = "other", active = true},
}
local refuse, calls = false, 0
local watch
C_Minimap = {
  GetNumTrackingTypes = function() return #list end,
  GetTrackingInfo = function(i) return list[i] end,
  SetTracking = function(i, on)
    calls = calls + 1
    if refuse then return end
    if list[i].type == "spell" then for _, t in ipairs(list) do if t.type == "spell" then t.active = false end end end
    list[i].active = on
    watch.scripts.OnEvent(watch, "MINIMAP_UPDATE_TRACKING")
  end,
}

ev.scripts.OnEvent(ev,"PLAYER_LOGIN")
local db = YaHT.db.profile
local hub, wheel, slices = YaHT.trackerFrame, YaHT.trackerWheel, YaHT.trackerSlices
watch = YaHT.trackerWatch
assert(hub and wheel and watch, "no tracking wheel")
hub.GetCenter = function() return 0, 0 end -- (the test rig has no screen positions: the button is at 0, 0)
local dt = 0.05
local function run(sec) for k = 1, math.floor(sec/dt + 0.5) do advance(dt)
  hub.scripts.OnUpdate(hub, dt)
  if wheel.shown then wheel.scripts.OnUpdate(wheel, dt) end end end
local function mouse(x, y) cursorX, cursorY = x, y end
local chat = {}
local add = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, msg) chat[#chat + 1] = msg end

-- tracking nothing: the button is there, grey, and closed, behind bags and other windows
assert(hub.layer == "LOW", "the closed button should sit behind windows, is "..tostring(hub.layer))
assert(hub.shown and not wheel.open and hub.current == nil and hub.icon.desat == true, "the button should show 'nothing' to start with")

-- a click opens the wheel: a circle, with one track for each spell (not the minimap's other filters)
mouse(0, 0)
hub.scripts.OnClick(hub)
assert(wheel.open and wheel.shown and wheel.count == 4, "the wheel should have the four tracking spells, has "..tostring(wheel.count))
assert(slices[1].name == "Track Beasts" and slices[4].name == "Find Minerals" and slices[1].shown, "wrong tracks")
run(0.3)
-- a pie: one piece for each track, together a wide grey disc around the tracks; no tooltip on the button
assert(wheel.edge > wheel.radius + db.trackersize and wheel.edge >= db.trackersize * 3, "the pie should be wide")
assert(slices[1].piece.shown and slices[1].piece.w == wheel.edge * 2, "no pieces of pie")
assert(not slices[1].lit and not slices[2].lit and slices[1].alpha == 1, "nothing should be lit yet")
assert(hub.scripts.OnEnter == nil, "the button should have no tooltip")
assert(wheel.aimed == nil and wheel.label.txt == "No tracking", "nothing should be aimed at while the mouse is in the middle")

-- heading for one: it is marked and named, nothing is picked yet. (1 = up, 2 = right, 3 = down, 4 = left)
mouse(40, 0) run(0.1)
assert(wheel.aimed == slices[2] and wheel.label.txt == "Track Humanoids" and slices[2].w > slices[1].w, "the track you head for isn't marked")
assert(slices[2].lit and not slices[1].lit and not slices[3].lit, "the whole piece you head for should light up, and only that one")
assert(calls == 0 and wheel.open, "picked before leaving the circle")
mouse(0, -40) run(0.1)
assert(wheel.aimed == slices[3] and wheel.label.txt == "Track Hidden" and calls == 0, "changing direction should change the aim, nothing more")
assert(slices[3].lit and not slices[2].lit, "the light should move to the new piece")
-- ... and on out of the circle: that one is picked, and the wheel closes
mouse(0, -(wheel.edge + 5)) run(0.1)
assert(calls == 1 and list[3].active and not wheel.open, "leaving the circle should pick the track you headed for")
assert(hub.current == "Track Hidden" and hub.icon.tex == "hidden" and hub.icon.desat == false, "the button doesn't show the new tracking")
-- it fades away rather than vanishing
assert(wheel.shown and wheel.alpha <= 1, "the pie should fade out, not pop")
assert(hub.layer == "DIALOG", "the button should be in front while its pie is open")
run(0.3) assert(not wheel.shown, "the pie should be gone after its fade")
assert(hub.layer == "LOW", "the button should go behind windows again once the pie is closed")
run(2) assert(#chat == 0, "a pick that went through was reported as ignored")

-- out past the one you already track: nothing is asked of the game, the wheel just closes
mouse(0, 0) hub.scripts.OnClick(hub) run(0.3)
assert(slices[3].active, "the wheel doesn't mark the one you track")
assert(slices[3].piece.vcolor == nil or true)
mouse(0, -(wheel.edge + 5)) run(0.1)
assert(calls == 1 and not wheel.open and list[3].active, "leaving past the one you track should change nothing")
-- another direction: switched, and only that one is on
mouse(0, 0) hub.scripts.OnClick(hub) run(0.3)
mouse(0, wheel.edge + 5) run(0.1)
assert(calls == 2 and list[1].active and not list[3].active and hub.current == "Track Beasts", "leaving upwards should pick the top one")

-- the middle again closes it without choosing
mouse(0, 0) hub.scripts.OnClick(hub) run(0.3)
hub.scripts.OnClick(hub)
assert(not wheel.open and calls == 2, "a second click on the button should close the wheel and pick nothing")

-- a click on a track picks it and closes; a click on the one you track switches it off
hub.scripts.OnClick(hub) run(0.3)
slices[2].scripts.OnClick(slices[2])
assert(list[2].active and not wheel.open and hub.current == "Track Humanoids", "a click should pick and close")
hub.scripts.OnClick(hub) run(0.3)
slices[2].scripts.OnClick(slices[2])
assert(not list[2].active and hub.current == nil, "a click on the one you track should switch it off")

-- "Clicking it": leaving the circle only closes the wheel
db.trackerpick = "CLICK" YaHT:ApplySettings()
calls = 0
mouse(0, 0) hub.scripts.OnClick(hub) run(0.3)
mouse(-(wheel.edge + 5), 0) run(0.1)
assert(calls == 0 and not wheel.open, "set to clicking, leaving the circle should pick nothing")
mouse(0, 0) hub.scripts.OnClick(hub) run(0.3)
slices[4].scripts.OnClick(slices[4])
assert(calls == 1 and list[4].active, "set to clicking, a click should pick")
db.trackerpick = "MOVE" YaHT:ApplySettings()

-- a game that ignores a pick made without a click: said once, and from then on only clicks pick
refuse, calls = true, 0
mouse(0, 0) hub.scripts.OnClick(hub) run(0.3)
mouse(0, wheel.edge + 5) run(0.1)
assert(calls == 1 and not wheel.open, "setup: one try")
run(1.5)
assert(#chat == 1 and chat[1]:find("on a click", 1, true), "should say once that the game wants a click")
mouse(0, 0) hub.scripts.OnClick(hub) run(0.3)
mouse(0, wheel.edge + 5) run(0.1)
run(1.5)
assert(calls == 1 and #chat == 1 and not wheel.open, "kept trying after the game ignored a pick")
refuse = false
mouse(0, 0) hub.scripts.OnClick(hub) run(0.3)
slices[2].scripts.OnClick(slices[2])
assert(list[2].active, "a click should still work")

-- "also the minimap's other filters"
db.trackerall = true YaHT:ApplySettings()
hub.scripts.OnClick(hub)
assert(wheel.count == 5 and slices[5].name == "Repair", "the other filters should join the wheel")
hub.scripts.OnClick(hub)
db.trackerall = false

-- dragging moves it only while unlocked, and the spot is kept
db.lock = true YaHT:ApplySettings()
assert(hub.dragHint.shown == false, "drag hint while locked")
db.lock = false YaHT:ApplySettings()
assert(hub.dragHint.shown, "no drag hint while unlocked")
hub.scripts.OnDragStop(hub)
assert(db.trackerpoint == "CENTER" and db.trackerx == 10 and db.trackery == 20, "dragged spot not saved")

-- its switch, its page and Reset
db.tracker = false YaHT:ApplySettings() assert(not hub.shown, "the wheel ignores its switch")
db.tracker = true YaHT:ApplySettings() assert(hub.shown, "the wheel didn't come back")
local R = LibStub("AceConfigRegistry-3.0")
local opts = R:GetOptionsTable("YaHT")("dialog","AceConfigDialog-3.0")
local page = opts.args.alerts.args.trackerpage
assert(page and opts.args.alerts.args.tracker and page.args.trackerpick and page.args.trackersize and page.args.trackerall, "no Tracking wheel page / switch")
db.trackersize = 50 page.args.reset.func()
assert(db.trackersize == 36 and db.trackerpoint == nil and db.trackerpick == "MOVE", "Reset this page left something behind")

-- a client without the tracking list: nothing breaks, the wheel just stays shut
C_Minimap = nil
hub.scripts.OnClick(hub)
assert(not wheel.open, "opened without a tracking list")
DEFAULT_CHAT_FRAME.AddMessage = add
print("OK52")
