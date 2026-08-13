/* Four-control exploration. Frozen: field, Cover Flow, timer, status title, Subscriptions. */

function V0({ connected }) {
  return (
    <HomeFrame
      connected={connected}
      settings={<SettingsOrb light={connected} />}
      locationIdle={<LocationCaption />}
      locationOn={<LocationPill light />}
      mode={<ModeText />}
      connect={<ConnectStage connected={connected} />}
    />
  );
}

function VTwin({ connected }) {
  return (
    <HomeFrame
      connected={connected}
      settings={<SettingsOrb light={connected} size={44} />}
      locationIdle={
        <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 10 }}>
          <LocationPill light={false} />
        </div>
      }
      locationOn={null}
      mode={
        <div style={{ display: 'flex', gap: 8, justifyContent: 'center', flexWrap: 'wrap', padding: '0 20px' }}>
          {connected && <LocationPill light />}
          <ModeChip light={connected} />
        </div>
      }
      connect={<ConnectStage connected={connected} scale={0.9} />}
    />
  );
}

function VFlanks({ connected }) {
  return (
    <Phone connected={connected} label={connected ? 'B-c' : 'B-i'}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <ChromeRow light={connected} settings={<SettingsOrb light={connected} size={44} />} />
        <div style={{ paddingTop: 36 }}>
          {connected ? <FrozenStats /> : <FrozenCoverFlow />}
          {!connected && (
            <div style={{ opacity: 0.55, pointerEvents: 'none' }}>
              <div style={{ textAlign: 'center', paddingTop: 8, fontSize: 13, fontWeight: 600, color: 'rgba(255,255,255,0.72)' }}>
                {NODE.name}
              </div>
            </div>
          )}
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
          <FrozenStatus connected={connected} />
        </div>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1fr auto 1fr',
            alignItems: 'center',
            padding: '0 16px 8px',
            gap: 4,
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <div style={{ transform: 'scale(0.92)', transformOrigin: 'right center' }}>
              {connected ? <LocationPill light /> : <LocationPill light={false} />}
            </div>
          </div>
          <ConnectStage connected={connected} scale={0.86} />
          <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
            <ModeChip light={connected} />
          </div>
        </div>
      </div>
    </Phone>
  );
}

function VOrbs({ connected }) {
  return (
    <HomeFrame
      connected={connected}
      settings={<SettingsOrb light={connected} size={44} />}
      locationIdle={
        <div style={{ textAlign: 'center', paddingTop: 8, fontSize: 13, fontWeight: 500, color: 'rgba(255,255,255,0.55)' }}>
          {NODE.proto} · {NODE.ms}ms
        </div>
      }
      locationOn={null}
      mode={
        <div style={{ display: 'flex', gap: 22, alignItems: 'flex-start', justifyContent: 'center', paddingTop: 4 }}>
          <LocationOrb light={connected} />
          <ModeOrb light={connected} />
        </div>
      }
      connect={<ConnectStage connected={connected} scale={0.86} jewel />}
    />
  );
}

