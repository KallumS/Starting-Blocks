--[[
 * ReaScript Name: Starting Blocks
 * Description:    A catalogue of the smallest useful pieces of music - chords,
 *                 arpeggios, runs, melodic steps and leaps - picked by key,
 *                 scale and scale degree, and put into the project as MIDI.
 *
 * About:          Pick a key. Pick a degree of it. Pick a block. Then insert it
 *                 at the edit cursor, write it out as a .mid, or audition it.
 *
 *                 Needs ReaImGui, from the ReaTeam Extensions repository.
 * Author:         Kallum Shah
 * Links:          https://github.com/KallumS/Starting-Blocks
 * Version:        2.5
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
            "Missing Extension", 0)
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

-- Three colours: a dark grey ground, a light grey for the controls raised off
-- it, and one yellow for whatever is switched on.
--
-- **Every grey here is blue-shifted** - R < G < B, all the way down the ramp.
-- That is deliberate and it is the easiest thing in this table to undo by
-- accident, because a neutral grey looks correct in a diff and only reads as
-- flat next to the yellow. The greys in this window were neutral for a long
-- time; they are not any more.
--
-- The dark end of the ramp is the ground and the roll, and it stops short of
-- black: flat black under a saturated yellow reads as a hole rather than a
-- surface.
local THEME = {
  { "Col_Text",              0xDDE1E7FF },
  -- Also the shortcut keys beside a menu item (Cmd+=), which are words to be
  -- read: #8A919C was 4.2:1 on the lighter menu. A disabled item is dimmed
  -- by ImGui on top of this, so it still looks disabled.
  { "Col_TextDisabled",      0xBFC5CEFF },
  { "Col_WindowBg",          0x23272EFF },   -- the chrome: dark grey, cool
  -- Menus and tooltips sit in front of the window, so they are a step lighter
  -- than it, as Apple's Dark Mode page asks of a surface raised over another,
  -- with a rule round them (final HIG sweep, 0009).
  { "Col_PopupBg",           0x2A2F37FF },
  { "Col_Border",            0x3A404AFF },
  { "Col_FrameBg",           0x1A1D23FF },   -- anything sunk into the chrome
  { "Col_FrameBgHovered",    0x22262DFF },
  { "Col_FrameBgActive",     0x2A2F37FF },
  { "Col_TitleBg",           0x1B1F25FF },
  { "Col_TitleBgActive",     0x23272EFF },
  { "Col_TitleBgCollapsed",  0x1B1F25FF },
  { "Col_MenuBarBg",         0x1B1F25FF },
  -- A menu item under the pointer. ImGui's own is a blue that leaves the
  -- words on it at 2.4:1; this grey keeps them at 8:1.
  { "Col_Header",            0x3A404AFF },
  { "Col_HeaderHovered",     0x3A404AFF },
  { "Col_HeaderActive",      0x3A404AFF },
  { "Col_Button",            0xA9AFBAFF },   -- the controls: light grey, raised
  { "Col_ButtonHovered",     0xC0C6CFFF },
  { "Col_ButtonActive",      0x8F96A2FF },
  { "Col_CheckMark",         0xFFF200FF },
  { "Col_SliderGrab",        0xA9AFBAFF },
  { "Col_SliderGrabActive",  0xFFF200FF },
  { "Col_Separator",         0x3A404AFF },
  { "Col_ScrollbarBg",       0x1A1D23FF },
  -- The scrollbar's grab and the corner that resizes the window are things to
  -- find and drag, so each is at least 3:1 on what it sits on.
  { "Col_ScrollbarGrab",     0x6D7581FF },
  { "Col_ScrollbarGrabHovered", 0x8F96A2FF },
  { "Col_ScrollbarGrabActive",  0xA9AFBAFF },
  { "Col_ResizeGrip",        0x6D7581FF },
  { "Col_ResizeGripHovered", 0xA9AFBAFF },
  { "Col_ResizeGripActive",  0xC0C6CFFF },
  -- The keyboard's focus ring: near-white, because yellow means "on" and a
  -- focused control need not be.
  { "Col_NavHighlight",      0xF2F4F7FF },
}

-- The accent, spent on what is switched on - and, unlike every scheme this
-- window has worn before it, on the notes too.
local SELECTED    = 0xFFF200FF

-- Ink. The buttons are lighter than the chrome now, so the text on one has to
-- go dark - on the grey and on the yellow alike. This is the only scheme here
-- where an unchosen button needs a text colour of its own.
local INK         = 0x14171CFF

-- The step numbers. Neutral: they show the order and nothing more.
local STEP        = 0xBFC5CEFF

-- The edge of a slider's track and of a box to tick. Their fill is sunk only a
-- shade below the ground, so without an edge a box with no tick in it is all
-- but invisible; this one is 3:1 on the ground, as anything that has to be
-- found to be used should be (4.7:1, as in the rest of the family).
local FRAME_EDGE  = 0x8A919CFF

-- The roll is drawn rather than composed of widgets. The dark end of the same
-- cool ramp, with the notes in the accent.
local NOTE_COL    = SELECTED
local ROLL_BG     = 0x111419FF
-- The bar lines say where each bar starts, so they are 3:1 on the roll (the
-- ramp's #3A404A was 1.8:1); the beat lines between them stay a faint guide.
local ROLL_BAR    = 0x6D7581FF
local ROLL_BEAT   = 0x1E2228FF
local PLAYHEAD    = 0xF2F4F7FF
-- Secondary text and warnings are 7:1 against the ground, Apple's target
-- for small text in a dark window (0009). The ramp's #8A919C was 4.7:1 and
-- the house red #D2483F 3.4:1, so neither is used for words any more.
local DIM         = 0xB0B6C0FF
local WARN        = 0xFF9E96FF

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

------------------------------------------------------------------------------
-- Apple's Human Interface Guidelines (0009, docs/apple-hig-review.md)
--
-- Text Size, in the View menu: Apple asks that text can be made at least
-- twice as big, and 13 points is the Mac's default text size. Every fixed
-- width in the window goes through px(), so it grows with the text. It is a
-- preference about the window, not the block, so it is saved under its own
-- key beside the engine's settings rather than in `st`.
------------------------------------------------------------------------------

local TEXT_SIZES = { 100, 125, 150, 200 }
-- The narrowest and shortest the window may be made, at 100%: every row
-- wraps, so this is about the widest single control, which at 200% is a
-- slider and its label.
local MIN_W, MIN_H = 320, 240
local BASE_TEXT = 13
local fonts = {}           -- one per size, made and attached once in main()
local S = 1                -- the chosen size as a scale: 1, 1.25, 1.5 or 2
ui.textSize = 1
local function px(n) return math.floor(n * S + 0.5) end

local function setTextSize(i)
  ui.textSize = math.max(1, math.min(#TEXT_SIZES, math.floor(tonumber(i) or 1)))
  S = TEXT_SIZES[ui.textSize] / 100
end

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
                "octaves", "repeats", "bars", "gate", "chop",
                "interval", "melDir", "shape", "baseOct" }

local function saveState()
  local out = {}
  for _, k in ipairs(SAVED) do out[#out + 1] = k .. "=" .. tostring(st[k]) end
  reaper.SetExtState(SECTION, "state", table.concat(out, ";"), true)
  reaper.SetExtState(SECTION, "view", "textSize=" .. ui.textSize, true)
end

local function loadState()
  -- The window's own preference, clamped by setTextSize.
  setTextSize((reaper.GetExtState(SECTION, "view") or ""):match("textSize=([%-%d%.]+)"))
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

-- The text size and Apple's Mac control: 28 points tall at 100% (a 13-point
-- line and 7.5 above and below), about 12 points between controls. Pushed
-- before Begin and popped after End, like the theme.
local SIZE_VARS = 3
local function pushSize()
  ImGui.PushFont(ctx, fonts[ui.textSize])
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, px(8), 7.5 * S)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, px(12), px(12))
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing, px(8), px(6))
end
local function popSize()
  ImGui.PopStyleVar(ctx, SIZE_VARS)
  ImGui.PopFont(ctx)
