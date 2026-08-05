# 同时仅一个 Active Subscription

用户可保存多个 Subscription，但连接、Node Selection、Connectivity Probe、诊断、Repair 与 Node Failover 只作用于当前 **Active Subscription**。切换 Active 必须是用户显式操作。不默认将多订阅节点合并为同一选节点池，也不做多订阅多隧道并行。

**Considered Options**
- 多订阅节点池合并 → Provider-Side 难归因，规则与故障边界糊。
- 多隧道并行 → 超出 MVP 客户端复杂度。
- **选定：** 单 Active；多份仅作库存与切换。
