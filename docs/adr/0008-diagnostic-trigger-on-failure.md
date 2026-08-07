# 诊断触发（历史）→ 见 ADR 0060

**Status:** superseded by [0060-diagnostic-only-on-help.md](./0060-diagnostic-only-on-help.md)

原决议：失败路径自动跑 Diagnostic Engine 并展示四桶。  
**现行：** 诊断 **仅** 在用户点击 **Help（Agent）** 后触发；日常失败 = Idle + toast（ADR **0059**）。Engine 仍为唯一裁判。
