const { DesignCanvas, DCSection, DCArtboard, DCPostIt } = window;
const { RVScreens } = window;

const W = 430;
const H = 932;

const A_COPY = [
  { id: 'a01', screen: 'connected', kicker: '01 · Hook', h: 'Connect without the maze.', s: 'Swipe once. Get a connection that actually checks out.' },
  { id: 'a02', screen: 'idle', kicker: '02 · Gesture', h: 'Swipe to go online.', s: 'Down to connect. Up to stop.' },
  { id: 'a03', screen: 'add', kicker: '03 · Setup', h: 'Easy to set up.', s: 'Paste a link you already have.' },
  { id: 'a04', screen: 'location', kicker: '04 · Control', h: 'Prefer a faster node.', s: 'Your nodes, sorted by latency.' },
];

const AJ_COPY = [
  {
    id: 'aj01', screen: 'connected', layout: 'reveal', label: '01 · Reveal',
    h: (<><span className="line">Connect without</span><span className="line">the maze.</span></>),
  },
  {
    id: 'aj02', screen: 'idle', layout: 'demo', label: '02 · Gesture',
    h: (<><span className="line">Swipe once</span><span className="line">to go online.</span></>),
  },
  {
    id: 'aj03', screen: 'add', layout: 'insight', label: '03 · Setup',
    h: (<><span className="line">Paste a link</span><span className="line">to set up.</span></>),
  },
  {
    id: 'aj04', screen: 'location', layout: 'detail', label: '04 · Detail',
    h: (<><span className="line">Pick the</span><span className="line">fastest one.</span></>),
  },
];

const AR_COPY = [
  {
    id: 'ar01', screen: 'connected', layout: 'hook', label: '01 · Hook',
    h: (<><span className="line">Connect without</span><span className="line">the maze.</span></>),
    s: 'Swipe once. Get a connection that actually checks out.',
  },
  {
    id: 'ar02', screen: 'idle', layout: 'gesture', label: '02 · Gesture',
    h: 'Swipe to go online.',
    s: 'Down to connect. Up to stop.',
  },
  {
    id: 'ar03', screen: 'add', layout: 'qualify', label: '03 · Setup',
    h: 'Easy to set up.',
    s: 'Paste a link you already have.',
  },
  {
    id: 'ar04', screen: 'location', layout: 'control', label: '04 · Control',
    h: (<><span className="line">Prefer a</span><span className="line">faster node.</span></>),
    s: 'Your nodes, sorted by latency.',
  },
];

const B_COPY = [
  { id: 'b01', screen: 'connected', word: 'CONNECTED' },
  { id: 'b02', screen: 'idle', word: 'SWIPE' },
  { id: 'b03', screen: 'add', word: 'PASTE' },
  { id: 'b04', screen: 'location', word: 'NODES' },
];

const C_COPY = [
  { id: 'c01', screen: 'connected', h: 'Connected', s: 'Real path' },
  { id: 'c02', screen: 'idle', h: 'Swipe', s: 'Once' },
  { id: 'c03', screen: 'add', h: 'Paste Link', s: 'Your plan' },
  { id: 'c04', screen: 'location', h: 'Faster Node', s: 'Your list' },
];

function Screen({ name }) {
  const Comp = RVScreens[name];
  return Comp ? <Comp /> : null;
}

function FrameA({ item }) {
  return (
    <div className="shot shot-a" data-screen-label={'A-' + item.id}>
      <div className="shot-a-copy">
        <p className="shot-kicker">{item.kicker}</p>
        <h2>{item.h}</h2>
        <p className="shot-sub">{item.s}</p>
      </div>
      <div className="shot-a-device">
        <Screen name={item.screen} />
      </div>
    </div>
  );
}

function FrameAR({ item }) {
  return (
    <div className={'shot shot-ar is-' + item.layout} data-screen-label={'AR-' + item.id}>
      <div className="ar-copy">
        <h2>{item.h}</h2>
        <p className="ar-sub">{item.s}</p>
      </div>
      <div className="ar-stage">
        <div className="ar-device">
          <Screen name={item.screen} />
        </div>
      </div>
    </div>
  );
}

function FrameAJ({ item }) {
  return (
    <div className={'shot shot-aj is-' + item.layout} data-screen-label={'AJ-' + item.id}>
      <div className="aj-copy">
        <h2>{item.h}</h2>
      </div>
      <div className="aj-stage">
        <div className="ar-device">
          <Screen name={item.screen} />
        </div>
      </div>
    </div>
  );
}

function FrameB({ item }) {
  return (
    <div className="shot shot-b" data-screen-label={'B-' + item.id}>
      <div className="shot-b-word">{item.word}</div>
      <div className="shot-b-device">
        <Screen name={item.screen} />
      </div>
    </div>
  );
}

function FrameC({ item }) {
  return (
    <div className="shot shot-c" data-screen-label={'C-' + item.id}>
      <div className="shot-c-copy">
        <h2>{item.h}</h2>
        <p>{item.s}</p>
      </div>
      <div className="shot-c-device">
        <Screen name={item.screen} />
      </div>
    </div>
  );
}

function App() {
  return (
    <DesignCanvas>
      <DCSection id="aj" title="A · Jobs" subtitle="四张。01 结果 · 02 一滑 · 03 设置 · 04 选节点。">
        {AJ_COPY.map((item) => (
          <DCArtboard key={item.id} id={item.id} label={item.label} width={W} height={H}>
            <FrameAJ item={item} />
          </DCArtboard>
        ))}
      </DCSection>
      <DCSection id="ar" title="A · Refined" subtitle="上一轮生产向 · 对照">
        {AR_COPY.map((item) => (
          <DCArtboard key={item.id} id={item.id} label={item.label} width={W} height={H}>
            <FrameAR item={item} />
          </DCArtboard>
        ))}
      </DCSection>
      <DCSection id="a" title="A · v1 archive" subtitle="精修前 · 对照用">
        {A_COPY.map((item) => (
          <DCArtboard key={item.id} id={item.id} label={item.kicker} width={W} height={H}>
            <FrameA item={item} />
          </DCArtboard>
        ))}
      </DCSection>
      <DCSection id="b" title="B · Instrument Quiet" subtitle="Surge / 小火箭的克制 · 标题缩成一词 · 绿场自己说话">
        {B_COPY.map((item) => (
          <DCArtboard key={item.id} id={item.id} label={'B · ' + item.word} width={W} height={H}>
            <FrameB item={item} />
          </DCArtboard>
        ))}
      </DCSection>
      <DCSection id="c" title="C · Capability Nouns" subtitle="QX 短名词骨架 · 只写 Paste / Swipe / Node / Check · 不写 MitM / OTT">
        {C_COPY.map((item) => (
          <DCArtboard key={item.id} id={item.id} label={'C · ' + item.h} width={W} height={H}>
            <FrameC item={item} />
          </DCArtboard>
        ))}
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
