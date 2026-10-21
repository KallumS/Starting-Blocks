# Apple HIG Foundations: a checklist for custom-drawn REAPER windows on macOS

> **What this is.** Every guideline in Apple's 19 Human Interface Guidelines
> *Foundations* pages, as a checklist for the user's REAPER windows: 343 rows,
> each with an ID, a paraphrase in our own words, a testable criterion and a
> tag saying whether a custom-drawn window can do it. Written 16 October 2026
> from the user's copy of the pages, and used for the family's HIG work (in this
> repo, decision 0009 and `docs/apple-hig-review.md`). Apple's own text is
> copyrighted and is deliberately **not** in this repository: nothing here is
> quoted (checked: no run of eight words matches the source). Kept here so
> future projects can be held to the same list.

Source: all 19 Foundations pages, read in full (the Typography spec tables included).
The wording here is a paraphrase. No Apple text is quoted.

**Scope.** Windows drawn by the app itself: ReaImGui (Lua), `gfx` (Lua), JSFX `@gfx` (EEL2), plus one JUCE plugin editor.
They are hosted inside REAPER or a DAW. Most of them cannot reach VoiceOver, Dynamic Type, Increase Contrast,
Reduce Motion or Transparency (as system settings), the system appearance, SF Symbols, Liquid Glass or AppKit controls.

**Tags**

- **IMPL**: this can be done in a custom-drawn window.
- **IMPL (covered)**: the house list already covers it (7:1 text, Text Size 100–200%, 28 pt controls 12 apart, Tab focus ring, ink bar, message at top until dismissed, Reduce Motion, Apple writing style).
- **IMPL (analog)**: the guideline is written for another platform or API, but the same idea works here.
- **JUCE-ONLY**: only the JUCE plugin, or its Standalone app, can do it.
- **NOT-POSSIBLE**: the host or API cannot do it. The reason is given.
- **NOT-RELEVANT**: the guideline is about another platform or a feature these apps don't have.

Where a number comes from WCAG and not from these pages, it is marked **[WCAG]**.

---

## Accessibility (ACC)

