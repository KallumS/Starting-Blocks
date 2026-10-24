#include "Plugin.h"
#include "Session.h"
#include "imgui.h"
#include <cmath>

namespace sb {

Processor::Processor()
    : juce::AudioProcessor(BusesProperties()
                               .withInput("Input", juce::AudioChannelSet::stereo(), true)
                               .withOutput("Output", juce::AudioChannelSet::stereo(), true))
{
    m_notes.reserve(4096);
    restartSession();
}

Processor::~Processor() { m_session.reset(); }

void Processor::restartSession()
{
    m_session.reset();                      // runs the old script's atexit (saves its settings)
    m_session = std::make_unique<Session>(*this);
}

bool Processor::isBusesLayoutSupported(const BusesLayout &layout) const
{
    // audio passes straight through; any matching layout will do
    return layout.getMainInputChannelSet() == layout.getMainOutputChannelSet();
}

void Processor::prepareToPlay(double sampleRate, int) { m_sampleRate = sampleRate; }

// ---- the block ---------------------------------------------------------------------

void Processor::setBlock(std::vector<Note> notes, double beats)
{
    std::sort(notes.begin(), notes.end(), [](const Note &a, const Note &b) { return a.start < b.start; });
    {
        const juce::SpinLock::ScopedLockType sl(m_blockLock);
        m_notes.swap(notes);
        m_beats = beats;
    }
    m_blockVersion.fetch_add(1);
    m_auditionBeats = beats;
}

void Processor::audition(bool on)
{
    m_auditionRequest = on ? 1 : 2;
    m_auditionOn = on;
    m_auditionShown = 0;
}

double Processor::auditionFraction() const
{
    double b = m_auditionBeats.load();
    return b > 0 ? juce::jlimit(0.0, 1.0, m_auditionShown.load() / b) : 0.0;
}

std::map<juce::String, juce::String> Processor::extState()
{
    const juce::ScopedLock sl(m_extLock);
    return m_ext;
}

void Processor::setExt(const juce::String &key, const juce::String &value)
{
    const juce::ScopedLock sl(m_extLock);
    m_ext[key] = value;
}

// ---- playing it --------------------------------------------------------------------

static int sampleAt(double beat, double from, double spb, int sample0, int numSamples)
{
    return juce::jlimit(0, juce::jmax(0, numSamples - 1), sample0 + (int)std::floor((beat - from) * spb));
}

// Lets go of every voice due before `upTo`.
void Processor::release(Voices &vs, double upTo, double from, double spb, int sample0, juce::MidiBuffer &out)
{
    for (int i = 0; i < vs.n;) {
        if (vs.v[(size_t)i].off < upTo) {
            int s = sample0 + juce::jmax(0, (int)std::floor((vs.v[(size_t)i].off - from) * spb));
            out.addEvent(juce::MidiMessage::noteOff(1, vs.v[(size_t)i].pitch), s);
            vs.v[(size_t)i] = vs.v[(size_t)(--vs.n)];
        } else {
            ++i;
        }
    }
}

void Processor::releaseAll(Voices &vs, int sample, juce::MidiBuffer &out)
{
    for (int i = 0; i < vs.n; ++i)
        out.addEvent(juce::MidiMessage::noteOff(1, vs.v[(size_t)i].pitch), sample);
    vs.n = 0;
}

// The notes that start in [from, to), in quarter notes. With `repeat` the
// block repeats every m_beats from 0 (the song's start), so it lines up with
// the song's bars; without, it is played once from 0. Caller holds the lock.
void Processor::play(Voices &vs, double from, double to, double spb, int sample0, int numSamples,
                     bool repeat, juce::MidiBuffer &out)
{
    release(vs, from + 1e-9, from, spb, sample0, out);   // anything already due
    double L = m_beats;
    if (L > 0 && !m_notes.empty()) {
        double k0 = repeat ? std::floor(from / L) : 0;
        double k1 = repeat ? std::floor(to / L) : 0;
        for (double k = k0; k <= k1; k += 1) {
            for (const Note &n : m_notes) {
                double t = k * L + n.start;
                if (t < from) continue;
                if (t >= to) break;
                int s = sampleAt(t, from, spb, sample0, numSamples);
                // the same pitch still sounding is let go first
                for (int i = 0; i < vs.n; ++i)
                    if (vs.v[(size_t)i].pitch == n.pitch) {
                        out.addEvent(juce::MidiMessage::noteOff(1, n.pitch), s);
                        vs.v[(size_t)i] = vs.v[(size_t)(--vs.n)];
                        break;
                    }
                out.addEvent(juce::MidiMessage::noteOn(1, n.pitch, (juce::uint8)n.vel), s);
                if (vs.n < (int)vs.v.size()) vs.v[(size_t)(vs.n++)] = {n.pitch, t + juce::jmax(0.001, n.len)};
            }
        }
    }
    // notes shorter than this block end inside it
    for (int i = 0; i < vs.n;) {
        if (vs.v[(size_t)i].off < to) {
            int s = sampleAt(vs.v[(size_t)i].off, from, spb, sample0, numSamples);
            out.addEvent(juce::MidiMessage::noteOff(1, vs.v[(size_t)i].pitch), s);
            vs.v[(size_t)i] = vs.v[(size_t)(--vs.n)];
        } else {
            ++i;
        }
    }
}

void Processor::processBlock(juce::AudioBuffer<float> &buffer, juce::MidiBuffer &midi)
{
    const int n = buffer.getNumSamples();
    juce::MidiBuffer out;
    out.addEvents(midi, 0, n, 0);              // what comes in still goes on

    double bpm = 120;
    bool playing = false;
    double ppq = 0;
    bool hasPpq = false;
    if (auto *ph = getPlayHead()) {
        if (auto pos = ph->getPosition()) {
            if (auto b = pos->getBpm()) bpm = juce::jmax(1.0, *b);
            playing = pos->getIsPlaying();
            if (auto q = pos->getPpqPosition()) { ppq = *q; hasPpq = true; }
            if (auto sig = pos->getTimeSignature()) {
                m_sigNum = sig->numerator > 0 ? sig->numerator : 4;
                m_sigDen = sig->denominator > 0 ? sig->denominator : 4;
            }
        }
    }
    m_tempo = bpm;
    const double spb = m_sampleRate * 60.0 / bpm;     // samples per quarter note
    const double span = n / spb;

    const juce::SpinLock::ScopedTryLockType sl(m_blockLock);
    const bool haveBlock = sl.isLocked();

    // In time with the song
    int version = m_blockVersion.load();
    if (withSong && playing && hasPpq && haveBlock) {
        bool jumped = std::abs(ppq - m_lastSongEnd) > 1e-3;
        if (jumped || version != m_songVersion) releaseAll(m_songVoices, 0, out);
        m_songVersion = version;
        play(m_songVoices, ppq, ppq + span, spb, 0, n, true, out);
        m_lastSongEnd = ppq + span;
    } else if (m_songVoices.n > 0) {
        releaseAll(m_songVoices, 0, out);
        m_lastSongEnd = -1;
    }

    // Audition: the block once (or round and round) from the top, at the tempo
    int req = m_auditionRequest.exchange(0);
    if (req) {
        releaseAll(m_auditionVoices, 0, out);
        m_auditionAt = 0;
    }
    if (m_auditionOn && haveBlock) {
        double L = m_beats;
        double from = m_auditionAt, to = from + span;
        if (L <= 0) {
            m_auditionOn = false;
        } else if (to < L) {
            play(m_auditionVoices, from, to, spb, 0, n, false, out);
            m_auditionAt = to;
        } else {
            int split = juce::jlimit(0, n, (int)std::floor((L - from) * spb));
            play(m_auditionVoices, from, L, spb, 0, n, false, out);
            releaseAll(m_auditionVoices, split, out);
            if (loop) {
                m_auditionAt = to - L;
                play(m_auditionVoices, 0, m_auditionAt, spb, split, n, false, out);
            } else {
                m_auditionOn = false;
                m_auditionAt = 0;
            }
        }
        m_auditionShown = m_auditionAt;
    } else if (!m_auditionOn && m_auditionVoices.n > 0) {
        releaseAll(m_auditionVoices, 0, out);
    }

    midi.swapWith(out);
    juce::ignoreUnused(buffer);                 // the audio itself passes through untouched
}

// ---- the project ---------------------------------------------------------------------

void Processor::getStateInformation(juce::MemoryBlock &dest)
{
    juce::ValueTree root("StartingBlocks");
    root.setProperty("version", 1, nullptr);
    root.setProperty("editorWidth", editorWidth, nullptr);
    root.setProperty("editorHeight", editorHeight, nullptr);
    juce::ValueTree ext("ext");
    for (auto &kv : extState()) {
        juce::ValueTree item("item");
        item.setProperty("key", kv.first, nullptr);
        item.setProperty("value", kv.second, nullptr);
        ext.addChild(item, -1, nullptr);
    }
    root.addChild(ext, -1, nullptr);
    juce::MemoryOutputStream stream(dest, false);
    root.writeToStream(stream);
}

void Processor::setStateInformation(const void *data, int size)
{
    juce::ValueTree root = juce::ValueTree::readFromData(data, (size_t)size);
    if (!root.hasType("StartingBlocks")) return;
    editorWidth = root.getProperty("editorWidth", 0);
    editorHeight = root.getProperty("editorHeight", 0);
    {
        const juce::ScopedLock sl(m_extLock);
        m_ext.clear();
        for (auto item : root.getChildWithName("ext"))
            m_ext[item.getProperty("key").toString()] = item.getProperty("value").toString();
        withSong = m_ext["plugin/withSong"] == "1";
    }
    // The script reads its settings when it starts, so it starts again.
    auto restart = [this] {
        auto keep = extState();
        m_session.reset();
        {
            const juce::ScopedLock sl(m_extLock);
            m_ext = keep;                      // the old script's atexit must not overwrite them
        }
        m_session = std::make_unique<Session>(*this);
    };
    if (juce::MessageManager::getInstance()->isThisTheMessageThread()) restart();
    else juce::MessageManager::callAsync(restart);
}

//==============================================================================
// Draws ImGui's triangles with JUCE. ImGui's own smoothing is off, so every
// shape is flat-coloured triangles (drawn as one path per run of a colour, so
// JUCE smooths the outline and no seams show between them) and text is
// quads cut from the font atlas (drawn as the atlas's alpha in their colour).
void drawImGui(juce::Graphics &g, ImDrawData *dd, const juce::Image &atlas)
{
    if (!dd || !atlas.isValid()) return;
    const ImVec2 white = ImGui::GetIO().Fonts->TexUvWhitePixel;
    const float aw = (float)atlas.getWidth(), ah = (float)atlas.getHeight();
    auto colour = [](ImU32 c) {
        return juce::Colour((juce::uint8)(c & 255), (juce::uint8)((c >> 8) & 255),
                            (juce::uint8)((c >> 16) & 255), (juce::uint8)((c >> 24) & 255));
    };
    for (int l = 0; l < dd->CmdListsCount; ++l) {
        const ImDrawList *list = dd->CmdLists[l];
        const ImDrawVert *vtx = list->VtxBuffer.Data;
        const ImDrawIdx *idx = list->IdxBuffer.Data;
        for (const ImDrawCmd &cmd : list->CmdBuffer) {
            if (cmd.UserCallback) continue;
            juce::Graphics::ScopedSaveState save(g);
            g.reduceClipRegion(juce::Rectangle<float>(cmd.ClipRect.x, cmd.ClipRect.y,
                                                      cmd.ClipRect.z - cmd.ClipRect.x,
                                                      cmd.ClipRect.w - cmd.ClipRect.y)
                                   .getSmallestIntegerContainer());
            juce::Path path;
            ImU32 pathCol = 0;
            auto flush = [&] {
                if (!path.isEmpty()) {
                    g.setColour(colour(pathCol));
                    g.fillPath(path);
                    path.clear();
                }
            };
            const unsigned end = cmd.IdxOffset + cmd.ElemCount;
            for (unsigned i = cmd.IdxOffset; i + 3 <= end;) {
                const ImDrawVert &a = vtx[cmd.VtxOffset + idx[i]];
                const ImDrawVert &b = vtx[cmd.VtxOffset + idx[i + 1]];
                const ImDrawVert &c = vtx[cmd.VtxOffset + idx[i + 2]];
                bool solid = a.uv.x == white.x && a.uv.y == white.y && b.uv.x == white.x &&
                             b.uv.y == white.y && c.uv.x == white.x && c.uv.y == white.y;
                if (solid) {
                    if (a.col != pathCol) { flush(); pathCol = a.col; }
                    path.addTriangle(a.pos.x, a.pos.y, b.pos.x, b.pos.y, c.pos.x, c.pos.y);
                    i += 3;
                    continue;
                }
                // A glyph: ImGui draws it as two triangles, top-left, top-right,
                // bottom-right first, so the first one spans the whole rectangle.
                flush();
                i += 6;
                float x0 = std::min({a.pos.x, b.pos.x, c.pos.x}), x1 = std::max({a.pos.x, b.pos.x, c.pos.x});
                float y0 = std::min({a.pos.y, b.pos.y, c.pos.y}), y1 = std::max({a.pos.y, b.pos.y, c.pos.y});
                float u0 = std::min({a.uv.x, b.uv.x, c.uv.x}), u1 = std::max({a.uv.x, b.uv.x, c.uv.x});
                float v0 = std::min({a.uv.y, b.uv.y, c.uv.y}), v1 = std::max({a.uv.y, b.uv.y, c.uv.y});
                juce::Rectangle<int> src((int)std::lround(u0 * aw), (int)std::lround(v0 * ah),
                                         (int)std::lround((u1 - u0) * aw), (int)std::lround((v1 - v0) * ah));
                if (src.isEmpty() || x1 <= x0 || y1 <= y0) continue;
                g.setColour(colour(a.col));
                g.drawImageTransformed(atlas.getClippedImage(src),
                                       juce::AffineTransform::scale((x1 - x0) / (float)src.getWidth(),
                                                                    (y1 - y0) / (float)src.getHeight())
                                           .translated(x0, y0),
                                       true);
            }
            flush();
        }
    }
}

// ImGui's key for a JUCE key code, for the keys a window needs.
static ImGuiKey imguiKey(const juce::KeyPress &k)
{
    const int c = k.getKeyCode();
    if (c == juce::KeyPress::tabKey) return ImGuiKey_Tab;
    if (c == juce::KeyPress::returnKey) return ImGuiKey_Enter;
    if (c == juce::KeyPress::escapeKey) return ImGuiKey_Escape;
    if (c == juce::KeyPress::spaceKey) return ImGuiKey_Space;
    if (c == juce::KeyPress::backspaceKey) return ImGuiKey_Backspace;
    if (c == juce::KeyPress::deleteKey) return ImGuiKey_Delete;
    if (c == juce::KeyPress::leftKey) return ImGuiKey_LeftArrow;
    if (c == juce::KeyPress::rightKey) return ImGuiKey_RightArrow;
    if (c == juce::KeyPress::upKey) return ImGuiKey_UpArrow;
    if (c == juce::KeyPress::downKey) return ImGuiKey_DownArrow;
    if (c == juce::KeyPress::homeKey) return ImGuiKey_Home;
    if (c == juce::KeyPress::endKey) return ImGuiKey_End;
    if (c == juce::KeyPress::pageUpKey) return ImGuiKey_PageUp;
    if (c == juce::KeyPress::pageDownKey) return ImGuiKey_PageDown;
    if (c == juce::KeyPress::numberPadAdd) return ImGuiKey_KeypadAdd;
    if (c == juce::KeyPress::numberPadSubtract) return ImGuiKey_KeypadSubtract;
    if (c >= '0' && c <= '9') return (ImGuiKey)(ImGuiKey_0 + (c - '0'));
    if (c >= 'A' && c <= 'Z') return (ImGuiKey)(ImGuiKey_A + (c - 'A'));
    if (c >= 'a' && c <= 'z') return (ImGuiKey)(ImGuiKey_A + (c - 'a'));
    if (c == '=' || c == '+') return ImGuiKey_Equal;
    if (c == '-' || c == '_') return ImGuiKey_Minus;
    return ImGuiKey_None;
}

class Editor : public juce::AudioProcessorEditor, private juce::Timer {
public:
    explicit Editor(Processor &p) : juce::AudioProcessorEditor(p), m_proc(p)
    {
        setWantsKeyboardFocus(true);
        setResizable(true, true);
        Session *s = p.session();
        int minW = s && s->minWidth() > 0 ? (int)s->minWidth() : 320;
        int minH = s && s->minHeight() > 0 ? (int)s->minHeight() : 240;
        setResizeLimits(juce::jmax(320, minW), juce::jmax(240, minH), 4096, 4096);
        int w = p.editorWidth > 0 ? p.editorWidth : 860;
        int h = p.editorHeight > 0 ? p.editorHeight : 700;
        setSize(w, h);
        startTimerHz(30);
    }

