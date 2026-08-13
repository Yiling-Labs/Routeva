/* Ship composite: 0 Idle location + D Connected split bar + E jewel capsule. Settings stays orb. */

function ModeTextHit() {
  return (
    <div
      data-ctrl="mode"
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 5,
        minHeight: 44,
        padding: '10px 16px',
        fontSize: 12,
        fontWeight: 600,
        color: C.secondary,
      }}
    >
      <span style={{ color: C.quiet }}>Mode</span>
      Smart
      <span style={{ fontSize: 9, color: C.quiet }}>›</span>
    </div>
  );
}

function ShipIdle() {
  return (
    <HomeFrame
      connected={false}
      settings={<SettingsOrb light={false} />}
      locationIdle={<LocationCaptionHit />}
      locationOn={null}
      mode={<ModeTextHit />}
      connect={<ConnectStage connected={false} scale={0.9} jewel />}
    />
  );
}

function ShipConnected() {
  return (
    <HomeFrame
      connected
      settings={<SettingsOrb light />}
      locationIdle={null}
      locationOn={null}
      mode={<SplitBar light />}
      connect={<ConnectStage connected scale={0.9} jewel />}
    />
  );
}

function ShipConnecting() {
  return (
    <HomeFrame
      connected={false}
      settings={<SettingsOrb />}
      locationIdle={
        <div style={{ opacity: 0.45, pointerEvents: 'none' }}>
          <LocationCaptionHit />
        </div>
      }
      locationOn={null}
      mode={null}
      statusTitle="Connecting…"
      connect={<ConnectStage connected={false} scale={0.9} jewel />}
    />
  );
}

function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="ship"
        title="精修定稿 · 0 + D + E"
        subtitle="Idle 球下 Location · 绿场一条 Location|Mode · Settings 仍是 orb · 胶囊 Jewel"
      >
        <DCPostIt top={-8} left={6} width={240} rotate={-1.2}>
          不改 Cover Flow / 时长 / 状态大字 / Subscriptions。Idle 禁止中部 Location pill。
        </DCPostIt>
        <DCArtboard id="ship-idle" label="Ship · Idle" width={C.W} height={C.H}>
          <ShipIdle />
        </DCArtboard>
        <DCArtboard id="ship-conn" label="Ship · Connected" width={C.W} height={C.H}>
          <ShipConnected />
        </DCArtboard>
        <DCArtboard id="ship-busy" label="Ship · Connecting（Mode 隐藏）" width={C.W} height={C.H}>
          <ShipConnecting />
        </DCArtboard>
      </DCSection>

      <DCSection id="vs" title="对照 · 现网 vs 定稿" subtitle="只看四个控件差在哪">
        <DCArtboard id="vs-0-i" label="0 · Current · Idle" width={C.W} height={C.H}>
          <HomeFrame
            connected={false}
            settings={<SettingsOrb />}
            locationIdle={<LocationCaption />}
            locationOn={null}
            mode={<ModeText />}
            connect={<ConnectStage connected={false} />}
          />
        </DCArtboard>
        <DCArtboard id="vs-s-i" label="Ship · Idle" width={C.W} height={C.H}>
          <ShipIdle />
        </DCArtboard>
        <DCArtboard id="vs-0-c" label="0 · Current · Connected" width={C.W} height={C.H}>
          <HomeFrame
            connected
            settings={<SettingsOrb light />}
            locationIdle={null}
            locationOn={<LocationPill light />}
            mode={<ModeText />}
            connect={<ConnectStage connected />}
          />
        </DCArtboard>
        <DCArtboard id="vs-s-c" label="Ship · Connected" width={C.W} height={C.H}>
          <ShipConnected />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
