// ReaImGui's Lua API, the part the window script uses, on Dear ImGui.
//
// The window script is written against ReaImGui 0.9 (functions take the
// context first, colours are 0xRRGGBBAA, several calls return two values).
// This file gives it the same table, so the script runs in the plugin as it
// is. Anything it does not provide raises an error naming the call, the way
// the test mock does.
#include "ImGuiLua.h"
#include "imgui.h"
#include "imgui_internal.h"
#include <algorithm>
#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace sb {

ImGuiLuaState *g_imgui = nullptr;

static ImU32 col32(lua_Integer rgba)
{
    auto v = (uint32_t)rgba;
    return IM_COL32((v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255);
}

static ImVec4 col4(lua_Integer rgba)
{
    auto v = (uint32_t)rgba;
    return ImVec4(((v >> 24) & 255) / 255.0f, ((v >> 16) & 255) / 255.0f,
                  ((v >> 8) & 255) / 255.0f, (v & 255) / 255.0f);
}

static float num(lua_State *L, int i, float d) { return (float)luaL_optnumber(L, i, d); }
static int integer(lua_State *L, int i, int d) { return (int)luaL_optinteger(L, i, d); }
static bool boolean(lua_State *L, int i, bool d) { return lua_isnoneornil(L, i) ? d : lua_toboolean(L, i) != 0; }
static const char *str(lua_State *L, int i) { return luaL_checkstring(L, i); }

static int push2(lua_State *L, float a, float b)
{
    lua_pushnumber(L, a);
    lua_pushnumber(L, b);
    return 2;
}

// ---- context, fonts, window ---------------------------------------------------

static int CreateContext(lua_State *L)
{
    g_imgui->configFlags = integer(L, 2, 0);
    ImGui::GetIO().ConfigFlags |= g_imgui->configFlags;
    lua_newtable(L);                               // the script only passes it back
    return 1;
}

static int CreateFont(lua_State *L)
{
    lua_newtable(L);
    lua_pushstring(L, luaL_optstring(L, 1, "sans-serif"));
    lua_setfield(L, -2, "family");
    lua_pushinteger(L, integer(L, 2, 13));
    lua_setfield(L, -2, "size");
    return 1;
}

static int fontSize(lua_State *L, int i)
{
    if (!lua_istable(L, i)) return 0;
    lua_getfield(L, i, "size");
    int s = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);
    return s;
}

static int Attach(lua_State *L)
{
    int s = fontSize(L, 2);
    if (s > 0) {
        for (int have : g_imgui->fontSizes)
            if (have == s) return 0;
        g_imgui->fontSizes.push_back(s);
        g_imgui->fontsChanged = true;
    }
    return 0;
}

static ImFont *fontFor(int size)
{
    auto it = g_imgui->fonts.find(size);
    return it == g_imgui->fonts.end() ? nullptr : it->second;
}

static int PushFont(lua_State *L)
{
    ImGui::PushFont(fontFor(fontSize(L, 2)));     // nullptr: the default font
    return 0;
}
static int PopFont(lua_State *) { ImGui::PopFont(); return 0; }

static int SetNextWindowSize(lua_State *L)
{
    if (g_imgui->preferredW <= 0) {
        g_imgui->preferredW = num(L, 2, 0);
        g_imgui->preferredH = num(L, 3, 0);
    }
    return 0;
}

static int SetNextWindowSizeConstraints(lua_State *L)
{
    g_imgui->minW = num(L, 2, 0);
    g_imgui->minH = num(L, 3, 0);
    return 0;
}

static int SetNextWindowBgAlpha(lua_State *L) { ImGui::SetNextWindowBgAlpha(num(L, 2, 1)); return 0; }

