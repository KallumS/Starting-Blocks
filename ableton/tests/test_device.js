/* The Max for Live device, run in Node on a pretend Max and a pretend Live.
 *   node --test ableton/tests/
 * Build first: python3 ableton/kit/build.py ableton/device.json */
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { load, liveSet } = require('../kit/test/max.js');

const BUNDLE = path.join(__dirname, '..', 'StartingBlocks.js');
function device(opts) { const d = load(BUNDLE, opts); d.send('bang'); return d; }
function balanced(bytes) {
  const on = {};
  for (let i = 0; i < bytes.length; i += 3) {
    const st = bytes[i] & 0xF0, p = bytes[i + 1];
    if (st === 0x90 && bytes[i + 2] > 0) on[p] = (on[p] || 0) + 1; else on[p] = (on[p] || 0) - 1;
  }
  return Object.values(on).every((n) => n === 0);
}

test('it opens on a block for every degree of the key', () => {
  const d = device();
  const t = d.texts();
  assert.ok(t.includes('Starting Blocks — C Major'), t.join(' | '));
  assert.strictEqual(d.ctx.S.results.length, 7);
  assert.ok(t.some((s) => /^I\b/.test(s)), 'a tonic block is listed');
  for (const w of ['New Ideas', 'Play', 'Insert', 'New Clip', 'Follow Live']) assert.ok(t.includes(w), w);
});

test('a block is heard when chosen, and every note it starts it stops', () => {
  const d = device();
  d.click(d.ctx.S.results[1].title);
  d.run(20000);
  const bytes = d.midi();
  assert.ok(bytes.length >= 9, 'notes were sent');
  assert.ok(balanced(bytes));
});

test('Insert puts the block in a new clip on this track', () => {
  const d = device();
  d.click('Insert');
  const clip = d.set.slots[0].kids.clip;
  assert.ok(clip, 'a clip was made in the first free slot');
  const expect = d.ctx.S.results[0].parts[0].notes;
  assert.strictEqual(clip.notes.length, expect.length);
  assert.deepStrictEqual(clip.notes.map((n) => n.pitch).sort(), expect.map((n) => n.pitch).sort());
  assert.ok(d.texts().includes('Added a clip in scene 1.'));
});

test('a full track says so instead of overwriting', () => {
  const d = device({ live: { scenes: 1 } });
  d.click('Insert');
  d.click('Insert');
  assert.ok(d.texts().some((s) => s.startsWith('Every clip slot on this track is full')));
});

test('This Clip replaces the notes of the clip being edited', () => {
  const set = liveSet();
  const c = set.clip(8, [{ pitch: 40, start_time: 0, duration: 1, velocity: 90 }]);
  set.open(c);
  const d = device({ set });
  d.click('New Clip'); d.click('Arrangement');
  assert.ok(d.texts().includes('This Clip'));
  d.click('Insert');
  assert.ok(!c.notes.some((n) => n.pitch === 40), 'the old note went');
  assert.strictEqual(c.notes.length, d.ctx.S.results[0].parts[0].notes.length);
});

test('Arrangement puts the block at the insert marker', () => {
  const set = liveSet({ song: { current_song_time: 8 } });
  const d = device({ set });
  d.click('New Clip');
  d.click('Insert');
  assert.strictEqual(set.arrangement.length, 1);
  assert.strictEqual(set.arrangement[0].props.start_time, 8);
  assert.ok(set.arrangement[0].notes.length > 0);
});

test('it follows Live’s scale, and spells the key the way the key is written', () => {
  const d = device({ live: { song: { scale_name: 'Dorian', root_note: 2 } } });
  assert.deepStrictEqual(JSON.parse(JSON.stringify(d.ctx.S.key)), { root: 4, scale: 5 });
  const e = device({ live: { song: { scale_name: 'Minor', root_note: 8 } } });
  assert.ok(e.texts().includes('Starting Blocks — G# Minor (Natural)'));
  const f = device({ live: { song: { scale_name: 'Major', root_note: 8 } } });
  assert.ok(f.texts().includes('Starting Blocks — Ab Major'));
});

test('a setting changed is regenerated, saved, and comes back with the set', () => {
  const d = device();
  const before = d.ctx.S.settings.find((s) => s.id === 'cat');
  d.click(before.names[before.index - 1]);
  const after = d.ctx.S.settings.find((s) => s.id === 'cat');
  assert.notStrictEqual(after.index, before.index);
  const saved = d.saved();
  assert.ok(saved && saved.st, 'the state went to [pattr]');
  const e = device();
  e.send('restore', JSON.stringify(saved));
  assert.strictEqual(e.ctx.S.settings.find((s) => s.id === 'cat').index, after.index);
  assert.strictEqual(e.ctx.S.results[0].title, d.ctx.S.results[0].title);
});

test('state restored before Live is ready waits for it', () => {
  const d = device();
  d.click('Follow Live');
  const saved = d.saved();
  const e = load(BUNDLE);
  e.send('restore', JSON.stringify(saved));
  e.send('bang');
  assert.strictEqual(e.ctx.S.follow, false);
});

test('every setting can be stepped through without an error', () => {
  const d = device();
  for (let pass = 0; pass < 3; pass++) {
    for (const s of d.ctx.S.settings.slice()) {
      for (let i = 1; i <= s.names.length; i++) d.ctx.setSetting(s.id, i);
      assert.ok(!d.ctx.S.warn, s.id + ': ' + d.ctx.S.status);
    }
  }
  assert.ok(d.ctx.S.results.length > 0);
});
