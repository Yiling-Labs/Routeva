# PRD — Routeva MVP

> 基于 grill Q1–Q15 + grill-with-docs 复审 Q1–Q12（2026-08-05）收口。术语以 [CONTEXT.md](../../CONTEXT.md) 为准；摘要见 [PRODUCT.md](../../PRODUCT.md)。  
> 原料（非权威）：[../sessions/2026-08-05-init-brief.md](../sessions/2026-08-05-init-brief.md) 与初版 docx。

| 字段 | 值 |
|---|---|
| 产品 | Routeva |
| slug | routeva |
| repo | https://github.com/zyhang/Routeva |
| primary_type | ios |
| secondary_types | android |
| types | ios, android |
| code_layout | Dual-Native（ADR 0049） |
| min_os | iOS 17+；Android minSdk 实现期锁定 |
| updated | 2026-08-06 |
| status | MVP = Connect（**无 Help/诊断 UI** · ADR **0063**）；iOS 先（0061）；Beta 全免（0006） |

## 1. 背景与目标

### 1.1 问题

代理客户端对普通订阅用户过重：配置复杂、失败不可解释、修复依赖人工。

### 1.2 MVP 要证明什么

| 优先级 | 内容 |
|---|---|
| **主证明点（MVP）** | Table Stakes Connect：粘贴/导入即可稳定 Connection Success |
| **交付质量** | Craft：导入→连接路径精致可信 |
| **Post-MVP** | Self-Healing Loop + Help/Agent（ADR **0063**） |

**不证明（MVP）：** 完整自愈 UI、聊天机器人、协议数量军备。

### 1.3 成功标准（沿用初版方向，实现期可校准）

导入成功率、首次连接成功率/耗时、可识别失败原因比例、可自动修复比例、免费→Pro 转化、退款率、评分、留存与连接稳定性。北极星侧重 **修复成功率 + 连接稳定性**，非对话次数。

## 2. 用户与场景

### 2.1 目标用户

已有 Subscription、能复制链接、不懂协议细节的普通用户（美区商店叙事优先；用户可全球）。

### 2.2 关键场景（JTBD）

1. 粘贴订阅 → 达到 Connection Success（无需理解协议名）。
2. 连接失败 → 回 Idle + 短 toast，可立即再连（ADR **0059**；**MVP 无** Help/诊断 UI · **0063**）。
3. 选节点 / Mode / DNS / Overrides / 多订阅管理可用。
4. （Post-MVP）诊断分桶 → Repair；Help NL。
5. （商业化后）Pro；**Beta 无此门槛。**

## 3. 范围

### 3.1 In scope（MVP）

- 订阅导入（粘贴、剪贴板、二维码、文件、单节点 URI）— 宽度见 P0 Interop
- VPN 连接、节点测试、Node Selection、首次自动选节点连接
- Diagnostic Engine 四层检查 + Failure Bucket 展示
- Repair 白名单 + Config Snapshot + 回滚
- Thick Agent + Cloud AI（Help 内默认开、可关 · ADR 0042；非全 app 静默大脑）
- Routing Mode：**Smart** / Global / Direct（用户可见；内部 id `auto`/global/direct）；Smart = 服务商规则 + 选节点
- **Beta：全功能开放（无配额/无付费墙）**；目标 Free/Pro 与 $2.99 见 §4.8 草稿与 ADR 0001/0006
- 无账号；本机数据；隐私边界（Token 不上云等）
- Craft P0 路径英文化打磨
- **iOS + Android 能力单源**（Dual-Native · 0049）；**实现 / Beta 默认 iOS 先**（0061）；平台 API 为 Realization
- iPhone 主 + iPad 基础；iOS 17+；Android 手机主验收

### 3.2 Out of scope（MVP）

- **Help / Agent Surface、诊断结果 UI、Repair UI、Cloud AI**（ADR **0063** · Post-MVP）
- 节点销售/推荐机场
- 完整 QX/Surge/Stash 高级语法；暂缓协议列表（SSH/ShadowTLS/MASQUE 等）
- MITM / Rewrite / 根证书 / 远程脚本
- 规则市场、完整规则编辑器、per-App 分流承诺
- 强制账号、默认云端大脑、自建跨端账号同步；**全量**配置 / 订阅 Token 的 iCloud 或跨端同步（**例外：** iOS 仅 **User Override** 经用户 iCloud 备份——ADR **0054**；Android 无此能力，记 Platform Gap）
- Mac / Apple TV / 桌面；iOS 16−
- 默认跨端 UI 壳或编译期共享业务内核（除非另 ADR）
- 流媒体解锁 SLA

