/* First-run beyond Current — field / type / gravity. No figurines. */

const T = {
  font: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif',
  field: 'linear-gradient(168deg, #2e343a 0%, #171c21 42%, #0b0e11 100%)',
  fieldSealed: 'linear-gradient(180deg, #161a1e 0%, #0b0e11 100%)',
  cta: 'linear-gradient(160deg, #8fe8c0 0%, #4bb98a 48%, #2f9a6c 100%)',
  ctaShadow: '0 12px 32px rgba(50,190,130,0.32), inset 0 1px 0 rgba(255,255,255,0.4)',
  primary: 'rgba(255,255,255,0.96)',
  muted: 'rgba(255,255,255,0.58)',
  ink: '#0a1f18',
  W: 393,
  H: 852,
};

function FieldDecor({ sealed }) {
  return (
    <React.Fragment>
      <div className="wd-noise" aria-hidden="true"></div>
      {!sealed ? (
        <React.Fragment>
          <div
            className="wd-map"
            aria-hidden="true"
            style={{
              backgroundImage: `url("data:image/svg+xml,${encodeURIComponent(
                "<svg xmlns='http://www.w3.org/2000/svg' width='400' height='300'><g fill='none' stroke='#fff' stroke-width='1' opacity='0.4'><ellipse cx='200' cy='148' rx='158' ry='88'/><path d='M42 148 Q100 78 200 98 T358 138'/></g></svg>"
              )}")`,
            }}
          ></div>
          <div className="wd-halftone" aria-hidden="true"></div>
        </React.Fragment>
      ) : null}
    </React.Fragment>
  );
}

function Phone({ label, sealed, children }) {
  return (
    <div
      data-screen-label={label}
      style={{
        width: T.W,
        height: T.H,
        borderRadius: 48,
        overflow: 'hidden',
        position: 'relative',
        background: sealed ? T.fieldSealed : T.field,
        boxShadow: '0 28px 70px rgba(0,0,0,0.38), 0 0 0 1px rgba(255,255,255,0.06)',
        fontFamily: T.font,
        color: T.primary,
        userSelect: 'none',
      }}
    >
      <FieldDecor sealed={sealed} />
      <div
        aria-hidden="true"
        style={{
          position: 'relative',
          zIndex: 8,
          height: 54,
          padding: '14px 28px 0',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          fontSize: 15,
          fontWeight: 600,
          pointerEvents: 'none',
        }}
      >
        <span>9:41</span>
        <span style={{ fontSize: 12, opacity: 0.9 }}>●●●●  Wi-Fi  100%</span>
      </div>
      <div
        style={{
          position: 'relative',
          zIndex: 5,
          height: T.H - 54 - 22,
          display: 'flex',
          flexDirection: 'column',
          padding: '8px 28px 28px',
        }}
      >
        {children}
      </div>
      <div
        aria-hidden="true"
        style={{
          position: 'absolute',
          bottom: 8,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 128,
          height: 5,
          borderRadius: 999,
          background: 'rgba(255,255,255,0.35)',
          zIndex: 8,
        }}
      ></div>
    </div>
  );
}

function Primary({ children }) {
  return (
    <button type="button" className="wd-press" style={{
      border: 'none',
      cursor: 'pointer',
      width: '100%',
      padding: '17px 28px',
      borderRadius: 18,
      background: T.cta,
      boxShadow: T.ctaShadow,
      color: T.ink,
      fontFamily: T.font,
      fontSize: 16,
      fontWeight: 800,
    }}>
      {children}
    </button>
  );
}

function PrivacyLink() {
  return (
    <a
      className="wd-press"
      href="https://routeva.yilinglabs.com/privacy/"
      target="_blank"
      rel="noreferrer"
      style={{
        display: 'block',
        textAlign: 'center',
        padding: '12px 8px',
        fontFamily: T.font,
        fontSize: 15,
        fontWeight: 600,
        letterSpacing: '-0.01em',
        color: T.muted,
        textDecoration: 'none',
      }}
    >
      Privacy Policy
    </a>
  );
}

function Pair({ label, left, right }) {
  return (
    <div data-screen-label={label} style={{ display: 'flex', gap: 16 }}>
      {left}
      {right}
    </div>
  );
}

Object.assign(window, { T, Phone, Primary, PrivacyLink, Pair });
