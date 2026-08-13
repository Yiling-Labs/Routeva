/* Interactive motion spec: Idle → Connecting → Connected, and Connected → Idle. */
const { useEffect, useRef, useState } = React;
const EASE = 'cubic-bezier(0.22, 1, 0.36, 1)';

function MotionPhone({ phase }) {
  const idle = phase === 'idle';
  const busy = phase === 'connecting';
  const on = phase === 'connected';
  const t = (ms) => `${ms}ms ${EASE}`;

  const status = on ? 'Connected' : busy ? 'Connecting…' : 'Not Connected';
  const field = on
    ? `linear-gradient(180deg, ${C.greenTop}, ${C.greenBot})`
    : `linear-gradient(180deg, ${C.fieldTop}, ${C.fieldBot})`;

  return (
    <div
      className="motion"
      data-screen-label={'motion-' + phase}
      style={{
        width: C.W,
        height: C.H,
        borderRadius: 48,
        overflow: 'hidden',
        position: 'relative',
        background: field,
        transition: `background ${t(on ? 420 : 380)}`,
        boxShadow: '0 28px 70px rgba(0,0,0,0.38)',
        fontFamily: C.font,
        color: C.primary,
        userSelect: 'none',
      }}
    >
      <div
        aria-hidden
        style={{
          position: 'absolute',
          inset: 0,
          opacity: on ? 0.07 : 0.1,
          transition: `opacity ${t(400)}`,
          pointerEvents: 'none',
          backgroundImage: `url("data:image/svg+xml,${encodeURIComponent(
            `<svg xmlns='http://www.w3.org/2000/svg' width='400' height='300'><g fill='none' stroke='#fff' stroke-width='1' opacity='0.45'><ellipse cx='200' cy='148' rx='158' ry='88'/></g></svg>`
          )}")`,
          backgroundSize: '130% auto',
          backgroundPosition: 'center 42%',
        }}
      />
      <div
        style={{
          height: 54,
          padding: '14px 28px 0',
          display: 'flex',
          justifyContent: 'space-between',
          position: 'relative',
          zIndex: 8,
          fontSize: 15,
          fontWeight: 600,
        }}
      >
        <span>9:41</span>
        <span style={{ fontSize: 12, opacity: 0.92 }}>●●●●  Wi‑Fi  100%</span>
      </div>

      <div style={{ position: 'relative', zIndex: 5, height: C.H - 54 - 18, display: 'flex', flexDirection: 'column' }}>
        <ChromeRow light={on} settings={<SettingsOrb light={on} />} />

        {/* Upper: Cover Flow stays through Connecting; Stats only on Connected */}
        <div style={{ position: 'relative', height: 168, marginTop: 20 }}>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              opacity: on ? 0 : 1,
              transform: on ? 'scale(0.98) translateY(-6px)' : 'none',
              filter: on ? 'blur(4px)' : 'blur(0)',
              transition: `opacity ${t(280)}, transform ${t(320)}, filter ${t(280)}`,
              pointerEvents: on ? 'none' : 'auto',
            }}
          >
            <FrozenCoverFlow />
            <div
              style={{
                opacity: busy ? 0.42 : 1,
                transition: `opacity ${t(220)}`,
                pointerEvents: idle ? 'auto' : 'none',
              }}
            >
              <LocationCaptionHit />
            </div>
          </div>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              opacity: on ? 1 : 0,
              transform: on ? 'none' : 'translateY(10px)',
              transition: `opacity ${t(360)} ${on ? '80ms' : '0ms'}, transform ${t(360)} ${on ? '80ms' : '0ms'}`,
              pointerEvents: on ? 'auto' : 'none',
            }}
          >
            <FrozenStats />
          </div>
        </div>

        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 10,
            minHeight: 0,
          }}
        >
          <div
            key={status}
            style={{
              fontSize: 30,
              fontWeight: 700,
              letterSpacing: '-0.028em',
              animation: 'statusIn 280ms cubic-bezier(0.22, 1, 0.36, 1)',
            }}
          >
            {status}
          </div>

          {/* Idle Mode text — exits before Connecting settles */}
          <div
            style={{
              opacity: idle ? 1 : 0,
              transform: idle ? 'none' : 'translateY(-4px)',
              maxHeight: idle ? 48 : 0,
              overflow: 'hidden',
              transition: `opacity ${t(180)}, transform ${t(180)}, max-height ${t(220)}`,
              pointerEvents: idle ? 'auto' : 'none',
            }}
          >
            <div
              data-ctrl="mode"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
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
          </div>

          {/* Connected split bar — not during Connecting */}
          <div
            style={{
              width: '100%',
              display: 'flex',
              justifyContent: 'center',
              opacity: on ? 1 : 0,
              transform: on ? 'scale(1)' : 'scale(0.97) translateY(6px)',
              maxHeight: on ? 56 : 0,
              overflow: 'hidden',
              transition: `opacity ${t(380)} ${on ? '120ms' : '0ms'}, transform ${t(380)} ${on ? '120ms' : '0ms'}, max-height ${t(300)}`,
              pointerEvents: on ? 'auto' : 'none',
            }}
          >
            <SplitBar light />
          </div>
        </div>

        <div style={{ paddingBottom: 6 }}>
          <ConnectMotion phase={phase} />
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          bottom: 8,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 134,
          height: 5,
          borderRadius: 3,
          background: 'rgba(255,255,255,0.35)',
        }}
      />
      <style>{`
        @keyframes statusIn {
          from { opacity: 0; filter: blur(2px); transform: translateY(3px); }
          to { opacity: 1; filter: blur(0); transform: none; }
        }
        @media (prefers-reduced-motion: reduce) {
          @keyframes statusIn { from { opacity: 1; } to { opacity: 1; } }
        }
      `}</style>
    </div>
  );
}

