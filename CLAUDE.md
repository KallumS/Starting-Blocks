# Starting Blocks

A ReaScript that hands you the smallest useful pieces of music and puts them in
the project. ReaImGui for the window.

## Shape of it

| | |
| --- | --- |
| `reascripts/Starting Blocks.lua` | The window and the wiring. ReaImGui lives only here. |
| `reascripts/sb_engine.lua` | The music. **No `reaper.` and no `ImGui.` in this file, ever.** |
| `reascripts/sb_midi.lua` | The MIDI file writer. Pure. |
| `reascripts/sb_place.lua` | Everything that touches REAPER. |

That split is the whole reason the tests are worth anything. The engine is pure
so it can be run and checked; `sb_place.lua` touches REAPER but not ImGui, so a
mocked `reaper` table is enough to test it. Keep it that way: if a music
question needs `reaper.`, the answer is to pass the value in, not to reach out.

## What this thing is for

It hands you **the smallest useful piece**, and you assemble. That sentence has
settled several design arguments already, and it will settle more:

- **A progression block was built and then removed.** Presets swayed the choice
  before a note was played. Picking each chord yourself is the point.
- **Named drum patterns were built and then removed.** "Four on the floor" is a
  kick every 1/4; "one and three" is a kick every 1/2; the backbeat is a snare
  from beat two every 1/2. Naming them named what the rate already said.
- **Velocity sliders were removed.** One velocity, 100, for everything. Dynamics
  belong to the MIDI editor once the block is in the project.
- **Fixed-order arpeggios were removed.** They ordered the lowest three voices
  and appended the rest ascending, which means nothing past the third voice of a
  seventh or a thirteenth. Absent beats quietly wrong.

When something here looks like it wants a preset, a name or a curve, check it is
not really asking for a smaller piece and a number.

**No dead controls.** A control that does nothing in the current state is worse
than no control: the drums hide the rate and shuffle entirely for a tom rather
than showing them greyed. The same instinct removed the old "clicking a degree
while following turns following off" - there was no mode to get stuck in.

Where a control goes dead there is often a better one to put in its place. A
sustained melody has no direction and no shape, so the Melody panel does not
grey them: it drops both and draws the **scale degree** there instead, which is
the only thing left to choose about one held note. That degree is step 2's
degree, drawn a second time - `degreeButtons(idPrefix)` is called from both, so
there is one setting and two places it can be reached, per **one setting shown
in many places** below.

## Generators

Each one fills `c.notes` and leaves the block's length in `c.len`.
`generate()` hands it `c.len` already set to `barBeats * bars`, which is what
chord, bass and drums fill. The other three replace it: a melody is as long as
its own notes, and an arpeggio or a run is as long as `repeats` passes of
whatever the direction produced.

**Bars and repeats are alternatives on an arpeggio and a run, and only there.**
This file used to say the opposite - that a block is measured one way or the
other and which way is a property of the block. That was wrong for these two:
sometimes you want the pass to come out whole, and sometimes you want it to
line up with a bar, and neither answer is the right one always. `st.lengthMode`
picks, and `layOut` dispatches. Chord, bass and drums are bars only; melody is
its own length and ignores the mode entirely.

Bars are a list with fractions in it, not a number: `M.BAR_LENGTHS` runs from a
quarter of a bar to eight. Anything iterating bars has to cope with `st.bars`
being less than one - the drum generator walks `while bar * barBeats < c.len`
and clips each hit, rather than `for bar = 0, st.bars - 1`, which simply does
not run for a fraction.

**Count, do not accumulate.** `layRepeats` and the chord's chop both compute
`n` and loop `i = 0, n - 1`, so the last note of a pass cannot land a rounding
error short of the end the way `pos = pos + step` could.
`M.passLength(st)` is the same count without generating anything, for the UI.

There used to be a progression block that laid any of these out across a
sequence of degrees, which is why generators once took an offset and a degree
rather than reading `st`. It went, and the offset machinery went with it. In
the history if the idea comes back.

## State

One plain table describes a block completely, and every engine function is a
pure function of it. `M.clampState(st)` puts every field back inside its table
and inside the range of the slider that shows it.

Settings are saved as `key=value` pairs in one ExtState string. A field dropped
from `SAVED` simply stops being written and is ignored on the way back in, so
removing a setting needs nothing else done to old saved state. Values come back
through `tonumber(v) or v`, so a string setting is fine as long as it never
looks like a number - the drum rates are `"1/8"` and friends, which never do.