end

-- A button's width: the width asked for (0 is its label's), grown with the
-- text size, and never narrower than its label, so nothing is cut short.
local function fit(label, width)
  local text = label:gsub("##.*$", "")
  return math.max(px(width or 0), select(1, ImGui.CalcTextSize(ctx, text)) + px(16))
end

-- An unchosen button wears the theme's grey. A chosen one takes the accent.
-- Either way the text on it goes to INK: both are far lighter than the chrome,
-- so the window's own light text would vanish on them.
local function pick(label, selected, width)
  local pushed = 1
  if selected then
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, SELECTED)
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, shade(SELECTED, 0.18))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, shade(SELECTED, -0.18))
    pushed = 4
  end
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, INK)
  local hit = ImGui.Button(ctx, label, fit(label, width), 0)
  ImGui.PopStyleColor(ctx, pushed)
  -- Not colour alone: a chosen button also carries a bar under its label.
  if selected then
    local x1 = ImGui.GetItemRectMin(ctx)
    local x2, y2 = ImGui.GetItemRectMax(ctx)
    ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx),
                                 x1 + px(8), y2 - px(5), x2 - px(8), y2 - px(3), INK)
  end
  return hit
end

-- A row of controls that wraps at the window's edge, so nothing in it is ever
-- cut off however narrow the window or large the text. `flowStart` begins a
-- row on a fresh line; `flowNextW` places the next thing, `w` wide, beside the
-- last if it fits and under it if not. Every row of the window goes through
-- these rather than a bare SameLine, which would push its end off the edge.
local flowX, flowAvail
local function flowStart()
  flowX = nil
  flowAvail = select(1, ImGui.GetContentRegionAvail(ctx))
