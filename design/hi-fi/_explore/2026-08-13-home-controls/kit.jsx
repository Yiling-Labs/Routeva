/* Frozen Home shell + the four controls under exploration */
const C = {
  font: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "PingFang SC", system-ui, sans-serif',
  fieldTop: '#2e343a',
  fieldBot: '#0b0e11',
  greenTop: '#4d7a6c',
  greenBot: '#1f3f38',
  W: 393,
  H: 852,
  quiet: 'rgba(255,255,255,0.38)',
  muted: 'rgba(255,255,255,0.58)',
  secondary: 'rgba(255,255,255,0.72)',
  primary: 'rgba(255,255,255,0.96)',
};

const NODES = [
  { id: 'za', cc: 'za', name: 'JNB-Edge-02', proto: 'SS', ms: 186 },
  { id: 'us', cc: 'us', name: 'LAX-08', proto: 'VMess', ms: 92 },
  { id: 'hk', cc: 'hk', name: 'HKG-01', proto: 'VMess', ms: 48 },
  { id: 'tw', cc: 'cn', name: '🇨🇳 台湾A01 | IEPL | x2', proto: 'VLESS', ms: 64 },
  { id: 'de', cc: 'de', name: 'FRA-04', proto: 'Hy2', ms: 210 },
  { id: 'gb', cc: 'gb', name: 'LON-05', proto: 'SS', ms: 118 },
];
const FOCUS = 3;
const NODE = NODES[FOCUS];

function flagSrc(cc) {
  return `https://flagcdn.com/w160/${cc === 'tw' ? 'cn' : cc}.png`;
}

function glass(light, extra) {
  return Object.assign(
    {
      background: light
        ? 'linear-gradient(160deg, rgba(255,255,255,0.28), rgba(255,255,255,0.1))'
        : 'linear-gradient(160deg, rgba(255,255,255,0.16), rgba(255,255,255,0.06))',
      border: light
        ? '0.5px solid rgba(255,255,255,0.28)'
        : '0.5px solid rgba(255,255,255,0.14)',
      boxShadow: light
        ? 'inset 0 1px 0 rgba(255,255,255,0.35), 0 6px 18px rgba(0,0,0,0.12)'
        : 'inset 0 1px 0 rgba(255,255,255,0.2), 0 8px 22px rgba(0,0,0,0.28)',
      backdropFilter: 'blur(18px) saturate(1.2)',
      WebkitBackdropFilter: 'blur(18px) saturate(1.2)',
    },
    extra || {}
  );
}

function Phone({ connected, label, children }) {
  const bg = connected
    ? `linear-gradient(180deg, ${C.greenTop}, ${C.greenBot})`
    : `linear-gradient(180deg, ${C.fieldTop}, ${C.fieldBot})`;
  return (
    <div
      data-screen-label={label}
      style={{
        width: C.W,
        height: C.H,
        borderRadius: 48,
        overflow: 'hidden',
        position: 'relative',
        background: bg,
        boxShadow: '0 28px 70px rgba(0,0,0,0.38), 0 0 0 1px rgba(255,255,255,0.06)',
        fontFamily: C.font,
        color: C.primary,
        userSelect: 'none',
      }}
    >
      <div
        aria-hidden
        style={{
          position: 'absolute',
          inset: 0,
          opacity: connected ? 0.07 : 0.1,
          pointerEvents: 'none',
          backgroundImage: `url("data:image/svg+xml,${encodeURIComponent(
            `<svg xmlns='http://www.w3.org/2000/svg' width='400' height='300'><g fill='none' stroke='#fff' stroke-width='1' opacity='0.45'><ellipse cx='200' cy='148' rx='158' ry='88'/><path d='M42 148 Q100 78 200 98 T358 138'/></g></svg>`
          )}")`,
          backgroundSize: '130% auto',
          backgroundPosition: 'center 42%',
        }}
      />
      <div
        aria-hidden
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: '48%',
          backgroundImage: 'radial-gradient(circle, currentColor 0.85px, transparent 1.05px)',
          backgroundSize: '4.5px 4.5px',
          color: connected ? 'rgba(0,0,0,0.35)' : 'rgba(255,255,255,0.55)',
          opacity: 0.18,
          WebkitMaskImage: 'linear-gradient(180deg, transparent, #000 48%)',
          pointerEvents: 'none',
        }}
      />
      <div
        style={{
          height: 54,
          padding: '14px 28px 0',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          position: 'relative',
          zIndex: 8,
          fontSize: 15,
          fontWeight: 600,
        }}
      >
        <span>9:41</span>
        <span style={{ fontSize: 12, opacity: 0.92 }}>●●●●  Wi‑Fi  100%</span>
      </div>
      <div style={{ position: 'relative', zIndex: 5, height: C.H - 54 - 18 }}>{children}</div>
      <div
        style={{
          position: 'absolute',
          bottom: 8,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 134,
          height: 5,
          borderRadius: 3,
          background: 'rgba(255,255,255,0.35)',
          zIndex: 9,
        }}
      />
    </div>
  );
}

