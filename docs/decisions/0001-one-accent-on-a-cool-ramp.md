# 0001. One accent on a cool grey ramp, with dark ink on every button

Taken 2026-09-18. Stands.

## Context

The window had been through four palettes in two days: Dear ImGui's default,
a teal-and-orange pass, a four-band scheme colouring each section differently,
and a mid-grey chrome with a warm accent. The four-band one was abandoned
because it was doing too much - colour was carrying information that the
numbered steps already carried.

So the question was not "which colours" but "how much work should colour do".

## Decision

Colour does one job: it says **what is switched on**. Everything else is
structure.

- A dark, cool grey ground, with the controls raised off it in a **light** grey.
- One accent, spent only on the state that is on: a chosen button, a ticked
  box, the slider grab being dragged.
- Every grey is **blue-shifted**, R < G < B down the whole ramp.
- Semantic colour stays off the accent's hue, so a warning cannot read as a
  selection.

Two consequences fall out of the light-controls choice and are not optional:

**Every button needs dark ink, chosen or not.** Both button fills sit far
lighter than the ground, so the window's own light text vanishes on them. This
inverts the usual dark-theme habit of raising buttons a shade off the chrome
and lettering them in the body text colour.

**The blue bias is load-bearing.** A neutral grey at the same lightness looks
correct in a diff and only reads as flat on screen beside the accent.

## Consequences

`pick()` pushes `Col_Text` for every button rather than only the selected one -
the first scheme here that needed an unchosen button to carry its own text
colour. Dropping that push fails quietly: the chosen button still looks right
while everything else goes unreadable. See [0005](0005-assert-per-widget-not-per-frame.md)
for why the obvious test does not catch it.

The values are in [`../COLOUR.md`](../COLOUR.md), and they are settled - treat a
change to one as a change of mind rather than a tidy-up.

## Alternatives

**Keep colour per section** (the four-band scheme). Rejected: the steps are
numbered and spaced already, so the colour was a third encoding of the same
thing, and it made the window loud.

**Keep the buttons darker than the chrome**, the conventional arrangement.
Rejected once the ground went dark and cool: raising a control off an already
dark ground either barely reads or drags the whole window lighter.

**Neutral greys.** Rejected, and this is the one that keeps coming back - it is
the default a careless edit reverts to.
