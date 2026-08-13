/* Round 2 — rethink Home composition around real vertical ConnectStage geometry */

/**
 * Diagnosis of Round 1 (discarded):
 * - Fake horizontal capsule destroyed product DNA
 * - Glass cards / docks were AI-generic chrome, not Routeva
 * - Merely reordering the same 3 bands ≠ better experience
 *
 * Real constraint: ConnectStage ≈ 300pt tall. Layout must treat it as an
 * instrument, not a bottom pill. Status must not fight the flags for hero.
 */

/** 0 · Current — shipping reference, craft-corrected */
function LayoutCurrent({ connected }) {
  return (
    <PhoneShell connected={connected} label={connected ? '0-c' : '0-i'}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Chrome light={connected} />
        <div style={{ paddingTop: 28 }}>
          {connected ? (
            <SessionStats />
          ) : (
            <>
              <CoverFlow />
              <div style={{ marginTop: 6 }}>
                <NodeCaption />
              </div>
            </>
          )}
        </div>
        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            gap: 12,
            minHeight: 0,
          }}
        >
          <StatusTitle text={connected ? 'Connected' : 'Not Connected'} />
          {connected ? (
            <>
              <NodeGlassRow light />
              <ModeChip light />
            </>
          ) : (
            <ModeChip />
          )}
        </div>
        <div style={{ paddingBottom: 8 }}>
          <ConnectStage connected={connected} scale={0.92} />
        </div>
      </div>
    </PhoneShell>
  );
}

/**
 * F · Instrument First
 * Capsule is the product face. Nodes are a quiet channel strip under chrome.
 * Status is one soft line above the instrument — not a second hero title.
 */
function LayoutInstrument({ connected }) {
  return (
    <PhoneShell connected={connected} label={connected ? 'F-c' : 'F-i'}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Chrome light={connected} />
        {connected ? (
          <div style={{ paddingTop: 20 }}>
            <SessionStats />
            <div
              style={{
                marginTop: 16,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 10,
              }}
            >
              <StatusTitle text="Connected" size={26} />
              <NodeGlassRow light />
              <ModeChip light quiet />
            </div>
            <div style={{ flex: 1 }} />
          </div>
        ) : (
          <div style={{ paddingTop: 6 }}>
            {/* Quiet channel strip */}
            <CoverFlow scale={0.82} height={96} step={64} base={48} />
            <div style={{ marginTop: 2 }}>
              <NodeCaption size={14} />
            </div>
            {/* Soft status — not competing with orbs */}
            <div style={{ marginTop: 18, textAlign: 'center' }}>
              <div
                style={{
                  fontSize: 13,
                  fontWeight: 600,
                  letterSpacing: '0.08em',
                  textTransform: 'uppercase',
                  color: HK.quiet,
                }}
              >
                Status
              </div>
              <div
                style={{
                  marginTop: 6,
                  fontSize: 22,
                  fontWeight: 650,
                  letterSpacing: '-0.025em',
                  color: 'rgba(255,255,255,0.88)',
                }}
              >
                Not Connected
              </div>
              <div style={{ marginTop: 10, display: 'flex', justifyContent: 'center' }}>
                <ModeChip quiet />
              </div>
            </div>
          </div>
        )}
        <div style={{ flex: 1, minHeight: 8 }} />
        {/* Instrument owns the lower field */}
        <div style={{ paddingBottom: 4 }}>
          <ConnectStage connected={connected} scale={1} />
        </div>
      </div>
    </PhoneShell>
  );
}

/**
 * G · Single Orb
 * One hero flag (product photography). Neighbors only peek.
 * Caption + status form one reading column above the instrument.
 */
