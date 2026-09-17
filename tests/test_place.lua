--[[ Everything that touches REAPER, against a REAPER that only records.

     sb_place.lua is the half that used to need a separate bridge script and a
     shared-memory protocol to reach at all. Now it is an ordinary module, and
     a mocked reaper table is enough to check what it asks REAPER to do.

       lua5.4 tests/test_place.lua
       python3 tools/run_lua.py tests/test_place.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."

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
-- The mock
------------------------------------------------------------------------------

local tmpdir = "/tmp/starting-blocks-place-test"
os.execute('rm -rf "' .. tmpdir .. '" && mkdir -p "' .. tmpdir .. '"')

local items, stuffed = {}, {}
local cursor, tempo, tsNum, tsDen = 0, 120, 4, 4
local selected = "selected"
local undoDepth, undoNames = 0, {}

reaper = {
  Master_GetTempo = function() return tempo end,
  -- Three values, numerator first: there is no retval in front of them.
  TimeMap_GetTimeSigAtTime = function() return tsNum, tsDen, tempo end,
  GetCursorPosition = function() return cursor end,
  -- 120bpm, so one quarter note is half a second.
  TimeMap2_timeToQN = function(_, t) return t * (tempo / 60) end,
  TimeMap2_QNToTime = function(_, qn) return qn / (tempo / 60) end,

  GetSelectedTrack = function() return selected end,
  GetLastTouchedTrack = function() return nil end,

  CreateNewMIDIItemInProj = function(track, a, b)
    if track == "refuses" then return nil end
    local item = { track = track, pos = a, fin = b, take = { notes = {} } }
    items[#items + 1] = item
    return item
  end,
  GetActiveTake = function(i) return i.take end,
  MIDI_GetPPQPosFromProjQN = function(_, qn) return qn * 960 end,
  MIDI_InsertNote = function(take, sel, muted, sp, ep, ch, pitch, vel, noSort)
    take.notes[#take.notes + 1] =
      { sp = sp, ep = ep, ch = ch, pitch = pitch, vel = vel, noSort = noSort }
  end,
  MIDI_Sort = function(take) take.sorted = true end,
  GetSetMediaItemTakeInfo_String = function(take, k, v)
    if k == "P_NAME" then take.name = v end
  end,
  UpdateArrange = function() end,
  Undo_BeginBlock = function() undoDepth = undoDepth + 1 end,
  Undo_EndBlock = function(name)
    undoDepth = undoDepth - 1
    undoNames[#undoNames + 1] = name
  end,

  GetResourcePath = function() return tmpdir end,
  RecursiveCreateDirectory = function(p) os.execute('mkdir -p "' .. p .. '"') end,
  StuffMIDIMessage = function(mode, a, b, c)
    stuffed[#stuffed + 1] = { mode = mode, a = a, b = b, c = c }
  end,
  time_precise = function() return 0 end,
}

local Place = dofile(HERE .. "/../reascripts/sb_place.lua")
local Midi  = dofile(HERE .. "/../reascripts/sb_midi.lua")
local E     = dofile(HERE .. "/../reascripts/sb_engine.lua")
Place.setMidi(Midi)

local block = E.generate(E.newState())         -- C major I triad, one bar

------------------------------------------------------------------------------
-- Reading the project
------------------------------------------------------------------------------

eq(Place.tempo(), 120, "tempo")
do
  local n, d = Place.timeSig(0)
  eq(n, 4, "time signature numerator comes first")
  eq(d, 4, "then the denominator")
end
eq(Place.barBeats(), 4, "a 4/4 bar is four quarter notes")

tsNum, tsDen = 6, 8
eq(Place.barBeats(), 3, "a 6/8 bar is three")
tsNum, tsDen = 3, 4
eq(Place.barBeats(), 3, "a 3/4 bar is three")
tsNum, tsDen = 4, 4

-- A project that reports nothing sensible must not produce a zero-length bar.
local realTS = reaper.TimeMap_GetTimeSigAtTime
reaper.TimeMap_GetTimeSigAtTime = function() return 0, 0, 120 end
eq(Place.barBeats(), 4, "a nonsense time signature falls back to 4/4")
reaper.TimeMap_GetTimeSigAtTime = realTS

------------------------------------------------------------------------------
-- Inserting
------------------------------------------------------------------------------

do
  items, undoNames = {}, {}
  cursor = 2.0                                  -- two seconds in: quarter note 4
  eq(Place.insert(block), Place.OK, "insert reports success")
  eq(#items, 1, "one item created")
  eq(items[1].track, "selected", "on the selected track")
  eq(items[1].pos, 2.0, "starting at the edit cursor")
  eq(items[1].fin, 4.0, "a four-beat block at 120bpm is two seconds long")
  eq(items[1].take.name, block.name, "the take is named after the block")
  eq(#items[1].take.notes, #block.notes, "with every note in it")
  eq(items[1].take.notes[1].sp, 4 * 960, "placed relative to the cursor, in ticks")
  eq(items[1].take.notes[1].ep, (4 + 3.6) * 960, "and ending where the block says")
  eq(items[1].take.notes[1].pitch, 60, "pitch survives")
  eq(items[1].take.notes[1].vel, 100, "velocity survives")
  ok(items[1].take.sorted, "the take is sorted after a batch insert")
  ok(items[1].take.notes[1].noSort, "which is why each note went in unsorted")

  eq(undoDepth, 0, "the undo block is closed")
  eq(#undoNames, 1, "one undo point")
  ok(undoNames[1]:find(block.name, 1, true), "named after the block")
end

do
  -- With nothing selected there is nowhere obvious to put it.
  selected = nil
  eq(Place.insert(block), Place.NO_TRACK, "with no track, insert says so")
  selected = "selected"

  -- An empty block must not leave an empty item behind.
  items = {}
  eq(Place.insert({ notes = {}, beats = 4, name = "empty" }), Place.NOTHING,
     "an empty block is refused")
  eq(#items, 0, "and creates nothing")

  -- A refusal from REAPER has to close the undo block it opened.
  eq(Place.insert(block, "refuses"), Place.NO_TRACK, "a refused item is reported")
  eq(undoDepth, 0, "and does not leave an undo block open")
end

------------------------------------------------------------------------------
-- Exporting
------------------------------------------------------------------------------

do
  local status, path = Place.export(block)
  eq(status, Place.OK, "export reports success")
  ok(path and path:match("%.mid$"), "and names a .mid file")
  ok(path:find(Place.binPath(), 1, true) == 1, "inside the drag bin folder")

  local f = io.open(path, "rb")
  ok(f ~= nil, "which is on disk")
  if f then
    local data = f:read("a"); f:close()
    eq(data:sub(1, 4), "MThd", "and is a MIDI file")
    ok(#data > 20, "with something in it")
  end

  -- Exporting the same block twice gives two files, not one.
  local _, second = Place.export(block)
  ok(second ~= path, "a second export lands beside the first")
  ok(io.open(second, "rb") ~= nil, "and is also on disk")

  eq(Place.export({ notes = {}, beats = 4, name = "empty" }), Place.NOTHING,
     "an empty block is not written")
end

------------------------------------------------------------------------------
-- Auditioning
------------------------------------------------------------------------------

do
  local st = E.newState()
  st.cat = "Arpeggio"
  local arp = E.generate(st)

  stuffed = {}
  ok(Place.previewStart(arp, 120, 0), "audition starts")
  ok(Place.previewRunning(), "and reports itself running")

  local t, open, maxOpen = 0, 0, 0
  while Place.previewRunning() and t < 30 do
    t = t + 1 / 30                              -- about one defer's worth
    Place.previewTick(t, false)
  end
  ok(not Place.previewRunning(), "and ends on its own at the end of the block")

  for _, m in ipairs(stuffed) do
    eq(m.mode, 0, "notes go to the virtual keyboard")
    if m.a == 0x90 then open = open + 1 elseif m.a == 0x80 then open = open - 1 end
    maxOpen = math.max(maxOpen, open)
    ok(open >= 0, "never closes a note that was not open")
  end
  eq(open, 0, "every note auditioned is closed again")
  ok(maxOpen >= 1, "and something actually sounded")

  -- Stopping midway must not leave anything hanging.
  stuffed = {}
  Place.previewStart(arp, 120, 0)
  Place.previewTick(0.2, false)
  Place.previewStop()
  local held = 0
  for _, m in ipairs(stuffed) do
    if m.a == 0x90 then held = held + 1 elseif m.a == 0x80 then held = held - 1 end
  end
  eq(held, 0, "stopping releases whatever was sounding")
  ok(not Place.previewRunning(), "and the audition is over")

  -- Looping goes round instead of stopping, and releases across the seam.
  stuffed = {}
  Place.previewStart(arp, 120, 0)
  local wrapped = false
  for i = 1, 400 do
    local at = Place.previewTick(i / 30, true)
    if at == 0 and i > 2 then wrapped = true end
  end
  ok(wrapped, "a looping audition goes round again")
  ok(Place.previewRunning(), "and keeps running")
  Place.previewStop()

  held = 0
  for _, m in ipairs(stuffed) do
    if m.a == 0x90 then held = held + 1 elseif m.a == 0x80 then held = held - 1 end
  end
  eq(held, 0, "including across the loop point")

  eq(Place.previewStart({ notes = {}, beats = 4 }, 120, 0), false,
     "there is nothing to audition in an empty block")
end

io.write(("%d checks, %d failure%s\n"):format(checks, failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
