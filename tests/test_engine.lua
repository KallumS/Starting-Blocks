--[[ The generators, checked by running them.

     This is the test the JSFX could never have: EEL2 only runs inside REAPER,
     so what a converging arpeggio actually came out as was checked by reading.
     Here the engine is plain Lua with no REAPER in it, so the notes can be
     asked for and compared.

       lua5.4 tests/test_engine.lua
       python3 tools/run_lua.py tests/test_engine.lua
]]

local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local E = dofile(HERE .. "/../reascripts/sb_engine.lua")

local failures, checks = 0, 0

local function fail(what, extra)
  failures = failures + 1
  io.write("FAIL  ", what, "\n")
  if extra then io.write(extra, "\n") end
end

local function ok(cond, what)
  checks = checks + 1
  if not cond then fail(what) end
end

local function eq(got, want, what)
  checks = checks + 1
  if got ~= want then
    fail(what, "        got  " .. tostring(got) .. "\n        want " .. tostring(want))
  end
end

local function list(t) return "{" .. table.concat(t, ", ") .. "}" end

-- Compares lists of numbers within a rounding error, or lists of strings
-- outright: the kinds of block are names, the note starts are numbers.
local function eqList(got, want, what)
  checks = checks + 1
  local same = #got == #want
  if same then
    for i = 1, #want do
      if type(want[i]) == "number" then
        if type(got[i]) ~= "number" or math.abs(got[i] - want[i]) > 1e-9 then
          same = false
        end
      elseif got[i] ~= want[i] then
        same = false
      end
    end
  end
  if not same then
    fail(what, "        got  " .. list(got) .. "\n        want " .. list(want))
  end
end

local function pitches(res)
  local p = {}
  for i, n in ipairs(res.notes) do p[i] = n.pitch end
  return p
end

local function starts(res)
  local s = {}
  for i, n in ipairs(res.notes) do s[i] = n.start end
  return s
end

-- Index of a named entry, so the tests read as music rather than as numbers.
local function indexOf(tbl, name, key)
  for i, v in ipairs(tbl) do
    if (key and v[key] or v.name or v) == name then return i end
  end
  error("no such entry: " .. name)
end

local function state(overrides)
  local st = E.newState()
  for k, v in pairs(overrides or {}) do st[k] = v end
  return st
end

local C_MAJOR = 1
local function inKey(root, scale, overrides)
  local st = state(overrides)
  st.root  = indexOf(E.ROOTS, root)
  st.scale = indexOf(E.SCALES, scale)
  return st
end

------------------------------------------------------------------------------
-- The scale under the whole thing
------------------------------------------------------------------------------

do
  local st = inKey("C", "Major")
  eqList({ E.scalePitch(st, 0), E.scalePitch(st, 1), E.scalePitch(st, 2),
           E.scalePitch(st, 3), E.scalePitch(st, 4), E.scalePitch(st, 5),
           E.scalePitch(st, 6), E.scalePitch(st, 7) },
         { 60, 62, 64, 65, 67, 69, 71, 72 },
         "C major runs C4 to C5")

  eq(E.scalePitch(st, -1), 59, "degree -1 is the B below")
  eq(E.scalePitch(st, 14), 84, "two octaves up")
end

-- Spelling is the key's, not the keyboard's.
do
  local fs = inKey("F#", "Major")
  eq(E.noteName(fs, 6), "E#", "the seventh of F# major is E#, not F")
  eq(E.noteName(fs, 0), "F#", "and its tonic is F#")
  eq(E.noteName(fs, 3), "B",  "its fourth is a plain B")

  local cb = inKey("Cb", "Major")
  eq(E.noteName(cb, 3), "Fb", "the fourth of Cb major is Fb")
  eq(E.scalePitch(cb, 0), 71, "Cb sounds as B")

  local db = inKey("Db", "Major")
  eq(E.noteName(db, 1), "Eb", "Db major spells flats")
  local cs = inKey("C#", "Major")
  eq(E.noteName(cs, 1), "D#", "C# major spells the same notes sharp")
  eq(E.scalePitch(cs, 1), E.scalePitch(db, 1), "and they sound the same")

  local ees = inKey("Eb", "Major")
  eq(E.noteName(ees, 6), "D", "Eb major's seventh")
end

