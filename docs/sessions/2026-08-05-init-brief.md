# 原料归档 — AI 智能代理客户端 MVP 产品需求

> **原料归档，非权威。** 业务请经 grill 后写入 PRODUCT / PRD / CONTEXT。

- **来源文件：** `AI 智能代理客户端 MVP 产品需求.docx`（副本：`2026-08-05-init-brief-mvp-prd.docx`）
- **归档日期：** 2026-08-05
- **状态：** Grill Q1–Q15 已收口；PRODUCT/PRD v0.1 已写。初版 docx 仍为原料非权威
- **产品名：** Routeva（已确认）
- **文档自称：** V1.0 · MVP · iPhone/iOS · 美国 App Store 为主 · 免费 + 一次性永久解锁（首发 $2.99）

## Grill 决议记录（已收口 Q1–Q15）

### 2026-08-05 — Q1 产品主证明点
- **决议：** A 为主（Self-Healing Loop），B 为必要条件（Table Stakes Connect）
- **补充：** Craft（界面/交互精致）在高保真与交互设计中重点打磨；是交付质量要求，不取代 A 作为 MVP 主证明点
- **已写入：** `CONTEXT.md`（Product Bet / Self-Healing Loop / Table Stakes Connect / Craft 等）

### 2026-08-05 — Q2 免费 / Pro 边界
- **决议：** 免费 = 完整首次成功体验（B + 有限次 A 尝鲜）；Pro = 自动化与长期自愈
- **细则：** 不阉割协议；限制诊断次数与自动化（修复/自动切换/Agent 等），避免默认「硬切断连接」式付费墙；付费墙在成功导入+真实连接之后
- **已写入：** `CONTEXT.md`（Free Experience / Pro Unlock / Paywall Timing）
- **ADR：** 可考虑「免费试用深度 vs 转化」——待 Q 轮次更稳后统一补

### 2026-08-05 — Q3 诊断诚实边界
- **决议：** 只自动修 Client-Fixable；四桶诚实分桶（Client-Fixable / Provider-Side / Environment / Unknown）
- **已写入：** `CONTEXT.md`；ADR `docs/adr/0002-honest-failure-buckets.md`

### 2026-08-05 — Q4 Agent 厚度
- **决议：** C 厚 Agent（开放 NL + 分流意图 + 云端可选）
- **约束保留：** Diagnostic Engine 为故障裁判；工具白名单；隐私；无模型时核心不瘫
- **已写入：** `CONTEXT.md`；ADR `docs/adr/0003-thick-agent-mvp.md`

### 2026-08-05 — Q5 云端 AI
- **决议：** 路线 1 — 云端可选增强，非默认大脑；默认本地/规则/模板
- **已写入：** `CONTEXT.md`（Cloud AI Optional）；更新 ADR 0003

### 2026-08-05 — Q6 协议/格式宽度
- **决议：** 同意瘦身 P0（常见订阅真连优先，非协议数量）
- **已写入：** `CONTEXT.md`（P0 Interop Surface）；ADR `docs/adr/0004-slim-p0-interop.md`

### 2026-08-05 — Q7 产品名
- **决议：** A — Routeva 为最终产品名（商店名仅可轻量微调）
- **已写入：** `CONTEXT.md`

### 2026-08-05 — Q8 语言与市场
- **决议：** 1 — 美区优先；English 为产品语言源；内部文档可中文
- **已写入：** `CONTEXT.md`（Primary Market / Product Language）

### 2026-08-05 — Q9 默认分流 Auto
- **决议：** Auto = 服务商/订阅规则为主 + 客户端智能选节点；非自建全球分流引擎
- **已写入：** `CONTEXT.md`（Auto Policy / User Override Rule / Node Selection）；ADR `docs/adr/0005-auto-means-provider-rules-plus-nodes.md`

### 2026-08-05 — Q10 免费配额数字
- **决议：** 诊断 3 次/安装；Repair 1 次；首次自动选节点可；后台自动切换 Pro；Agent 共享诊断池
- **已写入：** `CONTEXT.md`；更新 ADR 0001

### 2026-08-05 — Q11 Craft 路径优先级
- **决议：** 同意 P0/P1/P2 表（Onboarding/Home/诊断/Repair/付费墙为 P0）
- **已写入：** `CONTEXT.md`（Craft Priority）

### 2026-08-05 — Q12 设备范围
- **决议：** 2 — iPhone 主 + iPad 基础可用（不优先适配）；无 Mac/TV
- **已写入：** `CONTEXT.md`（Device Scope）

### 2026-08-05 — Q13 价格与 IAP
- **决议：** A — Non-Consumable 永久 Pro，美区首发 $2.99 USD
- **已写入：** `CONTEXT.md`（Pro Unlock）

