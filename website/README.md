# website/ — Routeva marketing & legal

Static site for **https://routeva.yilinglabs.com**.

| Path | File |
|------|------|
| `/` | `public/index.html` — **Brand Presence** (ADR 0052) |
| `/tokens.css` | Design tokens (Hallmark) |
| `/media/` | Craft P0 stills (Home · Diagnostic · Help) |
| `/privacy/` | `public/privacy/index.html` |
| `/terms/` | `public/terms/index.html` |

**本阶段主职：** Brand Presence + Legal 必保。首页主 CTA = *How it works*（无伪商店下载）。

**视觉方向（2026-08-07）：** Sabbath DNA（`https://trysabbath.com/` 结构参考）· 双栏落地 · 右侧 media + Highlights 面板 · 自有 craft 静帧 · 见根目录 [`design.md`](../design.md)。**主 CTA 非商店下载**（Brand Presence）。

## Local preview

```bash
npx --yes serve public -p 4173
# open http://localhost:4173/privacy/
```

## Deploy (Cloudflare Pages)

```bash
# from repo root or website/
wrangler pages deploy public --project-name=routeva --branch=main
```

### Custom domain

Pages project: **routeva** · domains: `routeva-93b.pages.dev` · **`routeva.yilinglabs.com`** (active)

DNS (zone `yilinglabs.com`):

| Type | Name | Target | Proxy |
|------|------|--------|-------|
| CNAME | `routeva` | `routeva-93b.pages.dev` | Proxied |

Live:

- https://routeva.yilinglabs.com/
- https://routeva.yilinglabs.com/privacy/
- https://routeva.yilinglabs.com/terms/
- https://routeva-93b.pages.dev/ (alias)

App About links (system browser):

- Privacy Policy → `https://routeva.yilinglabs.com/privacy/`
- Terms of Use → `https://routeva.yilinglabs.com/terms/`
