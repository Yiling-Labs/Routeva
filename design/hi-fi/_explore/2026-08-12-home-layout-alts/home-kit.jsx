/* Routeva Home kit v2 — craft-faithful atoms (vertical ConnectStage + Cover Flow) */
const HK = {
  font: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "PingFang SC", system-ui, sans-serif',
  fieldTop: '#2e343a',
  fieldBot: '#0b0e11',
  greenTop: '#4d7a6c',
  greenBot: '#1f3f38',
  mint: '#6ed4a6',
  primary: 'rgba(255,255,255,0.96)',
  secondary: 'rgba(255,255,255,0.72)',
  muted: 'rgba(255,255,255,0.58)',
  quiet: 'rgba(255,255,255,0.38)',
  W: 393,
  H: 852,
};

const NODES = [
  { id: 'za', cc: 'za', name: 'JNB-Edge-02', proto: 'SS', ms: 186 },
  { id: 'us', cc: 'us', name: 'LAX-08', proto: 'VMess', ms: 92 },
  { id: 'hk', cc: 'hk', name: 'HKG-01', proto: 'VMess', ms: 48 },
  { id: 'tw', cc: 'cn', name: '🇨🇳 台湾A01 | IEPL | x2', proto: 'VLESS', ms: 64 },
  { id: 'de', cc: 'de', name: 'FRA-04', proto: 'Hy2', ms: 210 },
  { id: 'gb', cc: 'gb', name: 'LON-05', proto: 'SS', ms: 118 },
  { id: 'jp', cc: 'jp', name: 'TYO-12', proto: 'Trojan', ms: 71 },
];
const FOCUS = 3;

function flagSrc(cc) {
  return `https://flagcdn.com/w160/${cc === 'tw' ? 'cn' : cc}.png`;
}

function latencyTier(ms) {
  if (ms == null) return null;
  if (ms < 100) return { t: `${ms}ms`, c: 'oklch(0.82 0.08 155)' };
  if (ms <= 200) return { t: `${ms}ms`, c: 'oklch(0.86 0.08 85)' };
  return { t: `${ms}ms`, c: 'oklch(0.82 0.08 25)' };
}

function glassSurface(light) {
  return {
    background: light
      ? 'linear-gradient(160deg, rgba(255,255,255,0.28) 0%, rgba(255,255,255,0.1) 100%)'
      : 'linear-gradient(160deg, rgba(255,255,255,0.16) 0%, rgba(255,255,255,0.06) 100%)',
    border: light
      ? '0.5px solid rgba(255,255,255,0.28)'
      : '0.5px solid rgba(255,255,255,0.14)',
    boxShadow: light
      ? 'inset 0 1px 0 rgba(255,255,255,0.35), 0 6px 18px rgba(0,0,0,0.12)'
      : 'inset 0 1px 0 rgba(255,255,255,0.2), 0 8px 22px rgba(0,0,0,0.28)',
    backdropFilter: 'blur(18px) saturate(1.2)',
    WebkitBackdropFilter: 'blur(18px) saturate(1.2)',
  };
}

