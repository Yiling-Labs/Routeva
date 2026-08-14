const { RVScreens } = window;

const A_COPY = [
  { id: 'a01', screen: 'connected', kicker: '01', h: 'Connect without the maze.', s: 'Swipe once. Get a connection that actually checks out.' },
  { id: 'a02', screen: 'idle', kicker: '02', h: 'Swipe to go online.', s: 'Down to connect. Up to stop.' },
  { id: 'a03', screen: 'add', kicker: '03', h: 'Easy to set up.', s: 'Paste a link you already have.' },
  { id: 'a04', screen: 'location', kicker: '04', h: 'Prefer a faster node.', s: 'Your nodes, sorted by latency.' },
];
const AJ_COPY = [
  { id: 'aj01', screen: 'connected', layout: 'reveal', h: (<><span className="line">Connect without</span><span className="line">the maze.</span></>) },
  { id: 'aj02', screen: 'idle', layout: 'demo', h: (<><span className="line">Swipe once</span><span className="line">to go online.</span></>) },
  { id: 'aj03', screen: 'add', layout: 'insight', h: (<><span className="line">Paste a link</span><span className="line">to set up.</span></>) },
  { id: 'aj04', screen: 'location', layout: 'detail', h: (<><span className="line">Pick the</span><span className="line">fastest one.</span></>) },
];
const AR_COPY = [
  { id: 'ar01', screen: 'connected', layout: 'hook', h: (<><span className="line">Connect without</span><span className="line">the maze.</span></>), s: 'Swipe once. Get a connection that actually checks out.' },
  { id: 'ar02', screen: 'idle', layout: 'gesture', h: 'Swipe to go online.', s: 'Down to connect. Up to stop.' },
  { id: 'ar03', screen: 'add', layout: 'qualify', h: 'Easy to set up.', s: 'Paste a link you already have.' },
  { id: 'ar04', screen: 'location', layout: 'control', h: (<><span className="line">Prefer a</span><span className="line">faster node.</span></>), s: 'Your nodes, sorted by latency.' },
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
      <div className="shot-a-device"><Screen name={item.screen} /></div>
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
      <div className="shot-b-device"><Screen name={item.screen} /></div>
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
      <div className="shot-c-device"><Screen name={item.screen} /></div>
    </div>
  );
}

function Row({ title, lede, children }) {
  return (
    <section className="shelf-row" data-screen-label={title}>
      <header>
        <h2>{title}</h2>
        <p>{lede}</p>
      </header>
      <div className="shelf-track">{children}</div>
    </section>
  );
}

function Card({ children }) {
  return <div className="shelf-card">{children}</div>;
}

function Shelf() {
  return (
    <div className="shelf">
      <header className="shelf-hero">
        <p className="shelf-kicker">Routeva · App Store candidates</p>
        <h1>One idea. Then stop talking.</h1>
        <p className="shelf-lede">
          Four frames. Swipe before setup. No connecting close.
          <a href="./index.html"> Open the canvas</a>
        </p>
      </header>
      <Row title="A · Jobs" lede="One idea each. Two lines. Shared baseline.">
        {AJ_COPY.map((item) => <Card key={item.id}><FrameAJ item={item} /></Card>)}
      </Row>
      <Row title="A · Refined" lede="Previous production pass.">
        {AR_COPY.map((item) => <Card key={item.id}><FrameAR item={item} /></Card>)}
      </Row>
      <Row title="A · v1" lede="Previous pass — kept only to see the delta.">
        {A_COPY.map((item) => <Card key={item.id}><FrameA item={item} /></Card>)}
      </Row>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Shelf />);
