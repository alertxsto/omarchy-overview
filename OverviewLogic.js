// Shared by QML and the dependency-free geometry regression tests.
function workspaceForDigit(text, first, count) {
  var slot = "1234567890".indexOf(text);
  return text.length === 1 && slot >= 0 && slot < count ? first + slot : -1;
}

function workspaceAtPoint(x, y, width, height, gap, columns, rows, first) {
  if (x < 0 || y < 0) return -1;
  var col = Math.floor(x / (width + gap));
  var row = Math.floor(y / (height + gap));
  if (col >= columns || row >= rows) return -1;
  if (x - col * (width + gap) >= width || y - row * (height + gap) >= height) return -1;
  return first + row * columns + col;
}

function windowRect(ipc, monitor, width, height) {
  var scale = monitor.scale || 1;
  var rotated = (monitor.transform || 0) % 2 !== 0;
  var mw = (rotated ? monitor.height : monitor.width) / scale;
  var mh = (rotated ? monitor.width : monitor.height) / scale;
  var ratio = Math.min(width / Math.max(1, mw), height / Math.max(1, mh));
  var at = ipc.at || [monitor.x || 0, monitor.y || 0];
  var size = ipc.size || [0, 0];
  return {
    x: (at[0] - (monitor.x || 0)) * ratio + (width - mw * ratio) / 2,
    y: (at[1] - (monitor.y || 0)) * ratio + (height - mh * ratio) / 2,
    width: Math.max(0, size[0]) * ratio,
    height: Math.max(0, size[1]) * ratio
  };
}

function visibleOverFullscreen(ipc) {
  return !!ipc.floating && (!!ipc.allowedOverFullscreen || !!ipc.pinned);
}

function stacking(ipc, active) {
  if (ipc.fullscreen === 2) return 4;
  if (visibleOverFullscreen(ipc)) return 5;
  return ipc.floating ? 3 : (active ? 2 : 1);
}
