# Activity：能力 P0，Craft 可 P1

Beta 必须**记录**本机 Activity（时间序事件：连接、Node Failover、诊断、Repair、回滚、模式/Override 等），并在用户需要解释时**可触达**，以支撑 Failover 与 Repair 的可解释性。视觉与完整时间线 UI 可按 Craft P1 后打磨；不得将「完全不记事件 / 完全不可解释」延后到正式版。

**入口（ADR 0020 / **0051**）：** **非** Home 顶栏；**非** Settings 根页/History。优先 **Help / Agent 最近事件摘要**、诊断与 Repair 结果上下文。

**Considered Options**
- 整页 P1、Beta 可无 → 与自动 Failover / 配置变更的信任叙事冲突。
- Home 顶栏常驻 Activity → 用户难理解日常用途。
- Settings History 常驻 → 小白/半专业无直接场景（**0051** 去掉）。
- **选定：** 事件记录 + 可解释为能力 P0；Settings 不占根页；完整列表 UI 可后补。
