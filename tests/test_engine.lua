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

local function eqList(got, want, what)
  checks = checks + 1
  local same = #got == #want
  if same then
    for i = 1, #want do
      if math.abs((got[i] or 0) - want[i]) > 1e-9 then same = false end
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
         "a triad cannot invert past its third voice")

  -- An absolute chord is stacked on the degree whatever the key says.
  st.family = indexOf(E.FAMILIES, "6ths & 7ths")
  st.chord  = indexOf(E.CHORDS, "maj7", "sym")
  eqList(E.chordTones(st, 0, 0), {60, 64, 67, 71}, "Cmaj7")
  eqList(E.chordTones(st, 1, 0), {62, 66, 69, 73},
         "the same shape on the second degree, out of key and on purpose")
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
  -- One bar of 1/4 notes over a C major triad: four steps, so the cell of
  -- three repeats into the fourth.
  local st = inKey("C", "Major", { cat = "Arpeggio", rate = indexOf(E.RATES, "1/4") })
  local r = E.generate(st)
  eqList(pitches(r), {60, 64, 67, 60}, "an ascending arpeggio, wrapping")
  eqList(starts(r), {0, 1, 2, 3}, "one note per beat")
  eq(r.beats, 4, "one bar")

  st.pattern = indexOf(E.DIRECTIONS, "Down")
  eqList(pitches(E.generate(st)), {67, 64, 60, 67}, "descending")

  st.pattern = indexOf(E.DIRECTIONS, "Converge")
  eqList(pitches(E.generate(st)), {60, 67, 64, 60}, "converging")

  -- Two octaves widens the pool before the direction is applied.
  st.pattern = indexOf(E.DIRECTIONS, "Up")
  st.octaves = 2
  st.rate    = indexOf(E.RATES, "1/8")
  eqList(pitches(E.generate(st)), {60, 64, 67, 72, 76, 79, 60, 64},
         "two octaves of chord tones, then round again")

  -- The six fixed orders.
  st.octaves = 1
  st.rate = indexOf(E.RATES, "1/4")
  st.patternIsOrder = true
  local expected = {
    ["1-3-5"] = {60, 64, 67}, ["3-1-5"] = {64, 60, 67},
    ["5-3-1"] = {67, 64, 60}, ["3-5-1"] = {64, 67, 60},
    ["1-5-3"] = {60, 67, 64}, ["5-1-3"] = {67, 60, 64},
  }
  for name, want in pairs(expected) do
    st.pattern = indexOf(E.ORDERS, name)
    local got = pitches(E.generate(st))
    eqList({got[1], got[2], got[3]}, want, "order " .. name)
  end

  -- Anything above the triad follows the order, in order.
  st.dia = indexOf(E.DIATONIC, "7th")
  st.pattern = indexOf(E.ORDERS, "3-1-5")
  st.rate = indexOf(E.RATES, "1/4")
  eqList(pitches(E.generate(st)), {64, 60, 67, 71},
         "the seventh comes after the reordered triad")
end

------------------------------------------------------------------------------
-- Runs
------------------------------------------------------------------------------

do
  local st = inKey("C", "Major", { cat = "Run", rate = indexOf(E.RATES, "1/4"), bars = 2 })
  local r = E.generate(st)
  eqList(pitches(r), {60, 62, 64, 65, 67, 69, 71, 72},
         "a one-octave run lands back on the note it started from")
  eq(r.beats, 8, "two bars")

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

------------------------------------------------------------------------------
-- Bass
------------------------------------------------------------------------------

do
  local st = inKey("C", "Major", { cat = "Bass", rate = indexOf(E.RATES, "1/4") })
  local r = E.generate(st)
  eqList(pitches(r), {48, 48, 48, 48}, "the root, an octave down, on every beat")
  eqList(starts(r), {0, 1, 2, 3}, "four to the bar")

  st.bassTone = indexOf(E.BASS_TONES, "5th")
  eq(pitches(E.generate(st))[1], 55, "the fifth of the chord, an octave down")

  -- Inversion moves the chord on screen but must not move the bass.
  st.bassTone = indexOf(E.BASS_TONES, "Root")
  st.inv = 2
  eq(pitches(E.generate(st))[1], 48, "the bass ignores inversion")

  st.inv = 0
  st.bassOct = -2
  eq(pitches(E.generate(st))[1], 36, "two octaves down")
