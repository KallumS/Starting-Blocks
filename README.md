# Starting Blocks

A catalogue of the smallest useful pieces of music - chords, arpeggios, runs,
melodic steps and leaps, bass notes, single drum hits - that you pick by key,
scale and scale degree and then drop into a REAPER project.

The idea is that a song starts from parts, not from a blank arrange. Pick a
key. Pick a degree of it. Then pull in the block you want and keep going.

| | |
| --- | --- |
| `reascripts/Starting Blocks.lua` | The script you run. The window, and getting blocks into the project. |
| `reascripts/sb_engine.lua` | The music: keys, scales, chords, generators. No REAPER in it. |
| `reascripts/sb_midi.lua` | Writing a block out as a standard MIDI file. |
| `reascripts/sb_place.lua` | Everything that touches REAPER: inserting, exporting, auditioning. |
| `docs/BLOCKS.md` | Every block it can make. Generated from the engine. |

The keys, scales and note spelling are
[ScaleView for REAPER](https://github.com/KallumS/ScaleView-for-Reaper)'s,
unchanged, so the two apps agree on what a scale is and on what to call its
notes. F# major spells its seventh E#, here as there.

## Installing

**1. Install ReaImGui.** The script will not start without it.

In REAPER: Extensions -> ReaPack -> Browse packages, search for `ReaImGui`,
right-click it and Install. Then Extensions -> ReaPack -> Apply changes, and
restart REAPER.

If you have no ReaPack, get it from [reapack.com](https://reapack.com), put the
file it gives you in `UserPlugins` inside the resource path below, restart, and
then do the above.

**2. Put all four files in one folder under Scripts.**

Options -> Show REAPER resource path in explorer/finder, then into `Scripts/`.
Make a folder and put these four in it together:

```
Scripts/Starting Blocks/
  Starting Blocks.lua
  sb_engine.lua
  sb_midi.lua
  sb_place.lua
```

They have to be in the same folder. `Starting Blocks.lua` loads the other three
from wherever it is itself, so splitting them up stops it working.

The resource path is `%APPDATA%\REAPER` on Windows,
`~/Library/Application Support/REAPER` on macOS and `~/.config/REAPER` on Linux.

**3. Load it as an action.** Actions -> Show action list -> New action ->
Load ReaScript, and pick `Starting Blocks.lua`. It turns up in the action list,
where you can run it, give it a shortcut, or right-click a toolbar button to
put it there.

It is a toggle, so running the action again closes the window. Escape closes it
too.

### If something goes wrong

**It says it needs ReaImGui.** The extension is not installed, or REAPER has
not been restarted since it was.

**It errors on the line that loads ReaImGui.** Your ReaImGui is older than the
version the script asks for. Either update it, or change `dofile(imgui_path)("0.9")`
near the top of `Starting Blocks.lua` to the version you have.

**It cannot find `sb_engine.lua`.** The four files are not in the same folder.

**Audition makes no sound.** It plays through REAPER's virtual MIDI keyboard,
so it needs a track that is record-armed with input monitoring on, holding an
instrument. Insert, Place and Export do not need any of that.

**You had version 1 installed.** Remove `Starting Blocks.jsfx` from `Effects/`
and `Starting Blocks Bridge.lua` from `Scripts/`. The JSFX is retired and the
bridge now does nothing.

## Using it

**Key** across the top, then **Scale**, then the **Scale Degree** as a Roman
numeral. The numerals are cased and marked for the chord the scale actually
builds on that degree, so the vii of major reads `vii°` and the III of natural
minor reads `III`.

Then pick what kind of block you want - **Chord**, **Arpeggio**, **Run**,
**Melody**, **Bass**, **Drums** - and only that block's options are on screen.
The piano roll underneath is whatever you have currently built.

Arpeggios and bass notes read the chord you set in the Chord tab, so there is
one chord picker rather than three.

Chords, bass and drums are measured in **bars**. Arpeggios and runs are
measured in **repeats** instead: one repeat is one pass of whatever the
direction produced, so the block is as long as the arpeggio and no longer. A
triad up is three notes and a thirteenth up is seven, and Repeats of 1 gives
you one of each rather than a bar of each. A melody is however long its own
notes make it.

## Getting a block out

- **Insert at cursor** puts it on the selected track at the edit cursor, as one
  MIDI item named after the block.
- **Export .mid** writes it into `<REAPER resource path>/Starting Blocks/`.
  Point the Media Explorer at that folder and every block you export is one
  drag away from the arrange.
- **Audition** plays it through the virtual keyboard, so a record-armed and
  monitored track sounds it. A deferred script wakes about thirty times a
  second, so this is a preview rather than a performance - a note lands on the
  nearest wake-up, not on the sample. Anything that needs to be exact wants the
  block in the project, where REAPER plays it properly.

## Checking it

```
tools/test.sh
```

| | |
| --- | --- |
| `tests/test_engine.lua` | The generators, by running them. Every direction, repeats, the spelling, the whole catalogue. |
| `tests/test_midi.lua` | The MIDI writer, read back by a parser that is not itself. |
| `tests/test_place.lua` | Inserting, exporting and auditioning, against a mocked REAPER. |
| `tests/test_ui.lua` | Runs the real script headlessly against a mocked ReaImGui, clicking every control in every panel. |

This is the part that changed most when the plugin became a script. As a JSFX
the engine was EEL2, which only runs inside REAPER, so what a converging
arpeggio actually came out as could only be checked by reading it. In Lua it
can be asked. `tests/test_engine.lua` is that question, 352 times.

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
protocol to keep in step. And the engine is ordinary Lua, so it can be tested.

The JSFX is in the history if you want it: `git log -- 'jsfx/Starting Blocks.jsfx'`.
