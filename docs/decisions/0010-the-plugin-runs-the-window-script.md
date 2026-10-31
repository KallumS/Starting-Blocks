# 0010. The plugin runs the window script on a stand-in for ReaImGui

Taken 2026-10-24. Stands.

## Context

The user asked for Starting Blocks as a VST3 and CLAP plugin for the Mac, built by
GitHub Actions, and chose what it does instead of inserting at the cursor:
**play the block in time with the song, and drag it out as a MIDI clip**.

The window is a ReaImGui script whose behaviour the suites pin down, and the
engine is shared, unchanged, across the family. A second window written for
the plugin would have been a second program to keep in step, with no tests.

## Decision

`plugin/` is a JUCE plugin that runs `reascripts/Starting Blocks.lua` itself:

- an embedded **Lua 5.4** (built as C++, so an error unwinds cleanly);
- **`plugin/source/ImGuiLua.cpp`**: ReaImGui 0.9's Lua API, the part the
  script uses, on **Dear ImGui 1.91**; anything else raises an error naming
  the call;
- **`plugin/source/Session.cpp`**: `reaper.defer`, ExtState (saved with the
  project), `dofile` of the script's own files (compiled into the plugin), and
  a `host` table for the plugin itself;
- **`plugin/lua/sb_place.lua`** replaces the REAPER one: the same functions,
  plus `follow` (the block on screen is the one the plugin plays), `dragOut`
  and Play with the Song. Audition and Play with the Song are played by the
  audio thread, timed to the sample;
- ImGui's triangles are drawn with JUCE (`drawImGui` in `Plugin.cpp`): its own
  smoothing is off and JUCE smooths each run of a colour as one path, so the
  engraving and the shapes are anti-aliased without seams; text comes from a
  font atlas rasterised at the screen's density, in San Francisco on a Mac.

The script gains its plugin controls only where `Place` offers them
(`Place.dragOut`, `Place.setPlayingWithSong`, `Place.HOST == "plugin"`):
Drag into Song in place of Insert at Cursor, a Play with the Song box, and
Escape leaves the window open (the host owns it). In REAPER nothing changes.

## Consequences

- One window, one engine. A change to the script reaches REAPER and the
  plugin alike.
- **A new ReaImGui call in the script needs a function in `ImGuiLua.cpp`**,
  or the plugin's window stops with an error naming it.
  `tests/test_plugin.lua` runs the script against exactly the functions that
  file registers, so the suite catches it first.
- The plugin passes audio through untouched and adds MIDI; hosts that cannot
  route a plugin's MIDI output (Logic has no VST3 or CLAP at all) can still
  use Drag into Song and Export.
- JUCE 8 is AGPL v3 (or commercial): the binaries are AGPL-3.0 as well as
  GPL-3.0. Fine while the source is public.
- Not signed or notarised; the user clears the quarantine flag once.
- clap-validator's `state-invalid` test is skipped: JUCE cannot report a
  failed load.

## Alternatives considered

- A native JUCE window: a second implementation of every panel, untested.
- OpenGL for ImGui's own renderer: a second thread to share the Lua state
  with, and Apple has deprecated OpenGL; drawing with JUCE keeps everything
  on the message thread.
