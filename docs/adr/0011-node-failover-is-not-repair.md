# 连接保活 Failover 不是 Repair

在用户启用自动选节点且未钉死节点时，为维持 Connection Success 可**自动**执行 Node Failover（改选可用节点或短重连），不经过 Repair 的一键确认。Failover 属 Node Selection / 连接保活，须记入 Activity；连续失败仍走 Diagnostic Trigger。用户关闭自动选节点或手动钉节点时禁止静默切换。Repair 仍仅用于诊断为 Client-Fixable 后、经用户确认的 Allowlist 流程。

**Considered Options**
- 每次换节点都确认 → 「后台自动切换」无法成立，断流体验差。
- Failover 与 Repair 同一套确认 → 概念混淆，自愈与保活纠缠。
- **选定：** Failover 自动（在自动选节点前提下）；Repair 须确认。