### 2026-08-05 — Q14 账号体系
- **决议：** 1 — MVP 无自建账号；IAP 靠 Apple 恢复购买；数据本机
- **已写入：** `CONTEXT.md`（Identity）

### 2026-08-05 — Q15 最低 iOS
- **决议：** 1 — iOS 17+
- **已写入：** `CONTEXT.md`（Device Scope）

### 2026-08-05 — 收口
- **决议：** 结束本轮 grill（Q1–Q15）
- **已写入：** `PRODUCT.md`、`docs/prd/PRD.md`（v0.1）
- **权威层级：** CONTEXT（术语）> ADR（难逆决策）> PRODUCT/PRD（产品规格）> 本 sessions 原料与初版 docx

### 2026-08-05 — Grill-with-docs 复审 Q1 商业
- **决议：D** — Beta 阶段 MVP 功能默认全部免费、无付费墙；收费项目后期再规划
- **不采用：** Beta 即硬配额；或删除 Free/Pro 目标草稿
- **已写入：** ADR `0006`；更新 `0001` 为草稿；CONTEXT **Beta Access**；PRD §4.8；PRODUCT 元数据

### 2026-08-05 — Grill-with-docs 复审 Q2 连接成功定义
- **决议：B** — Connection Success = 隧道就绪 + Connectivity Probe 成功；非仅 VPN 图标；非流媒体解锁
- **已写入：** CONTEXT（Connection Success / Connectivity Probe）；PRD §4.3、Repair 验证、验收与用户故事；ADR 0007

### 2026-08-05 — Grill-with-docs 复审 Q3 诊断触发
- **决议：A** — 失败才自动诊断；Probe 失败必须自动诊断；成功不强制体检；Agent 同一 Engine
- **已写入：** CONTEXT（Diagnostic Trigger）；PRD §4.4 / 验收；ADR 0008

### 2026-08-05 — Grill-with-docs 复审 Q4 Repair 闭集
- **决议：A** — Repair Allowlist MVP 闭集 6 类；未列入不得作 Repair；扩展须改文档
- **已写入：** CONTEXT（Repair Allowlist）；PRD §4.5；ADR 0009

### 2026-08-05 — Grill-with-docs 复审 Q5 Repair 确认
- **决议：A** — 一键确认后执行；一次确认覆盖多候选；不静默修；Agent 须明确修复意图
- **已写入：** CONTEXT（Repair Consent）；PRD §4.5 / Craft P0 / 验收；ADR 0010

### 2026-08-05 — Grill-with-docs 复审 Q6 Failover vs Repair
- **决议：A** — Node Failover 在自动选节点下自动执行、不经 Repair 确认；与 Repair 严格区分
- **已写入：** CONTEXT（Node Failover）；PRD §4.3；ADR 0011

### 2026-08-05 — Grill-with-docs 复审 Q7 Snapshot
- **决议：A** — Repair/显式策略变更前建快照；Failover 不强制；Beta 10 份或 7 天；失败自动回滚
- **已写入：** CONTEXT（Snapshot Policy）；PRD §4.5.1；ADR 0012

### 2026-08-05 — Grill-with-docs 复审 Q8 Activity
- **决议：A** — Activity 能力 P0（事件可查）、Craft P1；Beta 不可无事件流
- **已写入：** CONTEXT（Activity Log / Craft Priority）；PRD IA 与 §6 / 验收；ADR 0013

### 2026-08-05 — Grill-with-docs 复审 Q9 多订阅
- **决议：A** — 单 Active Subscription；多份可存；不合并池、不并行隧道
- **已写入：** CONTEXT（Active Subscription）；PRD §4.1；ADR 0014

### 2026-08-05 — Grill-with-docs 复审 Q10 订阅更新
- **决议：A** — 冷启动/连接前按 T=6h 刷 Active；禁止固定后台周期；成功少打扰；失败不覆盖
- **已写入：** CONTEXT（Subscription Refresh）；PRD §4.1；ADR 0015

### 2026-08-05 — Grill-with-docs 复审 Q11 Agent 工具闭集
- **决议：A** — Agent Tool Allowlist 只读+变更闭集；禁止项写死；扩展须改文档
- **已写入：** CONTEXT（Agent Tool Allowlist）；PRD §4.6；ADR 0016

### 2026-08-05 — Grill-with-docs 复审 Q12 User Override
- **决议：A** — 服务名或单域名 → proxy|direct；上限 20；无正则/规则市场
- **已写入：** CONTEXT（User Override Rule）；PRD §4.7；ADR 0017

### 2026-08-05 — Grill-with-docs 复审收口
- **决议：A** — 结束本轮（Q1–Q12）；共享理解足够进入设计/实现；开放问题实现期短 grill
- **权威：** CONTEXT > ADR 0001–0017 > PRODUCT/PRD > sessions/docx