// The script's window is the whole plugin window: no title bar, nothing to
// move, resize or close (the host owns all of that).
static int Begin(lua_State *L)
{
    ImGuiIO &io = ImGui::GetIO();
    ImGui::SetNextWindowPos(ImVec2(0, 0));
    ImGui::SetNextWindowSize(io.DisplaySize);
    int flags = integer(L, 4, 0) | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoCollapse |
                ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoBringToFrontOnFocus;
    float rounding = ImGui::GetStyle().WindowRounding;
    ImGui::GetStyle().WindowRounding = 0;
    bool visible = ImGui::Begin(str(L, 2), nullptr, flags);
    ImGui::GetStyle().WindowRounding = rounding;
    g_imgui->windowOpen = true;
    if (!visible) {
        ImGui::End();                              // ReaImGui ends a hidden window itself
        g_imgui->windowOpen = false;
    }
    lua_pushboolean(L, visible);
    lua_pushboolean(L, 1);
    return 2;
}
static int End(lua_State *) { ImGui::End(); g_imgui->windowOpen = false; return 0; }

static int BeginMenuBar(lua_State *L) { lua_pushboolean(L, ImGui::BeginMenuBar()); return 1; }
static int EndMenuBar(lua_State *) { ImGui::EndMenuBar(); return 0; }
static int BeginMenu(lua_State *L) { lua_pushboolean(L, ImGui::BeginMenu(str(L, 2), boolean(L, 3, true))); return 1; }
static int EndMenu(lua_State *) { ImGui::EndMenu(); return 0; }

static int MenuItem(lua_State *L)
{
    const char *shortcut = luaL_optstring(L, 3, nullptr);
    bool enabled = boolean(L, 5, true);
    if (lua_isnoneornil(L, 4)) {
        lua_pushboolean(L, ImGui::MenuItem(str(L, 2), shortcut, false, enabled));
        return 1;
    }
    bool sel = lua_toboolean(L, 4) != 0;
    bool hit = ImGui::MenuItem(str(L, 2), shortcut, &sel, enabled);
    lua_pushboolean(L, hit);
    lua_pushboolean(L, sel);
    return 2;
}

static int BeginTooltip(lua_State *L) { lua_pushboolean(L, ImGui::BeginTooltip()); return 1; }
static int EndTooltip(lua_State *) { ImGui::EndTooltip(); return 0; }
static int SetTooltip(lua_State *L) { ImGui::SetTooltip("%s", str(L, 2)); return 0; }

// ---- widgets ---------------------------------------------------------------------

static int Button(lua_State *L)
{
    lua_pushboolean(L, ImGui::Button(str(L, 2), ImVec2(num(L, 3, 0), num(L, 4, 0))));
    return 1;
}

static int InvisibleButton(lua_State *L)
{
    ImVec2 size(std::max(1.0f, num(L, 3, 1)), std::max(1.0f, num(L, 4, 1)));
    lua_pushboolean(L, ImGui::InvisibleButton(str(L, 2), size, integer(L, 5, 0)));
    return 1;
}

static int Checkbox(lua_State *L)
{
    bool v = lua_toboolean(L, 3) != 0;
    bool hit = ImGui::Checkbox(str(L, 2), &v);
    lua_pushboolean(L, hit);
    lua_pushboolean(L, v);
    return 2;
}

static int SliderInt(lua_State *L)
{
    int v = (int)luaL_checknumber(L, 3);
    bool hit = ImGui::SliderInt(str(L, 2), &v, integer(L, 4, 0), integer(L, 5, 100),
                                luaL_optstring(L, 6, "%d"), integer(L, 7, 0));
    lua_pushboolean(L, hit);
    lua_pushinteger(L, v);
    return 2;
}

static int Text(lua_State *L) { ImGui::TextUnformatted(str(L, 2)); return 0; }
static int TextWrapped(lua_State *L) { ImGui::TextWrapped("%s", str(L, 2)); return 0; }
static int SeparatorText(lua_State *L) { ImGui::SeparatorText(str(L, 2)); return 0; }
static int Separator(lua_State *) { ImGui::Separator(); return 0; }
static int SameLine(lua_State *L) { ImGui::SameLine(num(L, 2, 0), num(L, 3, -1)); return 0; }
static int NewLine(lua_State *) { ImGui::NewLine(); return 0; }
static int Dummy(lua_State *L) { ImGui::Dummy(ImVec2(num(L, 2, 0), num(L, 3, 0))); return 0; }