function FrozenCoverFlow() {
  return (
    <div
      style={{
        position: 'relative',
        height: 118,
        width: '100%',
        WebkitMaskImage:
          'linear-gradient(90deg, transparent 0%, #000 10%, #000 90%, transparent 100%)',
      }}
    >
      {NODES.map((n, i) => {
        const d = i - FOCUS;
        const ad = Math.abs(d);
        const sc = ad < 0.5 ? 1.26 : ad < 1.5 ? 0.88 : ad < 2.5 ? 0.76 : 0.66;
        const op = ad < 0.5 ? 1 : ad < 1.5 ? 0.8 : ad < 2.5 ? 0.5 : 0.3;
        return (
          <div
            key={n.id}
            style={{
              position: 'absolute',
              left: '50%',
              top: '50%',
              width: 56,
              height: 56,
              transform: `translate(-50%, -50%) translate(${d * 72}px, ${Math.min(18, ad * ad * 2)}px) scale(${sc})`,
              opacity: op,
              zIndex: 30 - Math.round(ad * 6),
              borderRadius: '50%',
              overflow: 'hidden',
              border: ad < 0.45 ? '1.5px solid rgba(255,255,255,0.32)' : '1px solid rgba(255,255,255,0.16)',
              boxShadow: '0 8px 20px rgba(0,0,0,0.3)',
            }}
          >
            <img src={flagSrc(n.cc)} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            {ad < 0.45 && (
              <div
                style={{
                  position: 'absolute',
                  left: '50%',
                  bottom: 4,
                  transform: 'translateX(-50%)',
                  fontSize: 9,
                  fontWeight: 700,
                  color: 'oklch(0.82 0.08 155)',
                  background: 'rgba(12,16,18,0.48)',
                  borderRadius: 999,
                  padding: '2px 6px',
                  border: '0.5px solid rgba(255,255,255,0.14)',
                }}
              >
                {n.ms}ms
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function FrozenStats() {
  return (
    <div style={{ textAlign: 'center', height: 112, paddingTop: 8 }}>
      <div style={{ fontSize: 40, fontWeight: 300, letterSpacing: '-0.02em', fontVariantNumeric: 'tabular-nums' }}>
        00:45:29
      </div>
      <div style={{ marginTop: 10, display: 'flex', justifyContent: 'center', gap: 18, fontSize: 12, fontWeight: 500, color: 'rgba(255,255,255,0.78)', fontVariantNumeric: 'tabular-nums' }}>
        <span>↓ 48.2 MB</span>
        <span>↑ 6.1 MB</span>
      </div>
    </div>
  );
}

function FrozenStatus({ connected, title }) {
  return (
    <div
      style={{
        fontSize: 30,
        fontWeight: 700,
        letterSpacing: '-0.028em',
        textAlign: 'center',
        lineHeight: 1.12,
      }}
    >
      {title || (connected ? 'Connected' : 'Not Connected')}
    </div>
  );
}

function IconBtn({ children, light, size = 40, mark }) {
  return (
    <div
      data-ctrl={mark}
      style={Object.assign(
        {
          width: size,
          height: size,
          borderRadius: 999,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: 'rgba(255,255,255,0.92)',
          flexShrink: 0,
        },
        glass(light)
      )}
    >
      {children}
    </div>
  );
}

function ChromeLeft({ light }) {
  const Sub = (window.RoutevaIcons || {}).IconSubscriptions;
  return (
    <IconBtn light={light} mark="subs-frozen">
      {Sub ? <Sub size={18} /> : '☰'}
    </IconBtn>
  );
}

function SettingsOrb({ light, size = 40 }) {
  const Gear = (window.RoutevaIcons || {}).IconGear;
  return (
    <IconBtn light={light} size={size} mark="settings">
      {Gear ? <Gear size={size > 42 ? 20 : 18} /> : '⚙'}
    </IconBtn>
  );
}

function SettingsChip({ light }) {
  const Gear = (window.RoutevaIcons || {}).IconGear;
  return (
    <div
      data-ctrl="settings"
      style={Object.assign(
        {
          height: 40,
          padding: '0 14px',
          borderRadius: 999,
          display: 'inline-flex',
          alignItems: 'center',
          gap: 7,
          color: 'rgba(255,255,255,0.92)',
          fontSize: 13,
          fontWeight: 600,
        },
        glass(light)
      )}
    >
      {Gear ? <Gear size={16} /> : '⚙'}
      Settings
    </div>
  );
}

function LocationCaption() {
  return (
    <div
      data-ctrl="location"
      style={{
        display: 'flex',
        justifyContent: 'center',
        padding: '8px 28px 0',
      }}
    >
      <div
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 5,
          maxWidth: 300,
          minWidth: 0,
          fontSize: 16,
          fontWeight: 600,
          color: 'rgba(255,255,255,0.88)',
        }}
      >
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', minWidth: 0 }}>
          {NODE.name}
        </span>
        <span style={{ color: C.quiet, fontSize: 11, fontWeight: 500, flexShrink: 0 }}>· {NODE.proto}</span>
        <span style={{ color: C.quiet, fontSize: 11, flexShrink: 0 }}>›</span>
      </div>
    </div>
  );
}

function LocationPill({ light }) {
  return (
    <div
      data-ctrl="location"
      style={Object.assign(
        {
          display: 'inline-flex',
          alignItems: 'center',
          gap: 7,
          maxWidth: 280,
          padding: '10px 16px',
          borderRadius: 999,
          fontSize: 13,
          fontWeight: 600,
        },
        glass(light)
      )}
    >
      <img src={flagSrc(NODE.cc)} alt="" style={{ width: 18, height: 18, borderRadius: '50%', objectFit: 'cover' }} />
      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', minWidth: 0 }}>{NODE.name}</span>
      <span style={{ color: C.quiet, fontSize: 11, flexShrink: 0 }}>· {NODE.proto}</span>
      <span style={{ color: C.quiet, fontSize: 10 }}>›</span>
    </div>
  );
}

function LocationOrb({ light }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }} data-ctrl="location">
      <div
        style={Object.assign(
          {
            width: 44,
            height: 44,
            borderRadius: 999,
            overflow: 'hidden',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          },
          glass(light)
        )}
      >
        <img src={flagSrc(NODE.cc)} alt="" style={{ width: 28, height: 28, borderRadius: '50%', objectFit: 'cover' }} />
      </div>
      <span style={{ fontSize: 11, fontWeight: 600, color: C.muted, maxWidth: 72, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        Location
      </span>
    </div>
  );
}

function displayNodeName(name) {
  // Bar already shows a circular flag — drop a leading regional emoji.
  return String(name || '').replace(/^(?:\uD83C[\uDDE6-\uDDFF]){2}\s*/g, '');
}

/** Green-field only: Location | Mode as one secondary cluster. */
function SplitBar({ light }) {
  return (
    <div
      data-ctrl="location-mode"
      style={{
        display: 'inline-flex',
        alignItems: 'stretch',
        justifyContent: 'center',
        margin: '0 auto',
        maxWidth: 'min(320px, calc(100% - 48px))',
        width: 'auto',
        minHeight: 44,
        borderRadius: 999,
        overflow: 'hidden',
        ...glass(!!light),
      }}
    >
      <div
        data-ctrl="location"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 7,
          padding: '10px 12px 10px 14px',
          minWidth: 0,
          flex: '1 1 auto',
          fontSize: 13,
          fontWeight: 600,
        }}
      >
        <img
          src={flagSrc(NODE.cc)}
          alt=""
          style={{ width: 18, height: 18, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }}
        />
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', minWidth: 0 }}>
          {displayNodeName(NODE.name)}
        </span>
        <span style={{ color: C.quiet, flexShrink: 0, fontSize: 11 }}>›</span>
      </div>
      <div
        aria-hidden
        style={{ width: 1, margin: '10px 0', background: 'rgba(255,255,255,0.16)', flexShrink: 0 }}
      />
      <div
        data-ctrl="mode"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 5,
          padding: '10px 16px 10px 12px',
          flex: '0 0 auto',
          fontSize: 13,
          fontWeight: 600,
          color: C.secondary,
        }}
      >
        <span style={{ color: C.quiet }}>Mode</span>
        Smart
        <span style={{ color: C.quiet, fontSize: 10 }}>›</span>
      </div>
    </div>
  );
}

function LocationCaptionHit() {
  return (
    <div
      data-ctrl="location"
      style={{
        display: 'flex',
        justifyContent: 'center',
        padding: '10px 28px 4px',
        minHeight: 44,
        boxSizing: 'content-box',
      }}
    >
      <div
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 5,
          maxWidth: 300,
          minWidth: 0,
          fontSize: 16,
          fontWeight: 600,
          color: 'rgba(255,255,255,0.88)',
        }}
      >
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', minWidth: 0 }}>
          {NODE.name}
        </span>
        <span style={{ color: C.quiet, fontSize: 11, fontWeight: 500, flexShrink: 0 }}>· {NODE.proto}</span>
        <span style={{ color: C.quiet, fontSize: 11, flexShrink: 0 }}>›</span>
      </div>
    </div>
  );
}

