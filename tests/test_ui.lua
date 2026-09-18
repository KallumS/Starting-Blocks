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
  idDepth = 0, colDepth = 0, widthDepth = 0, varDepth = 0,
  buttons = {}, sliders = {}, checkboxes = {},
  bgAlpha = nil, windowBg = nil, windowBgPushes = 0,
  highlights = {}, hovered = {}, held = {}, buttonColourPushes = 0,
  texts = {}, lines = {}, gaps = {},
  textColours = {}, drawColours = {},
  clickTarget = nil, clicked = nil,
  tooltips = {}, drawCalls = 0, maxIdDepth = 0,
}

local function count(name) imgui.calls[name] = (imgui.calls[name] or 0) + 1 end
imgui.calls = {}

local ImGui = {}

-- Constants ReaImGui exposes as plain values.
-- Distinct values, so the mock can tell which colour is being pushed rather
-- than only that one was.
for i, k in ipairs({ "Col_Button", "Col_ButtonHovered", "Col_ButtonActive",
                     "Col_Text", "Col_TextDisabled", "Col_WindowBg",
                     "Col_PopupBg", "Col_Border", "Col_FrameBg",
                     "Col_FrameBgHovered", "Col_FrameBgActive",
                     "Col_TitleBg", "Col_TitleBgActive", "Col_TitleBgCollapsed",
                     "Col_CheckMark", "Col_SliderGrab", "Col_SliderGrabActive",
                     "Col_Separator", "Col_ScrollbarBg", "Col_ScrollbarGrab",
                     "Col_ScrollbarGrabHovered", "Col_ScrollbarGrabActive",
                     "Cond_FirstUseEver", "Key_Escape",
                     "HoveredFlags_AnyWindow", "StyleVar_WindowRounding" }) do
  ImGui[k] = i
end

function ImGui.CreateContext(name) return { name = name } end
function ImGui.SetNextWindowSize() count("SetNextWindowSize") end
function ImGui.SetNextWindowBgAlpha(_, a)
  if type(a) ~= "number" or a < 0 or a > 1 then
    error("window background alpha is " .. tostring(a) .. ", not a 0..1 number")
  end
  imgui.bgAlpha = a
end
function ImGui.PushStyleVar(_, var, v)
  if var == nil then error("PushStyleVar with no variable") end
  if type(v) ~= "number" then error("style var value is a " .. type(v)) end
  imgui.varDepth = imgui.varDepth + 1
  imgui.windowRounding = (var == ImGui.StyleVar_WindowRounding) and v
                         or imgui.windowRounding
end
function ImGui.PopStyleVar(_, n)
  imgui.varDepth = imgui.varDepth - (n or 1)
  if imgui.varDepth < 0 then error("PopStyleVar without a push") end
