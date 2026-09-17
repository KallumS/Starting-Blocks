# Starting Blocks

A catalogue of the smallest useful pieces of music - chords, arpeggios, runs,
melodic steps and leaps, bass notes, single drum hits - that you pick by key,
scale and scale degree and then drop into a REAPER project.

The idea is that a song starts from parts, not from a blank arrange. Pick a
key. Pick a degree of it. Then pull in the block you want and keep going.

| | |
| --- | --- |
| `reascripts/Starting Blocks.lua` | The script you run. The window, and getting blocks into the project. |
| `reascripts/sb_engine.lua` | The music: keys, scales, chords, progressions, generators. No REAPER in it. |
| `reascripts/sb_midi.lua` | Writing a block out as a standard MIDI file. |
| `reascripts/sb_place.lua` | Everything that touches REAPER: inserting, exporting, auditioning. |
| `docs/BLOCKS.md` | Every block it can make. Generated from the engine. |

The keys, scales and note spelling are
[ScaleView for REAPER](https://github.com/KallumS/ScaleView-for-Reaper)'s,
unchanged, so the two apps agree on what a scale is and on what to call its
notes. F# major spells its seventh E#, here as there.

## Installing

1. Install **ReaImGui** with ReaPack, from the ReaTeam Extensions repository.
2. Put the four files in `reascripts/` together in one folder under
   `<REAPER resource path>/Scripts/`. Actions -> Show REAPER resource path will
   find it.
3. Actions -> Show action list -> New action -> Load ReaScript, and pick
   `Starting Blocks.lua`.

It is a toggle, so running the action again closes the window. Escape closes it
too.

## Using it

**Key** across the top, then **Scale**, then the **Scale Degree** as a Roman
numeral. The numerals are cased and marked for the chord the scale actually
builds on that degree, so the vii of major reads `vii°` and the III of natural
minor reads `III`.

Then pick what kind of block you want - **Chord**, **Arpeggio**, **Run**,
**Melody**, **Bass**, **Drums**, **Progression** - and only that block's
options are on screen. The piano roll underneath is whatever you have currently
built.

Arpeggios and bass notes read the chord you set in the Chord tab, so there is
one chord picker rather than four.

## Getting a block out

- **Place with the mouse** picks the block up. Move over the arrange and click:
  it lands on the track under the pointer, at the time under the pointer,
  snapped to the grid if Snap is on. This is the drag-and-drop of the whole
  idea. Click Place again to put it back down without using it.
- **Insert at cursor** puts it on the selected track at the edit cursor.
- **Export .mid** writes it into `<REAPER resource path>/Starting Blocks/`.
  Point the Media Explorer at that folder and every block you export is one
  drag away from the arrange.
- **Audition** plays it through the virtual keyboard, so a record-armed and
  monitored track sounds it. A deferred script wakes about thirty times a
  second, so this is a preview rather than a performance - a note lands on the
  nearest wake-up, not on the sample. Anything that needs to be exact wants the
  block in the project, where REAPER plays it properly.

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
bass line walks them, a run starts from a different place each bar. One drop
now gives you four bars that move.

Melody and drums do not offer it, on purpose. A step or a leap is a smaller
thing than a chord change, and a drum has no degree to follow.

Clicking a degree at the top while a block is following turns following off and
uses that degree - there is no dead control to notice and no mode to get stuck
in.

## Checking it

```
tools/test.sh
```

| | |
| --- | --- |
| `tests/test_engine.lua` | The generators, by running them. Every direction and ordering, the progressions, the spelling, the whole catalogue. |
| `tests/test_midi.lua` | The MIDI writer, read back by a parser that is not itself. |
| `tests/test_place.lua` | Inserting, placing at the mouse, exporting and auditioning, against a mocked REAPER. |
| `tests/test_ui.lua` | Runs the real script headlessly against a mocked ReaImGui, clicking every control in every panel. |

This is the part that changed most when the plugin became a script. As a JSFX
the engine was EEL2, which only runs inside REAPER, so what a converging
arpeggio actually came out as could only be checked by reading it. In Lua it
can be asked. `tests/test_engine.lua` is that question, 389 times.

`tests/test_ui.lua` cannot tell you the window looks right. It can tell you
that every panel draws, that no call reaches a ReaImGui function that does not
exist, that every push is matched by its pop, that clicking any control leaves
the state somewhere the engine can still generate from, and that settings saved
by a version that knew different tables do not index off the end of these ones.

## Notes on the catalogue

`docs/BLOCKS.md` has the whole thing. Two things worth saying here:

The 78 chords follow
[Wikipedia's list of chords](https://en.wikipedia.org/wiki/List_of_chords),
checked against that page's pitch-class column. Two of its entries are not
here: the **Magic chord**'s cell runs two voicings together with no separator,
and the **Northern lights chord** is eleven notes over three octaves. Two named
chords are voiced rather than reduced - the list gives the **Tristan chord** as
the pitch-class set `0 3 6 10`, which makes it a half-diminished seventh and
indistinguishable from one; here it is `0 6 10 15`, F-B-D#-G# as it stands in
the prelude.

Most of what looks missing from that page is not a chord shape at all. Tonic,
Supertonic, Mediant, Subdominant, Dominant, Submediant, Subtonic, the parallels
and counter-parallels, Secondary dominant, Leading-tone triad - all of those
are one of three or four triads under a name that says **which degree of the
key it is built on**. That is the other axis of this script, not a row in its
chord table.

## It used to be a JSFX

Version 1 was a JSFX plus a companion ReaScript. It had to be: JSFX cannot
write a file, cannot reach the REAPER API and cannot start a drag, so the
plugin built blocks and a bridge script put them in the project, the two of
them talking over shared memory.

None of that is needed here. A script has the API, so there is no bridge and no
protocol to keep in step. It can ask what track the mouse is over and what time
it is pointing at, which is better than dragging a file because it snaps and
names the item. And the engine is ordinary Lua, so it can be tested.

The JSFX is in the history if you want it: `git log -- 'jsfx/Starting Blocks.jsfx'`.
