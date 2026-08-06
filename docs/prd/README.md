# PRD 文档规划

## 目的

`docs/prd/` 放**需求规格**类文档的骨架与后续正文。  
init 只建规划与空壳；**业务实例在初始化之后的对话中写入**。

## 结构

| 文件 | 说明 |
|---|---|
| [PRD.md](./PRD.md) | 总 PRD 章节骨架（L1） |
| [features/subscription-refresh-ui-states.md](./features/subscription-refresh-ui-states.md) | 实现任务：Subscriptions **1d / 1e**（无远程源 · 手动 Update 失败） |
| 本 README | 何时写、如何拆分 |

## 何时写什么

| 时机 | 动作 |
|---|---|
| 刚 init | 保持空壳；先熟悉 `docs/guides/` |
| 与 Agent 细化功能 | 过程 → `../sessions/`；结论 → `PRD.md` + `PRODUCT.md` 内容区 |
| 单功能过长 | 再拆 `features/<slug>.md` 并在此登记（init 不预建） |

## 与 L2 的关系

上架、隐私、渠道尺寸等**品类**事项见 `../guides/` 与 `../../gtm/specs/`，不要塞进 PRD 当「本产品独特功能」唯一来源。
