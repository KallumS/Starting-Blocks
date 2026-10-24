// ReaImGui's Lua API on Dear ImGui (ImGuiLua.cpp).
#pragma once
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <map>
#include <vector>

struct ImFont;

namespace sb {

// What the script asked for that the plugin, not ImGui, acts on.
struct ImGuiLuaState {
    int configFlags = 0;
    std::vector<int> fontSizes;          // CreateFont + Attach, in order
    bool fontsChanged = false;
    std::map<int, ImFont *> fonts;       // by size, once the atlas is built
    float preferredW = 0, preferredH = 0;
    float minW = 0, minH = 0;
    bool windowOpen = false;
};

// One script runs at a time on the message thread; the session in use sets
// its own ImGui context current and owns this.
extern ImGuiLuaState *g_imgui;

// Sets the global ImGui table.
void openImGui(lua_State *L);

} // namespace sb