function PhoneShell({ connected, label, children }) {
  const bg = connected
    ? `linear-gradient(180deg, ${HK.greenTop} 0%, ${HK.greenBot} 100%)`
    : `linear-gradient(180deg, ${HK.fieldTop} 0%, ${HK.fieldBot} 100%)`;
  return (
    <div
      data-screen-label={label}
      style={{
        width: HK.W,
        height: HK.H,
        borderRadius: 48,
        overflow: 'hidden',
        position: 'relative',
        background: bg,
        boxShadow: '0 28px 70px rgba(0,0,0,0.38), 0 0 0 1px rgba(255,255,255,0.06)',
        fontFamily: HK.font,
        color: HK.primary,
        userSelect: 'none',
      }}
    >
      {/* map wash */}
      <div
        aria-hidden
        style={{
          position: 'absolute',
          inset: 0,
          opacity: connected ? 0.07 : 0.1,
          pointerEvents: 'none',
          backgroundImage: `url("data:image/svg+xml,${encodeURIComponent(
            `<svg xmlns='http://www.w3.org/2000/svg' width='400' height='300' viewBox='0 0 400 300'><g fill='none' stroke='${connected ? 'rgba(255,255,255,0.55)' : '#fff'}' stroke-width='1' opacity='0.45'><ellipse cx='200' cy='148' rx='158' ry='88'/><path d='M42 148 Q100 78 200 98 T358 138'/><path d='M58 178 Q140 218 220 168 T348 188'/><path d='M82 118 Q160 58 242 108'/><circle cx='128' cy='138' r='2.5'/><circle cx='248' cy='128' r='2.5'/></g></svg>`
          )}")`,
          backgroundSize: '130% auto',
          backgroundPosition: 'center 42%',
          backgroundRepeat: 'no-repeat',
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
          pointerEvents: 'none',
          backgroundImage: 'radial-gradient(circle, currentColor 0.85px, transparent 1.05px)',
          backgroundSize: '4.5px 4.5px',
          color: connected ? 'rgba(0,0,0,0.35)' : 'rgba(255,255,255,0.55)',
          opacity: 0.18,
          WebkitMaskImage: 'linear-gradient(180deg, transparent 0%, #000 48%, #000 100%)',
          maskImage: 'linear-gradient(180deg, transparent 0%, #000 48%, #000 100%)',
        }}
      />
      {/* status bar */}
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
        <div style={{ display: 'flex', gap: 6, opacity: 0.92, fontSize: 12 }}>
          <span>●●●●</span>
          <span>Wi‑Fi</span>
          <span>100%</span>
        </div>
      </div>
      <div style={{ position: 'relative', zIndex: 5, height: HK.H - 54 - 18 }}>{children}</div>
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

function Chrome({ light }) {
  const icons = window.RoutevaIcons || {};
  const Sub = icons.IconSubscriptions;
  const Gear = icons.IconGear;
  const g = glassSurface(!!light);
  const orb = {
    width: 40,
    height: 40,
    borderRadius: 999,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    color: 'rgba(255,255,255,0.92)',
    ...g,
  };
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: '8px 22px 0',
        height: 48,
      }}
    >
      <div style={orb}>{Sub ? <Sub size={18} /> : '☰'}</div>
      <div style={orb}>{Gear ? <Gear size={18} /> : '⚙'}</div>
    </div>
  );
}

function FlagOrb({ node, selected, size = 56 }) {
  const tier = latencyTier(node.ms);
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        position: 'relative',
        overflow: 'hidden',
        flexShrink: 0,
        background: '#1a1e22',
        border: selected
          ? '1.5px solid rgba(255,255,255,0.32)'
          : '1px solid rgba(255,255,255,0.16)',
        boxShadow: selected
          ? '0 12px 28px rgba(0,0,0,0.38), inset 0 1px 0 rgba(255,255,255,0.35)'
          : '0 6px 14px rgba(0,0,0,0.28)',
      }}
    >
      <img
        src={flagSrc(node.cc)}
        alt=""
        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(160deg, rgba(255,255,255,0.3) 0%, transparent 45%, rgba(0,0,0,0.15) 100%)',
          pointerEvents: 'none',
        }}
      />
      {tier && selected && (
        <div
          style={{
            position: 'absolute',
            left: '50%',
            bottom: 4,
            transform: 'translateX(-50%)',
            padding: '2px 6px',
            borderRadius: 999,
            fontSize: 9,
            fontWeight: 700,
            letterSpacing: '0.02em',
            fontVariantNumeric: 'tabular-nums',
            color: tier.c,
            background: 'rgba(12,16,18,0.48)',
            border: '0.5px solid rgba(255,255,255,0.14)',
            backdropFilter: 'blur(8px)',
            whiteSpace: 'nowrap',
          }}
        >
          {tier.t}
        </div>
      )}
    </div>
  );
}

