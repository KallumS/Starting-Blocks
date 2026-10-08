# 0006. The Bass and Drums blocks are removed

Taken 2026-10-08. Stands.

## Context

The window offered six kinds of block: Chord, Arpeggio, Run, Melody, Bass and
Drums. Bass was one chord tone on its own, low, repeated at a rate. Drums was
one piece of the kit hit at a rate, with a shuffle. They were no longer needed,
and were asked to come out of the list.

The same engine runs in Starting Blocks Notation, copied byte for byte so a fix
here is a copy there (that project's decision 0001). Noterator carries a copy
too, and had already hidden both blocks in its own adapter (its decision 0024).

## Decision

Take out the two blocks and everything that existed only for them, and nothing
else:

- From the engine: `"Bass"` and `"Drums"` in `M.CATEGORIES`, `M.BASS_TONES`,
  `M.DRUM_PIECES`, `M.drumStep`, `M.swingOffset`, `GEN.Bass`, `GEN.Drums`,
  their names in `M.blockName`, and the state fields only they read -
  `bassTone`, `bassOct`, `drumPiece`, `drumRate`, `shuffle` - with their clamps.
- From the window: the two panels, and those fields from `SAVED`.

**What did not change** is anything that decides where the bass of a chord
sits. That is the chord's inversion (`st.inv`, `M.chordTones`), and the Bass
block only ever read the chord, in root position, without changing it. Chords,
inversions, the chop, arpeggios, runs and melodies generate exactly the notes
they did.

## Consequences

- A setting saved on Bass or Drums opens on the chord: `cat` is a name, and an
  unknown name falls back to the first kind. The fields only those blocks used
  are ignored on the way in and no longer written on the way out. Both are
  tested, and both tests were shown to fail when broken.
- Two rules in `CLAUDE.md` had their worked examples in the drum code - walking
  time rather than bars for a fractional block, and keeping a rate as a name.
  The rules stay; the examples are now history.
- The engine is copied unchanged to Starting Blocks Notation in the same piece
  of work, so the two stay identical. Noterator's copy is not touched here; its
  adapter already leaves both blocks out, so syncing it later changes nothing it
  shows.

## Alternatives

**Hide the two buttons and leave the engine alone**, as Noterator's adapter
does. Rejected here: Noterator hides them because its engine copies must not be
edited; this is the engine's own repository, and a generator nothing can reach
is dead code with tests that keep it alive.
