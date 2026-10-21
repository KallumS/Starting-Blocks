# Review against Apple's Human Interface Guidelines: Foundations

Starting Blocks checked against all 19 Foundations pages (the user's copy,
October 2026), the same review Transient Shuffler had. Writing was done
first, on its own ([0008](decisions/0008-the-window-follows-apples-writing-guidelines.md));
this covers the rest ([0009](decisions/0009-apples-hig-foundations.md)).

The window is drawn by ReaImGui inside REAPER, so some guidance cannot apply:
a script cannot reach VoiceOver, Dynamic Type or Increase Contrast, or read the
system's appearance. Where a guideline is not met for that reason, this says
so rather than counting it as met.

## What changed (2.4)

| Guideline | Before | Now |
| --- | --- | --- |
| **Accessibility: the keyboard alone** | Mouse only. | Keyboard navigation is on: Tab and the arrow keys move between controls, Space or Return presses one, and a near-white ring shows where you are. |
| **Accessibility, Typography: larger text** | One fixed size. | **View → Text Size**: 100%, 125%, 150% or 200%, also Cmd+= and Cmd+- (Ctrl on Windows), Cmd+0 for 100%. Remembered between runs. Buttons grow with the text and rows wrap at the window's edge. |
| **Typography: default size** | ReaImGui's own font. | The system's sans-serif at 13 points, the Mac's default text size. |
| **Accessibility: control size and spacing** | Buttons 19 points tall, 8 apart. | 28 points tall (Apple's Mac default) with 12 between them. |
| **Accessibility, Dark Mode: contrast** | Secondary text 4.7:1, warnings 3.4:1. | Every line of text is at least 7:1, the target for small text in a dark window: secondary text `#B0B6C0` (7.4:1), warnings `#FF9E96` (7.6:1). The house red is no longer used for words. |
| **Accessibility, Color: more than colour alone** | A chosen button was shown only by being yellow. | It also has a dark bar under its label. |
| **Layout: nothing important at the bottom of a window** | The message line came last, under Insert, Export and Audition. | It sits at the top, above step 1. |
| **Accessibility: avoid time-boxed elements** | (Messages stayed, but could not be cleared.) | A message stays until **Dismiss**, or a newer one replaces it. |

## Already met

- **Design principles.** The smallest useful piece: three numbered steps in reading order, no dead controls, one setting shown wherever it is asked. Insert is one REAPER undo step and nothing in the project is changed until you insert.
- **Feedback.** Controls change on hover and press; the roll shows the block; the playhead moves while auditioning; Audition turns into Stop.
- **Playback you control.** Nothing plays until Audition is clicked, and Stop ends it; Loop is off until ticked.
- **Colour.** One yellow, for what is on and for the notes, kept apart by ground: the roll is far darker than the chrome (decision 0002).
- **Motion.** Nothing animates except the playhead, which follows playback.
- **Dark Mode.** Always dark. Apple allows this for apps built around media,
  and advises against an app-only appearance setting; it is also the house
  scheme.
- **Writing.** Decision 0008.
- **Privacy.** Nothing is collected or sent. Only preferences are saved, in REAPER's own settings; an exported .mid goes where REAPER's resource folder is.
- **Inclusion.** Plain musical words; the tooltips explain each choice.

## Not met, because a ReaImGui script can't

- **VoiceOver, Voice Control and Switch Control** cannot read a ReaImGui
  window.
- **Dynamic Type and Increase Contrast** cannot be read from a script. Text
  Size and the 7:1 colours stand in for them.
- **Right to left.** The window is English only; time runs left to right, as in
  every DAW.

## Not relevant

Materials (Liquid Glass), app icons, icons and SF Symbols, images, spatial
layout and immersive experiences: the window has none of these.

## Unverified in REAPER

- Whether REAPER hands Cmd+=, Cmd+- and Cmd+0 to the window (the View menu
  does the same either way).
- Which face "sans-serif" gives on each system (Helvetica or San Francisco on
  a Mac, Segoe UI or Arial on Windows).

## Checked by

`tests/test_ui.lua` with `tests/hig_mock.lua` (the family's shared checks): keyboard navigation on and its ring not the accent; 13-point text, 28-point controls, 12 points apart; every line of text 7:1 on the ground and every button's ink 7:1 on its fill; a bar on every chosen button; the warning above everything else, still there twenty frames later, gone on Dismiss; the View menu's sizes, the keys, every button wide enough for its label at 200%, the size saved under its own key, clamped and restored. Each was broken on purpose and the suite failed - except a button narrower than its label, which no label here can be: every fixed width already holds its label at every size.

## Final sweep (16 October 2026)

Every guideline the family's checklist marks as possible in a window like
this one, checked again against Apple's pages (2.5, finished 21 October;
[0009](decisions/0009-apples-hig-foundations.md)). Contrast is WCAG's ratio,
measured; sizes are points at 100%.

| Guideline | Verdict |
| --- | --- |
| Accessibility: familiar, consistent interaction (ACC-01, ACC-32) | Met: click, Return/Space, Tab, Esc behave as in the sister windows. |
| Accessibility: never one channel only (ACC-02, ACC-15, COL-08) | Met: chosen buttons have the ink bar; a warning's words say it is one; the notes are one colour. |
| Accessibility: text to 200%, icons grow with it (ACC-06, ACC-07, TYP-17) | **Fixed now**: the roll, its lines and the playhead now grow with Text Size too (they were fixed pixels). |
| Accessibility, Typography: 13 pt, nothing under 10 pt (ACC-08, TYP-01) | Met: every word is 13 pt at 100%. |
| Typography: no light weights, few faces, no SF bundled (ACC-09, TYP-03, TYP-05, TYP-08) | Met: the system sans-serif, regular. |
| Accessibility: 7:1 text (ACC-10, DRK-07) | Met, and **fixed now** in two places: a menu item under the pointer was ImGui's blue (2.4:1 under its words), now `#3A404A` (8:1); the shortcut keys in the View menu were `#8A919C` (4.2:1 on the lighter menu), now `#BFC5CE`. |
| Accessibility: non-text contrast 3:1 (ACC-11, DRK-10) | **Fixed now**: tick box and slider tracks were 1.1:1 on the ground and now have a `#8A919C` edge (4.7:1); the roll's bar lines 1.8:1 → `#6D7581` (4.0:1); the scrollbar's grab 2.6:1 → 3.6:1; the window's resize corner was ImGui's blue, now 3.2:1 grey. Beat lines stay a faint guide between bar lines. Focus ring 13.6:1, notes 15:1. |
| Accessibility: colour-blind pairs (ACC-16, COL-09) | Met: one hue (yellow) against cool greys; nothing is told apart by red/green. |
| Accessibility: let people recolour (ACC-17, COL-07) | The user's decision: the three colours are settled (CLAUDE.md). |
| Accessibility: every sound has something to see (ACC-21, MOT-02) | Met: the playhead moves and Audition reads Stop. |
| Accessibility: 28 pt controls, 20 pt targets, 12 apart (ACC-22, ACC-23) | Met; no icon-only buttons. |
| Accessibility: room round frameless targets (ACC-24) | Not applicable: nothing frameless is clickable (the roll only shows). |
| Accessibility: simple gestures, a key for every drag (ACC-25, ACC-26, ACC-30) | Met: sliders take the arrow keys once focused (ImGui); nothing needs right-click or a drag only. |
| Accessibility: system shortcuts left alone (ACC-31) | Met: only Cmd+=, Cmd+-, Cmd+0. |
| Accessibility: nothing on a timer (ACC-33) | Met: the message stays until Dismiss. |
| Accessibility: sound only when asked, Stop always there (ACC-35) | Met: nothing plays by itself; the same button is Stop while it plays. |
| Accessibility: motion and flashing (ACC-37–42, MOT-15, COL-26) | Met: the playhead follows the music; a note lighting is far below any flash threshold. |
| Accessibility: ask before what can't be undone (ACC-43, DP-06) | Met: Insert is one REAPER undo step; Export never overwrites (a new name each time); no edits to lose. |
| Accessibility: VoiceOver can read the title (ACC-18b) | **Fixed now**: the title names the block on screen ("Starting Blocks — …"). |
| Accessibility: native dialogs (ACC-18c) | Not applicable: no choice or text entry needs one. |
| Accessibility: Esc cancels (ACC-32, DP-05) | **Fixed now**: Esc lets go of the keyboard's ring or an open menu first; only with nothing in hand does it close the window. |
| Branding (BRA-02–10) | Met: the accent is spent on what is on; no logo, no splash, no Apple names. |
| Color: one meaning per colour, accent sparing (COL-01, COL-12, COL-14, COL-16) | Met: yellow is on and the notes, which sit on the far darker roll (0002); the house red is never words. |
| Color: inactive selection dimmed (COL-22) | Not applicable: chosen buttons are settings, not a selection, and stay as they are. |
| Color: zebra rows (COL-21) | Not applicable: there are no lists. |
| Dark Mode: dark only, and why (DRK-04, DRK-01) | Met: written down above; a script cannot follow the system appearance. |
| Dark Mode: raised surfaces lighter (DRK-14) | **Fixed now**: menus and tooltips `#2A2F37` with a `#3A404A` rule, over the `#23272E` window (they were darker, `#1B1F25`); the menu bar wears the scheme instead of ImGui's neutral grey. |
| Dark Mode: off-white pages (DRK-08) | Not applicable: there is no light page here. |
| Design principles (DP-04, DP-11, DP-13, DP-16, DP-18) | Met: opens on the last state; hover/press distinct; numbered steps; nothing hidden that is needed. |
| Icons, SF Symbols, Images (ICN, SFS, IMG) | Not applicable: no icons or pictures; the roll is drawn at the screen's scale. |
| Inclusion and Writing (INC-04–10, INC-19, WRI-12, WRI-19) | Met: no "we", no idioms, no gendered or ableist words. |
| Inclusion: explain terms (INC-06, WRI-22) | **Fixed now**: Octaves, Octave, Gate % and Loop have tooltips saying what they do (Repeats said already). |
| Layout: wrap rather than crop; same functions at every size (LAY-07, LAY-08, LAY-09, LAY-12, TYP-18, TYP-19) | **Fixed now**: every row wraps at the window's edge (the sliders, the Insert/Export/Audition row, the message and its Dismiss, the notes beside the degrees), and long lines of words wrap. Nothing is cut off at 200%. |
| Layout: a minimum window size (LAY-20) | **Fixed now**: 320 × 240 points, grown with the text size. |
| Layout: line length (LAY-14) | **Fixed now**: tooltips wrap at about 60 characters (a long one ran off the screen at 200%). |
| Layout: nothing at the bottom edge (LAY-16) | Met (2.4). |
| Materials (MAT-02, MAT-05) | Met: no text over pictures, no translucency. |
| Motion (MOT-01–06) | Met: the playhead only. |
| Privacy (PRV-01–04, PRV-16) | Met: nothing collected; preferences in REAPER's own settings. |
| Spatial layout: one window, no overlapping targets, no text shadows (SPA-04, SPA-05, SPA-07) | Met. |
| Typography: heading sizes kept at 200% (TYP-04), tooltip font (TYP-21) | Met: one size, scaled whole. |
| VoiceOver, Dynamic Type, Increase Contrast, system appearance, right to left | Not possible from a script (above). |

Checked by `tests/test_ui.lua`'s final-sweep section: menus lighter than the
window with a lighter rule, a menu item's words and shortcut keys 7:1, every
grey in the theme blue-shifted, the scrollbar grab and the resize corner 3:1,
every slider and tick box with an edge 3:1 and a tooltip, tooltips wrapping at
a reading width, the minimum size growing with the text, every row of every
panel in every state inside the narrowest window at 100% and 200% (a ruler in
the mock lays each line out as ImGui does), Escape letting go before closing,
the roll's bar lines 3:1 and its height doubling at 200%, and the block's name
in the title. Each was broken on purpose in a copy and the suite failed.

Only REAPER can confirm: that ReaImGui shows a tooltip for the focused
control, that the first Escape takes the ring away, and the minimum size.