function ModeText() {
  return (
    <div
      data-ctrl="mode"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 5,
        fontSize: 12,
        fontWeight: 600,
        color: C.secondary,
        padding: '8px 12px',
      }}
    >
      <span style={{ color: C.quiet }}>Mode</span>
      Smart
      <span style={{ fontSize: 9, color: C.quiet }}>›</span>
    </div>
  );
}

function ModeChip({ light }) {
  return (
    <div
      data-ctrl="mode"
      style={Object.assign(
        {
          display: 'inline-flex',
          alignItems: 'center',
          gap: 6,
          padding: '10px 16px',
          borderRadius: 999,
          fontSize: 13,
          fontWeight: 600,
          color: C.secondary,
        },
        glass(light)
      )}
    >
      <span style={{ color: C.quiet, fontSize: 12 }}>Mode</span>
      Smart
      <span style={{ fontSize: 10, color: C.quiet }}>›</span>
    </div>
  );
}

function ModeOrb({ light }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }} data-ctrl="mode">
      <IconBtn light={light} size={44} mark="mode">
        <span style={{ fontSize: 11, fontWeight: 800, letterSpacing: '0.04em' }}>S</span>
      </IconBtn>
      <span style={{ fontSize: 11, fontWeight: 600, color: C.muted }}>Smart ›</span>
    </div>
  );
}

