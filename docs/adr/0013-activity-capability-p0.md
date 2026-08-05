# Activity：能力 P0，Craft 可 P1

Beta 必须提供可查看的本机 Activity（时间序事件：连接、Node Failover、诊断、Repair、回滚、模式/Override 等），以支撑 Failover 与 Repair 的可解释性。视觉与动效可按 Craft P1 后打磨；不得将「完全没有事件可查」延后到正式版。

**入口（ADR 0020）：** 能力保留，**非** Home 顶栏常驻；默认 **Settings → Activity**，Agent 可摘要 recent events。

**Considered Options**
- 整页 P1、Beta 可无 → 与自动 Failover / 配置变更的信任叙事冲突。
- Activity 也进 P0 Craft → 与 Onboarding/诊断抢关键路径工期。
- Home 顶栏常驻 Activity → 用户难理解日常用途；已改由 Subscriptions 占位。
- **选定：** 事件可查为能力 P0；呈现精致度 P1；入口在 Settings 二级。
