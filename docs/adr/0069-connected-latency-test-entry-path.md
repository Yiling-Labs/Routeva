# Connected 时显式 Latency Test：入口路径，不断开会话

Location 顶栏 *Test* 与静默测同源（节点入口 TCP RTT）。ADR **0068** §7 暂停 Connecting / Connected 的静默全表测；实现把同一道闸写在整条管道上，导致 Connected 时用户 *Test* 点了无探测。产品确认（grill 2026-08-13）：**显式 *Test* 在 Idle 与 Connected 都要能跑，且数字必须仍是入口路径的 Latency Test**——不是经当前隧道绕到其他入口的时延，也不是先拆会话再测。

1. **同一测量：** Idle 与 Connected 的 **ms** 同义 = 到节点入口的 TCP RTT。做不到这种数就**不出新数**，禁止用经隧道的假 **ms** 冒充 Latency Test。
2. **准入：** **Idle** = 静默 + 用户 *Test*。**Connected** = **仅**用户 *Test*（静默仍暂停，回 Idle 再续 · 0068 §7 仍有效）。**Connecting** = 不测；进行中的一轮取消（Home 本就锁 Location 入口；若 Location 已打开而会话进入 Connecting，仍取消）。
3. **Connected 不拆会话：** *Test* **不** Disconnect，**无**「先断开才准」确认框。点选仍立刻改 Preferred 并切节点（ADR **0056**）。
4. **探测边界：** Connected 时只允许 **Test 自己的探测**走入口/物理路径。**禁止**把节点入口写成通用隧道排除（避免任意 App 流量漏出）。
5. **测完副作用：** 只写行内 **ms**；仅**整轮完成**后重排 Location。不改 Preferred、不改当前会话节点、不改 Cover Flow 下标。
6. **未完成的一轮：** 点选、离开 Location、进入 Connecting → 取消剩余探测；已写出的 **ms** 保留；**不**重排。*Test* 是 Location 上的可见工作，离开后不得变成绿场后台全表扫。
7. **入口路径不可用：** Connected 这轮不测；上一轮数保留；会话不动。不可用须可见（按钮不可用或短 toast），禁止再出现「能点但没反应」。

**Considered Options（否决）**

- Connected 继续静默 no-op，或按钮能点管道直接 return。
- 先 Disconnect /「关闭 VPN」再自动 *Test*（绿场主路径是看延迟并立刻切节点，不是拆会话）。
- Connected 经隧道测一圈仍叫 Latency Test（与 Idle 的 **ms** 不可比，会骗用户切错节点）。
- 把节点 IP 写入隧道排除表来「走直连」（漏面大于探测本身）。
- Connected 恢复静默全表测，或离开 Location 后继续跑完。
- Connecting 与 *Test* 并行，或记下意图连上后再自动开跑。
- 测完自动切到最低 **ms**，或用本轮结果改写 Cover Flow 预停 / 会话节点。

**Consequences**

- **0068 §8**「同一管道」= 同一测量与同一轮末重排，**不是**同一准入。§7 的暂停只约束**静默**全表测；用户 *Test* 以本 ADR 为准。
- CONTEXT **Latency Test** / **Location Surface** / **Node Selection** 以本 ADR 收口 Connected / Connecting 准入与「入口路径、不断开」。
- 实现须让 Connected 的探测不经当前隧道；做不到则走第 7 条降级，不改本 ADR 的测量定义。
