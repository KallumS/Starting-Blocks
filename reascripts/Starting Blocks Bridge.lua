--[[
 * ReaScript Name: Starting Blocks Bridge
 * Description:    Gives the Starting Blocks JSFX its two ways out of the
 *                 plugin - inserting a block on a track, and writing one to
 *                 disk as a .mid file to drag in from the Media Explorer.
 * About:          JSFX cannot write files and cannot see the REAPER API, so
 *                 the plugin hands a finished block over through gmem and this
 *                 script does the part that needs REAPER.
 *
 *                 Run it once and leave it running; it is a toggle, so running
 *                 it again stops it. While it runs the plugin's header shows
 *                 "Bridge connected".
 *
 *                 Exported files land in
 *                   <REAPER resource path>/Starting Blocks/
 *                 Point the Media Explorer at that folder once and every block
 *                 you export from then on is one drag away from the arrange.
 * Author:         Kallum Shah
 * Links:          https://github.com/KallumS/Starting-Blocks
 * Version:        1.0
--]]

local SEP     = package.config:sub(1, 1)
local SECTION = "StartingBlocks"
local PPQ     = 960

-- gmem layout, shared with jsfx/Starting Blocks.jsfx. Keep the two in step.
local GM = {
  MAGIC = 0, SEQ = 1, CMD = 2, ACK = 3, STATUS = 4, NCOUNT = 5,
  BEATS = 6, HB = 7, NAMELEN = 8, TRACK = 9, HFLAGS = 10,
  NAME = 16, NOTES = 128,
}

-- What the plugin shows for each status it reads back.
local OK_INSERT, OK_EXPORT, NO_TRACK, WRITE_FAILED = 0, 1, 2, 3

local MAX_NOTES = 1024
local MAX_NAME  = 96

------------------------------------------------------------------------------
-- Writing a MIDI file
--
-- Format 0, one track, 960 ticks to the quarter note. Everything is written
-- with arithmetic rather than bit operators so the script does not care which
-- Lua a given REAPER build carries.
------------------------------------------------------------------------------

local function be16(n)
  return string.char(math.floor(n / 256) % 256, n % 256)
end

local function be32(n)
  return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256,
                     math.floor(n / 256) % 256, n % 256)
end

-- MIDI's variable length quantity: seven bits per byte, high bit set on every
-- byte but the last.
local function varlen(n)
  n = math.max(0, math.floor(n))
  local bytes = { n % 128 }
  n = math.floor(n / 128)
  while n > 0 do
    table.insert(bytes, 1, (n % 128) + 128)
    n = math.floor(n / 128)
  end
  local out = {}
  for i = 1, #bytes do out[i] = string.char(bytes[i]) end
  return table.concat(out)
end

