const AJ_FRAMES = [
  {
    id: '01',
    screen: 'connected',
    layout: 'reveal',
    label: '01 · Reveal',
    file: '01-connected',
    h: (<><span className="line">Connect without</span><span className="line">the maze.</span></>),
  },
  {
    id: '02',
    screen: 'idle',
    layout: 'demo',
    label: '02 · Gesture',
    file: '02-idle',
    h: (<><span className="line">Swipe once</span><span className="line">to go online.</span></>),
  },
  {
    id: '03',
    screen: 'add',
    layout: 'insight',
    label: '03 · Setup',
    file: '03-add-subscription',
    h: (<><span className="line">Paste a link</span><span className="line">to set up.</span></>),
  },
  {
    id: '04',
    screen: 'location',
    layout: 'detail',
    label: '04 · Detail',
    file: '04-location',
    h: (<><span className="line">Pick the</span><span className="line">fastest one.</span></>),
  },
];

function Screen({ name }) {
  const Comp = window.RVScreens[name];
  return Comp ? <Comp /> : null;
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

Object.assign(window, { AJ_FRAMES, FrameAJ, Screen });
