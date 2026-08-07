# craft-p0 · current（MVP）

**MVP 范围（ADR 0063）：** 无 Help / Agent / 诊断·Repair UI。  
**权威屏：** Home · Setup · Subscriptions · Settings · Location。

| 文件 | 说明 |
|---|---|
| **[02-home.html](./02-home.html)** | **唯一权威** Home：连接故事板 · Mode Smart/Global（0058）· fail toast（0059）· Failover toast · 顶栏 **Subscriptions · Settings**（**无** Help） |
| **[03-setup.html](./03-setup.html)** | Welcome → Empty（**仅 Settings**）→ Add |
| **[04-subscriptions.html](./04-subscriptions.html)** | Subscriptions 单列表 + Active 态 |
| **[05-settings.html](./05-settings.html)** | Settings 根页 + 二级 |
| **[08-location.html](./08-location.html)** | Location · Preferred · Latency Test |
| **[visual-system.md](./visual-system.md)** | 全 app 风格约束 |
| [design-spec.md](./design-spec.md) | Home 视觉 / 交互规格 |

**Post-MVP（非 current 权威）：**  
[`_explore/2026-08-07-help-agent-post-mvp/`](../../_explore/2026-08-07-help-agent-post-mvp/) — 原 `06-agent` / `07-diagnostic`。

## 连接故事板（`02-home.html`）

| # | 状态 | 备注 |
|---|---|---|
| Demo / Interactive | 胶囊 craft | START↓ → connect → STOP↑ |
| 1 Idle | Cover Flow · 节点 › → Location · Smart › · **无** Help |
| 2–3 Swipe | 点阵 · 无 Mode chip |
| 4 Connecting | Connecting… |
| 5 Connected | 绿场 · 节点 glass → Mode |
| A | Mode Smart/Global sheet | ADR 0058 |
| C1 | Fail toast | ADR 0059 |
| C3 | Empty | **仅 Settings** |

## 文档同步

| 文档 | 内容 |
|---|---|
| [00-ia.md](../../wireframes/current/craft-p0/00-ia.md) | IA（MVP 无 Help） |
| [CONTEXT.md](../../../CONTEXT.md) | Home Chrome · ADR **0063** |
| [PRD](../../../docs/prd/PRD.md) | MVP 范围 |
| [ADR 0063](../../../docs/adr/0063-mvp-no-help-agent-surface.md) | Help 出 MVP |

更新：2026-08-07 · ADR 0063 裁 MVP
