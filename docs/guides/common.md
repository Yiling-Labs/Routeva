# 通用工作区实践（L2）

> 适用于所有 Project Type。面向 AI 大量生成资产的快速交付。

## 硬规则

1. **一仓一产品**；第二个产品新建 Workspace。  
2. **AI 输出必须归域**（见根 `AGENTS.md` 归位表），禁止根目录垃圾堆。  
3. **结构文件**（`AGENTS.md`、guides、目录约定）慎改；**内容文件**（PRODUCT 内容区、PRD、设计、GTM 文案）可随对话迭代。  
4. **密钥与 `.env` 永不入库**。  
5. 改顶层布局或跨域职责 → 写 `docs/adr/`。  

## 协作节奏（建议）

- [ ] 功能/范围讨论过程落入 `docs/sessions/`  
- [ ] 收敛结论写入 `PRODUCT.md` 内容区与/或 `docs/prd/PRD.md`  
- [ ] 设计探索进 `design/**/_explore/`，采用稿进 `design/**/current/`；上架图只从 current 导出到 `gtm/`  
- [ ] 设计多版本规则见 [design-versions.md](./design-versions.md)  
- [ ] 发版/上架前过本类型 `docs/guides/<type>.md` 与 `gtm/specs/`  

## 明确不是本文件的职责

- 规定本产品功能列表、商业模式、具体 UX 文案  
