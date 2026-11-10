// The picture in the README: `node ableton/window.js` redraws ableton/window.png.
// An arpeggio in E flat major.
require('./kit/test/picture.js')(__dirname, { bundle: 'StartingBlocks.js', w: 860, h: 169,
  go(d) { d.ctx.setKey(6, 1); d.ctx.setSetting('cat', 2); } });
