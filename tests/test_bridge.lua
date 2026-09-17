--[[ Headless test for the Starting Blocks bridge. The bridge is the half of
     the plugin that touches REAPER, so everything it touches is mocked here
     and the script itself is the real one off disk - the MIDI writer under
     test is the one that ships.

       lua5.4 tests/test_bridge.lua
       python3 tools/run_lua.py tests/test_bridge.lua   (if you have no lua)
]]

local HERE   = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SCRIPT = HERE .. "/../reascripts/Starting Blocks Bridge.lua"

local failures, checks = 0, 0

local function ok(cond, what)
  checks = checks + 1
  if not cond then
    failures = failures + 1
    io.write("FAIL  ", what, "\n")
  end
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
-- The mocks
------------------------------------------------------------------------------

local ext, gmem, deferred = {}, {}, nil
local console, inserted, items = {}, {}, {}
local tmpdir = os.getenv("SB_TMPDIR") or "/tmp/starting-blocks-test"
local cursorPos, selectedTrack, tempo = 0, "track1", 120

os.execute('rm -rf "' .. tmpdir .. '" && mkdir -p "' .. tmpdir .. '"')

reaper = {
  gmem_attach = function() end,
  gmem_read   = function(i) return gmem[i] or 0 end,
  gmem_write  = function(i, v) gmem[i] = v end,

  GetExtState = function(s, k) return ext[s .. ":" .. k] or "" end,
  SetExtState = function(s, k, v) ext[s .. ":" .. k] = v end,
  DeleteExtState = function(s, k) ext[s .. ":" .. k] = nil end,

  defer  = function(f) deferred = f end,
  atexit = function() end,
  get_action_context   = function() return true, "", 0, 1 end,
  set_action_options   = function() end,
  SetToggleCommandState= function() end,
  RefreshToolbar2      = function() end,
  ShowConsoleMsg       = function(s) console[#console + 1] = s end,

  GetResourcePath = function() return tmpdir end,
  RecursiveCreateDirectory = function(path)
    os.execute('mkdir -p "' .. path .. '"')
  end,

  -- 120bpm, so one quarter note is half a second.
  Master_GetTempo = function() return tempo end,
  TimeMap_GetTimeSigAtTime = function() return 0, 4, 4 end,
  TimeMap2_timeToQN = function(_, t) return t * (tempo / 60) end,
  TimeMap2_QNToTime = function(_, qn) return qn / (tempo / 60) end,

  GetCursorPosition   = function() return cursorPos end,
  GetSelectedTrack    = function() return selectedTrack end,
  GetLastTouchedTrack = function() return nil end,
  CreateNewMIDIItemInProj = function(track, a, b)
    local item = { track = track, pos = a, fin = b, take = { notes = {} } }
    items[#items + 1] = item
    return item
  end,
  GetActiveTake = function(item) return item.take end,
  MIDI_GetPPQPosFromProjQN = function(_, qn) return qn * 960 end,
  MIDI_InsertNote = function(take, _, _, sp, ep, ch, pitch, vel)
    take.notes[#take.notes + 1] =
      { sp = sp, ep = ep, ch = ch, pitch = pitch, vel = vel }
    inserted[#inserted + 1] = take.notes[#take.notes]
  end,
  MIDI_Sort = function() end,
  GetSetMediaItemTakeInfo_String = function(take, key, value)
    if key == "P_NAME" then take.name = value end
  end,
  UpdateArrange  = function() end,
  Undo_BeginBlock= function() end,
  Undo_EndBlock  = function() end,
}

--  The bridge keeps its working parts file-scope local, so read the source and
--  append one line that hands them out, exactly as ScaleView's suites do.
local src = assert(io.open(SCRIPT)):read("a")
assert(load(src .. [[

_G.__SB = { buildMidi = buildMidi, sanitise = sanitise, varlen = varlen,
            readBlock = readBlock, insertBlock = insertBlock,
            exportBlock = exportBlock, uniquePath = uniquePath,
            binPath = binPath, GM = GM }
]], "@" .. SCRIPT))()

local SB = assert(_G.__SB, "could not reach the bridge's internals")
local GM = SB.GM

------------------------------------------------------------------------------
-- A MIDI file reader, so the writer is checked against something that is not
-- itself.
------------------------------------------------------------------------------

local function parseMidi(data)
  local pos = 1
  local function u8()  local b = data:byte(pos); pos = pos + 1; return b end
  local function u16() return u8() * 256 + u8() end
  local function u32() return ((u8() * 256 + u8()) * 256 + u8()) * 256 + u8() end
  local function varint()
    local n = 0
    repeat local b = u8(); n = n * 128 + (b % 128) until b < 128
    return n
  end

  assert(data:sub(1, 4) == "MThd", "no MThd")
  pos = 5
  local hdrLen  = u32()
  local format  = u16()
  local ntracks = u16()
  local ppq     = u16()
  assert(data:sub(pos, pos + 3) == "MTrk", "no MTrk")
  pos = pos + 4
  local trkLen = u32()
  local trkEnd = pos + trkLen

  local tick, events, metas, ended = 0, {}, {}, false
  while pos < trkEnd do
    tick = tick + varint()
    local status = u8()
    if status == 0xFF then
      local mt  = u8()
      local len = varint()
      local payload = data:sub(pos, pos + len - 1)
      pos = pos + len
      metas[#metas + 1] = { type = mt, tick = tick, data = payload }
      if mt == 0x2F then ended = true end
    else
      local b2, b3 = u8(), u8()
      events[#events + 1] =
        { tick = tick, status = status, pitch = b2, vel = b3 }
    end
  end

  return {
    format = format, ntracks = ntracks, ppq = ppq, hdrLen = hdrLen,
    events = events, metas = metas, ended = ended,
    bytesUsed = pos, total = #data,
  }
end

------------------------------------------------------------------------------
-- varlen
------------------------------------------------------------------------------

eq(SB.varlen(0),    "\0",            "varlen 0")
eq(SB.varlen(127),  "\127",          "varlen 127")
eq(SB.varlen(128),  "\129\0",        "varlen 128")
eq(SB.varlen(8192), "\192\0",        "varlen 8192")
eq(SB.varlen(0x1FFFFF), "\255\255\127", "varlen 0x1FFFFF")
eq(SB.varlen(-5),   "\0",            "varlen clamps negatives")

------------------------------------------------------------------------------
-- The MIDI writer
------------------------------------------------------------------------------

local chord = {
  { start = 0, len = 3.6, pitch = 60, vel = 100 },
  { start = 0, len = 3.6, pitch = 64, vel = 100 },
  { start = 0, len = 3.6, pitch = 67, vel = 100 },
}
local m = parseMidi(SB.buildMidi(chord, 4, "C Major I Chord Triad", 120, 4, 4))

eq(m.format,  0, "format 0")
eq(m.ntracks, 1, "one track")
eq(m.ppq,   960, "960 ticks per quarter note")
eq(m.hdrLen,  6, "header length")
ok(m.ended,      "track ends with an end-of-track meta")
eq(m.bytesUsed - 1, m.total, "the track length matches the bytes written")
eq(#m.events, 6, "three notes make six events")

for i = 1, 3 do
  eq(m.events[i].status, 0x90, "event " .. i .. " is a note on")
  eq(m.events[i].tick, 0,      "event " .. i .. " starts at tick 0")
end
for i = 4, 6 do
  eq(m.events[i].status, 0x80,      "event " .. i .. " is a note off")
  eq(m.events[i].tick, 3.6 * 960,   "event " .. i .. " ends at 3.6 quarter notes")
end

-- The block is four beats long but the notes stop at 3.6, so the file has to
-- run on to the end of the bar or the item drags in short.
local endMeta
for _, meta in ipairs(m.metas) do if meta.type == 0x2F then endMeta = meta end end
eq(endMeta.tick, 4 * 960, "end of track sits at the end of the block")

local nameMeta, tempoMeta, tsMeta
for _, meta in ipairs(m.metas) do
  if meta.type == 0x03 then nameMeta  = meta end
  if meta.type == 0x51 then tempoMeta = meta end
  if meta.type == 0x58 then tsMeta    = meta end
end
eq(nameMeta and nameMeta.data, "C Major I Chord Triad", "track carries the block name")
eq(tempoMeta and #tempoMeta.data, 3, "tempo meta is three bytes")
eq(tempoMeta and (tempoMeta.data:byte(1) * 65536 + tempoMeta.data:byte(2) * 256 +
                  tempoMeta.data:byte(3)), 500000, "120bpm is 500000us per quarter note")
eq(tsMeta and tsMeta.data:byte(1), 4, "time signature numerator")
eq(tsMeta and tsMeta.data:byte(2), 2, "time signature denominator is stored as a power of two")

-- 6/8 stores 8 as 3.
local sixEight = parseMidi(SB.buildMidi(chord, 3, "x", 90, 6, 8))
for _, meta in ipairs(sixEight.metas) do
  if meta.type == 0x58 then
    eq(meta.data:byte(1), 6, "6/8 numerator")
    eq(meta.data:byte(2), 3, "6/8 denominator")
  end
end

-- A drum block: sixteen repeats of one pitch. Every note-off must land before
-- the next note-on at the same pitch or the notes run together.
local hits = {}
for i = 0, 15 do hits[#hits + 1] = { start = i * 0.25, len = 0.1, pitch = 42, vel = 90 } end
local hat = parseMidi(SB.buildMidi(hits, 4, "hats", 120, 4, 4))
eq(#hat.events, 32, "sixteen hits make thirty-two events")
local open = 0
for _, e in ipairs(hat.events) do
  open = open + (e.status == 0x90 and 1 or -1)
  ok(open >= 0 and open <= 1, "never more than one hi-hat sounding at a time")
end
eq(open, 0, "every note that opens is closed")

-- Two notes of the same pitch back to back at the same tick: the off has to
-- come first.
local runOn = parseMidi(SB.buildMidi({
  { start = 0,   len = 0.5, pitch = 60, vel = 90 },
  { start = 0.5, len = 0.5, pitch = 60, vel = 90 },
}, 1, "x", 120, 4, 4))
eq(runOn.events[2].status, 0x80, "at a shared tick the note off is written first")
eq(runOn.events[2].tick, runOn.events[3].tick, "the off and the next on share a tick")

-- A note shorter than a tick still has to be a note, not a zero-length one.
local tiny = parseMidi(SB.buildMidi(
  { { start = 0, len = 0.0001, pitch = 60, vel = 90 } }, 1, "x", 120, 4, 4))
ok(tiny.events[2].tick > tiny.events[1].tick, "a note is never zero ticks long")

------------------------------------------------------------------------------
-- Filenames
------------------------------------------------------------------------------

eq(SB.sanitise("C Major V Arp 6/9 Up 1-8"), "C Major V Arp 6_9 Up 1-8", "slashes go")
eq(SB.sanitise("Cmaj7#11"), "Cmaj7sharp11", "sharps are spelled out")
eq(SB.sanitise(""), "Block", "an empty name still gives a file")
eq(SB.sanitise("  spaced   out  "), "spaced out", "spaces are tidied")
ok(#SB.sanitise(string.rep("x", 400)) <= 80, "names are cut to a sane length")
ok(not SB.sanitise("../../etc/passwd"):find("/"), "no path separators survive")

------------------------------------------------------------------------------
-- Reading a block out of gmem
------------------------------------------------------------------------------

local function writeBlock(notes, beats, name)
  gmem = {}
  gmem[GM.NCOUNT] = #notes
  gmem[GM.BEATS]  = beats
  for i, nt in ipairs(notes) do
    local at = GM.NOTES + (i - 1) * 4
    gmem[at], gmem[at + 1], gmem[at + 2], gmem[at + 3] =
      nt.start, nt.len, nt.pitch, nt.vel
  end
  gmem[GM.NAMELEN] = #name
  for i = 1, #name do gmem[GM.NAME + i - 1] = name:byte(i) end
end

writeBlock(chord, 4, "C Major I Chord Triad")
local notes, beats, name = SB.readBlock()
eq(#notes, 3, "three notes read back")
eq(notes[1].pitch, 60, "first pitch")
eq(notes[3].pitch, 67, "third pitch")
eq(beats, 4, "block length")
eq(name, "C Major I Chord Triad", "block name")

-- A block with no notes and no length must not produce a zero-length item.
gmem = {}
local _, emptyBeats = SB.readBlock()
eq(emptyBeats, 4, "a missing length falls back to a bar")

------------------------------------------------------------------------------
-- Inserting
------------------------------------------------------------------------------

writeBlock(chord, 4, "C Major I Chord Triad")
cursorPos = 2.0                       -- two seconds in, so quarter note 4
inserted, items = {}, {}
local n2, b2, name2 = SB.readBlock()
eq(SB.insertBlock(n2, b2, name2), 0, "insert reports success")
eq(#items, 1, "one item created")
eq(items[1].pos, 2.0, "item starts at the edit cursor")
eq(items[1].fin, 4.0, "a four-beat block at 120bpm is two seconds long")
eq(items[1].take.name, "C Major I Chord Triad", "the take is named after the block")
eq(#inserted, 3, "three notes inserted")
eq(inserted[1].sp, 4 * 960, "notes are placed relative to the cursor, in ticks")
eq(inserted[1].ep, (4 + 3.6) * 960, "and end where the block says")
eq(inserted[1].pitch, 60, "pitch survives the trip")
eq(inserted[1].vel, 100, "velocity survives the trip")

selectedTrack = nil
eq(SB.insertBlock(n2, b2, name2), 2, "with no track, insert says so rather than failing quietly")
selectedTrack = "track1"

------------------------------------------------------------------------------
-- Exporting
------------------------------------------------------------------------------

eq(SB.exportBlock(chord, 4, "C Major I Chord Triad"), 1, "export reports success")
local first = SB.binPath() .. "/C Major I Chord Triad.mid"
local f = io.open(first, "rb")
ok(f ~= nil, "the file is on disk")
if f then
  local written = parseMidi(f:read("a"))
  f:close()
  eq(#written.events, 6, "the file on disk holds the block")
end

-- Exporting the same block again must not overwrite the first one.
SB.exportBlock(chord, 4, "C Major I Chord Triad")
local second = io.open(SB.binPath() .. "/C Major I Chord Triad 2.mid", "rb")
ok(second ~= nil, "a second export lands beside the first")
if second then second:close() end

------------------------------------------------------------------------------
-- The polling loop
------------------------------------------------------------------------------

ok(deferred ~= nil, "the script defers a loop on startup")
ok(ext["StartingBlocks:running"] == "1", "and marks itself as running")

local beforeHeartbeat = gmem[GM.HB]
writeBlock(chord, 4, "Loop Test")
gmem[GM.CMD] = 1
gmem[GM.SEQ] = 1
inserted, items = {}, {}
deferred()
eq(#items, 1, "a new sequence number is acted on")
eq(gmem[GM.ACK], 1, "and acknowledged")
eq(gmem[GM.STATUS], 0, "with a status the plugin can show")
ok(gmem[GM.HB] ~= beforeHeartbeat, "the heartbeat moves so the plugin knows we are here")

-- The same sequence number must not be acted on twice.
inserted, items = {}, {}
deferred()
eq(#items, 0, "the same request is not run again")

-- Running the action a second time sets a stop flag, and the loop reads it
-- and lets go rather than arming another defer.
local liveLoop = deferred
ext["StartingBlocks:stop"] = "1"
deferred = nil
liveLoop()
eq(deferred, nil, "the stop flag ends the loop")
eq(ext["StartingBlocks:stop"], nil, "and the flag is cleared behind it")

io.write(string.format("%d checks, %d failure%s\n",
                       checks, failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