## 4. 需求详述

### 4.1 首次启动与导入

- **First-Run（ADR 0019）：** Welcome（仅一次：三词 *Paste / Connect / Smart*，无副文）→ Data & Privacy（仅一次：*On device / No tracking* + Privacy Policy 外链，无说明卡）→ Home Empty → 用户主动 Add subscription。**无** 1·2·3 卡片墙；**无** 应用内 VPN 说明页。
- **VPN 权限（Platform Realization）：** 首次真正连接手势时出 **系统 VPN 授权**（iOS：系统 VPN 弹窗；Android：VpnService / 系统 VPN 权限流）；拒绝 → 回 Home Idle；同意 → 连接至 Connection Success。用途说明放商店/隐私文案，不单独做应用内说明屏。不要求注册/邮箱。
- **Add Subscription：** Paste from Clipboard 为主，Scan QR / Import file 为辅；**无**手填主 UI、**无**「剪贴板已发现」独立页。解析为叠在 Add 上的 **Parsing 模态**（源相关文案：*Reading from Clipboard…* / *Reading QR code…* / *Reading file…*）。失败：页内短句 + Paste again；**不覆盖**已有配置。
- **导入成功：** 直接回 **Home Idle（同壳）** + 短 toast（**Subscription Display Name · 节点数**；**2–3s** 自动消失）；设 Active；**不**自动连；**不**强制命名（自动取名 + Subscriptions 内可选 Rename，见 ADR 0033）。详细字段（到期/流量/更新时间等）进订阅详情，不挡首次路径。
- **多订阅模型（Active Subscription）：** 可保存多份 Subscription；同一时间仅 **1 个 Active** 用于连接 / 选节点 / Probe / 诊断 / Repair / Failover。切换 Active 须用户明确操作，记入 Activity；不默认合并多订阅节点池；不做多隧道并行。首次导入的订阅自动成为 Active。
- **Subscription Refresh（少打扰 · ADR 0015）：**
  - **用户总闸：** Settings › App · **Auto-update subscription**（全局 Toggle，**默认开**）。关 → 无自动路径。
  - **内容：** 成功则**整份替换**（节点 + 可解析服务商规则/策略组 + 有则到期/流量元数据 + *Updated*）；用户 Rename 的显示名不覆盖。
  - **自动触发（闸开）：** 仅**严格冷启动**（不含热启动/回前台、**不含**点连接）；Active；距上次成功 ≥ **T**（默认 **24h**）；且有可复访远程源。无远程源 → 静默 no-op。
  - **禁止：** 固定后台周期拉订阅；连接前自动刷。
  - **成功：** 安静落盘 + Activity；Preferred / 上次节点失效 → 静默取消偏好，下次连接 Node Selection；**不**弹成功打扰。
  - **自动失败：** 完全安静；**不覆盖**已有可用配置；不强制诊断横幅。
  - **手动：** Subscriptions **Update** 随时可；失败短 toast（2–3s，*Couldn’t update. Check your connection and try again.*），无卡内错误条；Repair #2 = 失败路径重载。
  - 非 Active：不自动刷，除非切换为 Active 后满足条件或用户手动。

### 4.2 P0 互操作（瘦身）

**须真连 + 自动化测试**

| 类 | 内容 |
|---|---|
| 格式 | Clash/Mihomo YAML；V2Ray Base64 订阅；URI：ss / vmess / vless / trojan / hysteria2 |
| 协议 | VLESS(+Reality)、VMess、Trojan、Shadowsocks、Hysteria2 |

**实验/补充（不进主卖点）：** sing-box JSON（若顺带）、TUIC、WireGuard、HTTP/SOCKS5。  
**首发不做：** 完整 QX/Surge/Stash 高级语法；远程脚本；暂缓协议列表。

### 4.3 连接与 Node Selection

权威决策：**ADR 0055**（Node Selection 政策）· **ADR 0056**（Location 点选 = Preferred）；术语：**CONTEXT → Node Selection / Location Surface / Preferred node / Latency Test / Node Failover**。

**Connection Success**