// ---- the stacks -----------------------------------------------------------------

static int PushID(lua_State *L) { ImGui::PushID(luaL_tolstring(L, 2, nullptr)); return 0; }
static int PopID(lua_State *) { ImGui::PopID(); return 0; }

static int PushStyleColor(lua_State *L)
{
    ImGui::PushStyleColor(integer(L, 2, 0), col4(luaL_checkinteger(L, 3)));
    return 0;
}
static int PopStyleColor(lua_State *L) { ImGui::PopStyleColor(integer(L, 2, 1)); return 0; }

static int PushStyleVar(lua_State *L)
{
    int idx = integer(L, 2, 0);
    const ImGuiStyleVarInfo *info = ImGui::GetStyleVarInfo(idx);
    if (info->Count == 2)
        ImGui::PushStyleVar(idx, ImVec2(num(L, 3, 0), num(L, 4, num(L, 3, 0))));
    else
        ImGui::PushStyleVar(idx, num(L, 3, 0));
    return 0;
}
static int PopStyleVar(lua_State *L) { ImGui::PopStyleVar(integer(L, 2, 1)); return 0; }

static int PushItemWidth(lua_State *L) { ImGui::PushItemWidth(num(L, 2, 0)); return 0; }
static int PopItemWidth(lua_State *) { ImGui::PopItemWidth(); return 0; }
static int PushTextWrapPos(lua_State *L) { ImGui::PushTextWrapPos(num(L, 2, 0)); return 0; }
static int PopTextWrapPos(lua_State *) { ImGui::PopTextWrapPos(); return 0; }

// ---- questions ------------------------------------------------------------------

static int CalcTextSize(lua_State *L)
{
    ImVec2 s = ImGui::CalcTextSize(str(L, 2), nullptr, boolean(L, 5, false), num(L, 6, -1));
    return push2(L, s.x, s.y);
}
static int GetContentRegionAvail(lua_State *L)
{
    ImVec2 v = ImGui::GetContentRegionAvail();
    return push2(L, v.x, v.y);
}
static int GetCursorScreenPos(lua_State *L)
{
    ImVec2 v = ImGui::GetCursorScreenPos();
    return push2(L, v.x, v.y);
}
static int GetItemRectMin(lua_State *L)
{
    ImVec2 v = ImGui::GetItemRectMin();
    return push2(L, v.x, v.y);
}
static int GetItemRectMax(lua_State *L)
{
    ImVec2 v = ImGui::GetItemRectMax();
    return push2(L, v.x, v.y);
}

static int IsItemHovered(lua_State *L) { lua_pushboolean(L, ImGui::IsItemHovered(integer(L, 2, 0))); return 1; }
static int IsItemActive(lua_State *L) { lua_pushboolean(L, ImGui::IsItemActive()); return 1; }
static int IsAnyItemFocused(lua_State *L) { lua_pushboolean(L, ImGui::IsAnyItemFocused()); return 1; }
static int IsWindowHovered(lua_State *L) { lua_pushboolean(L, ImGui::IsWindowHovered(integer(L, 2, 0))); return 1; }
static int IsPopupOpen(lua_State *L)
{
    lua_pushboolean(L, ImGui::IsPopupOpen(luaL_optstring(L, 2, ""), integer(L, 3, 0)));
    return 1;
}
static int IsKeyPressed(lua_State *L)
{
    lua_pushboolean(L, ImGui::IsKeyPressed((ImGuiKey)integer(L, 2, 0), boolean(L, 3, true)));
    return 1;
}
static int GetKeyMods(lua_State *L) { lua_pushinteger(L, ImGui::GetIO().KeyMods); return 1; }
static int IsMouseClicked(lua_State *L)
{
    lua_pushboolean(L, ImGui::IsMouseClicked(integer(L, 2, 0), boolean(L, 3, false)));
    return 1;
}
static int IsMouseDragging(lua_State *L)
{
    lua_pushboolean(L, ImGui::IsMouseDragging(integer(L, 2, 0), num(L, 3, -1)));
    return 1;
}

