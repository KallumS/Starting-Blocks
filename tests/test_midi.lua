--[[ The MIDI file writer, checked against a parser that is not itself.

     Carried over from the bridge suite when the plugin became a script; the
     writer is the same code, so its tests are the same tests.

       lua5.4 tests/test_midi.lua
       python3 tools/run_lua.py tests/test_midi.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SB   = dofile(HERE .. "/../reascripts/sb_midi.lua")

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
local m = parseMidi(SB.build(chord, 4, "C Major I Chord Triad", 120, 4, 4))

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
local sixEight = parseMidi(SB.build(chord, 3, "x", 90, 6, 8))
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
local hat = parseMidi(SB.build(hits, 4, "hats", 120, 4, 4))
eq(#hat.events, 32, "sixteen hits make thirty-two events")
local open = 0
for _, e in ipairs(hat.events) do
  open = open + (e.status == 0x90 and 1 or -1)
  ok(open >= 0 and open <= 1, "never more than one hi-hat sounding at a time")
end
eq(open, 0, "every note that opens is closed")

-- Two notes of the same pitch back to back at the same tick: the off has to
-- come first.
local runOn = parseMidi(SB.build({
  { start = 0,   len = 0.5, pitch = 60, vel = 90 },
  { start = 0.5, len = 0.5, pitch = 60, vel = 90 },
}, 1, "x", 120, 4, 4))
eq(runOn.events[2].status, 0x80, "at a shared tick the note off is written first")
eq(runOn.events[2].tick, runOn.events[3].tick, "the off and the next on share a tick")

-- A note shorter than a tick still has to be a note, not a zero-length one.
local tiny = parseMidi(SB.build(
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
ok(not SB.sanitise("..\\..\\windows"):find("\\"), "nor backslashes")

-- A block name that is already safe must come back untouched.
eq(SB.sanitise("C Major viidim Arp maj7 Up 1-8 x4"),
   "C Major viidim Arp maj7 Up 1-8 x4", "a clean name needs no cleaning up")

------------------------------------------------------------------------------
-- Nothing to write
------------------------------------------------------------------------------

do
  -- An empty block still has to be a valid file rather than a truncated one.
  local empty = parseMidi(SB.build({}, 4, "empty", 120, 4, 4))
  eq(#empty.events, 0, "no notes")
  ok(empty.ended, "but still a properly ended track")
  eq(empty.bytesUsed - 1, empty.total, "and a correct track length")
end

io.write(("%d checks, %d failure%s\n"):format(checks, failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
