#include "Session.h"
#include "Plugin.h"
#include "BinaryData.h"
#include "imgui.h"
#include "imgui_internal.h"

namespace sb {

// The script's files, compiled into the plugin. `dofile("<embedded>/x.lua")`
// finds them by name; the plugin's own sb_place.lua replaces the REAPER one.
static const char *EMBEDDED = "<embedded>";

static bool resource(const juce::String &name, const char *&data, int &size)
{
    for (int i = 0; i < BinaryData::namedResourceListSize; ++i) {
        if (name == BinaryData::originalFilenames[i]) {
            data = BinaryData::getNamedResource(BinaryData::namedResourceList[i], size);
            return data != nullptr;
        }
    }
    return false;
}

static Session *self(lua_State *L)
{
    return (Session *)lua_touserdata(L, lua_upvalueindex(1));
}

static void reg(lua_State *L, Session *s, const char *name, lua_CFunction f)
{
    lua_pushlightuserdata(L, s);
    lua_pushcclosure(L, f, 1);
    lua_setfield(L, -2, name);
}

// ImGui's own assertions become Lua errors while the script is running (Lua
// is built as C++, so the error unwinds cleanly), and are ignored otherwise.
static lua_State *g_running = nullptr;

} // namespace sb

void sbImAssertFailed(const char *expr)
{
    if (sb::g_running) luaL_error(sb::g_running, "ImGui check failed: %s", expr);
    DBG("ImGui check failed: " << expr);
}

namespace sb {

// ---- dofile, for the script's own files ------------------------------------------

static int embeddedDofile(lua_State *L)
{
    juce::String path = luaL_checkstring(L, 1);
    juce::String name = path.fromLastOccurrenceOf("/", false, false);
    const char *data = nullptr;
    int size = 0;
    if (!path.startsWith(EMBEDDED) || !resource(name, data, size)) {
        lua_pushvalue(L, lua_upvalueindex(1));    // the real dofile
        lua_pushvalue(L, 1);
        lua_call(L, 1, LUA_MULTRET);
        return lua_gettop(L) - 1;
    }
    int base = lua_gettop(L);
    if (luaL_loadbuffer(L, data, (size_t)size, ("@" + name).toRawUTF8()) != LUA_OK)
        return lua_error(L);
    lua_call(L, 0, LUA_MULTRET);
    return lua_gettop(L) - base;
}

// ---- reaper ---------------------------------------------------------------------

static int r_defer(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_pushvalue(L, 1);
    lua_setfield(L, LUA_REGISTRYINDEX, "sb_deferred");
    return 0;
}

static int r_atexit(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_pushvalue(L, 1);
    lua_setfield(L, LUA_REGISTRYINDEX, "sb_atexit");
    return 0;
}

static int r_get_action_context(lua_State *L)
{
    lua_pushboolean(L, 0);
    lua_pushstring(L, (juce::String(EMBEDDED) + "/" + SB_SCRIPT).toRawUTF8());
    lua_pushinteger(L, 0);
    lua_pushinteger(L, 0);
    return 4;
}

static int r_builtin(lua_State *L) { lua_pushstring(L, EMBEDDED); return 1; }

static int r_getos(lua_State *L)
{
#if JUCE_MAC
  #if defined(__aarch64__) || defined(__arm64__)
    lua_pushstring(L, "macOS-arm64");
  #else
    lua_pushstring(L, "OSX64");
  #endif
#elif JUCE_WINDOWS
    lua_pushstring(L, "Win64");
#else
    lua_pushstring(L, "Other");
#endif
    return 1;
}

static int r_nothing(lua_State *) { return 0; }

static int r_new_array(lua_State *L) { lua_settop(L, 1); return 1; }

static int r_getext(lua_State *L)
{
    auto key = juce::String(luaL_checkstring(L, 1)) + "/" + luaL_checkstring(L, 2);
    auto ext = self(L)->processor.extState();
    auto it = ext.find(key);
    lua_pushstring(L, it == ext.end() ? "" : it->second.toRawUTF8());
    return 1;
}

static int r_setext(lua_State *L)
{
    auto key = juce::String(luaL_checkstring(L, 1)) + "/" + luaL_checkstring(L, 2);
    self(L)->processor.setExt(key, juce::String::fromUTF8(luaL_checkstring(L, 3)));
    return 0;
}

static int r_mb(lua_State *L)
{
    juce::AlertWindow::showMessageBoxAsync(juce::MessageBoxIconType::InfoIcon,
                                           luaL_optstring(L, 2, JucePlugin_Name),
                                           juce::String::fromUTF8(luaL_checkstring(L, 1)));
    lua_pushinteger(L, 1);
    return 1;
}

static int r_time_precise(lua_State *L)
{
    lua_pushnumber(L, juce::Time::getMillisecondCounterHiRes() / 1000.0);
    return 1;
}

// ---- host: the plugin itself -------------------------------------------------------

static int h_tempo(lua_State *L) { lua_pushnumber(L, self(L)->processor.tempo()); return 1; }
static int h_timeSig(lua_State *L)
{
    lua_pushinteger(L, self(L)->processor.sigNum());
    lua_pushinteger(L, self(L)->processor.sigDen());
    return 2;
}

static double field(lua_State *L, int t, const char *k, double d)
{
    lua_getfield(L, t, k);
    double v = lua_isnumber(L, -1) ? lua_tonumber(L, -1) : d;
    lua_pop(L, 1);
    return v;
}

static int h_setBlock(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TTABLE);
    std::vector<Note> notes;
    auto n = (int)lua_rawlen(L, 1);
    notes.reserve((size_t)n);
    for (int i = 1; i <= n; ++i) {
        lua_rawgeti(L, 1, i);
        int t = lua_gettop(L);
        if (lua_istable(L, t)) {
            Note nt;
            nt.start = field(L, t, "start", 0);
            nt.len = field(L, t, "len", 0.25);
            nt.pitch = juce::jlimit(0, 127, (int)field(L, t, "pitch", 60));
            nt.vel = juce::jlimit(1, 127, (int)field(L, t, "vel", 100));
            notes.push_back(nt);
        }
        lua_pop(L, 1);
    }
    self(L)->processor.setBlock(std::move(notes), luaL_optnumber(L, 2, 0));
    return 0;
}

