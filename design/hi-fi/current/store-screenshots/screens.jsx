/* Routeva phone UI for store screenshot candidates.
   Visual tokens from craft-p0/visual-system.md. Demo data: no Taiwan nodes. */

const t = window.t;
const RVFont = '-apple-system, "SF Pro Display", "SF Pro Text", "PingFang SC", system-ui, sans-serif';

const T = {
  primary: 'rgba(255,255,255,0.96)',
  secondary: 'rgba(255,255,255,0.55)',
  muted: 'rgba(255,255,255,0.58)',
  quiet: 'rgba(255,255,255,0.38)',
  mint: 'rgba(127,217,176,0.95)',
  mintSoft: 'rgba(127,217,176,0.14)',
  card: 'linear-gradient(180deg, rgba(255,255,255,0.10), rgba(255,255,255,0.045))',
  cardBorder: 'rgba(255,255,255,0.10)',
  hairline: 'rgba(255,255,255,0.08)',
};

const NODES = [
  { id: 'hk', cc: 'hk', flag: '🇭🇰', name: '香港A03 | IEPL', proto: 'VLESS', ms: 42 },
  { id: 'jp', cc: 'jp', flag: '🇯🇵', name: '东京B12 | 专线', proto: 'VMess', ms: 68 },
  { id: 'sg', cc: 'sg', flag: '🇸🇬', name: '新加坡C02', proto: 'Hy2', ms: 91 },
  { id: 'us', cc: 'us', flag: '🇺🇸', name: 'Los Angeles | x2', proto: 'Trojan', ms: 148 },
  { id: 'gb', cc: 'gb', flag: '🇬🇧', name: '伦敦A01', proto: 'SS', ms: 186 },
];

const FLOW = ['us', 'hk', 'jp', 'sg', 'gb'];
const PREFERRED = NODES[0];

function flagSrc(cc) {
  return 'https://flagcdn.com/w160/' + cc + '.png';
}

function msColor(ms) {
  if (ms < 100) return 'rgba(127,217,176,0.95)';
  if (ms <= 200) return 'rgba(232,201,112,0.92)';
  return 'rgba(232,140,140,0.88)';
}

function IconSubs() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 2L2 7l10 5 10-5-10-5z" />
      <path d="M2 17l10 5 10-5" />
      <path d="M2 12l10 5 10-5" />
    </svg>
  );
}

function IconGear() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9c.3.6.9 1 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" />
    </svg>
  );
}

function IconPower() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 2v10" />
      <path d="M18.4 6.6a8 8 0 1 1-12.8 0" />
    </svg>
  );
}

function IconClose() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" aria-hidden="true">
      <path d="M18 6L6 18M6 6l12 12" />
    </svg>
  );
}

function IconBack() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M15 18l-6-6 6-6" />
    </svg>
  );
}

function IconCheck() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M20 6L9 17l-5-5" />
    </svg>
  );
}

function IconQr() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" aria-hidden="true">
      <rect x="3" y="3" width="7" height="7" rx="1" />
      <rect x="14" y="3" width="7" height="7" rx="1" />
      <rect x="3" y="14" width="7" height="7" rx="1" />
      <path d="M14 14h3v3h-3zM20 14v7M14 20h3" />
    </svg>
  );
}

function IconFile() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
    </svg>
  );
}

function StatusBar({ time }) {
  const c = '#fff';
  return (
    <div className="rv-status">
      <span className="rv-status-time">{time || '9:41'}</span>
      <span className="rv-island" aria-hidden="true"></span>
      <span className="rv-status-icons" aria-hidden="true">
        <svg width="17" height="11" viewBox="0 0 17 11"><rect x="0" y="7" width="3" height="4" rx="0.6" fill={c}/><rect x="4.5" y="5" width="3" height="6" rx="0.6" fill={c}/><rect x="9" y="2.5" width="3" height="8.5" rx="0.6" fill={c}/><rect x="13.5" y="0" width="3" height="11" rx="0.6" fill={c}/></svg>
        <svg width="15" height="11" viewBox="0 0 15 11"><path d="M7.5 2.6C9.5 2.6 11.3 3.4 12.6 4.7L13.6 3.7C12 2.1 9.9 1.1 7.5 1.1S3 2.1 1.4 3.7L2.4 4.7C3.7 3.4 5.5 2.6 7.5 2.6Z" fill={c}/><path d="M7.5 5.8C8.7 5.8 9.8 6.3 10.6 7.1L11.6 6.1C10.5 5 9.1 4.4 7.5 4.4S4.5 5 3.4 6.1L4.4 7.1C5.2 6.3 6.3 5.8 7.5 5.8Z" fill={c}/><circle cx="7.5" cy="9.4" r="1.3" fill={c}/></svg>
        <svg width="25" height="12" viewBox="0 0 25 12"><rect x="0.5" y="0.5" width="21" height="11" rx="3.2" stroke={c} strokeOpacity="0.35" fill="none"/><rect x="2" y="2" width="18" height="8" rx="2" fill={c}/><path d="M23 4.2V7.8C23.8 7.5 24.4 6.6 24.4 6C24.4 5.4 23.8 4.5 23 4.2Z" fill={c} fillOpacity="0.4"/></svg>
      </span>
    </div>
  );
}

