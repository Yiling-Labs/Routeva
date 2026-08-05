# User Override：Beta 不设条数上限

Beta 阶段 User Override **不设**条数硬上限（取消 ADR 0017 的「最多 20」产品配额）。仍保持 **Domain only → proxy|direct**、无正则/通配、O3「少数例外」文案；**不**在列表展示 N/M 额度，**不**因条数禁用 Add。

**为何：** 20 为软产品常数而非技术硬限；硬上限 + 额度文案易读成规则引擎配额，与「不是完整规则集」冲突。Beta 用意图文案约束用法即可；若日后滥用或性能问题再议软/硬上限。

**相对 0017：** 保留「结构化条目」；**废止** Beta「最多 20 / 满则禁 Add」。0017 标题中的 cap 以本 ADR 为准。

**后果：** CONTEXT **User Override Rule**；空态辅文 *One domain each*（无 *Up to 20*）；hi-fi 始终 *Add exception*。