end
local function flowNextW(w)
  if not flowX then flowX = w; return end
  if flowX + px(12) + w <= flowAvail then
    ImGui.SameLine(ctx, 0, px(12))
    flowX = flowX + px(12) + w
  else
    flowX = w
  end
end
local function flowNext(label, width) flowNextW(fit(label, width)) end

local function textWidth(s) return (select(1, ImGui.CalcTextSize(ctx, s))) end

-- How wide a slider is with its label beside it, and a box with its label.
local function sliderWidth(label, width)
  return px(width or 130) + px(8) + textWidth((label:gsub("##.*$", "")))
end
local function checkWidth(label) return px(28) + px(8) + textWidth(label) end

-- Words in a row: beside the last control if they fit, else on a line of their
-- own, wrapped at the window's edge rather than running past it.
local function flowText(s, col)
  flowNextW(math.min(textWidth(s), flowAvail))
  if col then ImGui.PushStyleColor(ctx, ImGui.Col_Text, col) end
  ImGui.TextWrapped(ctx, s)
  if col then ImGui.PopStyleColor(ctx, 1) end
end

-- `n` numbers the step, for the three that are done in order.
local function heading(n, text)
  if n then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, STEP)
    ImGui.Text(ctx, tostring(n))
    ImGui.PopStyleColor(ctx, 1)
    ImGui.SameLine(ctx, 0, px(10))
  end
  ImGui.SeparatorText(ctx, text)
end

-- The space between one numbered step and the next. There were arrows drawn in
-- here; taking them out and leaving the gap turned out to separate the steps
-- just as well, with nothing on screen to read.
local STEP_GAP = 22
local function stepGap() ImGui.Dummy(ctx, px(16), px(STEP_GAP)) end

-- A tooltip, wrapped at about 60 characters so a long one stays a readable
-- paragraph, and inside the screen at 200%. ReaImGui shows it for the control
-- the keyboard is on as well as the one under the pointer.
local function tip(text)
  if text and ImGui.IsItemHovered(ctx) and ImGui.BeginTooltip(ctx) then
    ImGui.PushTextWrapPos(ctx, px(420))
    ImGui.Text(ctx, text)
    ImGui.PopTextWrapPos(ctx)
    ImGui.EndTooltip(ctx)
  end
end

