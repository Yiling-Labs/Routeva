# User Override：服务/单域名结构化，上限 20

User Override 仅支持结构化条目：目标为预设服务名或单个域名，动作为 proxy 或 direct。可预览、可关、可回滚，并提示与订阅规则可能叠加。Beta 最多 20 条。Global/Direct 总开关不计入条数。明确不做正则、Rule Set 市场、JS 规则与 per-App 分流，避免滑向完整规则编辑器。

**Considered Options**
- 自由域名列表 + 正则 → 超出 MVP，贴近高级客户端。
- 仅预设服务芯片 → 过窄，常见「这个域名直连」做不到。
- **选定：** 服务名或单域名 → proxy|direct，上限 20。