- 系统 VPN/隧道就绪 **且** 至少一次 **Connectivity Probe** 成功。仅隧道就绪而探针失败 → **不得**宣称成功；Home 回 **Idle** + 短 toast（ADR **0059**）；**不**弹诊断 UI（MVP 无 · ADR **0063**）。
- Connectivity Probe（grill **A**）：经当前节点 **HTTPS** 固定端点（TLS + **2xx**）；**主 URL + ≥1 热备**；内部常数、非 UI；用于选节点**加权**、连接验收与 Repair 验证；**不是**流媒体/站点解锁检测。
- Wi‑Fi / 蜂窝切换后应能恢复连接（恢复后仍以 Probe 判定是否 Success）。

**Node Selection 政策（ADR 0055）**

| 规则 | 要求 |
|---|---|
| 评分目标 | 延迟 / 握手 / 可达（含 Probe 信号）/ 近期失败与稳定性等**加权**；**禁止**仅 Ping |
| 地区 | **不进**默认评分；不根据 locale/时区/语言猜出口国（如默认香港） |
| 测速时机 | Active 导入成功（及重测触发）后 **静默预评分**，Cover Flow **预停**最高分（有 Preferred 则预停偏好）；**不**自动连；**禁止**把全表测压在连接手势关键路径 |
| 静默信号 | **轻量分层**：快速层（入口延迟/握手）+ 对前列候选加深；**不得**静默全表完整出网 Probe；静默测分**不得**染绿场 / 宣称 Connected |
| 测分未完 | **可连**；连接路径短确认 + 完整 Probe；Connecting/Connected **不被**后续预选换脚 |
| 重测触发 | ① 节点集合实质变化 ② 长间隔缓存过期 S + 打开/回前台（弱）③ 失败/Failover **定向**重测 ④ 用户 Location *Test*；**禁止**仅网络切换就全表重测 |
| 状态机 | **两档：** **Auto 预选** vs **Preferred node**。Cover Flow 横滑 = **临时浏览焦点**（无 Preferred 时可被预选覆盖）。**不设**硬 Pin（禁 Failover） |
| Cover Flow 条 | **有界快选** `strip[]` ≤ **N=15**（默认）：**Preferred 强制入条** + 预评分可用性 Top 填满（去重）。**非**全量 flatten；**无** group UI。总数 &lt;N → 全进条。测分未完：有分在前、无分订阅原序。初始预停 Preferred 否则 Top#1。Failover 不永久扩条 · 全量列表在 Location |

**Preferred node（偏好节点）**

- 默认连接目标；静默预选**不得覆盖**；**Node Failover 仍允许**为保活换走会话节点（偏好不因 Failover 改写）。
- **入口：** **Location Surface** 点选 = 设 Preferred；返回 Home 时 Cover Flow 对齐偏好；会话因 Failover 暂用他节点时 Home 显示**当前会话**节点。
- **清除：** **无** `⋯` / *Use automatic* UI。节点离开 Active 列表 → 静默丢弃偏好；改偏好 = 点另一节点。
- 已 Connected 时点选另一节点：立即切换（非 Repair）；失败**保留偏好**，toast/回退可连态，**不**自动诊断。
- Home Cover Flow 横滑** alone 不构成 Preferred**。

**Node Failover vs Repair**

- **Failover：** 自动选节点开启时，为维持 Connection Success **自动**换节点/短重连（**含有 Preferred 时**）；不走 Repair 确认；记 Activity；**成功换节点 → 一次短 toast**（grill D · 无常驻离偏好 UI）。
- **Repair：** 仅 Client-Fixable + 用户确认的 Allowlist（其中也可换节点，语义是「修」不是「保活」）。
- **关闭自动选节点** → 禁止静默 Failover。

**Beta：** 含自动选节点与 Node Failover（全免）。目标商业草稿中 Free 仅「首次」自动连、后台切换属 Pro——见 §4.8.2，Beta 不执行。

**Location Surface**

