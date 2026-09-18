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

-- The colours, recorded rather than remembered. A preview that draws the
-- widgets from a recording and then paints them from a palette typed out by
-- hand is only half a recording, and the painted half is the half that flatters.
local theme, colStack, rollCols = {}, {}, {}
local inRoll, sawGrid = false, false


------------------------------------------------------------------------------
-- A ReaImGui that writes down instead of drawing
------------------------------------------------------------------------------

local ImGui = {}
for i, k in ipairs({ "Cond_FirstUseEver", "Key_Escape",
                     "HoveredFlags_AnyWindow" }) do
  ImGui[k] = i
end

-- Every `Col_` name mints itself on first use and remembers what it is called,
-- so a colour added to the script's THEME turns up here with nothing edited.
local colName, nextCol = {}, 1000
setmetatable(ImGui, { __index = function(t, k)
  if type(k) == "string" and k:match("^Col_") then
    nextCol = nextCol + 1
    colName[nextCol] = k
    rawset(t, k, nextCol)
    return nextCol
  end
  return nil
end })

-- What a style colour is right now: the last push of it still standing.
local function effective(idx)
  for i = #colStack, 1, -1 do
    if colStack[i].idx == idx then return colStack[i].col end
  end
  return nil
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
  local bg = effective(ImGui.Col_Button)
  push{ k = "btn", t = (label:gsub("##.*$", "")), w = w,
        sel = bg ~= nil and bg ~= theme.Col_Button,
        bg = bg, ink = effective(ImGui.Col_Text) }
  return false
end
function ImGui.PushStyleColor(_, idx, col)
  local name = colName[idx]
  -- The theme goes on first each frame, so the first value a name is ever
  -- pushed with is the theme's; anything after it is a control's own.
  if name and theme[name] == nil then theme[name] = col end
  colStack[#colStack + 1] = { idx = idx, col = col }
end
function ImGui.PopStyleColor(_, n)
  for _ = 1, (n or 1) do colStack[#colStack] = nil end
end
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
function ImGui.InvisibleButton(_, id)
  if id == "##roll" then push{ k = "roll" }; inRoll, sawGrid = true, false end
  return false
end
-- The roll is drawn rather than built from widgets, so its colours arrive here
-- and nowhere else - and with no labels on them. What tells them apart is the
-- drawing order inside `pianoRoll`, which is structural rather than a property
-- of the palette: the ground is the first rectangle after the roll's hit box,
-- the grid is the lines, and anything filled after a line is a note. Read that
-- way the names survive any recolouring; read off a list's positions they would
-- not.
function ImGui.DrawList_AddRectFilled(_, _, _, _, _, col)
  if not inRoll then return end
  if sawGrid then rollCols.note = rollCols.note or col
  else rollCols.ground = rollCols.ground or col end
end
function ImGui.DrawList_AddLine(_, _, _, _, _, col)
  if not inRoll then return end
  sawGrid = true
  if rollCols.bar == nil then rollCols.bar = col
  elseif col ~= rollCols.bar then rollCols.beat = rollCols.beat or col end
end
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

-- The recorded palette, so nothing downstream has to retype it.
doc.theme = theme
doc.roll  = rollCols

io.write(json(doc), "\n")
