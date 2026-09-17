# The catalogue

Every block Starting Blocks can make, and exactly what each one is.

**This file is generated.** Run
`python3 tools/run_lua.py tools/blocks_md.lua > docs/BLOCKS.md` to rebuild
it. It loads `reascripts/sb_engine.lua` and reads its tables, so it cannot
drift from what the script actually does.

## Keys

18 roots: `C`, `C#`, `Db`, `D`, `D#`, `Eb`, `E`, `F`, `F#`, `Gb`, `G`, `G#`, `Ab`, `A`, `A#`, `Bb`, `B`, `Cb`.

Both spellings of every pitch class are offered, plus `Cb`, because C# major
and Db major are the same seven notes written differently and the difference
is what the note names come out as. These are ScaleView for REAPER's roots,
unchanged.

## Scales

Semitones from the root. Also ScaleView's, unchanged, so the two apps agree
on what a scale is.

| scale | semitones | notes |
| --- | --- | --- |
| Major | 0 2 4 5 7 9 11 | 7 |
| Minor | 0 2 3 5 7 8 10 | 7 |
| Harm Minor | 0 2 3 5 7 8 11 | 7 |
| Ionian | 0 2 4 5 7 9 11 | 7 |
| Dorian | 0 2 3 5 7 9 10 | 7 |
| Phrygian | 0 1 3 5 7 8 10 | 7 |
| Lydian | 0 2 4 6 7 9 11 | 7 |
| Mixolydian | 0 2 4 5 7 9 10 | 7 |
| Aeolian | 0 2 3 5 7 8 10 | 7 |
| Maj Pent | 0 2 4 7 9 | 5 |
| Min Pent | 0 3 5 7 10 | 5 |
| Maj Blues | 0 2 3 4 7 9 | 6 |
| Min Blues | 0 3 5 6 7 10 | 6 |
| Whole Tone | 0 2 4 6 8 10 | 6 |
| Dim W-H | 0 2 3 5 6 8 9 11 | 8 |
| Dim H-W | 0 1 3 4 6 7 9 10 | 8 |

## Scale degrees

The degree buttons are Roman numerals, cased and marked for the triad the
scale itself builds on that degree: upper case for major, lower for minor,
`°` for diminished, `+` for augmented. That is read off the scale rather
than assumed, so the modes and the blues scales come out right - the vii of
major is `vii°`, the III of natural minor is `III`.

| degree | name |
| --- | --- |
| 1 | Tonic |
| 2 | Supertonic |
| 3 | Mediant |
| 4 | Subdominant |
| 5 | Dominant |
| 6 | Submediant |
| 7 | Leading Tone |

Only the seven-note scales have these names. In a pentatonic or a diminished
scale the degrees are simply numbered. The seventh is called a **Leading
Tone** only when it really is a semitone below the tonic; otherwise it is a
**Subtonic**.

## Blocks

**Chord**, **Arpeggio**, **Run**, **Melody**, **Bass**, **Drums**.

### Chords

The first family is built from the scale you picked, so it is always in key:

| shape | scale degrees above the one you chose |
| --- | --- |
| Triad | +0 +2 +4 |
| 7th | +0 +2 +4 +6 |
| 9th | +0 +2 +4 +6 +8 |
| 11th | +0 +2 +4 +6 +8 +10 |
| 13th | +0 +2 +4 +6 +8 +10 +12 |
| 6th | +0 +2 +4 +5 |
| sus2 | +0 +1 +4 |
| sus4 | +0 +3 +4 |
| 5th | +0 +4 |

The rest are absolute shapes, stacked on the degree you chose whether or not
they fit the key. Semitones are from the chord's root.

#### Triads

| symbol | chord | semitones | intervals |
| --- | --- | --- | --- |
| `maj` | Major | 0 4 7 | 1 3 5 |
| `m` | Minor | 0 3 7 | 1 b3 5 |
| `dim` | Diminished | 0 3 6 | 1 b3 b5 |
| `aug` | Augmented | 0 4 8 | 1 3 #5 |
| `b5` | Flat Five | 0 4 6 | 1 3 b5 |
| `5` | Fifth (Power) | 0 7 | 1 5 |