- 从 Home **Cover Flow 下节点名行**（黑场 Idle，可点）或 **Connected 中部节点行**（绿场，可点；**不**恢复 Cover Flow）全屏 push；标题 *Location*。Swipe / Connecting 节点名行锁定。
- 只列 **Active** 订阅**全部**出口节点；**无**分组 chip；顺序 = **订阅原序**；**不**按客户端猜地区重分类或按延迟重排；**无**列表顶伪造 Auto 行。
- **行：** 主行节点名 + Preferred 时 check（**无** *Pinned* 文案）；次行弱协议短名（`SS`/`VMess`/`VLESS`/`Trojan`/`Hy2`，与 Home 同源）· Latency（`—` / `{ms} ms` / `Timeout`）。
- **Latency Test：** 顶栏 *Test* 批量入口延迟/握手标注（非 ICMP *Ping* 叙事、非完整 Probe）；可取消；**不**改偏好、**不**自动切、**不**按 ms 重排。
- MVP：**无**搜索/筛选、**无**进页自动测、**无**客户端伪造的列表顶 *Auto* 行、**无**顶栏 `⋯`、**无**订阅 CRUD 主路径、**无**全部组纵向长卷主路径。
- 权威 hi-fi：`design/hi-fi/current/craft-p0/08-location.html`。

### 4.4–4.6 诊断 · Repair · Help / Agent（**Post-MVP** · ADR **0063**）

**MVP 不交付** Diagnostic 四桶 UI、Repair 流、Help/Agent Surface、Cloud AI。  
领域闭集（Failure Bucket、Repair Allowlist、Tool Allowlist 等）见 CONTEXT 与历史 ADR（0002 / 0009 / 0010 / 0035–0044 / 0042 / 0060）；恢复时整包里程碑。  
**MVP 失败路径：** Idle + toast（**0059**）· Failover toast（grill D）· 用户再连或检查订阅。

### 4.5.1 Config Snapshot（MVP 精简）

| 规则 | 要求 |
|---|---|
| MVP | 显式改 Mode / Override / DNS 等策略前可建快照；Failover 不强制全量快照 |
| 保留 | 约 10 份或 7 天 |
| Post-MVP | Repair 前必建；失败自动回滚 |

### 4.7 Auto Policy 与分流

- Auto = **订阅/服务商规则优先** + 客户端智能选节点；客户端仅安全兜底（如局域网直连）。
- 不承诺流媒体解锁。
- Global / Direct 为显式总开关（**不计入** Override 条数）。
- **User Override Rule（形态 A）：**
  - 每条：`目标` = **单个域名** → `proxy | direct`（**无** Service 预设；ADR **0057**）。
  - 可预览、可关、可回滚；应用前按 Snapshot Policy 建快照（显式策略变更）。
  - 须提示可能与订阅/服务商规则**叠加**；不静默删除服务商规则。
  - **Beta 不设条数硬上限**（ADR 0050）；意图仍为少数例外，靠 O3 文案而非配额。
  - **iOS · User Override iCloud Backup（ADR 0054）：** 默认静默备份到用户 iCloud；空库整表恢复；非空不一致则按 Domain 合并（`updatedAt` 较新整条胜 / 墓碑删）；冷启动·前台·进 Overrides 读云；变更后写云；恢复/合并后尽快作用于分流。成功恢复可短 toast；**仅**空库恢复失败弱提示；无主开关、不记 Activity。**Android：** Platform Gap（本机-only）。
  - **不做：** 正则、Rule Set 市场、JS 规则、per-App 分流；订阅/Mode/DNS/快照经 iCloud；多设备实时同步 SLA。

### 4.8 商业：Beta 全免 + 目标 Free / Pro 草稿

#### 4.8.1 Beta 行为（当前有效）

- MVP In-scope 能力**全部可用**：多订阅、不限诊断/Repair、自动选节点与后台故障切换、Agent、提醒与快照等 **不限额**。
- **不展示付费墙**；不依赖 IAP 才能用核心路径。
- 验收与北极星：**修复成功率 + 连接稳定性**（及导入/连接/分桶诚实性），**不是**转化率。
- 权威：ADR `0006`；术语：CONTEXT **Beta Access**。

#### 4.8.2 目标商业模型（草稿，商业化后再确认）

下表与 ADR `0001` 为**日后规划收费的草稿**，**Beta 不执行**。

| 能力 | Free（按本机安装） | Pro（$2.99 永久，价可改） |
|---|---|---|
| 导入 | 1 个 Subscription | 多订阅 |
| 协议/测节点/手动选节点 | ✅ | ✅ |
| 首次自动选节点连接 | ✅ | ✅ 持续自动选 + **后台故障切换** |
| 完整诊断 | **3** 次 | 不限 |
| Repair | **1** 次 | 不限 |
| Agent | 可进；诊断共享 3 次池；Repair 单独 1 次 | 全量 |
| 提醒 / 无限快照等 | 否或极有限 | ✅ |

