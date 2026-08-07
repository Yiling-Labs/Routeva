# Design — Routeva Marketing Site

Locked design system for **Brand Presence** pages under `website/public/`.  
Future Hallmark runs **read this file first**; pages defer to it.

**Canonical tokens:** [`website/public/tokens.css`](./website/public/tokens.css)  
**Product narrative:** ADR **0067** · CONTEXT **Crafted Connect**

## Provenance

- **Extracted from** `https://trysabbath.com/` as a **public reference** for structural DNA (2026-08-07).
- Structural only: dual-column landing · media panel · secondary panel swap · centered serif hero · pill CTA expand.
- **Not copied:** Sabbath photography, video, QR, App Store CTA, testimonials, or brand assets.
- **Routeva fill:** own craft stills (`media/*.png`), you-voice highlights, Brand Presence CTAs (no fake store download).
- Rhythm: partially inferred from CSS layout constants (URL mode blind spot noted).

## System

- **Genre** · modern-minimal / product landing
- **Macrostructure** · Split Studio (fixed split + panel swap)
- **Theme** · studied-DNA (Sabbath skeleton × Routeva ink/paper)
- **Axes** · light / roman editorial serif display + grotesque body / neutral ink (+ green only as product accent in story, not flood)
- **Nav** · none (footer utility row on copy column)
- **Footer** · Ft2-ish centered utility on left column
- **Secondary panel** · Highlights / brand story (replaces Wall of Love)

## Tokens

See `website/public/tokens.css`.

- Paper `#ffffff` · Ink `#000000` · Muted `rgba(0,0,0,0.4)` · Panel `#f5f5f7`
- Display **Playfair Display** 500 · Body **Inter** 500/600
- Story panel gradient `#546688` → `#99a3b4` (structural analogue; not product Field Green)
- Product accent `#00bb68` reserved for product UI previews, not marketing flood

## CTA voice

- Primary pill **black** · white type · expands on fine-pointer hover to status copy (not store QR)
- Brand Presence: **How it works** / open Highlights — **never** fake App Store / Download
- Press: `scale(0.97)` · strong ease-out · no bounce overshoot on expand

## Motion stance

- Panel swap `translateY` ~420ms ease-out
- Optional infinite vertical scroll of story cards (desktop, when panel open)
- Wheel gesture to open/close highlights (desktop)
- Reduced motion: no panel transition excess · no marquee scroll
- Hover gated: `@media (hover: hover) and (pointer: fine)`

## Layout

| Region | Behavior |
|---|---|
| Left `copy-pane` | Centered icon mark · two-line serif H1 · muted lede · pill CTA · footer utilities |
| Right `panel-viewport` | Gray rounded `media-panel` with phone still · absolute `story-panel` slides up |
| Mobile | Stack: copy → media → story list static (no wall toggle) |

## Copy rules

- You-voice highlights (ADR 0067)
- **Capability-first** (Stash-style craft, not Stash audience): title = ability/result (short); body = one mechanism + one outcome
- Prefer affirmative claims; boundary lines (no-sell nodes, not on stores) 1–2 per screen max
- No tutorial-tour marketing (*On Home, swipe down. You’ll see…* as the whole pitch)
- No invented testimonials / ratings / user counts
- Coming next: help & safe repair only with consent language
- Screenshots labeled design preview where needed

## What MUST share

- Split landing skeleton on home
- Playfair + Inter pairing
- Black primary CTA pill
- Legal URLs `/privacy/` `/terms/`

## What MUST NOT

- Copy Sabbath assets or quotes
- App Store / QR as primary CTA before real links exist
- Equal 3-feature SaaS grids as home structure
- Purple gradient AI heroes

## Stamp

```css
/* Hallmark · macrostructure: Split Studio · studied: yes
 * DNA-source: url https://trysabbath.com/
 * display: Playfair Display · body: Inter · paper #fff · ink #000
 * designed-as: marketing Brand Presence · design-system: design.md
 */
```
