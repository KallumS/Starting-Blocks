# 0007. A chord has as many inversions as it has notes, less one

Taken 2026-10-10. Stands.

## Context

The Inversion row offered Root, 1st, 2nd and 3rd for every chord. A triad's
"3rd" quietly gave its 2nd again; a power chord's 2nd and 3rd gave its 1st;
a ninth, eleventh or thirteenth could never put its 9th, 11th or 13th in the
bass. The user set out how it should be:

- a triad has two inversions: the 3rd, then the 5th, in the bass;
- a seventh has three: then the 7th;
- a ninth, eleventh or thirteenth has one for each of its notes after the
  root - "a 9th chord can have a 4th inversion when the 9th degree of the
  chord is placed in the bass".

Two faults were found on the way. An inversion lifted the notes under the
new bass by one octave, which is not enough when the chord is wider than an
octave: Cmaj9's 4th inversion would have kept C under D, and three named
chords (Elektra, Farben, Mystic) already did that in their 3rd. And the lifted
notes went on the end of the list, so an Up arpeggio of an inverted ninth or
wider jumped down near the top (E G B D F A then C).

## Decision

- `M.inversionCount(st, degree)`: the chord's distinct notes, less one. Two
  for a triad, three for a seventh, four for a ninth, five for an eleventh,
  six for a thirteenth, one for a power chord; in a scale where a diatonic
  thirteenth comes back round to a note it has (the pentatonics), that note
  is not counted twice.
- `M.chordTones`: inversion n puts the chord's (n+1)th distinct note, counted
  up the stack as the tables write it, in the bass, lifts every note under it
  by octaves until it sits above it, and returns the pitches in order.
- `M.INVERSIONS` runs to "6th"; `M.inversionNames(st)` is the chord's own
  list, and the window shows only that (no dead controls). `clampState` pins
  `inv` to the chord's count, last, once what it reads is sound; the window
  does the same when the chord changes under a chosen inversion.

## What changes for what was there

Root position, and every inversion up to the 3rd of a chord no wider than an
octave, gives exactly the notes it gave. What changes: a triad or power chord
no longer offers inversions it does not have (a saved "3rd" on a triad loads
as its 2nd, which is what it sounded); the three wide named chords put the
right note in the bass; an arpeggio of an inverted ninth or wider climbs.
Block names never named the inversion, so none changes.

## What it rules out

Calling an inversion by the note in the bass ("the 9th in the bass") in the
window. It reads well for stacked thirds and badly elsewhere - six semitones
is a b5 in one chord and a #11 in another - so the row keeps its ordinals.