/** Craft Cover Flow — absolute positioned orbs, shallow arc */
function CoverFlow({ scale = 1, step = 72, base = 56, height = 118 }) {
  const BASE = base * scale;
  const STEP = step * scale;
  return (
    <div
      style={{
        position: 'relative',
        height: height * scale,
        width: '100%',
        maskImage: 'linear-gradient(90deg, transparent 0%, #000 10%, #000 90%, transparent 100%)',
        WebkitMaskImage:
          'linear-gradient(90deg, transparent 0%, #000 10%, #000 90%, transparent 100%)',
      }}
    >
      {NODES.map((n, i) => {
        const dist = i - FOCUS;
        const ad = Math.abs(dist);
        const sc =
          ad < 0.5 ? 1.26 : ad < 1.5 ? 0.88 : ad < 2.5 ? 0.76 : 0.66;
        const opacity = ad < 0.5 ? 1 : ad < 1.5 ? 0.8 : ad < 2.5 ? 0.5 : 0.3;
        const y = Math.min(18, ad * ad * 2.0);
        const x = dist * STEP;
        return (
          <div
            key={n.id}
            style={{
              position: 'absolute',
              left: '50%',
              top: '50%',
              width: BASE,
              height: BASE,
              transform: `translate(-50%, -50%) translate(${x}px, ${y}px) scale(${sc})`,
              opacity,
              zIndex: 30 - Math.round(ad * 6),
            }}
          >
            <FlagOrb node={n} selected={ad < 0.45} size={BASE} />
          </div>
        );
      })}
    </div>
  );
}

/** Hero focus: one large selected orb + peeks */
function HeroOrbStage() {
  const left = NODES[FOCUS - 1];
  const mid = NODES[FOCUS];
  const right = NODES[FOCUS + 1];
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 18,
        height: 168,
        width: '100%',
      }}
    >
      <div style={{ opacity: 0.45, transform: 'scale(0.78) translateY(10px)' }}>
        <FlagOrb node={left} selected={false} size={64} />
      </div>
      <div style={{ transform: 'scale(1.08)', filter: 'drop-shadow(0 18px 36px rgba(0,0,0,0.4))' }}>
        <FlagOrb node={mid} selected size={108} />
      </div>
      <div style={{ opacity: 0.45, transform: 'scale(0.78) translateY(10px)' }}>
        <FlagOrb node={right} selected={false} size={64} />
      </div>
    </div>
  );
}

function NodeCaption({ withChevron = true, size = 16, align = 'center' }) {
  const node = NODES[FOCUS];
  return (
    <div
      style={{
        display: 'flex',
        justifyContent: align === 'left' ? 'flex-start' : 'center',
        width: '100%',
        padding: '0 28px',
      }}
    >
      <div
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: 5,
          maxWidth: 300,
          minWidth: 0,
          color: 'rgba(255,255,255,0.9)',
          fontSize: size,
          fontWeight: 600,
        }}
      >
        <span
          style={{
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
            minWidth: 0,
          }}
        >
          {node.name}
        </span>
        <span style={{ color: HK.quiet, fontSize: 11, fontWeight: 500, flexShrink: 0 }}>
          · {node.proto}
        </span>
        {withChevron && (
          <span style={{ color: HK.quiet, fontSize: 11, flexShrink: 0 }}>›</span>
        )}
      </div>
    </div>
  );
}

function StatusTitle({ text, size = 30, weight = 700, color, align = 'center' }) {
  return (
    <div
      style={{
        fontSize: size,
        fontWeight: weight,
        letterSpacing: '-0.03em',
        lineHeight: 1.1,
        textAlign: align,
        color: color || HK.primary,
        padding: align === 'left' ? '0 28px' : '0 20px',
      }}
    >
      {text}
    </div>
  );
}

function ModeChip({ light, quiet }) {
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 4,
        padding: quiet ? '0' : '6px 12px',
        borderRadius: 999,
        fontSize: quiet ? 13 : 13,
        fontWeight: 600,
        color: quiet ? HK.muted : 'rgba(255,255,255,0.78)',
        ...(quiet
          ? {}
          : {
              background: light
                ? 'rgba(255,255,255,0.14)'
                : 'rgba(255,255,255,0.08)',
              border: '0.5px solid rgba(255,255,255,0.12)',
            }),
      }}
    >
      Smart <span style={{ opacity: 0.5, fontSize: 11 }}>›</span>
    </div>
  );
}

