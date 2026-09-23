# 0004. Sustain swaps the shape control for the scale degree

Taken 2026-09-18. Stands.

## Context

The Melody block offers an interval, a direction and a shape. A **Sustain**
interval was asked for: one note, held for the rate - the smallest melodic thing
there is.

A held note has nothing to point in a direction and no shape to take, so two of
the panel's three controls become meaningless the moment it is chosen.
`CLAUDE.md`'s standing rule is that a control doing nothing in the current state
is worse than no control.

## Decision

Sustain **drops** the direction and shape controls and draws the **scale degree**
in their place - the only thing left to choose about one held note.

That degree is not a new setting. `degreeButtons(idPrefix)` is called from step 2
and from the Melody panel, so there is one `st.degree` reachable in two places,
per `CLAUDE.md`'s "one setting shown in many places beats one setting per place".

## Consequences

`degreeButtons` had to move above the `panels` table in `Starting Blocks.lua`,
since a `local` is not visible to a function defined earlier in the file.

The Melody panel is visibly wider in Sustain than in any other state, because the
degree row is seven buttons plus the note name. It reads acceptably, but it is
the one state where the panel changes size noticeably.

The swap is not visible to the UI test's click sweep. See
[0005](0005-assert-per-widget-not-per-frame.md).

## Alternatives

**Grey out direction and shape.** Rejected by the standing rule - the drums
already hide the rate and shuffle for a tom rather than greying them, and this
is the same situation.

**Leave the panel alone and let the controls do nothing.** Rejected for the same
reason, more strongly: silently ignored controls are worse than greyed ones.

**A second, panel-local degree.** Rejected: two settings that mean the same
thing, which would then need reconciling every time either moved.