static int h_withSong(lua_State *L) { lua_pushboolean(L, self(L)->processor.withSong.load()); return 1; }
static int h_setWithSong(lua_State *L)
{
    self(L)->processor.withSong = lua_toboolean(L, 1) != 0;
    self(L)->processor.setExt("plugin/withSong", lua_toboolean(L, 1) ? "1" : "0");
    return 0;
}

static juce::File exportDir()
{
    return juce::File::getSpecialLocation(juce::File::userMusicDirectory).getChildFile(JucePlugin_Name);
}

static int h_exportDir(lua_State *L) { lua_pushstring(L, exportDir().getFullPathName().toRawUTF8()); return 1; }
static int h_dragDir(lua_State *L)
{
    auto d = juce::File::getSpecialLocation(juce::File::tempDirectory).getChildFile(JucePlugin_Name);
    lua_pushstring(L, d.getFullPathName().toRawUTF8());
    return 1;
}
static int h_makeDir(lua_State *L) { juce::File(juce::String::fromUTF8(luaL_checkstring(L, 1))).createDirectory(); return 0; }
static int h_reveal(lua_State *L) { juce::File(juce::String::fromUTF8(luaL_checkstring(L, 1))).revealToUser(); return 0; }
static int h_dragFile(lua_State *L) { self(L)->pendingDrag = juce::String::fromUTF8(luaL_checkstring(L, 1)); return 0; }
static int h_audition(lua_State *L) { self(L)->processor.audition(lua_toboolean(L, 1) != 0); return 0; }
static int h_auditioning(lua_State *L) { lua_pushboolean(L, self(L)->processor.auditioning()); return 1; }
static int h_setLoop(lua_State *L) { self(L)->processor.loop = lua_toboolean(L, 1) != 0; return 0; }
static int h_auditionPosition(lua_State *L)
{
    if (!self(L)->processor.auditioning()) return 0;
    lua_pushnumber(L, self(L)->processor.auditionFraction());
    return 1;
}

// ---- the session ---------------------------------------------------------------------

static int traceback(lua_State *L)
{
    luaL_traceback(L, L, luaL_tolstring(L, 1, nullptr), 1);
    return 1;
}

static bool call(lua_State *L, int nargs, juce::String &error)
{
    int base = lua_gettop(L) - nargs;
    lua_pushcfunction(L, traceback);
    lua_insert(L, base);
    g_running = L;
    int rc = lua_pcall(L, nargs, 0, base);
    g_running = nullptr;
    lua_remove(L, base);
    if (rc != LUA_OK) {
        error = juce::String::fromUTF8(lua_tostring(L, -1));
        lua_pop(L, 1);
        return false;
    }
    return true;
}

void Session::use()
{
    ImGui::SetCurrentContext(m_ctx);
    g_imgui = &m_state;
}

