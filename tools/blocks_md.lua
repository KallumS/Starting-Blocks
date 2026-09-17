--[[ Regenerates docs/BLOCKS.md from the engine.

     It loads sb_engine.lua and reads its tables, so the catalogue in the docs
     is the catalogue in the code - not a copy of it, and not a regex's guess
     at it.

       python3 tools/run_lua.py tools/blocks_md.lua > docs/BLOCKS.md
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local E = dofile(HERE .. "/../reascripts/sb_engine.lua")

local out = {}
local function w(line) out[#out + 1] = line or "" end

-- What each interval is called, for the chord table's last column.
local DEGREE = { [0]="1", [1]="b9", [2]="9", [3]="b3", [4]="3", [5]="11",
                 [6]="b5", [7]="5", [8]="#5", [9]="13", [10]="b7", [11]="7",
                 [13]="b9", [14]="9", [15]="#9", [16]="3", [17]="11",
                 [18]="#11", [19]="5", [20]="b13", [21]="13", [26]="9" }

local function join(t, sep)
  local s = {}
  for i, v in ipairs(t) do s[i] = tostring(v) end
  return table.concat(s, sep or " ")
end

w("# The catalogue")
w()
w("Every block Starting Blocks can make, and exactly what each one is.")
w()
w("**This file is generated.** Run")
w("`python3 tools/run_lua.py tools/blocks_md.lua > docs/BLOCKS.md` to rebuild")
w("it. It loads `reascripts/sb_engine.lua` and reads its tables, so it cannot")
w("drift from what the script actually does.")
w()

w("## Keys")
w()
local roots = {}
for i, r in ipairs(E.ROOTS) do roots[i] = "`" .. r.name .. "`" end
w(#E.ROOTS .. " roots: " .. table.concat(roots, ", ") .. ".")
w()
w("Both spellings of every pitch class are offered, plus `Cb`, because C# major")
w("and Db major are the same seven notes written differently and the difference")
w("is what the note names come out as. These are ScaleView for REAPER's roots,")
w("unchanged.")
w()

w("## Scales")
w()
w("Semitones from the root. Also ScaleView's, unchanged, so the two apps agree")
w("on what a scale is.")
w()
w("| scale | semitones | notes |")
w("| --- | --- | --- |")
for _, sc in ipairs(E.SCALES) do
  w(("| %s | %s | %d |"):format(sc.name, join(sc.iv), #sc.iv))
end
w()

w("## Scale degrees")
w()
w("The degree buttons are Roman numerals, cased and marked for the triad the")
w("scale itself builds on that degree: upper case for major, lower for minor,")
w("`\u{00B0}` for diminished, `+` for augmented. That is read off the scale rather")
w("than assumed, so the modes and the blues scales come out right - the vii of")
w("major is `vii\u{00B0}`, the III of natural minor is `III`.")
w()
w("| degree | name |")
w("| --- | --- |")
for i, name in ipairs(E.DEGREE_TITLES) do w(("| %d | %s |"):format(i, name)) end
w()
w("Only the seven-note scales have these names. In a pentatonic or a diminished")
w("scale the degrees are simply numbered. The seventh is called a **Leading")
w("Tone** only when it really is a semitone below the tonic; otherwise it is a")
w("**Subtonic**.")
w()

w("## Blocks")
w()
local cats = {}
for i, c in ipairs(E.CATEGORIES) do cats[i] = "**" .. c .. "**" end
w(table.concat(cats, ", ") .. ".")
w()
w("The first six are single pieces. The seventh, **Progression**, is the one")
w("that links them together.")
w()

w("### Chords")
w()
w("The first family is built from the scale you picked, so it is always in key:")
w()
w("| shape | scale degrees above the one you chose |")
w("| --- | --- |")
for _, d in ipairs(E.DIATONIC) do
  local offs = {}
  for i, o in ipairs(d.offsets) do offs[i] = "+" .. o end
  w(("| %s | %s |"):format(d.name, table.concat(offs, " ")))
end
w()
w("The rest are absolute shapes, stacked on the degree you chose whether or not")
w("they fit the key. Semitones are from the chord's root.")
w()
for fam = 2, #E.FAMILIES do
  local rows = {}
  for _, ch in ipairs(E.CHORDS) do
    if ch.fam == fam then rows[#rows + 1] = ch end
  end
  if #rows > 0 then
    w("#### " .. E.FAMILIES[fam])
    w()
    -- Naming the intervals only makes sense for the chords that stack in
    -- thirds; a quartal chord or the Tristan chord is its semitones and
    -- nothing more useful.
    local tertian = fam <= 6
    w("| symbol | chord | semitones |" .. (tertian and " intervals |" or ""))
    w("| --- | --- | --- |" .. (tertian and " --- |" or ""))
    for _, ch in ipairs(rows) do
      local row = ("| `%s` | %s | %s |"):format(ch.sym, ch.name, join(ch.iv))
      if tertian then
        local degs = {}
        for i, iv in ipairs(ch.iv) do degs[i] = DEGREE[iv] or tostring(iv) end
        row = row .. " " .. table.concat(degs, " ") .. " |"
      end
      w(row)
    end
    w()
  end
end
w("Chords can be inverted (root, 1st, 2nd, 3rd) and moved by up to three")
w("octaves either way.")
w()

w("### Arpeggios")
w()
w("The chord from the Chord tab, one note at a time. Two ways to order it, and")
w("you pick one or the other.")
w()
w("**Directions** lay every chord tone across the octave span out in pitch")
w("order and then walk them: " .. table.concat(E.DIRECTIONS, ", ") .. ".")
w()
w("`Random` is a shuffle rather than free picks, so every tone gets its turn")
w("before any of them repeats. `Converge` works inwards from the outside,")
w("`Diverge` outwards from the middle.")
w()
w("**Fixed orders** put the lowest three voices in a set order. Anything above")
w("them - a seventh, a ninth, an eleventh, a thirteenth - follows in order, and")
w("the whole cell climbs an octave at a time:")
w()
local orders = {}
for i, o in ipairs(E.ORDERS) do orders[i] = "`" .. o.name .. "`" end
w(table.concat(orders, ", ") .. ".")
w()

w("### Runs")
w()
w("The same seven directions, but over the scale rather than the chord,")
w("starting on the degree you chose and running up to four octaves. A")
w("one-octave run is inclusive of the octave above, so it lands back on the")
w("note it started from.")
w()

w("### Melody")
w()
w("The two smallest moves a melody can make. An interval, a direction and a")
w("shape:")
w()
w("| interval | |")
w("| --- | --- |")
for _, iv in ipairs(E.INTERVALS) do
  w(("| %s | %s |"):format(iv, iv == "2nd" and "the step" or "a leap"))
end
w()
w("| shape | |")
w("| --- | --- |")
w("| Single | the move: two notes |")
w("| Return | there and back: three notes |")
w("| Fill | every scale note in between |")
w()
w("All of it is diatonic: a 3rd is two scale steps, whatever that is in")
w("semitones in this key, and an octave is however many steps this scale takes")
w("to get there - five in a pentatonic, seven in a major scale.")
w()

w("### Bass")
w()
local tones = {}
for i, t in ipairs(E.BASS_TONES) do tones[i] = t end
w("One note of the chord, on its own, low. Inversion is ignored here, so the")
w("voices are always counted from the root: " .. table.concat(tones, ", ") .. ".")
w("Up to three octaves down, repeating at the chosen rate.")
w()

w("### Drums")
w()
w("One piece of the kit, one pattern, one bar. Stack a kit up by dropping in")
w("several. The note numbers are General MIDI, so the blocks land on the right")
w("pads in anything that follows the map.")
w()
w("| piece | note |")
w("| --- | --- |")
for _, p in ipairs(E.DRUM_PIECES) do w(("| %s | %d |"):format(p.name, p.note)) end
w()
w("| pattern | where the hits fall, in beats from the start of the bar |")
w("| --- | --- |")
for _, p in ipairs(E.DRUM_PATTERNS) do
  w(("| %s | %s |"):format(p.name, join(p.hits, ", ")))
end
w()
w("These are written on a 4/4 grid. In a shorter bar the hits past the end of")
w("it are dropped rather than squeezed in.")
w()

w("### Progressions")
w()
w("A progression is a sequence of scale degrees - up to " .. E.MAX_PROG .. " of")
w("them, each lasting one, two or four bars. It is the one block made of other")
w("blocks, and the only one that changes what the rest of them do.")
w()
w("On its own tab it plays the chord on each step. The switch that matters is")
w("**Follow progression**, on the Chord, Arpeggio, Run and Bass panels: with it")
w("on, that block is laid out across the whole progression instead of sitting")
w("on one degree, so an arpeggio follows the changes rather than repeating.")
w("Melody and drums do not offer it - a step or a leap is a smaller thing than")
w("a chord change, and a drum has no degree to follow.")
w()
w("| preset | degrees |")
w("| --- | --- |")
for _, p in ipairs(E.PROGRESSIONS) do
  local degs = {}
  for i, d in ipairs(p.degrees) do degs[i] = d + 1 end
  w(("| %s | %s |"):format(p.name, join(degs)))
end
w()
w("Degrees are numbered from 1 here for reading; the numerals on screen are")
w("cased for the scale you are in, so `I-V-vi-IV` in C major shows as")
w("`I - V - vi - IV` and the same preset in A minor shows as `i - v - VI - iv`.")
w("A progression written for seven degrees folds into a shorter scale rather")
w("than running off the end of it.")
w()

w("## Timing")
w()
local names, beats = {}, {}
for i, r in ipairs(E.RATES) do names[i] = r.name; beats[i] = r.beats end
w("| rate | " .. table.concat(names, " | ") .. " |")
local dashes = {}
for i = 1, #names do dashes[i] = "---" end
w("| --- | " .. table.concat(dashes, " | ") .. " |")
w("| quarter notes | " .. join(beats, " | ") .. " |")
w()
local mods = {}
for i, m in ipairs(E.RATE_MODS) do mods[i] = m.name:lower() end
w("Each one can be " .. table.concat(mods, ", ") ..
  " - a triplet is two thirds of the straight value, a dotted note one and a half.")
w()
w("**Gate** is how much of the step the note actually holds, from 5% to 100%.")
w("**Bars** is 1, 2, 4 or 8, and a bar is however long the project's time")
w("signature says it is.")

io.write(table.concat(out, "\n") .. "\n")
