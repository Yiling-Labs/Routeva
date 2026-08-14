# 静默 TCP 延迟、Location 延迟序、Cover Flow 角标

用户换节点的主依据是 **入口延迟** 与 **地区（手动/Preferred）**。在 ADR **0055** 之上，产品确认（grill 2026-08-12）：

1. **时机：** 订阅可用后静默测（导入 Active / 列表实质变化 / 弱缓存过期 S 等），**不是**无订阅的空启动。与 0055 测速时机一致。
2. **信号（本期）：** 静默 = **TCP 入口 RTT**（与 Location *Test* 同源）；展示 ms；**Timeout / 未测降权**。**禁止**静默全表完整 Connectivity Probe。预选/排序 **不得**把 Timeout 当「已验证出网」。连接路径仍：短确认 + 完整 Probe（防假连接）。
3. **Cover Flow（2026-08-12 改判）：** Active 订阅**全量**可路由节点（导入时已剔除额度/到期等 metadata 横幅行），**订阅原序**，**循环**横滑（无端点）。角标仍为 **B2 · Inset glass + `NNms` + 分档色**（`design/hi-fi/_explore/2026-08-12-coverflow-latency-badge/`）：嵌在国旗圆盘底弧；未测不显示 · 测中 `…` · 有延迟 `NNms` · Timeout `—`。TCP RTT 分档：**&lt;100 绿 · 100–200 黄 · &gt;200/超时 软红**。延迟**只**做角标与 Location 排序信号，**不**再裁剪 / 重排 Cover Flow 成员。
4. **Location 默认序（改判）：** 由「订阅原序、Avoid 按延迟重排」改为 **默认延迟升序**（有 ms 升序 → Timeout → 未测且未测保持订阅相对序）。Preferred 用 ✓，**不**强制置顶。
5. **重排时机：** 测中 **只更新标注**；**本轮静默测或用户 *Test* 全部结束后** 再重排 **Location**（Cover Flow 序不变）。
6. **预停（Idle）：** 当前焦点已是绿色（TCP RTT &lt;100）→ **不**自动换到更低 ms。当前非绿且未连接 → 预停已测样本中最低 ms。横滑 / Location 点选仍占焦点，测完不得抢走。仅改选中下标，不改 Cover Flow 列表序。Connecting / Connected 不预停。
7. **连接中：** Connecting / Connected **暂停**静默全表测；回 Idle 再续；**禁止**测分刷新换掉当前会话节点。
8. **显式 *Test*：** 与静默 **同一管道、同一结果集、同一轮末 Location 重排**。

**Considered Options（否决）**

- 仅进程首次启动测一次 / 每次冷启动全表狂刷。
- Cover Flow 仍用 strip ≤ N（Preferred ∪ 低延迟 Top）— 已改判为全量循环。
- 出分即重排 Location（跳动抢点）。
- 静默永远预停最低延迟并覆盖用户横滑焦点 / Preferred。
- 连接与全表 TCP 并行抢路径。

**Consequences**

- CONTEXT **Location Surface** / **Latency Test** / **Node Selection** 与 ADR **0055** 中「*Test* 不重排 Location」「strip ≤ N」等：Location 延迟序与 B2 角标以本 ADR 为准；**Cover Flow 全量循环**以本 ADR 第 3 条改判为准（覆盖 0055 §7 有界 strip）。
- 实现常数：S、批并发、单点超时、分档阈值（默认 100/200）——可调，不改 B2 语义。
