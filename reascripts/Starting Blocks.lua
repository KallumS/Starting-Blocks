--[[
 * ReaScript Name: Starting Blocks
 * Description:    A catalogue of the smallest useful pieces of music - chords,
 *                 arpeggios, runs, melodic steps and leaps, bass notes, single
 *                 drum hits - picked by key, scale and scale degree, and put
 *                 into the project as MIDI.
 *
 * About:          Pick a key. Pick a degree of it. Pick a block. Then insert it
 *                 at the edit cursor, write it out as a .mid, or audition it.
 *
 *                 Needs ReaImGui, from the ReaTeam Extensions repository.
 * Author:         Kallum Shah
 * Links:          https://github.com/KallumS/Starting-Blocks
 * Version:        2.3
 * Provides:
 *   sb_engine.lua
 *   sb_midi.lua
 *   sb_place.lua
--]]

local TITLE   = "Starting Blocks"
local SECTION = "StartingBlocks"

------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------

local imgui_path = reaper.ImGui_GetBuiltinPath and
                   (reaper.ImGui_GetBuiltinPath() .. "/imgui.lua")
if not imgui_path then
  reaper.MB("Starting Blocks needs the ReaImGui extension.\n\n" ..
            "Install it with ReaPack, from the ReaTeam Extensions repository.",
            "Missing dependency", 0)
  return
end
local ImGui = dofile(imgui_path)("0.9")

local HERE = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
local E     = dofile(HERE .. "sb_engine.lua")
local Midi  = dofile(HERE .. "sb_midi.lua")
local Place = dofile(HERE .. "sb_place.lua")
Place.setMidi(Midi)

------------------------------------------------------------------------------
-- Look
------------------------------------------------------------------------------

-- After Ableton Live 8's default theme: a mid-dark neutral grey chrome meant
-- to sit quietly under brightly coloured clips, controls raised a shade off it,
-- and one warm accent for whatever is on. Built from that description rather
-- than from the theme file - Live's .ask values are not published - so it is a
-- likeness, not a match.
local THEME = {
  { "Col_Text",              0xE4E4E4FF },
  { "Col_TextDisabled",      0x9C9C9CFF },
  { "Col_WindowBg",          0x4A4A4AFF },   -- the chrome
  { "Col_PopupBg",           0x3C3C3CFF },
  { "Col_Border",            0x363636FF },
  { "Col_FrameBg",           0x383838FF },   -- anything sunk into the chrome
  { "Col_FrameBgHovered",    0x424242FF },
  { "Col_FrameBgActive",     0x464646FF },
  { "Col_TitleBg",           0x3C3C3CFF },
  { "Col_TitleBgActive",     0x4A4A4AFF },
  { "Col_TitleBgCollapsed",  0x3C3C3CFF },
  { "Col_Button",            0x5E5E5EFF },   -- raised a shade off the chrome
  { "Col_ButtonHovered",     0x6E6E6EFF },
  { "Col_ButtonActive",      0x7A7A7AFF },
  { "Col_CheckMark",         0xD7A93CFF },
  { "Col_SliderGrab",        0x8A8A8AFF },
  { "Col_SliderGrabActive",  0xD7A93CFF },
  { "Col_Separator",         0x5A5A5AFF },
  { "Col_ScrollbarBg",       0x3A3A3AFF },
  { "Col_ScrollbarGrab",     0x6A6A6AFF },
  { "Col_ScrollbarGrabHovered", 0x7A7A7AFF },
  { "Col_ScrollbarGrabActive",  0x8A8A8AFF },
}

-- The warm accent. Live spends it on what is switched on, and so does this: a
-- chosen button and nothing else.
local SELECTED    = 0xD7A93CFF

-- The step numbers. Neutral: they show the order and nothing more.
local STEP        = 0xC8C8C8FF

-- The roll is drawn rather than composed of widgets. Dark like Live's MIDI
-- editor, with the notes in a cool tone so they never read as a selection.
local NOTE_COL    = 0xA8D8E8FF
local ROLL_BG     = 0x2E2E2EFF
local ROLL_BAR    = 0x5A5A5AFF
local ROLL_BEAT   = 0x3A3A3AFF
local PLAYHEAD    = 0xF2F2F2FF
local DIM         = 0x9C9C9CFF
local WARN        = 0xD2483FFF