// ---- drawing --------------------------------------------------------------------

static ImDrawList *drawlist(lua_State *L)
{
    auto *dl = (ImDrawList *)lua_touserdata(L, 1);
    if (!dl) luaL_error(L, "expected a draw list");
    return dl;
}

static int GetWindowDrawList(lua_State *L)
{
    lua_pushlightuserdata(L, ImGui::GetWindowDrawList());
    return 1;
}

static int DrawList_AddRectFilled(lua_State *L)
{
    drawlist(L)->AddRectFilled(ImVec2(num(L, 2, 0), num(L, 3, 0)), ImVec2(num(L, 4, 0), num(L, 5, 0)),
                               col32(luaL_checkinteger(L, 6)), num(L, 7, 0), integer(L, 8, 0));
    return 0;
}

static int DrawList_AddLine(lua_State *L)
{
    drawlist(L)->AddLine(ImVec2(num(L, 2, 0), num(L, 3, 0)), ImVec2(num(L, 4, 0), num(L, 5, 0)),
                         col32(luaL_checkinteger(L, 6)), num(L, 7, 1));
    return 0;
}

static int DrawList_AddCircle(lua_State *L)
{
    drawlist(L)->AddCircle(ImVec2(num(L, 2, 0), num(L, 3, 0)), num(L, 4, 1),
                           col32(luaL_checkinteger(L, 5)), integer(L, 6, 0), num(L, 7, 1));
    return 0;
}

static int DrawList_AddCircleFilled(lua_State *L)
{
    drawlist(L)->AddCircleFilled(ImVec2(num(L, 2, 0), num(L, 3, 0)), num(L, 4, 1),
                                 col32(luaL_checkinteger(L, 5)), integer(L, 6, 0));
    return 0;
}

// The points come as reaper.new_array(t), which in the plugin is the table.
static int DrawList_AddConcavePolyFilled(lua_State *L)
{
    luaL_checktype(L, 2, LUA_TTABLE);
    auto n = (int)lua_rawlen(L, 2);
    static std::vector<ImVec2> pts;
    pts.clear();
    for (int i = 1; i + 1 <= n; i += 2) {
        lua_rawgeti(L, 2, i);
        lua_rawgeti(L, 2, i + 1);
        pts.emplace_back((float)lua_tonumber(L, -2), (float)lua_tonumber(L, -1));
        lua_pop(L, 2);
    }
    if (pts.size() >= 3)
        drawlist(L)->AddConcavePolyFilled(pts.data(), (int)pts.size(), col32(luaL_checkinteger(L, 3)));
    return 0;
}

static int DrawList_AddText(lua_State *L)
{
    drawlist(L)->AddText(ImVec2(num(L, 2, 0), num(L, 3, 0)), col32(luaL_checkinteger(L, 4)), str(L, 5));
    return 0;
}

static int DrawList_AddTextEx(lua_State *L)
{
    ImFont *font = lua_istable(L, 2) ? fontFor(fontSize(L, 2)) : nullptr;
    float size = num(L, 3, 0);
    if (size <= 0) size = ImGui::GetFontSize();
    drawlist(L)->AddText(font, size, ImVec2(num(L, 4, 0), num(L, 5, 0)),
                         col32(luaL_checkinteger(L, 6)), str(L, 7), nullptr, num(L, 8, 0));
    return 0;
}

// ---- constants --------------------------------------------------------------------

static void constant(lua_State *L, const std::string &name, lua_Integer v)
{
    lua_pushinteger(L, v);
    lua_setfield(L, -2, name.c_str());
}