function ConnectMotion({ phase }) {
  const on = phase === 'connected';
  const busy = phase === 'connecting';
  const scale = 0.9;
  const TRACK_W = 72 * scale;
  const TRACK_H = 188 * scale;
  const THUMB_H = 96 * scale;
  const PAD = 7 * scale;
  const INSET = 4 * scale;
  const THUMB_W = TRACK_W - INSET * 2;
  const Y_START = PAD;
  const Y_STOP = TRACK_H - THUMB_H - PAD;
  const y = on || busy ? Y_STOP : Y_START;
  const STAGE_W = 260 * scale;
  const STAGE_H = 292 * scale;
  const trackLeft = (STAGE_W - TRACK_W) / 2;
  const trackTop = Math.round((STAGE_H - TRACK_H) * 0.42);
  const Power = (window.RoutevaIcons || {}).IconPower;
  const thumbBg = on
    ? 'linear-gradient(165deg, #b6f5d6 0%, #6ed4a6 38%, #3fb887 72%, #2a9a6c 100%)'
    : busy
      ? 'linear-gradient(165deg, #3e4c48 0%, #222c2a 48%, #161c1c 100%)'
      : 'linear-gradient(165deg, #5a626c 0%, #2c333b 40%, #14181c 100%)';
  const fg = on ? 'rgba(6,28,20,0.92)' : 'rgba(255,255,255,0.94)';
  const ignite = on ? 1 : busy ? 0.85 : 0;

  return (
    <div data-ctrl="connect" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ position: 'relative', width: STAGE_W, height: STAGE_H }}>
        <div
          aria-hidden
          style={{
            position: 'absolute',
            left: '50%',
            bottom: STAGE_H * 0.1,
            width: 150 * scale,
            height: 150 * scale,
            marginLeft: -75 * scale,
            borderRadius: '50%',
            boxShadow: `0 0 0 20px rgba(110,212,166,${0.06 * ignite}), 0 0 0 40px rgba(110,212,166,${0.04 * ignite})`,
            opacity: ignite,
            transition: 'opacity 700ms cubic-bezier(0.22, 1, 0.36, 1), box-shadow 700ms cubic-bezier(0.22, 1, 0.36, 1)',
            pointerEvents: 'none',
          }}
        />
        <div
          style={{
            position: 'absolute',
            left: trackLeft,
            top: trackTop,
            width: TRACK_W,
            height: TRACK_H,
            borderRadius: 999,
            background: on
              ? 'linear-gradient(180deg, rgba(12,36,28,0.5), rgba(6,20,16,0.78))'
              : 'linear-gradient(180deg, rgba(255,255,255,0.14), rgba(6,8,10,0.55) 60%, rgba(0,0,0,0.62))',
            boxShadow: on
              ? 'inset 0 2px 18px rgba(0,0,0,0.42), 0 0 0 1px rgba(120,255,190,0.16)'
              : 'inset 0 2px 20px rgba(0,0,0,0.58), 0 0 0 1px rgba(255,255,255,0.1)',
            transition: 'background 480ms cubic-bezier(0.22, 1, 0.36, 1), box-shadow 480ms cubic-bezier(0.22, 1, 0.36, 1)',
          }}
        >
          <div
            style={{
              position: 'absolute',
              left: INSET,
              top: y,
              width: THUMB_W,
              height: THUMB_H,
              borderRadius: 999,
              background: thumbBg,
              boxShadow: on
                ? '0 14px 36px rgba(30,190,120,0.42), inset 0 1.5px 0 rgba(255,255,255,0.62)'
                : '0 14px 34px rgba(0,0,0,0.48), inset 0 1.5px 0 rgba(255,255,255,0.28)',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 7 * scale,
              color: fg,
              transition: 'top 480ms cubic-bezier(0.22, 1, 0.36, 1), background 400ms cubic-bezier(0.22, 1, 0.36, 1), box-shadow 400ms cubic-bezier(0.22, 1, 0.36, 1), color 400ms cubic-bezier(0.22, 1, 0.36, 1)',
              animation: busy ? 'thumb-busy 1.1s ease-in-out infinite' : 'none',
            }}
          >
            <div
              style={{
                position: 'absolute',
                top: 13 * scale,
                width: 7 * scale,
                height: 7 * scale,
                borderRadius: '50%',
                background: on || busy ? 'rgba(50,255,130,0.95)' : 'rgba(28,36,32,0.95)',
                boxShadow: on || busy ? '0 0 12px rgba(50,255,130,0.7)' : 'none',
                transition: 'background 400ms, box-shadow 400ms',
              }}
            />
            <span style={{ fontSize: 12 * scale, fontWeight: 800, letterSpacing: '0.12em', marginTop: 8 * scale }}>
              {busy ? '…' : on ? 'STOP' : 'START'}
            </span>
            {Power ? <Power size={22 * scale} stroke={2} color="currentColor" /> : <span>⏻</span>}
          </div>
        </div>
      </div>
      <div style={{ fontSize: 13, fontWeight: 500, color: C.muted, marginTop: -4 }}>
        {on ? 'Swipe up to stop' : busy ? 'Connecting…' : 'Swipe down to connect'}
      </div>
      <style>{`
        @keyframes thumb-busy {
          0%, 100% { opacity: 0.72; }
          50% { opacity: 1; }
        }
      `}</style>
    </div>
  );
}

