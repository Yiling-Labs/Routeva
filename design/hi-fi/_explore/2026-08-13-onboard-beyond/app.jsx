/* Beyond Current. Thesis: beat 0 by changing the pair, not bolting a figurine.

   Last round lost because marks added a second meaning (steps, toggle, unfinished).
   This round: field, weight, gravity, a period, a hang. Words stay white.
*/

function Screen({ label, sealed, cta, privacy, gravity, hang, children }) {
  const mid = {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    justifyContent: gravity === 'low' ? 'flex-end' : 'center',
    paddingBottom: gravity === 'low' ? 8 : '16%',
    marginLeft: hang ? -18 : 0,
  };
  return (
    <Phone label={label} sealed={sealed}>
      <div style={mid}>{children}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {privacy ? <PrivacyLink /> : null}
        <Primary>{cta}</Primary>
      </div>
    </Phone>
  );
}

function Words({ items, leading }) {
  const ranked = items.some(function (item) {
    return typeof item === 'object' && item.stress;
  });
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: leading || 2 }}>
      {items.map(function (item) {
        const word = typeof item === 'string' ? item : item.word;
        const stress = typeof item === 'object' && item.stress;
        const quiet = ranked && !stress;
        return (
          <div
            key={word}
            style={{
              fontSize: stress ? 56 : 52,
              fontWeight: quiet ? 600 : 700,
              letterSpacing: stress ? '-0.05em' : '-0.045em',
              lineHeight: 1.02,
              color: quiet ? 'rgba(255,255,255,0.72)' : 'rgba(255,255,255,0.96)',
              whiteSpace: 'nowrap',
            }}
          >
            {word}
          </div>
        );
      })}
    </div>
  );
}

function Rule() {
  return (
    <div
      aria-hidden="true"
      style={{
        width: 48,
        height: 1,
        marginTop: 20,
        background: 'rgba(255,255,255,0.42)',
      }}
    ></div>
  );
}

function CurrentWelcome() {
  return (
    <Screen label="0w" cta="Get started">
      <Words items={['Paste', 'Connect', 'Smart']} />
    </Screen>
  );
}
function CurrentPrivacy() {
  return (
    <Screen label="0p" cta="Continue" privacy>
      <Words items={['On device', 'No tracking']} />
    </Screen>
  );
}

function SealedWelcome() {
  return (
    <Screen label="Fw" cta="Get started">
      <Words items={['Paste', 'Connect', 'Smart']} />
    </Screen>
  );
}
function SealedPrivacy() {
  return (
    <Screen label="Fp" cta="Continue" privacy sealed>
      <Words items={['On device', 'No tracking']} />
    </Screen>
  );
}

function StressWelcome() {
  return (
    <Screen label="Gw" cta="Get started">
      <Words items={['Paste', { word: 'Connect', stress: true }, 'Smart']} />
    </Screen>
  );
}
function StressPrivacy() {
  return (
    <Screen label="Gp" cta="Continue" privacy>
      <Words items={['On device', { word: 'No tracking', stress: true }]} />
    </Screen>
  );
}

function GravityWelcome() {
  return (
    <Screen label="Hw" cta="Get started">
      <Words items={['Paste', 'Connect', 'Smart']} />
    </Screen>
  );
}
function GravityPrivacy() {
  return (
    <Screen label="Hp" cta="Continue" privacy gravity="low">
      <Words items={['On device', 'No tracking']} leading={0} />
    </Screen>
  );
}

function RuleWelcome() {
  return (
    <Screen label="Jw" cta="Get started">
      <div>
        <Words items={['Paste', 'Connect', 'Smart']} />
        <Rule />
      </div>
    </Screen>
  );
}
function RulePrivacy() {
  return (
    <Screen label="Jp" cta="Continue" privacy>
      <div>
        <Words items={['On device', 'No tracking']} />
        <Rule />
      </div>
    </Screen>
  );
}

function HangWelcome() {
  return (
    <Screen label="Kw" cta="Get started" hang>
      <Words items={['Paste', 'Connect', 'Smart']} />
    </Screen>
  );
}
function HangPrivacy() {
  return (
    <Screen label="Kp" cta="Continue" privacy hang>
      <Words items={['On device', 'No tracking']} />
    </Screen>
  );
}

function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="beyond"
        title="Beyond Current"
        subtitle="不加物件 · 改两屏的关系 · 字保持白"
      >
        <DCPostIt top={-8} left={6} width={268} rotate={-1.1}>
          上一轮输在第二语义。F 隐私收场；G 加重对的词；H 主张落在按钮上；J 句号不是下划线；K 印刷悬字。
        </DCPostIt>
        <DCArtboard id="v-0" label="0 · Current" width={802} height={T.H}>
          <Pair label="0" left={<CurrentWelcome />} right={<CurrentPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-f" label="F · Sealed" width={802} height={T.H}>
          <Pair label="F" left={<SealedWelcome />} right={<SealedPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-g" label="G · Stress" width={802} height={T.H}>
          <Pair label="G" left={<StressWelcome />} right={<StressPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-h" label="H · Gravity" width={802} height={T.H}>
          <Pair label="H" left={<GravityWelcome />} right={<GravityPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-j" label="J · Rule" width={802} height={T.H}>
          <Pair label="J" left={<RuleWelcome />} right={<RulePrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-k" label="K · Hang" width={802} height={T.H}>
          <Pair label="K" left={<HangWelcome />} right={<HangPrivacy />} />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
