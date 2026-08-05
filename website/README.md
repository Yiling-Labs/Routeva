# website/ — Routeva marketing & legal

Static site for **https://routeva.yilinglabs.com**.

| Path | File |
|------|------|
| `/` | `public/index.html` |
| `/privacy/` | `public/privacy/index.html` |
| `/terms/` | `public/terms/index.html` |

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

Pages project: **routeva** · default host: `https://routeva-93b.pages.dev`

Attach **routeva.yilinglabs.com** (API may mark domain pending until DNS exists):

1. Cloudflare Dashboard → **Pages** → **routeva** → **Custom domains** → add `routeva.yilinglabs.com`, **or**
2. DNS (zone `yilinglabs.com`) → CNAME:

   | Type | Name | Target | Proxy |
   |------|------|--------|-------|
   | CNAME | `routeva` | `routeva-93b.pages.dev` | Proxied |

Until DNS is set, Privacy is already live at:

- https://routeva-93b.pages.dev/privacy/
- https://6e1165d3.routeva-93b.pages.dev/privacy/ (this deploy)

App About links (system browser):

- Privacy Policy → `https://routeva.yilinglabs.com/privacy/`
- Terms of Use → `https://routeva.yilinglabs.com/terms/`
