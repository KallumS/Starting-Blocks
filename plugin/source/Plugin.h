// Starting Blocks as a VST3 and CLAP plugin.
//
// The window is the ReaScript's own window script, run unchanged by an
// embedded Lua on a stand-in for ReaImGui (ImGuiLua.cpp) and drawn with
// JUCE (Render.cpp). The script's engine builds the block; the plugin plays
// it out of its MIDI output, either in time with the song or as an audition,
// and lets it be dragged onto a track as a MIDI file.
#pragma once
#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_gui_basics/juce_gui_basics.h>
#include <array>
#include <atomic>
#include <map>
#include <memory>
#include <vector>

struct ImDrawData;

namespace sb {

class Session;

struct Note {
    double start = 0, len = 0;   // in quarter notes from the start of the block
    int pitch = 60, vel = 100;
};

// Notes sounding from one source (the song, or the audition), so each can be
// let go of on time or all at once.
struct Voices {
    struct V { int pitch; double off; };
    std::array<V, 512> v{};
    int n = 0;
};

class Processor : public juce::AudioProcessor {
public:
    Processor();
    ~Processor() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override {}
    bool isBusesLayoutSupported(const BusesLayout &layout) const override;
    void processBlock(juce::AudioBuffer<float> &, juce::MidiBuffer &) override;
    using juce::AudioProcessor::processBlock;

    juce::AudioProcessorEditor *createEditor() override;
    bool hasEditor() const override { return true; }
    const juce::String getName() const override { return JucePlugin_Name; }
    bool acceptsMidi() const override { return true; }
    bool producesMidi() const override { return true; }
    double getTailLengthSeconds() const override { return 0; }
    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int) override {}
    const juce::String getProgramName(int) override { return {}; }
    void changeProgramName(int, const juce::String &) override {}
    void getStateInformation(juce::MemoryBlock &) override;
    void setStateInformation(const void *, int) override;

    Session *session() { return m_session.get(); }

    // ---- what the window script reaches through `host` (message thread) ----
    void setBlock(std::vector<Note> notes, double beats);
    std::atomic<bool> withSong{false};
    std::atomic<bool> loop{false};
    void audition(bool on);
    bool auditioning() const { return m_auditionOn.load(); }
    double auditionFraction() const;
    double tempo() const { return m_tempo.load(); }
    int sigNum() const { return m_sigNum.load(); }
    int sigDen() const { return m_sigDen.load(); }

    // The script's ExtState, saved with the project.
    std::map<juce::String, juce::String> extState();
    void setExt(const juce::String &key, const juce::String &value);

    // the window's size, kept with the project
    int editorWidth = 0, editorHeight = 0;

private:
    void restartSession();
    void play(Voices &voices, double from, double to, double spb, int sample0, int numSamples,
              bool repeat, juce::MidiBuffer &out);
    void release(Voices &voices, double upTo, double from, double spb, int sample0,
                 juce::MidiBuffer &out);
    void releaseAll(Voices &voices, int sample, juce::MidiBuffer &out);

    std::unique_ptr<Session> m_session;

    juce::CriticalSection m_extLock;
    std::map<juce::String, juce::String> m_ext;

    // the block, written on the message thread, read on the audio thread
    juce::SpinLock m_blockLock;
    std::vector<Note> m_notes;
    double m_beats = 0;
    std::atomic<int> m_blockVersion{0};

    // audio thread
    double m_sampleRate = 44100;
    Voices m_songVoices, m_auditionVoices;
    double m_lastSongEnd = -1;
    int m_songVersion = -1;
    double m_auditionAt = 0;
    std::atomic<bool> m_auditionOn{false};
    std::atomic<int> m_auditionRequest{0};   // 1 start, 2 stop
    std::atomic<double> m_auditionShown{0}, m_auditionBeats{0};
    std::atomic<double> m_tempo{120};
    std::atomic<int> m_sigNum{4}, m_sigDen{4};
};

// Draws a finished ImGui frame with JUCE (Plugin.cpp).
void drawImGui(juce::Graphics &g, struct ::ImDrawData *dd, const juce::Image &atlas);

} // namespace sb
