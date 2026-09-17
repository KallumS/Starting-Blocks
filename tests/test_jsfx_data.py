#!/usr/bin/env python3
"""Checks the musical tables inside the JSFX against what they are meant to be.

The generators are EEL2 and there is no EEL2 interpreter to run them under, so
this checks the thing that can be checked without one and is the likeliest to
go quietly wrong: the data. Every chord is decoded from its bitmask and matched
against the semitones it is supposed to hold, the scales are matched against
ScaleView's, and the parallel name and symbol strings are matched against the
table they label.

    python3 tests/test_jsfx_data.py
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
JSFX = os.path.join(HERE, "..", "jsfx", "Starting Blocks.jsfx")

failures = []


def check(cond, what):
    if not cond:
        failures.append(what)


def eq(got, want, what):
    if got != want:
        failures.append(f"{what}\n        got  {got}\n        want {want}")


src = open(JSFX, encoding="utf-8").read()


# -- pull the tables out of the source ---------------------------------------

def indexed_string(var):
    parts = re.findall(r'str(?:cpy|cat)\(#%s,\s*"((?:[^"\\]|\\.)*)"\)' % var, src)
    return "".join(parts).split("|")


chord_masks = []
for m in re.finditer(r'chord_add\(cm\(([^)]*)\),\s*(\d+)\)', src):
    ivs = [int(x) for x in m.group(1).replace(" ", "").split(",")]
    chord_masks.append(([i for i in ivs if i >= 0], int(m.group(2))))

scales = []
for m in re.finditer(r'sc_add\((\d+),\s*([^)]*)\);\s*sc_let\(([^)]*)\);\s*//\s*(.+)', src):
    cnt = int(m.group(1))
    ivs = [int(x) for x in m.group(2).replace(" ", "").split(",")]
    lets = [int(x) for x in m.group(3).replace(" ", "").split(",")]
    scales.append((m.group(4).strip(), cnt, ivs[:cnt], lets[:cnt]))

roots = []
for m in re.finditer(r'root_add\(\s*(-?\d+),\s*(-?\d+)\)', src):
    roots.append((int(m.group(1)), int(m.group(2))))

dia = []
for m in re.finditer(r'dia_add\((\d+),\s*([^)]*)\);\s*//\s*(.+)', src):
    cnt = int(m.group(1))
    offs = [int(x) for x in m.group(2).replace(" ", "").split(",")]
    dia.append((m.group(3).strip(), cnt, offs[:cnt]))

chord_names = indexed_string("chord_names")
chord_syms  = indexed_string("chord_syms")
scale_names = indexed_string("scale_names")
root_names  = indexed_string("root_names")
dia_names   = indexed_string("dia_names")
fam_names   = indexed_string("fam_names")
pat_names   = indexed_string("pat_names")
drp_names   = indexed_string("drp_names")
drs_names   = indexed_string("drs_names")


# -- the parallel tables must stay parallel ----------------------------------

eq(len(chord_names), len(chord_masks), "one name per chord")
eq(len(chord_syms),  len(chord_masks), "one symbol per chord")
eq(len(scale_names), len(scales),      "one name per scale")
eq(len(root_names),  len(roots),       "one name per root")
eq(len(dia_names),   len(dia),         "one name per diatonic stack")
eq(len(set(chord_names)), len(chord_names), "no chord name appears twice")
eq(len(set(chord_syms)),  len(chord_syms),  "no chord symbol appears twice")
eq(len(fam_names), 8, "eight chord families, counting the diatonic one")


# -- scales ------------------------------------------------------------------
#
# Taken from ScaleView for REAPER, so the two apps agree on what a scale is.
# intervals are semitones from the root; letters are how many letter-names each
# degree sits above the root letter, which is what makes the spelling come out.

EXPECTED_SCALES = [
    ("Major",            [0,2,4,5,7,9,11],    [0,1,2,3,4,5,6]),
    ("Minor (natural)",  [0,2,3,5,7,8,10],    [0,1,2,3,4,5,6]),
    ("Harmonic Minor",   [0,2,3,5,7,8,11],    [0,1,2,3,4,5,6]),
    ("Ionian",           [0,2,4,5,7,9,11],    [0,1,2,3,4,5,6]),
    ("Dorian",           [0,2,3,5,7,9,10],    [0,1,2,3,4,5,6]),
    ("Phrygian",         [0,1,3,5,7,8,10],    [0,1,2,3,4,5,6]),
    ("Lydian",           [0,2,4,6,7,9,11],    [0,1,2,3,4,5,6]),
    ("Mixolydian",       [0,2,4,5,7,9,10],    [0,1,2,3,4,5,6]),
    ("Aeolian",          [0,2,3,5,7,8,10],    [0,1,2,3,4,5,6]),
    ("Major Pentatonic", [0,2,4,7,9],         [0,1,2,4,5]),
    ("Minor Pentatonic", [0,3,5,7,10],        [0,2,3,4,6]),
    ("Major Blues",      [0,2,3,4,7,9],       [0,1,2,2,4,5]),
    ("Minor Blues",      [0,3,5,6,7,10],      [0,2,3,4,4,6]),
    ("Whole Tone",       [0,2,4,6,8,10],      [0,1,2,3,4,5]),
    ("Diminished W-H",   [0,2,3,5,6,8,9,11],  [0,1,2,3,4,5,5,6]),
    ("Diminished H-W",   [0,1,3,4,6,7,9,10],  [0,1,2,2,3,4,5,6]),
]

eq(len(scales), len(EXPECTED_SCALES), "sixteen scales")
for (comment, cnt, ivs, lets), (name, want_ivs, want_lets) in zip(scales, EXPECTED_SCALES):
    eq(ivs,  want_ivs,  f"{name}: intervals")
    eq(lets, want_lets, f"{name}: letters")
    eq(cnt,  len(want_ivs), f"{name}: note count")
    check(ivs[0] == 0, f"{name}: starts on the root")
    check(ivs == sorted(ivs), f"{name}: intervals ascend")
    check(lets == sorted(lets), f"{name}: letters ascend")
    check(max(ivs) < 12, f"{name}: stays inside one octave")


# -- roots -------------------------------------------------------------------

LETTER_PC = [0, 2, 4, 5, 7, 9, 11]
SHARP = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]

for name, (letter, acc) in zip(root_names, roots):
    check(0 <= letter <= 6, f"root {name}: letter in range")
    check(-1 <= acc <= 1,   f"root {name}: accidental in range")
    # the name must spell what the letter and accidental say it is
    want = "CDEFGAB"[letter] + {-1: "b", 0: "", 1: "#"}[acc]
    eq(name, want, f"root {name}: name matches its letter and accidental")

eq(len(set((LETTER_PC[l] + a) % 12 for l, a in roots)), 12,
   "the roots between them cover all twelve pitch classes")


# -- chords ------------------------------------------------------------------
#
# Semitones above the root, in the order the table declares them.

TRIADS, SEVENTHS, EXTENDED, ALTERED, SUSADD, QUARTAL, NAMED = 1, 2, 3, 4, 5, 6, 7

EXPECTED_CHORDS = [
    ("Major",                         "maj",       [0,4,7],              TRIADS),
    ("Minor",                         "m",         [0,3,7],              TRIADS),
    ("Diminished",                    "dim",       [0,3,6],              TRIADS),
    ("Augmented",                     "aug",       [0,4,8],              TRIADS),
    ("Flat Five",                     "b5",        [0,4,6],              TRIADS),
    ("Fifth (Power)",                 "5",         [0,7],                TRIADS),

    ("Sixth",                         "6",         [0,4,7,9],            SEVENTHS),
    ("Minor Sixth",                   "m6",        [0,3,7,9],            SEVENTHS),
    ("Six-Nine",                      "6/9",       [0,4,7,9,14],         SEVENTHS),
    ("Minor Six-Nine",                "m6/9",      [0,3,7,9,14],         SEVENTHS),
    ("Dominant Seventh",              "7",         [0,4,7,10],           SEVENTHS),
    ("Major Seventh",                 "maj7",      [0,4,7,11],           SEVENTHS),
    ("Minor Seventh",                 "m7",        [0,3,7,10],           SEVENTHS),
    ("Minor-Major Seventh",           "mMaj7",     [0,3,7,11],           SEVENTHS),
    ("Half-Diminished Seventh",       "m7b5",      [0,3,6,10],           SEVENTHS),
    ("Diminished Seventh",            "dim7",      [0,3,6,9],            SEVENTHS),
    ("Augmented Seventh",             "7#5",       [0,4,8,10],           SEVENTHS),
    ("Augmented Major Seventh",       "maj7#5",    [0,4,8,11],           SEVENTHS),
    ("Seventh Flat Five",             "7b5",       [0,4,6,10],           SEVENTHS),

    ("Ninth",                         "9",         [0,4,7,10,14],        EXTENDED),
    ("Major Ninth",                   "maj9",      [0,4,7,11,14],        EXTENDED),
    ("Minor Ninth",                   "m9",        [0,3,7,10,14],        EXTENDED),
    ("Minor-Major Ninth",             "mMaj9",     [0,3,7,11,14],        EXTENDED),
    ("Eleventh",                      "11",        [0,4,7,10,14,17],     EXTENDED),
    ("Major Eleventh",                "maj11",     [0,4,7,11,14,17],     EXTENDED),
    ("Minor Eleventh",                "m11",       [0,3,7,10,14,17],     EXTENDED),
    ("Thirteenth",                    "13",        [0,4,7,10,14,17,21],  EXTENDED),
    ("Major Thirteenth",              "maj13",     [0,4,7,11,14,17,21],  EXTENDED),
    ("Minor Thirteenth",              "m13",       [0,3,7,10,14,17,21],  EXTENDED),

    ("Seventh Flat Nine",             "7b9",       [0,4,7,10,13],        ALTERED),
    ("Seventh Sharp Nine",            "7#9",       [0,4,7,10,15],        ALTERED),
    ("Seventh Sharp Eleven",          "7#11",      [0,4,7,10,18],        ALTERED),
    ("Seventh Flat Thirteen",         "7b13",      [0,4,7,10,20],        ALTERED),
    ("Seventh Sharp Five Flat Nine",  "7#5b9",     [0,4,8,10,13],        ALTERED),
    ("Seventh Sharp Five Sharp Nine", "7#5#9",     [0,4,8,10,15],        ALTERED),
    ("Seventh Flat Five Flat Nine",   "7b5b9",     [0,4,6,10,13],        ALTERED),
    ("Altered Dominant",              "7alt",      [0,4,8,10,13,15],     ALTERED),
    ("Thirteenth Flat Nine",          "13b9",      [0,4,7,10,13,21],     ALTERED),
    ("Major Seventh Sharp Eleven",    "maj7#11",   [0,4,7,11,18],        ALTERED),
    ("Minor Ninth Flat Five",         "m9b5",      [0,3,6,10,14],        ALTERED),

    ("Suspended Second",              "sus2",      [0,2,7],              SUSADD),
    ("Suspended Fourth",              "sus4",      [0,5,7],              SUSADD),
    ("Seventh Suspended Fourth",      "7sus4",     [0,5,7,10],           SUSADD),
    ("Ninth Suspended Fourth",        "9sus4",     [0,5,7,10,14],        SUSADD),
    ("Major Seventh Suspended Fourth","maj7sus4",  [0,5,7,11],           SUSADD),
    ("Added Ninth",                   "add9",      [0,4,7,14],           SUSADD),
    ("Minor Added Ninth",             "m(add9)",   [0,3,7,14],           SUSADD),
    ("Added Fourth",                  "add4",      [0,4,5,7],            SUSADD),
    ("Added Eleventh",                "add11",     [0,4,7,17],           SUSADD),
    ("Added Thirteenth",              "add13",     [0,4,7,21],           SUSADD),

    ("Quartal Triad",                 "Q4/3",      [0,5,10],             QUARTAL),
    ("Quartal Tetrad",                "Q4/4",      [0,5,10,15],          QUARTAL),
    ("Quintal Triad",                 "Q5/3",      [0,7,14],             QUARTAL),
    ("Whole-Tone Trichord",           "WT3",       [0,2,4],              QUARTAL),
    ("Chromatic Cluster",             "cluster",   [0,1,2],              QUARTAL),
    ("Diatonic Cluster",              "dia-cl",    [0,2,4,5],            QUARTAL),

    # C F# Bb E A D, stacked as Scriabin voiced it.
    ("Mystic (Scriabin)",             "Mystic",    [0,6,10,16,21,26],    NAMED),
    # C major over F# major.
    ("Petrushka",                     "Petrushka", [0,4,6,7,10,13],      NAMED),
    # F B D# G#, as it stands in the Tristan prelude.
    ("Tristan",                       "Tristan",   [0,6,10,15],          NAMED),
    # Three fourths and a third.
    ("So What",                       "So What",   [0,5,10,15,19],       NAMED),
    ("Dream",                         "Dream",     [0,5,6,7],            NAMED),
    ("Viennese Trichord",             "Vienna",    [0,1,6],              NAMED),
    ("Ode-to-Napoleon",               "Napoleon",  [0,1,4,5,8,9],        NAMED),
    ("Italian Sixth",                 "It+6",      [0,4,10],             NAMED),
    ("French Sixth",                  "Fr+6",      [0,4,6,10],           NAMED),
    ("German Sixth",                  "Ger+6",     [0,4,7,10],           NAMED),
]

eq(len(chord_masks), len(EXPECTED_CHORDS), "every chord in the table is accounted for")

for (ivs, fam), name, sym, (want_name, want_sym, want_ivs, want_fam) in zip(
        chord_masks, chord_names, chord_syms, EXPECTED_CHORDS):
    eq(name, want_name, f"chord {want_name}: name")
    eq(sym,  want_sym,  f"chord {want_name}: symbol")
    eq(ivs,  want_ivs,  f"chord {want_name}: semitones")
    eq(fam,  want_fam,  f"chord {want_name}: family")

for (ivs, fam), name in zip(chord_masks, chord_names):
    check(ivs[0] == 0, f"chord {name}: is written from its root")
    check(len(ivs) >= 2, f"chord {name}: has at least two notes")
    check(ivs == sorted(ivs), f"chord {name}: semitones ascend")
    check(len(set(ivs)) == len(ivs), f"chord {name}: no note twice")
    check(max(ivs) <= 31, f"chord {name}: fits the 32-bit interval mask")
    check(len(ivs) <= 7, f"chord {name}: fits the seven slots cm() takes")

# Two chords in the same family with the same notes would be two buttons that
# do the same thing. Across families it is allowed: a German sixth really is
# spelled like a dominant seventh.
by_family = {}
for (ivs, fam), name in zip(chord_masks, chord_names):
    by_family.setdefault(fam, []).append((tuple(ivs), name))
for fam, entries in by_family.items():
    seen = {}
    for ivs, name in entries:
        if ivs in seen:
            failures.append(f"family {fam}: {name} duplicates {seen[ivs]}")
        seen[ivs] = name
check(sorted(by_family) == [1, 2, 3, 4, 5, 6, 7], "every family from 1 to 7 has chords")


# -- diatonic stacks ---------------------------------------------------------

EXPECTED_DIA = [
    ("Triad", [0, 2, 4]),
    ("7th",   [0, 2, 4, 6]),
    ("9th",   [0, 2, 4, 6, 8]),
    ("11th",  [0, 2, 4, 6, 8, 10]),
    ("13th",  [0, 2, 4, 6, 8, 10, 12]),
    ("6th",   [0, 2, 4, 5]),
    ("sus2",  [0, 1, 4]),
    ("sus4",  [0, 3, 4]),
    ("5th",   [0, 4]),
]
eq(len(dia), len(EXPECTED_DIA), "nine diatonic stacks")
for (comment, cnt, offs), (name, want) in zip(dia, EXPECTED_DIA):
    eq(offs, want, f"diatonic {name}: scale-degree offsets")
    eq(cnt, len(want), f"diatonic {name}: count")
for name, dname in zip([d[0] for d in EXPECTED_DIA], dia_names):
    eq(dname, name, "diatonic names line up with the stacks")


# -- drums -------------------------------------------------------------------

drum_notes = []
for m in re.finditer(r'DRUM_NOTE\[(\d+)\]\s*=\s*(\d+)', src):
    drum_notes.append((int(m.group(1)), int(m.group(2))))
drum_notes = [n for _, n in sorted(drum_notes)]

# General MIDI percussion, so the blocks land on the right pads in any drum
# sampler that follows the map.
EXPECTED_DRUMS = [36, 38, 42, 46, 49, 51, 41, 47, 50]
eq(drum_notes, EXPECTED_DRUMS, "drum pieces use the General MIDI note numbers")
eq(len(drp_names), len(EXPECTED_DRUMS), "one name per drum piece")
eq(len(set(drum_notes)), len(drum_notes), "no two pieces share a note")
eq(len(drs_names), 9, "nine drum patterns")


# -- patterns ----------------------------------------------------------------

eq(pat_names[:7], ["Up", "Down", "Up/Down", "Down/Up", "Random", "Converge", "Diverge"],
   "the seven directions, in the order the run panel shows them")
eq(pat_names[7:], ["1-3-5", "3-1-5", "5-3-1", "3-5-1", "1-5-3", "5-1-3"],
   "all six orderings of a triad")
eq(len(set(pat_names[7:])), 6, "each ordering appears once")
for order in pat_names[7:]:
    eq(sorted(order.split("-")), ["1", "3", "5"], f"{order} is a permutation of 1 3 5")


# -- the memory map must not overlap -----------------------------------------

regions = {}
for m in re.finditer(r'^(\w+)\s*=\s*(\d+);', src, re.M):
    regions[m.group(1)] = int(m.group(2))

# (name, first word, words used)
SPANS = [
    ("NOTES", regions["NOTES"], 1024 * 4),
    ("SCL_IV", regions["SCL_IV"], 16 * 8),
    ("SCL_LT", regions["SCL_LT"], 16 * 8),
    ("SCL_N", regions["SCL_N"], 16),
    ("CH_MASK", regions["CH_MASK"], len(chord_masks)),
    ("CH_FAM", regions["CH_FAM"], len(chord_masks)),
    ("TONES", regions["TONES"], 128),
    ("POOL", regions["POOL"], 128),
    ("SEQ", regions["SEQ"], 128),
    ("ROOT_LT", regions["ROOT_LT"], len(roots)),
    ("ROOT_ACC", regions["ROOT_ACC"], len(roots)),
    ("DRUM_NOTE", regions["DRUM_NOTE"], len(drum_notes)),
    ("LETTER_PC", regions["LETTER_PC"], 7),
    ("DIA_OFF", regions["DIA_OFF"], 9 * 8),
    ("DIA_CNT", regions["DIA_CNT"], 9),
    ("HITS", regions["HITS"], 16),
    ("IDX_SCL", regions["IDX_SCL"], 2 * len(scale_names)),
    ("IDX_ROOT", regions["IDX_ROOT"], 2 * len(root_names)),
    ("IDX_CAT", regions["IDX_CAT"], 2 * 6),
    ("IDX_FAM", regions["IDX_FAM"], 2 * len(fam_names)),
    ("IDX_CHN", regions["IDX_CHN"], 2 * len(chord_names)),
    ("IDX_CHS", regions["IDX_CHS"], 2 * len(chord_syms)),
    ("IDX_DIA", regions["IDX_DIA"], 2 * len(dia_names)),
    ("IDX_PAT", regions["IDX_PAT"], 2 * len(pat_names)),
    ("IDX_RATE", regions["IDX_RATE"], 2 * 7),
    ("IDX_MOD", regions["IDX_MOD"], 2 * 3),
    ("IDX_MEL", regions["IDX_MEL"], 2 * 7),
    ("IDX_SHP", regions["IDX_SHP"], 2 * 3),
    ("IDX_DRP", regions["IDX_DRP"], 2 * len(drp_names)),
    ("IDX_DRS", regions["IDX_DRS"], 2 * len(drs_names)),
    ("IDX_BTONE", regions["IDX_BTONE"], 2 * 4),
    ("IDX_INV", regions["IDX_INV"], 2 * 4),
    ("IDX_NUM", regions["IDX_NUM"], 64 + 2 * 8),
    ("IDX_PCS", regions["IDX_PCS"], 2 * 12),
    ("IDX_PCF", regions["IDX_PCF"], 2 * 12),
]
SPANS.sort(key=lambda s: s[1])
for (an, aat, alen), (bn, bat, blen) in zip(SPANS, SPANS[1:]):
    check(aat + alen <= bat,
          f"memory: {an} ({aat}..{aat + alen - 1}) runs into {bn} (from {bat})")

# gmem holds a copy of the note buffer, so it must have room for all of it.
gm = dict(re.findall(r'^GM_(\w+)\s*=\s*(\d+);', src, re.M))
check(int(gm["NOTES"]) >= int(gm["NAME"]) + 96,
      "gmem: the note block starts after the name block ends")
check(int(gm["NAME"]) >= int(gm["NAMELEN"]) + 1,
      "gmem: the name starts after its length")


# -- report ------------------------------------------------------------------

for f in failures:
    print("FAIL  " + f)
print(f"{len(EXPECTED_CHORDS)} chords, {len(EXPECTED_SCALES)} scales, "
      f"{len(failures)} failure{'' if len(failures) == 1 else 's'}")
sys.exit(1 if failures else 0)
