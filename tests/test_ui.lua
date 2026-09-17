--[[ Runs the whole script, headlessly.

     ReaImGui only exists inside REAPER, so this stands a mock in its place and
     drives the real "Starting Blocks.lua" through every panel, clicking every
     control in turn. It cannot tell you the window looks right. It can tell
     you that nothing in it raises, that no call reaches a ReaImGui function
     that does not exist, that every PushID and PushStyleColor is matched by
     its pop, and that every control it clicks leaves the state somewhere the
     engine can still generate from.

       lua5.4 tests/test_ui.lua
       python3 tools/run_lua.py tests/test_ui.lua
]]

local HERE   = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SCRIPT = HERE .. "/../reascripts/Starting Blocks.lua"

local failures, checks = 0, 0
local function ok(cond, what)
  checks = checks + 1
  if not cond then failures = failures + 1; io.write("FAIL  ", what, "\n") end
end
local function eq(got, want, what)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    io.write("FAIL  ", what, "\n        got  ", tostring(got),
             "\n        want ", tostring(want), "\n")
  end
end

------------------------------------------------------------------------------
-- A ReaImGui that records instead of drawing
--
-- Unknown keys raise rather than returning nil, so a call to a function that
-- ReaImGui does not have is a failure here instead of a silent no-op in REAPER.
------------------------------------------------------------------------------

local imgui = {
  idDepth = 0, colDepth = 0, widthDepth = 0,
  buttons = {}, sliders = {}, checkboxes = {},
  clickTarget = nil, clicked = nil,
  tooltips = {}, drawCalls = 0, maxIdDepth = 0,
}

local function count(name) imgui.calls[name] = (imgui.calls[name] or 0) + 1 end
imgui.calls = {}

local ImGui = {}

-- Constants ReaImGui exposes as plain values.
for _, k in ipairs({ "Col_Button", "Col_ButtonHovered", "Col_ButtonActive",
                     "Col_Text", "Cond_FirstUseEver", "Key_Escape",
                     "HoveredFlags_AnyWindow" }) do
  ImGui[k] = 1
end

function ImGui.CreateContext(name) return { name = name } end
function ImGui.SetNextWindowSize() count("SetNextWindowSize") end
function ImGui.Begin() count("Begin"); return true, true end
function ImGui.End() count("End") end
function ImGui.IsKeyPressed() return false end
function ImGui.SeparatorText(_, s) count("SeparatorText"); imgui.lastHeading = s end
function ImGui.Text(_, s)
  count("Text")
  if type(s) ~= "string" then error("Text got a " .. type(s)) end
end
function ImGui.Dummy() count("Dummy") end
function ImGui.SameLine() count("SameLine") end
function ImGui.NewLine() count("NewLine") end
function ImGui.PushID(_, v)
  if v == nil then error("PushID with nil") end
  imgui.idDepth = imgui.idDepth + 1
  imgui.maxIdDepth = math.max(imgui.maxIdDepth, imgui.idDepth)
end
function ImGui.PopID()
  imgui.idDepth = imgui.idDepth - 1
  if imgui.idDepth < 0 then error("PopID without a PushID") end
