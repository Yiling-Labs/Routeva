# Routeva

> 产品摘要（权威导航）。术语见 [CONTEXT.md](./CONTEXT.md)；规格见 [docs/prd/PRD.md](./docs/prd/PRD.md)；难逆决策见 [docs/adr/](./docs/adr/)。  
> 初版原料（非权威）：[docs/sessions/2026-08-05-init-brief.md](./docs/sessions/2026-08-05-init-brief.md)。

## 元数据

| 字段 | 值 |
|---|---|
| slug | routeva |
| repo | https://github.com/zyhang/Routeva |
| primary_type | ios |
| secondary_types | 无 |
| types | ios |
| min_os | iOS 17+ |
| market | 美国 App Store 首发优先 |
| product_language | English（用户可见源语言） |
| business | **Beta：全功能免费**；目标草稿 Free + Pro $2.99 永久（见 ADR 0001/0006） |
| updated | 2026-08-05 |
| status | Grill Q1–Q15 + 复审 Q1–Q12 已收口；可进入设计/实现细化 |

## 工作区导航

| 域 | 路径 | 说明 |
|---|---|---|
| 术语 | [CONTEXT.md](./CONTEXT.md) | 领域语言 |
| 需求 | [docs/prd/](./docs/prd/) | PRD |
| 过程稿 | [docs/sessions/](./docs/sessions/) | grill / Brief 原料 |
| 决策 | [docs/adr/](./docs/adr/) | ADR |
| 品类实践 | [docs/guides/](./docs/guides/) | iOS 等 L2 |
| 设计 | [design/](./design/) | 线框、高保真 |
| 发布 | [gtm/](./gtm/) | 商店与渠道 |
| 官网 | [website/](./website/) | 营销站占位 |
| 代码 | [app/](./app/) | 应用源码区 |

---

## 产品内容

### 一句话

**Routeva** is a smart **proxy client** for people who already have a proxy subscription: paste to connect, explain failures honestly, and safely repair what the client can fix — without selling nodes.

中文对内表述：面向已有代理订阅的普通用户；粘贴即连、诚实诊断、可回滚修复；不提供/不销售节点。

### 背景与问题

现有代理客户端常见三类痛点：配置过重、失败只给技术错误码、用户只能求机场客服或教程。Routeva 不靠堆高级开关，而用 **Self-Healing Loop** 降低理解与操作成本。

### 目标用户

- **核心：** 已有代理订阅、会复制链接、不懂协议/路由/DNS 的普通用户；使用 ChatGPT、YouTube、Telegram 等海外服务。
- **次级：** 有经验但不愿维护配置的用户（自动测节点、选稳定节点、分清客户端 vs 服务商问题）。
- **不做：** 需要 MITM/Rewrite/完整规则编辑的高级玩家；要买节点的新手；企业 VPN；Mac/TV/家庭网关首发。

### 核心能力

1. **Table Stakes Connect** — 导入订阅后自动测节点、选节点、建立 VPN 并验证访问。
2. **Self-Healing Loop** — 分层诊断 → Failure Bucket → 仅 Client-Fixable 可 Repair（快照 + 验证 + 回滚）。
3. **Thick Agent** — 开放自然语言与分流意图；工具白名单；**Diagnostic Engine 为故障裁判**；Cloud AI 仅 Opt-in。
4. **Auto Policy** — 服务商/订阅规则优先 + 客户端智能选节点；非自建全球分流引擎。
5. **Craft** — 关键路径界面与交互精致可信（见 Craft Priority）。
6. **商业（分阶段）** — **Beta 全功能免费**（ADR 0006）；日后规划 Pro / 配额（目标草稿 ADR 0001，非 Beta 门槛）。

### 非目标（MVP）

- 销售或推荐特定机场/节点
- 协议数量竞赛；完整 QX/Surge/Stash 高级语法
- MITM、Rewrite、根证书、远程可执行脚本
- 自建账号体系；默认云端 AI 大脑
- 完整规则编辑器 / 规则市场 / per-App 分流承诺
- 流媒体解锁承诺（偏节点/服务商）
- Mac / Apple TV / 桌面端；iOS 16 及以下

### 平台与分发说明

| 项 | 决议 |
|---|---|
| 平台 | iOS App；**iPhone 主验收**；iPad 可装可用、布局不优先 |
| 系统 | **iOS 17+** |
| 商店 | 美国 App Store 首发优先 |
| 文案语言 | 用户可见 **English** 为源 |
| 身份 | 无自建账号；数据本机（商业化后再依赖 StoreKit 恢复购买） |
| 商业 | **Beta 全免**；目标草稿：Free 深度体验 + Pro Non-Consumable **$2.99** |

### 当前状态与下一步

| 状态 | 说明 |
|---|---|
| 已完成 | 工作区 init；GitHub；CONTEXT + ADR；Craft P0 hi-fi（Home / Setup / Subscriptions 等） |
| 下一步 | **先收敛设计定稿**（hi-fi / IA）；**定稿前 `app/` 不写代码**；之后再搭 iOS 工程与 VPN/Probe 等 |

开放项（实现期可短 grill）：内核选型、Probe 目标、分析事件表、隐私营养标签终稿、TestFlight 样本、**商业化时机与是否沿用 0001** 等。