-- A wrapped row of choices. `get` reads the current one, `label`/`hint` name
-- each entry. Returns the index clicked, or nil.
local function chooser(id, items, current, perRow, width, label, hint, cont)
  local chosen
  if not cont then flowStart() end
  ImGui.PushID(ctx, id)
  for i, item in ipairs(items) do
    local text = label and label(item, i) or tostring(item)
    if i > 1 and perRow ~= 0 and (i - 1) % perRow == 0 then flowX = nil end
    flowNext(text, width)
    ImGui.PushID(ctx, i)
    if pick(text, current == i, width) then
      chosen = i
    end
    if hint then tip(hint(item, i)) end
    ImGui.PopID(ctx)
  end
  ImGui.PopID(ctx)
  return chosen
end

-- A slider's track and a tick box get an edge (FRAME_EDGE), so either can be
-- found on the ground before it is used.
local function framed()
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, math.max(1, px(1)))
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, FRAME_EDGE)
end
local function unframed()
  ImGui.PopStyleColor(ctx, 1)
  ImGui.PopStyleVar(ctx, 1)
end

-- A slider, placed in the current row; `hint` says what it does.
local function slider(id, label, value, lo, hi, width, hint)
  flowNextW(sliderWidth(label, width))
  ImGui.PushItemWidth(ctx, px(width or 130))
  framed()
  local changed, v = ImGui.SliderInt(ctx, label .. "##" .. id, value, lo, hi)
  unframed()
  ImGui.PopItemWidth(ctx)
  tip(hint)
  return changed, v
end

local function checkbox(label, value, hint)
  flowNextW(checkWidth(label))
  framed()
  local _, v = ImGui.Checkbox(ctx, label, value)
  unframed()
  tip(hint)
  return v
end

-- Secondary words on a line of their own, wrapped at the window's edge.
local function dim(text)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, DIM)
  ImGui.TextWrapped(ctx, text)
  ImGui.PopStyleColor(ctx, 1)
end
local function dimBeside(text) flowText(text, DIM) end

------------------------------------------------------------------------------
-- The preview roll
------------------------------------------------------------------------------

local function pianoRoll(block, width, height, playhead)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##roll", width, height)

  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, ROLL_BG, px(3))
  if not block or #block.notes == 0 then return end

  local beats = math.max(block.beats, 1e-9)
  local bar   = math.max(st.barBeats, 1)
  local b = 0
  while b <= beats + 1e-9 do
    local gx = x + width * (b / beats)
    ImGui.DrawList_AddLine(dl, gx, y, gx, y + height,
                           (b % bar < 1e-9) and ROLL_BAR or ROLL_BEAT, math.max(1, px(1)))
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
    local nw = math.max(px(2), width * (n.len / beats) - 1)
    local ny = y + height - (n.pitch - lo + 1) * rowh
    ImGui.DrawList_AddRectFilled(dl, nx, ny, nx + nw,
                                 ny + math.max(px(2), rowh - 1), NOTE_COL, px(1))
  end

  if playhead then
    local hx = x + width * math.min(1, playhead)
    ImGui.DrawList_AddLine(dl, hx, y, hx, y + height, PLAYHEAD, px(2))
  end
end

------------------------------------------------------------------------------
-- Shared controls
------------------------------------------------------------------------------

-- Straight, triplet or dotted. One setting shown on every panel, because a
-- block is in one feel or the other and the choice is the same question
-- wherever it is asked.
local function modRow(cont)
  local m = chooser("ratemod", E.RATE_MODS, st.rateMod, 0, 72,
                    function(x) return x.name end,
                    function(x, i) return ({
                      "Notes fall where the grid says.",
                      "Three in the space of two",
                      "Half as long again" })[i] end, cont)
  if m then st.rateMod = m; touched() end
end

local function rateRow()
  dim("Rate")
  local r = chooser("rate", E.RATES, st.rate, 0, 54, function(x) return x.name end)
  if r then st.rate = r; touched() end
  modRow(true)
end