-- Shifts a colour towards white or black, so the chosen state needs one colour
-- rather than three. Arithmetic rather than bit operators, like the MIDI
-- writer, so it does not care which Lua a REAPER build carries - and it keeps
-- the alpha byte, or ReaImGui is handed a fully transparent colour.
local function shade(col, amount)
  local a = col % 256
  local b = math.floor(col / 256) % 256
  local g = math.floor(col / 65536) % 256
  local r = math.floor(col / 16777216) % 256
  local function mix(c)
    if amount >= 0 then return math.floor(c + (255 - c) * amount + 0.5) end
    return math.floor(c * (1 + amount) + 0.5)
  end
  return mix(r) * 16777216 + mix(g) * 65536 + mix(b) * 256 + a
end

-- ReaImGui patches Dear ImGui so a top-level window can carry its own
-- background alpha, which a plain Dear ImGui window cannot. The same patch
-- covers corner rounding, but rounding the window did not show on screen, so
-- it is not here: an outer radius is the host window's to draw, not ours.

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

local st = E.newState()
local ui = {
  loop   = false,
  status = "",
  warn   = false,
  block  = nil,      -- the last generated block
  dirty  = true,
}

local ctx

local function rebuild()
  st.barBeats = Place.barBeats()
  ui.block = E.generate(st)
  ui.dirty = false
end

local function touched() ui.dirty = true end

local function say(text, warn)
  ui.status, ui.warn = text, warn or false
end

------------------------------------------------------------------------------
-- Settings that outlive the window
------------------------------------------------------------------------------

local SAVED = { "root", "scale", "degree", "cat", "family", "dia", "chord",
                "inv", "oct", "pattern", "runDir", "rate", "rateMod",
                "octaves", "repeats", "bars", "gate", "chop", "shuffle",
                "interval", "melDir", "shape", "bassTone", "bassOct",
                "drumPiece", "drumRate", "baseOct" }

local function saveState()
  local out = {}
  for _, k in ipairs(SAVED) do out[#out + 1] = k .. "=" .. tostring(st[k]) end
  reaper.SetExtState(SECTION, "state", table.concat(out, ";"), true)
end

local function loadState()
  local blob = reaper.GetExtState(SECTION, "state")
  if not blob or blob == "" then return end
  local got = {}
  for pair in blob:gmatch("[^;]+") do
    local k, v = pair:match("^(%w+)=(.*)$")
    if k then got[k] = v end
  end
  for _, k in ipairs(SAVED) do
    if got[k] then st[k] = tonumber(got[k]) or got[k] end
  end
  -- A saved setting may name something that no longer exists, or a degree the
  -- scale does not have, or a value past the end of the slider that shows it.
  -- The engine owns the tables, so it owns putting all of that back in range.
  E.clampState(st)
end


------------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------------

-- The whole theme goes on before Begin and comes off after End, so it covers
-- the window itself as well as everything in it.
local function pushTheme()
  for _, c in ipairs(THEME) do ImGui.PushStyleColor(ctx, ImGui[c[1]], c[2]) end
end
local function popTheme() ImGui.PopStyleColor(ctx, #THEME) end

-- An unchosen button wears the theme. A chosen one takes the warm accent, and
-- dark text with it, because the accent is far lighter than the chrome.
local function pick(label, selected, width)
  if selected then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, SELECTED)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, shade(SELECTED, 0.18))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, shade(SELECTED, -0.18))
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x2A2A2AFF)
  end
  local hit = ImGui.Button(ctx, label, width or 0, 0)
  if selected then ImGui.PopStyleColor(ctx, 4) end
  return hit
end

-- `n` numbers the step, for the three that are done in order.
local function heading(n, text)
  if n then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, STEP)
    ImGui.Text(ctx, tostring(n))
    ImGui.PopStyleColor(ctx, 1)
    ImGui.SameLine(ctx, 0, 10)
  end
  ImGui.SeparatorText(ctx, text)
end

-- The space between one numbered step and the next. There were arrows drawn in
-- here; taking them out and leaving the gap turned out to separate the steps
-- just as well, with nothing on screen to read.
local STEP_GAP = 22
local function stepGap() ImGui.Dummy(ctx, 16, STEP_GAP) end

local function tip(text)
  if text and ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, text) end
end