function VSplit({ connected }) {
  return (
    <HomeFrame
      connected={connected}
      settings={<SettingsChip light={connected} />}
      locationIdle={null}
      locationOn={null}
      mode={
        <div
          data-ctrl="location-mode"
          style={Object.assign(
            {
              display: 'flex',
              alignItems: 'stretch',
              maxWidth: 320,
              borderRadius: 999,
              overflow: 'hidden',
            },
            {
              background: connected
                ? 'linear-gradient(160deg, rgba(255,255,255,0.26), rgba(255,255,255,0.1))'
                : 'linear-gradient(160deg, rgba(255,255,255,0.16), rgba(255,255,255,0.06))',
              border: '0.5px solid rgba(255,255,255,0.16)',
              boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.22)',
              backdropFilter: 'blur(18px)',
            }
          )}
        >
          <div
            data-ctrl="location"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              padding: '10px 14px 10px 16px',
              minWidth: 0,
              flex: 1,
              fontSize: 13,
              fontWeight: 600,
            }}
          >
            <img src={`https://flagcdn.com/w160/${NODE.cc}.png`} alt="" style={{ width: 18, height: 18, borderRadius: '50%', objectFit: 'cover', flexShrink: 0 }} />
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{NODE.name}</span>
            <span style={{ color: C.quiet, flexShrink: 0 }}>›</span>
          </div>
          <div style={{ width: 1, margin: '8px 0', background: 'rgba(255,255,255,0.16)' }} />
          <div
            data-ctrl="mode"
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 5,
              padding: '10px 16px 10px 14px',
              flexShrink: 0,
              fontSize: 13,
              fontWeight: 600,
              color: C.secondary,
            }}
          >
            <span style={{ color: C.quiet }}>Mode</span>
            Smart
            <span style={{ color: C.quiet, fontSize: 10 }}>›</span>
          </div>
        </div>
      }
      connect={<ConnectStage connected={connected} scale={0.9} />}
    />
  );
}

function VJewel({ connected }) {
  return (
    <HomeFrame
      connected={connected}
      settings={<SettingsOrb light={connected} size={44} />}
      locationIdle={
        <div style={{ paddingTop: 4 }}>
          <LocationCaption />
        </div>
      }
      locationOn={
        <div style={{ padding: '4px 0' }}>
          <LocationPill light />
        </div>
      }
      mode={
        <div style={{ padding: '4px 16px 8px' }}>
          <ModeText />
        </div>
      }
      connect={<ConnectStage connected={connected} scale={0.88} jewel />}
    />
  );
}

const VARIANTS = [
  { id: '0', name: 'Current', blurb: '现网对照', Idle: () => <V0 />, Conn: () => <V0 connected /> },
  { id: 'A', name: 'Twin chips', blurb: 'Location + Mode 同族 chip', Idle: () => <VTwin />, Conn: () => <VTwin connected /> },
  { id: 'B', name: 'Flanks', blurb: '节点 / Mode 分列胶囊两侧', Idle: () => <VFlanks />, Conn: () => <VFlanks connected /> },
  { id: 'C', name: 'Orb family', blurb: '三枚同尺 orb + 收细胶囊', Idle: () => <VOrbs />, Conn: () => <VOrbs connected /> },
  { id: 'D', name: 'Split bar', blurb: '一条玻璃条切节点 | Mode', Idle: () => <VSplit />, Conn: () => <VSplit connected /> },
  { id: 'E', name: 'Jewel', blurb: '仪表胶囊 + 更大热区文本', Idle: () => <VJewel />, Conn: () => <VJewel connected /> },
];

function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="idle"
        title="四控件 · Idle"
        subtitle="只改 Settings / Location / Mode / Connect · Cover Flow、时长、状态大字、Subscriptions 冻结"
      >
        <DCPostIt top={-10} left={4} width={230} rotate={-1.4}>
          交互闭集不变：Settings→设置 · Location→节点列表 · Mode→模式 sheet · 下滑连接 / 上滑断开
        </DCPostIt>
        {VARIANTS.map((v) => {
          const Idle = v.Idle;
          return (
            <DCArtboard key={'i' + v.id} id={'i-' + v.id} label={v.id + ' · ' + v.name + ' · Idle'} width={C.W} height={C.H}>
              <Idle />
            </DCArtboard>
          );
        })}
      </DCSection>
      <DCSection id="conn" title="四控件 · Connected" subtitle="绿场下同一套控件语言">
        {VARIANTS.map((v) => {
          const Conn = v.Conn;
          return (
            <DCArtboard key={'c' + v.id} id={'c-' + v.id} label={v.id + ' · ' + v.name + ' · Connected'} width={C.W} height={C.H}>
              <Conn />
            </DCArtboard>
          );
        })}
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
