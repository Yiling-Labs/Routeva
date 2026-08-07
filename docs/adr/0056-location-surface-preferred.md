# Location Surface：点选 = Preferred node（非 Pin 锁）

**Slug：** `0056-location-surface-preferred`（2026-08-06 自 `…-pin` **改名**——产品语义是 Preferred，非硬 Pin）

从 Home 进入全屏 **Location Surface**（标题 *Location*）：浏览 Active 订阅出口节点、**设偏好节点**、批量 Latency 标注。选节点主路径在 Home/Location，不进 Settings。与 **ADR 0055**（Node Selection 预评分 / 不猜地区 / Preferred vs Auto）配套。

**Home 入口（2026-08-06 收口）：**  
- **黑场 Idle**（含失败回退 Idle · ADR **0059**）：Cover Flow 下 **节点名 + 弱协议 + 弱 ›** 可点进 Location（可见**无** *Location* 词；a11y *Choose location* + 当前节点）。**无**中部空 *Location ›* glass pill；中部仅 *Not Connected*（**无** *Can’t connect*）。  
- **黑场 Swipe / Connecting：** 节点名行 **锁定**（无 ›），避免手势误触。  
- **绿场 Connected：** 中部 soft-glass **节点行**可点（不变）。  
- **两套语义不变：** Cover Flow 横滑 alone = 临时焦点；Location 点选 = Preferred；Home **不**标 Preferred。  
- **Cover Flow 条：** 有界 Top-N + Preferred 锚定（**非**全量）；**分组只在本面**（ADR **0055** §7）。

**列表（扁平 · 订阅顺序）：** **无**分组 chip / 分段。主列表一次展示 Active 订阅下**全部**出口节点，顺序 = **订阅/配置文件给出的顺序**（机场/市场原序）；**不**按地区重分类、**不**按延迟重排、**不**客户端伪造顶行 Auto。行 = 节点名 · check（仅偏好）· 次行协议 · Latency ms。MVP 无搜索、无进页自动测、无顶栏 `⋯`。Home Cover Flow 仍为有界 Top-N 快选；Location 为全量列表。

**点选 = Preferred node（偏好节点）：** 记住用户选中的出口偏好，作为连接与 Idle 焦点的默认目标。**允许 Node Failover** 为保活静默换走会话节点；偏好本身**不**被静默预选覆盖，也**不**因 Failover 自动改写。已连接时点选 → **立即切节点**（非 Repair）；失败**保留偏好**，toast/回退（**不**自动诊断 · ADR 0060）。返回 Home 时 Cover Flow / 中部节点名与偏好一致（若会话因 Failover 暂用他节点，Home 显示**当前会话**节点，偏好仍在 Location 标 check）。

**清除偏好：** **无**显式 *Use automatic node selection* / `⋯` 入口。仅当偏好节点离开 Active 列表（Refresh / 切 Active 等）时 **静默丢弃**，下次连接走 Auto 预选。用户改偏好 = 点选另一节点。

**Latency Test：** 仅顶栏批量 *Test*；入口延迟/握手（ms/Timeout）；非 ICMP 叙事、非完整 Connectivity Probe；不改偏好、不自动切换、不按 ms 重排。

**刻意不选：** 硬 **Pin**（禁 Failover）；*Pinned* / *Current* 徽章文案；清钉回 Auto 菜单；真 Ping；列表当第二订阅台；测后按 ms 重排为默认。

**权威：** `CONTEXT.md` Location Surface · Preferred node · `docs/prd/PRD.md` §4.3 · hi-fi `08-location.html` · copy `location.*`。
