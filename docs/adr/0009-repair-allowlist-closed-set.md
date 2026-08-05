# Repair 动作为 MVP 闭集白名单

自动/一键 Repair（含 Agent 触发的 Repair）**仅允许**执行已文档化的闭集动作：切换可用节点、重载订阅、重建 VPN/隧道、切换预设 DNS、兼容向出口参数偏好（如 IPv4/TCP）、回滚 Config Snapshot。未列入的动作不得作为 Repair；扩展必须先改规格。一律禁止未校验的任意配置写入、MITM/证书、对非 Client-Fixable 的假装修复、无快照修改与死循环重试。验证标准与 Connection Success 相同（隧道 + Connectivity Probe）。

**Considered Options**
- 原则 + 开放示例 → 边界漂移，与「禁止 AI 自由写配置」冲突。
- 闭集 + 用户包内实验开关 → 双轨复杂，易误伤信任。
- **选定：** MVP 闭集 6 类。