#### 6ths & 7ths

| symbol | chord | semitones | intervals |
| --- | --- | --- | --- |
| `6` | Sixth | 0 4 7 9 | 1 3 5 13 |
| `m6` | Minor Sixth | 0 3 7 9 | 1 b3 5 13 |
| `6/9` | Six-Nine | 0 4 7 9 14 | 1 3 5 13 9 |
| `m6/9` | Minor Six-Nine | 0 3 7 9 14 | 1 b3 5 13 9 |
| `7` | Dominant Seventh | 0 4 7 10 | 1 3 5 b7 |
| `maj7` | Major Seventh | 0 4 7 11 | 1 3 5 7 |
| `m7` | Minor Seventh | 0 3 7 10 | 1 b3 5 b7 |
| `mMaj7` | Minor-Major Seventh | 0 3 7 11 | 1 b3 5 7 |
| `m7b5` | Half-Diminished Seventh | 0 3 6 10 | 1 b3 b5 b7 |
| `dim7` | Diminished Seventh | 0 3 6 9 | 1 b3 b5 13 |
| `7#5` | Augmented Seventh | 0 4 8 10 | 1 3 #5 b7 |
| `maj7#5` | Augmented Major Seventh | 0 4 8 11 | 1 3 #5 7 |
| `7b5` | Seventh Flat Five | 0 4 6 10 | 1 3 b5 b7 |
| `dimMaj7` | Diminished Major Seventh | 0 3 6 11 | 1 b3 b5 7 |
| `7/6` | Seven Six | 0 4 7 9 10 | 1 3 5 13 b7 |

#### Extended

| symbol | chord | semitones | intervals |
| --- | --- | --- | --- |
| `9` | Ninth | 0 4 7 10 14 | 1 3 5 b7 9 |
| `maj9` | Major Ninth | 0 4 7 11 14 | 1 3 5 7 9 |
| `m9` | Minor Ninth | 0 3 7 10 14 | 1 b3 5 b7 9 |
| `mMaj9` | Minor-Major Ninth | 0 3 7 11 14 | 1 b3 5 7 9 |
| `11` | Eleventh | 0 4 7 10 14 17 | 1 3 5 b7 9 11 |
| `maj11` | Major Eleventh | 0 4 7 11 14 17 | 1 3 5 7 9 11 |
| `m11` | Minor Eleventh | 0 3 7 10 14 17 | 1 b3 5 b7 9 11 |
| `13` | Thirteenth | 0 4 7 10 14 17 21 | 1 3 5 b7 9 11 13 |
| `maj13` | Major Thirteenth | 0 4 7 11 14 17 21 | 1 3 5 7 9 11 13 |
| `m13` | Minor Thirteenth | 0 3 7 10 14 17 21 | 1 b3 5 b7 9 11 13 |

#### Altered

| symbol | chord | semitones | intervals |
| --- | --- | --- | --- |
| `7b9` | Seventh Flat Nine | 0 4 7 10 13 | 1 3 5 b7 b9 |
| `7#9` | Seventh Sharp Nine | 0 4 7 10 15 | 1 3 5 b7 #9 |
| `7#11` | Seventh Sharp Eleven | 0 4 7 10 18 | 1 3 5 b7 #11 |
| `7b13` | Seventh Flat Thirteen | 0 4 7 10 20 | 1 3 5 b7 b13 |
| `7#5b9` | Seventh Sharp Five Flat Nine | 0 4 8 10 13 | 1 3 #5 b7 b9 |
| `7#5#9` | Seventh Sharp Five Sharp Nine | 0 4 8 10 15 | 1 3 #5 b7 #9 |
| `7b5b9` | Seventh Flat Five Flat Nine | 0 4 6 10 13 | 1 3 b5 b7 b9 |
| `7alt` | Altered Dominant | 0 4 8 10 13 15 | 1 3 #5 b7 b9 #9 |
| `13b9` | Thirteenth Flat Nine | 0 4 7 10 13 21 | 1 3 5 b7 b9 13 |
| `maj7#11` | Major Seventh Sharp Eleven | 0 4 7 11 18 | 1 3 5 7 #11 |
| `m9b5` | Minor Ninth Flat Five | 0 3 6 10 14 | 1 b3 b5 b7 9 |
| `9#5` | Ninth Augmented Fifth | 0 4 8 10 14 | 1 3 #5 b7 9 |
| `9b5` | Ninth Flat Fifth | 0 4 6 10 14 | 1 3 b5 b7 9 |
| `9#11` | Augmented Eleventh | 0 4 7 10 14 18 | 1 3 5 b7 9 #11 |
| `maj7#5#11` | Augmented Major Seventh Sharp Eleven | 0 4 8 11 18 | 1 3 #5 7 #11 |
| `13b9b5` | Thirteenth Flat Nine Flat Five | 0 4 6 10 13 21 | 1 3 b5 b7 b9 13 |