function ConnectStage({ connected, scale = 0.92, jewel }) {
  const TRACK_W = (jewel ? 72 : 80) * scale;
  const TRACK_H = (jewel ? 188 : 204) * scale;
  const THUMB_H = (jewel ? 96 : 104) * scale;
  const PAD = 7 * scale;
  const INSET = jewel ? 4 * scale : 5 * scale;
  const THUMB_W = TRACK_W - INSET * 2;
  const Y = connected ? TRACK_H - THUMB_H - PAD : PAD;
  const STAGE_W = 260 * scale;
  const STAGE_H = 292 * scale;
  const trackLeft = (STAGE_W - TRACK_W) / 2;
  const trackTop = Math.round((STAGE_H - TRACK_H) * 0.42);
  const isOn = !!connected;
  const Power = (window.RoutevaIcons || {}).IconPower;
  const trackBg = isOn
    ? 'linear-gradient(180deg, rgba(12,36,28,0.5), rgba(6,20,16,0.78))'
    : jewel
      ? 'linear-gradient(180deg, rgba(255,255,255,0.14), rgba(6,8,10,0.55) 60%, rgba(0,0,0,0.62))'
      : 'linear-gradient(180deg, rgba(255,255,255,0.12), rgba(8,10,12,0.42) 55%, rgba(0,0,0,0.48))';
  const thumbBg = isOn
    ? 'linear-gradient(165deg, #b6f5d6 0%, #6ed4a6 38%, #3fb887 72%, #2a9a6c 100%)'
    : jewel
      ? 'linear-gradient(165deg, #5a626c 0%, #2c333b 40%, #14181c 100%)'
      : 'linear-gradient(165deg, #4a525a 0%, #2a3138 42%, #1a1f24 100%)';

  return (
    <div data-ctrl="connect" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ position: 'relative', width: STAGE_W, height: STAGE_H }}>
        {isOn && (
          <div
            aria-hidden
            style={{
              position: 'absolute',
              left: '50%',
              bottom: STAGE_H * 0.1,
              width: 150 * scale,
              height: 150 * scale,
              marginLeft: -75 * scale,
              borderRadius: '50%',
              boxShadow: '0 0 0 20px rgba(110,212,166,0.06), 0 0 0 40px rgba(110,212,166,0.04)',
              pointerEvents: 'none',
            }}
          />
        )}
        <div
          style={{
            position: 'absolute',
            left: trackLeft,
            top: trackTop,
            width: TRACK_W,
            height: TRACK_H,
            borderRadius: 999,
            background: trackBg,
            boxShadow: isOn
              ? 'inset 0 2px 18px rgba(0,0,0,0.42), 0 0 0 1px rgba(120,255,190,0.16), 0 20px 48px rgba(0,0,0,0.18)'
              : 'inset 0 2px 20px rgba(0,0,0,0.58), 0 0 0 1px rgba(255,255,255,0.1), 0 20px 48px rgba(0,0,0,0.34)',
            backdropFilter: 'blur(16px)',
          }}
        >
          {!isOn && (
            <div style={{ position: 'absolute', bottom: 12 * scale, left: 0, right: 0, textAlign: 'center', opacity: 0.42, fontSize: 10 * scale, fontWeight: 800, letterSpacing: '0.16em', color: 'rgba(255,255,255,0.55)' }}>
              SWIPE
              <div style={{ fontSize: 12 * scale, letterSpacing: 0 }}>↓</div>
            </div>
          )}
          {isOn && (
            <div style={{ position: 'absolute', top: 12 * scale, left: 0, right: 0, textAlign: 'center', opacity: 0.42, fontSize: 10 * scale, fontWeight: 800, letterSpacing: '0.16em', color: 'rgba(200,255,230,0.7)' }}>
              ↑
              <div>SWIPE</div>
            </div>
          )}
          <div
            style={{
              position: 'absolute',
              left: INSET,
              top: Y,
              width: THUMB_W,
              height: THUMB_H,
              borderRadius: 999,
              background: thumbBg,
              boxShadow: isOn
                ? '0 14px 36px rgba(30,190,120,0.42), inset 0 1.5px 0 rgba(255,255,255,0.62)'
                : '0 14px 34px rgba(0,0,0,0.48), inset 0 1.5px 0 rgba(255,255,255,0.28)',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 7 * scale,
              color: isOn ? 'rgba(6,28,20,0.92)' : 'rgba(255,255,255,0.94)',
            }}
          >
            <div
              style={{
                position: 'absolute',
                top: 13 * scale,
                width: 7 * scale,
                height: 7 * scale,
                borderRadius: '50%',
                background: isOn ? 'rgba(50,255,130,0.95)' : 'rgba(28,36,32,0.95)',
                boxShadow: isOn ? '0 0 12px rgba(50,255,130,0.7)' : 'none',
              }}
            />
            <span style={{ fontSize: 12 * scale, fontWeight: 800, letterSpacing: '0.12em', marginTop: 8 * scale }}>
              {isOn ? 'STOP' : 'START'}
            </span>
            {Power ? <Power size={22 * scale} stroke={2} color="currentColor" /> : <span>⏻</span>}
          </div>
        </div>
      </div>
      <div style={{ fontSize: 13, fontWeight: 500, color: C.muted, marginTop: -4 }}>
        {isOn ? 'Swipe up to stop' : 'Swipe down to connect'}
      </div>
    </div>
  );
}