**Paywall Timing（仅商业化后）：** 不在首次启动强塞；先导入并真实连上；在配额用尽、再次诊断、自动修复/切换、Agent 高价值动作等处触发。优先限制自动化，不默认硬切 VPN。

### 4.9 隐私与身份

- 无自建账号；StoreKit 恢复购买；敏感配置用系统安全存储。
- 禁止默认收集完整浏览历史、网页内容、原始 Token、未脱敏凭证等（详见初版原则，实现期对照隐私清单）。
- 导出诊断报告自动脱敏。

### 4.10 信息架构（MVP）

> 权威 UI：`design/wireframes/current/craft-p0/00-ia.md` + `design/hi-fi/current/craft-p0/`。**无底部 Tab**；根画布仅 Home。

| 面 | 内容 |
|---|---|
| **Home** | 选节点 + 竖直胶囊 + 连接真值；Mode Smart/Global；失败/Failover toast；顶栏 **Subscriptions · Settings**（**无 Help** · **0063**）。权威：`02-home.html` |
| **Location** | 扁平全量 · Preferred · Test。权威：`08-location.html` |
| **Subscriptions** | 单列表 + Active。权威：`04-subscriptions.html` |
| **Settings** | Connection · App。权威：`05-settings.html` |
| **Activity** | **仅本机记录**（无 UI · 0051 / 0063） |
| **Help / Diagnostic / Repair** | **Post-MVP**（explore 存档 · 0063） |

**Beta 不暴露：** Settings Advanced / 高级模式坟场（ADR 0027）。日后若加深层调试入口另议；Mode / DNS / Override / Export 等已落正式面或次要动作，不依赖 Advanced。

## 5. 用户故事（摘要）

- 作为订阅用户，我粘贴链接后无需选协议即可达到 Connection Success（隧道 + Probe），而非仅看到 VPN 已连接。
- 作为用户，失败时我看到诚实 toast 并可再试（MVP **无**四桶解释 UI）。
- 作为 Beta 用户，我能使用 MVP 连接能力且无付费墙。
- （Post-MVP）诊断分桶、Repair、Help NL。

## 6. 交互与 Craft 优先级

| 优先级 | 路径 |
|---|---|
| **P0 Craft** | Welcome→Empty→Add→Idle；VPN 系统弹窗→连上；Home / Location / Subs |
| **P0 能力** | Activity 本机记录；Settings 策略 |
| **Post-MVP** | Help / 诊断 / Repair / Agent |

原则：诊断/修复反馈质感 ≥ 装饰动效。用户可见文案 English 源。高保真见 `design/`。

## 7. 验收标准（上线门槛方向）

- P0 协议真连测试通过；主要格式导入达标。
- Connection Success 定义落地：自动化/手工验收均以隧道 + Connectivity Probe 为准；探针失败不得标为成功。
- **MVP 无**诊断/Repair/Help UI（ADR **0063**）；连接失败 = Idle + toast（**0059**）。
- 无高频崩溃与 VPN 异常退出；配置修改可回滚。
- 凭证不进分析通道；Cloud 仅脱敏临时上下文且可关；Agent **仅** Tool Allowlist；变更类无用户明确意图/Consent 不得改网。
- 错误提示均有下一步；删除 App 不遗留失控 VPN 配置。
- （商业化后）IAP 购买与恢复购买正常；**Beta 不验收 IAP。**
- 四桶诊断与 Repair 边界行为符合 CONTEXT；Repair **仅** Allowlist 6 类；自动化测试覆盖「非白名单动作不可作为 Repair」。
- Repair Consent：无用户确认不得执行 Repair；一次确认可多候选；失败/取消须回滚。
- Node Failover：自动选节点开启时可自动换节点且不经 Repair 确认（**含有 Preferred 时**）；关闭自动后不得静默切换；记 Activity；**成功切换短 toast**（`home.failover.toast`）；连续失败 **不**自动诊断（用户可 Help）。
- Location Surface（ADR 0055/0056）：扁平订阅原序列表；**点选 = Preferred**；已连接立即切换；顶栏 Latency Test；**无** group chip / `⋯`；静默重测**不**覆盖 Preferred；**无**硬 Pin 禁 Failover。
- Snapshot Policy：Repair 前必有可回滚点；失败/取消自动回滚；Beta 至少 10 份或 7 天；Failover 不强制完整快照。
- Activity：MVP 须**记录**连接 / Failover / 模式等；**无**用户列表（0063）。
- Active Subscription：同时仅一份参与连接与自愈；切换显式；不合并节点池、不并行多隧道。
- Subscription Refresh（ADR 0015）：Settings › App 全局 Auto-update 默认开；开时仅严格冷启动 + T=24h 刷可远程刷新的 Active；无连接前/后台周期；整包替换；自动失败安静不覆盖；手动 Update 在 Subscriptions。
- **UI 态实现任务（open）：** 无远程源 Active **1d**、手动 Update 失败 **1e** — 见 [`features/subscription-refresh-ui-states.md`](./features/subscription-refresh-ui-states.md)（IMPL-SUB-1d / 1e）。
- **实现勾选总表：** [`implementation-checklist.md`](./implementation-checklist.md)（双端 · 屏 · 文案 · 门槛 · 建议顺序）。
- Subscription Display Name：导入静默自动取名（配置名 → 元数据/文件名 → host 弱名 → 中性默认）；可选 Rename（名旁铅笔）；不承诺服务商品牌名（ADR 0033）。
- User Override：仅**单域名** → proxy|direct；Beta **无**条数硬上限；无 Service 预设、无正则/规则市场；Global/Direct 另计（ADR **0057** / 0050）。
- User Override iCloud Backup（iOS · ADR 0054）：换机/重装后空库可恢复例外列表；非空可合并；无 iCloud 时本机可用；Android 不假装已有。订阅等其余配置仍须本机重导。
- Cloud 关闭或无网时核心连接/诊断/Repair 与 Help 本机路径仍可用（ADR 0042）。

