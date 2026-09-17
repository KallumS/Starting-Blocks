# Starting Blocks

A catalogue of the smallest useful pieces of music - chords, arpeggios, runs,
melodic steps and leaps, bass notes, single drum hits - that you pick by key,
scale and scale degree and then drop into a REAPER project.

The idea is that a song starts from parts, not from a blank arrange. Pick a
key. Pick a degree of it. Then pull in the block you want and keep going.

| | |
| --- | --- |
| `jsfx/Starting Blocks.jsfx` | The catalogue and the UI. Makes no sound; everything it produces leaves as MIDI. |
| `reascripts/Starting Blocks Bridge.lua` | The half that touches REAPER: inserting a block on a track, and writing one to disk as a `.mid`. |
| `docs/BLOCKS.md` | Every block it can make, and exactly what each one is. Generated from the JSFX. |

The keys, scales and note spelling are
[ScaleView for REAPER](https://github.com/KallumS/ScaleView-for-Reaper)'s,
unchanged, so the two apps agree on what a scale is and on what to call its
notes. F# major spells its seventh E#, here as there.

## Installing

Needs REAPER 6.74 or newer, for `get_host_placement()`.

1. Put `Starting Blocks.jsfx` in `<REAPER resource path>/Effects/`.
   Actions → Show REAPER resource path will find it.
2. Put `Starting Blocks Bridge.lua` in `<REAPER resource path>/Scripts/` and
   add it under Actions → Show action list → New action → Load ReaScript.
3. Add the JSFX to a track: FX → JS → Starting Blocks.
4. Run the bridge action once. It is a toggle, so running it again stops it.
   The plugin's header says **Bridge connected** while it is up.

## Using it

**Key** across the top, then **Scale**, then the **Scale Degree** as a Roman
numeral. The numerals are cased and marked for the chord the scale actually
builds on that degree, so the vii of major reads `vii°` and the III of natural
minor reads `III`.

Then pick what kind of block you want - **Chord**, **Arpeggio**, **Run**,
**Melody**, **Bass**, **Drums**, **Progression** - and only that block's
options are on screen. The piano roll underneath is whatever you have
currently built.

Arpeggios and bass notes read the chord you set in the Chord tab, so there is
one chord picker rather than four.

## Linking blocks together

The first six blocks are single pieces. The seventh is the one that connects
them.

A **progression** is a sequence of scale degrees - up to twelve, each lasting
one, two or four bars, either a preset (`I-V-vi-IV`, `ii-V-I`, Pachelbel, the
twelve-bar blues) or whatever you click in. Click a step and the degree row at
the top sets it, which is why the progression panel has no degree buttons of
its own.

Then turn on **Follow progression** in the Chord, Arpeggio, Run or Bass panel.
That block stops sitting on one degree and is laid out across the whole
progression instead: an arpeggio follows the changes rather than repeating, a
bass line walks them, a run starts from a different place each bar. One drag
now gives you four bars that move.

Melody and drums do not offer it, on purpose. A step or a leap is a smaller
thing than a chord change, and a drum has no degree to follow.

Clicking a degree at the top while a block is following turns following off and
uses that degree - there is no dead control to notice and no mode to get stuck
in.

## Getting a block out

Three ways, and they are all the same block:

- **Audition** plays it out of the plugin's MIDI output at the project tempo.
  Nothing else in the plugin makes a sound, so whatever is after it on the
  track is what you hear. With a track record-armed you can record it.
- **Insert at cursor** puts it on the selected track at the edit cursor, as one
  MIDI item named after the block. One undo point. With nothing selected it
  falls back to the track the plugin itself is on, which the JSFX finds with
  `get_host_placement()` and passes over.
- **Export .mid** writes it into `<REAPER resource path>/Starting Blocks/`.
  Point the Media Explorer at that folder once and from then on every block you
  export is one drag away from the arrange.

### Why there is a second script

JSFX has no way to write a file, and no access to the REAPER API, and no way to
start a drag out of its own window - none of those are in the JSFX API at all.
So the plugin can build a block and play it, but it cannot put one in your
project by itself.

The bridge is how it gets there. The plugin writes the finished block into
`gmem` and raises a request; the bridge, running as a background action, picks
it up and does the part that needs REAPER. That is why **Insert** and
**Export** need it running and **Audition** does not, and why "drag and drop"
here means dragging the exported `.mid` in from the Media Explorer rather than
out of the plugin window.

## Checking it

```
python3 tests/test_jsfx_data.py        # the catalogue is what it says it is
python3 tools/run_lua.py tests/test_bridge.lua   # or: lua5.4 tests/test_bridge.lua
python3 tools/check_jsfx.py "jsfx/Starting Blocks.jsfx"
```

`test_jsfx_data.py` decodes every chord out of its bitmask and matches it
against the semitones it is meant to hold, matches the scales against
ScaleView's, and checks that the JSFX's hand-laid memory map has no two regions
running into each other. `test_bridge.lua` runs the real bridge against mocked
REAPER calls and reads its MIDI files back with a separate parser.
`check_jsfx.py` is a structural pass over the EEL2: brackets, and every
function defined before it is called and called with the right number of
arguments.

There is no EEL2 interpreter outside REAPER, so the generators themselves -
what a converging arpeggio actually comes out as - are checked in REAPER and by
reading, not by a test here.

## Notes on the catalogue

`docs/BLOCKS.md` has the whole thing. Two things worth saying here:

The 78 chords follow
[Wikipedia's list of chords](https://en.wikipedia.org/wiki/List_of_chords),
checked against that page's pitch-class column. Two of its entries are not
here:

- The **Magic chord**'s cell runs two voicings together with no separator, so
  there is no reading of it that is not a guess.
- The **Northern lights chord** is eleven notes spread over three octaves. A
  chord here is a 32-bit interval mask fed by seven slots, so it does not fit.

Most of what looks missing from that page is not a chord shape at all. Tonic,
Supertonic, Mediant, Subdominant, Dominant, Submediant, Subtonic, the parallels
and counter-parallels, Secondary dominant, Secondary leading-tone, Leading-tone
triad, Psalms - all of those are one of three or four triads under a name that
says **which degree of the key it is built on**. That is the other axis of this
plugin, not a row in its chord table: pick the degree, and the Diatonic family
gives you the chord that degree actually carries.

Two named chords are voiced rather than reduced. The list gives the **Tristan
chord** as the pitch-class set `0 3 6 t`, which makes it a half-diminished
seventh and indistinguishable from one; here it is `0 6 10 15`, F-B-D#-G# as it
stands in the prelude. **Petrushka** is the same pitch classes as the list's
`0 1 4 6 7 t`, stacked as the two triads it is made of.

Drum patterns are written on a 4/4 grid. In another time signature the hits
past the end of the bar are dropped rather than squeezed in.