    void paint(juce::Graphics &g) override
    {
        g.fillAll(juce::Colour(0xff23272e));
        if (Session *s = m_proc.session()) drawImGui(g, s->drawData(), s->atlas());
    }

    void resized() override
    {
        m_proc.editorWidth = getWidth();
        m_proc.editorHeight = getHeight();
    }

    // ---- input, handed to the script's ImGui ----
    void mouseMove(const juce::MouseEvent &e) override { pos(e); }
    void mouseEnter(const juce::MouseEvent &e) override { pos(e); }
    void mouseExit(const juce::MouseEvent &) override
    {
        if (Session *s = m_proc.session()) s->mouseMove(-FLT_MAX, -FLT_MAX);
    }
    void mouseDown(const juce::MouseEvent &e) override
    {
        grabKeyboardFocus();
        pos(e);
        if (Session *s = m_proc.session()) s->mouseButton(button(e), true);
    }
    void mouseDrag(const juce::MouseEvent &e) override
    {
        pos(e);
        Session *s = m_proc.session();
        if (s && s->pendingDrag.isNotEmpty()) {
            // the script asked for a drag: hand the MIDI file to the host
            juce::StringArray files{s->pendingDrag};
            s->pendingDrag.clear();
            s->mouseButton(0, false);
            juce::DragAndDropContainer::performExternalDragDropOfFiles(files, false, this);
        }
    }
    void mouseUp(const juce::MouseEvent &e) override
    {
        pos(e);
        if (Session *s = m_proc.session()) {
            s->mouseButton(button(e), false);
            s->pendingDrag.clear();
        }
    }
    void mouseWheelMove(const juce::MouseEvent &e, const juce::MouseWheelDetails &w) override
    {
        pos(e);
        if (Session *s = m_proc.session()) s->mouseWheel(w.deltaX * 5, w.deltaY * 5);
    }
    void modifierKeysChanged(const juce::ModifierKeys &m) override
    {
        if (Session *s = m_proc.session()) s->modifiers(m);
    }
    bool keyPressed(const juce::KeyPress &k) override
    {
        Session *s = m_proc.session();
        if (!s) return false;
        s->modifiers(k.getModifiers());
        ImGuiKey key = imguiKey(k);
        if (key != ImGuiKey_None) {
            s->key(key, true);
            s->key(key, false);
        }
        juce::juce_wchar c = k.getTextCharacter();
        if (c >= 32 && !k.getModifiers().isCommandDown() && !k.getModifiers().isCtrlDown())
            s->character(c);
        // Space with nothing focused is left to the host (play/stop)
        if (key == ImGuiKey_Space && !s->wantsKeyboard()) return false;
        return true;
    }
    void focusGained(FocusChangeType) override { if (Session *s = m_proc.session()) s->focus(true); }
    void focusLost(FocusChangeType) override { if (Session *s = m_proc.session()) s->focus(false); }

private:
    void timerCallback() override
    {
        if (Session *s = m_proc.session()) {
            float scale = 1;
            if (auto *peer = getPeer()) scale = (float)peer->getPlatformScaleFactor();
            if (auto *d = juce::Desktop::getInstance().getDisplays().getDisplayForRect(getScreenBounds()))
                scale = juce::jmax(scale, (float)d->scale);
            s->frame((float)getWidth(), (float)getHeight(), scale);
            repaint();
        }
    }
    void pos(const juce::MouseEvent &e)
    {
        if (Session *s = m_proc.session()) {
            s->modifiers(e.mods);
            s->mouseMove(e.position.x, e.position.y);
        }
    }
    static int button(const juce::MouseEvent &e)
    {
        if (e.mods.isRightButtonDown() || e.mods.isPopupMenu()) return 1;
        if (e.mods.isMiddleButtonDown()) return 2;
        return 0;
    }

    Processor &m_proc;
};

juce::AudioProcessorEditor *Processor::createEditor() { return new Editor(*this); }

} // namespace sb

juce::AudioProcessor *JUCE_CALLTYPE createPluginFilter() { return new sb::Processor(); }