function GlassOrb({ children, label }) {
  return (
    <div className="rv-orb" aria-label={label}>
      {children}
    </div>
  );
}

function HomeChrome({ showSubs }) {
  return (
    <div className="rv-chrome">
      {showSubs ? <GlassOrb label="Subscriptions"><IconSubs /></GlassOrb> : <span className="rv-orb-spacer"></span>}
      <GlassOrb label="Settings"><IconGear /></GlassOrb>
    </div>
  );
}

function FlagOrb({ cc, ms, size, active }) {
  const dim = size || 60;
  return (
    <div className={'rv-flag' + (active ? ' is-active' : '')} style={{ width: dim, height: dim }}>
      <img src={flagSrc(cc)} alt="" width={dim} height={dim} />
      {ms != null && (
        <span className="rv-ms" style={{ color: msColor(ms) }}>{ms}ms</span>
      )}
    </div>
  );
}

function CoverFlow({ focusId }) {
  const focus = focusId || 'hk';
  const i = FLOW.indexOf(focus);
  return (
    <div className="rv-flow" aria-hidden="true">
      {FLOW.map((id, idx) => {
        const n = NODES.find((x) => x.id === id);
        const d = idx - i;
        const scale = d === 0 ? 1 : Math.abs(d) === 1 ? 0.82 : 0.62;
        const y = Math.abs(d) * Math.abs(d) * 7;
        const opacity = d === 0 ? 1 : Math.abs(d) === 1 ? 0.78 : 0.42;
        return (
          <div
            key={id}
            className="rv-flow-item"
            style={{
              transform: 'translateX(' + (d * 52) + 'px) translateY(' + y + 'px) scale(' + scale + ')',
              opacity: opacity,
              zIndex: 8 - Math.abs(d),
            }}
          >
            <FlagOrb cc={n.cc} ms={n.ms} size={60} active={d === 0} />
          </div>
        );
      })}
    </div>
  );
}

function PinDots() {
  const rings = [
    { r: 53, n: 16 },
    { r: 73, n: 20 },
    { r: 93, n: 24 },
  ];
  return (
    <div className="rv-pins" aria-hidden="true">
      {rings.map((ring, ri) => {
        const dots = [];
        for (let i = 0; i < ring.n; i++) {
          const t = i / (ring.n - 1);
          const angle = -Math.PI / 6 + (Math.PI * 4 / 3) * t;
          const x = Math.cos(angle) * ring.r;
          const y = Math.sin(angle) * ring.r;
          dots.push(
            <i key={ri + '-' + i} style={{ transform: 'translate(' + x + 'px,' + y + 'px)' }}></i>
          );
        }
        return dots;
      })}
    </div>
  );
}

function Capsule({ mode }) {
  const connected = mode === 'connected';
  const atBottom = connected || mode === 'connecting';
  return (
    <div className={'rv-capsule' + (connected ? ' is-green' : '')}>
      {connected && <PinDots />}
      <div className={'rv-track' + (connected ? ' is-green' : '')}>
        {connected && (
          <div className="rv-swipe-hint is-up">
            <span className="rv-chev-sm">⌃</span>
            <span>{t('swipe')}</span>
          </div>
        )}
        {!connected && (
          <div className="rv-swipe-hint is-down">
            <span>{t('swipe')}</span>
            <span className="rv-chev-sm">⌄</span>
          </div>
        )}
        <div className={'rv-thumb' + (atBottom ? ' is-down' : '') + (connected ? ' is-green' : '')}>
          <span className={'rv-led' + (connected ? ' is-on' : '')}></span>
          <span className="rv-thumb-label">{connected ? t('stop') : t('start')}</span>
          <IconPower />
        </div>
      </div>
    </div>
  );
}

function PhoneShell({ field, children, time }) {
  return (
    <div className={'rv-phone field-' + field}>
      <div className="rv-noise" aria-hidden="true"></div>
      <div className="rv-halftone" aria-hidden="true"></div>
      <StatusBar time={time} />
      {children}
      <div className="rv-home-ind" aria-hidden="true"></div>
    </div>
  );
}

