--[[ Records what the script actually draws, as JSON.

     The window only exists inside REAPER, so a preview of it is either a
     drawing of what someone remembers, or a recording of the real thing. This
     is the second: it stands a recording mock in ReaImGui's place, loads
     "Starting Blocks.lua" unchanged, and writes down every widget it asks for,
     in order, for every panel. It also asks the engine what each block
     actually generates, so the preview's piano roll holds real notes.

       python3 tools/run_lua.py tools/preview.lua > /tmp/preview.json
]]

local HERE   = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local SCRIPT = HERE .. "/../reascripts/Starting Blocks.lua"

local ops, pendingSelected, pendingStep = {}, false, nil
local function push(op) ops[#ops + 1] = op end

------------------------------------------------------------------------------
-- A ReaImGui that writes down instead of drawing
------------------------------------------------------------------------------

local ImGui = {}
for i, k in ipairs({ "Col_Button", "Col_ButtonHovered", "Col_ButtonActive",
                     "Col_Text", "Col_WindowBg", "Cond_FirstUseEver",
                     "Key_Escape", "HoveredFlags_AnyWindow" }) do
  ImGui[k] = i
end

function ImGui.CreateContext(n) return { n = n } end
function ImGui.SetNextWindowSize() end
function ImGui.SetNextWindowBgAlpha() end
function ImGui.Begin() return true, true end
function ImGui.End() end
function ImGui.IsKeyPressed() return false end
function ImGui.SeparatorText(_, t) push{ k = "head", t = t, n = pendingStep }; pendingStep = nil end
function ImGui.Text(_, t)
  -- A lone digit just before a heading is that heading's step number.
  if t:match("^%d$") then pendingStep = tonumber(t) else push{ k = "text", t = t } end
end
function ImGui.Dummy(_, w, h) push{ k = "gap", h = h } end
function ImGui.SameLine() push{ k = "same" } end
function ImGui.NewLine() end
function ImGui.PushID() end
function ImGui.PopID() end
function ImGui.Button(_, label, w)
  push{ k = "btn", t = (label:gsub("##.*$", "")), sel = pendingSelected, w = w }
  pendingSelected = false
  return false
end
function ImGui.PushStyleColor(_, idx) if idx == ImGui.Col_Button then pendingSelected = true end end
function ImGui.PopStyleColor() end
function ImGui.IsItemHovered() return false end
function ImGui.SetTooltip() end
function ImGui.PushItemWidth() end
function ImGui.PopItemWidth() end
function ImGui.SliderInt(_, label, v, lo, hi)
  push{ k = "slider", t = (label:gsub("##.*$", "")), v = v, lo = lo, hi = hi }
  return false, v
end
function ImGui.Checkbox(_, label, v)
  push{ k = "check", t = (label:gsub("##.*$", "")), v = v }
  return false, v
end
function ImGui.GetWindowDrawList() return {} end
function ImGui.GetCursorScreenPos() return 0, 0 end
function ImGui.InvisibleButton(_, id) if id == "##roll" then push{ k = "roll" } end return false end
function ImGui.DrawList_AddRectFilled() end
function ImGui.DrawList_AddLine() end
function ImGui.GetContentRegionAvail() return 960, 400 end
function ImGui.IsMouseClicked() return false end
function ImGui.IsWindowHovered() return true end

------------------------------------------------------------------------------
-- A REAPER that answers plausibly
------------------------------------------------------------------------------

local tmp = "/tmp/starting-blocks-preview"
os.execute('mkdir -p "' .. tmp .. '/shim"')
local shim = assert(io.open(tmp .. "/shim/imgui.lua", "w"))
shim:write("return function() return _G.__PREVIEW_IMGUI end\n")
shim:close()
_G.__PREVIEW_IMGUI = ImGui

local deferred
reaper = {
  ImGui_GetBuiltinPath = function() return tmp .. "/shim" end,
  MB = function(m) error(m) end,
  get_action_context = function()
    local abs = SCRIPT
    if not abs:match("^/") then abs = (os.getenv("PWD") or ".") .. "/" .. abs end
    return true, abs, 0, 1, 0, 0, 0
  end,
  defer = function(f) deferred = f end,
  atexit = function() end,
  set_action_options = function() end,
  SetToggleCommandState = function() end,
  RefreshToolbar2 = function() end,
  time_precise = function() return 0 end,
  GetExtState = function() return "" end,
  SetExtState = function() end,
  Master_GetTempo = function() return 120 end,
  TimeMap_GetTimeSigAtTime = function() return 4, 4, 120 end,
  GetCursorPosition = function() return 0 end,
  GetResourcePath = function() return tmp end,
}

dofile(SCRIPT)
local E = dofile(HERE .. "/../reascripts/sb_engine.lua")

------------------------------------------------------------------------------
-- One frame per panel
------------------------------------------------------------------------------

local function record()
  ops, pendingSelected, pendingStep = {}, false, nil
  deferred()
  return ops
end

-- Everything up to the arrow under the block tabs is the same on every panel;
-- after it comes that panel, then the block's own heading and the buttons.
local function split(list)
  local header, panel, actions, heads = {}, {}, {}, 0
  local where = header
  for i, op in ipairs(list) do
    if op.k == "head" then
      heads = heads + 1
      if heads == 4 then where = actions end
    end
    where[#where + 1] = op
    -- The wide gap after the third step is where the header ends.
    if where == header and op.k == "gap" and op.h == 22 and heads == 3 then
      where = panel
    end
  end
  return header, panel, actions
end

local function clickCategory(name)
  -- The categories are the buttons in the third section; find and press one by
  -- swapping in a Button that returns true for exactly that label once.
  local realButton = ImGui.Button
  local fired = false
  ImGui.Button = function(_, label, w)
    local clean = label:gsub("##.*$", "")
    push{ k = "btn", t = clean, sel = pendingSelected, w = w }
    pendingSelected = false
    if not fired and clean == name then fired = true; return true end
    return false
  end
  record()
  ImGui.Button = realButton
end

------------------------------------------------------------------------------
-- Out
------------------------------------------------------------------------------

local function esc(s)
  return (s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' end
    if c == "\\" then return "\\\\" end
    return ("\\u%04x"):format(c:byte())
  end))
end

local out = {}
local function w(s) out[#out + 1] = s end

local function json(v)
  if type(v) == "string" then return '"' .. esc(v) .. '"' end
  if type(v) == "boolean" then return tostring(v) end
  if type(v) == "number" then
    if v == math.floor(v) then return ("%d"):format(v) end
    return ("%.4f"):format(v)
  end
  if type(v) == "table" then
    if #v > 0 or next(v) == nil then
      local parts = {}
      for i, x in ipairs(v) do parts[i] = json(x) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = '"' .. k .. '":' .. json(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

local doc = { header = nil, panels = {}, actions = {}, blocks = {} }

for _, cat in ipairs(E.CATEGORIES) do
  clickCategory(cat)                       -- select it
  local header, panel, actions = split(record())
  doc.header = doc.header or header
  doc.panels[cat] = panel
  doc.actions[cat] = actions

  local st = E.newState()
  st.cat = cat
  local block = E.generate(st)
  local notes = {}
  for i, n in ipairs(block.notes) do
    notes[i] = { s = n.start, l = n.len, p = n.pitch }
  end
  doc.blocks[cat] = { name = block.name, beats = block.beats, notes = notes }
end

io.write(json(doc), "\n")
