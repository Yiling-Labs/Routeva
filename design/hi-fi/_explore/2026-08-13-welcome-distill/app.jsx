/* Welcome distill — one copy set, three compositions + current control.

   Assumptions
   - English source. No feature blurbs. No 1·2·3 cards. No brand word.
   - Highlights = Paste / Connect / Smart (MVP-true; Mode name, not Auto).
   - Field Black + mint CTA from visual-system. Get started stays.
   - Current is the control. A/B/C only change type + gravity.
*/

function CurrentWelcome() {
  return (
    <Phone label="0 Current">
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        paddingBottom: '18%',
        maxWidth: 320,
      }}>
        <h1 style={{
          margin: 0,
          fontSize: 34,
          fontWeight: 700,
          letterSpacing: '-0.04em',
          lineHeight: 1.12,
          color: T.primary,
          textWrap: 'balance',
        }}>
          Paste your subscription.
          <span style={{ display: 'block', marginTop: 6 }}>We handle the rest.</span>
        </h1>
        <p style={{
          margin: '20px 0 0',
          fontSize: 16,
          fontWeight: 500,
          letterSpacing: '-0.01em',
          lineHeight: 1.45,
          color: T.secondary,
          maxWidth: 300,
        }}>
          No technical setup. Connects first—and explains itself when it doesn’t.
        </p>
      </div>
      <Primary>Get started</Primary>
    </Phone>
  );
}

function StackWelcome() {
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
          <div className="wd-word" style={{ animationDelay: '0ms' }}>Paste</div>
          <div className="wd-word" style={{ animationDelay: '70ms' }}>Connect</div>
          <div className="wd-word" style={{ animationDelay: '140ms' }}>Smart</div>
        </div>
      </div>
      <Primary>Get started</Primary>
    </Phone>
  );
}

function BreathWelcome() {
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
          lineHeight: 1.2,
          color: T.primary,
          textWrap: 'balance',
        }}>
          Paste. Connect. Smart.
        </p>
      </div>
      <Primary>Get started</Primary>
    </Phone>
  );
}

function CaptionWelcome() {
  return (
    <Phone label="C Caption">
      <div style={{ flex: 1 }}></div>
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 18,
      }}>
        <p style={{
          margin: 0,
          textAlign: 'center',
          fontSize: 15,
          fontWeight: 600,
          letterSpacing: '-0.01em',
          color: T.muted,
        }}>
          Paste<span className="wd-dot">·</span>Connect<span className="wd-dot">·</span>Smart
        </p>
        <Primary>Get started</Primary>
      </div>
    </Phone>
  );
}

function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="welcome"
        title="Welcome · distill"
        subtitle="已选定 A · Stack · 已升 current/03-setup 与 WelcomeView"
      >
        <DCPostIt top={-8} left={8} width={248} rotate={-1.2}>
          现稿副文在解释产品。A 用三个词当标题；B 收成一口气；C 把词降成 CTA 上的一行，舞台留空。
        </DCPostIt>
        <DCArtboard id="w-0" label="0 · Current" width={T.W} height={T.H}>
          <CurrentWelcome />
        </DCArtboard>
        <DCArtboard id="w-a" label="A · Stack" width={T.W} height={T.H}>
          <StackWelcome />
        </DCArtboard>
        <DCArtboard id="w-b" label="B · Breath" width={T.W} height={T.H}>
          <BreathWelcome />
        </DCArtboard>
        <DCArtboard id="w-c" label="C · Caption" width={T.W} height={T.H}>
          <CaptionWelcome />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
