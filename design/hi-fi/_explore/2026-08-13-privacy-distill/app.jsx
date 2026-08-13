/* Data & Privacy distill — same move as Welcome A.

   Assumptions
   - English source. No cards, no risk essays.
   - Two true words: On device / No tracking.
     iCloud exceptions and the rest live in Privacy Policy.
   - Do not write “no cloud” — Override backup exists (ADR 0054).
   - Field Black + mint Continue. Link uses existing About label.
*/

function CurrentPrivacy() {
  const card = {
    display: 'flex',
    gap: 13,
    padding: 14,
    borderRadius: 18,
    background: 'linear-gradient(rgba(255,255,255,0.10), rgba(255,255,255,0.045))',
    boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.16)',
  };
  const title = { margin: 0, fontSize: 15, fontWeight: 600, color: T.primary };
  const detail = { margin: '4px 0 0', fontSize: 13, fontWeight: 500, lineHeight: 1.35, color: T.muted };
  return (
    <Phone label="0 Current">
      <div style={{
        fontSize: 12,
        fontWeight: 700,
        letterSpacing: '0.18em',
        color: T.quiet,
        paddingTop: 10,
      }}>
        DATA & PRIVACY
      </div>
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        gap: 18,
        padding: '8px 0 12px',
      }}>
        <h1 style={{
          margin: 0,
          fontSize: 30,
          fontWeight: 700,
          letterSpacing: '-0.03em',
          lineHeight: 1.15,
          color: T.primary,
        }}>
          Your connection data stays under your control.
        </h1>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={card}>
            <div>
              <p style={title}>Credentials stay on this device</p>
              <p style={detail}>Subscription links and proxy credentials are never uploaded by Routeva.</p>
            </div>
          </div>
          <div style={card}>
            <div>
              <p style={title}>Only domain exceptions use iCloud</p>
              <p style={detail}>Subscriptions, DNS settings, logs and connection snapshots do not sync.</p>
            </div>
          </div>
          <div style={card}>
            <div>
              <p style={title}>No analytics or cloud help</p>
              <p style={detail}>This Beta includes no telemetry, ads, third-party crash SDK or cloud assistant.</p>
            </div>
          </div>
        </div>
      </div>
      <Primary>Continue</Primary>
    </Phone>
  );
}

function StackPrivacy() {
  return (
    <Phone label="A Stack">
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        paddingBottom: '16%',
      }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <div className="wd-word" style={{ animationDelay: '0ms' }}>On device</div>
          <div className="wd-word" style={{ animationDelay: '70ms' }}>No tracking</div>
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <PrivacyLink />
        <Primary>Continue</Primary>
      </div>
    </Phone>
  );
}

function BreathPrivacy() {
  return (
    <Phone label="B Breath">
      <div style={{
        flex: 1,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        padding: '0 4px 8%',
      }}>
        <p className="wd-breath" style={{
          margin: 0,
          fontSize: 28,
          fontWeight: 600,
          letterSpacing: '-0.035em',
          lineHeight: 1.25,
          color: T.primary,
          textWrap: 'balance',
        }}>
          On device. No tracking.
        </p>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <PrivacyLink />
        <Primary>Continue</Primary>
      </div>
    </Phone>
  );
}

function CaptionPrivacy() {
  return (
    <Phone label="C Caption">
      <div style={{ flex: 1 }}></div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        <p style={{
          margin: 0,
          textAlign: 'center',
          fontSize: 15,
          fontWeight: 600,
          letterSpacing: '-0.01em',
          color: T.muted,
        }}>
          On device<span className="wd-dot">·</span>No tracking
        </p>
        <PrivacyLink />
        <Primary>Continue</Primary>
      </div>
    </Phone>
  );
}

function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="privacy"
        title="Data & Privacy · distill"
        subtitle="已选定 A · Stack · 已升 current/03-setup 与 DataAndPrivacyView"
      >
        <DCPostIt top={-8} left={8} width={256} rotate={-1.2}>
          现稿三张卡在规避审查。A 跟 Welcome 同构；B 收成一句；C 舞台留空。iCloud 例外不写上屏。
        </DCPostIt>
        <DCArtboard id="p-0" label="0 · Current" width={T.W} height={T.H}>
          <CurrentPrivacy />
        </DCArtboard>
        <DCArtboard id="p-a" label="A · Stack" width={T.W} height={T.H}>
          <StackPrivacy />
        </DCArtboard>
        <DCArtboard id="p-b" label="B · Breath" width={T.W} height={T.H}>
          <BreathPrivacy />
        </DCArtboard>
        <DCArtboard id="p-c" label="C · Caption" width={T.W} height={T.H}>
          <CaptionPrivacy />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
