# User Override：仅单域名，不做 Service 预设

**Status：** accepted  
**编号：** **0057**（2026-08-06 grill 从错误撞号的 `0049-user-override-domain-only` **改号**；**0049 仅保留 Dual-Native**）

User Override 目标 **只允许单个 Domain** → `proxy | direct`。**不做** 产品维护的 Service / 站点预设表（如「ChatGPT」一键展开多域名）。

**为何：** Service 预设需持续维护域名映射；上游 CDN/域名变更会导致例外 silently 失效或误伤，维护成本高且损害信任。单域名由用户显式声明，行为可预期、可解释。

**相对 ADR 0017 / 0030：** 收窄目标形态——去掉 Service；保留结构化 Domain→proxy|direct、无正则/通配、列表 + Add sheet、与 Agent 同一模型。条数见 **ADR 0050**（Beta 无硬上限）。

**后果：** 见 CONTEXT **User Override Rule**；hi-fi `05-settings.html` 无 Target type / Service。
