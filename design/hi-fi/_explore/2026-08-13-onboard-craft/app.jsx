/* First-run craft — same words, five small marks.

   Locked: Paste / Connect / Smart · On device / No tracking
   Locked: Field Black, mint CTA, no extra sentences.
*/

function Screen({ label, cta, privacy, children, bottom }) {
  return (
    <Phone label={label}>
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        paddingBottom: '16%',
      }}>
        {children}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {bottom}
        {privacy ? <PrivacyLink /> : null}
        <Primary>{cta}</Primary>
      </div>
    </Phone>
  );
}

function BareWords({ words, lastMint, stagger, caret }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      {words.map(function (word, i) {
        const last = i === words.length - 1;
        return (
          <div
            key={word}
            className={stagger ? 'wd-word' : undefined}
            style={{
              fontSize: 52,
              fontWeight: 700,
              letterSpacing: '-0.045em',
              lineHeight: 1.02,
              color: last && lastMint ? T.mint : T.primary,
              whiteSpace: 'nowrap',
              animationDelay: stagger ? (i * 90) + 'ms' : undefined,
              display: 'flex',
              alignItems: 'center',
            }}
          >
            {word}
            {last && caret ? <span className="wd-caret" aria-hidden="true"></span> : null}
          </div>
        );
      })}
    </div>
  );
}

function FolioWords({ words }) {
  return (
    <div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {words.map(function (word, i) {
          const n = String(i + 1).padStart(2, '0');
          return (
            <div key={word} style={{ display: 'flex', alignItems: 'baseline', gap: 12 }}>
              <span style={{
                width: 22,
                fontSize: 11,
                fontWeight: 600,
                letterSpacing: '0.06em',
                color: T.quiet,
                fontVariantNumeric: 'tabular-nums',
              }}>
                {n}
              </span>
              <span style={{
                fontSize: 48,
                fontWeight: 700,
                letterSpacing: '-0.045em',
                lineHeight: 1.05,
                color: T.primary,
                whiteSpace: 'nowrap',
              }}>
                {word}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function CurrentWelcome() {
  return (
    <Screen label="0w" cta="Get started">
      <BareWords words={['Paste', 'Connect', 'Smart']} />
    </Screen>
  );
}
function CurrentPrivacy() {
  return (
    <Screen label="0p" cta="Continue" privacy>
      <BareWords words={['On device', 'No tracking']} />
    </Screen>
  );
}

function FolioWelcome() {
  return (
    <Screen label="Aw" cta="Get started">
      <FolioWords words={['Paste', 'Connect', 'Smart']} />
    </Screen>
  );
}
function FolioPrivacy() {
  return (
    <Screen label="Ap" cta="Continue" privacy>
      <FolioWords words={['On device', 'No tracking']} />
    </Screen>
  );
}

function CapsuleWelcome() {
  return (
    <Screen label="Bw" cta="Get started">
      <div style={{ display: 'flex', flexDirection: 'column', gap: 22 }}>
        <CapsuleMark />
        <BareWords words={['Paste', 'Connect', 'Smart']} />
      </div>
    </Screen>
  );
}
function CapsulePrivacy() {
  return (
    <Screen label="Bp" cta="Continue" privacy>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 22 }}>
        <CapsuleMark />
        <BareWords words={['On device', 'No tracking']} />
      </div>
    </Screen>
  );
}

function RingsWelcome() {
  return (
    <Screen label="Cw" cta="Get started">
      <div style={{ position: 'relative' }}>
        <GhostRings count={3} />
        <BareWords words={['Paste', 'Connect', 'Smart']} />
      </div>
    </Screen>
  );
}
function RingsPrivacy() {
  return (
    <Screen label="Cp" cta="Continue" privacy>
      <div style={{ position: 'relative' }}>
        <GhostRings count={1} />
        <BareWords words={['On device', 'No tracking']} />
      </div>
    </Screen>
  );
}

function MintWelcome() {
  return (
    <Screen label="Dw" cta="Get started">
      <BareWords words={['Paste', 'Connect', 'Smart']} lastMint stagger />
    </Screen>
  );
}
function MintPrivacy() {
  return (
    <Screen label="Dp" cta="Continue" privacy>
      <BareWords words={['On device', 'No tracking']} lastMint stagger />
    </Screen>
  );
}

function CaretWelcome() {
  return (
    <Screen label="Ew" cta="Get started" bottom={<PlaceDots index={0} total={2} />}>
      <BareWords words={['Paste', 'Connect', 'Smart']} caret />
    </Screen>
  );
}
function CaretPrivacy() {
  return (
    <Screen label="Ep" cta="Continue" privacy bottom={<PlaceDots index={1} total={2} />}>
      <BareWords words={['On device', 'No tracking']} caret />
    </Screen>
  );
}

function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="pairs"
        title="First-run craft"
        subtitle="字不动 · 只加一个记号 · Welcome + Data & Privacy 成对看"
      >
        <DCPostIt top={-8} left={6} width={260} rotate={-1.1}>
          0 是现稿。A 页码（Things / iA）。B 自家胶囊。C Home 点阵的静环。D 末词薄荷（Clear）。E 插入符 + 两点（iA / Linear）。
        </DCPostIt>
        <DCArtboard id="v-0" label="0 · Current" width={802} height={T.H}>
          <Pair label="0" left={<CurrentWelcome />} right={<CurrentPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-a" label="A · Folio" width={802} height={T.H}>
          <Pair label="A" left={<FolioWelcome />} right={<FolioPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-b" label="B · Capsule" width={802} height={T.H}>
          <Pair label="B" left={<CapsuleWelcome />} right={<CapsulePrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-c" label="C · Rings" width={802} height={T.H}>
          <Pair label="C" left={<RingsWelcome />} right={<RingsPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-d" label="D · Last mint" width={802} height={T.H}>
          <Pair label="D" left={<MintWelcome />} right={<MintPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-e" label="E · Caret" width={802} height={T.H}>
          <Pair label="E" left={<CaretWelcome />} right={<CaretPrivacy />} />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
