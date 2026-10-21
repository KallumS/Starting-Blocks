# Session log - 16 to 21 October 2026: the final HIG sweep (2.5)

Asked across the family: a final sweep of the 19 Foundations pages, so that
everything a ReaImGui window can do from them is done. Worked from a checklist
of every guideline, with decisions shared with Midi Suggester 1.3 and Midi
Variator 1.5. Starting Blocks Notation got the same window changes in the same
session but is finished separately. The table is in
[`../apple-hig-review.md`](../apple-hig-review.md); the decision is
[0009](../decisions/0009-apples-hig-foundations.md)'s dated section.

## What changed

- Theme: menus and tooltips lighter than the window, with a rule; menu bar,
  menu highlight and resize corner in house greys (ImGui's blue highlight left
  menu words at 2.4:1); shortcut keys 7:1; scrollbar grab 3:1.
- `framed()` puts a 4.7:1 edge on slider tracks and the Loop box (1.1:1 before).
- Every row wraps (`flowNextW`, `flowText`, `slider()` and `checkbox()` place
  themselves); `dim()` wraps; tooltips wrap (`BeginTooltip`, `PushTextWrapPos`).
- Minimum window size; Escape lets go of focus or a menu before closing; the
  title names the block; the roll's size, lines and playhead through `px()`;
  bar lines `#6D7581`.
- Tooltips for Octaves, Octave, Gate % and Loop.

## Checks

`tests/test_ui.lua` gained a ruler in its mock (each line laid out as ImGui
does, with the room left after `SameLine`), and a final-sweep section. Twenty
sabotages in scratch copies, all caught. Two (taking the edge off the Loop box
by deleting only the push, or only the pop) were caught by the frame's
push/pop balance rather than by the edge check; the edge check catches a faint
edge.

## Not done

Not run in REAPER. Only REAPER can show that a tooltip appears for the
focused control, that the first Escape takes the ring away, and the minimum
size.