local function barsButtons(cont)
  if not cont then flowStart() end
  for i, b in ipairs(E.BAR_LENGTHS) do
    flowNext(b.name, 44)
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

  if st.lengthMode == "Bars" then
    barsButtons(true)
    dimBeside(("%d notes a pass, cut wherever the bar ends"):format(pass))
  else
    local c, v = slider("repeats", "Repeats", st.repeats, 1, E.MAX_REPEATS, 150,
      ("How many times the pattern plays. One pass is %d note%s, so this block is %d."):format(
        pass, pass == 1 and "" or "s", pass * st.repeats))
    if c then st.repeats = v; touched() end
    dimBeside(("%d notes a pass"):format(pass))
  end
end

local function commonTail(withOctaves, withOctave, withBars, withGate)
  flowStart()
  if withOctaves then
    local c, v = slider("octaves", "Octaves", st.octaves, 1, 4, 110,
                        "How many octaves the pattern climbs before it turns.")
    if c then st.octaves = v; touched() end
  end
  if withOctave then
    local c, v = slider("oct", "Octave", st.oct, -3, 3, 110,
                        "Moves the whole block up or down by octaves.")
    if c then st.oct = v; touched() end
  end
  if withGate then
    local g, gv = slider("gate", "Gate %", st.gate, 5, 100, 130,
                         "How much of its time each note sounds: 100% joins the " ..
                         "notes up, less leaves a gap after each.")
    if g then st.gate = gv; touched() end
  end
  if withBars then barsRow() end
end

-- Drawn in step 2, and again inside the Melody panel when a sustained note has
-- no shape to put there. It is the same setting either way - there is one
-- scale degree, shown where it is wanted.
local function degreeButtons(idPrefix)
  flowStart()
  for d = 0, E.scaleLen(st) - 1 do
    flowNext(E.degreeNumeral(st, d), 62)
    ImGui.PushID(ctx, idPrefix .. d)
    if pick(E.degreeNumeral(st, d), st.degree == d, 62) then
      st.degree = d
      touched()
    end
    tip(E.degreeTitle(st, d) .. " — " .. E.noteName(st, d))
    ImGui.PopID(ctx)
  end
  dimBeside(("%s   %s"):format(E.noteName(st, st.degree), E.degreeTitle(st, st.degree)))
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
        if n == 1 then flowStart() end
        flowNext(ch.sym, 108)
        ImGui.PushID(ctx, i)
        if pick(ch.sym, st.chord == i, 108) then st.chord = i; touched() end
        tip(ch.name .. " — semitones " .. table.concat(ch.iv, " "))
        ImGui.PopID(ctx)
      end
    end
  end

  ImGui.Dummy(ctx, 0, px(4))
  -- Only the inversions this chord has: two for a triad, three for a
  -- seventh, up to six for a thirteenth. A chord with fewer than the one
  -- chosen takes its last.
  dim("Inversion")
  st.inv = math.min(st.inv, E.inversionCount(st))
  local v = chooser("inv", E.inversionNames(st), st.inv + 1, 0, 58)
  if v then st.inv = v - 1; touched() end

  dim("Chop")
  local ch = chooser("chop", E.RATES, st.chop, 0, 54, function(x) return x.name end,
                     function(x) return "Strike the chord again every " .. x.name ..
                       " through the block" end)
  if ch then st.chop = ch; touched() end
  modRow(true)

  commonTail(false, true, true, true)
end

panels.Arpeggio = function()
  dim(("Chord: %s — set it in the Chord panel"):format(E.chordLabel(st)))

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
    dim("Scale Degree")
    degreeButtons("meldeg")
  else
    flowNext("Up", 52)
    if pick("Up", st.melDir == 1, 52) then st.melDir = 1; touched() end
    flowNext("Down", 52)
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
  heading(2, "Scale Degree")
  degreeButtons("deg")
  stepGap()
end