-- A wrapped row of choices. `get` reads the current one, `label`/`hint` name
-- each entry. Returns the index clicked, or nil.
local function chooser(id, items, current, perRow, width, label, hint)
  local chosen
  ImGui.PushID(ctx, id)
  for i, item in ipairs(items) do
    if i > 1 and (perRow == 0 or (i - 1) % perRow ~= 0) then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, i)
    if pick(label and label(item, i) or tostring(item), current == i, width) then
      chosen = i
    end
    if hint then tip(hint(item, i)) end
    ImGui.PopID(ctx)
  end
  ImGui.PopID(ctx)
  return chosen
end

local function slider(id, label, value, lo, hi, width)
  ImGui.PushItemWidth(ctx, width or 130)
  local changed, v = ImGui.SliderInt(ctx, label .. "##" .. id, value, lo, hi)
  ImGui.PopItemWidth(ctx)
  return changed, v
end

local function dim(text)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, DIM)
  ImGui.Text(ctx, text)
  ImGui.PopStyleColor(ctx, 1)
end

------------------------------------------------------------------------------
-- The preview roll
------------------------------------------------------------------------------

local function pianoRoll(block, width, height, playhead)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##roll", width, height)

  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, ROLL_BG, 3)
  if not block or #block.notes == 0 then return end

  local beats = math.max(block.beats, 1e-9)
  local bar   = math.max(st.barBeats, 1)
  local b = 0
  while b <= beats + 1e-9 do
    local gx = x + width * (b / beats)
    ImGui.DrawList_AddLine(dl, gx, y, gx, y + height,
                           (b % bar < 1e-9) and ROLL_BAR or ROLL_BEAT, 1)
    b = b + 1
  end

  local lo, hi = 200, -1
  for _, n in ipairs(block.notes) do
    lo, hi = math.min(lo, n.pitch), math.max(hi, n.pitch)
  end
  -- A repeated single note would fill the whole box, so always show at least
  -- an octave of context around it.
  if hi - lo < 11 then
    lo = math.max(0, math.floor((lo + hi) / 2) - 6)
    hi = lo + 12
  end
  local rowh = height / (hi - lo + 1)

  for _, n in ipairs(block.notes) do
    local nx = x + width * (n.start / beats)
    local nw = math.max(2, width * (n.len / beats) - 1)
    local ny = y + height - (n.pitch - lo + 1) * rowh
    ImGui.DrawList_AddRectFilled(dl, nx, ny, nx + nw,
                                 ny + math.max(2, rowh - 1), NOTE_COL, 1)
  end

  if playhead then
    local px = x + width * math.min(1, playhead)
    ImGui.DrawList_AddLine(dl, px, y, px, y + height, PLAYHEAD, 2)
  end
end

------------------------------------------------------------------------------
-- Shared controls
------------------------------------------------------------------------------

-- Straight, triplet or dotted. One setting shown on every panel, because a
-- block is in one feel or the other and the choice is the same question
-- wherever it is asked.
local function modRow()
  local m = chooser("ratemod", E.RATE_MODS, st.rateMod, 0, 72,
                    function(x) return x.name end,
                    function(x, i) return ({
                      "Notes fall where the grid says",
                      "Three in the space of two",
                      "Half as long again" })[i] end)
  if m then st.rateMod = m; touched() end
end

local function rateRow()
  dim("Rate")
  local r = chooser("rate", E.RATES, st.rate, 0, 54, function(x) return x.name end)
  if r then st.rate = r; touched() end
  ImGui.SameLine(ctx, 0, 16)
  modRow()
end

local function barsButtons()
  for i, b in ipairs(E.BAR_LENGTHS) do
    if i > 1 then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, "bars" .. i)
    if pick(b.name, math.abs(st.bars - b.bars) < 1e-9, 44) then
      st.bars = b.bars
      touched()
    end
    ImGui.PopID(ctx)
  end
end

local function barsRow()
  dim("Bars")
  barsButtons()
end

