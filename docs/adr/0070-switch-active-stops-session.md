# 切换 Active 先停会话，不热切

**Set active** 换的是整份订阅目录，不是同一订阅内的节点。Connected（或尚未完成的 Connecting）会话绑在旧目录上；切 Active 时**先停止当前会话，再改 Active，不自动重连**。用户从 Home 用新目录重新连接。同一 Active 内的点选切节点（ADR **0056**）与手动 Update 后的目录热切不受影响。

**Considered Options（否决）**

- Connected 时热切 catalog / 自动重连到新订阅的 Preferred（当前实现；会话与新目录边界糊，失败面大）。
- 切 Active 前弹出「先断开？」确认（多一步；用户已经在显式换订阅）。
- Connecting 期间禁止 Set active（入口能点却无反应）。