end

------------------------------------------------------------------------------
-- Drums
------------------------------------------------------------------------------

do
  local st = state{ cat = "Drums",
                    drumPiece = indexOf(E.DRUM_PIECES, "Kick"),
                    drumPattern = indexOf(E.DRUM_PATTERNS, "Four on the Floor") }
  local r = E.generate(st)
  eqList(pitches(r), {36, 36, 36, 36}, "four kicks")
  eqList(starts(r), {0, 1, 2, 3}, "on the floor")

  st.drumPattern = indexOf(E.DRUM_PATTERNS, "And of Two")
  eqList(starts(E.generate(st)), {1.5}, "the & of 2 is one hit, halfway through beat 2")

  st.drumPattern = indexOf(E.DRUM_PATTERNS, "Two Step")
  eqList(starts(E.generate(st)), {0, 1.5, 3}, "two step")

  st.drumPattern = indexOf(E.DRUM_PATTERNS, "Every 16th")
  eq(#E.generate(st).notes, 16, "sixteen sixteenths")

  st.drumPattern = indexOf(E.DRUM_PATTERNS, "Four on the Floor")
  st.bars = 2
  eqList(starts(E.generate(st)), {0,1,2,3,4,5,6,7}, "two bars of it")

  -- The patterns are written on a 4/4 grid, so a 3/4 bar drops the fourth hit
  -- rather than squeezing it in.
  st.bars = 1
  st.barBeats = 3
  eqList(starts(E.generate(st)), {0, 1, 2}, "a 3/4 bar drops what runs past its end")

  st.barBeats = 4
  st.drumPiece = indexOf(E.DRUM_PIECES, "Closed HH")
  eq(pitches(E.generate(st))[1], 42, "the closed hi-hat is General MIDI 42")
end

------------------------------------------------------------------------------
-- Progressions: the blocks linking up
------------------------------------------------------------------------------

do
  local st = inKey("C", "Major", { cat = "Progression" })
  st.prog = { degrees = {0,4,5,3}, len = 4, bars = 1, follow = false }
  local r = E.generate(st)

  eq(r.beats, 16, "four steps of one bar")
  eqList(pitches(r), {60,64,67, 67,71,74, 69,72,76, 65,69,72},
         "I-V-vi-IV in C major is C E G / G B D / A C E / F A C")
  eqList(starts(r), {0,0,0, 4,4,4, 8,8,8, 12,12,12},
         "one chord per bar")
  eq(r.name, "C Major Prog I-V-vi-IV Triad", "named after what it is")

  st.prog.bars = 2
  eq(E.generate(st).beats, 32, "two bars a step")
  eqList(starts(E.generate(st)), {0,0,0, 8,8,8, 16,16,16, 24,24,24},
         "and the chords move with it")

  -- An arpeggio that follows is the same generator, once per step.
  st.prog.bars = 1
  st.cat = "Arpeggio"
  st.prog.follow = true
  st.rate = indexOf(E.RATES, "1/4")
  local arp = E.generate(st)
  eq(arp.beats, 16, "the arpeggio spans the whole progression")
  eqList(pitches(arp), {60,64,67,60, 67,71,74,67, 69,72,76,69, 65,69,72,65},
         "and arpeggiates each step's own chord")

  -- Turning follow off puts it back on the one degree.
  st.prog.follow = false
  local single = E.generate(st)
  eq(single.beats, 4, "with follow off it is one bar again")
  eqList(pitches(single), {60,64,67,60}, "on the chosen degree")

  -- Melody and drums do not follow, however the flag is set.
  ok(not E.canFollow("Melody"), "melody does not follow a progression")
  ok(not E.canFollow("Drums"), "nor do drums")
  st.cat = "Melody"
  st.prog.follow = true
  eq(E.follows(st), false, "so the flag does nothing for them")

  -- A single step is not a progression.
  st.cat = "Chord"
  st.prog.len = 1
  eq(E.follows(st), false, "one step is not a progression")
end

-- A progression in a minor key reads as that key.
do
  local st = inKey("A", "Minor", { cat = "Progression" })
  st.prog = { degrees = {0,4,5,3}, len = 4, bars = 1, follow = false }
  eq(E.progressionText(st, "-", true), "i-v-VI-iv",
     "the same steps in A minor are i-v-VI-iv")
  eqList(pitches(E.generate(st)), {69,72,76, 76,79,83, 77,81,84, 74,77,81},
         "Am / Em / F / Dm")
end

-- Folding a seven-degree progression into a five-note scale.
do
  local st = inKey("C", "Maj Pent")
  st.prog = { degrees = {0,4,5,3,0,0,0,0,0,0,0,0}, len = 4, bars = 1, follow = false }
  E.clampProgression(st)
  eqList({st.prog.degrees[1], st.prog.degrees[2], st.prog.degrees[3], st.prog.degrees[4]},
         {0, 4, 4, 3}, "the sixth degree folds back to the highest there is")
end

------------------------------------------------------------------------------
-- Rate, gate and the note buffer
------------------------------------------------------------------------------

do
  local st = inKey("C", "Major", { cat = "Bass" })
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
  -- Twelve bars of sixteenth-note arpeggio is more notes than the buffer holds,
  -- and the block has to say so rather than quietly dropping its end.
  local st = inKey("C", "Major", { cat = "Arpeggio", rate = indexOf(E.RATES, "1/64") })
  st.prog = { degrees = {0,0,0,0,3,3,0,0,4,3,0,4}, len = 12, bars = 4, follow = true }
  local r = E.generate(st)
  eq(#r.notes, E.MAX_NOTES, "the buffer fills")
  ok(r.truncated, "and says it was truncated")

  local small = inKey("C", "Major")
  ok(not E.generate(small).truncated, "an ordinary block is not")
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
  local low = inKey("C", "Major", { cat = "Bass", bassOct = -3, baseOct = 0 })
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
      if n.vel < 1 or n.vel > 127 then fail(cat .. ": velocity " .. n.vel) end
      if n.len <= 0 then fail(cat .. ": zero-length note") end
      if n.start < 0 then fail(cat .. ": note before the start of the block") end
      if n.start >= r.beats + 1e-9 then
        fail(cat .. ": note at " .. n.start .. " is past the end of a " .. r.beats .. " beat block")
      end
    end
  end
end

------------------------------------------------------------------------------
-- The catalogue itself
------------------------------------------------------------------------------

eq(#E.CHORDS, 78, "seventy-eight chords")
eq(#E.SCALES, 16, "sixteen scales")
eq(#E.ROOTS, 18, "eighteen roots")
eq(#E.PROGRESSIONS, 9, "nine preset progressions")
eq(#E.DRUM_PIECES, 9, "nine drum pieces")
eq(#E.DRUM_PATTERNS, 9, "nine drum patterns")
eq(#E.CATEGORIES, 7, "seven kinds of block")

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

-- A preset whose name spells its numerals has to play them.
do
  local NUM = { i = 0, ii = 1, iii = 2, iv = 3, v = 4, vi = 5, vii = 6 }
  for _, p in ipairs(E.PROGRESSIONS) do
    local parts, allNumerals = {}, true
    for part in p.name:gmatch("[^-]+") do
      parts[#parts + 1] = part
      if not NUM[part:lower()] then allNumerals = false end
    end
    if allNumerals then
      local want = {}
      for i, part in ipairs(parts) do want[i] = NUM[part:lower()] end
      eqList(p.degrees, want, "preset " .. p.name .. " plays the degrees it names")
    end
    checks = checks + 1
    if #p.degrees > E.MAX_PROG then fail(p.name .. " is longer than twelve steps") end
    for _, d in ipairs(p.degrees) do
      if d < 0 or d > 6 then fail(p.name .. ": degree " .. d .. " is not a degree") end
    end
  end
end

-- Every ordering is a permutation of the triad, and each appears once.
do
  local seen = {}
  for _, o in ipairs(E.ORDERS) do
    local sorted = { o.perm[1], o.perm[2], o.perm[3] }
    table.sort(sorted)
    eqList(sorted, {1,2,3}, "order " .. o.name .. " is a permutation of the triad")
    checks = checks + 1
    local key = table.concat(o.perm, ",")
    if seen[key] then fail("order " .. o.name .. " repeats " .. seen[key]) end
    seen[key] = o.name
  end
  eq(#E.ORDERS, 6, "all six orderings")
  eq(#E.DIRECTIONS, 7, "seven directions")
end

io.write(("%d checks, %d failure%s\n"):format(checks, failures, failures == 1 and "" or "s"))
os.exit(failures == 0 and 0 or 1)