-- An arpeggio or a run is measured either by how many passes it plays or by a
-- length it fills, and which one is the user's to choose. Both say what a pass
-- costs, because the answer moves with the chord: a triad is three notes, a
-- thirteenth is seven.
local function lengthRow()
  local pass = E.passLength(st)
  dim("Length")

  local cur = 1
  for i, m in ipairs(E.LENGTH_MODES) do if m == st.lengthMode then cur = i end end
  local m = chooser("lenmode", E.LENGTH_MODES, cur, 0, 84)
  if m then st.lengthMode = E.LENGTH_MODES[m]; touched() end
  ImGui.SameLine(ctx, 0, 16)

  if st.lengthMode == "Bars" then
    barsButtons()
    ImGui.SameLine(ctx, 0, 14)
    dim(("%d notes a pass, cut wherever the bar ends"):format(pass))
  else
    local c, v = slider("repeats", "Repeats", st.repeats, 1, E.MAX_REPEATS, 150)
    if c then st.repeats = v; touched() end
    tip(("One pass is %d note%s, so this block is %d."):format(
        pass, pass == 1 and "" or "s", pass * st.repeats))
    ImGui.SameLine(ctx, 0, 14)
    dim(("%d notes a pass"):format(pass))
  end
end

local function commonTail(withOctaves, withOctave, withBars, withGate)
  local first = true
  local function gap() if not first then ImGui.SameLine(ctx, 0, 14) end; first = false end
  if withOctaves then
    gap()
    local c, v = slider("octaves", "Octaves", st.octaves, 1, 4, 110)
    if c then st.octaves = v; touched() end
  end
  if withOctave then
    gap()
    local c, v = slider("oct", "Octave", st.oct, -3, 3, 110)
    if c then st.oct = v; touched() end
  end
  if withGate then
    gap()
    local g, gv = slider("gate", "Gate %", st.gate, 5, 100, 130)
    if g then st.gate = gv; touched() end
  end
  if withBars then barsRow() end
end

-- Drawn in step 2, and again inside the Melody panel when a sustained note has
-- no shape to put there. It is the same setting either way - there is one
-- scale degree, shown where it is wanted.
local function degreeButtons(idPrefix)
  for d = 0, E.scaleLen(st) - 1 do
    if d > 0 then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, idPrefix .. d)
    if pick(E.degreeNumeral(st, d), st.degree == d, 62) then
      st.degree = d
      touched()
    end
    tip(E.degreeTitle(st, d) .. "  -  " .. E.noteName(st, d))
    ImGui.PopID(ctx)
  end
  ImGui.SameLine(ctx, 0, 16)
  dim(("%s   %s"):format(E.noteName(st, st.degree), E.degreeTitle(st, st.degree)))
end

------------------------------------------------------------------------------
-- Panels
------------------------------------------------------------------------------

local panels = {}

panels.Chord = function()
  dim("Family")
  local f = chooser("fam", E.FAMILIES, st.family, 0, 108)
  if f then
    st.family = f
    if f > 1 then
      for i, ch in ipairs(E.CHORDS) do
        if ch.fam == f then st.chord = i; break end
      end
    end
    touched()
  end

  dim("Chord")
  if st.family == 1 then
    local d = chooser("dia", E.DIATONIC, st.dia, 0, 74,
                      function(x) return x.name end,
                      function() return "Built from the scale itself, so it is always in key" end)
    if d then st.dia = d; touched() end
  else
    local shown, n = {}, 0
    for i, ch in ipairs(E.CHORDS) do
      if ch.fam == st.family then
        n = n + 1
        if n > 1 and (n - 1) % 8 ~= 0 then ImGui.SameLine(ctx) end
        ImGui.PushID(ctx, i)
        if pick(ch.sym, st.chord == i, 108) then st.chord = i; touched() end
        tip(ch.name .. "   -   semitones " .. table.concat(ch.iv, " "))
        ImGui.PopID(ctx)
      end
    end
  end

  ImGui.Dummy(ctx, 0, 4)
  dim("Inversion")
  local v = chooser("inv", E.INVERSIONS, st.inv + 1, 0, 58)
  if v then st.inv = v - 1; touched() end

  dim("Chop")
  local ch = chooser("chop", E.RATES, st.chop, 0, 54, function(x) return x.name end,
                     function(x) return "Strike the chord again every " .. x.name ..
                       " through the block" end)
  if ch then st.chop = ch; touched() end
  ImGui.SameLine(ctx, 0, 16)
  modRow()

  commonTail(false, true, true, true)
end

