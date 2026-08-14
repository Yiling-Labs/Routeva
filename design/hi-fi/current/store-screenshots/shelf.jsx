const { AJ_FRAMES, FrameAJ } = window;

function Shelf() {
  return (
    <div className="shelf">
      <header className="shelf-hero">
        <p className="shelf-kicker">Routeva · App Store · A · Jobs</p>
        <h1>One idea. Then stop talking.</h1>
        <p className="shelf-lede">
          Current set. Four frames. Shared baseline.
          <a href="./index.html"> Open the canvas</a>
        </p>
      </header>
      <section className="shelf-row" data-screen-label="A · Jobs">
        <header>
          <h2>A · Jobs</h2>
          <p>Reveal · Gesture · Setup · Detail.</p>
        </header>
        <div className="shelf-track">
          {AJ_FRAMES.map((item) => (
            <div className="shelf-card" key={item.id}>
              <FrameAJ item={item} />
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Shelf />);
