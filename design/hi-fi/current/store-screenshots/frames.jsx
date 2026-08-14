function headline(index) {
  const lines = window.titleLines(index);
  return (<><span className="line">{lines[0]}</span><span className="line">{lines[1]}</span></>);
}

const AJ_FRAMES = [
  { id: '01', screen: 'connected', layout: 'reveal', label: '01 · Reveal', file: '01-connected', h: headline(0) },
  { id: '02', screen: 'idle', layout: 'demo', label: '02 · Gesture', file: '02-idle', h: headline(1) },
  { id: '03', screen: 'add', layout: 'insight', label: '03 · Setup', file: '03-add-subscription', h: headline(2) },
  { id: '04', screen: 'location', layout: 'detail', label: '04 · Detail', file: '04-location', h: headline(3) },
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
