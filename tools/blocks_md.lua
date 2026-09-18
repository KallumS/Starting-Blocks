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
w("**Chop** cuts the block into segments and strikes the chord again in each")
w("one: 1/64, 1/32, 1/16, 1/8, 1/4, 1/2 or 1/1. At 1/1 over one bar that is a")
w("single held chord, which is what a chord was before the chop existed. Over")
w("more than one bar it is one strike a bar.")
w()

w("### Arpeggios")
w()
w("The chord from the Chord tab, one note at a time.")
w()
w("**Direction** lays every chord tone across the octave span out in pitch")
w("order and then walks them: " .. table.concat(E.DIRECTIONS, ", ") .. ".")
w()
w("`Random` is a shuffle rather than free picks, so every tone gets its turn")
w("before any of them repeats. `Converge` works inwards from the outside,")
w("`Diverge` outwards from the middle.")
w()
w("**Length** is measured one of two ways, and you pick which.")
w()
w("**Repeats** is how many times the pass plays, from 1 to " .. E.MAX_REPEATS ..
  ". One pass is")
w("one time through whatever the direction produced, so the block is as long as")
w("the arpeggio and no longer - a triad up is three notes, a thirteenth up is")
w("seven, and the same Repeats setting gives you one of each rather than a bar")
w("of each.")
w()
w("**Bars** fills a length instead: the pass cycles until the block runs out,")
w("wherever in the pass that falls. A one-bar block of eighth notes is eight")
w("notes whether the chord under it has three tones or seven. This is how an")
w("arpeggio worked before repeats existed, and it is the one to reach for when")
w("the block has to line up with a bar rather than with itself.")
w()

w("### Runs")
w()
w("The same seven directions, but over the scale rather than the chord,")
w("starting on the degree you chose and running up to four octaves. A")
w("one-octave run is inclusive of the octave above, so it lands back on the")
w("note it started from, and it is measured in repeats or in bars the same way")
w("an arpeggio is.")
w()

w("### Melody")
w()
w("The two smallest moves a melody can make, and the one note that does not")
w("move at all. An interval, a direction and a shape:")
w()
w("| interval | |")
w("| --- | --- |")
for _, iv in ipairs(E.INTERVALS) do
  local what = "a leap"
  if iv.hold then what = "one note, held for the rate"
  elseif iv.name == "2nd" then what = "the step" end
  w(("| %s | %s |"):format(iv.name, what))
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
w("Sustain has nothing to point in a direction and no shape to take, so the")
w("panel puts the scale degree where the shape was - the same degree chosen in")
w("step 2, shown again where it is the only thing left to choose.")
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
w("One piece of the kit, hit at one rate. Stack a kit up by dropping in")
w("several. The note numbers are General MIDI, so the blocks land on the right")
w("pads in anything that follows the map.")
w()
w("There are no named patterns. The patterns fall out of the rates instead: a")
w("kick every 1/4 is four on the floor, a kick every 1/2 is one and three, and")
w("a snare - which starts on the two - every 1/2 is the backbeat. Naming those")
w("would be naming what the rates already say.")
w()
w("| piece | note | first hit | every |")
w("| --- | --- | --- | --- |")
for _, p in ipairs(E.DRUM_PIECES) do
  local every = #p.rates > 0 and table.concat(p.rates, ", ") or "one hit only"
  local first = p.start > 0 and ("beat " .. (p.start + 1)) or "top of the bar"
  w(("| %s | %d | %s | %s |"):format(p.name, p.note, first, every))
end
w()
w("1/1 is always the last rate a piece offers, and it means a single hit. The")
w("toms are a single hit and nothing to choose until they are thought through.")
w("A bar too short to reach a piece's first hit gets no hit at all.")
w()
w("**Shuffle** pushes every second hit later, from 0 to 100. At 100 it lands")
w("two thirds of the way through the pair, which is the triplet feel a shuffle")
w("is named after; anything less is on the way there. A piece that is only hit")
w("once has no second hit to push. Shuffle is measured against whatever the")
w("step turned out to be, so it composes with a triplet rather than fighting it.")
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
w("Every block can be " .. table.concat(mods, ", ") ..
  " - a triplet is two thirds of the straight value, a dotted note one and a")
w("half - and straight is where it starts. It is one setting shown on every")
w("panel, because a block is in one feel or the other and it is the same")
w("question wherever it is asked. It applies to whatever that panel reads as a")
w("rate: the chord's chop, the spacing of a drum, and the step an arpeggio, run,")
w("melody or bass line walks in. A block that is not straight says so in its")
w("name, `T` for a triplet and `.` for a dotted one, so two feels of the same")
w("rate are not two files fighting over one filename.")
w()
w("**Gate** is how much of the step the note actually holds, from 5% to 100%.")
w()
local lengths = {}
for i, b in ipairs(E.BAR_LENGTHS) do lengths[i] = b.name end
w("Chords, bass and drums are measured in **bars**: " ..
  table.concat(lengths, ", ") .. ". A bar is however long the")
w("project's time signature says it is, and a quarter or a half of one is still")
w("a block - a single chord stab is a quarter-bar chord. A drum pattern belongs")
w("to a bar, so a block shorter than a bar keeps the front of the pattern and")
w("drops the rest.")
w()
w("Arpeggios and runs take either of those lengths **or** a number of repeats.")
w("A melody is however long its own notes make it.")
w()
w("Everything leaves at velocity " .. E.VELOCITY .. ". Shaping a block's")
w("dynamics is a job for the MIDI editor once it is in the project, not for a")
w("slider on every panel here.")

io.write(table.concat(out, "\n") .. "\n")
