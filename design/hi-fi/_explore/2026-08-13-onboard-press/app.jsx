/* Publication on Current.

   Locked: Paste / Connect / Smart · On device / No tracking
   Locked: Field Black, mint CTA, words stay white.
   Not: line numbers 01 02 03 (that was Folio, already lost).
   Folio here = page number, like a magazine, not a checklist.
*/

function Words({ serif, open, couplet }) {
  const items = couplet ? ['On device', 'No tracking'] : ['Paste', 'Connect', 'Smart'];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: open ? 10 : 2 }}>
      {items.map(function (word) {
        return (
          <div
            key={word}
            style={{
              fontFamily: serif ? T.serif : T.font,
              fontSize: serif ? 50 : 52,
              fontWeight: serif ? 600 : 700,
              letterSpacing: open || serif ? '-0.025em' : '-0.045em',
              lineHeight: serif ? 1.08 : 1.02,
              color: T.primary,
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

function Screen({ label, cta, privacy, colophon, gravity, top, children }) {
  return (
    <Phone label={label}>
      {top}
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: gravity === 'low' ? 'flex-end' : 'center',
        paddingBottom: gravity === 'low' ? 10 : '16%',
      }}>
        {children}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {privacy && !colophon ? <PrivacyLink /> : null}
        {colophon ? <ColophonLink /> : null}
        <Primary>{cta}</Primary>
      </div>
    </Phone>
  );
}

function CurrentWelcome() {
  return (
    <Screen label="0w" cta="Get started">
      <Words />
    </Screen>
  );
}
function CurrentPrivacy() {
  return (
    <Screen label="0p" cta="Continue" privacy>
      <Words couplet />
    </Screen>
  );
}

function ChapterWelcome() {
  return (
    <Screen label="Pw" cta="Get started" top={<FolioBar page="01" />}>
      <Words />
    </Screen>
  );
}
function ChapterPrivacy() {
  return (
    <Screen label="Pp" cta="Continue" privacy top={<FolioBar page="02" />}>
      <Words couplet />
    </Screen>
  );
}

function SerifWelcome() {
  return (
    <Screen label="Sw" cta="Get started">
      <Words serif open />
    </Screen>
  );
}
function SerifPrivacy() {
  return (
    <Screen label="Sp" cta="Continue" privacy>
      <Words serif open couplet />
    </Screen>
  );
}

function SignatureWelcome() {
  return (
    <Screen label="Gw" cta="Get started">
      <Words />
    </Screen>
  );
}
function SignaturePrivacy() {
  return (
    <Screen
      label="Gp"
      cta="Continue"
      colophon
      gravity="low"
      top={<FolioBar page="02" dept="Privacy" />}
    >
      <Words couplet />
    </Screen>
  );
}

function InteriorWelcome() {
  return (
    <Screen label="Iw" cta="Get started" top={<FolioBar page="01" dept="" />}>
      <Words open />
    </Screen>
  );
}
function InteriorPrivacy() {
  return (
    <Screen label="Ip" cta="Continue" colophon top={<FolioBar page="02" dept="Privacy" />}>
      <Words open couplet />
    </Screen>
  );
}

function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="press"
        title="Current + publication"
        subtitle="封面/内页/章节线/衬线 · 页码不是步骤号 · 字保持白"
      >
        <DCPostIt top={-8} left={6} width={270} rotate={-1.1}>
          0 现稿。P 章节线+页码。S 衬线标题。G 封面对末页（含 H 的下落）。I 两页都当内页，Privacy 作栏头。
        </DCPostIt>
        <DCArtboard id="v-0" label="0 · Current" width={802} height={T.H}>
          <Pair label="0" left={<CurrentWelcome />} right={<CurrentPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-p" label="P · Chapter" width={802} height={T.H}>
          <Pair label="P" left={<ChapterWelcome />} right={<ChapterPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-s" label="S · Serif" width={802} height={T.H}>
          <Pair label="S" left={<SerifWelcome />} right={<SerifPrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-g" label="G · Signature" width={802} height={T.H}>
          <Pair label="G" left={<SignatureWelcome />} right={<SignaturePrivacy />} />
        </DCArtboard>
        <DCArtboard id="v-i" label="I · Interior" width={802} height={T.H}>
          <Pair label="I" left={<InteriorWelcome />} right={<InteriorPrivacy />} />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
