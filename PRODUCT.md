# Routeva

> 产品摘要（权威导航）。术语见 [CONTEXT.md](./CONTEXT.md)；规格见 [docs/prd/PRD.md](./docs/prd/PRD.md)；难逆决策见 [docs/adr/](./docs/adr/)。  
> 初版原料（非权威）：[docs/sessions/2026-08-05-init-brief.md](./docs/sessions/2026-08-05-init-brief.md)。

## 元数据

| 字段 | 值 |
|---|---|
| slug | routeva |
| repo | https://github.com/zyhang/Routeva |
| primary_type | ios |
| secondary_types | android |
| types | ios, android |
| code_layout | Dual-Native：`app/ios/` + `app/android/`（ADR 0049） |
| min_os | iOS 17+；Android 待实现期定 minSdk（建议 API 26+，PRD 显式） |
| market | 美国 App Store / Google Play 双端开发；商店叙事仍可分区优先 |
| product_language | English 源（`docs/copy/en.yaml` · ADR 0053）；App 8 locale（M · 0048）；壳机翻 · T1（0047） |
| business | **Beta：全功能免费**；目标草稿 Free + Pro $2.99 永久（见 ADR 0001/0006；双端 IAP 为实现差异） |
| updated | 2026-08-06 |
| status | MVP = Connect（**无 Help** · ADR **0063**）；实现默认 iOS 先（0061）；设计打磨主路径 |

## 工作区导航

| 域 | 路径 | 说明 |
|---|---|---|
| 术语 | [CONTEXT.md](./CONTEXT.md) | 领域语言 |
| 需求 | [docs/prd/](./docs/prd/) | PRD |
| 过程稿 | [docs/sessions/](./docs/sessions/) | grill / Brief 原料 |
| 决策 | [docs/adr/](./docs/adr/) | ADR |
| App 文案键 | [docs/copy/](./docs/copy/) | English 键值源（P0+壳 · ADR 0053） |
| 品类实践 | [docs/guides/](./docs/guides/) | iOS / Android L2 |
| 设计 | [design/](./design/) | 线框、高保真（两端 UI 真源；平台控件差异属 Realization） |
| 发布 | [gtm/](./gtm/) | 槽位与 specs；**现阶段 Brand Presence 为主**（商店 listing 等真机） |
| 官网 | [website/](./website/) | 营销站占位 |
| 代码 | [app/](./app/) | Dual-Native：`ios/` · `android/` |

---

## 产品内容

### 一句话

**Routeva** is a smart **proxy client** for people who already have a proxy subscription: paste to connect and stay online — without selling nodes. (Honest diagnostics & safe repair: post-MVP.)

中文对内表述：面向已有代理订阅的普通用户；粘贴即连、诚实诊断、可回滚修复；不提供/不销售节点。

### 背景与问题

现有代理客户端常见三类痛点：配置过重、失败只给技术错误码、用户只能求机场客服或教程。Routeva 不靠堆高级开关，而用 **Self-Healing Loop** 降低理解与操作成本。

### 目标用户

- **核心：** 已有代理订阅、会复制链接、不懂协议/路由/DNS 的普通用户；使用 ChatGPT、YouTube、Telegram 等海外服务。
- **次级：** 有经验但不愿维护配置的用户（自动测节点、选稳定节点、分清客户端 vs 服务商问题）。
- **不做：** 需要 MITM/Rewrite/完整规则编辑的高级玩家；要买节点的新手；企业 VPN；Mac/TV/家庭网关首发。

### 核心能力

**MVP（ADR 0063）**

1. **Table Stakes Connect** — 导入订阅后测节点、选节点、建立 VPN 并以 Connectivity Probe 验证访问。
2. **Auto Policy（Smart）** — 服务商/订阅规则优先 + 客户端智能选节点。
3. **Craft** — 关键连接路径精致可信。
4. **商业（分阶段）** — **Beta 全功能免费**（ADR 0006）；日后规划 Pro（草稿 0001）。

**Post-MVP（规格保留，不进 MVP UI）**

5. **Self-Healing Loop** — 诊断四桶 → Repair（快照 + 验证 + 回滚）。
6. **Help / Thick Agent** — NL + 工具白名单 + Cloud 可关；Engine 为故障裁判。

### 非目标（MVP）

- 销售或推荐特定机场/节点
- 协议数量竞赛；完整 QX/Surge/Stash 高级语法
- MITM、Rewrite、根证书、远程可执行脚本
- 自建账号体系；默认云端 AI 大脑
- 完整规则编辑器 / 规则市场 / per-App 分流承诺
- 流媒体解锁承诺（偏节点/服务商）
- Mac / Apple TV / 桌面端；iOS 16 及以下
- 默认跨端 UI 壳（Flutter/RN 等作主实现）；编译期共享业务内核（除非另开 ADR）

### 平台与分发说明

| 项 | 决议 |
|---|---|
| 平台 | **能力 Dual-Native 单源**（ADR 0049）；**实现 / Beta 默认 iOS 先**（ADR **0061**）；能力列表**不**按端永久分叉 |
| iOS 设备 | **iPhone 主验收**与首版 Beta 主轨；iPad 可装可用、布局不优先 |
| Android 设备 | **同一能力表**；手机主验收；可标 Platform Gap，不阻塞 iOS Beta |
| 系统 | **iOS 17+**；Android minSdk 实现期锁定（建议 ≥ API 26） |
| 商店 | App Store + Google Play；叙事/合规可分区优先，产品语义单源 |
| 文案语言 | **English** 源（[`docs/copy/en.yaml`](./docs/copy/en.yaml) · ADR 0053）；App **en·zh-Hans·zh-Hant·es·pt-BR·ja·ko·de**（壳机翻；诊断/Repair/隐私锁 en · 0047/0048）；GTM 精做 en 优先 |
| 身份 | 无自建账号；数据本机（商业化后：StoreKit / Play Billing 恢复购买 = Platform Realization） |
| 商业 | **Beta 全免**；目标草稿：Free 深度体验 + Pro Non-Consumable **$2.99**（双端价位对齐，实现 API 不同） |
| VPN 实现 | iOS：Network Extension / 系统 VPN 弹窗；Android：VpnService / 系统 VPN 权限 — 同一「连接」能力的 Realization |

### 当前状态与下一步

| 状态 | 说明 |
|---|---|
| 已完成 | 工作区 init；GitHub；CONTEXT + ADR；Craft P0 hi-fi；Dual-Native 布局（0049）+ **iOS-first 实现节奏**（0061）；grill 文档↔hi-fi 收口；实现 checklist 已备 |
| 下一步 | **MVP = Connect**（无 Help · ADR **0063**）；继续主路径设计/文案；**`app/` 暂不写代码**。开编码：**先 `app/ios/`**。表见 [`docs/prd/implementation-checklist.md`](./docs/prd/implementation-checklist.md) |

开放项（实现期可短 grill）：iOS 内核选型、**Probe 具体 host 部署**（形态已定 grill A：主+热备 HTTPS）、分析事件表、隐私营养标签、TestFlight 轨道、**商业化时机与是否沿用 0001**、Android minSdk / Play 数据安全表与追齐里程碑等。
