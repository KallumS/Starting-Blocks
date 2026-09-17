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
-- outright: the drum rates are names, the note starts are numbers.
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
         "a triad cannot invert past its third voice")

  -- An absolute chord is stacked on the degree whatever the key says.
  st.family = indexOf(E.FAMILIES, "6ths & 7ths")
  st.chord  = indexOf(E.CHORDS, "maj7", "sym")
  eqList(E.chordTones(st, 0, 0), {60, 64, 67, 71}, "Cmaj7")
  eqList(E.chordTones(st, 1, 0), {62, 66, 69, 73},
         "the same shape on the second degree, out of key and on purpose")
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
--
-- There are no named patterns any more. The point of the rework is that the
-- patterns fall out of the rates: a kick every 1/4 is four on the floor, a
-- kick every 1/2 is one and three, a snare from beat two every 1/2 is the
-- backbeat. These check that they really do.
------------------------------------------------------------------------------

local function drumsFor(name, rate, overrides)
  local st = state(overrides)
  st.cat = "Drums"
  st.drumPiece = indexOf(E.DRUM_PIECES, name)
  st.drumRate = rate
  return E.generate(st)
end

do
  eqList(starts(drumsFor("Kick", "1/4")), {0, 1, 2, 3},
         "a kick every 1/4 is four on the floor")
  eqList(starts(drumsFor("Kick", "1/2")), {0, 2},
         "a kick every 1/2 is one and three")
  eqList(starts(drumsFor("Kick", "1/1")), {0},
         "a kick every 1/1 is one hit at the top of the bar")
  eqList(starts(drumsFor("Kick", "1/8")), {0,0.5,1,1.5,2,2.5,3,3.5},
         "a kick every 1/8")
  eq(#drumsFor("Kick", "1/16").notes, 16, "a kick every 1/16 is sixteen hits")

  -- The snare starts on the two, which is what makes the backbeat fall out.
  eqList(starts(drumsFor("Snare", "1/2")), {1, 3},
         "a snare from beat two every 1/2 is the backbeat")
  eqList(starts(drumsFor("Snare", "1/1")), {1}, "and every 1/1 is just the two")
  eqList(starts(drumsFor("Snare", "1/4")), {1, 2, 3}, "every 1/4 from the two")
  eqList(starts(drumsFor("Snare", "1/8")), {1,1.5,2,2.5,3,3.5}, "every 1/8 from the two")

  eqList(pitches(drumsFor("Kick", "1/1")), {36}, "the kick is General MIDI 36")
  eqList(pitches(drumsFor("Snare", "1/1")), {38}, "the snare is 38")
  eq(#drumsFor("Closed HH", "1/32").notes, 32, "the hi-hat goes down to 1/32")
  eq(#drumsFor("Ride", "1/32").notes, 32, "so does the ride")

  -- Two bars is the same bar twice.
  eqList(starts(drumsFor("Kick", "1/2", { bars = 2 })), {0, 2, 4, 6},
         "two bars of one and three")

  -- A shorter bar drops what runs past its end rather than squeezing it in.
  eqList(starts(drumsFor("Kick", "1/4", { barBeats = 3 })), {0, 1, 2},
         "a 3/4 bar holds three quarter-note kicks")
  eqList(starts(drumsFor("Snare", "1/1", { barBeats = 1 })), {},
         "a bar too short to reach beat two gets no snare at all")
end

-- Each piece offers only the rates it should, and 1/1 is always last so that
-- an unknown rate falls back to a single hit.
do
  local want = {
    Kick        = { "1/16", "1/8", "1/4", "1/2", "1/1" },
    Snare       = { "1/8", "1/4", "1/2", "1/1" },
    ["Closed HH"] = { "1/32", "1/16", "1/8", "1/4", "1/2", "1/1" },
    ["Open HH"] = { "1/32", "1/16", "1/8", "1/4", "1/2", "1/1" },
    Crash       = { "1/16", "1/8", "1/4", "1/2", "1/1" },
    Ride        = { "1/32", "1/16", "1/8", "1/4", "1/2", "1/1" },
    ["Low Tom"] = {}, ["Mid Tom"] = {}, ["High Tom"] = {},
  }
  for _, piece in ipairs(E.DRUM_PIECES) do
    eqList(piece.rates, want[piece.name] or { "?" },
           piece.name .. " offers the rates it should")
    if #piece.rates > 0 then
      eq(piece.rates[#piece.rates], "1/1", piece.name .. ": 1/1 is last")
    end
    checks = checks + 1
    local known = false
    for _, r in ipairs(E.RATES) do
      for _, pr in ipairs(piece.rates) do if r.name == pr then known = true end end
    end
    if #piece.rates > 0 and not known then
      fail(piece.name .. " offers a rate that is not a rate")
    end
  end

  -- The toms are a single hit until they are thought through.
  for _, name in ipairs({ "Low Tom", "Mid Tom", "High Tom" }) do
    eqList(starts(drumsFor(name, "1/8")), {0}, name .. " is one hit")
    eq(#drumsFor(name, "1/8", { bars = 2 }).notes, 2, name .. ": one a bar")
  end

  -- A rate the piece does not offer falls back to a single hit rather than
  -- guessing at something near it.
  eqList(starts(drumsFor("Snare", "1/16")), {1},
         "a snare asked for 1/16, which it does not offer, gets one hit")
end

-- Shuffle pushes every second hit later, and only the second ones.
do
  eqList(starts(drumsFor("Closed HH", "1/8", { shuffle = 0 })),
         {0,0.5,1,1.5,2,2.5,3,3.5}, "no shuffle is straight")

  local swung = starts(drumsFor("Closed HH", "1/8", { shuffle = 100 }))
  eqList(swung, {0, 2/3, 1, 1+2/3, 2, 2+2/3, 3, 3+2/3},
         "full shuffle lands the off-beats two thirds through the pair")

  local half = starts(drumsFor("Closed HH", "1/8", { shuffle = 50 }))
  eq(half[1], 0, "the on-beats never move")
  ok(math.abs(half[2] - (0.5 + 0.5 * 0.5 / 3)) < 1e-9,
     "half shuffle is half way there")
  ok(half[2] > 0.5 and half[2] < 2/3, "which is between straight and full")

  -- Every hit still has to land inside the block it belongs to, however far
  -- the shuffle pushes it.
  for _, piece in ipairs({ "Kick", "Snare", "Closed HH", "Ride" }) do
    for _, rate in ipairs(E.DRUM_PIECES[indexOf(E.DRUM_PIECES, piece)].rates) do
      local r = drumsFor(piece, rate, { shuffle = 100, bars = 2 })
      for _, n in ipairs(r.notes) do
        checks = checks + 1
        if n.start < 0 or n.start >= r.beats then
          fail(("%s %s at full shuffle put a hit at %s, outside a %s beat block")
               :format(piece, rate, n.start, r.beats))
        end
      end
    end
  end

  -- A single hit has no second hit to push.
  eqList(starts(drumsFor("Low Tom", "1/1", { shuffle = 100 })), {0},
         "shuffle does nothing to a single hit")
  eq(drumsFor("Low Tom", "1/1", { shuffle = 100 }).name, "Drum Low Tom",
     "and the name does not claim one")
  eq(drumsFor("Kick", "1/8", { shuffle = 60 }).name, "Drum Kick 1/8 shuffle 60",
     "a shuffle that did something is named")
end

------------------------------------------------------------------------------
-- Straight, triplet and dotted
--
-- One setting, and every block that reads a rate has to read it: the chord's
-- chop and the drum's spacing as well as the step the others walk in.
------------------------------------------------------------------------------

do
  eq(E.RATE_MODS[E.newState().rateMod].name, "Straight", "straight is the default")
  eq(#E.RATE_MODS, 3, "straight, triplet and dotted")

  local TRIPLET = indexOf(E.RATE_MODS, "Triplet")
  local DOTTED  = indexOf(E.RATE_MODS, "Dotted")

  -- The drums.
  eqList(starts(drumsFor("Kick", "1/4")), {0, 1, 2, 3}, "straight quarters")
  eqList(starts(drumsFor("Kick", "1/4", { rateMod = TRIPLET })),
         {0, 2/3, 4/3, 2, 8/3, 10/3},
         "quarter-note triplets are six in the bar, three in the space of two")
  eqList(starts(drumsFor("Kick", "1/4", { rateMod = DOTTED })), {0, 1.5, 3},
         "dotted quarters are half as long again")
  eqList(starts(drumsFor("Snare", "1/4", { rateMod = DOTTED })), {1, 2.5},
         "and still start where the piece starts")

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

  -- Shuffle is measured against whatever the step turned out to be, so the two
  -- compose rather than fighting.
  local swung = starts(drumsFor("Closed HH", "1/8",
                                { rateMod = TRIPLET, shuffle = 100 }))
  local step = 0.5 * 2 / 3
  ok(math.abs(swung[2] - (step + step / 3)) < 1e-9,
     "a full shuffle on triplets is measured against the triplet")

  -- Names have to tell the three apart, or two blocks land on one filename.
  eq(drumsFor("Kick", "1/4", { rateMod = TRIPLET }).name, "Drum Kick 1/4T",
     "a triplet drum is named T")
  eq(drumsFor("Kick", "1/4", { rateMod = DOTTED }).name, "Drum Kick 1/4.",
     "a dotted one is named with a dot")
  eq(drumsFor("Kick", "1/4").name, "Drum Kick 1/4", "a straight one is not marked")

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
-- The catalogue itself
------------------------------------------------------------------------------

eq(#E.CHORDS, 78, "seventy-eight chords")
eq(#E.SCALES, 16, "sixteen scales")
eq(#E.ROOTS, 18, "eighteen roots")
eq(#E.DRUM_PIECES, 9, "nine drum pieces")
eq(E.VELOCITY, 100, "one velocity for everything")
eq(#E.CATEGORIES, 6, "six kinds of block")

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
