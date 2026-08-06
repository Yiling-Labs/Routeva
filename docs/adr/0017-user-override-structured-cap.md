# User Override：结构化条目

User Override 仅支持结构化条目：目标为**单个域名**，动作为 proxy 或 direct。可预览、可关、可回滚，并提示与订阅规则可能叠加。Global/Direct 总开关不计入列表。明确不做正则、Rule Set 市场、JS 规则与 per-App 分流，避免滑向完整规则编辑器。

> **目标形态：** **ADR 0057**（Domain only；原误标 0049，已改号）。  
> **条数：** 原「Beta 最多 20」由 **ADR 0050** 废止（Beta 不设硬上限）。

**Considered Options**
- 自由域名列表 + 正则 → 超出 MVP，贴近高级客户端。
- 仅预设服务芯片 → 过窄，且维护成本高（后由 **0057** 明确拒绝 Service）。
- **选定（0017）：** 结构化目标 → proxy|direct。**0057：** Domain only。**0050：** Beta 无条数硬上限。