local function meta(typeByte, payload)
  return string.char(0xFF, typeByte) .. varlen(#payload) .. payload
end

-- notes are { start, len, pitch, vel } in quarter notes; beats is how long the
-- whole block is, which is what decides where the file ends.
local function buildMidi(notes, beats, name, bpm, tsNum, tsDen)
  local ev = {}
  for _, nt in ipairs(notes) do
    local on  = math.floor(nt.start * PPQ + 0.5)
    local off = math.floor((nt.start + nt.len) * PPQ + 0.5)
    if off <= on then off = on + 1 end
    ev[#ev + 1] = { tick = on,  order = 1, b1 = 0x90, b2 = nt.pitch, b3 = nt.vel }
    ev[#ev + 1] = { tick = off, order = 0, b1 = 0x80, b2 = nt.pitch, b3 = 0 }
  end

  -- At a shared tick the note-offs go first, so a repeated note is not cut
  -- short by the release of the one before it.
  table.sort(ev, function(a, b)
    if a.tick  ~= b.tick  then return a.tick  < b.tick  end
    if a.order ~= b.order then return a.order < b.order end
    return a.b2 < b.b2
  end)

  local trk = {}
  trk[#trk + 1] = varlen(0) .. meta(0x03, name)

  local usPerQN = math.floor(60000000 / math.max(bpm, 1) + 0.5)
  trk[#trk + 1] = varlen(0) .. meta(0x51, string.char(
    math.floor(usPerQN / 65536) % 256,
    math.floor(usPerQN / 256) % 256,
    usPerQN % 256))

  -- The time signature meta wants the denominator as a power of two.
  local dd, d = 0, math.max(1, math.floor(tsDen))
  while d > 1 do d = d / 2; dd = dd + 1 end
  trk[#trk + 1] = varlen(0) .. meta(0x58,
    string.char(math.max(1, math.min(255, math.floor(tsNum))), dd, 24, 8))

  local last = 0
  for _, e in ipairs(ev) do
    trk[#trk + 1] = varlen(e.tick - last) ..
                    string.char(e.b1, e.b2 % 128, e.b3 % 128)
    last = e.tick
  end

  -- End the track at the end of the block, not at the last note-off, so an
  -- empty tail (a one-beat hit inside a four-beat bar) survives the trip.
  local endTick = math.max(math.floor(beats * PPQ + 0.5), last)
  trk[#trk + 1] = varlen(endTick - last) .. meta(0x2F, "")

  local body = table.concat(trk)
  return "MThd" .. be32(6) .. be16(0) .. be16(1) .. be16(PPQ) ..
         "MTrk" .. be32(#body) .. body
end

------------------------------------------------------------------------------
-- Files
------------------------------------------------------------------------------

-- Block names carry things a filename should not: slashes in 6/9, sharps,
-- parentheses. Keep letters, digits, space and a few safe marks.
local function sanitise(name)
  local s = (name or ""):gsub("[^%w%s%-%+#&%.]", "_")
  s = s:gsub("#", "sharp"):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then s = "Block" end
  return s:sub(1, 80)
end

local function binPath()
  return reaper.GetResourcePath() .. SEP .. "Starting Blocks"
end

local function fileExists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

-- Exporting the same block twice should give you two files, not one.
local function uniquePath(dir, base)
  local path = dir .. SEP .. base .. ".mid"
  local n = 2
  while fileExists(path) do
    path = dir .. SEP .. base .. " " .. n .. ".mid"
    n = n + 1
    if n > 999 then return nil end
  end
  return path
end

------------------------------------------------------------------------------
-- Reading a block out of gmem
------------------------------------------------------------------------------

local function readBlock()
  local n = math.max(0, math.min(MAX_NOTES, math.floor(reaper.gmem_read(GM.NCOUNT))))
  local notes = {}
  for i = 0, n - 1 do
    notes[#notes + 1] = {
      start = reaper.gmem_read(GM.NOTES + i * 4),
      len   = reaper.gmem_read(GM.NOTES + i * 4 + 1),
      pitch = math.floor(reaper.gmem_read(GM.NOTES + i * 4 + 2)),
      vel   = math.floor(reaper.gmem_read(GM.NOTES + i * 4 + 3)),
    }
  end

  local nameLen = math.max(0, math.min(MAX_NAME, math.floor(reaper.gmem_read(GM.NAMELEN))))
  local chars = {}
  for i = 0, nameLen - 1 do
    chars[#chars + 1] = string.char(math.floor(reaper.gmem_read(GM.NAME + i)) % 256)
  end

  local beats = reaper.gmem_read(GM.BEATS)
  if not beats or beats <= 0 then beats = 4 end

  return notes, beats, table.concat(chars)
end

------------------------------------------------------------------------------
-- The two things the plugin can ask for
------------------------------------------------------------------------------

-- Where the block lands. A selected track wins, because that is the one the
-- user is pointing at. Failing that, the plugin tells us over gmem which track
-- it is sitting on, which is almost always the one they meant anyway - and it
-- is the difference between Insert working and Insert saying "no track".
local function targetTrack()
  local track = reaper.GetSelectedTrack(0, 0)
  if track then return track end

  local idx    = math.floor(reaper.gmem_read(GM.TRACK) or -1)
  local flags  = math.floor(reaper.gmem_read(GM.HFLAGS) or 0)
  local isTake = flags % 2 == 1
  if idx >= 0 and not isTake then
    -- get_host_placement counts tracks from zero, the same way GetTrack does.
    track = reaper.GetTrack(0, idx)
    if track then return track end
  end

  return reaper.GetLastTouchedTrack()
end

local function insertBlock(notes, beats, name)
  local track = targetTrack()
  if not track then return NO_TRACK end

  local pos     = reaper.GetCursorPosition()
  local startQN = reaper.TimeMap2_timeToQN(0, pos)
  local endTime = reaper.TimeMap2_QNToTime(0, startQN + beats)

  reaper.Undo_BeginBlock()
  local item = reaper.CreateNewMIDIItemInProj(track, pos, endTime, false)
  if not item then reaper.Undo_EndBlock("Starting Blocks", -1); return NO_TRACK end

  local take = reaper.GetActiveTake(item)
  for _, nt in ipairs(notes) do
    local sp = reaper.MIDI_GetPPQPosFromProjQN(take, startQN + nt.start)
    local ep = reaper.MIDI_GetPPQPosFromProjQN(take, startQN + nt.start + nt.len)
    reaper.MIDI_InsertNote(take, false, false, sp, ep, 0, nt.pitch, nt.vel, true)
  end
  reaper.MIDI_Sort(take)
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)

  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Starting Blocks: insert " .. name, -1)
  return OK_INSERT
end

local announcedFolder = false

local function exportBlock(notes, beats, name)
  local dir = binPath()
  reaper.RecursiveCreateDirectory(dir, 0)

  local path = uniquePath(dir, sanitise(name))
  if not path then return WRITE_FAILED end

  local bpm, tsNum, tsDen = reaper.Master_GetTempo(), 4, 4
  -- Three return values, and the first of them is the numerator: there is no
  -- retval in front of it.
  local num, den = reaper.TimeMap_GetTimeSigAtTime(0, reaper.GetCursorPosition())
  if num and num > 0 and den and den > 0 then tsNum, tsDen = num, den end

  local f = io.open(path, "wb")
  if not f then return WRITE_FAILED end
  f:write(buildMidi(notes, beats, name, bpm, tsNum, tsDen))
  f:close()

  -- Say where the files go, once, so the folder is findable without reading
  -- the README.
  if not announcedFolder then
    announcedFolder = true
    reaper.ShowConsoleMsg("Starting Blocks: exporting to " .. dir ..
      "\nPoint the Media Explorer here and drag the .mid files into the arrange.\n")
  end
  return OK_EXPORT
end

------------------------------------------------------------------------------
-- The loop
------------------------------------------------------------------------------

local heartbeat = 0
local lastSeq   = -1
local sectionID, cmdID

local function handle(cmd, notes, beats, name)
  if #notes == 0 then return WRITE_FAILED end
  if cmd == 1 then return insertBlock(notes, beats, name) end
  if cmd == 2 then return exportBlock(notes, beats, name) end
  return WRITE_FAILED
end

local function loop()
  if reaper.GetExtState(SECTION, "stop") == "1" then
    reaper.DeleteExtState(SECTION, "stop", false)
    return
  end

  heartbeat = (heartbeat + 1) % 1000000
  reaper.gmem_write(GM.HB, heartbeat)

  local seq = reaper.gmem_read(GM.SEQ)
  if seq and seq > 0 and seq ~= lastSeq then
    lastSeq = seq
    local notes, beats, name = readBlock()
    local status = handle(math.floor(reaper.gmem_read(GM.CMD)), notes, beats, name)
    reaper.gmem_write(GM.STATUS, status)
    reaper.gmem_write(GM.ACK, seq)
  end

  reaper.defer(loop)
end

local function main()
  -- Running the action a second time stops the copy already running rather
  -- than starting a second one that fights it for the same gmem.
  if reaper.GetExtState(SECTION, "running") == "1" then
    reaper.SetExtState(SECTION, "stop", "1", false)
    return
  end

  reaper.gmem_attach(SECTION)
  reaper.SetExtState(SECTION, "running", "1", false)

  local _, _, sid, cid = reaper.get_action_context()
  sectionID, cmdID = sid, cid
  reaper.SetToggleCommandState(sectionID, cmdID, 1)
  reaper.RefreshToolbar2(sectionID, cmdID)

  reaper.atexit(function()
    reaper.DeleteExtState(SECTION, "running", false)
    reaper.gmem_write(GM.HB, 0)
    if sectionID then
      reaper.SetToggleCommandState(sectionID, cmdID, 0)
      reaper.RefreshToolbar2(sectionID, cmdID)
    end
  end)

  reaper.set_action_options(1)
  loop()
end

main()
