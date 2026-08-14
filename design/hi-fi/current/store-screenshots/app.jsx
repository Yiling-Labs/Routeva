const { DesignCanvas, DCSection, DCArtboard } = window;
const { AJ_FRAMES, FrameAJ } = window;

function App() {
  return (
    <DesignCanvas>
      <DCSection id="aj" title="A · Jobs" subtitle="现行商店截图。01 结果 · 02 一滑 · 03 设置 · 04 选节点。">
        {AJ_FRAMES.map((item) => (
          <DCArtboard key={item.id} id={item.id} label={item.label} width={430} height={932}>
            <FrameAJ item={item} />
          </DCArtboard>
        ))}
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
