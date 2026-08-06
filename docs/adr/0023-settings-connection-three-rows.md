# Settings · Connection 段：三行一级

Settings 根页 **Connection** 段固定三行一级入口：**Routing mode ›**、**DNS ›**（预设闭集）、**Overrides ›**（User Override；Beta 无条数硬上限 · ADR 0050）。每行 **标题 + 一行释义副文（解释标题是什么）+ 右侧当前值**。副文**不**绑定具体选项枚举、**不**写「何时该改」。不采用仅 Mode、不把 Override 默认塞进 Advanced、不在此段加 Node selection/Failover 总闸或再包一层 Connection details。

**根页释义副文（English 源闭集）：**
- Routing mode — *How traffic uses your proxy*
- DNS — *How names resolve on your connection*
- Overrides — *Exceptions for specific domains*

**为何：** 落实 Connection Policy 优先；副文回答「这一行是什么」，降低 jargon 成本；选项含义与触发场景放在二级页/Help。节点偏好 / 选节点主路径仍在 Home/Location。

**后果：** 见 CONTEXT **Settings Surface** Connection 条；hi-fi `05-settings.html` Connection 行。
