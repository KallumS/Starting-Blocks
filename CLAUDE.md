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

## Generators

Each one fills `c.notes` and leaves the block's length in `c.len`.
`generate()` hands it `c.len` already set to `barBeats * bars`, which is what
chord, bass and drums fill. The other three replace it: a melody is as long as
its own notes, and an arpeggio or a run is as long as `repeats` passes of
whatever the direction produced.

**Bars and repeats are not alternatives to offer together.** A block is
measured one way or the other, and which way is a property of the block, not a
setting. Chord, bass and drums are bars; arpeggio and run are repeats; melody
is neither.

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
  background alpha and round its own corners, which plain Dear ImGui cannot.
  `SetNextWindowBgAlpha(ctx, 1)` makes the background solid without having an
  opinion about its colour, so the window still follows whatever theme is set;
  `StyleVar_WindowRounding` rounds the outside. Both are read by `Begin`, so
  they are set before it and popped straight after - pushing a window style var
  inside the window styles the wrong thing.

## REAPER, from a script

- `TimeMap_GetTimeSigAtTime` returns `num, denom, tempo`. **There is no retval
  in front of them.** Reading one there wrote 4/2 into every exported file for
  a while, and the test mock had the same wrong shape so it agreed with the bug.
  Check a signature in the API docs before destructuring it, and write the mock
  from the signature rather than from the code's assumption about it.
- `MIDI_InsertNote`'s last argument is **noSort**. Pass true for each note in a
  batch, then call `MIDI_Sort` once.
- A refusal has to close the undo block it opened.

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

**Prove a test bites before believing it.** Every suite here has been checked by
deliberately breaking the thing it covers and watching it fail. Three real gaps
were found that way and would not have been found otherwise: the speller test
that only covered seven-note scales, the slider sweep that never reached a
conditionally-shown control, and settings loading that clamped some fields and
not others. A test that has never failed has not been tested.

**Name what you assert, do not count it.** The slider check lists the sliders it
reached rather than counting them, so a control that stops being reachable shows
up as a missing name instead of a number that quietly went down by one.

`docs/BLOCKS.md` is generated by `tools/blocks_md.lua`, which reads the engine's
tables directly. Do not hand-edit it; `tools/test.sh` fails if it is stale.

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
