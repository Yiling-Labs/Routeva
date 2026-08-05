# Agent 工具为 MVP 闭集

Thick Agent 只能调用文档化的 Agent Tool Allowlist（只读摘要类 + 受既有 Consent/Snapshot/Active 约束的变更类）。未列出的工具不得注册或调用；扩展必须先改规格。硬边界不变：无网页内容/完整浏览历史、无 Token 与原始订阅上传、无 MITM、无自由写配置、无推荐机场、无静默改系统。故障判定仍以 Diagnostic Engine 为准。

**Considered Options**
- 原则约束 + 开放工具列表 → 边界易漂移。
- 仅闭集变更类、只读任意扩 → 只读面仍可能越权取数。
- **选定：** 只读与变更均为 MVP 闭集。
