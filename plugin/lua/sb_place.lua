--[[ Starting Blocks - getting a block into the song, as a plugin.

     The plugin's stand-in for reascripts/sb_place.lua: the same functions,
     so the window script runs unchanged, but talking to the plugin (the
     `host` table, from plugin/source/Host.cpp) instead of REAPER.

     A plugin cannot put an item on a track, so it has three ways out instead:
     it plays the block in time with the song (MIDI out, to whatever
     instrument follows it), it lets the block be dragged onto a track as a
     MIDI file, and it still writes one out. Audition plays through the same
     MIDI out, timed by the audio thread, so it is sample-accurate rather
     than the preview the script gives in REAPER.
]]

local M = {}

M.OK, M.NO_TRACK, M.WRITE_FAILED, M.NOTHING = 0, 1, 2, 3
M.HOST = "plugin"

local SEP = package.config:sub(1, 1)

function M.setMidi(midi) M.midi = midi end

------------------------------------------------------------------------------
-- What the song is doing
------------------------------------------------------------------------------

function M.tempo() return host.tempo() end

function M.timeSig()
  local num, den = host.timeSig()
  if not num or num <= 0 or not den or den <= 0 then return 4, 4 end
  return num, den
end

function M.cursor() return 0 end

function M.barBeats()
  local num, den = M.timeSig()
  return num * 4 / den
end

------------------------------------------------------------------------------
-- The block the plugin plays
------------------------------------------------------------------------------

-- Called by the window whenever the block changes, so the plugin plays (and
-- the project saves) what is on screen.
function M.follow(block)
  host.setBlock(block and block.notes or {}, block and block.beats or 0)
end

function M.playingWithSong() return host.withSong() end
function M.setPlayingWithSong(on) host.setWithSong(on and true or false) end

------------------------------------------------------------------------------
-- Writing one out, and dragging one out
------------------------------------------------------------------------------

function M.binPath() return host.exportDir() end

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

function M.uniquePath(dir, base)
  local path = dir .. SEP .. base .. ".mid"
  local n = 2
  while exists(path) do
    path = dir .. SEP .. base .. " " .. n .. ".mid"
    n = n + 1
    if n > 999 then return nil end
  end
  return path
end

local function write(path, block)
  local num, den = M.timeSig()
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(M.midi.build(block.notes, block.beats, block.name, M.tempo(), num, den))
  f:close()
  return true
end

function M.export(block)
  if #block.notes == 0 then return M.NOTHING end
  local dir = M.binPath()
  host.makeDir(dir)
  local path = M.uniquePath(dir, M.midi.sanitise(block.name))
  if not path or not write(path, block) then return M.WRITE_FAILED end
  host.reveal(path)
  return M.OK, path
end

-- Starts dragging the block out of the window as a MIDI file. The drag
-- itself starts on the next mouse movement, which the plugin owns.
function M.dragOut(block)
  if #block.notes == 0 then return M.NOTHING end
  local dir = host.dragDir()
  host.makeDir(dir)
  local path = dir .. SEP .. M.midi.sanitise(block.name) .. ".mid"
  if not write(path, block) then return M.WRITE_FAILED end
  host.dragFile(path)
  return M.OK, path
end

-- Not available in a plugin; kept so a stray call says why.
function M.insert(block)
  if #block.notes == 0 then return M.NOTHING end
  return M.NO_TRACK
end

------------------------------------------------------------------------------
-- Hearing one
------------------------------------------------------------------------------

function M.previewStart(block)
  if #block.notes == 0 then return false end
  M.follow(block)
  host.audition(true)
  return true
end

function M.previewStop() host.audition(false) end
function M.previewRunning() return host.auditioning() end

-- How far through the block the audition is, 0 to 1, or nil.
function M.previewTick(_, loop)
  host.setLoop(loop and true or false)
  return host.auditionPosition()
end

return M