**One setting shown in many places beats one setting per place.** Straight,
triplet and dotted is a single `rateMod` drawn on every panel, because a block
is in one feel or the other and it is the same question wherever it is asked.
Whatever a panel reads as a rate goes through it: `M.rateBeats`, `M.chopBeats`
and `M.drumStep` all multiply by `M.modMul`. Adding a new rate-like setting
means adding it to that list, and to `M.modSuffix` so two feels of one rate do
not become two blocks with the same name.

**Prefer a name to an index when a list differs between contexts.** `drumRate`
is kept as `"1/8"`, not as position 3, so moving from a kick to a snare keeps
1/8 as 1/8 instead of sliding it up a shorter list. An unknown name falls back
to `1/1`, which is why every piece's rates end there.

**Slider ranges in the script and the clamps in `clampState` have to agree.**
ReaImGui refuses a value outside a slider's declared range, so a setting that
can legally reach 100 shown by a slider declared 0..50 is a runtime error.
`tests/test_ui.lua` now loads state at both ends of every clamp and draws every
panel, which catches exactly that - but it still cannot tell you which of the
two is wrong. Change both together.

## Tables

A chord is one row carrying its own name, symbol and intervals, so it cannot
half-exist. Under the old JSFX these were three parallel tables and adding a
chord meant editing all three in step; do not reintroduce that. The same goes
for the drum pieces, which now carry their own rates and starting beat.

Scales and roots are copied from ScaleView for REAPER and `test_engine.lua`
asserts they still match it. Do not tidy them independently.

Every seven-note scale walks the letters in order, so those alone cannot tell
the `letters` table apart from a plain index. The pentatonic, blues and
diminished scales are what make it load-bearing, and the spelling tests use
them for exactly that reason. **This was found by deliberately breaking the
speller and watching the tests pass.**

Nothing the controls allow can overflow the note buffer - the longest block
available is a diminished-scale run, four octaves, up and down, sixteen times,
which is 1024 on the nose. The guard still has to work, so `test_engine.lua`
shrinks `E.MAX_NOTES` to test it rather than pretending some setting reaches it.

## ReaImGui

- Load it the documented way: `reaper.ImGui_GetBuiltinPath()`, then
  `dofile(path .. '/imgui.lua')('0.9')`. Not the old flat `reaper.ImGui_*` API.
- Every `PushID` needs its `PopID`, every `PushStyleColor(n)` its
  `PopStyleColor(n)`. The UI test counts them per frame.
- Button labels are IDs. Two buttons with the same label in one window are the
  same button unless they are inside different `PushID`s.
- Colours are `0xRRGGBBAA`.
- Every `PushStyleVar` needs its `PopStyleVar` too; the UI test counts those
  per frame alongside the ids and colours.
- ReaImGui patches Dear ImGui so a **top-level** window can carry its own
  background alpha, which plain Dear ImGui cannot. `SetNextWindowBgAlpha(ctx, 1)`
  makes it solid and `Col_WindowBg` sets the colour. Both are read by `Begin`,
  so they are set before it and popped straight after - pushing a window style
  colour inside the window styles the wrong thing.
- **`StyleVar_WindowRounding` did not visibly round the window** when it was
  tried, whatever the patch notes say. The outer radius appears to be the host
  window's to draw. It was removed rather than left in doing nothing.

## REAPER, from a script

- `TimeMap_GetTimeSigAtTime` returns `num, denom, tempo`. **There is no retval
  in front of them.** Reading one there wrote 4/2 into every exported file for
  a while, and the test mock had the same wrong shape so it agreed with the bug.
  Check a signature in the API docs before destructuring it, and write the mock
  from the signature rather than from the code's assumption about it.
- `MIDI_InsertNote`'s last argument is **noSort**. Pass true for each note in a
  batch, then call `MIDI_Sort` once.
- A refusal has to close the undo block it opened.

## Finding your way down the window

The three things done in order - **1 Key, 2 Scale degree, 3 Building block** -
are numbered, with a gap after each. The options and the buttons under them are
not a step: they are what you do once the three are chosen.

There were arrows drawn in those gaps. Taking them out and **leaving the gap**
separated the steps just as well with nothing on screen to read, which is the
better answer. The test counts the gaps rather than the arrows now, so losing
one still fails.

The step numbers are **neutral, not an accent**, and the test holds that in
place: the step colour is pushed as a text colour nowhere but on the numbers.

## Colour

**After Ableton Live 8's default theme**: a mid-dark neutral grey chrome meant
to sit quietly under brightly coloured clips, controls raised a shade off it,
and one warm accent for whatever is on.