local function drawActions()
  local block = ui.block
  heading(nil, block and block.name or "")

  local w = select(1, ImGui.GetContentRegionAvail(ctx))
  pianoRoll(block, math.max(px(120), w), px(92),
            Place.previewRunning() and ui.playhead or nil)

  if block then
    local note = ("%d notes, %.2f beats"):format(#block.notes, block.beats)
    if block.truncated then note = note .. " — too many notes, so the end is cut off. Shorten the block." end
    dim(note)
  end

  ImGui.Dummy(ctx, 0, px(2))

  flowStart()
  if Place.dragOut then
    -- In the plugin there is no edit cursor to insert at: the block is
    -- dragged out of the window onto a track instead (plugin/lua/sb_place.lua).
    flowNext("Drag into Song", 150)
    if pick("Drag into Song", false, 150) then
      say("Drag this button onto a track to put the block there as a MIDI clip.")
    end
    if ImGui.IsItemActive(ctx) and ImGui.IsMouseDragging(ctx, 0) then
      if not ui.dragging then
        ui.dragging = true
        local r = Place.dragOut(block)
        if r == Place.NOTHING then say("There are no notes to drag.", true)
        elseif r ~= Place.OK then say("The block couldn’t be written out to drag. Try Export MIDI File.", true) end
      end
    else
      ui.dragging = false
    end
    tip("Drag it onto a track in your song: the block goes there as a MIDI clip.")
  else
    flowNext("Insert at Cursor", 150)
    if pick("Insert at Cursor", false, 150) then
      local r = Place.insert(block)
      if r == Place.OK then say("Inserted at the edit cursor.")
      elseif r == Place.NOTHING then say("There are no notes to insert.", true)
      else say("No track is selected. Select a track, then insert again.", true) end
    end
  end

  flowNext("Export MIDI File", 140)
  if pick("Export MIDI File", false, 140) then
    local r, path = Place.export(block)
    if r == Place.OK then say("Saved " .. tostring(path))
    elseif r == Place.NOTHING then say("There are no notes to save.", true)
    elseif Place.HOST == "plugin" then say("The MIDI file couldn’t be saved. Check that your Music folder can be written to.", true)
    else say("The MIDI file couldn’t be saved. Check that REAPER’s resource folder can be written to.", true) end
  end

  local playLabel = Place.previewRunning() and "Stop" or "Audition"
  flowNext(playLabel, 96)
  if pick(playLabel, Place.previewRunning(), 96) then
    if Place.previewRunning() then
      Place.previewStop()
    else
      Place.previewStart(block, Place.tempo())
    end
  end
  if Place.HOST == "plugin" then
    tip("Plays through the plugin’s MIDI output, to the instrument after it, at the song’s tempo.")
  else
    tip("Plays through the virtual keyboard, so a record-armed monitored track " ..
        "will sound it. Timing is a preview, not a performance.")
  end

  ui.loop = checkbox("Loop", ui.loop,
                     "When this is on, Audition starts again from the top until you click Stop.")

  if Place.setPlayingWithSong then
    Place.setPlayingWithSong(checkbox("Play with the Song", Place.playingWithSong(),
      "When this is on, the block plays over and over while the song plays, " ..
      "lined up with its bars, through the plugin’s MIDI output."))
  end

end

-- The View menu: Text Size, with the Mac's own zoom keys.
local SHORTCUT_KEY = (reaper.GetOS():find("OSX") or reaper.GetOS():find("mac")) and "Cmd" or "Ctrl"
local function menuBar()
  if not ImGui.BeginMenuBar(ctx) then return end
  if ImGui.BeginMenu(ctx, "View") then
    for i, size in ipairs(TEXT_SIZES) do
      local keys = (i == 1 and SHORTCUT_KEY .. "+0") or nil
      if ImGui.MenuItem(ctx, ("Text Size %d%%"):format(size), keys, ui.textSize == i) then
        setTextSize(i)
      end
    end
    ImGui.Separator(ctx)
    if ImGui.MenuItem(ctx, "Bigger Text", SHORTCUT_KEY .. "+=", false, ui.textSize < #TEXT_SIZES) then
      setTextSize(ui.textSize + 1)
    end
    if ImGui.MenuItem(ctx, "Smaller Text", SHORTCUT_KEY .. "+-", false, ui.textSize > 1) then
      setTextSize(ui.textSize - 1)
    end
    ImGui.EndMenu(ctx)
  end
  ImGui.EndMenuBar(ctx)
end

-- Cmd (Ctrl on Windows) with =, - or 0, as in every Mac app that zooms.
local function zoomKeys()
  if ImGui.GetKeyMods(ctx) & ImGui.Mod_Shortcut == 0 then return end
  if ImGui.IsKeyPressed(ctx, ImGui.Key_Equal) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadAdd) then
    setTextSize(ui.textSize + 1)
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Minus) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadSubtract) then
    setTextSize(ui.textSize - 1)
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_0) then
    setTextSize(1)
  end
