# Marketing Site · 视觉可独立于 App DNA（OpenDesign 方法）

**Status:** accepted · 2026-08-07  
**Supersedes（仅视觉句）：** ADR **0052** 中「官网视觉必须延续 App Field Black + mint」——**0052 的 Brand Presence 主职、主 CTA、Legal 必保、技术与语言条款仍有效。**

## 决定

Brand Presence 阶段，**Marketing Site**（`website/` · `routeva.yilinglabs.com`）允许拥有 **独立于 App Visual System** 的视觉 DNA。App hi-fi / `design/hi-fi/current/craft-p0/visual-system.md` **不**因本决策强制同步。

视觉选型采用 **OpenDesign 方法**（真实 design pack 的测量 token 作 taste 源）：brief → 不同审美族的多方向探索 → 人选定赢家 → 再写入生产站。不是套用 opendesign.cc 站皮肤，也不是无参考的 vibe redesign。

## 为何

- 当前 GTM = Brand Presence only：站是对外主触点；App 像素尚未上架，强绑 craft-p0 色板会限制换脸与反 AI-slop 实验。
- OpenDesign 的价值在换一套有主张的真实系统 DNA；锁死 mint Field Black 等于半废该方法。
- 站/App 短暂不一致在 Beta 前可接受；统一 DNA 若需要，另开里程碑把 App 迁到同一套，而非本轮全线换脸。

## 本轮范围（grill 共识）

| 做 | 不做 |
|---|---|
| 皮肤 + 版式（token、材质、分区节奏、编排） | 改产品主张 / 假 Download 主 CTA |
| 三方向同文案探索后选赢家 | 活站直接试错 |
| 锁品牌名与「不卖节点 / Paste→Connect / Coming next」叙事 | 改 Legal **正文**；同步改 App visual system |
| 赢家首页先上；Legal **视觉**第二小步 | 用未交付 Repair 当地铁卖点 |

**探索落盘：** `website/public/_explore/2026-08-07-opendesign/{a,b,c}/`（同 IA 骨架；须 noindex 或构建排除，避免当正式叙事推广）。  
**三方向族：** A Quiet product dark · B Editorial instrument · C Soft technical（light 或 dual-surface）。  
**赢家（2026-08-07）：** **C · OpenDesign `supabase`** → 生产 `tokens.css` / 首页。叙事升级见 ADR **0067**。  
**忠实度：** 探索严格接地 pack；生产允许有限调和（可读性 / a11y / 现有产品图），禁止滑回平均脸。  
**验收：** 主观选赢家 + Brand Presence / Legal / a11y / 反 slop / 来源可追溯硬门槛。

## 后果

- 后人不得仅凭 0052 旧视觉句把生产站改回 App DNA，而不读本 ADR。
- 商店截图与站视觉对齐属 **上架/GTM 后续**问题，不阻塞本阶段 Brand Presence 换脸。
- 若未来要 **App ↔ 站统一 DNA**，另开 ADR/里程碑；本 ADR 不禁止统一，只解除「必须从 App 单向继承」的绑定。
