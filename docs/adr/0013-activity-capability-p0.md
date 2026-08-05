# Activity：能力 P0，Craft 可 P1

Beta 必须提供可查看的本机 Activity（时间序事件：连接、Node Failover、诊断、Repair、回滚、模式/Override 等），以支撑 Failover 与 Repair 的可解释性。视觉与动效可按 Craft P1 后打磨；不得将「完全没有事件可查」延后到正式版。

**Considered Options**
- 整页 P1、Beta 可无 → 与自动 Failover / 配置变更的信任叙事冲突。
- Activity 也进 P0 Craft → 与 Onboarding/诊断抢关键路径工期。
- **选定：** 事件可查为能力 P0；呈现精致度 P1。
