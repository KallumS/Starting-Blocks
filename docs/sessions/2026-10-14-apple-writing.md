# 2026-10-14 - The window's words to Apple's writing guidelines

## Asked

A sweep of every repository so the text on screen follows Apple's writing
guidelines, as was done for Noterator and Miderator (their 0053).

## Done (0008)

- Buttons and step headings in title style: "Insert at Cursor", "Export
  MIDI File", "Scale Degree", "Building Block"; the missing-ReaImGui box is
  titled "Missing Extension".
- Status messages that say what to do: "No track is selected. Select a
  track, then insert again."; the save failure points at REAPER's resource
  folder; "buffer full" became "too many notes, so the end is cut off.
  Shorten the block."
- Em dashes in the tooltips and the Arpeggio panel's line ("Chord: Triad —
  set it in the Chord panel"; it said "tab", but the code and the rest of the
  window call these panels). The note count reads "3 notes, 1.50 beats".
- Export's button grew from 120 to 140 pixels for its longer label.
- The same changes in Starting Blocks Notation, which has this window.

## Left alone, and why

- The engine's tables (scale names from ScaleView, chord names, "sus2",
  rate names) and the block's name, which becomes a file and take name.
  Nothing in the three shared files changed, so nothing needs syncing.
- The undo point's text ("Starting Blocks: <block>") is in `sb_place.lua`,
  shared with the fork; it is a name, not prose.

## Checked

`tools/test.sh`: every suite passes; no test looked for an old label.
`tools/preview.lua` recorded before and after: the only differences are the
nine labels above.

## Not done yet

- Not run in REAPER; the window is tested against the mocked ReaImGui, which
  does not measure text, so the button widths are by estimate.