function LayoutSingleOrb({ connected }) {
  return (
    <PhoneShell connected={connected} label={connected ? 'G-c' : 'G-i'}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Chrome light={connected} />
        {connected ? (
          <>
            <div style={{ paddingTop: 32 }}>
              <SessionStats />
            </div>
            <div
              style={{
                flex: 1,
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'center',
                alignItems: 'center',
                gap: 12,
              }}
            >
              <StatusTitle text="Connected" size={28} />
              <NodeGlassRow light />
              <ModeChip light quiet />
            </div>
          </>
        ) : (
          <>
            <div style={{ paddingTop: 36 }}>
              <HeroOrbStage />
            </div>
            <div
              style={{
                marginTop: 4,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 8,
              }}
            >
              <NodeCaption size={17} />
              <div
                style={{
                  fontSize: 14,
                  fontWeight: 500,
                  color: HK.muted,
                  letterSpacing: '0.01em',
                }}
              >
                Not Connected · <span style={{ color: 'rgba(255,255,255,0.7)' }}>Smart ›</span>
              </div>
            </div>
            <div style={{ flex: 1, minHeight: 12 }} />
          </>
        )}
        <div style={{ paddingBottom: 4 }}>
          <ConnectStage connected={connected} scale={0.94} />
        </div>
      </div>
    </PhoneShell>
  );
}

/**
 * H · Two Acts
 * Clear vertical split: Act 1 Select (upper) / Act 2 Connect (lower).
 * No glass dock — only a hairline and disciplined spacing.
 * Status lives with the instrument, not with the nodes.
 */
function LayoutTwoActs({ connected }) {
  return (
    <PhoneShell connected={connected} label={connected ? 'H-c' : 'H-i'}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Chrome light={connected} />
        {/* Act 1 */}
        <div
          style={{
            flex: '0 0 auto',
            paddingTop: connected ? 20 : 18,
            paddingBottom: 16,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 10,
          }}
        >
          {connected ? (
            <SessionStats compact />
          ) : (
            <>
              <CoverFlow scale={1.02} />
              <NodeCaption />
            </>
          )}
        </div>

        {/* hairline separator */}
        <div
          style={{
            height: 1,
            margin: '0 36px',
            background:
              'linear-gradient(90deg, transparent, rgba(255,255,255,0.14), transparent)',
          }}
        />

        {/* Act 2 — connect instrument cluster */}
        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'flex-start',
            paddingTop: 16,
            minHeight: 0,
          }}
        >
          <StatusTitle
            text={connected ? 'Connected' : 'Not Connected'}
            size={24}
            weight={650}
          />
          <div style={{ marginTop: 10 }}>
            {connected ? <NodeGlassRow light /> : <ModeChip quiet />}
          </div>
          {connected && (
            <div style={{ marginTop: 8 }}>
              <ModeChip light quiet />
            </div>
          )}
          <div style={{ marginTop: 4, flex: 1, display: 'flex', alignItems: 'flex-end', paddingBottom: 2 }}>
            <ConnectStage connected={connected} scale={0.9} />
          </div>
        </div>
      </div>
    </PhoneShell>
  );
}

/**
 * I · Field Whisper
 * Huge soft status as atmosphere (watermark), not chrome.
 * Sharp elements: orbs + capsule only. Mode is a caption footnote.
 */
function LayoutFieldWhisper({ connected }) {
  return (
    <PhoneShell connected={connected} label={connected ? 'I-c' : 'I-i'}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
        <Chrome light={connected} />

        {/* Watermark status */}
        {!connected && (
          <div
            aria-hidden
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: '38%',
              transform: 'translateY(-50%)',
              textAlign: 'center',
              fontSize: 42,
              fontWeight: 700,
              letterSpacing: '-0.045em',
              color: 'rgba(255,255,255,0.06)',
              pointerEvents: 'none',
              zIndex: 0,
              whiteSpace: 'nowrap',
            }}
          >
            Not Connected
          </div>
        )}

        {connected ? (
          <div style={{ paddingTop: 28, position: 'relative', zIndex: 1 }}>
            <SessionStats />
            <div
              style={{
                marginTop: 22,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 10,
              }}
            >
              <StatusTitle text="Connected" size={28} />
              <NodeGlassRow light />
              <ModeChip light quiet />
            </div>
          </div>
        ) : (
          <div style={{ paddingTop: 44, position: 'relative', zIndex: 1 }}>
            <CoverFlow scale={1.08} height={124} />
            <div style={{ marginTop: 10 }}>
              <NodeCaption size={16} />
            </div>
            <div
              style={{
                marginTop: 8,
                textAlign: 'center',
                fontSize: 13,
                fontWeight: 500,
                color: HK.muted,
              }}
            >
              Smart ›
            </div>
          </div>
        )}

        <div style={{ flex: 1, minHeight: 8 }} />
        <div style={{ paddingBottom: 4, position: 'relative', zIndex: 1 }}>
          <ConnectStage connected={connected} scale={0.96} />
        </div>
      </div>
    </PhoneShell>
  );
}

