# Node Selection：静默预评分 + 不猜地区

**Node Selection** 是 Table Stakes 的一部分，但「自动帮用户选」必须同时满足：连接路径不被全表测速拖死，且客户端**不**假装知道用户要哪个出口国。

**决定：**

1. **评分目标 = 可达与稳定，不是地区。** Auto 默认评分不含系统 locale、时区、语言或「大陆用户常选香港」等先验。用户要特定出口：Cover Flow / Location 手动选，或 **Preferred node**（Location 点选记住的偏好；**允许** Node Failover 为保活换走会话节点）。
2. **测速时机 = 导入后静默预选，不堵连接。** Active 导入成功（及下方重测触发）后后台测分，Cover Flow **预停**最高分节点；**不**自动连接。禁止把全表测分压在下滑连接的关键路径上；连接时复用已有分，必要时仅对当前节点短确认 + 完整 **Connectivity Probe**。
3. **两档语义：Auto 预选 vs Preferred。** 无硬 **Pin**（不再「钉死后禁 Failover」）。**Preferred** = Location 点选后的持久偏好；静默重测**不得覆盖**偏好；**Failover 仍可**为 Connection Success 换会话节点（偏好保留，供下次优先尝试）。**无**偏好时 Cover Flow 横滑仅为临时 UI 焦点，重测可覆盖。**无**显式「回全自动」UI（见 ADR 0056）。
4. **静默重测闭集：** ① 节点集合实质变化（导入 Active、Refresh 改列表、切换 Active）；② 长间隔缓存过期 S 且打开/回前台（弱）；③ 失败 / Failover **定向**重测；④ 用户显式测速。**禁止**仅因网络切换就全表重测。
5. **静默测信号 = 轻量分层。** 快速层（入口延迟/握手）+ 对前列候选的加深层（可与 Connectivity Probe 同源轻量探针）。**不得**静默全表完整出网 Probe；**不得**只按 Ping；静默测分**不得**把 Home 标成 Connection Success。
6. **测分未完成亦可连。** 静默测不是闸门；Connecting/Connected 会话不被后续预选刷新换节点。

**Considered Options（否决摘要）**

- 连接时再全表测 → 严重拖垮连接手势体验。
- 默认按地区/locale 偏置（如总偏香港）→ 假智能，与海外用户、流媒体出口等需求冲突。
- **硬 Pin 禁 Failover** → 过锁；用户要记住偏好但仍需保活换节点（2026-08-06 产品改判）。
- 静默全表完整 Probe → 成本与权限不现实；只 Ping 预选 → 假活节点多，失败叙事变差。
- 测完前禁用连接 → 把预评分做成闸门，削弱 Table Stakes。

**Consequences**

- 地区意图靠 **Preferred**（及临时 Cover Flow），不靠评分猜。**Location 点选 = Preferred**（列表 check，无 *Pinned* 锁语义）；**无** `⋯` 清钉。Cover Flow 横滑 alone **不**构成 Preferred。
- Idle 是否露出测速进度属呈现层，须服从 Home 主状态闭集；默认宜安静。
- 实现常数（S、分层抽样额度、加深层并发）可调，不改变本 ADR 语义。
- Location 面交互细则见 **ADR 0056**（点选 = Preferred · Failover 允许）。
- 术语权威：`CONTEXT.md` → **Node Selection** · **Location Surface** · **Preferred node** · **Latency Test** · **Node Failover**；规格：`docs/prd/PRD.md` §4.3；hi-fi：`08-location.html`。
