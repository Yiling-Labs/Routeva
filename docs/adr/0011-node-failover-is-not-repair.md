# 连接保活 Failover 不是 Repair

在用户启用自动选节点时，为维持 Connection Success 可**自动**执行 Node Failover（改选可用节点或短重连），不经过 Repair 的一键确认。**Preferred node**（Location 点选偏好）**不**阻止 Failover：会话可暂用其他节点；偏好保留，供后续优先尝试（ADR **0055** / **0056**）。Failover 属 Node Selection / 连接保活，须记入 Activity；连续失败仍走 Diagnostic Trigger。用户**关闭**自动选节点时禁止静默切换。Repair 仍仅用于诊断为 Client-Fixable 后、经用户确认的 Allowlist 流程。

**Considered Options**
- 每次换节点都确认 → 「后台自动切换」无法成立，断流体验差。
- Failover 与 Repair 同一套确认 → 概念混淆，自愈与保活纠缠。
- 硬 Pin 禁 Failover → 过锁；产品改判为偏好可记、保活可换（ADR 0055 修订）。
- **选定：** Failover 自动（在自动选节点前提下，含有 Preferred 时）；Repair 须确认。