/** Static craft ConnectStage (Idle START at top / Connected STOP at bottom) */
function ConnectStage({ connected, scale = 1, showHint = true }) {
  const TRACK_W = 80 * scale;
  const TRACK_H = 204 * scale;
  const THUMB_H = 104 * scale;
  const PAD = 7 * scale;
  const THUMB_INSET = 5 * scale;
  const THUMB_W = TRACK_W - THUMB_INSET * 2;
  const Y_START = PAD;
  const Y_STOP = TRACK_H - THUMB_H - PAD;
  const STAGE_W = 260 * scale;
  const STAGE_H = 300 * scale;
  const trackLeft = (STAGE_W - TRACK_W) / 2;
  const trackTop = Math.round((STAGE_H - TRACK_H) * 0.42);
  const y = connected ? Y_STOP : Y_START;
  const isOn = !!connected;

  const trackBg = isOn
    ? 'linear-gradient(180deg, rgba(12,36,28,0.5) 0%, rgba(6,20,16,0.78) 100%)'
    : 'linear-gradient(180deg, rgba(255,255,255,0.12) 0%, rgba(8,10,12,0.42) 55%, rgba(0,0,0,0.48) 100%)';
  const thumbBg = isOn
    ? 'linear-gradient(165deg, #b6f5d6 0%, #6ed4a6 38%, #3fb887 72%, #2a9a6c 100%)'
    : 'linear-gradient(165deg, #4a525a 0%, #2a3138 42%, #1a1f24 100%)';
  const thumbFg = isOn ? 'rgba(6,28,20,0.92)' : 'rgba(255,255,255,0.94)';
  const thumbShadow = isOn
    ? '0 14px 36px rgba(30,190,120,0.42), 0 4px 12px rgba(20,120,80,0.28), 0 0 0 1px rgba(255,255,255,0.22), inset 0 1.5px 0 rgba(255,255,255,0.62)'
    : '0 14px 34px rgba(0,0,0,0.48), 0 3px 8px rgba(0,0,0,0.28), 0 0 0 1px rgba(255,255,255,0.1), inset 0 1.5px 0 rgba(255,255,255,0.28)';

  const Power = (window.RoutevaIcons || {}).IconPower;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ position: 'relative', width: STAGE_W, height: STAGE_H }}>
        {/* soft rings when connected */}
        {isOn && (
          <div
            aria-hidden
            style={{
              position: 'absolute',
              left: '50%',
              bottom: STAGE_H * 0.12,
              width: 160 * scale,
              height: 160 * scale,
              marginLeft: -80 * scale,
              borderRadius: '50%',
              border: '1px solid rgba(140,255,200,0.18)',
              boxShadow:
                '0 0 0 22px rgba(110,212,166,0.06), 0 0 0 44px rgba(110,212,166,0.04)',
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
              ? 'inset 0 2px 18px rgba(0,0,0,0.42), inset 0 1px 0 rgba(255,255,255,0.06), 0 0 0 1px rgba(120,255,190,0.16), 0 20px 48px rgba(0,0,0,0.18)'
              : 'inset 0 2px 20px rgba(0,0,0,0.58), inset 0 1px 0 rgba(255,255,255,0.08), 0 0 0 1px rgba(255,255,255,0.1), 0 20px 48px rgba(0,0,0,0.34)',
            backdropFilter: 'blur(16px) saturate(1.15)',
          }}
        >
          {!isOn && (
            <div
              style={{
                position: 'absolute',
                bottom: 11 * scale,
                left: 0,
                right: 0,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 1,
                opacity: 0.42,
                pointerEvents: 'none',
              }}
            >
              <span
                style={{
                  fontSize: 10 * scale,
                  fontWeight: 800,
                  letterSpacing: '0.16em',
                  color: 'rgba(255,255,255,0.55)',
                }}
              >
                SWIPE
              </span>
              <span style={{ color: 'rgba(255,255,255,0.5)', fontSize: 12 * scale }}>↓</span>
            </div>
          )}
          {isOn && (
            <div
              style={{
                position: 'absolute',
                top: 11 * scale,
                left: 0,
                right: 0,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 1,
                opacity: 0.4,
                pointerEvents: 'none',
              }}
            >
              <span style={{ color: 'rgba(180,255,220,0.55)', fontSize: 12 * scale }}>↑</span>
              <span
                style={{
                  fontSize: 10 * scale,
                  fontWeight: 800,
                  letterSpacing: '0.16em',
                  color: 'rgba(200,255,230,0.7)',
                }}
              >
                SWIPE
              </span>
            </div>
          )}
          <div
            style={{
              position: 'absolute',
              left: THUMB_INSET,
              width: THUMB_W,
              height: THUMB_H,
              top: y,
              borderRadius: 999,
              background: thumbBg,
              boxShadow: thumbShadow,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8 * scale,
              paddingTop: 10 * scale,
            }}
          >
            {/* LED */}
            <div
              style={{
                position: 'absolute',
                top: 14 * scale,
                width: 7 * scale,
                height: 7 * scale,
                borderRadius: '50%',
                background: isOn ? 'rgba(50,255,130,0.95)' : 'rgba(28,36,32,0.95)',
                boxShadow: isOn
                  ? '0 0 12px rgba(50,255,130,0.7)'
                  : 'inset 0 1px 1px rgba(0,0,0,0.5)',
              }}
            />
            <span
              style={{
                fontSize: 12 * scale,
                fontWeight: 800,
                letterSpacing: '0.12em',
                color: thumbFg,
                marginTop: 8 * scale,
              }}
            >
              {isOn ? 'STOP' : 'START'}
            </span>
            {Power ? (
              <Power size={22 * scale} stroke={2} color={thumbFg} />
            ) : (
              <span style={{ color: thumbFg, fontSize: 18 * scale }}>⏻</span>
            )}
          </div>
        </div>
      </div>
      {showHint && (
        <div
          style={{
            marginTop: -6 * scale,
            fontSize: 13,
            fontWeight: 500,
            color: HK.muted,
            letterSpacing: '0.01em',
          }}
        >
          {isOn ? 'Swipe up to stop' : 'Swipe down to connect'}
        </div>
      )}
    </div>
  );
}

