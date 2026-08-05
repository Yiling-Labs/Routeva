# 连接成功 = 隧道就绪 + Connectivity Probe

「连接成功」（含首次自动连接与 Repair 后验证）不得仅以系统 VPN 已连接判定，必须再经当前节点完成至少一次客户端 **Connectivity Probe**（固定探针出网检测）成功。Probe 用于选节点加权与验收，**不是**流媒体/特定站点解锁检测，也不构成解锁 SLA。仅隧道就绪而探针失败时，不得宣称成功，应进入 Diagnostic Engine 四桶，并按 Diagnostic Trigger **自动**诊断。

**Considered Options**
- 仅隧道就绪 → 实现简单，易出现「已连接但上不了网」的假成功。
- 默认以用户指定站点（如 YouTube）验证 → 易与解锁承诺混淆。
- **选定：** 隧道 + 固定 Connectivity Probe。