-- Every seven-note scale walks the letters in order, so those alone cannot
-- tell the letter table apart from a plain index. The scales that skip or
-- repeat a letter are the ones that can.
do
  local pent = inKey("C", "Maj Pent")
  local got = {}
  for d = 0, 4 do got[#got + 1] = E.noteName(pent, d) end
  eq(table.concat(got, " "), "C D E G A",
     "the major pentatonic skips a letter rather than renaming the next one")

  local blues = inKey("C", "Min Blues")
  got = {}
  for d = 0, 5 do got[#got + 1] = E.noteName(blues, d) end
  eq(table.concat(got, " "), "C Eb F Gb G Bb",
     "the minor blues repeats G for its flat fifth and fifth")

  local majBlues = inKey("C", "Maj Blues")
  got = {}
  for d = 0, 5 do got[#got + 1] = E.noteName(majBlues, d) end
  eq(table.concat(got, " "), "C D Eb E G A",
     "the major blues repeats E for its flat third and third")

  local dim = inKey("C", "Dim W-H")
  got = {}
  for d = 0, 7 do got[#got + 1] = E.noteName(dim, d) end
  eq(table.concat(got, " "), "C D Eb F Gb Ab A B",
     "the diminished scale repeats a letter across its eight notes")
end

-- Numerals are read off the scale, not assumed.
do
  local maj = inKey("C", "Major")
  local got = {}
  for d = 0, 6 do got[#got + 1] = E.degreeNumeral(maj, d, true) end
  eq(table.concat(got, " "), "I ii iii IV V vi viidim",
     "major gives I ii iii IV V vi vii-diminished")

  local min = inKey("A", "Minor")
  got = {}
  for d = 0, 6 do got[#got + 1] = E.degreeNumeral(min, d, true) end
  eq(table.concat(got, " "), "i iidim III iv v VI VII",
     "natural minor gives i ii-diminished III iv v VI VII")

  local harm = inKey("A", "Harm Minor")
  eq(E.degreeNumeral(harm, 4, true), "V", "harmonic minor has a major V")
  eq(E.degreeNumeral(harm, 6, true), "viidim", "and a diminished vii")

  local lyd = inKey("C", "Lydian")
  eq(E.degreeNumeral(lyd, 1, true), "II", "Lydian's second is major")
end

-- The seventh is only a leading tone when it leans on the tonic.
do
  eq(E.degreeTitle(inKey("C", "Major"), 6), "Leading Tone",
     "major has a leading tone")
  eq(E.degreeTitle(inKey("C", "Mixolydian"), 6), "Subtonic",
     "Mixolydian's flat seventh is a subtonic, not a leading tone")
  eq(E.degreeTitle(inKey("C", "Minor"), 6), "Subtonic",
     "so is natural minor's")
  eq(E.degreeTitle(inKey("C", "Harm Minor"), 6), "Leading Tone",
     "harmonic minor raises it back into one")
  eq(E.degreeTitle(inKey("C", "Maj Pent"), 3), "Degree 4",
     "a five-note scale just numbers its degrees")
end

------------------------------------------------------------------------------
-- Chords
------------------------------------------------------------------------------

do
  local st = inKey("C", "Major")
  eqList(E.chordTones(st, 0, 0), {60, 64, 67}, "the I of C major is C E G")
  eqList(E.chordTones(st, 4, 0), {67, 71, 74}, "the V is G B D")
  eqList(E.chordTones(st, 6, 0), {71, 74, 77}, "the vii is B D F")

  st.dia = indexOf(E.DIATONIC, "7th")
  eqList(E.chordTones(st, 4, 0), {67, 71, 74, 77}, "the V7 is G B D F")
  st.dia = indexOf(E.DIATONIC, "13th")
  eq(#E.chordTones(st, 0, 0), 7, "a thirteenth stacks seven notes")

  -- Inversions lift the lowest voice an octave at a time.
  st.dia = indexOf(E.DIATONIC, "Triad")
  eqList(E.chordTones(st, 0, 1), {64, 67, 72}, "first inversion")
  eqList(E.chordTones(st, 0, 2), {67, 72, 76}, "second inversion")
  eqList(E.chordTones(st, 0, 3), {67, 72, 76},
         "a triad has no third inversion: asked for one, it gives its second")

  -- An absolute chord is stacked on the degree whatever the key says.
  st.family = indexOf(E.FAMILIES, "6ths & 7ths")
  st.chord  = indexOf(E.CHORDS, "maj7", "sym")
  eqList(E.chordTones(st, 0, 0), {60, 64, 67, 71}, "Cmaj7")
  eqList(E.chordTones(st, 1, 0), {62, 66, 69, 73},
         "the same shape on the second degree, out of key and on purpose")
end

-- A chord has one inversion for each of its notes after the root, and
-- inversion n puts its (n+1)th note, counted up the stack, in the bass: the
-- 3rd, the 5th, the 7th, the 9th...
do
  local st = inKey("C", "Major")
  eq(E.inversionCount(st), 2, "a triad has two inversions")
  st.dia = indexOf(E.DIATONIC, "7th")
  eq(E.inversionCount(st), 3, "a seventh three")
  eqList(E.chordTones(st, 4, 3), {77, 79, 83, 86}, "the V7's third inversion has its 7th, F, in the bass")
  st.dia = indexOf(E.DIATONIC, "9th")
  eq(E.inversionCount(st), 4, "a ninth four")
  eqList(E.chordTones(st, 0, 4), {74, 76, 79, 83, 84},
         "Cmaj9's fourth inversion: the 9th in the bass, the root lifted above it")
  st.dia = indexOf(E.DIATONIC, "13th")
  eq(E.inversionCount(st), 6, "a thirteenth six")
  eq(E.chordTones(st, 0, 6)[1], 81, "its sixth inversion has the 13th, A, in the bass")
  st.dia = indexOf(E.DIATONIC, "5th")
  eq(E.inversionCount(st), 1, "a power chord one")
  eqList(E.inversionNames(st), {"Root", "1st"}, "and offers only those")

  st.dia = indexOf(E.DIATONIC, "Triad")
  st.inv = 6
  E.clampState(st)
  eq(st.inv, 2, "a 6th inversion asked of a triad is its 2nd")
  st.dia, st.inv = indexOf(E.DIATONIC, "13th"), 6
  E.clampState(st)
  eq(st.inv, 6, "and of a thirteenth, kept")

  -- An Up arpeggio of an inverted thirteenth climbs: the lifted notes go
  -- back in order, not on the end.
  st.cat, st.pattern, st.octaves, st.lengthMode, st.repeats = "Arpeggio", 1, 1, "Repeats", 1
  st.inv = 1
  local arp = pitches(E.generate(st))
  local climbs = true
  for i = 2, #arp do if arp[i] <= arp[i - 1] then climbs = false end end
  ok(climbs, "an Up arpeggio of an inverted thirteenth only climbs: " .. list(arp))
end

-- Every chord, in every family, on every degree of several scales: each
-- inversion keeps the chord's notes, puts the right one in the bass, and stacks
-- the rest above it without a doubled pitch.
do
  local seen, bad = 0, nil
  for _, key in ipairs({ {"C", "Major"}, {"F#", "Harm Minor"}, {"Eb", "Maj Pent"}, {"A", "Dim W-H"} }) do
    local st = inKey(key[1], key[2])
    local function check(label)
      for degree = 0, E.scaleLen(st) - 1 do
        local root = E.chordTones(st, degree, 0)
        local order, pcs = {}, {}
        for _, p in ipairs(root) do
          if not pcs[p % 12] then pcs[p % 12] = true; order[#order + 1] = p % 12 end
        end
        local n = E.inversionCount(st, degree)
        if n ~= #order - 1 then bad = bad or (label .. ": " .. n .. " inversions for " .. #order .. " notes") end
        for inv = 0, n do
          local t = E.chordTones(st, degree, inv)
          seen = seen + 1
          local got, dup = {}, false
          for i, p in ipairs(t) do
            if i > 1 and p <= t[i - 1] then dup = true end
            got[p % 12] = true
          end
          for pc in pairs(pcs) do if not got[pc] then dup = true end end
          for pc in pairs(got) do if not pcs[pc] then dup = true end end
          if dup or t[1] % 12 ~= order[inv + 1] then
            bad = bad or (("%s %s %s on degree %d, inversion %d: %s"):format(
              key[1], key[2], label, degree, inv, list(t)))
          end
        end
      end
    end
    st.family = 1
    for d, dia in ipairs(E.DIATONIC) do st.dia = d; check(dia.name) end
    for c, ch in ipairs(E.CHORDS) do st.family, st.chord = ch.fam, c; check(ch.sym) end
  end
  ok(bad == nil, "every inversion of every chord is right" .. (bad and (": " .. bad) or ""))
  ok(seen > 5000, "and there were plenty of them: " .. seen)
end

-- Chopping the chord strikes it again in each segment.
do
  local st = inKey("C", "Major")
  st.chop = indexOf(E.RATES, "1/1", "name")
  local whole = E.generate(st)
  eq(#whole.notes, 3, "at 1/1 over one bar the chord is struck once")
  eqList(starts(whole), {0, 0, 0}, "all together at the start")
  eq(whole.notes[1].len, 4 * 0.9, "and held for the block, less the gate")

  st.chop = indexOf(E.RATES, "1/4", "name")
  local quarters = E.generate(st)
  eq(#quarters.notes, 12, "chopped into quarters it is struck four times")
  eqList(starts(quarters), {0,0,0, 1,1,1, 2,2,2, 3,3,3}, "one strike a beat")
  eq(quarters.notes[1].len, 0.9, "each held for its own segment, less the gate")
  eq(quarters.beats, 4, "the block is still one bar")

  st.chop = indexOf(E.RATES, "1/8", "name")
  eq(#E.generate(st).notes, 24, "chopped into eighths, eight strikes")

  -- Two bars of 1/1 is two strikes, not one long one.
  st.chop = indexOf(E.RATES, "1/1", "name")
  st.bars = 2
  eq(#E.generate(st).notes, 6, "two bars at 1/1 is one strike a bar")
  eq(E.generate(st).beats, 8, "over two bars")

  -- A segment longer than what is left of the block is cut to fit.
  st.bars = 1
  st.barBeats = 3
  local threeFour = E.generate(st)
  eq(#threeFour.notes, 3, "a 3/4 bar at 1/1 is still one strike")
  eq(threeFour.notes[1].len, 3 * 0.9, "cut to the length of the bar")
end

------------------------------------------------------------------------------
-- The seven directions, which were the whole reason for wanting this test
------------------------------------------------------------------------------

do
  local pool = {1, 2, 3, 4, 5}
  local function dir(name) return E._applyDirection(pool, indexOf(E.DIRECTIONS, name)) end

  eqList(dir("Up"),       {1,2,3,4,5},             "Up")
  eqList(dir("Down"),     {5,4,3,2,1},             "Down")
  eqList(dir("Up/Down"),  {1,2,3,4,5,4,3,2},       "Up/Down turns without repeating either end")
  eqList(dir("Down/Up"),  {5,4,3,2,1,2,3,4},       "Down/Up likewise")
  eqList(dir("Converge"), {1,5,2,4,3},             "Converge works inwards from the outside")
  eqList(dir("Diverge"),  {3,4,2,5,1},             "Diverge works outwards from the middle")

  -- Even lengths have no single middle note.
  local four = {1,2,3,4}
  eqList(E._applyDirection(four, indexOf(E.DIRECTIONS, "Converge")), {1,4,2,3},
         "Converge over an even pool")
  eqList(E._applyDirection(four, indexOf(E.DIRECTIONS, "Diverge")), {2,3,1,4},
         "Diverge over an even pool")

  -- Random is a shuffle, so it must hold every pitch exactly once.
  math.randomseed(7)
  for _ = 1, 20 do
    local r = E._applyDirection(pool, indexOf(E.DIRECTIONS, "Random"))
    checks = checks + 1
    local seen = {}
    local good = #r == #pool
    for _, v in ipairs(r) do
      if seen[v] then good = false end
      seen[v] = true
    end
    if not good then fail("Random is a shuffle, never a repeat: " .. list(r)) end
  end

  eqList(E._applyDirection({}, 1), {}, "an empty pool gives an empty sequence")
  eqList(E._applyDirection({9}, indexOf(E.DIRECTIONS, "Up/Down")), {9},
         "one pitch has nowhere to turn")
end

------------------------------------------------------------------------------
-- Arpeggios
------------------------------------------------------------------------------

do
  -- One repeat of an ascending arpeggio over a C major triad is three notes,
  -- and the block is exactly that long: no padding out to a bar.
  local st = inKey("C", "Major", { cat = "Arpeggio", rate = indexOf(E.RATES, "1/4") })
  local r = E.generate(st)
  eqList(pitches(r), {60, 64, 67}, "one pass up the chord")
  eqList(starts(r), {0, 1, 2}, "one note per beat")
  eq(r.beats, 3, "and the block stops when the arpeggio does")

  st.repeats = 3
  r = E.generate(st)
  eq(#r.notes, 9, "three repeats is three passes")
  eq(r.beats, 9, "and three times as long")
  eqList(pitches(r), {60,64,67, 60,64,67, 60,64,67}, "the same pass, over again")

  st.repeats = 1
  st.pattern = indexOf(E.DIRECTIONS, "Down")
  eqList(pitches(E.generate(st)), {67, 64, 60}, "descending")

  st.pattern = indexOf(E.DIRECTIONS, "Converge")
  eqList(pitches(E.generate(st)), {60, 67, 64}, "converging")

  -- Up/Down is a longer pass than Up, so one repeat of it is longer.
  st.pattern = indexOf(E.DIRECTIONS, "Up/Down")
  local ud = E.generate(st)
  eqList(pitches(ud), {60, 64, 67, 64}, "up and back down without repeating either end")
  eq(ud.beats, 4, "and the block is as long as that pass")
  eq(E.passLength(st), 4, "which is what a pass is reported to be")

  -- Two octaves widens the pool before the direction is applied.
  st.pattern = indexOf(E.DIRECTIONS, "Up")
  st.octaves = 2
  local two = E.generate(st)
  eqList(pitches(two), {60, 64, 67, 72, 76, 79}, "two octaves of chord tones")
  eq(two.beats, 6, "one pass, six notes long")
  eq(E.passLength(st), 6, "a pass is six")

  -- A seventh chord makes a longer pass again, which is the whole point of
  -- counting repeats rather than bars.
  st.octaves = 1
  st.dia = indexOf(E.DIATONIC, "7th")
  eqList(pitches(E.generate(st)), {60, 64, 67, 71}, "a seventh arpeggiates four notes")
  eq(E.passLength(st), 4, "and one pass is four")
  st.dia = indexOf(E.DIATONIC, "13th")
  eq(E.passLength(st), 7, "a thirteenth is seven")
  eq(#E.generate(st).notes, 7, "and one repeat plays all of them")
end

------------------------------------------------------------------------------
-- Runs
------------------------------------------------------------------------------

do
  local st = inKey("C", "Major", { cat = "Run", rate = indexOf(E.RATES, "1/4") })
  local r = E.generate(st)
  eqList(pitches(r), {60, 62, 64, 65, 67, 69, 71, 72},
         "a one-octave run lands back on the note it started from")
  eq(r.beats, 8, "one pass of eight notes, one beat each")
  eq(E.passLength(st), 8, "which is what a pass is reported to be")

  st.repeats = 2
  local twice = E.generate(st)
  eq(#twice.notes, 16, "two repeats is two passes")
  eq(twice.beats, 16, "and twice as long")
  eqList({ twice.notes[9].pitch, twice.notes[16].pitch }, {60, 72},
         "the second pass starts again from the bottom")
  st.repeats = 1

  st.degree = 4
  eqList(pitches(E.generate(st)), {67, 69, 71, 72, 74, 76, 77, 79},
         "a run from the fifth starts on the fifth")

  st.degree = 0
  st.runDir = indexOf(E.DIRECTIONS, "Down")
  eqList(pitches(E.generate(st)), {72, 71, 69, 67, 65, 64, 62, 60}, "downwards")
end

------------------------------------------------------------------------------
-- Melody: the smallest moves
------------------------------------------------------------------------------

do
  local st = inKey("C", "Major", { cat = "Melody", rate = indexOf(E.RATES, "1/8") })

  local r = E.generate(st)
  eqList(pitches(r), {60, 62}, "a step up is two notes")
  eqList(starts(r), {0, 0.5}, "one rate apart")
  eq(r.beats, 1, "and the block is exactly as long as it needs to be")

  st.melDir = 2
  eqList(pitches(E.generate(st)), {60, 59}, "a step down leaves the scale below")

  st.melDir = 1
  st.interval = indexOf(E.INTERVALS, "3rd")
  eqList(pitches(E.generate(st)), {60, 64}, "a third is a leap of two scale steps")

  st.shape = indexOf(E.SHAPES, "Return")
  eqList(pitches(E.generate(st)), {60, 64, 60}, "Return goes there and back")

  st.shape = indexOf(E.SHAPES, "Fill")
  eqList(pitches(E.generate(st)), {60, 62, 64}, "Fill walks every note between")

  st.interval = indexOf(E.INTERVALS, "Octave")
  st.shape = indexOf(E.SHAPES, "Single")
  eqList(pitches(E.generate(st)), {60, 72}, "the octave is the widest leap")

  -- In a five-note scale the octave is five steps, not seven.
  local pent = inKey("C", "Maj Pent", {
    cat = "Melody", interval = indexOf(E.INTERVALS, "Octave"),
    shape = indexOf(E.SHAPES, "Fill"), rate = indexOf(E.RATES, "1/8") })
  eqList(pitches(E.generate(pent)), {60, 62, 64, 67, 69, 72},
         "filling an octave of the major pentatonic is six notes")
end

-- Sustain is one note held for the rate. Direction and shape have nothing to
-- act on, so the generator must ignore them rather than quietly fold them in.
do
  local st = inKey("C", "Major", { cat = "Melody",
    interval = indexOf(E.INTERVALS, "Sustain"), rate = indexOf(E.RATES, "1/8") })

  local r = E.generate(st)
  eqList(pitches(r), {60}, "a sustain is one note")
  eqList(starts(r), {0}, "at the top of the block")
  eq(r.beats, 0.5, "as long as the rate, and no longer")
  eq(r.notes[1].len, 0.5 * st.gate / 100, "gated like any other note")

  st.rate = indexOf(E.RATES, "1/1")
  eq(E.generate(st).beats, 4, "a slower rate is a longer note")

  st.melDir = 2
  st.shape  = indexOf(E.SHAPES, "Fill")
  eqList(pitches(E.generate(st)), {60},
         "direction and shape have nothing to do here")

  -- The degree shown in the Melody panel is the one chosen in step 2, so
  -- moving it has to move the note.
  st.degree = 4
  eqList(pitches(E.generate(st)), {67}, "sustaining the fifth sounds the fifth")

  eq(E.blockName(st), "C Major V Melody Sustain 1/1",
     "and it is named for what it is, with no direction or shape in it")

  st.interval = indexOf(E.INTERVALS, "2nd")
  st.shape    = indexOf(E.SHAPES, "Single")
  eq(E.blockName(st), "C Major V Melody Down 2nd Single",
     "a moving melody is still named the old way")
end

------------------------------------------------------------------------------
-- How long a block is
--
-- A chord is measured in bars, and a bar can now be a quarter
-- or a half of one. An arpeggio or a run is measured either in passes or by
-- filling that same length, and which is the user's choice.
------------------------------------------------------------------------------

do
  eqList({ E.BAR_LENGTHS[1].bars, E.BAR_LENGTHS[2].bars, E.BAR_LENGTHS[3].bars },
         {0.25, 0.5, 1}, "a block can be a quarter or a half of a bar")
  eq(#E.BAR_LENGTHS, 6, "six lengths")
  eq(E.BAR_LENGTHS[#E.BAR_LENGTHS].bars, 8, "up to eight bars")

  -- The chord, which fills whatever length it is given.
  local chord = inKey("C", "Major", { bars = 0.25 })
  eq(E.generate(chord).beats, 1, "a quarter-bar chord is one beat of 4/4")
  eq(#E.generate(chord).notes, 3, "struck once")
  eq(E.generate(chord).notes[1].len, 0.9, "and held for that beat, less the gate")

  chord.bars = 0.5
  eq(E.generate(chord).beats, 2, "a half-bar chord is two beats")

  -- A fractional block still ends where it says it does, whatever is in it.
  for _, cat in ipairs(E.CATEGORIES) do
    for _, b in ipairs({ 0.25, 0.5 }) do
      local st = inKey("C", "Major", { cat = cat, bars = b })
      local r = E.generate(st)
      for _, n in ipairs(r.notes) do
        checks = checks + 1
        if n.start >= r.beats + 1e-9 then
          fail(("%s over %s bars put a note at %s, past a %s beat block")
               :format(cat, b, n.start, r.beats))
        end
      end
    end
  end
end

-- An arpeggio or a run, measured both ways.
do
  local st = inKey("C", "Major", { cat = "Arpeggio", rate = indexOf(E.RATES, "1/8") })

  eq(st.lengthMode, "Repeats", "passes are the default")
  st.repeats = 2
  local byPass = E.generate(st)
  eq(#byPass.notes, 6, "two passes of a triad is six notes")
  eq(byPass.beats, 3, "and the block stops with the second pass")
  ok(byPass.name:find("x2", 1, true), "named for its passes")

  -- Filling a length instead: the pass cycles and is cut wherever the block
  -- ends, which is how it worked before repeats existed.
  st.lengthMode = "Bars"
  st.bars = 1
  local byBar = E.generate(st)
  eq(byBar.beats, 4, "a one-bar block is a bar long")
  eq(#byBar.notes, 8, "eight eighth-notes fill it")
  eqList(pitches(byBar), {60,64,67,60,64,67,60,64},
         "the pass cycles and is cut mid-pass at the bar line")
  ok(byBar.name:find("1 bar", 1, true), "named for its length instead")

  st.bars = 0.5
  eq(#E.generate(st).notes, 4, "half a bar is four")
  st.bars = 2
  eq(#E.generate(st).notes, 16, "two bars is sixteen")

  -- The same choice on a run.
  local run = inKey("C", "Major", { cat = "Run", rate = indexOf(E.RATES, "1/4") })
  eq(E.generate(run).beats, 8, "a run of one pass is its own length")
  run.lengthMode = "Bars"
  run.bars = 1
  eq(E.generate(run).beats, 4, "filling a bar cuts it to the bar")
  eq(#E.generate(run).notes, 4, "four quarter notes")
  eqList(pitches(E.generate(run)), {60, 62, 64, 65}, "the first four of the run")

  -- Melody and chord are measured one way only, so the mode must not leak
  -- into them.
  local mel = inKey("C", "Major", { cat = "Melody", lengthMode = "Bars", bars = 8 })
  eq(E.generate(mel).beats, E.melodyBeats(mel),
     "a melody is its own length whatever the mode says")
end

------------------------------------------------------------------------------
-- Straight, triplet and dotted
--
-- One setting, and every block that reads a rate has to read it: the chord's
-- chop as well as the step the others walk in.
------------------------------------------------------------------------------

do
  eq(E.RATE_MODS[E.newState().rateMod].name, "Straight", "straight is the default")
  eq(#E.RATE_MODS, 3, "straight, triplet and dotted")

  local TRIPLET = indexOf(E.RATE_MODS, "Triplet")
  local DOTTED  = indexOf(E.RATE_MODS, "Dotted")

  -- The chord's chop.
  local st = inKey("C", "Major")
  st.chop = indexOf(E.RATES, "1/4", "name")
  eq(#E.generate(st).notes, 12, "four straight strikes of a triad")
  st.rateMod = TRIPLET
  eq(#E.generate(st).notes, 18, "six triplet strikes")
  eq(E.chopBeats(st), 2/3, "a quarter-note triplet is two thirds of a beat")
  st.rateMod = DOTTED
  eq(#E.generate(st).notes, 9, "three dotted strikes")
  eq(E.chopBeats(st), 1.5, "a dotted quarter is a beat and a half")

  -- The blocks that walk a step.
  local arp = inKey("C", "Major", { cat = "Arpeggio", rate = indexOf(E.RATES, "1/8") })
  eq(E.rateBeats(arp), 0.5, "a straight eighth")
  arp.rateMod = TRIPLET
  eq(E.rateBeats(arp), 0.5 * 2 / 3, "an eighth-note triplet")
  eq(E.generate(arp).beats, 3 * 0.5 * 2 / 3, "and the pass is that much shorter")
  arp.rateMod = DOTTED
  eq(E.rateBeats(arp), 0.75, "a dotted eighth")

  -- Names have to tell the three apart, or two blocks land on one filename.
  local named = inKey("C", "Major", { cat = "Arpeggio", rate = indexOf(E.RATES, "1/8") })
  eq(E.blockName(named), "C Major I Arp Triad Up 1/8", "a straight arpeggio")
  named.rateMod = TRIPLET
  eq(E.blockName(named), "C Major I Arp Triad Up 1/8T", "a triplet one")

  -- A 1/1 chop is silent in the name only while it is straight; a 1/1 triplet
  -- is a different block and has to say so.
  local chord = inKey("C", "Major")
  eq(E.blockName(chord), "C Major I Chord Triad", "a plain held chord")
  chord.rateMod = TRIPLET
  eq(E.blockName(chord), "C Major I Chord Triad 1/1T", "a triplet one is marked")
end

------------------------------------------------------------------------------
-- Rate, gate and the note buffer
------------------------------------------------------------------------------

do
  -- A held melody note is one note as long as the step, so it shows the gate
  -- with nothing else in the way.
  local st = inKey("C", "Major", { cat = "Melody",
                                   interval = indexOf(E.INTERVALS, "Sustain") })
  st.rate = indexOf(E.RATES, "1/16")
  eq(E.rateBeats(st), 0.25, "a sixteenth is a quarter of a beat")
  st.rateMod = indexOf(E.RATE_MODS, "Triplet")
  eq(E.rateBeats(st), 0.25 * 2 / 3, "a triplet is two thirds of it")
  st.rateMod = indexOf(E.RATE_MODS, "Dotted")
  eq(E.rateBeats(st), 0.375, "a dotted note is one and a half")

  st.rateMod = 1
  st.rate = indexOf(E.RATES, "1/4")
  st.gate = 50
  eq(E.generate(st).notes[1].len, 0.5, "gate is how much of the step is held")
  st.gate = 100
  eq(E.generate(st).notes[1].len, 1, "a full gate holds the whole step")

  local chord = inKey("C", "Major", { gate = 50 })
  eq(E.generate(chord).notes[1].len, 2, "a chord's gate is of the whole block")
end

do
  -- With progressions gone nothing a user can set reaches the note buffer any
  -- more: the longest block available is a diminished scale run, four octaves,
  -- up and down, sixteen times, which is 1024 on the nose. The guard still has
  -- to work, so shrink the buffer and check it rather than pretending some
  -- setting can overflow it.
  local st = inKey("C", "Major", { cat = "Arpeggio", repeats = 8 })
  local real = E.MAX_NOTES
  E.MAX_NOTES = 5
  local r = E.generate(st)
  E.MAX_NOTES = real
  eq(#r.notes, 5, "the buffer fills and stops")
  ok(r.truncated, "and says it was truncated")

  ok(not E.generate(inKey("C", "Major")).truncated, "an ordinary block is not")

  -- The longest thing the controls can actually ask for still fits.
  local biggest = inKey("C", "Dim W-H", {
    cat = "Run", octaves = 4, repeats = E.MAX_REPEATS,
    runDir = indexOf(E.DIRECTIONS, "Up/Down"), rate = indexOf(E.RATES, "1/64") })
  local big = E.generate(biggest)
  ok(#big.notes <= E.MAX_NOTES,
     "the longest block the controls allow fits the buffer (" .. #big.notes .. ")")
  ok(not big.truncated, "so it is not truncated")
end

-- Nothing may ever leave the engine outside the MIDI range.
do
  local st = inKey("C", "Major", { cat = "Arpeggio", octaves = 4, oct = 3,
                                   baseOct = 8, rate = indexOf(E.RATES, "1/4"),
                                   bars = 8 })
  st.dia = indexOf(E.DIATONIC, "13th")
  for _, n in ipairs(E.generate(st).notes) do
    checks = checks + 1
    if n.pitch < 0 or n.pitch > 127 then fail("pitch " .. n.pitch .. " is outside MIDI") end
  end
  local low = inKey("C", "Major", { cat = "Run", oct = -3, baseOct = 0, octaves = 4 })
  for _, n in ipairs(E.generate(low).notes) do
    checks = checks + 1
    if n.pitch < 0 then fail("pitch " .. n.pitch .. " is below MIDI") end
  end
end

-- Every note carries a usable velocity and a real length.
do
  for _, cat in ipairs(E.CATEGORIES) do
    local st = inKey("C", "Major", { cat = cat })
    local r = E.generate(st)
    checks = checks + 1
    if #r.notes == 0 then fail(cat .. " generates nothing at all") end
    for _, n in ipairs(r.notes) do
      if n.vel ~= E.VELOCITY then fail(cat .. ": velocity " .. n.vel) end
      if n.len <= 0 then fail(cat .. ": zero-length note") end
      if n.start < 0 then fail(cat .. ": note before the start of the block") end
      if n.start >= r.beats + 1e-9 then
        fail(cat .. ": note at " .. n.start .. " is past the end of a " .. r.beats .. " beat block")
      end
    end
  end
end

------------------------------------------------------------------------------
-- clampState
--
-- Every field here is used to look something up or to fill a slider, so what
-- it does with a value it should never have seen is worth checking directly
-- rather than only through the window.
------------------------------------------------------------------------------

do
  -- Bars are picked from a list with fractions in it, so they snap to the
  -- nearest entry rather than rounding to a whole number.
  local function barsAfter(v)
    local st = E.newState()
    st.bars = v
    E.clampState(st)
    return st.bars
  end
  eq(barsAfter(0.25), 0.25, "a quarter bar survives")
  eq(barsAfter(0.5),  0.5,  "so does a half")
  eq(barsAfter(0.3),  0.25, "something between snaps to the nearer of the two")
  eq(barsAfter(0.45), 0.5,  "the other way too")
  eq(barsAfter(3),    2,    "exactly between two entries keeps the shorter")
  eq(barsAfter(3.5),  4,    "nearer the longer takes the longer")
  eq(barsAfter(1.4),  1,    "and nearer the shorter takes the shorter")
  eq(barsAfter(99),   8,    "past the end comes back to the longest")
  eq(barsAfter(-5),   0.25, "below the start comes back to the shortest")
  eq(barsAfter("x"),  1,    "and nonsense falls back to one bar")

  -- The length mode is a name, and an unknown one falls back to the first.
  local function modeAfter(v)
    local st = E.newState()
    st.lengthMode = v
    E.clampState(st)
    return st.lengthMode
  end
  eq(modeAfter("Bars"), "Bars", "a real mode survives")
  eq(modeAfter("Repeats"), "Repeats", "so does the other one")
  eq(modeAfter("Furlongs"), E.LENGTH_MODES[1], "an invented one does not")
  eq(modeAfter(nil), E.LENGTH_MODES[1], "nor does nothing at all")

  -- Everything else comes back inside its own table.
  local wild = E.newState()
  for _, k in ipairs({ "root", "scale", "family", "chord", "dia", "rate",
                       "rateMod", "runDir", "pattern", "interval", "melDir",
                       "shape", "chop", "inv", "oct", "octaves", "repeats",
                       "gate", "baseOct", "degree" }) do
    wild[k] = 9999
  end
  wild.cat = "Sousaphone"
  E.clampState(wild)
  eq(wild.cat, E.CATEGORIES[1], "an unknown block falls back to the first")
  ok(wild.root <= #E.ROOTS and wild.root >= 1, "root is inside its table")
  ok(wild.chord <= #E.CHORDS, "chord is inside its table")
  ok(wild.chop <= #E.RATES, "chop is inside its table")
  ok(wild.degree <= E.scaleLen(wild) - 1, "degree is inside the scale")
  ok(wild.repeats <= E.MAX_REPEATS, "repeats is inside its range")
  ok(wild.gate <= 100, "gate is inside its range")
  ok(wild.oct <= 3, "the octave is inside its range")

  -- And a clamped state still generates, for every block.
  for _, cat in ipairs(E.CATEGORIES) do
    wild.cat = cat
    E.clampState(wild)
    checks = checks + 1
    local good, err = pcall(E.generate, wild)
    if not good then fail(cat .. " will not generate from a clamped state: " .. tostring(err)) end
  end
end

------------------------------------------------------------------------------
-- The catalogue itself
------------------------------------------------------------------------------

eq(#E.CHORDS, 78, "seventy-eight chords")
eq(#E.SCALES, 16, "sixteen scales")
eq(#E.ROOTS, 18, "eighteen roots")
eq(E.VELOCITY, 100, "one velocity for everything")
-- Named rather than counted, so a kind that goes missing or comes back shows
-- up as a name. Bass and Drums were taken out once they were no longer
-- needed; a chord's own lowest note is still the chord's, set by inversion.
eqList(E.CATEGORIES, { "Chord", "Arpeggio", "Run", "Melody" }, "the kinds of block")

-- A setting saved while Bass and Drums still existed opens on the chord rather
-- than on a block that is not there, and the fields only they used are left
-- alone - nothing reads them now.
for _, gone in ipairs({ "Bass", "Drums" }) do
  local st = E.newState()
  st.cat, st.bassTone, st.drumPiece, st.shuffle = gone, 99, 99, 400
  E.clampState(st)
  eq(st.cat, "Chord", "a saved " .. gone .. " block opens as a chord")
  checks = checks + 1
  local good, err = pcall(E.generate, st)
  if not good then fail("and it generates: " .. tostring(err)) end
end

do
  local seenSym, seenName = {}, {}
  for _, ch in ipairs(E.CHORDS) do
    checks = checks + 1
    if seenSym[ch.sym] then fail("two chords share the symbol " .. ch.sym) end
    if seenName[ch.name] then fail("two chords share the name " .. ch.name) end
    seenSym[ch.sym], seenName[ch.name] = true, true
    if ch.iv[1] ~= 0 then fail(ch.name .. " is not written from its root") end
    if #ch.iv < 2 then fail(ch.name .. " has fewer than two notes") end
    for i = 2, #ch.iv do
      if ch.iv[i] <= ch.iv[i-1] then fail(ch.name .. ": semitones do not ascend") end
    end
    if not E.FAMILIES[ch.fam] then fail(ch.name .. " is in no family") end
    if ch.fam == 1 then fail(ch.name .. " claims to be diatonic") end
  end

  -- Two chords in one family with the same notes would be two buttons doing
  -- the same thing. Across families it is fine: a German sixth really is
  -- spelled like a dominant seventh.
  local byFamily = {}
  for _, ch in ipairs(E.CHORDS) do
    local key = ch.fam .. ":" .. table.concat(ch.iv, ",")
    checks = checks + 1
    if byFamily[key] then
      fail(ch.name .. " duplicates " .. byFamily[key] .. " inside its family")
    end
    byFamily[key] = ch.name
  end

  -- The chord grid is eight wide and three rows deep.
  local count = {}
  for _, ch in ipairs(E.CHORDS) do count[ch.fam] = (count[ch.fam] or 0) + 1 end
  for fam, n in pairs(count) do
    checks = checks + 1
    if n > 24 then fail(E.FAMILIES[fam] .. " has " .. n .. " chords; the grid holds 24") end
  end
end

-- Scales are ScaleView for REAPER's, and have to stay that way.
do
  local SCALEVIEW = {
    Major = {0,2,4,5,7,9,11}, Minor = {0,2,3,5,7,8,10},
    ["Harm Minor"] = {0,2,3,5,7,8,11}, Ionian = {0,2,4,5,7,9,11},
    Dorian = {0,2,3,5,7,9,10}, Phrygian = {0,1,3,5,7,8,10},
    Lydian = {0,2,4,6,7,9,11}, Mixolydian = {0,2,4,5,7,9,10},
    Aeolian = {0,2,3,5,7,8,10}, ["Maj Pent"] = {0,2,4,7,9},
    ["Min Pent"] = {0,3,5,7,10}, ["Maj Blues"] = {0,2,3,4,7,9},
    ["Min Blues"] = {0,3,5,6,7,10}, ["Whole Tone"] = {0,2,4,6,8,10},
    ["Dim W-H"] = {0,2,3,5,6,8,9,11}, ["Dim H-W"] = {0,1,3,4,6,7,9,10},
  }
  for _, sc in ipairs(E.SCALES) do
    eqList(sc.iv, SCALEVIEW[sc.name] or {}, "scale " .. sc.name .. " matches ScaleView")
    eq(#sc.letters, #sc.iv, "scale " .. sc.name .. " spells every degree")
  end
end

-- A root's name has to be what its letter and accidental say it is.
do
  local L, A = {"C","D","E","F","G","A","B"}, {[-1]="b", [0]="", [1]="#"}
  for _, r in ipairs(E.ROOTS) do
    eq(r.name, L[r.letter + 1] .. A[r.acc], "root " .. r.name .. " spells itself")
  end
  local pcs = {}
  for _, r in ipairs(E.ROOTS) do
    local pc = ({0,2,4,5,7,9,11})[r.letter + 1]
    pcs[(pc + r.acc + 12) % 12] = true
  end
  local n = 0
  for _ in pairs(pcs) do n = n + 1 end
  eq(n, 12, "the roots between them cover all twelve pitch classes")
end

eq(#E.DIRECTIONS, 7, "seven directions")

io.write(("%d checks, %d failure%s\n"):format(checks, failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
