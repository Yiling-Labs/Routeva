# Cloud AI 授权在 Agent，不进 Settings 根页

Cloud AI Opt-in **不在 Settings 根页**提供开关或 Assistant 段。用户**首次在 Agent 中需要云端增强**时再做知情同意；开启后有可见指示，并在 Agent 内可关闭。Settings 不预开/预关。

**为何（相对「Settings 根页 Toggle ± 首次 sheet」）：** 授权上下文贴着真实需要云的动作，减少「设置里先开一堆」的误开；Agent 已是 Thick 主面之一。代价：无法在进 Agent 前于 Settings 预关/预开——接受该摩擦。

**后果：** Settings 根页收为 **Connection → History → App** 三段（修订 ADR 0022）；CONTEXT **Cloud AI** / **Settings Surface** 同步。Agent 内授权文案与「可一键关」控件为实现必达；Privacy 页可只读说明「云端如何工作」，但不做第二套开关。
