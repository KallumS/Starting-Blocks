# Starting Blocks

A JSFX catalogue of musical building blocks, plus the ReaScript that gets them
into a project.

## Shape of it

`jsfx/Starting Blocks.jsfx` is the whole plugin: data tables, generators and
UI. `reascripts/Starting Blocks Bridge.lua` is a background action that does
the two things JSFX cannot - insert an item, write a file.

They talk over `gmem` under the name `StartingBlocks`. The layout is declared
at the top of both files as `GM_*` / `GM`. **If you change one, change the
other**; there is no handshake that would catch a mismatch, only a heartbeat
that says the bridge is alive.

## JSFX constraints worth remembering

These are the reasons the design is the way it is, so they do not get
rediscovered and "fixed":

- JSFX has **no file write**. `file_open` reads.
- JSFX has **no access to the REAPER API**. It cannot make an item.
- JSFX has **no drag-out**. `gfx_getdropfile` is for files dropped *in*.
- JSFX **can** insert media into a project, but only audio:
  `export_buffer_to_project()` writes an audio file. There is no MIDI
  equivalent, so it is no use here.
- EEL2 has no `if`/`else`, only `cond ? ... : ...`. An assignment is a perfectly
  good branch - the reference documents `a < 5 ? b = 6 : c = 7;` - so the
  parentheses this file used to insist on are a style, not a fix. The style is
  worth keeping for anything longer than one assignment.
- Functions may take up to 40 parameters, and functions defined in `@init` are
  visible from every other section. Ones defined in `@gfx` are not.
- `tempo`, `ts_num`, `ts_denom`, `play_state` and `beat_position` exist **only
  in `@block` and `@sample`**. `@gfx` cannot read them, which is why `@block`
  caches them into `cur_tempo` and `bar_beats`.
- `get_host_placement()` gives the track index the plugin sits on (REAPER
  6.74+). That is how Insert has a target when no track is selected.

## The bridge

Lua multiple returns are the trap. `TimeMap_GetTimeSigAtTime` returns
`num, denom, tempo` - there is no `retval` in front of it, and reading one
there silently wrote 4/2 into every exported file for a while. Check the
signature in the API docs before destructuring anything, and make the mock in
`tests/test_bridge.lua` match the real signature rather than the code's
assumption about it - a mock that agrees with the bug tests nothing.

## State

There are no sliders. All of it lives in `@serialize`, so the FX window is the
custom UI and nothing else. Adding a setting means adding a `file_var` line,
and old projects then read one variable short - bump `ser_ver` if that ever
needs handling.

## Tables

`CH_MASK[i]` is a 32-bit interval mask, one bit per semitone above the root, so
a chord is one number. `cm()` takes seven slots, so seven notes is the ceiling
and 31 semitones the reach. It is parallel to `#chord_names` and `#chord_syms`, which
are `|` separated strings indexed at init. **Three places to edit for one
chord.** `data_ok` catches a length mismatch at runtime and
`tests/test_jsfx_data.py` catches a content mismatch before that.

Scales and roots are copied from ScaleView for REAPER and the test asserts they
still match it. Do not "tidy" them independently.

## Memory

The local address space is about 8 million words and `gmem` under a named
`options:gmem=` is 8 million too, so there is no pressure here - the whole map
fits under 8000.

`@init` lays out one flat `mem` by hand, as named offsets at the top of the
file. The test checks the regions do not run into each other, but it only knows
about regions listed in its `SPANS` table - add to both.

## Tests

```
python3 tests/test_jsfx_data.py
python3 tools/run_lua.py tests/test_bridge.lua
python3 tools/check_jsfx.py "jsfx/Starting Blocks.jsfx"
python3 tools/blocks_md.py > docs/BLOCKS.md
```

`docs/BLOCKS.md` is generated. Do not hand-edit it.
