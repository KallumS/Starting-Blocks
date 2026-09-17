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
- EEL2 has no `if`/`else`, only `cond ? ( ... ) : ( ... )`. **Always
  parenthesise a branch that assigns.** `a ? b = 1;` is not reliably parsed;
  `a ? ( b = 1; );` is. `tools/check_jsfx.py` does not catch this - grep for it.

## State

There are no sliders. All of it lives in `@serialize`, so the FX window is the
custom UI and nothing else. Adding a setting means adding a `file_var` line,
and old projects then read one variable short - bump `ser_ver` if that ever
needs handling.

## Tables

`CH_MASK[i]` is a 32-bit interval mask, one bit per semitone above the root, so
a chord is one number. It is parallel to `#chord_names` and `#chord_syms`, which
are `|` separated strings indexed at init. **Three places to edit for one
chord.** `data_ok` catches a length mismatch at runtime and
`tests/test_jsfx_data.py` catches a content mismatch before that.

Scales and roots are copied from ScaleView for REAPER and the test asserts they
still match it. Do not "tidy" them independently.

## Memory

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
