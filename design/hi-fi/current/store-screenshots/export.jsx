const { AJ_FRAMES, FrameAJ } = window;

const id = new URLSearchParams(window.location.search).get('id') || '01';
const item = AJ_FRAMES.find((frame) => frame.id === id) || AJ_FRAMES[0];

function markReady() {
  const waitFonts = document.fonts ? document.fonts.ready : Promise.resolve();
  const images = Array.from(document.images);
  const waitImages = Promise.all(images.map((img) => {
    if (img.complete) return Promise.resolve();
    return new Promise((resolve) => {
      img.addEventListener('load', resolve, { once: true });
      img.addEventListener('error', resolve, { once: true });
    });
  }));
  Promise.all([waitFonts, waitImages]).then(() => {
    document.documentElement.dataset.ready = '1';
  });
}

function ExportShot() {
  React.useEffect(markReady, []);
  return <FrameAJ item={item} />;
}

ReactDOM.createRoot(document.getElementById('root')).render(<ExportShot />);
