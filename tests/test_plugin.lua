--[[ The window script as the plugin runs it.

     The plugin (plugin/) runs "Starting Blocks.lua" unchanged on a stand-in
     for ReaImGui written in C++ (plugin/source/ImGuiLua.cpp), with its own
     sb_place.lua (plugin/lua/) talking to a `host` table instead of REAPER.
     This runs the script the same way, headlessly:

       - the ImGui table offers exactly the functions ImGuiLua.cpp registers
         (read from that file), so a call the plugin lacks fails here;
       - `reaper` offers exactly what plugin/source/Session.cpp registers;
       - `host` records what the script asks of the plugin.

     It checks the plugin's own controls: the block reaches the plugin and the
     project, Drag into Song writes a MIDI file and hands it over, Play with
     the Song and Audition reach the plugin, and Escape does not close it.

       lua5.4 tests/test_plugin.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local ROOT = HERE .. "/.."

local failures, checks = 0, 0
local function ok(cond, what)
  checks = checks + 1
  if not cond then failures = failures + 1; io.write("FAIL  ", what, "\n") end
end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
end

------------------------------------------------------------------------------
-- What the plugin provides, read from its source
------------------------------------------------------------------------------

local provided = {}
for name in read(ROOT .. "/plugin/source/ImGuiLua.cpp"):gmatch('{"([%w_]+)", [%w_]+}') do
  provided[name] = true
end
local reaperFns = {}
for name in read(ROOT .. "/plugin/source/Session.cpp"):gmatch('reg%(L, this, "([%w_]+)"') do
  reaperFns[name] = true
end
for name in read(ROOT .. "/plugin/source/Session.cpp"):gmatch('"([%w_]+)"[,}]') do
  reaperFns[name] = true     -- the no-op list
end
ok(provided.Begin and provided.Button and provided.IsItemActive, "ImGuiLua.cpp's function list was read")
ok(reaperFns.defer and reaperFns.GetExtState, "Session.cpp's reaper list was read")

------------------------------------------------------------------------------
-- An ImGui with only those functions
------------------------------------------------------------------------------

local state = {
  buttons = {}, checkboxes = {}, clickLabel = nil, checkLabel = nil,
  lastItem = nil, dragLabel = nil, escape = false, calls = {},
}

local behaviour = {
  CreateContext = function() return {} end,
  CreateFont = function(f, s) return { family = f, size = s } end,
  Begin = function() return true, true end,
  BeginMenuBar = function() return true end,
  BeginMenu = function() return false end,
  MenuItem = function() return false end,
  BeginTooltip = function() return true end,
  Button = function(_, label)
    state.buttons[#state.buttons + 1] = label
    state.lastItem = label
    if label == state.clickLabel then state.clickLabel = nil; return true end
    return false
  end,
  InvisibleButton = function(_, id) state.lastItem = id; return false end,
  Checkbox = function(_, label, v)
    state.checkboxes[#state.checkboxes + 1] = label
    state.lastItem = label
    if label == state.checkLabel then state.checkLabel = nil; return true, not v end
    return false, v
  end,
  SliderInt = function(_, label, v) state.lastItem = label; return false, v end,
  CalcTextSize = function(_, s) return #tostring(s) * 7, 13 end,
  GetContentRegionAvail = function() return 760, 400 end,
  GetCursorScreenPos = function() return 0, 0 end,
  GetItemRectMin = function() return 0, 0 end,
  GetItemRectMax = function() return 100, 28 end,
  GetWindowDrawList = function() return {} end,
  GetKeyMods = function() return 0 end,
  IsItemHovered = function() return true end,
  IsItemActive = function() return state.lastItem ~= nil and state.lastItem == state.dragLabel end,
  IsMouseDragging = function() return state.dragLabel ~= nil end,
  IsKeyPressed = function(_, key) return state.escape and key == ImGui.Key_Escape end,
}

ImGui = setmetatable({}, {
  __index = function(_, name)
    if name:match("^Col_") or name:match("^Key_") or name:match("^StyleVar_")
       or name:match("^Cond_") or name:match("^ConfigFlags_") or name:match("^WindowFlags_")
       or name:match("^PopupFlags_") or name:match("^Mod_") or name:match("^HoveredFlags_") then
      local v = 0
      for i = 1, #name do v = (v * 31 + name:byte(i)) % 65536 end
      return v
    end
    if not provided[name] then
      error("ImGui." .. name .. " is called by the script but the plugin does not provide it", 2)
    end
    return function(...)
      state.calls[name] = (state.calls[name] or 0) + 1
      local f = behaviour[name]
      if f then return f(...) end
    end
  end,
})

------------------------------------------------------------------------------
-- reaper and host, as the plugin gives them
------------------------------------------------------------------------------

local ext, deferred, atexitFn = {}, nil, nil
local tmp = os.tmpname(); os.remove(tmp); os.execute('mkdir -p "' .. tmp .. '"')

local realDofile = dofile
local function embedded(path)
  local name = path:match("^<embedded>/(.+)$")
  if not name then return realDofile(path) end
  if name == "sb_place.lua" or name == "imgui.lua" then
    return realDofile(ROOT .. "/plugin/lua/" .. name)
  end
  return realDofile(ROOT .. "/reascripts/" .. name)
end

local function only(t)
  return setmetatable(t, {
    __index = function(_, k)
      error("reaper." .. tostring(k) .. " is called by the script but the plugin does not provide it", 2)
    end,
  })
end

local reaperImpl = {
  defer = function(f) deferred = f end,
  atexit = function(f) atexitFn = f end,
  get_action_context = function() return false, "<embedded>/Starting Blocks.lua", 0, 0 end,
  ImGui_GetBuiltinPath = function() return "<embedded>" end,
  GetOS = function() return "macOS-arm64" end,
  GetExtState = function(s, k) return ext[s .. "/" .. k] or "" end,
  SetExtState = function(s, k, v) ext[s .. "/" .. k] = v end,
  MB = function(m) error("the script gave up: " .. tostring(m)) end,
  time_precise = function() return os.clock() end,
  new_array = function(t) return t end,
  SetToggleCommandState = function() end,
  RefreshToolbar2 = function() end,
  set_action_options = function() end,
}
for k in pairs(reaperImpl) do
  ok(reaperFns[k], "the test's reaper." .. k .. " is one the plugin registers")
end
reaper = only(reaperImpl)

local H = { withSong = false, auditioning = false, loop = false, blocks = 0 }
host = {
  tempo = function() return 120 end,
  timeSig = function() return 4, 4 end,
  setBlock = function(notes, beats) H.blocks = H.blocks + 1; H.notes, H.beats = notes, beats end,
  withSong = function() return H.withSong end,
  setWithSong = function(on) H.withSong = on end,
  exportDir = function() return tmp .. "/export" end,
  dragDir = function() return tmp .. "/drag" end,
  makeDir = function(p) os.execute('mkdir -p "' .. p .. '"') end,
  reveal = function(p) H.revealed = p end,
  dragFile = function(p) H.dragged = p end,
  audition = function(on) H.auditioning = on end,
  auditioning = function() return H.auditioning end,
  setLoop = function(on) H.loop = on end,
  auditionPosition = function() return H.auditioning and 0.5 or nil end,
}

------------------------------------------------------------------------------
-- Run it
------------------------------------------------------------------------------

dofile = embedded
local loaded, err = pcall(dofile, "<embedded>/Starting Blocks.lua")
ok(loaded, "the script loads in the plugin: " .. tostring(err))
ok(deferred ~= nil, "and defers a loop")
if not loaded or not deferred then io.write("cannot continue\n"); os.exit(1) end

local function frame()
  state.buttons, state.checkboxes = {}, {}
  local f = deferred
  deferred = nil
  local fine, e = pcall(f)
  ok(fine, "a frame runs: " .. tostring(e))
  return fine
end

local function has(list, label)
  for _, v in ipairs(list) do if v == label then return true end end
  return false
end

frame()
ok(H.blocks >= 1 and H.notes and #H.notes > 0, "the first frame hands the plugin a block with notes")
ok(H.beats and H.beats > 0, "and its length in beats")
ok((ext["StartingBlocks/state"] or "") ~= "", "and saves the settings where the project keeps them")
ok(has(state.buttons, "Drag into Song"), "Drag into Song is drawn")
ok(not has(state.buttons, "Insert at Cursor"), "Insert at Cursor is not (there is no cursor)")
ok(has(state.checkboxes, "Play with the Song"), "Play with the Song is drawn")

-- Play with the Song reaches the plugin
state.checkLabel = "Play with the Song"
frame()
frame()
ok(H.withSong == true, "ticking Play with the Song turns it on in the plugin")

-- Audition
state.clickLabel = "Audition"
frame()
ok(H.auditioning == true, "Audition starts the plugin's audition")
frame()
ok(has(state.buttons, "Stop"), "and the button then says Stop")
state.clickLabel = "Stop"
frame()
ok(H.auditioning == false, "Stop stops it")

-- Dragging the block out
state.dragLabel = "Drag into Song"
frame()
state.dragLabel = nil
frame()
ok(H.dragged ~= nil, "dragging Drag into Song hands the plugin a file")
if H.dragged then
  ok(H.dragged:match("%.mid$") ~= nil, "a .mid file")
  local f = io.open(H.dragged, "rb")
  ok(f ~= nil, "that exists")
  if f then ok(f:read(4) == "MThd", "and is a MIDI file"); f:close() end
end

-- Export
state.clickLabel = "Export MIDI File"
frame()
ok(H.revealed ~= nil and H.revealed:match("%.mid$") ~= nil, "Export MIDI File writes a file and shows it")

-- Escape does not end the script: the host owns the window
state.escape = true
frame()
state.escape = false
ok(deferred ~= nil, "Escape does not close the plugin's window")
frame()

-- A change of block reaches the plugin
local before = H.blocks
state.clickLabel = "Arpeggio"
frame()
frame()
ok(H.blocks > before, "choosing another block hands the plugin the new one")

if atexitFn then
  local fine, e = pcall(atexitFn)
  ok(fine, "the script's atexit runs: " .. tostring(e))
end

os.execute('rm -rf "' .. tmp .. '"')
io.write(("%d checks, %d failures\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