It is a **likeness, not a match**. Live's `.ask` values are not published, so
this was built from the theme's described character rather than extracted from
it. If an exact match ever matters, the values would have to come from a real
theme file or a screenshot, and this is the thing to replace.

`THEME` is a list of `{ "Col_Name", 0xRRGGBBAA }` pushed before `Begin` and
popped after `End` - **outside the `visible` test**, because a push always
needs its pop and a collapsed window still pushed. Adding a colour is one row.
A `Col_` name that does not exist is a hard error in REAPER, and the mock's
`__index` raises on it, so an invented one fails in the test instead.

The accent is spent where Live spends it: on what is switched on. A chosen
button takes it, **and dark text with it**, because the accent is far lighter
than the chrome. Nothing else is coloured except the roll, which is drawn
rather than composed of widgets - dark like Live's MIDI editor, notes in a cool
tone so they never read as a selection.

`shade()` makes the hover and held states from the accent rather than
hand-picking them. Arithmetic rather than bit operators, like the MIDI writer,
and it must keep the alpha byte or ReaImGui is handed a fully transparent
colour. **It has now been deleted twice by a careless block replacement** -
it lives among the colour constants but is not one, so check it survived.

## Tests

```
tools/test.sh
```

| | |
| --- | --- |
| `test_engine.lua` | The generators, by running them. |
| `test_midi.lua` | The MIDI writer, read back by a parser that is not itself. |
| `test_place.lua` | Inserting, exporting and auditioning, against a mocked REAPER. |
| `test_ui.lua` | The real script against a mocked ReaImGui. |

`tests/test_ui.lua` runs the real script against a mocked ReaImGui whose
`__index` raises on anything it does not have, so calling a ReaImGui function
that does not exist fails here rather than in REAPER. It clicks every button in
every panel, drives every slider to both ends **from every button state** - a
panel can hide a control behind another one, and the drums do - reloads the
script on top of its own saved settings, and loads state at both ends of every
clamp.

When you add a control, nothing needs to be added to the test: the sweep finds
it. When you add a ReaImGui function, add it to the mock.

**The sweep cannot see one control swapped for another.** It clicks what is on
screen, so a panel that shows A where it used to show B still draws, still
balances its pushes and still has the same sliders - the sweep is happy either
way. Melody's sustain swap was written, and deliberately broken, and every
suite still passed. Assert a swap directly: count the labels on screen in each
state, and click the second copy of a shared control to prove it drives the same
setting rather than a new one. The sweep leaves the key wherever it stopped, so
such a test clears the ExtState and reloads the script first, or the numerals it
is counting are not the ones it expects.

**Prove a test bites before believing it.** Every suite here has been checked by
deliberately breaking the thing it covers and watching it fail. Four real gaps
were found that way and would not have been found otherwise: the speller test
that only covered seven-note scales, the slider sweep that never reached a
conditionally-shown control, settings loading that clamped some fields and not
others, and the sweep's blindness to a swapped control described above. A test
that has never failed has not been tested.

**Name what you assert, do not count it.** The slider check lists the sliders it
reached rather than counting them, so a control that stops being reachable shows
up as a missing name instead of a number that quietly went down by one.

`docs/BLOCKS.md` is generated by `tools/blocks_md.lua`, which reads the engine's
tables directly. Do not hand-edit it; `tools/test.sh` fails if it is stale.

## Previewing the window without REAPER

```
python3 tools/run_lua.py tools/preview.lua > preview.json
```

`tools/preview.lua` stands a recording mock in ReaImGui's place, loads the real
script unchanged, and writes down every widget it asks for, in order, for every
panel - plus the notes the engine really generates for each. A preview built
from that is a recording rather than a drawing of what someone remembers, so it
cannot flatter the layout.

What it is faithful about: the widgets, their order, their labels, which are
chosen, and the note data. What it is not: spacing and font metrics, because
ReaImGui measures text with its own font.

## History worth knowing

Version 1 was a JSFX plus a bridge ReaScript talking over `gmem`. JSFX cannot
write a file, cannot reach the REAPER API and cannot start a drag - none of
those are in its API - so the plugin built blocks and the bridge placed them.
It worked, and none of it is needed from a script.

The engine was EEL2 then, which only runs inside REAPER, so what a converging
arpeggio actually came out as could only be checked by reading it. That is the
single biggest reason the port was worth doing, and the reason the engine must
stay free of `reaper.`

A "place with the mouse" mode was built - it asked which track the pointer was
over and what time it pointed at - and removed, because Insert at cursor does
the job.
