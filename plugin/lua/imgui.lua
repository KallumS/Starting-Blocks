-- ReaImGui's loader, as the plugin provides it: the window script does
-- dofile(reaper.ImGui_GetBuiltinPath() .. "/imgui.lua")("0.9") and gets the
-- plugin's own ImGui table (plugin/source/ImGuiLua.cpp).
return function() return ImGui end