end
function ImGui.Begin() count("Begin"); return true, true end
function ImGui.End() count("End") end
function ImGui.IsKeyPressed() return false end
function ImGui.SeparatorText(_, s) count("SeparatorText"); imgui.lastHeading = s end
function ImGui.Text(_, s)
  count("Text")
  if type(s) ~= "string" then error("Text got a " .. type(s)) end
  imgui.texts[#imgui.texts + 1] = s
end
function ImGui.Dummy(_, w, h)
  count("Dummy")
  imgui.gaps[#imgui.gaps + 1] = h
end
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
  if col % 256 == 0 then
    error(("style colour %08X is fully transparent - colours are 0xRRGGBBAA")
          :format(col))
  end
  if idx == ImGui.Col_WindowBg then
    imgui.windowBg = col
    imgui.windowBgPushes = imgui.windowBgPushes + 1
  end
  if idx == ImGui.Col_Button then
    imgui.highlights[col] = true
    imgui.buttonColourPushes = imgui.buttonColourPushes + 1
  end
  if idx == ImGui.Col_ButtonHovered then imgui.hovered[col] = true end
  if idx == ImGui.Col_ButtonActive  then imgui.held[col] = true end
  if idx == ImGui.Col_Text          then imgui.textColours[col] = true end
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
  imgui.drawColours[col] = true
end
function ImGui.DrawList_AddLine(_, x1, y1, x2, y2, col)
  imgui.drawCalls = imgui.drawCalls + 1
  if type(col) ~= "number" then error("line colour is a " .. type(col)) end
  for _, v in ipairs({ x1, y1, x2, y2 }) do
    if type(v) ~= "number" then error("line coordinate is a " .. type(v)) end
  end
  imgui.lines[col] = (imgui.lines[col] or 0) + 1
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

  GetSelectedTrack = function() return "track1" end,
  GetLastTouchedTrack = function() return nil end,

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
  imgui.idDepth, imgui.colDepth, imgui.widthDepth, imgui.varDepth = 0, 0, 0, 0
  imgui.bgAlpha, imgui.windowBg, imgui.windowBgPushes = nil, nil, 0
  imgui.highlights, imgui.textColours, imgui.drawColours = {}, {}, {}
  imgui.hovered, imgui.held = {}, {}
  imgui.buttonColourPushes = 0
  imgui.texts, imgui.lines, imgui.gaps = {}, {}, {}
  local good, e = pcall(deferred)
  if not good then return false, e end
  if imgui.idDepth ~= 0 then return false, "unbalanced PushID: " .. imgui.idDepth end
  if imgui.colDepth ~= 0 then return false, "unbalanced PushStyleColor: " .. imgui.colDepth end
  if imgui.widthDepth ~= 0 then return false, "unbalanced PushItemWidth" end
  if imgui.varDepth ~= 0 then return false, "unbalanced PushStyleVar: " .. imgui.varDepth end
  return true
end

------------------------------------------------------------------------------
-- Every panel draws
------------------------------------------------------------------------------

local good, e = frame()
ok(good, "the first frame draws: " .. tostring(e))
ok(#imgui.buttons > 0, "and puts buttons on screen")
ok(imgui.drawCalls > 0, "and draws the preview roll")

-- The window is solid rather than transparent. It is easy to lose in a later
-- edit and shows up nowhere else, so it is asserted rather than left to be
-- noticed missing.
eq(imgui.bgAlpha, 1.0, "the window background is fully opaque, not transparent")

-- The window carries a whole theme now. Two things have to hold: the theme
-- goes on once and comes off once, and a chosen button still looks different
-- from an unchosen one, or the window cannot be used.
do
  local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end

  -- Two colours paint buttons: the theme's, and the accent a chosen one takes.
  eq(count(imgui.highlights), 2, "the theme's button colour and the chosen one")
  ok(imgui.highlights[0xD7A93CFF], "a chosen button takes the warm accent")
  eq(count(imgui.hovered), 2, "each with a hover shade")
  eq(count(imgui.held), 2, "and a held shade")
  for col in pairs(imgui.highlights) do
    ok(col % 256 == 255, ("button colour %08X is fully opaque"):format(col))
  end

  -- The theme is pushed once a frame and popped once. Col_WindowBg belongs to
  -- the theme alone, so seeing it exactly once is what says so.
  eq(imgui.windowBgPushes, 1, "the theme goes on once a frame")
  ok(imgui.windowBg ~= nil, "and it sets the window's own background")
  eq(imgui.bgAlpha, 1.0, "which is solid rather than transparent")

  ok(imgui.drawColours[0xA8D8E8FF], "the MIDI notes have a colour of their own")
  ok(not imgui.highlights[0xA8D8E8FF], "which paints no button")
end

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
  -- A panel can hide a control behind another one - the drums only offer a
  -- shuffle for a piece that is hit more than once - so driving the sliders
  -- with each panel in its default state misses those. Click each control in
  -- turn and drive the sliders from there, which reaches the conditional ones
  -- without the test needing to know which they are.
  local names, worstSlider = {}, nil
  for _, cat in ipairs(E.CATEGORIES) do
    clickLabel(cat)
    frame()
    local buttons = #imgui.buttons

    for click = 0, buttons do
      clickLabel(cat)
      if click > 0 then frame(click) end
      frame()
      for _, l in ipairs(imgui.sliders) do names[l] = true end

      for _, mode in ipairs({ "max", "min" }) do
        imgui.sliderMode = mode
        local g, err2 = frame()
        imgui.sliderMode = nil
        if not g then
          worstSlider = ("%s: sliders at their %s raised: %s")
                        :format(cat, mode, tostring(err2))
          break
        end
        local g2, err3 = frame()        -- and the frame that reads them back
        if not g2 then
          worstSlider = ("%s: the frame after the %s raised: %s")
                        :format(cat, mode, tostring(err3))
          break
        end
      end
      if worstSlider then break end
    end
    if worstSlider then break end
  end
  ok(worstSlider == nil, "every slider survives both ends: " .. tostring(worstSlider))

  local found = {}
  for l in pairs(names) do found[#found + 1] = l end
  table.sort(found)
  -- Named rather than counted, so a control that stops being reachable shows
  -- up as a missing name instead of a number that quietly went down by one.
  eq(table.concat(found, ", "),
     "Gate %##gate, Octave##oct, Octaves down##boct, Octaves##octaves, " ..
     "Repeats##repeats, Shuffle %##shuffle",
     "every slider in the window is reached")

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
    "shape=99", "bassTone=99", "drumPiece=99", "drumPattern=99",
    "inv=99", "oct=99", "bassOct=-99", "octaves=99", "vel=999", "gate=999",
    "baseOct=99", "bars=99", "repeats=99", "degree=99", "cat=Sousaphone",
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
  extstate["StartingBlocks:state"] = "root=-5;scale=0;degree=-3;vel=-1;repeats=0"
  deferred = nil
  ok(pcall(dofile, SCRIPT), "negative and empty settings load")
  ok(frame(), "and draw")

  extstate["StartingBlocks:state"] = "this is not settings at all"
  deferred = nil
  ok(pcall(dofile, SCRIPT), "a blob that is not settings at all loads")
  ok(frame(), "and draws")
end

------------------------------------------------------------------------------
-- The clamps and the slider ranges have to agree
--
-- clampState decides the widest a setting may be; a slider declares the widest
-- it will show. ReaImGui refuses a value outside a slider's declared range, so
-- a setting that can legally reach 100 shown by a slider declared 0..50 is a
-- runtime error in REAPER. Loading state at both ends of every clamp and
-- drawing every panel is what finds it.
------------------------------------------------------------------------------

do
  local EXTREMES = {
    { "oct=3",      "oct=-3" },
    { "octaves=4",  "octaves=1" },
    { "gate=100",   "gate=5" },
    { "repeats=" .. E.MAX_REPEATS, "repeats=1" },
    { "shuffle=100", "shuffle=0" },
    { "bassOct=0",  "bassOct=-3" },
    { "bars=8",     "bars=1" },
    { "chop=" .. #E.RATES, "chop=1" },
    { "inv=3",      "inv=0" },
    { "baseOct=8",  "baseOct=0" },
  }

  for _, pair in ipairs(EXTREMES) do
    for _, setting in ipairs(pair) do
      extstate["StartingBlocks:state"] = setting
      deferred = nil
      local loadedIt = pcall(dofile, SCRIPT)
      ok(loadedIt, "loads with " .. setting)
      for _, cat in ipairs(E.CATEGORIES) do
        local g, err2 = clickLabel(cat)
        ok(g, ("%s with %s: %s"):format(cat, setting, tostring(err2)))
      end
    end
  end

  -- And all of them at once, on every drum piece, since the drums hide a
  -- slider behind which piece is chosen.
  extstate["StartingBlocks:state"] =
    "oct=3;octaves=4;gate=100;repeats=" .. E.MAX_REPEATS ..
    ";shuffle=100;bassOct=-3;bars=8;chop=1;inv=3;baseOct=8;cat=Drums"
  deferred = nil
  ok(pcall(dofile, SCRIPT), "loads with every setting at an extreme")
  frame()
  local n = #imgui.buttons
  local worst
  for i = 1, n do
    local g, err2 = frame(i)
    if not g then worst = ("button %d: %s"):format(i, tostring(err2)); break end
    if not frame() then worst = "the frame after button " .. i; break end
  end
  ok(worst == nil, "every drum piece draws at those extremes: " .. tostring(worst))
end

------------------------------------------------------------------------------
-- The order to do things in
--
-- Three numbered steps with an arrow from each to the next. The arrows are
-- drawn out of lines rather than set as a character, so what is asserted is
-- that the lines are there - a missing arrow is silent otherwise.
------------------------------------------------------------------------------

do
  frame()
  local STEP = 0xC8C8C8FF

  local seen = {}
  for _, t in ipairs(imgui.texts) do seen[t] = true end
  for _, n in ipairs({ "1", "2", "3" }) do
    ok(seen[n], "step " .. n .. " is numbered on screen")
  end
  ok(not seen["4"], "and there is no fourth step")

  -- The arrows that used to sit between the steps are gone; the space they
  -- took is what separates them now, so the space is what is checked.
  local wide = 0
  for _, h in ipairs(imgui.gaps) do if h == 22 then wide = wide + 1 end end
  eq(wide, 3, "three step gaps, one after each numbered step")
  ok(not imgui.lines[STEP], "and nothing is drawn in them")

  -- The step numbers are deliberately neutral. STEP is pushed as a text colour
  -- nowhere but on the numbers, so this is what holds that in place.
  ok(imgui.textColours[STEP], "the step numbers are neutral, not an accent")
end

io.write(("%d checks, %d failure%s\n"):format(checks, failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
