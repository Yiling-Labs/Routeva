# Config Snapshot：变更前必建，Failover 不刷爆，Beta 有限保留

进入 Repair 前必须创建 Config Snapshot；用户/Agent 的显式策略或分流变更前也应建快照。Node Failover 自动换节点不强制完整快照。Repair 失败或取消时回滚到进入该次 Repair 前的快照。Beta 至少保留最近 10 份或 7 天内快照（实现常数）。不做无限配置时光机。

**Considered Options**
- 仅 Repair 前保留 1 份 → 无法支持列表回滚与多次修复历史。
- 任何变化含 Failover 都无限保留 → 存储与 UX 过重。
- **选定：** 重要变更前建快照 + 有限保留；Failover 不强制全量快照。
