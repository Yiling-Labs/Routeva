# 商店截图像素套与 App 8 locale 对齐

**取代** ADR **0048** 中「完整多语言截图不与 App 8 locale 同日齐发」。listing **描述/关键词** 仍按 **GTM Language Set** 分层精做。

**决定（grill 2026-08-14）：** 商店截图闭集 = **Store Screenshot Locale Set**（en · zh-Hans · zh-Hant · es · pt-BR · ja · ko · de）。每语同一 Spine 四张，6.5" + 6.7" 两档。框外标题人工两行；手机壳层 UI 用与二进制相同的 catalog；lock-en 与演示节点名不译。

**为何改：** 用户要在对应 locale 商店看到该语言标题和界面，而不是 8 语 App 只配 en 图。代价是 64 张 PNG 与中日韩字体分轨，换来 listing 与系统语言一致。

**Status:** accepted · 2026-08-14  
**Relates:** ADR **0048** · **0071** · CONTEXT Store Screenshot Locale Set / Copy Surface / String Source
