#!/usr/bin/env python3
"""Regenerates docs/BLOCKS.md from the JSFX itself.

Everything in that file is read out of jsfx/Starting Blocks.jsfx, so the
catalogue in the docs is the catalogue in the plugin.

    python3 tools/blocks_md.py > docs/BLOCKS.md
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = open(os.path.join(HERE, "..", "jsfx", "Starting Blocks.jsfx"), encoding="utf-8").read()


def strings(var):
    parts = re.findall(r'str(?:cpy|cat)\(#%s,\s*"((?:[^"\\]|\\.)*)"\)' % var, SRC)
    return "".join(parts).split("|")


chords = []
for m in re.finditer(r"chord_add\(cm\(([^)]*)\),\s*(\d+)\)", SRC):
    chords.append(([i for i in (int(x) for x in m.group(1).replace(" ", "").split(",")) if i >= 0],
                   int(m.group(2))))

scales = []
for m in re.finditer(r"sc_add\((\d+),\s*([^)]*)\);\s*sc_let\(([^)]*)\);", SRC):
    cnt = int(m.group(1))
    scales.append([int(x) for x in m.group(2).replace(" ", "").split(",")][:cnt])

dia = []
for m in re.finditer(r"dia_add\((\d+),\s*([^)]*)\);", SRC):
    cnt = int(m.group(1))
    dia.append([int(x) for x in m.group(2).replace(" ", "").split(",")][:cnt])

drums = [n for _, n in sorted(
    (int(a), int(b)) for a, b in re.findall(r"DRUM_NOTE\[(\d+)\]\s*=\s*(\d+)", SRC))]

names   = strings("chord_names")
syms    = strings("chord_syms")
fams    = strings("fam_names")
scnames = strings("scale_names")
rtnames = strings("root_names")
dianame = strings("dia_names")
pats    = strings("pat_names")
rates   = strings("rate_names")
mods    = strings("mod_names")
mels    = strings("mel_names")
shapes  = strings("shape_names")
drp     = strings("drp_names")
drs     = strings("drs_names")
btone   = strings("btone_names")
cats    = strings("cat_names")

# What each interval is called, for the chord table's second column.
DEGREE = {0: "1", 1: "b9", 2: "9", 3: "b3", 4: "3", 5: "11", 6: "b5", 7: "5",
          8: "#5", 9: "13", 10: "b7", 11: "7", 13: "b9", 14: "9", 15: "#9",
          16: "3", 17: "11", 18: "#11", 19: "5", 20: "b13", 21: "13", 26: "9"}

out = []
w = out.append

w("# The catalogue")
w("")
w("Every block Starting Blocks can make, and exactly what each one is.")
w("")
w("**This file is generated.** Run `python3 tools/blocks_md.py > docs/BLOCKS.md`")
w("to rebuild it; it is read straight out of `jsfx/Starting Blocks.jsfx`, so it")
w("cannot drift from what the plugin actually does.")
w("")
w("## Keys")
w("")
w(f"{len(rtnames)} roots: " + ", ".join(f"`{r}`" for r in rtnames) + ".")
w("")
w("Both spellings of every pitch class are offered, plus `Cb`, because C# major")
w("and Db major are the same seven notes written differently and the difference")
w("is what the note names come out as. These are ScaleView for REAPER's roots,")
w("unchanged.")
w("")
w("## Scales")
w("")
w("Semitones from the root. Also ScaleView's, unchanged, so the two apps agree")
w("on what a scale is.")
w("")
w("| scale | semitones | notes |")
w("| --- | --- | --- |")
for name, ivs in zip(scnames, scales):
    w(f"| {name} | {' '.join(str(i) for i in ivs)} | {len(ivs)} |")
w("")
w("## Scale degrees")
w("")
w("The degree buttons are Roman numerals, cased and marked for the triad the")
w("scale itself builds on that degree: upper case for major, lower for minor,")
w("`°` for diminished, `+` for augmented. That is read off the scale rather")
w("than assumed, so the modes and the blues scales come out right - the vii of")
w("major is `vii°`, the III of natural minor is `III`.")
w("")
w("| degree | name |")
w("| --- | --- |")
for i, dn in enumerate(strings("degree_names")[:7]):
    w(f"| {i + 1} | {dn} |")
w("")
w("Only the seven-note scales have these names. In a pentatonic or a")
w("diminished scale the degrees are simply numbered. The seventh is called a")
w("**Leading Tone** only when it really is a semitone below the tonic;")
w("otherwise it is a **Subtonic**.")
w("")
w("## Blocks")
w("")
w(", ".join(f"**{c}**" for c in cats) + ".")
w("")
w("### Chords")
w("")
w("The first family is built from the scale you picked, so it is always in key:")
w("")
w("| shape | scale degrees above the one you chose |")
w("| --- | --- |")
for name, offs in zip(dianame, dia):
    w(f"| {name} | {' '.join('+' + str(o) for o in offs)} |")
w("")
w("The rest are absolute shapes, stacked on the degree you chose whether or not")
w("they fit the key. Semitones are from the chord's root.")
w("")
for fam_id in range(1, len(fams)):
    rows = [(n, s, i) for (i, f), n, s in zip(chords, names, syms) if f == fam_id]
    if not rows:
        continue
    w(f"#### {fams[fam_id]}")
    w("")
    # Naming the intervals only makes sense for the chords that stack in
    # thirds; a quartal chord or the Tristan chord is its semitones and
    # nothing more useful.
    tertian = fam_id <= 5
    w("| symbol | chord | semitones |" + (" intervals |" if tertian else ""))
    w("| --- | --- | --- |" + (" --- |" if tertian else ""))
    for n, s, ivs in rows:
        row = f"| `{s}` | {n} | {' '.join(str(i) for i in ivs)} |"
        if tertian:
            row += " " + " ".join(DEGREE.get(i, str(i)) for i in ivs) + " |"
        w(row)
    w("")
w("Chords can be inverted (root, 1st, 2nd, 3rd) and moved by up to three")
w("octaves either way.")
w("")
w("### Arpeggios")
w("")
w("The chord from the Chord tab, one note at a time. Two ways to order it, and")
w("you pick one or the other:")
w("")
w("**Directions** lay every chord tone across the octave span out in pitch order")
w("and then walk them:")
w("")
for p in pats[:7]:
    w(f"- **{p}**")
w("")
w("`Random` is a shuffle rather than free picks, so every tone of the chord")
w("gets its turn before any of them repeats. `Converge` works inwards from the")
w("outside, `Diverge` outwards from the middle.")
w("")
w("**Fixed orders** put the lowest three voices in a set order. Anything above")
w("them - a seventh, a ninth, an eleventh, a thirteenth - follows in order, and")
w("the whole cell climbs an octave at a time:")
w("")
w(", ".join(f"`{p}`" for p in pats[7:]) + ".")
w("")
w("### Runs")
w("")
w("The same seven directions, but over the scale rather than the chord, starting")
w("on the degree you chose and running up to four octaves. A one-octave run is")
w("inclusive of the octave above, so it lands back on the note it started from.")
w("")
w("")
w("### Melody")
w("")
w("The two smallest moves a melody can make. An interval, a direction, and a")
w("shape:")
w("")
w("| interval | |")
w("| --- | --- |")
for m_ in mels:
    w(f"| {m_} | {'the step' if m_ == '2nd' else 'a leap'} |")
w("")
w("| shape | |")
w("| --- | --- |")
w("| Single | the move: two notes |")
w("| Return | there and back: three notes |")
w("| Fill | every scale note in between |")
w("")
w("All of it is diatonic: a 3rd is two scale steps, whatever that is in")
w("semitones in this key.")
w("")
w("### Bass")
w("")
w("One note of the chord, on its own, low. Inversion is ignored here, so the")
w("voices are always counted from the root: " + ", ".join(btone) + ".")
w("Up to three octaves down, repeating at the chosen rate.")
w("")
w("### Drums")
w("")
w("One piece of the kit, one pattern, one bar. Stack a kit up by dropping in")
w("several. The note numbers are General MIDI, so the blocks land on the right")
w("pads in anything that follows the map.")
w("")
w("| piece | note |")
w("| --- | --- |")
for p, n in zip(drp, drums):
    w(f"| {p} | {n} |")
w("")
POSITIONS = {
    "One Hit": "1",
    "Four on the Floor": "1, 2, 3, 4",
    "One & Three": "1, 3",
    "Two & Four": "2, 4",
    "And of Two": "the & of 2",
    "Two Step": "1, the & of 2, 4",
    "Off-beats": "the & of every beat",
    "Every 8th": "all eight eighths",
    "Every 16th": "all sixteen sixteenths",
}
w("| pattern | where the hits fall |")
w("| --- | --- |")
for s in drs:
    w(f"| {s} | {POSITIONS.get(s, '')} |")
w("")
w("These are written on a 4/4 grid. In a shorter bar the hits past the end of")
w("it are dropped rather than squeezed in.")
w("")
w("## Timing")
w("")
w("| rate | " + " | ".join(rates) + " |")
w("| --- | " + " | ".join("---" for _ in rates) + " |")
w("| quarter notes | " + " | ".join(str(2 ** i / 16) for i in range(len(rates))) + " |")
w("")
w("Each one can be " + ", ".join(m.lower() for m in mods) +
  " - a triplet is two thirds of the straight value, a dotted note one and a half.")
w("")
w("**Gate** is how much of the step the note actually holds, from 5% to 100%.")
w("**Bars** is 1, 2, 4 or 8, and a bar is however long the project's time")
w("signature says it is.")

sys.stdout.write("\n".join(out) + "\n")
