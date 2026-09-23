# 0002. The preview notes share the accent with a chosen button

Taken 2026-09-18. Stands. **Reverses a rule that held for every earlier palette.**

## Context

Until this palette, the preview roll's notes were deliberately a different
colour from anything a control could be - a cool tone against the warm accent -
and `tests/test_ui.lua` asserted it directly:

    ok(not imgui.highlights[NOTE_COL], "which paints no button")

The reason was sound: a note painted in the selection colour invites the reading
that the note is *selected*, which is not a thing this window has.

Then the palette brief asked for the yellow on the highlights **and** the MIDI
notes.

## Decision

One accent, used for both. The notes and a chosen button are the same value.

What keeps them apart is no longer hue but **ground**: the roll is drawn far
darker than the chrome the buttons sit on, so the two never appear on the same
surface. That property replaces the old rule, and the test now asserts it:

    ok(roll ~= nil and lum(roll) < lum(imgui.windowBg) - 15,
       "and the roll they sit on is darker than the chrome, so they read apart")

## Consequences

The old assertion had to go, and this is worth flagging because deleting a test
is normally a smell. It was not weakened - it was **replaced by an assertion
about the property that now does the work**. Had it simply been deleted, nothing
would have stopped the roll drifting lighter until notes and buttons collided.

A future palette that wants the notes separate again should restore the old
assertion rather than keep both.

## Alternatives

**Two yellows**, one for notes and a slightly different one for buttons.
Rejected: the brief said one accent, and two near-identical yellows would read
as an inconsistency rather than a distinction.

**Keep the notes cool.** Rejected: it was asked for the other way, and the
ground separation turns out to carry it.