#### Sus & Add

| symbol | chord | semitones | intervals |
| --- | --- | --- | --- |
| `sus2` | Suspended Second | 0 2 7 | 1 9 5 |
| `sus4` | Suspended Fourth | 0 5 7 | 1 11 5 |
| `7sus4` | Seventh Suspended Fourth | 0 5 7 10 | 1 11 5 b7 |
| `9sus4` | Ninth Suspended Fourth | 0 5 7 10 14 | 1 11 5 b7 9 |
| `maj7sus4` | Major Seventh Suspended Fourth | 0 5 7 11 | 1 11 5 7 |
| `add9` | Added Ninth | 0 4 7 14 | 1 3 5 9 |
| `m(add9)` | Minor Added Ninth | 0 3 7 14 | 1 b3 5 9 |
| `add4` | Added Fourth | 0 4 5 7 | 1 3 11 5 |
| `add11` | Added Eleventh | 0 4 7 17 | 1 3 5 11 |
| `add13` | Added Thirteenth | 0 4 7 21 | 1 3 5 13 |
| `add2` | Added Second | 0 2 4 7 | 1 9 3 5 |
| `m(add2)` | Minor Added Second | 0 2 3 7 | 1 9 b3 5 |

#### Quartal

| symbol | chord | semitones |
| --- | --- | --- |
| `Q4/3` | Quartal Triad | 0 5 10 |
| `Q4/4` | Quartal Tetrad | 0 5 10 15 |
| `Q5/3` | Quintal Triad | 0 7 14 |
| `WT3` | Whole-Tone Trichord | 0 2 4 |
| `cluster` | Chromatic Cluster | 0 1 2 |
| `dia-cl` | Diatonic Cluster | 0 2 4 5 |

#### Named

| symbol | chord | semitones |
| --- | --- | --- |
| `Mystic` | Mystic (Scriabin) | 0 6 10 16 21 26 |
| `Petrushka` | Petrushka | 0 4 6 7 10 13 |
| `Tristan` | Tristan | 0 6 10 15 |
| `So What` | So What | 0 5 10 15 19 |
| `Dream` | Dream | 0 5 6 7 |
| `Vienna` | Viennese Trichord | 0 1 6 |
| `Vienna II` | Viennese Trichord II | 0 6 7 |
| `Napoleon` | Ode-to-Napoleon | 0 1 4 5 8 9 |
| `Elektra` | Elektra | 0 7 9 13 16 |
| `Farben` | Farben | 0 8 11 16 21 |
| `It+6` | Italian Sixth | 0 4 10 |
| `Fr+6` | French Sixth | 0 4 6 10 |
| `Ger+6` | German Sixth | 0 4 7 10 |

Chords can be inverted (root, 1st, 2nd, 3rd) and moved by up to three
octaves either way.

**Chop** cuts the block into segments and strikes the chord again in each
one: 1/64, 1/32, 1/16, 1/8, 1/4, 1/2 or 1/1. At 1/1 over one bar that is a
single held chord, which is what a chord was before the chop existed. Over
more than one bar it is one strike a bar.

### Arpeggios

The chord from the Chord tab, one note at a time.