panels.Arpeggio = function()
  dim(("Chord:  %s   -   set it in the Chord tab"):format(E.chordLabel(st)))

  dim("Direction")
  local d = chooser("dir", E.DIRECTIONS, st.pattern, 0, 84)
  if d then st.pattern = d; touched() end

  rateRow()
  lengthRow()
  commonTail(true, true, false, true)
end

panels.Run = function()
  dim(("Runs the %s %s scale, starting on %s"):format(
    E.ROOTS[st.root].name, E.SCALES[st.scale].name, E.noteName(st, st.degree)))

  dim("Direction")
  local d = chooser("rundir", E.DIRECTIONS, st.runDir, 0, 84)
  if d then st.runDir = d; touched() end

  rateRow()
  lengthRow()
  commonTail(true, true, false, true)
end

panels.Melody = function()
  local held = E.isSustain(st)
  dim(held
      and "One note, held for the rate. The smallest melodic thing there is."
      or  "The two smallest moves in a melody: a step to the next scale note, or a leap past it.")

  dim("Interval")
  local i = chooser("mel", E.INTERVALS, st.interval, 0, 74,
                    function(x) return x.name end,
                    function(x) return x.hold and "One note, no move"
                      or (x.name == "2nd" and "The step" or "A leap") end)
  if i then st.interval = i; touched() end

  -- Nothing moves in a sustained note, so there is no direction to give it and
  -- no shape to put it in. The shape row makes way for the one thing that does
  -- decide the note: which degree it is.
  if held then
    dim("Scale degree")
    degreeButtons("meldeg")
  else
    ImGui.SameLine(ctx, 0, 16)
    if pick("Up", st.melDir == 1, 52) then st.melDir = 1; touched() end
    ImGui.SameLine(ctx)
    if pick("Down", st.melDir == 2, 52) then st.melDir = 2; touched() end

    dim("Shape")
    local sh = chooser("shape", E.SHAPES, st.shape, 0, 84, nil, function(_, k)
      return ({ "The move: two notes",
                "There and back: three notes",
                "Every scale note in between" })[k]
    end)
    if sh then st.shape = sh; touched() end
  end

  rateRow()
  commonTail(false, true, false, true)
end

panels.Bass = function()
  dim(("One note of the chord, on its own, low.   Chord:  %s"):format(E.chordLabel(st)))

  dim("Chord tone")
  local t = chooser("btone", E.BASS_TONES, st.bassTone, 0, 62)
  if t then st.bassTone = t; touched() end
  ImGui.SameLine(ctx, 0, 16)
  local c, v = slider("boct", "Octaves down", -st.bassOct, 0, 3, 130)
  if c then st.bassOct = -v; touched() end

  rateRow()
  commonTail(false, false, true, true)
end

panels.Drums = function()
  dim("One piece of the kit, hit at one rate. Stack a kit up by dropping in several.")

  dim("Piece")
  local p = chooser("drp", E.DRUM_PIECES, st.drumPiece, 0, 92,
                    function(x) return x.name end,
                    function(x) return "General MIDI note " .. x.note end)
  if p then st.drumPiece = p; touched() end

  local piece = E.DRUM_PIECES[st.drumPiece]
  if #piece.rates == 0 then
    -- Nothing to choose yet, and a control that does nothing is worse than no
    -- control, so say so instead of showing one.
    dim(("A single hit at the top of the bar. %s is still to be thought through.")
        :format(piece.name))
  else
    dim(piece.start > 0
        and ("Every  -  starting on beat %d"):format(piece.start + 1)
        or  "Every  -  starting at the top of the bar")
    for i, name in ipairs(piece.rates) do
      if i > 1 then ImGui.SameLine(ctx) end
      ImGui.PushID(ctx, "drate" .. i)
      if pick(name, st.drumRate == name, 54) then st.drumRate = name; touched() end
      ImGui.PopID(ctx)
    end
    ImGui.SameLine(ctx, 0, 16)
    modRow()

    dim("Shuffle")
    local c, v = slider("shuffle", "Shuffle %", st.shuffle, 0, 100, 150)
    if c then st.shuffle = v; touched() end
    tip("Pushes every second hit later. At 100 it lands two thirds of the way " ..
        "through the pair, which is the triplet feel a shuffle is named after.")
  end

  commonTail(false, false, true, false)
end

------------------------------------------------------------------------------
-- The frame
------------------------------------------------------------------------------

