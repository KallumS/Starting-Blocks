// A smoke test of the plugin without a host: makes one, checks the window
// script ran and handed over a block, plays four bars of song and an
// audition and checks MIDI comes out, and paints the window to a PNG.
//
//   plugin/build.sh with EXTRA_TARGETS=sb_smoke, then
//   plugin/build/sb_smoke out.png
#include "../source/Plugin.h"
#include "../source/Session.h"
#include <iostream>

struct FakePlayHead : juce::AudioPlayHead {
    double ppq = 0, bpm = 120;
    bool playing = true;
    juce::Optional<PositionInfo> getPosition() const override
    {
        PositionInfo p;
        p.setBpm(bpm);
        p.setPpqPosition(ppq);
        p.setIsPlaying(playing);
        p.setTimeSignature(TimeSignature{4, 4});
        return p;
    }
};

static int failures = 0;
static void check(bool ok, const char *what)
{
    std::cout << (ok ? "ok    " : "FAIL  ") << what << "\n";
    if (!ok) ++failures;
}

static int countOns(const juce::MidiBuffer &m)
{
    int n = 0;
    for (const auto md : m) n += md.getMessage().isNoteOn() ? 1 : 0;
    return n;
}

int main(int argc, char **argv)
{
    juce::ScopedJuceInitialiser_GUI gui;
    std::unique_ptr<juce::AudioProcessor> base(createPluginFilter());
    auto &p = dynamic_cast<sb::Processor &>(*base);
    check(p.session() != nullptr, "a session started");

    FakePlayHead head;
    p.setPlayHead(&head);
    p.prepareToPlay(48000, 512);
    juce::AudioBuffer<float> audio(2, 512);
    juce::MidiBuffer midi;

    // nothing plays until asked
    p.processBlock(audio, midi);
    check(countOns(midi) == 0, "silent until Play with the Song or Audition");

    // four bars of song, Play with the Song on
    p.withSong = true;
    int ons = 0, offs = 0;
    const double perBlock = 512 / (48000.0 * 60 / 120);
    for (int b = 0; b < 375; ++b) {          // 4 s = 8 beats at 120
        midi.clear();
        head.ppq = b * perBlock;
        p.processBlock(audio, midi);
        for (const auto md : midi) {
            ons += md.getMessage().isNoteOn() ? 1 : 0;
            offs += md.getMessage().isNoteOff() ? 1 : 0;
        }
    }
    std::cout << "      song: " << ons << " note-ons, " << offs << " note-offs\n";
    check(ons > 0, "Play with the Song sends notes while the song plays");

    head.playing = false;
    midi.clear();
    p.processBlock(audio, midi);
    int stopOffs = 0;
    for (const auto md : midi) stopOffs += md.getMessage().isNoteOff() ? 1 : 0;
    check(ons - offs == stopOffs, "stopping the song lets go of every note still sounding");

    // audition
    p.withSong = false;
    p.audition(true);
    ons = 0;
    for (int b = 0; b < 375 && p.auditioning(); ++b) {
        midi.clear();
        p.processBlock(audio, midi);
        ons += countOns(midi);
    }
    check(ons > 0, "Audition sends notes with the song stopped");

    // state round trip
    juce::MemoryBlock state;
    p.getStateInformation(state);
    check(state.getSize() > 0, "the project saves something");
    p.setStateInformation(state.getData(), (int)state.getSize());
    check(p.session() != nullptr, "and loads it back");

    // the window, painted
    if (auto *s = p.session()) {
        const int w = 860, h = argc > 2 ? juce::String(argv[2]).getIntValue() : 700;
        s->frame((float)w, (float)h, 2);
        s->frame((float)w, (float)h, 2);
        juce::Image img(juce::Image::ARGB, w * 2, h * 2, true);
        {
            juce::Graphics g(img);
            g.addTransform(juce::AffineTransform::scale(2));
            g.fillAll(juce::Colour(0xff23272e));
            sb::drawImGui(g, s->drawData(), s->atlas());
        }
        juce::File out(argc > 1 ? juce::String(argv[1]) : juce::String("smoke.png"));
        out.deleteFile();
        juce::FileOutputStream os(out);
        juce::PNGImageFormat().writeImageToStream(img, os);
        std::cout << "      window painted to " << out.getFullPathName() << "\n";
    }
    std::cout << (failures ? "FAILED\n" : "all passed\n");
    return failures ? 1 : 0;
}