## 8. 指标与成功定义

匿名产品指标方向：导入/连接/诊断/修复/回滚/转化/崩溃/VPN 异常退出等。  
禁止上传节点地址、访问域名、订阅内容、未授权对话原文；Agent 优先结构化意图枚举。

## 9. 依赖与风险

| 风险 | 缓解（已决策） |
|---|---|
| 协议范围失控 | 瘦身 P0；数量非北极星 |
| AI 噱头 | Engine 判定；无模型可降级；量修复率 |
| 诊断不准 | 四桶 + 置信度 + 禁止编造 |
| 被当机场客服 | 定位不卖节点；Provider-Side 标准话术 |
| 免费白嫖 | Beta 接受；商业化时再定配额（草稿见 0001） |
| 后台不稳 | 稳定性优先于花活 |
| 商业化时用户反弹 | 保留 0001 草稿；上线前单独 grill 价格与墙 |

ADR：`0001`–`0005`（初轮）· `0006` Beta 全免 · `0007` Connection Success · `0008` 诊断触发 · `0009` Repair 闭集 · `0010` Repair 确认 · `0011` Failover · `0012` Snapshot · `0013` Activity · `0014` Active 订阅 · `0015` 订阅刷新 · `0016` Agent 工具 · `0017` Override 结构化 · `0042` Help Cloud 默认开 · `0049` Dual-Native · `0050` Override Beta 无条数上限 · `0051` Settings 无 History 段 · `0055`/`0056` Node/Location · `0057` Override Domain only · **`0061` 实现 iOS 先** · **`0062` 台湾节点旗 PRC** · **`0063` MVP 无 Help**。

## 10. 里程碑（建议）

1. 内部：VPN + P0 协议真连 + 订阅标准化 + 测试架  
2. 封闭测试：真实订阅兼容、诊断准确率、首次连接 Craft  
3. 公开测试：稳定性、转化、客服压力  
4. 美区首发：商店叙事 *Paste your subscription. We handle the rest.*（解释失败与修复，而非空泛 AI）

## 11. 开放问题

- 深层调试入口是否在商业化后出现（Beta 无 Advanced）
- 匿名分析事件字典与隐私营养标签终稿  
- 网络内核与扩展架构选型  
- **商业化触发条件**与是否沿用 0001 配额/$2.99（Beta 后另议）  
- Snapshot 保留常数是否在实现中从 10/7 天微调  
- TestFlight 人数与样本机场覆盖  
- 商店显示名是否加轻量后缀  

## 相关路径

- [PRODUCT.md](../../PRODUCT.md)
- [CONTEXT.md](../../CONTEXT.md)
- [docs/adr/](../adr/)
- [docs/sessions/](../sessions/)
- [docs/guides/](../guides/)
- [design/](../../design/)
- [gtm/](../../gtm/)
