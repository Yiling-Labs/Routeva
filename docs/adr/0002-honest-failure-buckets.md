# 只自动修复 Client-Fixable，诊断必须诚实分桶

Self-Healing Loop 的信任前提是：系统分得清「客户端能修」与「修不了」。MVP 将每次诊断归入 Client-Fixable / Provider-Side / Environment / Unknown 四桶；**仅 Client-Fixable 可走一键 Repair**（白名单动作 + 快照 + 验证 + 失败回滚）。其余三桶只解释原因与下一步，不静默当成功，不编造原因。牺牲「看起来什么都能修」的营销空间，换取更低误修率、更少客服压力和更可持续的付费信任。