static void constants(lua_State *L)
{
    for (int i = 0; i < ImGuiCol_COUNT; ++i)
        constant(L, std::string("Col_") + ImGui::GetStyleColorName(i), i);
    // ReaImGui 0.9's name for it; Dear ImGui 1.91.4 renamed it
    constant(L, "Col_NavHighlight", ImGuiCol_NavCursor);
    for (int k = ImGuiKey_NamedKey_BEGIN; k < ImGuiKey_NamedKey_END; ++k)
        if (k < ImGuiKey_ReservedForModCtrl)
            constant(L, std::string("Key_") + ImGui::GetKeyName((ImGuiKey)k), k);

    const std::pair<const char *, int> vars[] = {
        {"Alpha", ImGuiStyleVar_Alpha}, {"DisabledAlpha", ImGuiStyleVar_DisabledAlpha},
        {"WindowPadding", ImGuiStyleVar_WindowPadding}, {"WindowRounding", ImGuiStyleVar_WindowRounding},
        {"WindowBorderSize", ImGuiStyleVar_WindowBorderSize}, {"WindowMinSize", ImGuiStyleVar_WindowMinSize},
        {"ChildRounding", ImGuiStyleVar_ChildRounding}, {"ChildBorderSize", ImGuiStyleVar_ChildBorderSize},
        {"PopupRounding", ImGuiStyleVar_PopupRounding}, {"PopupBorderSize", ImGuiStyleVar_PopupBorderSize},
        {"FramePadding", ImGuiStyleVar_FramePadding}, {"FrameRounding", ImGuiStyleVar_FrameRounding},
        {"FrameBorderSize", ImGuiStyleVar_FrameBorderSize}, {"ItemSpacing", ImGuiStyleVar_ItemSpacing},
        {"ItemInnerSpacing", ImGuiStyleVar_ItemInnerSpacing}, {"IndentSpacing", ImGuiStyleVar_IndentSpacing},
        {"CellPadding", ImGuiStyleVar_CellPadding}, {"ScrollbarSize", ImGuiStyleVar_ScrollbarSize},
        {"ScrollbarRounding", ImGuiStyleVar_ScrollbarRounding}, {"GrabMinSize", ImGuiStyleVar_GrabMinSize},
        {"GrabRounding", ImGuiStyleVar_GrabRounding}, {"TabRounding", ImGuiStyleVar_TabRounding},
        {"ButtonTextAlign", ImGuiStyleVar_ButtonTextAlign},
        {"SeparatorTextBorderSize", ImGuiStyleVar_SeparatorTextBorderSize},
        {"SeparatorTextAlign", ImGuiStyleVar_SeparatorTextAlign},
        {"SeparatorTextPadding", ImGuiStyleVar_SeparatorTextPadding},
    };
    for (auto &v : vars) constant(L, std::string("StyleVar_") + v.first, v.second);

    const std::pair<const char *, int> other[] = {
        {"Cond_Always", ImGuiCond_Always}, {"Cond_Once", ImGuiCond_Once},
        {"Cond_FirstUseEver", ImGuiCond_FirstUseEver}, {"Cond_Appearing", ImGuiCond_Appearing},
        {"ConfigFlags_None", 0}, {"ConfigFlags_NavEnableKeyboard", ImGuiConfigFlags_NavEnableKeyboard},
        {"WindowFlags_None", 0}, {"WindowFlags_MenuBar", ImGuiWindowFlags_MenuBar},
        {"WindowFlags_NoTitleBar", ImGuiWindowFlags_NoTitleBar},
        {"WindowFlags_NoResize", ImGuiWindowFlags_NoResize},
        {"WindowFlags_NoScrollbar", ImGuiWindowFlags_NoScrollbar},
        {"WindowFlags_AlwaysAutoResize", ImGuiWindowFlags_AlwaysAutoResize},
        {"PopupFlags_None", 0}, {"PopupFlags_AnyPopup", ImGuiPopupFlags_AnyPopup},
        {"HoveredFlags_None", 0}, {"HoveredFlags_DelayNormal", ImGuiHoveredFlags_DelayNormal},
        {"HoveredFlags_ForTooltip", ImGuiHoveredFlags_ForTooltip},
        {"Mod_None", 0}, {"Mod_Ctrl", ImGuiMod_Ctrl}, {"Mod_Shift", ImGuiMod_Shift},
        {"Mod_Alt", ImGuiMod_Alt}, {"Mod_Super", ImGuiMod_Super}, {"Mod_Shortcut", ImGuiMod_Ctrl},
        {"MouseButton_Left", 0}, {"MouseButton_Right", 1}, {"MouseButton_Middle", 2},
        {"SliderFlags_None", 0}, {"SliderFlags_AlwaysClamp", ImGuiSliderFlags_AlwaysClamp},
        {"DrawFlags_None", 0},
    };
    for (auto &v : other) constant(L, v.first, v.second);
}

