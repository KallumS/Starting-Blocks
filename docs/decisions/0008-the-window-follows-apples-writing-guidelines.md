# 0008. The window's text follows Apple's writing guidelines

Taken 2026-10-14. Stands.

## Context

The user asked for every repository's on-screen words to follow Apple's
Human Interface Guidelines on writing, as Noterator and Miderator already do
(Noterator's decision 0053). The window had grown its own habits: buttons in
sentence case ("Insert at cursor", "Export .mid"), " - " for a dash, a
programmer's word on screen ("buffer full"), and status messages that said
what went wrong but not what to do ("No track selected").

## Decision

- **Buttons, step headings, toggles and dialog titles** in title style:
  "Insert at Cursor", "Export MIDI File", "Scale Degree", "Building Block",
  "Missing Extension". Export writes straight to its folder and asks nothing
  more, so it takes no "…".
- **Tooltips, hints and status messages** in sentence case; a complete
  sentence ends with a full stop, a fragment does not.
- **A failure says what happened, then what to do**: "No track is selected.
  Select a track, then insert again."; "The MIDI file couldn’t be saved.
  Check that REAPER’s resource folder can be written to." No "please", no
  "Error:", no "buffer": a block that hits the note limit reads "too many
  notes, so the end is cut off. Shorten the block."
- **Typography**: an em dash (—) between phrases ("Tonic — C"), curly
  apostrophes in sentences. Block names stay plain ASCII: they become file
  names and take names.
- **Only labels change.** Stored values (`cat`, `lengthMode`, rate and bar
  names like "1/8"), the ExtState key and the engine's tables are untouched.
  Musical values ("1/8", "sus2", "maj7", note names) stay as they are written,
  as do ScaleView's scale names ("Harm Minor", "Dim W-H"), which are copies.

## Consequences

- Nothing in `sb_engine.lua`, `sb_midi.lua` or `sb_place.lua` changed, so
  the notation fork, Noterator and Miderator have nothing to sync.
- A word in the engine would be a change to four repositories; it is made
  here first and copied.
