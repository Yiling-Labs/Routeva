# Subscriptions 列表：到期必须带状态标签

列表卡元信息固定三槽（有则显示、无则整槽省略）：**nodes** → **Expires / Expired {medium date}** → **Updated**。禁止 `N nodes · Sep 12, 2026` 式裸日期；未过期用 *Expires*，已过期用 *Expired* + 非连接绿警示色。列表不到秒；不写 *Renews*；无 provider 字段不写 *Not reported*。

**为何：** 裸日期与节点数粘连会与 Updated 混淆账期/刷新/导入日；代理订阅精度参差，秒级无决策价值。

**后果：** 见 CONTEXT **Subscriptions Surface**；hi-fi `04-subscriptions.html`。
