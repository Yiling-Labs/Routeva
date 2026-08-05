# Settings · Connection 段：三行一级

Settings 根页 **Connection** 段固定三行一级入口：**Routing mode ›**、**DNS ›**（预设闭集）、**Overrides ›**（User Override，≤20）。不采用仅 Mode、不把 Override 默认塞进 Advanced、不在此段加 Node selection/Failover 总闸或再包一层 Connection details。

**为何：** 落实 Connection Policy 优先；Mode 是最高频非 Home 策略；DNS 与 Repair Allowlist 预设切换对称可发现；Override 是产品结构化能力而非隐藏高级项。节点钉选与列表主路径在 Home/Location，避免双源。

**后果：** 见 CONTEXT **Settings Surface** Connection 条；DNS 预设枚举、Override 编辑 UI 细项另议。
