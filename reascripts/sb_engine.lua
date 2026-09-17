--[[ Starting Blocks - the music.

     Pure Lua. Nothing in this file touches REAPER or ImGui, which is the
     point: the generators are the part that has to be right, and here they can
     be run and checked by tests/test_engine.lua rather than only by reading.

     Scale degrees are 0-based throughout - degree 0 is the tonic - because the
     arithmetic wants them that way (degree + 2 is the third above, and the
     octave falls out of the division). Table indices are 1-based, like Lua.
]]

local M = {}

M.MAX_NOTES = 1024
M.MAX_PROG  = 12
M.PPQ       = 960

------------------------------------------------------------------------------
-- Keys
--
-- These are ScaleView for REAPER's roots and scales, unchanged, so the two
-- apps agree on what a scale is and on what to call its notes. Both spellings
-- of every pitch class are here plus Cb, because C# major and Db major are the
-- same seven notes written differently and the difference is what the note
-- names come out as.
------------------------------------------------------------------------------

local LETTER_PC = { 0, 2, 4, 5, 7, 9, 11 }        -- C D E F G A B
local LETTERS   = { "C", "D", "E", "F", "G", "A", "B" }
local ACCIDENTAL = { [-2] = "bb", [-1] = "b", [0] = "", [1] = "#", [2] = "x" }

M.ROOTS = {
  { name = "C",  letter = 0, acc =  0 }, { name = "C#", letter = 0, acc =  1 },
  { name = "Db", letter = 1, acc = -1 }, { name = "D",  letter = 1, acc =  0 },
  { name = "D#", letter = 1, acc =  1 }, { name = "Eb", letter = 2, acc = -1 },
  { name = "E",  letter = 2, acc =  0 }, { name = "F",  letter = 3, acc =  0 },
  { name = "F#", letter = 3, acc =  1 }, { name = "Gb", letter = 4, acc = -1 },
  { name = "G",  letter = 4, acc =  0 }, { name = "G#", letter = 4, acc =  1 },
  { name = "Ab", letter = 5, acc = -1 }, { name = "A",  letter = 5, acc =  0 },
  { name = "A#", letter = 5, acc =  1 }, { name = "Bb", letter = 6, acc = -1 },
  { name = "B",  letter = 6, acc =  0 }, { name = "Cb", letter = 0, acc = -1 },
}