end
function ImGui.Button(_, label, w, h)
  if type(label) ~= "string" then error("Button label is a " .. type(label)) end
  imgui.buttons[#imgui.buttons + 1] = label
  if imgui.clickTarget == #imgui.buttons then
    imgui.clicked = label
    return true
  end
  return false
end
function ImGui.PushStyleColor(_, idx, col)
  if type(col) ~= "number" then error("style colour is a " .. type(col)) end
  imgui.colDepth = imgui.colDepth + 1
end
function ImGui.PopStyleColor(_, n)
  imgui.colDepth = imgui.colDepth - (n or 1)
  if imgui.colDepth < 0 then error("PopStyleColor without a push") end
end
function ImGui.IsItemHovered() return true end        -- so every tooltip is built
function ImGui.SetTooltip(_, s)
  if type(s) ~= "string" then error("tooltip is a " .. type(s)) end
  imgui.tooltips[#imgui.tooltips + 1] = s
end
function ImGui.PushItemWidth() imgui.widthDepth = imgui.widthDepth + 1 end
function ImGui.PopItemWidth()
  imgui.widthDepth = imgui.widthDepth - 1
  if imgui.widthDepth < 0 then error("PopItemWidth without a push") end
end
function ImGui.SliderInt(_, label, v, lo, hi)
  if type(v) ~= "number" then error("SliderInt " .. tostring(label) .. " got a " .. type(v)) end
  -- A slider handed a value outside its own range is a bug either way round:
  -- either the range is wrong or the state has drifted past it.
  if v < lo or v > hi then
    error(("SliderInt %s: value %s is outside its range %s..%s"):format(label, v, lo, hi))
  end
  imgui.sliders[#imgui.sliders + 1] = label
  if imgui.sliderMode == "max" then return true, hi end
  if imgui.sliderMode == "min" then return true, lo end
  return false, v
end
function ImGui.Checkbox(_, label, v)
  imgui.checkboxes[#imgui.checkboxes + 1] = label
  if imgui.toggleBoxes then return true, not v end
  return false, v
end
function ImGui.GetWindowDrawList() return {} end
function ImGui.GetCursorScreenPos() return 0, 0 end
function ImGui.InvisibleButton() return false end
function ImGui.DrawList_AddRectFilled(_, x1, y1, x2, y2, col)
  imgui.drawCalls = imgui.drawCalls + 1
  if type(col) ~= "number" then error("rect colour is a " .. type(col)) end
  if x2 < x1 or y2 < y1 then error("rect is inside out") end
end
function ImGui.DrawList_AddLine(_, _, _, _, _, col)
  imgui.drawCalls = imgui.drawCalls + 1
  if type(col) ~= "number" then error("line colour is a " .. type(col)) end
end
function ImGui.GetContentRegionAvail() return 960, 400 end
function ImGui.IsMouseClicked() return imgui.mouseClicked == true end
function ImGui.IsWindowHovered() return imgui.windowHovered ~= false end

setmetatable(ImGui, { __index = function(_, k)
  error("the script called ImGui." .. tostring(k) .. ", which the mock does not have")
end })

------------------------------------------------------------------------------
-- A REAPER that records instead of doing
------------------------------------------------------------------------------

local tmpdir = "/tmp/starting-blocks-ui-test"
os.execute('rm -rf "' .. tmpdir .. '" && mkdir -p "' .. tmpdir .. '"')

-- The script loads ReaImGui by dofile-ing a shim; give it one that hands over
-- the mock.
local shimDir = tmpdir .. "/shim"
os.execute('mkdir -p "' .. shimDir .. '"')
local shim = assert(io.open(shimDir .. "/imgui.lua", "w"))
shim:write("return function(version) return _G.__MOCK_IMGUI end\n")
shim:close()
_G.__MOCK_IMGUI = ImGui

local deferred, items, stuffed, extstate = nil, {}, {}, {}
local now = 1000.0

reaper = {
  ImGui_GetBuiltinPath = function() return shimDir end,
  MB = function(msg) error("the script gave up: " .. tostring(msg)) end,
  get_action_context = function()
    local abs = SCRIPT
    if not abs:match("^/") then abs = (os.getenv("PWD") or ".") .. "/" .. abs end
    return true, abs, 0, 1, 0, 0, 0
  end,
  defer = function(f) deferred = f end,
  atexit = function(f) reaper.atexitHandler = f end,
  set_action_options = function() end,
  SetToggleCommandState = function() end,
  RefreshToolbar2 = function() end,
  time_precise = function() return now end,

  GetExtState = function(s, k) return extstate[s .. ":" .. k] or "" end,
  SetExtState = function(s, k, v) extstate[s .. ":" .. k] = v end,

  Master_GetTempo = function() return 120 end,
  TimeMap_GetTimeSigAtTime = function() return 4, 4, 120 end,
  GetCursorPosition = function() return 0 end,
  TimeMap2_timeToQN = function(_, t) return t * 2 end,
  TimeMap2_QNToTime = function(_, qn) return qn / 2 end,
  SnapToGrid = function(_, t) return math.floor(t * 2 + 0.5) / 2 end,

  GetSelectedTrack = function() return "track1" end,
  GetLastTouchedTrack = function() return nil end,
  GetMousePosition = function() return 400, 300 end,
  GetTrackFromPoint = function() return "trackUnderMouse" end,
  GetSet_ArrangeView2 = function() return 3.25, 3.30 end,

  CreateNewMIDIItemInProj = function(track, a, b)
    local item = { track = track, pos = a, fin = b, take = { notes = {} } }
    items[#items + 1] = item
    return item
  end,
  GetActiveTake = function(i) return i.take end,
  MIDI_GetPPQPosFromProjQN = function(_, qn) return qn * 960 end,
  MIDI_InsertNote = function(take, _, _, sp, ep, ch, pitch, vel)
    take.notes[#take.notes + 1] = { sp = sp, ep = ep, pitch = pitch, vel = vel }
  end,
  MIDI_Sort = function() end,
  GetSetMediaItemTakeInfo_String = function(take, k, v) if k == "P_NAME" then take.name = v end end,
  UpdateArrange = function() end,
  Undo_BeginBlock = function() end,
  Undo_EndBlock = function() end,

  GetResourcePath = function() return tmpdir end,
  RecursiveCreateDirectory = function(p) os.execute('mkdir -p "' .. p .. '"') end,
  StuffMIDIMessage = function(mode, a, b, c)
    stuffed[#stuffed + 1] = { mode = mode, a = a, b = b, c = c }
  end,
}

------------------------------------------------------------------------------
-- Load it
------------------------------------------------------------------------------

local loaded, err = pcall(dofile, SCRIPT)
ok(loaded, "the script loads: " .. tostring(err))
ok(deferred ~= nil, "and defers a loop")
if not loaded or not deferred then
  io.write("cannot continue\n")
  os.exit(1)
end

local E = dofile(HERE .. "/../reascripts/sb_engine.lua")

-- One frame, optionally clicking the nth button drawn.
local function frame(clickNth)
  imgui.buttons, imgui.tooltips = {}, {}
  imgui.sliders, imgui.checkboxes = {}, {}
  imgui.clickTarget, imgui.clicked = clickNth, nil
  imgui.idDepth, imgui.colDepth, imgui.widthDepth = 0, 0, 0
  local good, e = pcall(deferred)
  if not good then return false, e end
  if imgui.idDepth ~= 0 then return false, "unbalanced PushID: " .. imgui.idDepth end
  if imgui.colDepth ~= 0 then return false, "unbalanced PushStyleColor: " .. imgui.colDepth end
  if imgui.widthDepth ~= 0 then return false, "unbalanced PushItemWidth" end
  return true
end

------------------------------------------------------------------------------
-- Every panel draws
------------------------------------------------------------------------------

local good, e = frame()
ok(good, "the first frame draws: " .. tostring(e))
ok(#imgui.buttons > 0, "and puts buttons on screen")
ok(imgui.drawCalls > 0, "and draws the preview roll")

-- The category buttons are the way in to each panel, so find and click them.
local function clickLabel(label)
  frame()
  for i, l in ipairs(imgui.buttons) do
    if l == label then return frame(i) end
  end
  return false, "no button labelled " .. label
end

for _, cat in ipairs(E.CATEGORIES) do
  local g, err2 = clickLabel(cat)
  ok(g, "switching to " .. cat .. ": " .. tostring(err2))
  local g2, err3 = frame()
  ok(g2, cat .. " draws: " .. tostring(err3))
  ok(#imgui.buttons > 0, cat .. " has controls")
end

------------------------------------------------------------------------------
-- Every control, clicked
--
-- For each panel in turn, click the nth button and redraw, for every n. A
-- control that indexes off the end of a table, or leaves the state somewhere
-- the engine cannot generate from, shows up here.
------------------------------------------------------------------------------

local clicks, worst = 0, nil
for _, cat in ipairs(E.CATEGORIES) do
  clickLabel(cat)
  frame()
  local n = #imgui.buttons
  for i = 1, n do
    clickLabel(cat)                       -- back to a known panel each time
    local g, err2 = frame(i)
    clicks = clicks + 1
    if not g then
      worst = ("%s: clicking button %d (%s) raised: %s")
              :format(cat, i, tostring(imgui.clicked), tostring(err2))
      break
    end
    local g2, err3 = frame()              -- and the frame after it
    if not g2 then
      worst = ("%s: the frame after clicking %s raised: %s")
              :format(cat, tostring(imgui.clicked), tostring(err3))
      break
    end
  end
  if worst then break end
end
ok(worst == nil, "every control survives being clicked: " .. tostring(worst))
ok(clicks > 200, "and there were enough of them to mean something (" .. clicks .. ")")

------------------------------------------------------------------------------
-- Every slider, driven to both ends
--
-- The click sweep never moves a slider, so on its own it leaves every numeric
-- setting at its default and never finds out what the engine does with an
-- octave range of four or a gate of five.
------------------------------------------------------------------------------

do
  local names = {}
  frame()
  for _, cat in ipairs(E.CATEGORIES) do
    clickLabel(cat)
    frame()
    for _, l in ipairs(imgui.sliders) do names[l] = true end

    for _, mode in ipairs({ "max", "min", "max" }) do
      imgui.sliderMode = mode
      local g, err2 = frame()
      imgui.sliderMode = nil
      ok(g, ("%s with every slider at its %s: %s"):format(cat, mode, tostring(err2)))
      local g2, err3 = frame()          -- and the frame that reads them back
      ok(g2, ("%s after its sliders went to the %s: %s"):format(cat, mode, tostring(err3)))
    end
  end

  local n = 0
  for _ in pairs(names) do n = n + 1 end
  ok(n >= 6, "there are sliders to drive (" .. n .. ")")

  imgui.toggleBoxes = true
  local g, err2 = frame()
  imgui.toggleBoxes = false
  ok(g, "toggling the checkboxes: " .. tostring(err2))
  ok(frame(), "and the frame after")
end

------------------------------------------------------------------------------
-- Tooltips
------------------------------------------------------------------------------

frame()
ok(#imgui.tooltips > 0, "controls carry tooltips")

------------------------------------------------------------------------------
-- The block the window is holding is one the placement layer can take
--
-- What insert, place and export actually do is tests/test_place.lua's job.
-- What matters here is that the two halves fit together.
------------------------------------------------------------------------------

local Place = dofile(HERE .. "/../reascripts/sb_place.lua")
Place.setMidi(dofile(HERE .. "/../reascripts/sb_midi.lua"))

do
  for _, cat in ipairs(E.CATEGORIES) do
    local st2 = E.newState()
    st2.cat = cat
    local block = E.generate(st2)
    items = {}
    eq(Place.insert(block), Place.OK, "a " .. cat .. " block can be inserted")
    eq(#items[1].take.notes, #block.notes, "with all of its notes")
  end
end

------------------------------------------------------------------------------
-- Settings survive the window closing
------------------------------------------------------------------------------

do
  clickLabel("Drums")
  frame()
  reaper.atexitHandler()
  local blob = extstate["StartingBlocks:state"]
  ok(blob and blob ~= "", "closing saves the settings")
  ok(blob:match("cat=Drums"), "including which block was on screen")
  ok(blob:match("prog=[%d,]+"), "and the progression")

  -- Saving one thing and loading another is the classic way for settings to
  -- rot, so load the script again on top of what it just wrote and check it
  -- comes back up on the same block.
  deferred = nil
  local reloaded, err2 = pcall(dofile, SCRIPT)
  ok(reloaded, "the script loads again from its own saved settings: " .. tostring(err2))
  ok(deferred ~= nil, "and defers a loop")
  local g, err3 = frame()
  ok(g, "and draws: " .. tostring(err3))
  reaper.atexitHandler()
  ok(extstate["StartingBlocks:state"]:match("cat=Drums"),
     "on the block it was left on, not the default")
end

------------------------------------------------------------------------------
-- Settings from a project that knew a different version
--
-- A saved block can name a chord, a drum piece or an octave that this build
-- does not have. Every one of those is used to look something up or to fill a
-- slider, so none of them may arrive unchecked.
------------------------------------------------------------------------------

do
  local junk = {
    "root=99", "scale=99", "family=99", "chord=999", "dia=99", "rate=99",
    "rateMod=99", "runDir=99", "pattern=99", "interval=99", "melDir=9",
    "shape=99", "bassTone=99", "drumPiece=99", "drumPattern=99", "step=99",
    "inv=99", "oct=99", "bassOct=-99", "octaves=99", "vel=999", "gate=999",
    "baseOct=99", "bars=99", "degree=99", "cat=Sousaphone",
    "patternIsOrder=1", "progLen=99", "progBars=99", "progFollow=1",
    "prog=99,99,99,99,99,99,99,99,99,99,99,99",
  }
  extstate["StartingBlocks:state"] = table.concat(junk, ";")

  deferred = nil
  local loadedJunk, err2 = pcall(dofile, SCRIPT)
  ok(loadedJunk, "settings full of nonsense still load: " .. tostring(err2))
  ok(deferred ~= nil, "and the script still runs")
  local g, err3 = frame()
  ok(g, "and draws without reaching past the end of anything: " .. tostring(err3))

  -- And every panel, since each reads different settings.
  for _, cat in ipairs(E.CATEGORIES) do
    local g2, err4 = clickLabel(cat)
    ok(g2, cat .. " survives nonsense settings: " .. tostring(err4))
  end

  -- Negative and empty are their own kind of nonsense.
  extstate["StartingBlocks:state"] = "root=-5;scale=0;degree=-3;vel=-1;prog=;progLen=0"
  deferred = nil
  ok(pcall(dofile, SCRIPT), "negative and empty settings load")
  ok(frame(), "and draw")

  extstate["StartingBlocks:state"] = "this is not settings at all"
  deferred = nil
  ok(pcall(dofile, SCRIPT), "a blob that is not settings at all loads")
  ok(frame(), "and draws")
end

io.write(("%d checks, %d failure%s\n"):format(checks, failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
