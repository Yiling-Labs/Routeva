import { spawn } from "node:child_process";
import { mkdir, writeFile, unlink, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const assets = path.join(root, "assets");
const chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const icons = [
  "01-glass-orb",
  "02-considered-path",
  "03-nest-rings",
  "04-capsule",
  "05-flow-orbs",
];

await mkdir(assets, { recursive: true });

for (const id of icons) {
  const htmlPath = path.join(assets, `_${id}.html`);
  const pngPath = path.join(assets, `${id}.png`);
  const svg = (await readFile(path.join(assets, `${id}.svg`), "utf8")).replace(
    /^<\?xml[^>]*>\s*/u,
    ""
  );
  await writeFile(
    htmlPath,
    `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
      html,body{margin:0;width:1024px;height:1024px;overflow:hidden;background:#0b0e11}
      svg{display:block;width:1024px;height:1024px}
    </style></head><body>${svg}</body></html>`
  );
  await new Promise((resolve, reject) => {
    const child = spawn(
      chrome,
      [
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        "--default-background-color=00000000",
        `--window-size=1024,1024`,
        `--screenshot=${pngPath}`,
        `file://${htmlPath}`,
      ],
      { stdio: "inherit" }
    );
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`chrome exited ${code} for ${id}`));
    });
  });
  await unlink(htmlPath);
  console.log("wrote", pngPath);
}
