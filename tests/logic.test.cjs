const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const logic = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../OverviewLogic.js'), 'utf8'), logic);
const rect = value => JSON.parse(JSON.stringify(value));

test('number keys select their labeled workspace, including zero and later groups', () => {
  for (let n = 1; n <= 9; n++) assert.equal(logic.workspaceForDigit(String(n), 1, 10), n);
  assert.equal(logic.workspaceForDigit('0', 1, 10), 10);
  assert.equal(logic.workspaceForDigit('1', 11, 10), 11);
  assert.equal(logic.workspaceForDigit('0', 11, 10), 20);
  assert.equal(logic.workspaceForDigit('x', 1, 10), -1);
});

test('drop hit testing rejects gaps, outer edges and off-grid coordinates', () => {
  assert.equal(logic.workspaceAtPoint(50, 40, 100, 60, 6, 5, 2, 1), 1);
  assert.equal(logic.workspaceAtPoint(103, 40, 100, 60, 6, 5, 2, 1), -1);
  assert.equal(logic.workspaceAtPoint(20, 63, 100, 60, 6, 5, 2, 1), -1);
  assert.equal(logic.workspaceAtPoint(100, 20, 100, 60, 6, 5, 2, 1), -1);
  assert.equal(logic.workspaceAtPoint(-1, 20, 100, 60, 6, 5, 2, 1), -1);
  assert.equal(logic.workspaceAtPoint(530, 20, 100, 60, 6, 5, 2, 1), -1);
  assert.equal(logic.workspaceAtPoint(450, 100, 100, 60, 6, 5, 2, 11), 20);
});

test('window layout uses monitor-relative logical coordinates without stretching', () => {
  const monitor = { x: 1920, y: -100, width: 2560, height: 1440, scale: 2, transform: 0 };
  assert.deepEqual(rect(logic.windowRect({ at: [1930, -80], size: [630, 680] }, monitor, 320, 180)), { x: 2.5, y: 5, width: 157.5, height: 170 });
  assert.deepEqual(rect(logic.windowRect({ at: [1920, -100], size: [1280, 720], fullscreen: 2 }, monitor, 320, 180)), { x: 0, y: 0, width: 320, height: 180 });
});

test('rotated output swaps logical extents and offscreen windows clip proportionally', () => {
  const monitor = { x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 1 };
  assert.deepEqual(rect(logic.windowRect({ at: [0, 0], size: [1080, 1920] }, monitor, 108, 192)), { x: 0, y: 0, width: 108, height: 192 });
  const unrotated = { ...monitor, transform: 0 };
  assert.deepEqual(rect(logic.windowRect({ at: [-200, 0], size: [1000, 500] }, unrotated, 192, 108)), { x: -20, y: 0, width: 100, height: 50 });
});

test('fullscreen flag never replaces actual compositor geometry with a centered box', () => {
  const monitor = { x: 0, y: 0, width: 1920, height: 1080, scale: 1 };
  assert.deepEqual(rect(logic.windowRect({ at: [12, 38], size: [941, 1030], fullscreen: 1 }, monitor, 192, 108)), { x: 1.2000000000000002, y: 3.8000000000000003, width: 94.10000000000001, height: 103 });
});

test('floating dialogs allowed over fullscreen remain visible and win hit testing', () => {
  const fullscreen = logic.stacking({ fullscreen: 2, floating: true, allowedOverFullscreen: true }, true);
  assert.ok(logic.stacking({ floating: true, allowedOverFullscreen: true }, false) > fullscreen);
  assert.ok(logic.stacking({ floating: true, pinned: true }, false) > fullscreen);
  assert.ok(logic.stacking({ floating: true, allowedOverFullscreen: false }, true) < fullscreen);
  assert.equal(logic.visibleOverFullscreen({ floating: false, allowedOverFullscreen: true }), false);
  assert.equal(logic.visibleOverFullscreen({ floating: true, allowedOverFullscreen: false }), false);
  assert.equal(logic.visibleOverFullscreen({ floating: true, allowedOverFullscreen: true }), true);
});