-- iv is semitones from the root; letters is how many letter-names each degree
-- sits above the root letter, which is what makes F# major spell its seventh
-- E# rather than F.
M.SCALES = {
  { name = "Major",      iv = {0,2,4,5,7,9,11},   letters = {0,1,2,3,4,5,6} },
  { name = "Minor",      iv = {0,2,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Harm Minor", iv = {0,2,3,5,7,8,11},   letters = {0,1,2,3,4,5,6} },
  { name = "Ionian",     iv = {0,2,4,5,7,9,11},   letters = {0,1,2,3,4,5,6} },
  { name = "Dorian",     iv = {0,2,3,5,7,9,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Phrygian",   iv = {0,1,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Lydian",     iv = {0,2,4,6,7,9,11},   letters = {0,1,2,3,4,5,6} },
  { name = "Mixolydian", iv = {0,2,4,5,7,9,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Aeolian",    iv = {0,2,3,5,7,8,10},   letters = {0,1,2,3,4,5,6} },
  { name = "Maj Pent",   iv = {0,2,4,7,9},        letters = {0,1,2,4,5} },
  { name = "Min Pent",   iv = {0,3,5,7,10},       letters = {0,2,3,4,6} },
  { name = "Maj Blues",  iv = {0,2,3,4,7,9},      letters = {0,1,2,2,4,5} },
  { name = "Min Blues",  iv = {0,3,5,6,7,10},     letters = {0,2,3,4,4,6} },
  { name = "Whole Tone", iv = {0,2,4,6,8,10},     letters = {0,1,2,3,4,5} },
  { name = "Dim W-H",    iv = {0,2,3,5,6,8,9,11}, letters = {0,1,2,3,4,5,5,6} },
  { name = "Dim H-W",    iv = {0,1,3,4,6,7,9,10}, letters = {0,1,2,2,3,4,5,6} },
}

M.DEGREE_TITLES = { "Tonic", "Supertonic", "Mediant", "Subdominant",
                    "Dominant", "Submediant", "Leading Tone" }

local NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

------------------------------------------------------------------------------
-- Chords
--
-- One row per chord, carrying its own name, symbol and intervals. Under JSFX
-- these were three parallel tables and adding a chord meant editing all three
-- in step; here a chord is one thing and cannot half-exist.
--
-- Semitones are from the chord's root. The families follow Wikipedia's list of
-- chords.
------------------------------------------------------------------------------

M.FAMILIES = { "Diatonic", "Triads", "6ths & 7ths", "Extended", "Altered",
               "Sus & Add", "Quartal", "Named" }

local T, S7, EX, AL, SA, QU, NA = 2, 3, 4, 5, 6, 7, 8   -- indices into FAMILIES

M.CHORDS = {
  { sym="maj",  name="Major",                  iv={0,4,7},          fam=T },
  { sym="m",    name="Minor",                  iv={0,3,7},          fam=T },
  { sym="dim",  name="Diminished",             iv={0,3,6},          fam=T },
  { sym="aug",  name="Augmented",              iv={0,4,8},          fam=T },
  { sym="b5",   name="Flat Five",              iv={0,4,6},          fam=T },
  { sym="5",    name="Fifth (Power)",          iv={0,7},            fam=T },

  { sym="6",       name="Sixth",                    iv={0,4,7,9},     fam=S7 },
  { sym="m6",      name="Minor Sixth",              iv={0,3,7,9},     fam=S7 },
  { sym="6/9",     name="Six-Nine",                 iv={0,4,7,9,14},  fam=S7 },
  { sym="m6/9",    name="Minor Six-Nine",           iv={0,3,7,9,14},  fam=S7 },
  { sym="7",       name="Dominant Seventh",         iv={0,4,7,10},    fam=S7 },
  { sym="maj7",    name="Major Seventh",            iv={0,4,7,11},    fam=S7 },
  { sym="m7",      name="Minor Seventh",            iv={0,3,7,10},    fam=S7 },
  { sym="mMaj7",   name="Minor-Major Seventh",      iv={0,3,7,11},    fam=S7 },
  { sym="m7b5",    name="Half-Diminished Seventh",  iv={0,3,6,10},    fam=S7 },
  { sym="dim7",    name="Diminished Seventh",       iv={0,3,6,9},     fam=S7 },
  { sym="7#5",     name="Augmented Seventh",        iv={0,4,8,10},    fam=S7 },
  { sym="maj7#5",  name="Augmented Major Seventh",  iv={0,4,8,11},    fam=S7 },
  { sym="7b5",     name="Seventh Flat Five",        iv={0,4,6,10},    fam=S7 },
  { sym="dimMaj7", name="Diminished Major Seventh", iv={0,3,6,11},    fam=S7 },
  { sym="7/6",     name="Seven Six",                iv={0,4,7,9,10},  fam=S7 },

  { sym="9",     name="Ninth",               iv={0,4,7,10,14},       fam=EX },
  { sym="maj9",  name="Major Ninth",         iv={0,4,7,11,14},       fam=EX },
  { sym="m9",    name="Minor Ninth",         iv={0,3,7,10,14},       fam=EX },
  { sym="mMaj9", name="Minor-Major Ninth",   iv={0,3,7,11,14},       fam=EX },
  { sym="11",    name="Eleventh",            iv={0,4,7,10,14,17},    fam=EX },
  { sym="maj11", name="Major Eleventh",      iv={0,4,7,11,14,17},    fam=EX },
  { sym="m11",   name="Minor Eleventh",      iv={0,3,7,10,14,17},    fam=EX },
  { sym="13",    name="Thirteenth",          iv={0,4,7,10,14,17,21}, fam=EX },
  { sym="maj13", name="Major Thirteenth",    iv={0,4,7,11,14,17,21}, fam=EX },
  { sym="m13",   name="Minor Thirteenth",    iv={0,3,7,10,14,17,21}, fam=EX },

  { sym="7b9",       name="Seventh Flat Nine",             iv={0,4,7,10,13},    fam=AL },
  { sym="7#9",       name="Seventh Sharp Nine",            iv={0,4,7,10,15},    fam=AL },
  { sym="7#11",      name="Seventh Sharp Eleven",          iv={0,4,7,10,18},    fam=AL },
  { sym="7b13",      name="Seventh Flat Thirteen",         iv={0,4,7,10,20},    fam=AL },
  { sym="7#5b9",     name="Seventh Sharp Five Flat Nine",  iv={0,4,8,10,13},    fam=AL },
  { sym="7#5#9",     name="Seventh Sharp Five Sharp Nine", iv={0,4,8,10,15},    fam=AL },
  { sym="7b5b9",     name="Seventh Flat Five Flat Nine",   iv={0,4,6,10,13},    fam=AL },
  { sym="7alt",      name="Altered Dominant",              iv={0,4,8,10,13,15}, fam=AL },
  { sym="13b9",      name="Thirteenth Flat Nine",          iv={0,4,7,10,13,21}, fam=AL },
  { sym="maj7#11",   name="Major Seventh Sharp Eleven",    iv={0,4,7,11,18},    fam=AL },
  { sym="m9b5",      name="Minor Ninth Flat Five",         iv={0,3,6,10,14},    fam=AL },
  { sym="9#5",       name="Ninth Augmented Fifth",         iv={0,4,8,10,14},    fam=AL },
  { sym="9b5",       name="Ninth Flat Fifth",              iv={0,4,6,10,14},    fam=AL },
  { sym="9#11",      name="Augmented Eleventh",            iv={0,4,7,10,14,18}, fam=AL },
  { sym="maj7#5#11", name="Augmented Major Seventh Sharp Eleven", iv={0,4,8,11,18}, fam=AL },
  { sym="13b9b5",    name="Thirteenth Flat Nine Flat Five", iv={0,4,6,10,13,21}, fam=AL },

  { sym="sus2",     name="Suspended Second",             iv={0,2,7},       fam=SA },
  { sym="sus4",     name="Suspended Fourth",             iv={0,5,7},       fam=SA },
  { sym="7sus4",    name="Seventh Suspended Fourth",     iv={0,5,7,10},    fam=SA },
  { sym="9sus4",    name="Ninth Suspended Fourth",       iv={0,5,7,10,14}, fam=SA },
  { sym="maj7sus4", name="Major Seventh Suspended Fourth", iv={0,5,7,11},  fam=SA },
  { sym="add9",     name="Added Ninth",                  iv={0,4,7,14},    fam=SA },
  { sym="m(add9)",  name="Minor Added Ninth",            iv={0,3,7,14},    fam=SA },
  { sym="add4",     name="Added Fourth",                 iv={0,4,5,7},     fam=SA },
  { sym="add11",    name="Added Eleventh",               iv={0,4,7,17},    fam=SA },
  { sym="add13",    name="Added Thirteenth",             iv={0,4,7,21},    fam=SA },
  { sym="add2",     name="Added Second",                 iv={0,2,4,7},     fam=SA },
  { sym="m(add2)",  name="Minor Added Second",           iv={0,2,3,7},     fam=SA },

  { sym="Q4/3",    name="Quartal Triad",       iv={0,5,10},    fam=QU },
  { sym="Q4/4",    name="Quartal Tetrad",      iv={0,5,10,15}, fam=QU },
  { sym="Q5/3",    name="Quintal Triad",       iv={0,7,14},    fam=QU },
  { sym="WT3",     name="Whole-Tone Trichord", iv={0,2,4},     fam=QU },
  { sym="cluster", name="Chromatic Cluster",   iv={0,1,2},     fam=QU },
  { sym="dia-cl",  name="Diatonic Cluster",    iv={0,2,4,5},   fam=QU },

  -- Voiced as they stand rather than reduced to a pitch-class set: the list
  -- gives the Tristan chord as 0 3 6 10, which makes it a half-diminished
  -- seventh and indistinguishable from one.
  { sym="Mystic",    name="Mystic (Scriabin)",   iv={0,6,10,16,21,26}, fam=NA },
  { sym="Petrushka", name="Petrushka",           iv={0,4,6,7,10,13},   fam=NA },
  { sym="Tristan",   name="Tristan",             iv={0,6,10,15},       fam=NA },
  { sym="So What",   name="So What",             iv={0,5,10,15,19},    fam=NA },
  { sym="Dream",     name="Dream",               iv={0,5,6,7},         fam=NA },
  { sym="Vienna",    name="Viennese Trichord",   iv={0,1,6},           fam=NA },
  { sym="Vienna II", name="Viennese Trichord II", iv={0,6,7},          fam=NA },
  { sym="Napoleon",  name="Ode-to-Napoleon",     iv={0,1,4,5,8,9},     fam=NA },
  { sym="Elektra",   name="Elektra",             iv={0,7,9,13,16},     fam=NA },
  { sym="Farben",    name="Farben",              iv={0,8,11,16,21},    fam=NA },
  { sym="It+6",      name="Italian Sixth",       iv={0,4,10},          fam=NA },
  { sym="Fr+6",      name="French Sixth",        iv={0,4,6,10},        fam=NA },
  { sym="Ger+6",     name="German Sixth",        iv={0,4,7,10},        fam=NA },
}

-- The chords the key hands you for free, as offsets in scale degrees from the
-- one you picked. Always in key, which is why this is the default family.
M.DIATONIC = {
  { name = "Triad", offsets = {0,2,4} },
  { name = "7th",   offsets = {0,2,4,6} },
  { name = "9th",   offsets = {0,2,4,6,8} },
  { name = "11th",  offsets = {0,2,4,6,8,10} },
  { name = "13th",  offsets = {0,2,4,6,8,10,12} },
  { name = "6th",   offsets = {0,2,4,5} },
  { name = "sus2",  offsets = {0,1,4} },
  { name = "sus4",  offsets = {0,3,4} },
  { name = "5th",   offsets = {0,4} },
}

------------------------------------------------------------------------------
-- Everything else in the catalogue
------------------------------------------------------------------------------

M.RATES = {
  { name = "1/64", beats = 0.0625 }, { name = "1/32", beats = 0.125 },
  { name = "1/16", beats = 0.25 },   { name = "1/8",  beats = 0.5 },
  { name = "1/4",  beats = 1 },      { name = "1/2",  beats = 2 },
  { name = "1/1",  beats = 4 },
}
M.RATE_MODS = {
  { name = "Straight", mul = 1 },
  { name = "Triplet",  mul = 2/3 },
  { name = "Dotted",   mul = 1.5 },
}

M.DIRECTIONS = { "Up", "Down", "Up/Down", "Down/Up", "Random", "Converge", "Diverge" }
-- All six orderings of a triad. Anything above the triad follows in order.
M.ORDERS = {
  { name = "1-3-5", perm = {1,2,3} }, { name = "3-1-5", perm = {2,1,3} },
  { name = "5-3-1", perm = {3,2,1} }, { name = "3-5-1", perm = {2,3,1} },
  { name = "1-5-3", perm = {1,3,2} }, { name = "5-1-3", perm = {3,1,2} },
}

M.INTERVALS  = { "2nd", "3rd", "4th", "5th", "6th", "7th", "Octave" }
M.SHAPES     = { "Single", "Return", "Fill" }
M.BASS_TONES = { "Root", "3rd", "5th", "7th" }
M.INVERSIONS = { "Root", "1st", "2nd", "3rd" }

M.DRUM_PIECES = {
  { name = "Kick", note = 36 },     { name = "Snare", note = 38 },
  { name = "Closed HH", note = 42 },{ name = "Open HH", note = 46 },
  { name = "Crash", note = 49 },    { name = "Ride", note = 51 },
  { name = "Low Tom", note = 41 },  { name = "Mid Tom", note = 47 },
  { name = "High Tom", note = 50 },
}

-- Where the hits fall inside one 4/4 bar. A shorter bar drops what runs past
-- its end rather than squeezing it in.
M.DRUM_PATTERNS = {
  { name = "One Hit",           hits = {0} },
  { name = "Four on the Floor", hits = {0,1,2,3} },
  { name = "One & Three",       hits = {0,2} },
  { name = "Two & Four",        hits = {1,3} },
  { name = "And of Two",        hits = {1.5} },
  { name = "Two Step",          hits = {0,1.5,3} },
  { name = "Off-beats",         hits = {0.5,1.5,2.5,3.5} },
  { name = "Every 8th",         hits = {0,0.5,1,1.5,2,2.5,3,3.5} },
  { name = "Every 16th",        hits = {0,0.25,0.5,0.75,1,1.25,1.5,1.75,
                                        2,2.25,2.5,2.75,3,3.25,3.5,3.75} },
}

M.PROGRESSIONS = {
  { name = "I-V-vi-IV",    degrees = {0,4,5,3} },
  { name = "I-vi-IV-V",    degrees = {0,5,3,4} },
  { name = "ii-V-I",       degrees = {1,4,0} },
  { name = "vi-IV-I-V",    degrees = {5,3,0,4} },
  { name = "I-IV-V-I",     degrees = {0,3,4,0} },
  { name = "I-vi-ii-V",    degrees = {0,5,1,4} },
  { name = "i-VII-VI-VII", degrees = {0,6,5,6} },
  { name = "Pachelbel",    degrees = {0,4,5,2,3,0,3,4} },
  { name = "12-Bar Blues", degrees = {0,0,0,0,3,3,0,0,4,3,0,4} },
}

M.CATEGORIES = { "Chord", "Arpeggio", "Run", "Melody", "Bass", "Drums", "Progression" }

-- Blocks laid out across a progression rather than sitting on one degree.
-- Melody and drums are not among them on purpose: a step or a leap is a
-- smaller thing than a chord change, and a drum has no degree to follow.
local CAN_FOLLOW = { Chord = true, Arpeggio = true, Run = true, Bass = true }

------------------------------------------------------------------------------
-- Settings
--
-- One plain table describes a block completely. Every function below is a pure
-- function of it, so a test can build one, ask for the notes, and check them.
------------------------------------------------------------------------------

function M.newState()
  return {
    root = 1, scale = 1, degree = 0,       -- degree is 0-based: 0 is the tonic
    cat = "Chord",
    family = 1, dia = 1, chord = 1,        -- family 1 is Diatonic
    inv = 0, oct = 0,
    pattern = 1, patternIsOrder = false,   -- DIRECTIONS[1] or ORDERS[1]
    runDir = 1,
    rate = 4, rateMod = 1,                 -- 1/8 straight
    octaves = 1, bars = 1,
    vel = 100, gate = 90,
    interval = 1, melDir = 1, shape = 1,   -- a step, up, on its own
    bassTone = 1, bassOct = -1,
    drumPiece = 1, drumPattern = 2,
    baseOct = 4,                           -- C4 is 60
    barBeats = 4,                          -- what the project says a bar is
    prog = { degrees = {0,4,5,3}, len = 4, bars = 1, follow = false },
    step = 1,                              -- the progression step being edited
  }
end

------------------------------------------------------------------------------
-- Theory
------------------------------------------------------------------------------

function M.scaleLen(st) return #M.SCALES[st.scale].iv end

-- The MIDI pitch of a scale degree, counting past the top of the scale into
-- the octave above and below zero into the one below.
function M.scalePitch(st, degree)
  local sc  = M.SCALES[st.scale]
  local n   = #sc.iv
  local oct = math.floor(degree / n)
  local k   = degree - oct * n
  local rt  = M.ROOTS[st.root]
  local pc  = (LETTER_PC[rt.letter + 1] + rt.acc + 120) % 12
  return pc + (st.baseOct + 1) * 12 + sc.iv[k + 1] + oct * 12
end

-- Spelled for the key: the seventh of F# major comes out E#, not F.
function M.noteName(st, degree)
  local sc  = M.SCALES[st.scale]
  local n   = #sc.iv
  local oct = math.floor(degree / n)
  local k   = degree - oct * n
  local letter = (M.ROOTS[st.root].letter + sc.letters[k + 1]) % 7
  local acc = M.scalePitch(st, degree) % 12 - LETTER_PC[letter + 1]
  if acc >  6 then acc = acc - 12 end
  if acc < -6 then acc = acc + 12 end
  return LETTERS[letter + 1] .. (ACCIDENTAL[acc] or "?")
end

-- Read off the scale rather than assumed, so the modes and the blues scales
-- come out right: the vii of major is diminished, the III of natural minor is
-- major.
function M.degreeQuality(st, degree)
  local p  = M.scalePitch(st, degree)
  local r3 = M.scalePitch(st, degree + 2) - p
  local r5 = M.scalePitch(st, degree + 4) - p
  if r3 == 4 and r5 == 7 then return "major"      end
  if r3 == 3 and r5 == 7 then return "minor"      end
  if r3 == 3 and r5 == 6 then return "diminished" end
  if r3 == 4 and r5 == 8 then return "augmented"  end
  return "other"
end

function M.degreeNumeral(st, degree, ascii)
  local q = M.degreeQuality(st, degree)
  local n = NUMERALS[(degree % 8) + 1]
  if q == "minor" or q == "diminished" then n = n:lower() end
  if q == "diminished" then n = n .. (ascii and "dim" or "\u{00B0}") end
  if q == "augmented"  then n = n .. (ascii and "aug" or "+") end
  return n
end

-- Only the seven-note scales carry these names, and the seventh is a leading
-- tone only when it really does lean on the tonic a semitone above.
function M.degreeTitle(st, degree)
  if M.scaleLen(st) ~= 7 then return "Degree " .. (degree + 1) end
  if degree == 6 and M.scalePitch(st, 7) - M.scalePitch(st, 6) ~= 1 then
    return "Subtonic"
  end
  return M.DEGREE_TITLES[degree + 1] or ("Degree " .. (degree + 1))
end

-- The chord's pitches, ascending. inv lifts that many of the lowest voices an
-- octave, one at a time.
function M.chordTones(st, degree, inv)
  local tones = {}
  if st.family == 1 then
    for _, off in ipairs(M.DIATONIC[st.dia].offsets) do
      tones[#tones + 1] = M.scalePitch(st, degree + off) + st.oct * 12
    end
  else
    local base = M.scalePitch(st, degree) + st.oct * 12
    for _, iv in ipairs(M.CHORDS[st.chord].iv) do
      tones[#tones + 1] = base + iv
    end
  end
  for _ = 1, math.min(inv or 0, #tones - 1) do
    local lifted = table.remove(tones, 1) + 12
    tones[#tones + 1] = lifted
  end
  return tones
end

function M.rateBeats(st)
  return M.RATES[st.rate].beats * M.RATE_MODS[st.rateMod].mul
end

function M.canFollow(cat) return CAN_FOLLOW[cat] == true end

-- The Progression tab always walks its steps - that is what it is. The others
-- do it when asked.
function M.follows(st)
  if st.cat == "Progression" then return true end
  return st.prog.follow and st.prog.len > 1 and M.canFollow(st.cat)
end

-- A progression written for seven degrees has to fold into a shorter scale
-- rather than running off the end of it into the octave above.
function M.clampProgression(st)
  local top = M.scaleLen(st) - 1
  for i = 1, M.MAX_PROG do
    st.prog.degrees[i] = math.max(0, math.min(st.prog.degrees[i] or 0, top))
  end
end

-- Settings can arrive from a saved project written by an older version, or one
-- whose tables were a different size. Every index here is used to look
-- something up, so anything past the end of its table has to come back inside
-- it before the rest of the program trusts it.
function M.clampState(st)
  local function pin(v, lo, hi, fallback)
    v = tonumber(v) or fallback
    return math.max(lo, math.min(math.floor(v), hi))
  end

  st.root     = pin(st.root, 1, #M.ROOTS, 1)
  st.scale    = pin(st.scale, 1, #M.SCALES, 1)
  st.family   = pin(st.family, 1, #M.FAMILIES, 1)
  st.chord    = pin(st.chord, 1, #M.CHORDS, 1)
  st.dia      = pin(st.dia, 1, #M.DIATONIC, 1)
  st.rate     = pin(st.rate, 1, #M.RATES, 4)
  st.rateMod  = pin(st.rateMod, 1, #M.RATE_MODS, 1)
  st.runDir   = pin(st.runDir, 1, #M.DIRECTIONS, 1)
  st.pattern  = pin(st.pattern, 1,
                    st.patternIsOrder and #M.ORDERS or #M.DIRECTIONS, 1)
  st.interval = pin(st.interval, 1, #M.INTERVALS, 1)
  st.melDir   = pin(st.melDir, 1, 2, 1)
  st.shape    = pin(st.shape, 1, #M.SHAPES, 1)
  st.bassTone = pin(st.bassTone, 1, #M.BASS_TONES, 1)
  st.drumPiece   = pin(st.drumPiece, 1, #M.DRUM_PIECES, 1)
  st.drumPattern = pin(st.drumPattern, 1, #M.DRUM_PATTERNS, 1)
  st.step     = pin(st.step, 1, M.MAX_PROG, 1)

  -- Ranges the sliders declare. A value outside one of these is what ReaImGui
  -- refuses, so they have to agree with the UI.
  st.inv      = pin(st.inv, 0, 3, 0)
  st.oct      = pin(st.oct, -3, 3, 0)
  st.bassOct  = pin(st.bassOct, -3, 0, -1)
  st.octaves  = pin(st.octaves, 1, 4, 1)
  st.vel      = pin(st.vel, 1, 127, 100)
  st.gate     = pin(st.gate, 5, 100, 90)
  st.baseOct  = pin(st.baseOct, 0, 8, 4)
  st.bars     = pin(st.bars, 1, 8, 1)
  if st.bars ~= 1 and st.bars ~= 2 and st.bars ~= 4 and st.bars ~= 8 then st.bars = 1 end

  st.prog          = st.prog or {}
  st.prog.degrees  = st.prog.degrees or {}
  st.prog.len      = pin(st.prog.len, 1, M.MAX_PROG, 4)
  st.prog.bars     = pin(st.prog.bars, 1, 4, 1)
  if st.prog.bars == 3 then st.prog.bars = 4 end
  st.prog.follow   = st.prog.follow == true
  st.step          = math.min(st.step, st.prog.len)

  local found = false
  for _, c in ipairs(M.CATEGORIES) do if c == st.cat then found = true end end
  if not found then st.cat = M.CATEGORIES[1] end

  st.degree = pin(st.degree, 0, M.scaleLen(st) - 1, 0)
  M.clampProgression(st)
  return st
end

function M.progressionText(st, sep, ascii)
  local parts = {}
  for i = 1, st.prog.len do
    parts[i] = M.degreeNumeral(st, st.prog.degrees[i] or 0, ascii)
  end
  return table.concat(parts, sep or " - ")
end

function M.chordLabel(st)
  if st.family == 1 then return M.DIATONIC[st.dia].name end
  return M.CHORDS[st.chord].sym
end

------------------------------------------------------------------------------
-- Generators
--
-- Each one writes into a segment: c.notes is the block so far, c.ofs is where
-- in the block this piece starts, c.len is how long it should be, and c.degree
-- is the degree it is on. Following a progression is nothing more than calling
-- the same generator once per step with a different ofs and degree, which is
-- why none of them know progressions exist.
------------------------------------------------------------------------------

local function addNote(c, start, len, pitch, vel)
  if #c.notes >= M.MAX_NOTES then c.truncated = true; return end
  if pitch < 0 or pitch > 127 then return end
  c.notes[#c.notes + 1] = {
    start = c.ofs + start,
    len   = math.max(len, 0.015),
    pitch = math.floor(pitch),
    vel   = math.max(1, math.min(127, math.floor(vel))),
  }
end

-- Lays a list of pitches out in playing order for one of the seven directions.
local function applyDirection(pool, dir)
  local out, m = {}, #pool
  if m == 0 then return out end
  local name = M.DIRECTIONS[dir]

  if name == "Up" then
    for i = 1, m do out[#out + 1] = pool[i] end

  elseif name == "Down" then
    for i = m, 1, -1 do out[#out + 1] = pool[i] end

  elseif name == "Up/Down" then
    for i = 1, m do out[#out + 1] = pool[i] end
    for i = m - 1, 2, -1 do out[#out + 1] = pool[i] end

  elseif name == "Down/Up" then
    for i = m, 1, -1 do out[#out + 1] = pool[i] end
    for i = 2, m - 1 do out[#out + 1] = pool[i] end

  elseif name == "Random" then
    -- A shuffle rather than free picks, so every pitch gets its turn before
    -- any of them repeats.
    for i = 1, m do out[i] = pool[i] end
    for i = m, 2, -1 do
      local j = math.random(i)
      out[i], out[j] = out[j], out[i]
    end

  elseif name == "Converge" then          -- outside in
    local lo, hi = 1, m
    while lo <= hi do
      out[#out + 1] = pool[lo]; lo = lo + 1
      if lo <= hi then out[#out + 1] = pool[hi]; hi = hi - 1 end
    end

  elseif name == "Diverge" then           -- middle out
    local lo = math.floor((m + 1) / 2)
    local hi = lo + 1
    while lo >= 1 or hi <= m do
      if lo >= 1 then out[#out + 1] = pool[lo]; lo = lo - 1 end
      if hi <= m then out[#out + 1] = pool[hi]; hi = hi + 1 end
    end
  end
  return out
end
M._applyDirection = applyDirection

-- Walks a sequence of pitches over the length of the segment, one per step.
local function laySteps(st, c, seq)
  if #seq == 0 then return end
  local step = M.rateBeats(st)
  local pos, idx = 0, 0
  while pos < c.len - 1e-9 do
    addNote(c, pos, math.min(step * st.gate / 100, c.len - pos),
            seq[(idx % #seq) + 1], st.vel)
    if c.truncated then return end
    idx, pos = idx + 1, pos + step
  end
end

local GEN = {}

GEN.Chord = function(st, c)
  local len = c.len * st.gate / 100
  for _, p in ipairs(M.chordTones(st, c.degree, st.inv)) do
    addNote(c, 0, len, p, st.vel)
  end
end

GEN.Arpeggio = function(st, c)
  local tones = M.chordTones(st, c.degree, st.inv)
  if #tones == 0 then return end
  local seq

  if st.patternIsOrder then
    -- A fixed shape: the lowest three voices in a set order, anything above
    -- them in order after, and the whole cell climbing an octave at a time.
    seq = {}
    local perm = M.ORDERS[st.pattern].perm
    for o = 0, st.octaves - 1 do
      if #tones >= 3 then
        for _, k in ipairs(perm) do seq[#seq + 1] = tones[k] + o * 12 end
        for k = 4, #tones do seq[#seq + 1] = tones[k] + o * 12 end
      else
        for k = 1, #tones do seq[#seq + 1] = tones[k] + o * 12 end
      end
    end
  else
    local pool = {}
    for o = 0, st.octaves - 1 do
      for _, p in ipairs(tones) do pool[#pool + 1] = p + o * 12 end
    end
    seq = applyDirection(pool, st.pattern)
  end
  laySteps(st, c, seq)
end

GEN.Run = function(st, c)
  local pool = {}
  -- Inclusive of the octave above, so a one-octave run lands back on the note
  -- it started from.
  for i = 0, M.scaleLen(st) * st.octaves do
    pool[#pool + 1] = M.scalePitch(st, c.degree + i) + st.oct * 12
  end
  laySteps(st, c, applyDirection(pool, st.runDir))
end

-- A melodic cell is however long its own notes make it, so it sizes the block
-- rather than being sized by it.
function M.melodyBeats(st)
  local steps = (st.interval == 7) and M.scaleLen(st) or st.interval
  local n = (st.shape == 1 and 2) or (st.shape == 2 and 3) or (steps + 1)
  return M.rateBeats(st) * n
end

GEN.Melody = function(st, c)
  -- A 2nd is one scale step, a 3rd is two, and the octave is however many
  -- steps this particular scale takes to get there.
  local steps = (st.interval == 7) and M.scaleLen(st) or st.interval
  local dir   = (st.melDir == 1) and 1 or -1
  local step  = M.rateBeats(st)
  local len   = step * st.gate / 100
  local a = M.scalePitch(st, c.degree) + st.oct * 12
  local b = M.scalePitch(st, c.degree + dir * steps) + st.oct * 12

  if st.shape == 1 then                      -- Single: the move
    addNote(c, 0, len, a, st.vel)
    addNote(c, step, len, b, st.vel)
  elseif st.shape == 2 then                  -- Return: there and back
    addNote(c, 0, len, a, st.vel)
    addNote(c, step, len, b, st.vel)
    addNote(c, step * 2, len, a, st.vel)
  else                                       -- Fill: every note in between
    for i = 0, steps do
      addNote(c, i * step, len,
              M.scalePitch(st, c.degree + dir * i) + st.oct * 12, st.vel)
    end
  end
end

GEN.Bass = function(st, c)
  -- The bass reads the chord as it is stacked, so inversion is ignored: voice
  -- 1 is the root, 2 the third, 3 the fifth, 4 the seventh.
  local tones = M.chordTones(st, c.degree, 0)
  if #tones == 0 then return end
  local pitch = tones[math.min(st.bassTone, #tones)] + st.bassOct * 12
  local step  = M.rateBeats(st)
  local pos   = 0
  while pos < c.len - 1e-9 do
    addNote(c, pos, math.min(step * st.gate / 100, c.len - pos), pitch, st.vel)
    if c.truncated then return end
    pos = pos + step
  end
end

GEN.Drums = function(st, c)
  local note = M.DRUM_PIECES[st.drumPiece].note
  local hits = M.DRUM_PATTERNS[st.drumPattern].hits
  for bar = 0, st.bars - 1 do
    for _, at in ipairs(hits) do
      if at < st.barBeats then
        addNote(c, bar * st.barBeats + at, 0.1, note, st.vel)
      end
    end
  end
end

------------------------------------------------------------------------------
-- The block
------------------------------------------------------------------------------

function M.blockName(st)
  local root  = M.ROOTS[st.root].name
  local scale = M.SCALES[st.scale].name
  local where = M.follows(st) and M.progressionText(st, "-", true)
                              or M.degreeNumeral(st, st.degree, true)
  local rate  = M.RATES[st.rate].name
  local pat   = st.patternIsOrder and M.ORDERS[st.pattern].name
                                   or M.DIRECTIONS[st.pattern]

  if st.cat == "Progression" then
    return ("%s %s Prog %s %s"):format(root, scale, where, M.chordLabel(st))
  elseif st.cat == "Chord" then
    return ("%s %s %s Chord %s"):format(root, scale, where, M.chordLabel(st))
  elseif st.cat == "Arpeggio" then
    return ("%s %s %s Arp %s %s %s"):format(root, scale, where,
                                            M.chordLabel(st), pat, rate)
  elseif st.cat == "Run" then
    return ("%s %s %s Run %s %s"):format(root, scale, where,
                                         M.DIRECTIONS[st.runDir], rate)
  elseif st.cat == "Melody" then
    return ("%s %s %s Melody %s %s %s"):format(root, scale, where,
      (st.melDir == 1) and "Up" or "Down",
      M.INTERVALS[st.interval], M.SHAPES[st.shape])
  elseif st.cat == "Bass" then
    return ("%s %s %s Bass %s %s"):format(root, scale, where,
      M.BASS_TONES[st.bassTone], rate)
  end
  return ("Drum %s %s"):format(M.DRUM_PIECES[st.drumPiece].name,
                               M.DRUM_PATTERNS[st.drumPattern].name)
end

-- The whole point of the file. Returns the notes in quarter notes from the
-- start of the block, how long the block is, and what it is called.
function M.generate(st)
  local c = { notes = {}, ofs = 0, len = 0, degree = st.degree, truncated = false }
  -- A progression's own output is the chord on each of its steps.
  local gen = GEN[st.cat == "Progression" and "Chord" or st.cat]
  local beats

  if M.follows(st) then
    local seg = st.prog.bars * st.barBeats
    beats = st.prog.len * seg
    c.len = seg
    for i = 1, st.prog.len do
      c.degree = st.prog.degrees[i] or 0
      c.ofs    = (i - 1) * seg
      gen(st, c)
    end
  else
    c.len = (st.cat == "Melody") and M.melodyBeats(st) or (st.barBeats * st.bars)
    beats = c.len
    gen(st, c)
  end

  return {
    notes     = c.notes,
    beats     = beats,
    name      = M.blockName(st),
    truncated = c.truncated,
  }
end

return M