**Direction** lays every chord tone across the octave span out in pitch
order and then walks them: Up, Down, Up/Down, Down/Up, Random, Converge, Diverge.

`Random` is a shuffle rather than free picks, so every tone gets its turn
before any of them repeats. `Converge` works inwards from the outside,
`Diverge` outwards from the middle.

**Repeats** is how many times the pass plays, from 1 to 16. One pass
is one time through whatever the direction produced, so an arpeggio block is
as long as the arpeggio and no longer - a triad up is three notes, a
thirteenth up is seven, and the same Repeats setting gives you one of each
rather than a bar of each.

### Runs

The same seven directions, but over the scale rather than the chord,
starting on the degree you chose and running up to four octaves. A
one-octave run is inclusive of the octave above, so it lands back on the
note it started from, and **Repeats** counts passes the same way it does for
an arpeggio.

### Melody

The two smallest moves a melody can make. An interval, a direction and a
shape:

| interval | |
| --- | --- |
| 2nd | the step |
| 3rd | a leap |
| 4th | a leap |
| 5th | a leap |
| 6th | a leap |
| 7th | a leap |
| Octave | a leap |

| shape | |
| --- | --- |
| Single | the move: two notes |
| Return | there and back: three notes |
| Fill | every scale note in between |

All of it is diatonic: a 3rd is two scale steps, whatever that is in
semitones in this key, and an octave is however many steps this scale takes
to get there - five in a pentatonic, seven in a major scale.

### Bass

One note of the chord, on its own, low. Inversion is ignored here, so the
voices are always counted from the root: Root, 3rd, 5th, 7th.
Up to three octaves down, repeating at the chosen rate.

### Drums

One piece of the kit, hit at one rate. Stack a kit up by dropping in
several. The note numbers are General MIDI, so the blocks land on the right
pads in anything that follows the map.

There are no named patterns. The patterns fall out of the rates instead: a
kick every 1/4 is four on the floor, a kick every 1/2 is one and three, and
a snare - which starts on the two - every 1/2 is the backbeat. Naming those
would be naming what the rates already say.

| piece | note | first hit | every |
| --- | --- | --- | --- |
| Kick | 36 | top of the bar | 1/16, 1/8, 1/4, 1/2, 1/1 |
| Snare | 38 | beat 2 | 1/8, 1/4, 1/2, 1/1 |
| Closed HH | 42 | top of the bar | 1/32, 1/16, 1/8, 1/4, 1/2, 1/1 |
| Open HH | 46 | top of the bar | 1/32, 1/16, 1/8, 1/4, 1/2, 1/1 |
| Crash | 49 | top of the bar | 1/16, 1/8, 1/4, 1/2, 1/1 |
| Ride | 51 | top of the bar | 1/32, 1/16, 1/8, 1/4, 1/2, 1/1 |
| Low Tom | 41 | top of the bar | one hit only |
| Mid Tom | 47 | top of the bar | one hit only |
| High Tom | 50 | top of the bar | one hit only |

1/1 is always the last rate a piece offers, and it means a single hit. The
toms are a single hit and nothing to choose until they are thought through.
A bar too short to reach a piece's first hit gets no hit at all.

**Shuffle** pushes every second hit later, from 0 to 100. At 100 it lands
two thirds of the way through the pair, which is the triplet feel a shuffle
is named after; anything less is on the way there. A piece that is only hit
once has no second hit to push.

## Timing

| rate | 1/64 | 1/32 | 1/16 | 1/8 | 1/4 | 1/2 | 1/1 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| quarter notes | 0.0625 | 0.125 | 0.25 | 0.5 | 1 | 2 | 4 |

Each one can be straight, triplet, dotted - a triplet is two thirds of the straight value, a dotted note one and a half.

**Gate** is how much of the step the note actually holds, from 5% to 100%.

Chords, bass and drums are measured in **bars** - 1, 2, 4 or 8, and a bar is
however long the project's time signature says it is. Arpeggios and runs are
measured in **repeats** instead, and a melody is however long its own notes
make it.

Everything leaves at velocity 100. Shaping a block's
dynamics is a job for the MIDI editor once it is in the project, not for a
slider on every panel here.