function ChromeRow({ light, settings }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 22px 0', height: 48 }}>
      <ChromeLeft light={light} />
      {settings}
    </div>
  );
}

function HomeFrame({ connected, settings, locationIdle, locationOn, mode, connect, statusTitle }) {
  return (
    <Phone connected={connected} label={connected ? 'connected' : 'idle'}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <ChromeRow light={connected} settings={settings} />
        <div style={{ paddingTop: 36 }}>
          {connected ? <FrozenStats /> : <FrozenCoverFlow />}
          {!connected && locationIdle}
        </div>
        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            gap: 10,
            minHeight: 0,
          }}
        >
          <FrozenStatus connected={connected} title={statusTitle} />
          {connected && locationOn ? (
            <div style={{ width: '100%', display: 'flex', justifyContent: 'center' }}>{locationOn}</div>
          ) : null}
          {mode ? (
            <div style={{ width: '100%', display: 'flex', justifyContent: 'center' }}>{mode}</div>
          ) : null}
        </div>
        <div style={{ paddingBottom: 6 }}>{connect}</div>
      </div>
    </Phone>
  );
}

Object.assign(window, {
  C,
  NODE,
  Phone,
  FrozenCoverFlow,
  FrozenStats,
  FrozenStatus,
  ChromeRow,
  SettingsOrb,
  SettingsChip,
  LocationCaption,
  LocationCaptionHit,
  LocationPill,
  LocationOrb,
  ModeText,
  ModeChip,
  ModeOrb,
  SplitBar,
  ConnectStage,
  HomeFrame,
});