function SessionStats({ compact }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <div
        style={{
          fontSize: compact ? 34 : 40,
          fontWeight: 300,
          letterSpacing: '-0.02em',
          fontVariantNumeric: 'tabular-nums',
          lineHeight: 1.05,
        }}
      >
        00:45:29
      </div>
      <div
        style={{
          marginTop: 10,
          display: 'flex',
          justifyContent: 'center',
          gap: 18,
          fontSize: 12,
          fontWeight: 500,
          color: 'rgba(255,255,255,0.78)',
          fontVariantNumeric: 'tabular-nums',
        }}
      >
        <span>↓ 48.2 MB</span>
        <span>↑ 6.1 MB</span>
      </div>
    </div>
  );
}

function NodeGlassRow({ light }) {
  const node = NODES[FOCUS];
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 7,
        padding: '10px 16px',
        borderRadius: 999,
        maxWidth: 300,
        fontSize: 13,
        fontWeight: 600,
        ...glassSurface(!!light),
      }}
    >
      <img
        src={flagSrc(node.cc)}
        alt=""
        style={{ width: 18, height: 18, borderRadius: '50%', objectFit: 'cover' }}
      />
      <span
        style={{
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
          minWidth: 0,
        }}
      >
        {node.name}
      </span>
      <span style={{ color: HK.quiet, fontSize: 11, flexShrink: 0 }}>· {node.proto}</span>
      <span style={{ color: HK.quiet, fontSize: 10 }}>›</span>
    </div>
  );
}

Object.assign(window, {
  HK,
  NODES,
  FOCUS,
  PhoneShell,
  Chrome,
  CoverFlow,
  HeroOrbStage,
  NodeCaption,
  StatusTitle,
  ModeChip,
  ConnectStage,
  SessionStats,
  NodeGlassRow,
  FlagOrb,
});