end

-- What just happened, at the top of the window where it cannot fall off
-- the bottom of the screen, and there until it is dismissed or replaced:
-- Apple asks for nothing that goes away on a timer.
local function drawMessage()
  if ui.status == "" then return end
  flowStart()
  flowText(ui.status, ui.warn and WARN or DIM)
  flowNext("Dismiss")
  if pick("Dismiss", false) then say("") end
end

local function frame()
  if ui.dirty then rebuild() end
  ui.playhead = Place.previewTick(nil, ui.loop)

  menuBar()
  zoomKeys()
  drawMessage()
  drawKey()
  drawDegree()

  heading(3, "Building Block")
  flowStart()
  for i, name in ipairs(E.CATEGORIES) do
    flowNext(name, 96)
    ImGui.PushID(ctx, "cat" .. i)
    if pick(name, st.cat == name, 96) then st.cat = name; touched() end
    ImGui.PopID(ctx)
  end

  stepGap()
  ;(panels[st.cat] or panels.Chord)()

  ImGui.Dummy(ctx, 0, px(6))
  drawActions()
end

------------------------------------------------------------------------------
-- Running
------------------------------------------------------------------------------

local sectionID, cmdID

-- Escape lets go of what has the keyboard before it closes anything: with the
-- focus ring on a control, or a menu open, the first Escape takes the ring or
-- the menu away (ReaImGui does that itself) and the window stays. Only an
-- Escape with nothing in hand closes it. ImGui has already acted on this
-- frame's Escape by the time the window is drawn, so it is last frame's
-- answer that decides.
local escBusy = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 1000, 760, ImGui.Cond_FirstUseEver)
  -- Never so small that a control falls out of reach.
  ImGui.SetNextWindowSizeConstraints(ctx, px(MIN_W), px(MIN_H), 100000, 100000)
  -- Solid rather than the half-transparent window ReaImGui opens by default.
  ImGui.SetNextWindowBgAlpha(ctx, 1.0)
  pushTheme()
  pushSize()
  -- The title names the block on screen; after ### is the window's own id,
  -- so a new name does not make it a new window.
  if ui.dirty then
    rebuild()
    -- In the plugin, the block on screen is the one it plays, and the
    -- settings are saved with the project, so both go over at once.
    if Place.follow then Place.follow(ui.block); saveState() end
  end
  local name = ui.block and ui.block.name or ""
  local visible, open = ImGui.Begin(ctx, (name ~= "" and (TITLE .. " — " .. name) or TITLE)
                                    .. "###" .. TITLE, true, ImGui.WindowFlags_MenuBar)
  local busy = false
  if visible then
    frame()
    busy = ImGui.IsAnyItemFocused(ctx)
           or ImGui.IsPopupOpen(ctx, "", ImGui.PopupFlags_AnyPopup)
    ImGui.End(ctx)
  end
  popSize()
  popTheme()   -- outside the visible test: a push always needs its pop
  local escape = ImGui.IsKeyPressed(ctx, ImGui.Key_Escape)
  -- (A plugin's window belongs to the host, which closes it.)
  local close = escape and not escBusy and Place.HOST ~= "plugin"
  escBusy = busy
  if open and not close then
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
  -- The keyboard alone: Tab and the arrow keys move between controls, Space
  -- or Return presses one, and a ring shows where you are.
  ctx = ImGui.CreateContext(TITLE, ImGui.ConfigFlags_NavEnableKeyboard)
  for i, size in ipairs(TEXT_SIZES) do
    fonts[i] = ImGui.CreateFont("sans-serif", math.floor(BASE_TEXT * size / 100 + 0.5))
    ImGui.Attach(ctx, fonts[i])
  end
  reaper.defer(loop)
end

main()