static int missing(lua_State *L)
{
    return luaL_error(L, "ImGui.%s isn’t available in the plugin", luaL_checkstring(L, 2));
}

void openImGui(lua_State *L)
{
    static const luaL_Reg fns[] = {
        {"CreateContext", CreateContext}, {"CreateFont", CreateFont}, {"Attach", Attach},
        {"PushFont", PushFont}, {"PopFont", PopFont},
        {"SetNextWindowSize", SetNextWindowSize},
        {"SetNextWindowSizeConstraints", SetNextWindowSizeConstraints},
        {"SetNextWindowBgAlpha", SetNextWindowBgAlpha},
        {"Begin", Begin}, {"End", End},
        {"BeginMenuBar", BeginMenuBar}, {"EndMenuBar", EndMenuBar},
        {"BeginMenu", BeginMenu}, {"EndMenu", EndMenu}, {"MenuItem", MenuItem},
        {"BeginTooltip", BeginTooltip}, {"EndTooltip", EndTooltip}, {"SetTooltip", SetTooltip},
        {"Button", Button}, {"InvisibleButton", InvisibleButton}, {"Checkbox", Checkbox},
        {"SliderInt", SliderInt}, {"Text", Text}, {"TextWrapped", TextWrapped},
        {"SeparatorText", SeparatorText}, {"Separator", Separator}, {"SameLine", SameLine},
        {"NewLine", NewLine}, {"Dummy", Dummy},
        {"PushID", PushID}, {"PopID", PopID},
        {"PushStyleColor", PushStyleColor}, {"PopStyleColor", PopStyleColor},
        {"PushStyleVar", PushStyleVar}, {"PopStyleVar", PopStyleVar},
        {"PushItemWidth", PushItemWidth}, {"PopItemWidth", PopItemWidth},
        {"PushTextWrapPos", PushTextWrapPos}, {"PopTextWrapPos", PopTextWrapPos},
        {"CalcTextSize", CalcTextSize}, {"GetContentRegionAvail", GetContentRegionAvail},
        {"GetCursorScreenPos", GetCursorScreenPos}, {"GetItemRectMin", GetItemRectMin},
        {"GetItemRectMax", GetItemRectMax},
        {"IsItemHovered", IsItemHovered}, {"IsItemActive", IsItemActive},
        {"IsAnyItemFocused", IsAnyItemFocused}, {"IsWindowHovered", IsWindowHovered},
        {"IsPopupOpen", IsPopupOpen}, {"IsKeyPressed", IsKeyPressed}, {"GetKeyMods", GetKeyMods},
        {"IsMouseClicked", IsMouseClicked}, {"IsMouseDragging", IsMouseDragging},
        {"GetWindowDrawList", GetWindowDrawList},
        {"DrawList_AddRectFilled", DrawList_AddRectFilled}, {"DrawList_AddLine", DrawList_AddLine},
        {"DrawList_AddCircle", DrawList_AddCircle}, {"DrawList_AddCircleFilled", DrawList_AddCircleFilled},
        {"DrawList_AddConcavePolyFilled", DrawList_AddConcavePolyFilled},
        {"DrawList_AddText", DrawList_AddText}, {"DrawList_AddTextEx", DrawList_AddTextEx},
        {nullptr, nullptr}};
    luaL_newlib(L, fns);
    constants(L);
    lua_newtable(L);                              // metatable: unknown names are errors
    lua_pushcfunction(L, missing);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    lua_setglobal(L, "ImGui");
}

} // namespace sb