Session::Session(Processor &p) : processor(p)
{
    m_ctx = ImGui::CreateContext();
    use();
    ImGuiIO &io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    io.ConfigErrorRecoveryEnableAssert = false;
    io.DisplaySize = ImVec2(800, 600);
    io.DeltaTime = 1.0f / 30;
    // Shapes are drawn by JUCE, which smooths their edges itself; ImGui's own
    // smoothing would draw a fringe of extra triangles.
    ImGuiStyle &style = ImGui::GetStyle();
    style.AntiAliasedLines = style.AntiAliasedLinesUseTex = style.AntiAliasedFill = false;

    L = luaL_newstate();
    luaL_openlibs(L);
    openImGui(L);

    lua_getglobal(L, "dofile");
    lua_pushcclosure(L, embeddedDofile, 1);
    lua_setglobal(L, "dofile");

    lua_newtable(L);
    reg(L, this, "defer", r_defer);
    reg(L, this, "atexit", r_atexit);
    reg(L, this, "get_action_context", r_get_action_context);
    reg(L, this, "ImGui_GetBuiltinPath", r_builtin);
    reg(L, this, "GetOS", r_getos);
    reg(L, this, "GetExtState", r_getext);
    reg(L, this, "SetExtState", r_setext);
    reg(L, this, "MB", r_mb);
    reg(L, this, "ShowMessageBox", r_mb);
    reg(L, this, "time_precise", r_time_precise);
    reg(L, this, "new_array", r_new_array);
    for (auto name : {"SetToggleCommandState", "RefreshToolbar2", "set_action_options", "ShowConsoleMsg"})
        reg(L, this, name, r_nothing);
    lua_setglobal(L, "reaper");

    lua_newtable(L);
    reg(L, this, "tempo", h_tempo);
    reg(L, this, "timeSig", h_timeSig);
    reg(L, this, "setBlock", h_setBlock);
    reg(L, this, "withSong", h_withSong);
    reg(L, this, "setWithSong", h_setWithSong);
    reg(L, this, "exportDir", h_exportDir);
    reg(L, this, "dragDir", h_dragDir);
    reg(L, this, "makeDir", h_makeDir);
    reg(L, this, "reveal", h_reveal);
    reg(L, this, "dragFile", h_dragFile);
    reg(L, this, "audition", h_audition);
    reg(L, this, "auditioning", h_auditioning);
    reg(L, this, "setLoop", h_setLoop);
    reg(L, this, "auditionPosition", h_auditionPosition);
    lua_setglobal(L, "host");

    const char *data = nullptr;
    int size = 0;
    if (!resource(SB_SCRIPT, data, size)) {
        report("The window script is missing from the plugin.");
        return;
    }
    if (luaL_loadbuffer(L, data, (size_t)size, "@" SB_SCRIPT) != LUA_OK) {
        report(juce::String::fromUTF8(lua_tostring(L, -1)));
        return;
    }
    if (!call(L, 0, m_error)) return;

    // One frame straight away, unseen, so the script builds its block and
    // hands it to the plugin even if the window is never opened.
    frame(m_state.preferredW > 0 ? m_state.preferredW : 800,
          m_state.preferredH > 0 ? m_state.preferredH : 600, 1);
}

Session::~Session()
{
    if (L) {
        use();
        lua_getfield(L, LUA_REGISTRYINDEX, "sb_atexit");
        if (lua_isfunction(L, -1)) {
            juce::String e;
            call(L, 0, e);
        } else {
            lua_pop(L, 1);
        }
        lua_close(L);
    }
    ImGui::DestroyContext(m_ctx);
    g_imgui = nullptr;
}

void Session::report(const juce::String &message)
{
    m_error = message;
    DBG(message);
}

// Each size the script asked for, in the system's own face where it can be
// read, rasterised at the screen's density so text is sharp on Retina.
void Session::buildFonts(float scale)
{
    if (!m_state.fontsChanged && m_fontScale == scale && m_atlas.isValid()) return;
    m_state.fontsChanged = false;
    m_fontScale = scale;

    ImGuiIO &io = ImGui::GetIO();
    io.Fonts->Clear();
    m_state.fonts.clear();

    static const ImWchar ranges[] = {
        0x0020, 0x00FF,   // Latin
        0x0100, 0x017F,
        0x2010, 0x2027,   // dashes, quotes, ellipsis
        0x2030, 0x203A,
        0x2190, 0x21FF,   // arrows (⇧)
        0x2212, 0x2212,   // minus
        0x2318, 0x2318,   // ⌘
        0x2325, 0x2325,   // ⌥
        0x266D, 0x266F,   // ♭ ♮ ♯
        0};
    juce::StringArray candidates{
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Unicode.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "C:\\Windows\\Fonts\\segoeui.ttf"};
    juce::String face;
    for (auto &c : candidates)
        if (juce::File(c).existsAsFile()) { face = c; break; }

    std::vector<int> sizes = m_state.fontSizes;
    if (sizes.empty()) sizes.push_back(13);
    for (int s : sizes) {
        ImFontConfig cfg;
        cfg.RasterizerDensity = scale;
        cfg.OversampleH = 2;
        cfg.OversampleV = 1;
        ImFont *f = nullptr;
        if (face.isNotEmpty())
            f = io.Fonts->AddFontFromFileTTF(face.toRawUTF8(), (float)s, &cfg, ranges);
        if (!f) {
            cfg.SizePixels = (float)s;
            f = io.Fonts->AddFontDefault(&cfg);
        }
        m_state.fonts[s] = f;
    }
    io.Fonts->Build();

    unsigned char *pixels = nullptr;
    int w = 0, h = 0;
    io.Fonts->GetTexDataAsAlpha8(&pixels, &w, &h);
    m_atlas = juce::Image(juce::Image::SingleChannel, w, h, false);
    juce::Image::BitmapData bd(m_atlas, juce::Image::BitmapData::writeOnly);
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x)
            *bd.getPixelPointer(x, y) = pixels[y * w + x];
    io.Fonts->SetTexID((ImTextureID)1);
}

