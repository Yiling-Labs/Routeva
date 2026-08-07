# Home 模式不变骨架 + 三维策略轴（非 Clash 分组主路径）

用户易把「Global vs 规则」映射成 Home 分叉（全局单节点列表 vs 策略组树）。Routeva 明确拒绝：

1. **Home mode-invariant：** Smart / Global / Direct（内部 `auto`/global/direct）**共用**同一 Home 骨架（连接真值 + 手势 + 单一出口）；Mode 不换布局、不在 Home 展开 proxy-group。
2. **双轨是 IA 不是第二套 App：** 默认简单；半专业用 Settings 常驻 **Routing mode** + **Overrides**，Help/诊断深链同一页；**无** Advanced 总闸升级主 UI。
3. **不做 MVP 策略组出口台：** Location 的 group = **Provider Group**（浏览节点 → Preferred）；**不是**每组独立 `select`。精细需求 = Override（域名 → proxy|direct），不是 Clash 式分组点选。
4. **三维正交：** **Routing Mode**（默认范围）× **Preferred**（共用出口，三模式一份）× **Override**（例外；`proxy` 一律跟当前/Preferred 节点）。  
   - Auto：Preferred = 诚实子集（仅「该代理且客户端可选出口」的流量）。  
   - Global：默认收敛到当前会话节点；Override 仍生效。  
   - Direct：默认直连；Override 仍可强制代理。

**为何：** 初级用户任务是连上与换出口，不是维护分组；与 ADR 0005 / 0018 / 0032 / 0056 / 0057 一致，并堵住「规则模式 = Home 变复杂」的错误产品推演。

**后果：** 见 CONTEXT **Home Surface** · **Routing Mode Entry** · **Auto Policy** · **Provider Group** · **Policy Group Selection** · **User Override Rule**。  
**Hi-fi：** `design/hi-fi/current/craft-p0/02-home.html`（**唯一** Home 权威；已含 mode chip / sheet 与连接故事板）。文案：`home.mode.chip.*` · `home.mode.sheet.*` · `home.mode.hint.*` · `settings.routing.*.sub` · Overrides empty howto（`docs/copy/en.yaml`）。
