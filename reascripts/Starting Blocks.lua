--[[
 * ReaScript Name: Starting Blocks
 * Description:    A catalogue of the smallest useful pieces of music - chords,
 *                 arpeggios, runs, melodic steps and leaps, bass notes, single
 *                 drum hits - picked by key, scale and scale degree, and put
 *                 into the project as MIDI.
 *
 * About:          Pick a key. Pick a degree of it. Pick a block. Then either
 *                 drop it where the mouse is, insert it at the edit cursor, or
 *                 write it out as a .mid.
 *
 *                 A progression is a sequence of degrees, and the Chord,
 *                 Arpeggio, Run and Bass blocks can follow it, which is what
 *                 turns single pieces into something that moves.
 *
 *                 Needs ReaImGui, from the ReaTeam Extensions repository.
 * Author:         Kallum Shah
 * Links:          https://github.com/KallumS/Starting-Blocks
 * Version:        2.0
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

local ACCENT      = 0x3A7FE6FF
local ACCENT_HOV  = 0x4E90F0FF
local ACCENT_ACT  = 0x2E6FD0FF
local NOTE_COL    = 0x57C78CFF
local ROLL_BG     = 0x15181CFF
local ROLL_BAR    = 0x3D434EFF
local ROLL_BEAT   = 0x262A31FF
local PLAYHEAD    = 0xF2CC4DFF
local DIM         = 0x8A909CFF
local WARN        = 0xE09A5AFF

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

local st = E.newState()
local ui = {
  snap    = true,
  loop    = false,
  status  = "",
  warn    = false,
  block   = nil,     -- the last generated block
  dirty   = true,
  armed   = false,   -- waiting for a click over the arrange
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
                "octaves", "bars", "vel", "gate", "interval", "melDir",
                "shape", "bassTone", "bassOct", "drumPiece", "drumPattern",
                "baseOct", "step" }

local function saveState()
  local out = {}
  for _, k in ipairs(SAVED) do out[#out + 1] = k .. "=" .. tostring(st[k]) end
  out[#out + 1] = "patternIsOrder=" .. (st.patternIsOrder and 1 or 0)
  out[#out + 1] = "progLen=" .. st.prog.len
  out[#out + 1] = "progBars=" .. st.prog.bars
  out[#out + 1] = "progFollow=" .. (st.prog.follow and 1 or 0)
  out[#out + 1] = "prog=" .. table.concat(st.prog.degrees, ",")
  out[#out + 1] = "snap=" .. (ui.snap and 1 or 0)
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
  if got.patternIsOrder then st.patternIsOrder = got.patternIsOrder == "1" end
  if got.progLen    then st.prog.len    = tonumber(got.progLen) or 4 end
  if got.progBars   then st.prog.bars   = tonumber(got.progBars) or 1 end
  if got.progFollow then st.prog.follow = got.progFollow == "1" end
  if got.snap       then ui.snap        = got.snap == "1" end
  if got.prog then
    local degs, i = {}, 0
    for d in got.prog:gmatch("[^,]+") do i = i + 1; degs[i] = tonumber(d) or 0 end
    if i > 0 then st.prog.degrees = degs end
  end
  -- A saved setting may name something that no longer exists, or a degree the
  -- scale does not have, or a value past the end of the slider that shows it.
  -- The engine owns the tables, so it owns putting all of that back in range.
  E.clampState(st)
end


------------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------------

local function pick(label, selected, width)
  if selected then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, ACCENT)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, ACCENT_HOV)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, ACCENT_ACT)
  end
  local hit = ImGui.Button(ctx, label, width or 0, 0)
  if selected then ImGui.PopStyleColor(ctx, 3) end
  return hit
end

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

local function rateRow()
  dim("Rate")
  local r = chooser("rate", E.RATES, st.rate, 0, 54,
                    function(x) return x.name end)
  if r then st.rate = r; touched() end
  ImGui.SameLine(ctx, 0, 16)
  local m = chooser("ratemod", E.RATE_MODS, st.rateMod, 0, 72,
                    function(x) return x.name end)
  if m then st.rateMod = m; touched() end
end

local function barsRow()
  dim("Bars")
  for i, n in ipairs({1, 2, 4, 8}) do
    if i > 1 then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, "bars" .. i)
    if pick(tostring(n), st.bars == n, 40) then st.bars = n; touched() end
    ImGui.PopID(ctx)
  end
end

local function followToggle()
  local on = st.prog.follow and st.prog.len > 1
  if pick(on and "Following the progression" or "Follow progression", on, 0) then
    st.prog.follow = not st.prog.follow
    touched()
  end
  if st.prog.len > 1 then
    tip("Lay this block out across the progression:  " ..
        E.progressionText(st, " - "))
  else
    tip("Set a progression of more than one step first, in the Progression tab")
  end
end

local function commonTail(withOctaves, withOctave, withBars, withGate)
  if withOctaves then
    local c, v = slider("octaves", "Octaves", st.octaves, 1, 4, 110)
    if c then st.octaves = v; touched() end
    ImGui.SameLine(ctx, 0, 14)
  end
  if withOctave then
    local c, v = slider("oct", "Octave", st.oct, -3, 3, 110)
    if c then st.oct = v; touched() end
    ImGui.SameLine(ctx, 0, 14)
  end
  local c, v = slider("vel", "Velocity", st.vel, 1, 127, 130)
  if c then st.vel = v; touched() end
  if withGate then
    ImGui.SameLine(ctx, 0, 14)
    local g, gv = slider("gate", "Gate %", st.gate, 5, 100, 130)
    if g then st.gate = gv; touched() end
  end
  if withBars then barsRow() end
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
  ImGui.SameLine(ctx, 0, 16)
  followToggle()

  commonTail(false, true, true, true)
end

panels.Arpeggio = function()
  dim(("Chord:  %s   -   set it in the Chord tab"):format(E.chordLabel(st)))

  dim("Direction")
  local d = chooser("dir", E.DIRECTIONS,
                    (not st.patternIsOrder) and st.pattern or 0, 0, 84)
  if d then st.pattern, st.patternIsOrder = d, false; touched() end

  dim("Fixed order")
  local o = chooser("ord", E.ORDERS, st.patternIsOrder and st.pattern or 0, 0, 84,
                    function(x) return x.name end,
                    function() return "The lowest three voices in that order; " ..
                      "anything above them follows, then the cell climbs an octave" end)
  if o then st.pattern, st.patternIsOrder = o, true; touched() end

  rateRow()
  commonTail(true, true, true, true)
  followToggle()
end

panels.Run = function()
  if E.follows(st) then
    dim(("Runs the scale from each step of  %s"):format(E.progressionText(st, " - ")))
  else
    dim(("Runs the %s %s scale, starting on %s"):format(
      E.ROOTS[st.root].name, E.SCALES[st.scale].name, E.noteName(st, st.degree)))
  end

  dim("Direction")
  local d = chooser("rundir", E.DIRECTIONS, st.runDir, 0, 84)
  if d then st.runDir = d; touched() end

  rateRow()
  commonTail(true, true, true, true)
  followToggle()
end

panels.Melody = function()
  dim("The two smallest moves in a melody: a step to the next scale note, or a leap past it.")

  dim("Interval")
  local i = chooser("mel", E.INTERVALS, st.interval, 0, 74)
  if i then st.interval = i; touched() end
  ImGui.SameLine(ctx, 0, 16)
  if pick("Up", st.melDir == 1, 52) then st.melDir = 1; touched() end
  ImGui.SameLine(ctx)
  if pick("Down", st.melDir == 2, 52) then st.melDir = 2; touched() end

  dim("Shape")
  local s = chooser("shape", E.SHAPES, st.shape, 0, 84, nil, function(_, k)
    return ({ "The move: two notes",
              "There and back: three notes",
              "Every scale note in between" })[k]
  end)
  if s then st.shape = s; touched() end

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
  followToggle()
end

panels.Drums = function()
  dim("One piece of the kit, one pattern, one bar. Stack a kit up by dropping in several.")

  dim("Piece")
  local p = chooser("drp", E.DRUM_PIECES, st.drumPiece, 0, 92,
                    function(x) return x.name end,
                    function(x) return "General MIDI note " .. x.note end)
  if p then st.drumPiece = p; touched() end

  dim("Pattern")
  local q = chooser("drs", E.DRUM_PATTERNS, st.drumPattern, 0, 118,
                    function(x) return x.name end,
                    function() return "Written on a 4/4 grid; hits past the end " ..
                      "of a shorter bar are dropped" end)
  if q then st.drumPattern = q; touched() end

  commonTail(false, false, true, false)
end

panels.Progression = function()
  dim("Preset")
  for i, p in ipairs(E.PROGRESSIONS) do
    local same = #p.degrees == st.prog.len
    if same then
      for k = 1, st.prog.len do
        if p.degrees[k] ~= st.prog.degrees[k] then same = false; break end
      end
    end
    if i > 1 and (i - 1) % 5 ~= 0 then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, "preset" .. i)
    if pick(p.name, same, 118) then
      st.prog.len = #p.degrees
      st.prog.degrees = {}
      for k = 1, E.MAX_PROG do st.prog.degrees[k] = p.degrees[k] or 0 end
      E.clampProgression(st)
      st.step = math.min(st.step, st.prog.len)
      touched()
    end
    ImGui.PopID(ctx)
  end

  ImGui.Dummy(ctx, 0, 4)
  dim("Steps  -  click one, then pick its degree at the top")
  for i = 1, st.prog.len do
    if i > 1 and (i - 1) % 12 ~= 0 then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, "step" .. i)
    if pick(E.degreeNumeral(st, st.prog.degrees[i] or 0), st.step == i, 64) then
      st.step = i
    end
    tip(("Step %d:  %s, the %s"):format(i, E.noteName(st, st.prog.degrees[i] or 0),
                                        E.degreeTitle(st, st.prog.degrees[i] or 0)))
    ImGui.PopID(ctx)
  end

  ImGui.Dummy(ctx, 0, 4)
  dim(("One %s on each step."):format(E.chordLabel(st)))

  local c, v = slider("plen", "Steps", st.prog.len, 1, E.MAX_PROG, 150)
  if c then
    st.prog.len = v
    for k = 1, E.MAX_PROG do st.prog.degrees[k] = st.prog.degrees[k] or 0 end
    st.step = math.min(st.step, st.prog.len)
    touched()
  end
  ImGui.SameLine(ctx, 0, 16)
  dim("Bars each")
  ImGui.SameLine(ctx)
  for _, n in ipairs({1, 2, 4}) do
    ImGui.PushID(ctx, "pbars" .. n)
    if pick(tostring(n), st.prog.bars == n, 40) then st.prog.bars = n; touched() end
    ImGui.PopID(ctx)
    ImGui.SameLine(ctx)
  end
  ImGui.NewLine(ctx)

  commonTail(false, true, false, true)
end

------------------------------------------------------------------------------
-- The frame
------------------------------------------------------------------------------

local function drawKey()
  ImGui.SeparatorText(ctx, "Key")
  local r = chooser("root", E.ROOTS, st.root, 0, 44, function(x) return x.name end)
  if r then st.root = r; touched() end

  local s = chooser("scale", E.SCALES, st.scale, 8, 104, function(x) return x.name end)
  if s then
    st.scale = s
    st.degree = math.min(st.degree, E.scaleLen(st) - 1)
    E.clampProgression(st)
    touched()
  end
end

local function drawDegree()
  local editingStep = st.cat == "Progression"
  local shown = editingStep and (st.prog.degrees[st.step] or 0) or st.degree

  ImGui.SeparatorText(ctx, editingStep
    and ("Scale degree  -  step %d of %d"):format(st.step, st.prog.len)
    or "Scale degree")

  for d = 0, E.scaleLen(st) - 1 do
    if d > 0 then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, "deg" .. d)
    if pick(E.degreeNumeral(st, d), shown == d, 62) then
      if editingStep then
        st.prog.degrees[st.step] = d
      else
        -- Clicking a degree while a block is following is as clear a way as
        -- there is of saying stop following.
        st.degree, st.prog.follow = d, false
      end
      touched()
    end
    tip(E.degreeTitle(st, d) .. "  -  " .. E.noteName(st, d))
    ImGui.PopID(ctx)
  end
  ImGui.SameLine(ctx, 0, 16)
  dim(("%s   %s"):format(E.noteName(st, shown), E.degreeTitle(st, shown)))
end

local function drawActions()
  local block = ui.block
  ImGui.SeparatorText(ctx, block and block.name or "")

  local w = select(1, ImGui.GetContentRegionAvail(ctx))
  pianoRoll(block, math.max(120, w), 92,
            Place.previewRunning() and ui.playhead or nil)

  if block then
    local note = ("%d notes  /  %.2f beats"):format(#block.notes, block.beats)
    if block.truncated then note = note .. "   (buffer full - shorten the block)" end
    dim(note)
  end

  ImGui.Dummy(ctx, 0, 2)

  if pick(ui.armed and "Click over the arrange..." or "Place with the mouse",
          ui.armed, 190) then
    ui.armed = not ui.armed
    say(ui.armed and "Move over the arrange and click to drop the block." or "")
  end
  tip("Pick the block up, then click on a track to put it down there")

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Insert at cursor", 150, 0) then
    local r = Place.insert(block)
    if r == Place.OK then say("Inserted at the edit cursor")
    elseif r == Place.NOTHING then say("Nothing to insert", true)
    else say("No track selected", true) end
  end

  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Export .mid", 120, 0) then
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
  local c
  c, ui.loop = ImGui.Checkbox(ctx, "Loop", ui.loop)
  ImGui.SameLine(ctx)
  c, ui.snap = ImGui.Checkbox(ctx, "Snap", ui.snap)

  if ui.status ~= "" then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, ui.warn and WARN or DIM)
    ImGui.Text(ctx, ui.status)
    ImGui.PopStyleColor(ctx, 1)
  end
end

-- While a block is held, a click anywhere over the arrange puts it down.
local function handleArmedClick()
  if not ui.armed then return end
  if not ImGui.IsMouseClicked(ctx, 0) then return end
  if ImGui.IsWindowHovered(ctx, ImGui.HoveredFlags_AnyWindow) then return end

  local r = Place.placeAtMouse(ui.block, ui.snap)
  if r == Place.OK then
    say("Dropped it where you clicked")
  elseif r == Place.NO_TRACK then
    say("That was not over a track - try again, or click Place again to cancel", true)
    return
  else
    say("Nothing to place", true)
  end
  ui.armed = false
end

local function frame()
  if ui.dirty then rebuild() end
  ui.playhead = Place.previewTick(nil, ui.loop)

  drawKey()
  drawDegree()

  ImGui.SeparatorText(ctx, "Building block")
  for i, name in ipairs(E.CATEGORIES) do
    if i > 1 then ImGui.SameLine(ctx) end
    ImGui.PushID(ctx, "cat" .. i)
    if pick(name, st.cat == name, 96) then st.cat = name; touched() end
    ImGui.PopID(ctx)
  end

  ImGui.Dummy(ctx, 0, 4)
  ;(panels[st.cat] or panels.Chord)()

  ImGui.Dummy(ctx, 0, 6)
  drawActions()
  handleArmedClick()
end

------------------------------------------------------------------------------
-- Running
------------------------------------------------------------------------------

local sectionID, cmdID

local function loop()
  ImGui.SetNextWindowSize(ctx, 1000, 760, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, TITLE, true)
  if visible then
    frame()
    ImGui.End(ctx)
  end
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