void Session::frame(float width, float height, float scale)
{
    if (!L) return;
    use();
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(juce::jmax(1.0f, width), juce::jmax(1.0f, height));
    io.DisplayFramebufferScale = ImVec2(scale, scale);
    io.DeltaTime = 1.0f / 30;
    buildFonts(scale);

    ImGui::NewFrame();
    if (m_error.isEmpty()) {
        ImGuiErrorRecoveryState recover;
        ImGui::ErrorRecoveryStoreState(&recover);
        lua_getfield(L, LUA_REGISTRYINDEX, "sb_deferred");
        lua_pushnil(L);
        lua_setfield(L, LUA_REGISTRYINDEX, "sb_deferred");
        if (lua_isfunction(L, -1)) {
            if (!call(L, 0, m_error)) ImGui::ErrorRecoveryTryToRecoverState(&recover);
        } else {
            lua_pop(L, 1);
        }
        lua_getfield(L, LUA_REGISTRYINDEX, "sb_deferred");
        bool again = lua_isfunction(L, -1);
        lua_pop(L, 1);
        if (!again && m_error.isEmpty())
            m_error = "The window stopped. Close the plugin window and open it again.";
    }
    if (m_error.isNotEmpty()) {
        // What went wrong, where the window would be, so it can be reported.
        ImGui::SetNextWindowPos(ImVec2(0, 0));
        ImGui::SetNextWindowSize(io.DisplaySize);
        ImGui::Begin("##error", nullptr, ImGuiWindowFlags_NoDecoration);
        ImGui::TextWrapped("Starting Blocks stopped:\n\n%s", m_error.toRawUTF8());
        ImGui::End();
    }
    ImGui::Render();
}

ImDrawData *Session::drawData() const
{
    ImGui::SetCurrentContext(m_ctx);
    return ImGui::GetDrawData();
}

void Session::mouseMove(float x, float y) { use(); ImGui::GetIO().AddMousePosEvent(x, y); }
void Session::mouseButton(int b, bool down) { use(); ImGui::GetIO().AddMouseButtonEvent(b, down); }
void Session::mouseWheel(float dx, float dy) { use(); ImGui::GetIO().AddMouseWheelEvent(dx, dy); }
void Session::modifiers(const juce::ModifierKeys &m)
{
    use();
    ImGuiIO &io = ImGui::GetIO();
    // Command is Super; ImGui swaps it with Ctrl on a Mac, as its own Mac
    // backend expects, so Mod_Shortcut is Command there and Ctrl elsewhere.
#if JUCE_MAC
    io.AddKeyEvent(ImGuiMod_Super, m.isCommandDown());
    io.AddKeyEvent(ImGuiMod_Ctrl, m.isCtrlDown());
#else
    io.AddKeyEvent(ImGuiMod_Ctrl, m.isCtrlDown());
#endif
    io.AddKeyEvent(ImGuiMod_Shift, m.isShiftDown());
    io.AddKeyEvent(ImGuiMod_Alt, m.isAltDown());
}
void Session::key(int k, bool down) { use(); ImGui::GetIO().AddKeyEvent((ImGuiKey)k, down); }
void Session::character(juce::juce_wchar c) { use(); ImGui::GetIO().AddInputCharacter((unsigned int)c); }
void Session::focus(bool has) { use(); ImGui::GetIO().AddFocusEvent(has); }
bool Session::wantsKeyboard() const
{
    ImGui::SetCurrentContext(m_ctx);
    return ImGui::GetIO().WantCaptureKeyboard;
}

} // namespace sb
