# AGENTS.md — Routeva

## 元数据

- **名称：** Routeva
- **Slug：** routeva
- **仓库：** https://github.com/zyhang/Routeva
- **Primary Type：** ios
- **Secondary Types：** android
- **Types：** ios, android
- **Code Layout：** Dual-Native（`app/ios/` + `app/android/`）

## 本仓库是什么

**AI 快速开发用 Product Workspace**：文档、设计、GTM、官网占位、代码区的标准容器。  
素材 / 代码 / 文档常由 AI 生成——**必须按域落盘**。  
源码在 `app/`（双端原生：`app/ios/` · `app/android/`）；营销站只在 `website/`。

## 内容分层

| 层 | 含义 | 谁写 |
|---|---|---|
| L0 结构 | 目录与本文件类规则 | init；之后慎改 |
| L1 骨架 | PRODUCT/PRD 空槽 | init 建槽 |
| L2 品类轨道 | `docs/guides/`、`app/AGENTS` 短规则、gtm/specs | init 按 type |
| L3 产品实例 | 功能、逻辑、具体需求正文 | **仅** init 之后的对话 |

**禁止**在初始化或「只跑 init」时编造 L3 业务内容。

## AI 产物归位

| 产物 | 位置 |
|---|---|
| 可运行应用代码 | `app/ios/` · `app/android/`（Dual-Native） |
| 营销站代码/内容 | `website/` |
| 线框/高保真 | `design/**/current/`（探索在 `_explore/`） |
| 商店与宣发素材、文案 | `gtm/` |
| 规格与需求正文 | `docs/prd/`、`PRODUCT.md` 内容区 |
| 未收敛讨论 / Brief 原料 | `docs/sessions/` |
| 难逆结构决策 | `docs/adr/` |
| 品类检查清单 | `docs/guides/` |

禁止在仓库根目录堆放 AI 输出文件。

## 核心入口

| 文档 | 用途 |
|---|---|
| [PRODUCT.md](./PRODUCT.md) | 元数据 + 导航 + 产品内容空槽 |
| [docs/guides/](./docs/guides/) | L2 品类实践 |
| [docs/prd/](./docs/prd/) | PRD 骨架 |
| [gtm/specs/](./gtm/specs/) | 渠道尺寸 |

## 全局原则

1. 一个 Workspace 一个 Product。  
2. 新文件归入已有域。  
3. `AGENTS.md` / `docs/guides` 写结构与品类实践，**不写本产品功能列表**。  
4. 初始化类操作不覆盖已有文件。  
5. 语言默认中文。  

## 禁止

- 根目录平行「最终版」「new-docs」结构  
- 上架素材放进 `app/` 或错误域  
- init 流程中生成业务功能/用户故事正文  