function HomeIdle() {
  return (
    <PhoneShell field="black">
      <HomeChrome showSubs={true} />
      <div className="rv-mid">
        <CoverFlow focusId="hk" />
        <div className="rv-caption">
          <span className="rv-nodename">{PREFERRED.name}</span>
          <span className="rv-proto">· VLESS</span>
          <span className="rv-chev" aria-hidden="true">›</span>
        </div>
        <div className="rv-status-word">{t('notConnected')}</div>
        <div className="rv-mode">
          <span className="rv-mode-k">{t('mode')}</span>
          <span>{t('smart')}</span>
          <span className="rv-chev">›</span>
        </div>
      </div>
      <Capsule mode="idle" />
      <div className="rv-hint">{t('swipeDown')}</div>
    </PhoneShell>
  );
}

function HomeConnecting() {
  return (
    <PhoneShell field="black">
      <HomeChrome showSubs={true} />
      <div className="rv-mid">
        <CoverFlow focusId="hk" />
        <div className="rv-caption is-locked">
          <span className="rv-nodename">{PREFERRED.name}</span>
          <span className="rv-proto">· VLESS</span>
        </div>
        <div className="rv-status-word">{t('connecting')}</div>
      </div>
      <Capsule mode="connecting" />
    </PhoneShell>
  );
}

function HomeConnected() {
  return (
    <PhoneShell field="green">
      <HomeChrome showSubs={true} />
      <div className="rv-mid is-live">
        <div className="rv-timer">00:45:29</div>
        <div className="rv-traffic">
          <span>↓ 420 MB</span>
          <span>↑ 86 MB</span>
        </div>
        <div className="rv-status-word">{t('connected')}</div>
        <div className="rv-livebar">
          <span className="rv-live-loc">
            <img src={flagSrc('hk')} alt="" width="16" height="16" />
            <span className="rv-live-name">{PREFERRED.name}</span>
            <span className="rv-chev">›</span>
          </span>
          <span className="rv-live-split"></span>
          <span className="rv-live-mode">
            <span className="rv-mode-k">{t('mode')}</span>
            <span>{t('smart')}</span>
            <span className="rv-chev">›</span>
          </span>
        </div>
      </div>
      <Capsule mode="connected" />
      <div className="rv-hint">{t('swipeUp')}</div>
    </PhoneShell>
  );
}

function Welcome() {
  return (
    <PhoneShell field="black">
      <div className="rv-welcome">
        <h1>
          <span>Paste</span>
          <span>Connect</span>
          <span>Smart</span>
        </h1>
        <button type="button" className="rv-primary">Get started</button>
      </div>
    </PhoneShell>
  );
}

function AddSubscription() {
  return (
    <PhoneShell field="black">
      <div className="rv-chrome is-end">
        <GlassOrb label="Close"><IconClose /></GlassOrb>
      </div>
      <div className="rv-add">
        <h1>{t('addTitle')}</h1>
        <p>{t('addLead')}</p>
        <button type="button" className="rv-primary">{t('paste')}</button>
        <div className="rv-ghost-row">
          <button type="button" className="rv-ghost"><IconQr /> {t('scanQr')}</button>
          <button type="button" className="rv-ghost"><IconFile /> {t('importFile')}</button>
        </div>
        <p className="rv-add-foot">{t('addFooter')}</p>
      </div>
    </PhoneShell>
  );
}

function LocationList() {
  const sorted = NODES.slice().sort((a, b) => a.ms - b.ms);
  return (
    <PhoneShell field="black">
      <div className="rv-loc-nav">
        <GlassOrb label="Back"><IconBack /></GlassOrb>
        <h1>{t('location')}</h1>
        <button type="button" className="rv-test">{t('test')}</button>
      </div>
      <div className="rv-loc-list">
        {sorted.map((n, i) => {
          const pref = n.id === 'hk';
          return (
            <div key={n.id} className={'rv-loc-row' + (pref ? ' is-pref' : '') + (i === sorted.length - 1 ? ' is-last' : '')}>
              <span className="rv-loc-flag" aria-hidden="true">{n.flag}</span>
              <div className="rv-loc-text">
                <div className="rv-loc-name">{n.name}</div>
                <div className="rv-loc-meta">
                  <span>{n.proto}</span>
                  <span className="rv-loc-dot">·</span>
                  <span style={{ color: msColor(n.ms) }}>{n.ms} ms</span>
                </div>
              </div>
              <span className="rv-loc-check" style={{ color: pref ? T.mint : 'transparent' }}><IconCheck /></span>
            </div>
          );
        })}
      </div>
    </PhoneShell>
  );
}

const SCREENS = {
  connected: HomeConnected,
  welcome: Welcome,
  add: AddSubscription,
  idle: HomeIdle,
  location: LocationList,
  connecting: HomeConnecting,
};

Object.assign(window, {
  RVScreens: SCREENS,
  RVPhone: { HomeIdle, HomeConnecting, HomeConnected, AddSubscription, LocationList },
});