/**
 * J · Compact Rail + Full Instrument
 * Nodes as a top rail (almost toolbar). Everything else is the connect ritual.
 * Closest to "one-thumb VPN" without dropping Cover Flow.
 */
function LayoutCompactRail({ connected }) {
  return (
    <PhoneShell connected={connected} label={connected ? 'J-c' : 'J-i'}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <Chrome light={connected} />
        {connected ? (
          <div style={{ paddingTop: 16 }}>
            <SessionStats />
            <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
              <NodeGlassRow light />
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <StatusTitle text="Connected" size={20} weight={650} />
                <ModeChip light quiet />
              </div>
            </div>
          </div>
        ) : (
          <div style={{ paddingTop: 2 }}>
            <CoverFlow scale={0.78} height={88} step={60} base={46} />
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 10,
                marginTop: 4,
                padding: '0 24px',
              }}
            >
              <div style={{ minWidth: 0, flex: '0 1 auto' }}>
                <NodeCaption size={13} />
              </div>
            </div>
          </div>
        )}

        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 6,
            minHeight: 0,
          }}
        >
          {!connected && (
            <>
              <StatusTitle text="Not Connected" size={28} />
              <ModeChip quiet />
            </>
          )}
        </div>

        <div style={{ paddingBottom: 2 }}>
          <ConnectStage connected={connected} scale={1.02} />
        </div>
      </div>
    </PhoneShell>
  );
}

const ROUND2 = [
  {
    id: '0',
    name: 'Current',
    blurb: '现网结构 · craft 修正对照',
    Idle: () => <LayoutCurrent />,
    Conn: () => <LayoutCurrent connected />,
  },
  {
    id: 'F',
    name: 'Instrument',
    blurb: '胶囊作主仪表；节点降为顶栏频道条',
    Idle: () => <LayoutInstrument />,
    Conn: () => <LayoutInstrument connected />,
  },
  {
    id: 'G',
    name: 'Single Orb',
    blurb: '单枚英雄旗球；状态并入副文一行',
    Idle: () => <LayoutSingleOrb />,
    Conn: () => <LayoutSingleOrb connected />,
  },
  {
    id: 'H',
    name: 'Two Acts',
    blurb: '上选节点 / 下连接 · 发丝线分区无玻璃卡',
    Idle: () => <LayoutTwoActs />,
    Conn: () => <LayoutTwoActs connected />,
  },
  {
    id: 'I',
    name: 'Whisper',
    blurb: '状态作场域水印；锐利只留球与胶囊',
    Idle: () => <LayoutFieldWhisper />,
    Conn: () => <LayoutFieldWhisper connected />,
  },
  {
    id: 'J',
    name: 'Rail',
    blurb: '节点压成顶轨；中下全给连接仪式',
    Idle: () => <LayoutCompactRail />,
    Conn: () => <LayoutCompactRail connected />,
  },
];

function App() {
  return (
    <DesignCanvas>
      <DCSection
        id="r2-idle"
        title="Round 2 · Idle"
        subtitle="推翻 R1：纵向 ConnectStage 归位 · 去掉玻璃卡 · 重新定义谁是主视觉"
      >
        <DCPostIt top={-8} left={4} width={240} rotate={-1.2}>
          R1 失败点：假横条胶囊 + 挪位置 + 套玻璃。R2 按真实 300pt 仪表几何重构图。
        </DCPostIt>
        {ROUND2.map((v) => {
          const Idle = v.Idle;
          return (
            <DCArtboard
              key={`i-${v.id}`}
              id={`i-${v.id}`}
              label={`${v.id} · ${v.name} · Idle`}
              width={HK.W}
              height={HK.H}
            >
              <Idle />
            </DCArtboard>
          );
        })}
      </DCSection>

      <DCSection id="r2-conn" title="Round 2 · Connected" subtitle="同向在绿场下的表现">
        {ROUND2.map((v) => {
          const Conn = v.Conn;
          return (
            <DCArtboard
              key={`c-${v.id}`}
              id={`c-${v.id}`}
              label={`${v.id} · ${v.name} · Connected`}
              width={HK.W}
              height={HK.H}
            >
              <Conn />
            </DCArtboard>
          );
        })}
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
