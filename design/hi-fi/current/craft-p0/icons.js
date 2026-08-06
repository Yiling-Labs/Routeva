/**
 * Routeva craft-p0 shared icons
 * Paths: Lucide Static v0.469.0 (ISC) — https://lucide.dev
 * Style: Soft Glass chrome — stroke 1.6 / CTA 2, round caps, currentColor
 * SwiftUI handoff: names map to SF Symbols (see SF map in comments)
 *
 * Requires: window.React (load after React UMD)
 * Usage: const { IconHelp, IconClose, SIZE, STROKE } = window.RoutevaIcons;
 */
(function (global) {
  'use strict';
  var React = global.React;
  if (!React) {
    console.error('[RoutevaIcons] React must load before icons.js');
    return;
  }
  var h = React.createElement;

  var STROKE = { chrome: 1.6, cta: 2, dense: 1.6 };
  var SIZE = {
    chrome: 18,
    button: 16,
    dense: 14,
    chevron: 11,
    cta: 22,
    import: 22,
    mini: 14,
  };

  function svgProps(opts) {
    opts = opts || {};
    var size = opts.size != null ? opts.size : SIZE.chrome;
    var stroke = opts.stroke != null ? opts.stroke : STROKE.chrome;
    var color = opts.color;
    var style = opts.style || null;
    if (color) {
      style = Object.assign({}, style || {}, { color: color });
    }
    return {
      width: size,
      height: size,
      viewBox: '0 0 24 24',
      fill: 'none',
      stroke: 'currentColor',
      strokeWidth: stroke,
      strokeLinecap: 'round',
      strokeLinejoin: 'round',
      'aria-hidden': true,
      style: style,
    };
  }

  function Icon(paths, opts) {
    return h('svg', svgProps(opts), paths);
  }

  function path(d, extra) {
    return h('path', Object.assign({ d: d }, extra || {}));
  }
  function circle(cx, cy, r, extra) {
    return h('circle', Object.assign({ cx: cx, cy: cy, r: r }, extra || {}));
  }
  function line(x1, y1, x2, y2, extra) {
    return h('line', Object.assign({ x1: x1, y1: y1, x2: x2, y2: y2 }, extra || {}));
  }
  function rect(x, y, w, ht, extra) {
    return h('rect', Object.assign({ x: x, y: y, width: w, height: ht }, extra || {}));
  }

  /* —— Lucide paths —— */

  // circle-help → SF questionmark.circle
  function IconHelp(props) {
    return Icon([
      circle(12, 12, 10),
      path('M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3'),
      path('M12 17h.01'),
    ], props);
  }

  // layers → SF square.stack (subscriptions stack)
  function IconSubscriptions(props) {
    return Icon([
      path('M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z'),
      path('M2 12a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 12'),
      path('M2 17a1 1 0 0 0 .58.91l8.6 3.91a2 2 0 0 0 1.65 0l8.58-3.9A1 1 0 0 0 22 17'),
    ], props);
  }

  // settings → SF gearshape
  function IconSettings(props) {
    return Icon([
      path('M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z'),
      circle(12, 12, 3),
    ], props);
  }
  var IconGear = IconSettings;

  // x → SF xmark
  function IconClose(props) {
    var p = Object.assign({ size: SIZE.dense, stroke: STROKE.cta }, props || {});
    return Icon([
      path('M18 6 6 18'),
      path('m6 6 12 12'),
    ], p);
  }

  // chevron-left → SF chevron.left
  function IconBack(props) {
    var p = Object.assign({ size: SIZE.button, stroke: STROKE.cta }, props || {});
    return Icon([path('m15 18-6-6 6-6')], p);
  }

  // chevron-right → SF chevron.right
  function IconChevron(props) {
    var p = Object.assign({ size: SIZE.chevron, stroke: STROKE.cta }, props || {});
    return Icon([path('m9 18 6-6-6-6')], p);
  }

  // chevron-up / rotate for down — capsule affordance
  function IconChevronDir(props) {
    props = props || {};
    var dir = props.dir || 'up';
    var p = Object.assign({ size: 16, stroke: STROKE.cta }, props);
    delete p.dir;
    var style = Object.assign({}, p.style || {});
    if (dir === 'down') style.transform = 'rotate(180deg)';
    else if (dir === 'left') style.transform = 'rotate(-90deg)';
    else if (dir === 'right') style.transform = 'rotate(90deg)';
    p.style = style;
    return Icon([path('m18 15-6-6-6 6')], p);
  }

  // check → SF checkmark
  function IconCheck(props) {
    var p = Object.assign({ size: 17, stroke: STROKE.cta }, props || {});
    return Icon([path('M20 6 9 17l-5-5')], p);
  }

  // power → SF power
  function IconPower(props) {
    var p = Object.assign({ size: SIZE.cta, stroke: STROKE.cta }, props || {});
    return Icon([
      path('M12 2v10'),
      path('M18.4 6.6a9 9 0 1 1-12.77.04'),
    ], p);
  }

  // refresh-cw → SF arrow.clockwise
  function IconRefresh(props) {
    var p = Object.assign({ size: SIZE.button, stroke: STROKE.cta }, props || {});
    return Icon([
      path('M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8'),
      path('M21 3v5h-5'),
      path('M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16'),
      path('M8 16H3v5'),
    ], p);
  }

  // send → SF paperplane
  function IconSend(props) {
    var p = Object.assign({ size: SIZE.button, stroke: STROKE.chrome }, props || {});
    return Icon([
      path('M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z'),
      path('m21.854 2.147-10.94 10.939'),
    ], p);
  }

  // shield → SF shield
  function IconShield(props) {
    var p = Object.assign({ size: SIZE.dense, stroke: STROKE.chrome }, props || {});
    return Icon([
      path('M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z'),
    ], p);
  }

  // qr-code → SF qrcode
  function IconQr(props) {
    var p = Object.assign({ size: SIZE.import, stroke: STROKE.chrome }, props || {});
    return Icon([
      rect(3, 3, 5, 5, { rx: 1 }),
      rect(16, 3, 5, 5, { rx: 1 }),
      rect(3, 16, 5, 5, { rx: 1 }),
      path('M21 16h-3a2 2 0 0 0-2 2v3'),
      path('M21 21v.01'),
      path('M12 7v3a2 2 0 0 1-2 2H7'),
      path('M3 12h.01'),
      path('M12 3h.01'),
      path('M12 16v.01'),
      path('M16 12h1'),
      path('M21 12v.01'),
      path('M12 21v-1'),
    ], p);
  }

  // file → SF doc
  function IconFile(props) {
    var p = Object.assign({ size: SIZE.import, stroke: STROKE.chrome }, props || {});
    return Icon([
      path('M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z'),
      path('M14 2v4a2 2 0 0 0 2 2h4'),
    ], p);
  }

  // clipboard-paste → SF doc.on.clipboard
  function IconClipboard(props) {
    var p = Object.assign({ size: SIZE.import, stroke: STROKE.chrome }, props || {});
    return Icon([
      path('M15 2H9a1 1 0 0 0-1 1v2c0 .6.4 1 1 1h6c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1Z'),
      path('M8 4H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2M16 4h2a2 2 0 0 1 2 2v2M11 14h10'),
      path('m17 10 4 4-4 4'),
    ], p);
  }

  // map-pin → SF mappin
  function IconMapPin(props) {
    var p = Object.assign({ size: SIZE.button, stroke: STROKE.chrome }, props || {});
    return Icon([
      path('M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0'),
      circle(12, 10, 3),
    ], p);
  }

  // plus → SF plus
  function IconPlus(props) {
    var p = Object.assign({ size: 24, stroke: STROKE.cta }, props || {});
    return Icon([
      path('M5 12h14'),
      path('M12 5v14'),
    ], p);
  }

  // circle-alert → SF exclamationmark.circle
  function IconAlert(props) {
    var p = Object.assign({ size: SIZE.import, stroke: STROKE.chrome }, props || {});
    return Icon([
      circle(12, 12, 10),
      line(12, 8, 12, 12),
      line(12, 16, 12.01, 16),
    ], p);
  }

  // message-circle → SF bubble.left (Ask Help only — not main Help chrome)
  function IconMessage(props) {
    var p = Object.assign({ size: SIZE.dense, stroke: STROKE.chrome }, props || {});
    return Icon([
      path('M7.9 20A9 9 0 1 0 4 16.1L2 22Z'),
    ], p);
  }

  // list → SF list.bullet (empty overrides)
  function IconList(props) {
    var p = Object.assign({ size: 24, stroke: STROKE.chrome }, props || {});
    return Icon([
      path('M3 12h.01'),
      path('M3 18h.01'),
      path('M3 6h.01'),
      path('M8 12h13'),
      path('M8 18h13'),
      path('M8 6h13'),
    ], p);
  }

  // arrow-down / arrow-up → SF arrow.down / arrow.up
  function IconArrowDown(props) {
    var p = Object.assign({ size: 10, stroke: 1.5 }, props || {});
    return Icon([
      path('M12 5v14'),
      path('m19 12-7 7-7-7'),
    ], p);
  }
  function IconArrowUp(props) {
    var p = Object.assign({ size: 10, stroke: 1.5 }, props || {});
    return Icon([
      path('m5 12 7-7 7 7'),
      path('M12 19V5'),
    ], p);
  }

  // ellipsis / more-horizontal → SF ellipsis
  function IconMore(props) {
    var p = Object.assign({ size: SIZE.chrome, stroke: STROKE.chrome }, props || {});
    return Icon([
      circle(12, 12, 1),
      circle(19, 12, 1),
      circle(5, 12, 1),
    ], p);
  }

  /** Alias: Help mark same as Help (unified glyph) */
  var IconHelpMark = IconHelp;

  global.RoutevaIcons = {
    STROKE: STROKE,
    SIZE: SIZE,
    IconHelp: IconHelp,
    IconHelpMark: IconHelpMark,
    IconSubscriptions: IconSubscriptions,
    IconSettings: IconSettings,
    IconGear: IconGear,
    IconClose: IconClose,
    IconBack: IconBack,
    IconChevron: IconChevron,
    IconChevronDir: IconChevronDir,
    IconCheck: IconCheck,
    IconPower: IconPower,
    IconRefresh: IconRefresh,
    IconSend: IconSend,
    IconShield: IconShield,
    IconQr: IconQr,
    IconFile: IconFile,
    IconClipboard: IconClipboard,
    IconMapPin: IconMapPin,
    IconPlus: IconPlus,
    IconAlert: IconAlert,
    IconMessage: IconMessage,
    IconList: IconList,
    IconArrowDown: IconArrowDown,
    IconArrowUp: IconArrowUp,
    IconMore: IconMore,
  };
})(typeof window !== 'undefined' ? window : globalThis);