function App() {
  const [phase, setPhase] = useState('idle');
  const [playing, setPlaying] = useState(null);
  const timers = useRef([]);

  const clear = () => {
    timers.current.forEach(clearTimeout);
    timers.current = [];
    setPlaying(null);
  };

  const later = (fn, ms) => {
    const id = setTimeout(fn, ms);
    timers.current.push(id);
  };

  useEffect(() => () => clear(), []);

  const playForward = () => {
    clear();
    setPlaying('fwd');
    setPhase('idle');
    later(() => setPhase('connecting'), 400);
    later(() => setPhase('connected'), 400 + 1100);
    later(() => setPlaying(null), 400 + 1100 + 700);
  };

  const playReverse = () => {
    clear();
    setPlaying('rev');
    setPhase('connected');
    later(() => setPhase('idle'), 500);
    later(() => setPlaying(null), 500 + 700);
  };

  const playLoop = () => {
    clear();
    setPlaying('loop');
    const cycle = () => {
      setPhase('idle');
      later(() => setPhase('connecting'), 500);
      later(() => setPhase('connected'), 500 + 1100);
      later(() => setPhase('idle'), 500 + 1100 + 1600);
      later(cycle, 500 + 1100 + 1600 + 900);
    };
    cycle();
  };

  return (
    <div className="wrap">
      <MotionPhone phase={phase} />
      <div className="spec">
        <h1>连接态过渡</h1>
        <p>
          定稿四控件在 <strong>Idle → Connecting → Connected</strong> 的编排。
          反向产品路径是 <strong>Connected → Idle</strong>（不断开途经 Connecting）。
          曲线一律 <code>cubic-bezier(0.22, 1, 0.36, 1)</code>。
        </p>
        <div className="btns">
          <button type="button" data-on={phase === 'idle' ? '1' : '0'} onClick={() => { clear(); setPhase('idle'); }}>Idle</button>
          <button type="button" data-on={phase === 'connecting' ? '1' : '0'} onClick={() => { clear(); setPhase('connecting'); }}>Connecting</button>
          <button type="button" data-on={phase === 'connected' ? '1' : '0'} onClick={() => { clear(); setPhase('connected'); }}>Connected</button>
          <button type="button" data-on={playing === 'fwd' ? '1' : '0'} onClick={playForward}>播放正向</button>
          <button type="button" data-on={playing === 'rev' ? '1' : '0'} onClick={playReverse}>播放反向</button>
          <button type="button" data-on={playing === 'loop' ? '1' : '0'} onClick={playLoop}>循环</button>
        </div>

        <div className="tl">
          <div className="beat" data-on={phase === 'connecting' && playing === 'fwd' ? '1' : '0'}>
            <b>1 · Idle → Connecting · ~0.2–0.9s</b>
            <span>
              拇指滑到 STOP 座，灯/环点亮（~850ms）。状态字交叉淡入 *Connecting…*（280ms + 2px blur）。
              <strong> Mode 先退场</strong>（180ms 上移淡出）。Location <strong>不搬家</strong>，仍在球下，降到 42% 并锁点。
              Settings 不动。场域仍黑。Cover Flow 留下。
            </span>
          </div>
          <div className="beat" data-on={phase === 'connected' && playing !== 'rev' ? '1' : '0'}>
            <b>2 · Connecting → Connected · ~0.42s 主拍</b>
            <span>
              整屏黑→绿交叉淡入（420ms）。Cover Flow + 球下 Location 一起淡出并微缩/微糊（280ms）——
              <strong>不把名字飞到中间</strong>。时长从上方 80ms 后淡入。
              *Connected* 换字。120ms 后 <strong>整条</strong> Location|Mode 以 0.97→1 出现（380ms）。
              Mode 不单独飞入，只作为条的右半。胶囊已在底部，镀层变薄荷。
            </span>
          </div>
          <div className="beat" data-on={playing === 'rev' || (phase === 'idle' && playing !== 'fwd') ? '1' : '0'}>
            <b>3 · Connected → Idle · ~0.48s（产品反向，无 Connecting）</b>
            <span>
              绿→黑 380ms。条 <strong>先收</strong>（200ms，快于进场）。时长淡出，Cover Flow 回来。
              球下 Location 晚 120ms 淡入。Mode 文本等条消失后再出现（~180ms），避免两条 Mode。
              拇指上滑、环熄（480ms）。失败回 Idle 同此拍，可再叠 toast。
            </span>
          </div>
          <div className="beat">
            <b>减动 / 禁止</b>
            <span>
              <code>prefers-reduced-motion</code>：只做透明度交叉，无位移、无模糊、无拇指滑动插值。
              禁止 Location 做共享元素抛物线；禁止 Connecting 中途把条滑出来；禁止弹跳。
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
