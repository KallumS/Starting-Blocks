# 0005. The UI test asserts per widget, not per frame

Taken 2026-09-18. Stands.

## Context

`tests/test_ui.lua` drives the real script against a mocked ReaImGui, clicking
every button in every panel and driving every slider to both ends. The standing
claim in `CLAUDE.md` was that it finds new controls on its own: "When you add a
control, nothing needs to be added to the test: the sweep finds it."

Two changes in one session both slipped straight past it.

**The Sustain swap** ([0004](0004-sustain-swaps-the-shape-control.md)). The
panel was deliberately broken so the swap never happened - shape always drawn,
degree never - and **all four suites passed**. The sweep clicks whatever is on
screen; a panel showing A where it used to show B still draws, still balances
its pushes, and still has the same sliders.

**The button ink** ([0001](0001-one-accent-on-a-cool-ramp.md)). A first attempt
asserted that the dark ink was pushed somewhere in the frame:

    ok(imgui.textColours[INK], "buttons are lettered in dark ink")

The ink was then removed from *unchosen* buttons only - the exact failure that
rule exists to prevent - and the assertion still passed, because the chosen
button was still pushing it.

## Decision

Where a property belongs to a widget, the mock records it **per widget** and the
test walks them all.

`ImGui.PushStyleColor` / `PopStyleColor` maintain a real style-colour stack in the
mock, so it knows what is actually in effect at any moment rather than only what
was pushed at some point. `ImGui.Button` records the effective fill and text
colour for each button drawn. The test then checks every one, and names the
offender:

    every button is dark ink on light grey: button 2 (C#): DDE1E7FF text on A9AFBAFF does not read

Where a property is a *swap* between states, assert it directly: count the labels
on screen in each state, and click the second copy of a shared control to prove
it drives the same setting rather than a new one.

## Consequences

The claim in `CLAUDE.md` is now qualified rather than absolute - the sweep finds
a new control, but it cannot see one control replacing another, and it cannot see
a property that holds for some widgets and not others.

A swap test must clear the ExtState and reload the script first, because the
sweep leaves the key wherever it stopped and the degree numerals it counts depend
on the scale.

## Alternatives

**Count instead of naming.** Rejected, consistent with the existing rule that the
slider check lists the sliders it reached rather than counting them: a count that
quietly goes down by one tells you nothing about which one went.

**Trust the sweep and add nothing.** Rejected on evidence - two real regressions
were introduced on purpose and it caught neither.