local function drawKey()
  heading(1, "Key")
  local r = chooser("root", E.ROOTS, st.root, 0, 44, function(x) return x.name end)
  if r then st.root = r; touched() end

  local s = chooser("scale", E.SCALES, st.scale, 8, 104, function(x) return x.name end)
  if s then
    st.scale = s
    st.degree = math.min(st.degree, E.scaleLen(st) - 1)
    touched()
  end
  stepGap()
end

local function drawDegree()
  heading(2, "Scale degree")
  degreeButtons("deg")
  stepGap()
end

local function drawActions()
  local block = ui.block
  heading(nil, block and block.name or "")

  local w = select(1, ImGui.GetContentRegionAvail(ctx))
  pianoRoll(block, math.max(120, w), 92,
            Place.previewRunning() and ui.playhead or nil)

  if block then
    local note = ("%d notes  /  %.2f beats"):format(#block.notes, block.beats)
    if block.truncated then note = note .. "   (buffer full - shorten the block)" end
    dim(note)
  end

  ImGui.Dummy(ctx, 0, 2)

  if pick("Insert at cursor", false, 150) then
    local r = Place.insert(block)
    if r == Place.OK then say("Inserted at the edit cursor")
    elseif r == Place.NOTHING then say("Nothing to insert", true)
    else say("No track selected", true) end
  end

  ImGui.SameLine(ctx)
  if pick("Export .mid", false, 120) then
    local r, path = Place.export(block)
    if r == Place.OK then say("Wrote " .. tostring(path))
    elseif r == Place.NOTHING then say("Nothing to write", true)
    else say("Could not write the file", true) end
  end

  ImGui.SameLine(ctx, 0, 16)
  if pick(Place.previewRunning() and "Stop" or "Audition",
          Place.previewRunning(), 96) then
    if Place.previewRunning() then
      Place.previewStop()
    else
      Place.previewStart(block, Place.tempo())
    end
  end
  tip("Plays through the virtual keyboard, so a record-armed monitored track " ..
      "will sound it. Timing is a preview, not a performance.")

  ImGui.SameLine(ctx)
  local _
  _, ui.loop = ImGui.Checkbox(ctx, "Loop", ui.loop)

  if ui.status ~= "" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, ui.warn and WARN or DIM)
    ImGui.Text(ctx, ui.status)
    ImGui.PopStyleColor(ctx, 1)
  end
end

local function frame()
  if ui.dirty then rebuild() end
  ui.playhead = Place.previewTick(nil, ui.loop)

  drawKey()
  drawDegree()

  heading(3, "Building block")
  for i, name in ipairs(E.CATEGORIES) do
    if i > 1 then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, "cat" .. i)
    if pick(name, st.cat == name, 96) then st.cat = name; touched() end
    ImGui.PopID(ctx)
  end

  stepGap()
  ;(panels[st.cat] or panels.Chord)()

  ImGui.Dummy(ctx, 0, 6)
  drawActions()
end

------------------------------------------------------------------------------
-- Running
------------------------------------------------------------------------------

local sectionID, cmdID

local function loop()
  ImGui.SetNextWindowSize(ctx, 1000, 760, ImGui.Cond_FirstUseEver)
  -- Solid rather than the half-transparent window ReaImGui opens by default.
  ImGui.SetNextWindowBgAlpha(ctx, 1.0)
  pushTheme()
  local visible, open = ImGui.Begin(ctx, TITLE, true)
  if visible then
    frame()
    ImGui.End(ctx)
  end
  popTheme()   -- outside the visible test: a push always needs its pop
  if open and not ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
    reaper.defer(loop)
  end
end

local function shutdown()
  Place.previewStop()
  saveState()
  if sectionID then
    reaper.SetToggleCommandState(sectionID, cmdID, 0)
    reaper.RefreshToolbar2(sectionID, cmdID)
  end
end

local function main()
  loadState()
  local _, _, sid, cid = reaper.get_action_context()
  sectionID, cmdID = sid, cid
  reaper.SetToggleCommandState(sectionID, cmdID, 1)
  reaper.RefreshToolbar2(sectionID, cmdID)
  reaper.atexit(shutdown)
  reaper.set_action_options(1)
  ctx = ImGui.CreateContext(TITLE)
  reaper.defer(loop)
end

main()
