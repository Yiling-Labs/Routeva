# Overrides：列表 + Add sheet（Domain）

Settings **Overrides ›** 为规则列表 + Add sheet：目标 = 单个 **Domain**；动作 = **proxy | direct**；每条可开关/删除；Beta **无**条数硬上限（ADR 0050）。非文本速记、非仅 Agent 可写。

**为何：** 对齐结构化 User Override；单域名覆盖例外路径；避免迷你规则编辑器。与 Agent 同一模型。

> **目标形态：** 原「Service 或 Domain」收窄为 **Domain only**（**ADR 0049**）。

**后果：** 见 CONTEXT **User Override Rule**；空态文案 *one domain each*。
