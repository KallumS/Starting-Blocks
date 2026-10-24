// One run of the window script: its Lua state, its ImGui context, and the
// stand-ins for REAPER it calls (`reaper`, `host`, `dofile` of its own
// files). Lives on the message thread. A loaded project starts a new one, so
// the script reads its settings afresh, as it does when REAPER opens it.
#pragma once
#include "ImGuiLua.h"
#include <juce_gui_basics/juce_gui_basics.h>
#include <map>

struct ImGuiContext;
struct ImDrawData;

namespace sb {

class Processor;

class Session {
public:
    explicit Session(Processor &p);
    ~Session();

    // Run one frame of the script at this size (points) and density.
    void frame(float width, float height, float scale);

    ImDrawData *drawData() const;
    // The font atlas as an alpha mask, and how many atlas pixels make a point.
    const juce::Image &atlas() const { return m_atlas; }

    // input, in points (call between frames)
    void mouseMove(float x, float y);
    void mouseButton(int button, bool down);
    void mouseWheel(float dx, float dy);
    void modifiers(const juce::ModifierKeys &m);
    void key(int imguiKey, bool down);
    void character(juce::juce_wchar c);
    void focus(bool has);
    bool wantsKeyboard() const;

    float preferredWidth() const { return m_state.preferredW; }
    float preferredHeight() const { return m_state.preferredH; }
    float minWidth() const { return m_state.minW; }
    float minHeight() const { return m_state.minH; }

    // a MIDI file the script wants dragged out (the editor starts the drag)
    juce::String pendingDrag;

    Processor &processor;

private:
    void use();
    void buildFonts(float scale);
    void report(const juce::String &message);

    lua_State *L = nullptr;
    ImGuiContext *m_ctx = nullptr;
    ImGuiLuaState m_state;
    int m_deferred = -2;    // LUA_NOREF
    int m_atexit = -2;
    float m_fontScale = 0;
    juce::Image m_atlas;
    juce::String m_error;
};

} // namespace sb
