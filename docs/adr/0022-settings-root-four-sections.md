# Settings 根页分组闭集（三段）

Settings Surface 根列表定为三段（自上而下）：**Connection → History → App**。不根底常驻 Advanced 段、不无分组扁平长列表。

**原案四段含 Assistant**；后经 ADR **0025** 将 Cloud AI 授权放在 Agent 首次需要时，Settings 不再挂 Assistant 段，以免空壳或与 Agent 双源。History 仍单独成段以保证 Activity 发现性。

**为何：** 落实 ADR 0021（策略在上）；History 保证 Failover/Repair 可解释入口；App 收纳隐私/Subscriptions 深链/About（无 Appearance，见 0028）。

**后果：** 术语见 CONTEXT **Settings Surface**；hi-fi 与 `00-ia` 以本 ADR + 0021 / 0025 为准。