| ID | Guideline (paraphrase) | Testable criterion | Tag |
|---|---|---|---|
| ACC-01 | Interactions should be familiar and behave the same everywhere | The same key, click or drag does the same kind of thing on every page and in sister apps | IMPL |
| ACC-02 | Never carry information by one sense or channel only | Every state is shown as text or shape as well as by colour, sound or motion | IMPL |
| ACC-03 | Adapt to people: honour their system settings or let them personalise | In-app settings exist for size, motion and colours, because system settings don't reach the window | IMPL (system part NOT-POSSIBLE) |
| ACC-04 | Audit with Accessibility Inspector | The plugin editor's accessibility tree has no warnings. A script window shows only its title. | JUCE-ONLY |
| ACC-05 | Declare accessibility support on the App Store (Nutrition Labels) | — | NOT-RELEVANT (not on the App Store) |
| ACC-06 | Let text be enlarged to at least 200% | A Text Size setting from 100% to 200% | IMPL (covered) |
| ACC-07 | Let icons and glyphs grow too, not only words | At 200%, every drawn icon, arrow, tick and symbol is twice its 100% size | IMPL |
| ACC-08 | macOS type: 13 pt by default, never below 10 pt | At 100%, no string is under 10 pt. That includes axis numbers, ruler labels, note names and footnotes. | IMPL (13 pt covered; check the 10 pt floor) |
| ACC-09 | Thin weights need bigger sizes | No Light, Thin or Ultralight face at body sizes | IMPL |
| ACC-10 | Minimum contrast: 4.5:1 for text up to 17 pt; 3:1 at 18 pt and above or in bold | The floor is met everywhere, including disabled-looking labels that still carry meaning | IMPL (covered by 7:1) |
| ACC-11 | Contrast also applies to icons, not only text | Meaningful glyphs, notes, meters, input borders and the focus ring are ≥3:1 against what they sit on [WCAG 1.4.11] | IMPL |
| ACC-12 | If the defaults miss the minimum, give a higher-contrast scheme under Increase Contrast | The setting can't be read. Moot while every text colour is 7:1. | NOT-POSSIBLE (detection) |
| ACC-13 | Check contrast in every appearance you ship | Any alternate palette (e.g. Light Page) passes the same contrast checks | IMPL |
| ACC-14 | Prefer the system's adaptive colours | — | NOT-POSSIBLE (no NSColor in Lua, EEL2 or ImGui) |
| ACC-15 | Use shape, icon or text as well as colour | Covered for chosen buttons. Check notes, graph lines, rarities, status lights and warnings. | IMPL (partly covered) |
| ACC-16 | Watch the colour-blind pairings (red–green, blue–orange) | No two states differ only by such a hue pair. Check screenshots in a CVD simulator. | IMPL |
| ACC-17 | Consider letting people recolour charts and characters | The user can pick the roll, highlight and graph colours | IMPL |
| ACC-18 | Describe the interface for VoiceOver | Every control has an accessible name and role | JUCE-ONLY (scripts and JSFX NOT-POSSIBLE) |
| ACC-18b | (derived) VoiceOver can at least read a window's title | The window title names the app, and its current state where useful | IMPL (ReaImGui and `gfx`) |
| ACC-18c | (derived) Native dialogs reach VoiceOver | Confirmations, text entry and choices use `ShowMessageBox`, `GetUserInputs` or `gfx.showmenu` where they fit | IMPL (ReaScripts) |
| ACC-19 | Captions, subtitles, audio description and transcripts for media | — | NOT-RELEVANT (no video or dialogue) |
| ACC-20 | Pair audio cues with haptics | — | NOT-POSSIBLE |
| ACC-21 | Pair audio cues with visual cues | Every sound the app makes (audition, preview, error beep) has a visible counterpart: a playhead, a "Playing" label or a message | IMPL |
| ACC-22 | macOS control size: 28×28 pt by default, 20×20 pt at the least | Icon-only buttons are ≥28 pt wide too. No hit target is under 20×20 pt. | IMPL (height covered; check width) |
| ACC-23 | About 12 pt of space around controls with a bezel | Gaps between framed buttons are ≥12 pt | IMPL (covered) |
| ACC-24 | About 24 pt of space around clickable things with no bezel | Text links, bare icons, clickable notes or circles and chips without a fill have ≥24 pt clearance, or are given a bezel | IMPL |
| ACC-25 | Use the simplest gesture for frequent actions | No common action needs a modifier-plus-drag or a chord of keys | IMPL |
| ACC-26 | Every gesture has an on-screen alternative | Each drag, scroll, double-click, right-click or modifier-click has a button, menu item or key | IMPL |
| ACC-27 | Label elements so Voice Control can target them | — | JUCE-ONLY (scripts NOT-POSSIBLE) |
| ACC-28 | Siri and Shortcuts for voice and automation | Analog: expose the main commands as REAPER actions, so they can be bound to keys, MIDI or OSC | NOT-POSSIBLE (Siri); IMPL (analog) |
| ACC-29 | Work with Full Keyboard Access, Switch Control and Pointer Control | The keyboard is covered. Switch Control needs accessibility objects. | IMPL (keyboard covered); JUCE-ONLY (switch) |
| ACC-30 | Everything works from the keyboard alone | Every control can be reached and used: drags, menus, clicks on the roll, text entry | IMPL (covered; re-audit new controls) |
| ACC-31 | Don't override system shortcuts | No binding on ⌘Q, ⌘W, ⌘H, ⌘M, ⌘Tab, ⌘`, ⌘Space or ⌘, unless it does the system meaning. Space stays REAPER's. | IMPL |
| ACC-32 | Keep actions simple; prefer familiar system behaviour over custom | Click selects, Return activates, Esc cancels, scroll scrolls | IMPL |
| ACC-33 | Avoid UI that times out; dismiss explicitly | No message, toast, "Sure?" state or hint expires on its own. (Battle Pass's 3-second "Sure?" revert is a time-box.) | IMPL (messages covered) |
| ACC-34 | Offer difficulty accommodations in games | Battle Pass: the idle threshold, the pace of goals and quest difficulty can be adjusted | IMPL (game only) |
| ACC-35 | Never autoplay sound without visible start and stop controls; offer an opt-out | Auto-audition and "play new ideas" settings: Stop is always visible, and the opt-out is remembered | IMPL |
| ACC-36 | Honour Dim Flashing Lights in video | — | NOT-RELEVANT (no video) |
| ACC-37 | Be careful with fast or blinking animation; under Reduce Motion, cut automatic or repeating zoom, scale and peripheral motion | An in-app Reduce Motion switch (the system flag can't be read) | IMPL (covered where animation exists) |
| ACC-38 | Reduce Motion: stiffen springs, no bounce | With Reduce Motion on, nothing overshoots | IMPL |
| ACC-39 | Reduce Motion: motion follows the pointer directly | Dragged items track the cursor 1:1 and don't coast | IMPL |
| ACC-40 | Reduce Motion: no animated depth changes | No zoom-in or zoom-out transitions | IMPL |
| ACC-41 | Reduce Motion: fade instead of sliding | Panels and pages cross-fade, or switch at once | IMPL |
| ACC-42 | Reduce Motion: don't animate into or out of blur | No blur transitions | IMPL |
| ACC-43 | (Assistive Access, iOS) Keep only core flows, one interaction per step, confirm twice before hard-to-undo actions | The principle carries over: anything that can't be undone (deleting or overwriting files, discarding edits) asks first | NOT-RELEVANT (iOS); IMPL (principle) |
| ACC-44 | visionOS comfort and Pointer Control | — | NOT-RELEVANT |

## App icons (APP)

ReaScripts and JSFX have no app icon. These rows apply only to the JUCE Standalone app, or to any REAPER toolbar icon PNG you choose to ship.

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| APP-01 | A distinctive icon that says what the app is for | Recognisable at small sizes | JUCE-ONLY (Standalone); IMPL if shipping toolbar art |
| APP-02 | Build layers in Icon Composer for Liquid Glass effects | — | JUCE-ONLY (needs Xcode) |
| APP-03 | Foreground layers have crisp edges, not feathered ones | — | JUCE-ONLY |
| APP-04 | Vary layer opacity for depth | — | JUCE-ONLY |
| APP-05 | A simple solid or gradient background; imported art full-bleed and opaque | — | JUCE-ONLY |
| APP-06 | Vector layers, with text converted to outlines; lossless PNG for raster art | — | JUCE-ONLY |
| APP-07 | Supply square, unmasked art; the system rounds the corners | 1024×1024 px | JUCE-ONLY |
| APP-08 | Keep the main motif centred so masking doesn't cut it | — | JUCE-ONLY |
| APP-09 | One simple idea in few shapes; the background needn't be filled | — | JUCE-ONLY / toolbar art |
| APP-10 | The same icon design on every platform and format | VST3, AU, CLAP and Standalone match | JUCE-ONLY |
| APP-11 | Filled, overlapping shapes rather than outlines | — | JUCE-ONLY |
| APP-12 | Text only if essential; no "Play", "New" or platform words | — | JUCE-ONLY / toolbar art |
| APP-13 | Illustration, not photos or UI screenshots; no hairlines or needle-sharp corners | — | JUCE-ONLY |
| APP-14 | No replicas of Apple hardware in any artwork | Applies to rendered pictures too (Instrument Creator) | IMPL |
| APP-15 | Let the system add highlights, shadows and blur; don't bake them in | — | JUCE-ONLY |
| APP-16 | Group layers to apply effects together | — | JUCE-ONLY |
| APP-17 | Dark, clear and tinted variants keep the same features | — | JUCE-ONLY |
| APP-18 | Derive the dark variant from the light one; nothing too bright | — | JUCE-ONLY |
| APP-19 | Alternate app icons | — | NOT-RELEVANT (iOS, tvOS) |
| APP-20 | tvOS safe zone, visionOS concave shapes, watchOS black backgrounds | — | NOT-RELEVANT |
| APP-21 | Colour spaces: sRGB, Gray Gamma 2.2, P3 | Icon art in sRGB | JUCE-ONLY |

## Branding (BRA)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| BRA-01 | One voice and tone in every piece of copy | A shared term list across the sister apps | IMPL (style covered; add the list) |
| BRA-02 | Use the accent colour sparingly: the primary action, status and the selected item, not every control | The yellow appears only on "on" states and the one primary action | IMPL (covered by the house rule) |
| BRA-03 | Brand colour can live in the content rather than on controls | e.g. notes in the roll | IMPL |
| BRA-04 | A custom font must be legible at every size and scale with the text setting; use the system font for body text and captions | Bravura only for music; words in the system sans | IMPL |
| BRA-05 | Express the brand through familiar components; keep standard size, placement and behaviour | Buttons look and act like buttons | IMPL |
| BRA-06 | Branding gives way to content: no space spent only on a logo | No header strip whose only content is the app name or logo | IMPL |
| BRA-07 | Standard patterns: controls in expected places, standard symbols, standard navigation and modality | — | IMPL |
| BRA-08 | Don't repeat the logo through the app | — | IMPL |
| BRA-09 | No branded launch or splash screen; a welcome screen is fine | The window opens straight to work | IMPL |
| BRA-10 | Keep Apple trademarks out of names and images | No "Mac", "Logic", "Apple" or "iPhone" in product names or icons | IMPL |

## Color (COL)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| COL-01 | One colour, one meaning; never style static text in the "interactive" colour | The accent never colours plain text that is neither "on" nor clickable | IMPL |
| COL-02 | Colours work in light, dark and increased contrast | Dark only (see DRK-04). Alternate pages are checked too. | IMPL / NOT-POSSIBLE (system modes) |
| COL-03 | Supply light and dark variants for Liquid Glass even in single-appearance apps | — | NOT-POSSIBLE |
| COL-04 | Test under bright and dim lighting | Review at low brightness in a dark room and in daylight; the accent shouldn't glare | IMPL |
| COL-05 | Test on several displays and colour profiles (sRGB vs P3, True Tone) | Check under Displays → Color Profile on both | IMPL |
| COL-06 | Artwork and translucency change how nearby colours look; adjust the neighbours | Text over a scope, roll or picture still reads | IMPL |
| COL-07 | If people pick colours, use the system colour picker | `reaper.GR_SelectColor` in ReaScripts. JSFX can't. | IMPL (ReaScripts); NOT-POSSIBLE (JSFX) |
| COL-08 | Never rely on colour alone to tell objects or states apart, show interactivity or carry essential information | See ACC-15 | IMPL |
| COL-09 | Avoid combinations that are hard to see (low contrast, CVD confusion) | CVD-simulated screenshots stay readable | IMPL |
| COL-10 | Colours mean different things in different cultures | A warning says so in words, not only in red | IMPL |
| COL-11 | Don't hard-code system colour values | Analog: name colours by role, as tokens | NOT-RELEVANT / IMPL (analog, covered) |
| COL-12 | Don't use a semantic colour outside its role (e.g. separator colour as text) | Each palette role is used only for its job: separator grey never for words, red never for text | IMPL (analog, partly covered) |
| COL-13 | Liquid Glass tinting | — | NOT-POSSIBLE |
| COL-14 | Emphasise a primary action with a filled background, not coloured label text; don't fill many controls with the accent | At most one accent-filled primary button per group | IMPL |
| COL-15 | Over colourful content, keep control labels monochrome, or pick an accent clearly unlike the content | — | IMPL |
| COL-16 | Keep content colours from clashing with control colours where they meet; legible at rest | The roll's yellow notes never sit under a yellow control | IMPL |
| COL-17 | Embed a colour profile in images (sRGB is fine) | Rendered PNGs and screenshots carry sRGB | IMPL |
| COL-18 | Wide colour (P3, 16-bit PNG) where it helps | — | NOT-RELEVANT |
| COL-19 | Give sRGB variants if P3 colours clip | — | NOT-RELEVANT |
| COL-20 | Use macOS's dynamic colours (label tiers, placeholder, separator, link, selection, disabled text, focus ring…) | Analog: the palette has a token for each of these roles | NOT-POSSIBLE / IMPL (analog) |
| COL-21 | Alternate row backgrounds in lists and tables | Long lists use zebra rows or separators | IMPL |
| COL-22 | Show selection more softly when the window isn't key | Selection or the accent dims when the window loses focus (`IsWindowFocused`; `gfx.getchar(65536)`) | IMPL (ReaImGui, `gfx`, JUCE); NOT-POSSIBLE (JSFX) |
| COL-23 | The user's system accent colour replaces the app's | — | NOT-POSSIBLE (scripts); JUCE-ONLY (native code) |
| COL-24 | (tvOS) Don't show focus by colour alone | The focus ring is a shape (covered) | IMPL (covered) |
| COL-25 | (visionOS) Colour works best in bold text and large areas | Coloured words are bold or large | IMPL (analog) |
| COL-26 | (visionOS) Balance brightness; no bright flashing object on a black ground | No bright flash or particle burst on the near-black ground; ≤3 flashes per second [WCAG 2.3.1] | IMPL (analog) |
| COL-27 | (watchOS) Colour a background only when it says something; avoid full-window colour on long-lived views | — | IMPL (analog) |
| COL-28 | System colour value tables (light, dark, increased contrast) | Reference only | NOT-RELEVANT |

## Dark Mode (DRK)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| DRK-01 | Follow the system appearance; no app-only appearance switch | Lua and EEL2 can't read the macOS appearance. JUCE can. | NOT-POSSIBLE (scripts); JUCE-ONLY |
| DRK-02 | Look right in both modes, including Auto switching while running | — | NOT-POSSIBLE (scripts); JUCE-ONLY |
| DRK-03 | Test with Increase Contrast and Reduce Transparency, alone and together | These don't reach the window. Confirm nothing depends on them. | NOT-POSSIBLE |
| DRK-04 | A dark-only interface is fine in rare, media-focused cases | Write down why: DAW convention, studio lighting, content focus | IMPL |
| DRK-05 | A dark palette is not an inversion: dim the backgrounds, brighten the foregrounds | — | IMPL (covered by the ramp) |
| DRK-06 | Use adaptive colours, not fixed values | — | NOT-POSSIBLE / analog tokens |
| DRK-07 | Contrast 4.5:1 at minimum, aiming for 7:1 for small text | — | IMPL (covered) |
| DRK-08 | Soften white backgrounds in images shown in a dark context | Light Page uses off-white, not #FFFFFF | IMPL |
| DRK-09 | Use SF Symbols | — | NOT-POSSIBLE |
| DRK-10 | Give an edge to icons that would vanish on a dark ground | Dark glyphs or notes on the dark ground get a lighter outline, or reach ≥3:1 | IMPL |
| DRK-11 | Full-colour images must read in your appearance; adjust them if not | Rendered pictures checked on the dark ground | IMPL |
| DRK-12 | Use the label tiers (primary to quaternary) | A fixed set of text tiers | IMPL (covered) |
| DRK-13 | Prefer system text fields to drawn text | `GetUserInputs` gives a native field for occasional entry | NOT-POSSIBLE (in-window); IMPL (dialog) |
| DRK-14 | (iOS) Surfaces in front (popups, sheets) use a lighter "elevated" background | Popups, menus and modals are a step lighter than the base chrome. Note: the house popup #1B1F25 is darker than chrome #23272E. | NOT-RELEVANT (platform); IMPL (analog) |
| DRK-15 | (macOS) Partial transparency to pick up desktop tinting | — | NOT-POSSIBLE |

## Design principles (DP)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| DP-01 | Every feature serves the app's purpose | Each control maps to a stated job | IMPL |
| DP-02 | Focus: make the core features excellent | — | IMPL |
| DP-03 | Don't rebuild what already exists; find your own angle | No duplicates of REAPER's built-in features | IMPL |
| DP-04 | Stay out of the way: take people straight to the task | It opens on the last state, with no intro to click through | IMPL |
| DP-05 | Freedom to explore; no lock-in modes; guided flows can be skipped or escaped | Every modal, stage or step leaves with Esc or a visible Cancel | IMPL |
| DP-06 | Make mistakes cheap to recover from | Every project write is one REAPER undo point; there's in-app undo or back for edits and settings; nothing is lost on close | IMPL |
| DP-07 | Be transparent about what the product does and why | Background behaviour (activity watching, autostart, playing with REAPER) is explained in the window | IMPL |
| DP-08 | Collect only what's needed and keep it safe | See PRV | IMPL |
| DP-09 | Build on concepts people know (the real world and other software) | Musical and REAPER vocabulary | IMPL |
| DP-10 | Once a look or behaviour is set, apply it everywhere | Consistent across pages and the sister apps | IMPL (covered by the house scheme) |
| DP-11 | Clear feedback: show what's available, show when content changes, use system patterns for alerts and choices | Hover, pressed and disabled states are distinct; changed content is flagged; native alerts where possible | IMPL |
| DP-12 | Design for everyone; accessibility from the start | — | IMPL |
| DP-13 | Preserve context: keep content and controls in predictable places; ease transitions | Controls don't jump when state changes. This pulls against "No dead controls" hiding things. | IMPL |
| DP-14 | Support many input methods | Mouse, trackpad and keyboard (MIDI where it fits) | IMPL |
| DP-15 | Equal care on every platform supported | Windows and Linux builds are checked too | IMPL |
| DP-16 | Include only what's needed; let secondary items recede | Progressive disclosure | IMPL |
| DP-17 | Be concise in labels and copy | — | IMPL (covered) |
| DP-18 | Clear hierarchy: people know where they are and what's next | Numbered steps | IMPL (covered) |
| DP-19 | Craft: deliberate visuals, smooth motion, precise words, thoughtful sound | — | IMPL |
| DP-20 | Prototype, iterate, and test in real settings | Run it in REAPER, not only against mocks | IMPL |
| DP-21 | Keep maintaining after release | — | IMPL |
| DP-22 | Decide the emotion to evoke | — | IMPL |
| DP-23 | Treat small moments, error messages included, as chances for character | — | IMPL |
| DP-24 | Delight is not decoration; never at the task's expense | — | IMPL |

## Icons (ICN)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| ICN-01 | Simple, recognisable glyphs, using a metaphor tied directly to the action or content | — | IMPL |
| ICN-02 | All interface icons share size, detail, stroke weight and perspective | One stroke width (scaled), one grid | IMPL |
| ICN-03 | Adjust dimensions optically so light and heavy shapes look equal | — | IMPL |
| ICN-04 | Match an icon's weight to the text beside it | — | IMPL |
| ICN-05 | Centre asymmetric glyphs optically, not geometrically (pad them) | — | IMPL |
| ICN-06 | Make a separate selected-state icon only when needed | A fill variant marks selection | IMPL |
| ICN-07 | Inclusive imagery: gender-neutral figures, nothing culture-bound | — | IMPL |
| ICN-08 | Letters in an icon only when essential, and localised | — | IMPL |
| ICN-09 | Vector icons, or bitmaps at every scale | Drawn as vector paths at the current scale, or with @1x and @2x | IMPL (partly covered by `px()`) |
| ICN-10 | Accessibility descriptions for custom icons | Analog: every icon-only button has a text name shown on hover and on focus | JUCE-ONLY; IMPL (analog) |
| ICN-11 | No replicas of Apple hardware | — | IMPL |
| ICN-12 | Use the standard meanings: scissors = cut, two pages = copy, clipboard = paste, check = done or save, X = cancel or close, trash = delete, curved arrows = undo and redo, + = add, … = more, pencil = rename, folder, magnifier = search, three lines = filter, box with up arrow = share or export, printer = print | These glyphs are never used for other meanings | IMPL |
| ICN-13 | Document icons for custom file types | — | NOT-RELEVANT |

## Images (IMG)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| IMG-01 | Lay out in points; the scale factor maps points to pixels | Sizes × the Retina or DPI scale | IMPL (covered by `px()` and `gsc`) |
| IMG-02 | macOS needs @1x and @2x bitmaps | Every PNG has a 2× version, or is rendered at 2× | IMPL |
| IMG-03 | Design at 1×; put vector points and edges on whole points so they stay crisp at 2× | Rectangles and 1-pt lines snap to the pixel grid | IMPL |
| IMG-04 | Formats: de-interlaced PNG; an 8-bit palette when full colour isn't needed; JPEG or HEIC for photos; PDF or SVG for flat art | — | IMPL |
| IMG-05 | Embed a colour profile | — | IMPL |
| IMG-06 | Test images on real screens | Retina and non-Retina | IMPL |
| IMG-07 | tvOS layered images and parallax | — | NOT-RELEVANT |
| IMG-08 | visionOS vector art, high-res rasters, spatial photos | — | NOT-RELEVANT |
| IMG-09 | watchOS transparency and autoscaling PDFs | — | NOT-RELEVANT |

## Immersive experiences (IMM) — visionOS only

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| IMM-01 | Shared Space, Full Space, passthrough, immersion styles | — | NOT-RELEVANT |
| IMM-02 | Offer several ways to use it and respect accessibility settings | See ACC | IMPL (analog) |
| IMM-03 | Start in the least immersive mode; let people opt in | Full-window celebrations and stages are never forced | IMPL (analog) |
| IMM-04 | Save immersion for meaningful moments | The Battle Pass reward stage only for real rewards | IMPL (analog) |
| IMM-05 | Guide attention with gentle cues first, and stronger ones only if needed | — | IMPL (analog) |
| IMM-06 | Subtle passthrough tints | — | NOT-RELEVANT |
| IMM-07 | Comfort: content in view, comfortable motion | — | NOT-RELEVANT |
| IMM-08 | Choose a style that fits physical movement; the 1.5 m boundary | — | NOT-RELEVANT |
| IMM-09 | Don't require people to move | Analog: frequent actions need little mouse travel | IMPL (analog) |
| IMM-10 | Don't block passthrough in mixed immersion | — | NOT-RELEVANT |
| IMM-11 | ARKit data needs permission | — | NOT-RELEVANT |
| IMM-12 | Smooth, predictable transitions | Page or stage changes fade, or switch at once with Reduce Motion | IMPL (analog) |
| IMM-13 | Let people choose when to enter and leave; a clear exit | — | IMPL (analog) |
| IMM-14 | The exit says whether it goes back or quits; offer to save before quitting | Close vs Back are worded distinctly; state is kept on close | IMPL (analog) |
| IMM-15 | Virtual hands | — | NOT-RELEVANT |
| IMM-16 | Environments: few distractions, subtle animation, nothing moving at the edges | No busy animated backgrounds behind controls | IMPL (analog) |
| IMM-17 | Mark interactive objects clearly | Clickable things look clickable | IMPL (analog) |
| IMM-18 | Lower or stop ambient sound when other audio plays | The app's preview audio doesn't stack on the user's playback unexpectedly | IMPL (analog) |
| IMM-19 | Expansive spaces, a ground plane, few repeated assets, no flat 360° images | — | NOT-RELEVANT |

## Inclusion (INC)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| INC-01 | Learn people's goals and perspectives; keep revising | — | IMPL (process) |
| INC-02 | Weigh age, gender, culture, ability, education, economics and more | — | IMPL |
| INC-03 | Inoffensive isn't the same as inclusive | — | IMPL |
| INC-04 | Plain, welcoming tone, not academic | Hints read without formal music training | IMPL |
| INC-05 | Address people as "you"; avoid "the user" or "the player"; keep "we" for the maker | (Writing says avoid "we" entirely; follow that) | IMPL |
| INC-06 | Define specialised terms, or say it plainly; make definitions easy to find | Every theory term on screen (Neapolitan, pivot, voicing, schema…) has a hint or tooltip definition | IMPL |
| INC-07 | Swap idioms and colloquialisms for plain words | No "grandfathered", "nuke" or "kill" | IMPL |
| INC-08 | Be careful with humour (it translates badly and wears thin) | Battle Pass and generated names reviewed | IMPL |
| INC-09 | Approachable: a clear interface, with a way to learn that experts can skip | First-run guidance can be skipped | IMPL |
| INC-10 | Drop needless gender references ("his or her") | Grep the UI and docs for he, she, his, her, guys | IMPL |
| INC-11 | Avatars, glyphs and characters not gendered, or customisable | Battle Pass gear and characters | IMPL |
| INC-12 | Generic people drawn as non-gendered figures | — | IMPL |
| INC-13 | Ask for gender only if required, with inclusive options | Never asked | NOT-RELEVANT |
| INC-14 | Show varied people; avoid role stereotypes | Composer and example content | IMPL |
| INC-15 | Relatable settings and objects; don't assume wealth | Battle Pass shop rewards | IMPL |
| INC-16 | Question built-in assumptions (family, life events) | Defaults and examples don't assume one tradition or one setup | IMPL |
| INC-17 | Support accessibility features; never assume disability means no interest | — | IMPL |
| INC-18 | Disability is a spectrum, and also temporary or situational | e.g. monitoring muted, a noisy room | IMPL |
| INC-19 | No disability used as a negative ("blind to", "lame", "crippled", "dumb", "sanity check") | Grep the UI and docs | IMPL |
| INC-20 | People-first wording about disability | — | IMPL |
| INC-21 | Simple and perceivable | Duplicates ACC | IMPL |
| INC-22 | Prepare for other languages and regions (date, time, number formats) | Strings in one table, no sentence fragments glued together, consistent number and unit format. Locale detection is limited from Lua and EEL2. | IMPL (partial) |
| INC-23 | SF Symbols ease localisation | — | NOT-POSSIBLE |
| INC-24 | Check what colours mean in each locale you localise for | — | IMPL (if localised) |

## Layout (LAY)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| LAY-01 | Most important items at the top and leading edge | — | IMPL (covered) |
| LAY-02 | Align for scanning; indent to show subordination | Shared left edges; sub-options indented one step | IMPL |
| LAY-03 | Group related items with space, containers or separators | — | IMPL |
| LAY-04 | Progressive disclosure (disclosure triangles, menus, nested views) | — | IMPL (partly covered: folds) |
| LAY-05 | Make controls look distinct from content | The roll or page is clearly separate from the control area | IMPL |
| LAY-06 | Full-bleed background under bars; background extension | — | NOT-RELEVANT |
| LAY-07 | Adapt to window sizes, aspects and displays; respect margins | Correct from the minimum size to full screen, at 100% and 200% | IMPL |
| LAY-08 | Text growth: stack side-by-side items, grow rows, wrap instead of crop or overlap | No overlaps at 200% | IMPL (partly covered) |
| LAY-09 | Test the largest and smallest layouts and text sizes for clipping | — | IMPL |
| LAY-10 | Scale background art to fill without changing its aspect ratio | Pictures and pages never stretch | IMPL |
| LAY-11 | (iOS) Lay out by available space (size classes), not device | Reflow on width | NOT-RELEVANT / IMPL (analog) |
| LAY-12 | Same functions at every size; extras can move into an overflow | Nothing becomes unreachable in a narrow window (it scrolls or overflows) | IMPL |
| LAY-13 | The layout stays recognisable after a resize | — | IMPL |
| LAY-14 | Consistent margins; limit text line length for reading | One window margin; paragraphs about ≤70 characters wide | IMPL |
| LAY-15 | Respect safe areas | Keep inside the window or docker edges | NOT-RELEVANT / IMPL (analog) |
| LAY-16 | (macOS) No controls or critical information at the window's bottom edge | — | IMPL (covered) |
| LAY-17 | (macOS) Nothing behind the camera housing | — | NOT-RELEVANT (hosted window) |
| LAY-18 | tvOS safe area and grid specs | — | NOT-RELEVANT |
| LAY-19 | (tvOS) Even spacing in grids | Grids of tiles or chips use one gap | IMPL (analog) |
| LAY-20 | (visionOS) Allow resizing; a min and max size stop overlap, but don't use them to block resizing | A minimum window size or a scroll fallback | IMPL (analog) |
| LAY-21 | (visionOS) Centre content in very large windows | Cap the content width and centre it | IMPL (analog) |
| LAY-22 | visionOS 60 pt centres; ornaments | — | NOT-RELEVANT |
| LAY-23 | (watchOS) At most 2–3 controls in a row | — | NOT-RELEVANT |

## Materials (MAT)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| MAT-01 | Liquid Glass for the controls layer; not in content; sparingly; regular or clear variants | — | NOT-POSSIBLE |
| MAT-02 | Over bright content, put about a 35% dark dimming layer behind clear-glass controls | Analog: text or controls over busy graphics (scope, pictures, roll) sit on a scrim at least 35% dark, or opaque | IMPL (analog, partly covered by AutoCC's plate) |
| MAT-03 | Pick materials by meaning, not by the tint they give | Analog: role tokens | IMPL (analog) |
| MAT-04 | Use vibrant colours on materials for legibility | — | NOT-POSSIBLE |
| MAT-05 | Thicker (more opaque) backings for fine text; thinner ones keep context | No text on translucent fills | IMPL (analog) |
| MAT-06 | iOS standard materials and vibrancy levels | — | NOT-RELEVANT |
| MAT-07 | macOS vibrancy and blending modes | — | NOT-POSSIBLE |
| MAT-08 | tvOS, visionOS and watchOS materials | (visionOS: the lowest text tier only for inactive items — covered) | NOT-RELEVANT |
| MAT-09 | (derived) Reduce Transparency equivalent | No translucency in the UI, so nothing to reduce | IMPL (note) |

## Motion (MOT)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| MOT-01 | Only purposeful motion | Each animation has a stated job | IMPL |
| MOT-02 | Motion is optional and never the only carrier of information | Playing or progress is also shown in text | IMPL (partly covered) |
| MOT-03 | Feedback motion follows the gesture and expectation | Things leave the way they came | IMPL |
| MOT-04 | Feedback animation is short and precise | About ≤0.3 s (a suggestion; the page gives no number) | IMPL |
| MOT-05 | No added motion on frequent interactions | Ordinary clicks don't bump, bounce or flash | IMPL |
| MOT-06 | Motion can be cancelled; never make people wait for it | Input works during every animation; Esc or a click skips a stage | IMPL |
| MOT-07 | Animated SF Symbols | — | NOT-POSSIBLE |
| MOT-08 | Games: a steady 30–60 fps by default | Battle Pass redraw ≥30 fps | IMPL (game) |
| MOT-09 | Let people trade visuals for performance or battery | e.g. particles off | IMPL |
| MOT-10 | (visionOS) No motion in the periphery; large moving objects; no rotating world | Analog: no constantly turning decoration (covered by `calm`) | NOT-RELEVANT / IMPL (analog) |
| MOT-11 | (visionOS) Fade, don't fly, when relocating | — | IMPL (analog) |
| MOT-12 | (visionOS) A stationary frame of reference | Scrolling happens inside a fixed frame | IMPL (analog) |
| MOT-13 | (visionOS) Avoid sustained oscillation, worst near 0.2 Hz (a 5-second cycle); keep the amplitude low | Pulsing or breathing indicators avoid 4–6 s cycles and have small amplitude | IMPL (analog) |
| MOT-14 | (watchOS) Easing is automatic | — | NOT-RELEVANT |
| MOT-15 | (derived, ACC) No flashing above 3 per second | [WCAG 2.3.1] | IMPL |

## Privacy (PRV)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| PRV-01 | Ask only for data you need, when the feature needs it, as narrowly as possible | Battle Pass activity watching reads only "was there input", not which keys | IMPL |
| PRV-02 | Be transparent about what's collected and how it's used | The window or README says what is read, where it's stored, and that it stays local | IMPL |
| PRV-03 | Process on the device | No network calls | IMPL |
| PRV-04 | Use system protections and secure practices | e.g. saves loaded in an empty environment (covered in Battle Pass) | IMPL |
| PRV-05 | Protected resources need system permission prompts | REAPER owns the mic and the files | NOT-RELEVANT (scripts); JUCE-ONLY (Standalone mic) |
| PRV-06 | Ask at the moment of use, not at launch | e.g. offer autostart when it first matters | IMPL (analog) |
| PRV-07 | Purpose strings: one active, specific sentence in sentence case, with a full stop | `NSMicrophoneUsageDescription` in the Standalone | JUCE-ONLY |
| PRV-08 | A pre-permission screen has one "Continue"/"Next" button and no cancel | — | NOT-RELEVANT |
| PRV-09 | Tracking (ATT) rules; no incentives or fake alerts | — | NOT-RELEVANT |
| PRV-10 | The location button | — | NOT-RELEVANT |
| PRV-11 | Passkeys, 2FA, biometrics; no homemade authentication | — | NOT-RELEVANT (no accounts) |
| PRV-12 | Keep secrets in the Keychain | Only if API keys are ever added | NOT-RELEVANT |
| PRV-13 | Never keep passwords or secrets in plain-text files | — | IMPL (rule) |
| PRV-14 | (macOS) Sign with Developer ID for distribution outside the store | Plugin binaries signed and notarised | JUCE-ONLY |
| PRV-15 | (macOS) App sandboxing | — | NOT-RELEVANT (hosted) |
| PRV-16 | (macOS) Don't assume who is signed in (fast user switching) | Data goes in the user's REAPER resource path or ExtState, not shared locations | IMPL |
| PRV-17 | visionOS ARKit, gaze privacy, cameras | — | NOT-RELEVANT |

## Right to left (RTL)

The apps are English only. Everything here is **NOT-RELEVANT unless they are localised** into Arabic or Hebrew.
Music notation and piano rolls run left to right in every locale.

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| RTL-01 | System components flip automatically | — | NOT-POSSIBLE |
| RTL-02 | Mirror text alignment for RTL | — | NOT-RELEVANT |
| RTL-03 | Align a paragraph of 3+ lines by its own language | — | NOT-RELEVANT |
| RTL-04 | Every item in a list uses the same alignment | Holds generally | IMPL |
| RTL-05 | Pick the right numeral system per locale | — | NOT-RELEVANT |
| RTL-06 | Never reverse the digits of a number | — | NOT-RELEVANT |
| RTL-07 | Reverse the order of numbers along progress or rating scales | — | NOT-RELEVANT |
| RTL-08 | Flip sliders and progress bars | — | NOT-RELEVANT |
| RTL-09 | Flip back/next navigation | — | NOT-RELEVANT |
| RTL-10 | Never flip a control that means a real direction | Pan L/R, low→high pitch, timeline | IMPL (if ever localised) |
| RTL-11 | Arabic and Hebrew beside capitalised Latin: about +2 pt | — | NOT-RELEVANT |
| RTL-12 | Don't flip photos or artwork | — | NOT-RELEVANT |
| RTL-13 | Reverse sequences of images whose order means something | — | NOT-RELEVANT |
| RTL-14 | Flip icons that depict text or reading direction | — | NOT-RELEVANT |
| RTL-15 | Localise icons that contain letters | — | NOT-RELEVANT |
| RTL-16 | Flip icons that show forward or back motion (e.g. speaker waves) | — | NOT-RELEVANT |
| RTL-17 | Never flip logos or universal marks (the check mark) | — | NOT-RELEVANT |
| RTL-18 | Don't flip real-world objects (clock, pencil) | — | NOT-RELEVANT |
| RTL-19 | Judge an icon's parts (slashes, badges) separately when flipping | — | NOT-RELEVANT |

## SF Symbols (SFS)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| SFS-01 | Use SF Symbols for interface icons | Not available as a font in ImGui, LICE or `gfx` | NOT-POSSIBLE; JUCE-ONLY (native code) |
| SFS-02 | Check which OS each symbol needs | — | NOT-RELEVANT |
| SFS-03 | Licence: no SF Symbols, or look-alikes, in app icons, logos or trademarks | Custom icons don't copy SF shapes for branding | IMPL |
| SFS-04 | Rendering modes (monochrome, hierarchical, palette, multicolour) | Analog: icons are one colour, or one consistent two-tone hierarchy | NOT-POSSIBLE / IMPL (analog) |
| SFS-05 | Check icon legibility at each size and background | — | IMPL |
| SFS-06 | Gradients look best large | — | NOT-RELEVANT |
| SFS-07 | Variable colour shows a changing level (0–100%), not depth | Level icons (volume, signal, capacity) fill step by step with the value | IMPL (analog) |
| SFS-08 | Match symbol weight to the text weight | Duplicates ICN-04 | IMPL |
| SFS-09 | Size icons against the text's cap height (small, medium, large) | Icon height follows the font size and Text Size | IMPL (analog) |
| SFS-10 | Variant conventions: slash = unavailable or off; fill = selected; enclosed = clearer at small sizes; outline next to text | Used consistently | IMPL (analog) |
| SFS-11 | Script-specific variants | — | NOT-RELEVANT |
| SFS-12 | Animate symbols sparingly, with purpose, in keeping with the app's tone | — | IMPL (analog) |
| SFS-13 | Animation meanings: bounce = something happened; pulse or breathe = ongoing; rotate = working; variable colour = progress; wiggle = look here | The same motion always means the same thing | IMPL (analog) |
| SFS-14 | Custom symbols match the system set: simple, recognisable, inclusive, directly related | — | IMPL |
| SFS-15 | Negative side margins so badged icons align optically | — | IMPL (analog) |
| SFS-16 | Annotate layers; test custom symbol animations; draw whole shapes | — | NOT-RELEVANT |
| SFS-17 | Build badges and enclosures from the component library | — | NOT-RELEVANT |
| SFS-18 | Accessibility labels for custom symbols | — | JUCE-ONLY |
| SFS-19 | No Apple product replicas | Duplicates ICN-11 | IMPL |

## Spatial layout (SPA) — visionOS only

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| SPA-01 | Field of view, head anchoring, the floor plane, fixed vs dynamic scale, the Digital Crown | — | NOT-RELEVANT |
| SPA-02 | Depth cues must be accurate | — | NOT-RELEVANT |
| SPA-03 | Use depth for hierarchy, on big elements, only where it adds value | Shadows or elevation only on large panels, not on small icons | IMPL (analog) |
| SPA-04 | Don't give text depth | No drop shadows, embossing or 3D on words | IMPL (analog) |
| SPA-05 | Don't open too many windows | One window per app; no surprise extra windows | IMPL (analog) |
| SPA-06 | Prefer indirect gestures | — | NOT-RELEVANT |
| SPA-07 | Leave room round interactive elements (≥16 pt gaps there); never overlap them | No hit areas overlap | IMPL (analog) |
| SPA-08 | Usable with little physical movement | Short pointer paths for frequent actions | IMPL (analog) |

## Typography (TYP)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| TYP-01 | macOS: 13 pt default, 10 pt minimum | Same as ACC-08 | IMPL (13 covered; audit the 10 pt floor) |
| TYP-02 | Test legibility in context; fix with size, contrast or a more legible face | Check at 100% on a non-Retina screen | IMPL |
| TYP-03 | Avoid Ultralight, Thin and Light; use Regular through Bold | No light weights | IMPL |
| TYP-04 | Hierarchy through weight, size and colour, kept when text is scaled | At 200%, heading-to-body ratios are unchanged | IMPL |
| TYP-05 | Few typefaces | ≤2 (system sans + one music or display face) | IMPL |
| TYP-06 | When scaling, the important content grows; minor chrome may not | — | IMPL (optional) |
| TYP-07 | Use the system font (SF Pro on macOS) | Asked for by name (`.AppleSystemUIFont`); fallbacks Segoe UI and Arial | IMPL (covered) |
| TYP-08 | Don't embed or bundle the system fonts | No SF font files shipped | IMPL |
| TYP-09 | Use the macOS text styles: Large Title 26/32, Title 1 22/26, Title 2 17/22, Title 3 15/20, Headline 13 Bold/16, Body 13/16, Callout 12/15, Subheadline 11/14, Footnote 10/13, Caption 1 10/13, Caption 2 10 Medium/13 | Each text role maps to one of these (size/line height) | IMPL |
| TYP-10 | Emphasise with the bold trait (Body emphasised = Semibold; Headline = Heavy) | — | IMPL |
| TYP-11 | Looser leading for long or wide passages; tight leading only up to 2 lines | Multi-line hints ≥16/13 line height (≈1.23×) | IMPL |
| TYP-12 | Size-specific tracking (e.g. 10 pt +0.12 pt, 13 pt −0.08 pt, 17 pt −0.43 pt, 26 pt +0.22 pt) | ImGui and LICE don't apply SF's dynamic tracking | IMPL (optional) |
| TYP-13 | Custom fonts stay legible; follow the minimum sizes | Bravura, game fonts | IMPL |
| TYP-14 | Custom fonts honour accessibility (Bold Text, size changes) | The in-app Text Size covers size | IMPL (covered) |
| TYP-15 | Dynamic Type | macOS has none, and the window can't receive it | NOT-POSSIBLE (Text Size covers it) |
| TYP-16 | The layout adapts to every text size | — | IMPL (covered) |
| TYP-17 | Meaningful icons grow with the text | Same as ACC-07 | IMPL |
| TYP-18 | Keep truncation to a minimum at large sizes; never truncate scrolling text without a way to read it all | At 200%, no label is cut with "…". Anything truncated shows in full on hover or focus. | IMPL |
| TYP-19 | Stack, or use fewer columns, at large sizes | — | IMPL |
| TYP-20 | Primary elements stay at the top at any size | — | IMPL |
| TYP-21 | macOS control, menu and tooltip font variants match system controls | Analog: control labels at 13 pt; tooltips a step smaller but ≥10 pt | NOT-POSSIBLE (scripts) / IMPL (analog) |
| TYP-22 | visionOS 2D text, billboarding, bold text off-background | (no text shadows: see SPA-04) | NOT-RELEVANT |
| TYP-23 | iOS, watchOS and tvOS size tables | — | NOT-RELEVANT |

## Writing (WRI)

| ID | Guideline | Criterion | Tag |
|---|---|---|---|
| WRI-01 | Choose a voice; keep a list of terms; use them consistently | A shared glossary (Audition, Use Selected Items, click…) | IMPL (partly covered) |
| WRI-02 | Fit the tone to the moment (plain for problems, lighter for success) | — | IMPL |
| WRI-03 | Be clear; cut words; read it aloud | — | IMPL |
| WRI-04 | Write for everyone: plain, accessible, translatable, without jargon or gendered terms | — | IMPL |
| WRI-05 | Most important first; easy to read; split separate ideas | — | IMPL |
| WRI-06 | Active voice; buttons lead with a verb; clear rather than cute | — | IMPL (covered) |
| WRI-07 | Descriptive link text, never "Click here" | — | IMPL |
| WRI-08 | Reuse language patterns | — | IMPL |
| WRI-09 | One capitalisation style per kind of element, used throughout | — | IMPL (covered) |
| WRI-10 | Multi-step flows: consistent Get Started → Continue/Next → Done | — | IMPL |
| WRI-11 | Few possessives ("Favorites", not "Your Favorites"); one perspective | — | IMPL |
| WRI-12 | Avoid "we" (errors read "Unable to …") | Grep the UI strings for "we" | IMPL |
| WRI-13 | The right verbs for the device ("click" on a Mac) | — | IMPL (covered) |
| WRI-14 | Empty states say what to do next and offer the button | e.g. before a source is read: a one-line instruction plus *Use Selected Items* | IMPL |
| WRI-15 | Nothing crucial only in a temporary empty state | — | IMPL |
| WRI-16 | Prevent errors first | Impossible actions are hidden or disabled | IMPL (covered: no dead controls) |
| WRI-17 | Show an error as close to the problem as possible | Field-level problems also appear next to the control, not only in the top bar | IMPL |
| WRI-18 | No blame; say how to fix it, positively | — | IMPL (covered) |
| WRI-19 | No "Oops" or "Uh-oh" | — | IMPL |
| WRI-20 | If many people hit an error, redesign the interaction | — | IMPL |
| WRI-21 | Choose how to deliver a message by its urgency | Modal only when a decision is needed; otherwise a status line | IMPL |
| WRI-22 | Plain setting labels; the explanation says what "on" does | Each toggle's hint describes the on state | IMPL |
| WRI-23 | Send people to a setting with a button, not directions | e.g. a button that opens Text Size, not "go to View → …" | IMPL |
| WRI-24 | Text fields: a clear label plus a placeholder showing the format or an example | Search boxes, number fields, path entry | IMPL |
| WRI-25 | Field errors beside the field, instructive, not robotic ("Invalid …") | — | IMPL |

---

## Likely gaps

These are IMPLEMENTABLE items beyond the covered list: 7:1 text, Text Size 100–200%, 28 pt controls 12 apart, Tab focus ring, ink bar, message at top, Reduce Motion, Apple writing style.

**Sizes and targets**

- ACC-24: ~24 pt clearance around targets with no bezel. These include bare icons, text links, clickable notes or circles, and chips without a fill.
- ACC-22: icon-only buttons should be ≥28 pt wide too. Nothing should be under 20×20 pt.
- ACC-08 / TYP-01: audit the 10 pt floor at 100%. Look at axis, ruler and tick labels, note names and footnotes.
- ACC-07 / TYP-17 / SFS-09: drawn icons, arrows and ticks should scale with Text Size.

**Contrast and colour beyond words**

- ACC-11: meaningful graphics should be ≥3:1 [WCAG]. That covers notes, meters, input borders, graph lines and the focus ring.
- ACC-15/16, COL-09: audit for colour used alone beyond chosen buttons. Look at tune vs chord notes, rarities, status, warnings and graph series. Run a CVD simulation.
- ACC-17, COL-07: let people choose colours, using the native picker (`reaper.GR_SelectColor`).
- COL-01/12/14: one meaning per colour. Audit the yellow, which is used for chosen, playhead, notes and the primary button. Allow at most one accent-filled primary button per group.
- COL-21: zebra rows in long lists.
- COL-22: show selection less strongly when the window isn't focused.
- COL-26, MOT-15: no bright flashes on the near-black ground, and ≤3 flashes a second.
- DRK-10: dark glyphs on the dark ground need an edge.
- DRK-14: popups, menus and modals should be lighter than the base. The house popup colour is darker.
- DRK-08: Light Page should use off-white, not pure white.
- DRK-04: write down the reason for dark-only.

**Feedback, recovery and time**

- DP-11: hover, pressed and disabled states should be distinct, and changed content should be flagged.
- DP-06, ACC-43: undo or back for in-app edits and settings. Confirm anything that can't be undone, ideally with the native `ShowMessageBox`.
- ACC-33: remove time-boxes, such as the 3-second "Sure?" revert and hover-only reveals.
- ACC-35: autoplay settings for audio: Stop always visible, and an opt-out that is remembered.
- ACC-21, MOT-02: every sound needs a visible cue, and playing state needs a text cue.
- MOT-05/06: no motion on frequent clicks, and input never blocked by an animation.
- MOT-13: avoid slow sustained pulsing, around a 5-second cycle.

**Input**

- ACC-26: a button, menu or key alternative for every drag, right-click, double-click and modifier action.
- ACC-31: audit for system shortcuts the apps override.
- ACC-28: expose the main commands as REAPER actions.

**Reaching VoiceOver (partially)**

- ACC-18b: meaningful window titles.
- ACC-18c: native dialogs and menus (`ShowMessageBox`, `GetUserInputs`, `gfx.showmenu`) where a choice or text entry is needed.

**Layout**

- DP-13: keep controls from shifting position when state changes. This pulls against "No dead controls".
- LAY-02: indent sub-options.
- LAY-12: nothing unreachable at the minimum window size.
- LAY-14: one margin, and paragraph width ≤~70 characters.
- LAY-20/21: a minimum window size, and content capped and centred in very wide windows.
- MAT-02/05: a scrim behind text over busy graphics; no text on translucent fills.
- SPA-04: no text shadows.
- SPA-05: one window per app.
- SPA-07: no overlapping hit areas.

**Typography**

- TYP-03: no light weights.
- TYP-05: ≤2 typefaces.
- TYP-09/10: map each text role to a macOS text style (size/line height).
- TYP-11: leading of ≥1.23× for multi-line text.
- TYP-18: no "…" truncation at 200%, or the full text on hover or focus.
- TYP-08: never bundle SF.

**Icons**

- ICN-02..05: one stroke, grid and weight for all icons, centred optically.
- ICN-12: standard glyph meanings.
- ICN-10: a text name on hover or focus for every icon-only control.
- SFS-07/10/13: consistent variant conventions: slash = off, fill = selected, level fills.
- IMG-02/03: @2x bitmaps and pixel-snapped 1-pt lines.

**Words**

- INC-06: define theory jargon in hints.
- INC-10/19: grep the UI and docs for gendered and ableist idioms ("sanity check", "dummy", "blind to").
- WRI-07: descriptive link text.
- WRI-10: consistent flow labels.
- WRI-11/12: few possessives, and no "we".
- WRI-14: empty states with an action button.
- WRI-17/25: errors also shown next to the control at fault, not only in the top bar.
- WRI-22: toggle hints describe the on state.
- WRI-23: buttons that open the relevant setting.
- WRI-24: placeholder hints in text fields.

**Privacy and branding**

- PRV-01/02: say plainly what Battle Pass's activity watching reads (input yes/no, not which keys) and that it stays local.
- PRV-16: per-user storage.
- BRA-06/08/09: no logo banners or splash screens.
- BRA-10: no Apple trademarks in names.

**JUCE plugin only**

- ACC-04/18/27: accessible names and roles for every control (Voice Control and Switch Control follow from these), then an Accessibility Inspector audit.
- DRK-01/02: decide whether to follow the system appearance, or record why it stays dark-only.
- PRV-14: Developer ID signing and notarisation.
- APP-*: a Standalone icon at 1024 px, sRGB, simple and textless.
- PRV-07: a microphone purpose string if the Standalone takes audio input.
