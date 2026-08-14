# Routeva MVP · 实现 Checklist

> **用途：** 双端（iOS / Android）开工与里程碑勾选。不发明新能力——只汇总 PRD · CONTEXT · ADR · craft-p0 hi-fi · grill 决议。  
> **文案：** `docs/copy/en.yaml`（ADR **0053**）；按屏验收：`docs/copy/acceptance-by-screen.md`。  
> **UI 真源：** `design/hi-fi/current/craft-p0/` + `design/wireframes/current/craft-p0/00-ia.md`。  
> **定稿前** `app/` 不写代码的策略见 `PRODUCT.md`——**本表在「设计收口已完成」后使用。**  
> **节奏（ADR 0061）：** **iOS 列优先勾满**证明 Self-Healing；Android 可后填或标 Gap，**不**阻塞 iOS Beta。

| 字段 | 值 |
|---|---|
| 范围 | MVP · **Connect only**（**无 Help** · ADR **0063**）；Beta 全免（0006）；iOS 先（0061） |
| 平台 | iOS 17+（iPhone 主轨）；Android minSdk 实现期锁定（建议 ≥ 26） |
| 更新 | 2026-08-07（grill · **0063 无 Help**） |

**图例：** `[ ]` 未做 · `[x]` 完成 · **iOS** / **Android** 分列勾（Android 空着 = 预期 Gap，须在 status 写目标）。  
**Craft：** P0 = 须像素级对齐 hi-fi；P1 = 能力先通、UI 可后打磨。

---

## 0 · 开工闸门（先勾再写业务）

| # | 项 | iOS | Android | 权威 |
|---|---|---|---|---|
| 0.1 | craft-p0 / IA / 本文与 PRD 无未决议分叉 | [ ] | [ ] | PRODUCT · grill 收口 |
| 0.2 | 工程骨架：`app/ios/` · `app/android/` 可编译空壳 | [ ] | [ ] | ADR 0049 |
| 0.3 | 文案 catalog：灌入 `en.yaml`（Android key：`.` → `_`） | [ ] | [ ] | ADR 0053 |
| 0.4 | 8 locale 壳挂载策略就绪（机翻可后；en 源先跑通） | [ ] | [ ] | 0047 / 0048 |
| 0.5 | 安全存储方案选定（Keychain / EncryptedSharedPreferences 等） | [ ] | [ ] | PRD §4.9 |
| 0.6 | VPN 扩展/服务工程目标就绪（NE / VpnService） | [ ] | [ ] | Platform Realization |
| 0.7 | Probe：**主 HTTPS URL + ≥1 热备**；成功 = TLS+2xx；内部配置非 UI（占位可，上架前锁定） | [ ] | [ ] | ADR 0007 · grill A |

---

## 1 · 内核与互操作（无 UI 也可测）

| # | 项 | iOS | Android | 权威 |
|---|---|---|---|---|
| 1.1 | P0 格式导入：Clash/Mihomo YAML · V2Ray Base64 · URI ss/vmess/vless/trojan/hy2 | [ ] | [ ] | PRD §4.2 |
| 1.2 | P0 协议真连自动化 | [ ] | [ ] | PRD §4.2 · §7 |
| 1.3 | 导入失败：**不覆盖**已有配置 + 可分桶/可解释原因 | [ ] | [ ] | CONTEXT Add Subscription |
| 1.4 | **Active Subscription** 仅 1 份参与连接/选节点/诊断/Repair | [ ] | [ ] | ADR 0014 |
| 1.5 | **Connection Success** = 隧道就绪 **且** Probe 成功（单 HTTPS · 主失败试热备） | [ ] | [ ] | ADR 0007 · grill A |
| 1.6 | Probe 失败 **不得** 染绿场 / 标 Connected | [ ] | [ ] | ADR 0007 |
| 1.7 | **Node Selection** 预评分（非仅 Ping；地区不进默认分） | [ ] | [ ] | ADR 0055 |
| 1.8 | 静默测 **不** 染绿、**不** 阻塞可连 | [ ] | [ ] | ADR 0055 |
| 1.9 | **Node Failover** ≠ Repair；有 Preferred 仍可 Failover；关自动选则禁静默换；**成功换节点短 toast**（`home.failover.toast`） | [ ] | [ ] | ADR 0011 · grill D |
| 1.10 | Diagnostic Engine / 四桶 UI | **Post-MVP** | — | ADR 0063 |
| 1.11 | Repair Allowlist / Repair UI | **Post-MVP** | — | ADR 0063 |
| 1.12 | Repair 流 | **Post-MVP** | — | ADR 0063 |
| 1.13 | Snapshot 保留策略（Beta：约 10 份或 7 天） | [ ] | [ ] | ADR 0012 |
| 1.14 | **Subscription Refresh**：总闸 · 仅严格冷启动 · T=24h · 整包替换 · 自动失败安静 | [ ] | [ ] | ADR 0015 |
| 1.15 | **User Override**：单域名 → proxy\|direct；Beta 无条数硬上限 | [ ] | [ ] | ADR 0057 · 0050 |
| 1.16 | **iOS** Override iCloud 备份；**Android** 本机-only（不假装有云） | [ ] | [ ] | ADR 0054 |
| 1.17 | Auto = 服务商规则优先 + 客户端选节点 | [ ] | [ ] | ADR 0005 |
| 1.18 | DNS 仅三预设（Automatic / Privacy / Compatibility） | [ ] | [ ] | ADR 0029 |
| 1.19 | Routing：用户可见 **Smart** / Global / Direct（内部 id auto） | [ ] | [ ] | ADR 0032 · grill Smart 统一 |
| 1.20 | **Activity** 本机记录（连接/Failover/诊断/Repair/回滚/模式等） | [ ] | [ ] | ADR 0013 · 0051 |
| 1.21 | Agent / Tool Allowlist | **Post-MVP** | — | ADR 0063 |
| 1.22 | Cloud AI | **Post-MVP** | — | ADR 0063 |
| 1.23 | 删除 App / 卸载后不遗留失控 VPN 配置 | [ ] | [ ] | PRD §7 |

---

## 2 · 文案与 i18n

| # | 项 | iOS | Android | 权威 |
|---|---|---|---|---|
| 2.1 | 所有用户可见串从 `en.yaml` 绑定（禁硬编码漂移） | [ ] | [ ] | 0053 |
| 2.2 | `lock-en` 键不进错误机翻（诊断/Repair/隐私关键等） | [ ] | [ ] | 0047 |
| 2.3 | 弱协议 UI 短名：`SS` · `VMess` · `VLESS` · `Trojan` · **Hy2**（全 app 同源） | [ ] | [ ] | grill Q2 |
| 2.3b | 台湾相关节点自绘旗 = **PRC / cn only**（禁 🇹🇼 / tw） | [ ] | [ ] | ADR **0062** |
| 2.4 | Repair / diag CTA 文案 | **Post-MVP** | — | 0063 |
| 2.5 | Parsing 三源：Clipboard / QR / **file**（*Reading file…*） | [ ] | [ ] | grill Q9 · `setup.add.parsing.*` |
| 2.6 | Add lead / fail / 无法自动更新 / Update 失败 hint 含 paste·scan·import 家族 | [ ] | [ ] | grill Q10–12 |
| 2.7 | About **MT 披露**必显（`settings.about.mt_disclosure`） | [ ] | [ ] | grill Q13 · ADR 0031 |
| 2.8 | acceptance §1 Home + §6 Diagnostic 实现走查 pass | [ ] | [ ] | acceptance |
| 2.9 | acceptance §2–§5 · §7 走查 pass（设计/实现均可先做） | [ ] | [ ] | acceptance |
| 2.10 | 伪本地化 / de 长词压测（壳层） | [ ] | [ ] | 0048 |

---

## 3 · 屏幕与交互（P0 Craft）

权威 HTML 见 `design/hi-fi/current/craft-p0/_index.md`。

### 3.1 First-run · Setup（`03-setup` · ADR 0019）

| # | 项 | iOS | Android |
|---|---|---|---|
| 3.1.1 | Welcome 仅一次：Paste / Connect / Smart + Get started；**无**副文；**无** 1·2·3 | [ ] | [ ] |
| 3.1.1b | Data & Privacy 仅一次：On device / No tracking + Privacy Policy 外链 + Continue；**无**说明卡 | [ ] | [ ] |
| 3.1.2 | Home Empty：顶栏 **仅 Settings**；*Add subscription*；START 弱化 | [ ] | [ ] |
| 3.1.3 | Add：Paste 主 · Scan QR · Import file；**无**手填主 UI | [ ] | [ ] |
| 3.1.4 | Parsing 模态叠在 Add 上（非全屏）；三源文案正确 | [ ] | [ ] |
| 3.1.5 | 成功：回 Home Idle + toast（Display Name · N nodes · 2–3s）；**不**自动连 | [ ] | [ ] |
| 3.1.6 | 失败：*Couldn’t add this* + Paste again；不覆盖配置 | [ ] | [ ] |
| 3.1.7 | **无**应用内 VPN 说明页；首次连接出**系统** VPN 授权 | [ ] | [ ] |

### 3.2 Home（`02-home` · ADR 0018 / 0020 / 0036）

| # | 项 | iOS | Android |
|---|---|---|---|
| 3.2.1 | 无底 Tab；有订阅顶栏 **Subscriptions · Settings**；Empty **仅 Settings**；**无 Help** | [ ] | [ ] |
| 3.2.2 | **无** Help pill（ADR 0063） | [ ] | [ ] |
| 3.2.3 | Idle：Cover Flow + **节点名+弱协议+› 可点→Location**；中部**仅***Not Connected*；**无**中部 Location pill；START 顶；**无**点阵；**长名单行 ellipsis**（协议/› 不缩；a11y 全量原文） | [ ] | [ ] |
| 3.2.3b | **台湾节点旗 = PRC（cn/🇨🇳）**；禁止 tw/🇹🇼；解析 tw 显示层映射 cn（CONTEXT 硬性） | [ ] | [ ] |
| 3.2.3c | Cover Flow **`strip[]` ≤ N=15**：Preferred 强制入条 + 预评分 Top 填满；**非**全量；**无** group UI；预停 Preferred 否则 #1（ADR 0055） | [ ] | [ ] |
| 3.2.4 | 下滑连接：⅓/⅔/满 三圈点亮 → Connecting…（仍黑场）；Swipe/Connecting **节点名行锁定** | [ ] | [ ] |
| 3.2.5 | 绿场 **仅** Connection Success；时长 + ↓↑ Mb/s；*Connected* | [ ] | [ ] |
| 3.2.6 | 绿场 **节点行可点 → Location**（无 Cover Flow）；黑场 Idle/Can’t 入口 = Cover Flow 下节点名行 | [ ] | [ ] |
| 3.2.7 | STOP 底 · 上滑断开 | [ ] | [ ] |
| 3.2.8 | 连接失败 → Idle + toast；**无**诊断 sheet（MVP · 0059/0063） | [ ] | [ ] |
| 3.2.9 | 模式 ≠ Auto 时弱提示 Global / Direct | [ ] | [ ] |
| 3.2.10 | **无** provider rules 墙 / VERIFIED / 顶栏 Activity / Home *Pinned* | [ ] | [ ] |

### 3.3 Location（`08-location` · ADR 0055 / 0056）

| # | 项 | iOS | Android |
|---|---|---|---|
| 3.3.1 | 仅 Active 出口；服务商 group 原名；≥2 chip / =1 无 chip | [ ] | [ ] |
| 3.3.2 | **点选 = Preferred**（check；无 *Pinned* 文案） | [ ] | [ ] |
| 3.3.3 | 已 Connected 点选 → **立即切节点**（非 Repair）；失败保留偏好；**不**自动诊断 | [ ] | [ ] |
| 3.3.4 | 顶栏 Latency *Test*（非 Ping 叙事）；不改偏好、不重排 | [ ] | [ ] |
| 3.3.5 | **无** 客户端伪造列表顶 Auto 行；**无** `⋯` 清回 Auto | [ ] | [ ] |
| 3.3.6 | 空态：0 节点说明 + Update subscription 次要 | [ ] | [ ] |

### 3.4 Subscriptions（`04` · ADR 0014 / 0015 / 0033）

| # | 项 | iOS | Android |
|---|---|---|---|
| 3.4.1 | 单列表；Active 高亮；Set active；底 Add | [ ] | [ ] |
| 3.4.1a | Connected / Connecting 时 Set active：先停会话再切 Active；**不**自动重连 | [ ] | [ ] |
| 3.4.2 | Meta：nodes · Expires/Expired 有标签 · Updated；未知整槽省略 | [ ] | [ ] |
| 3.4.3 | 有远程源：Update；busy *Updating…* | [ ] | [ ] |
| 3.4.4 | **1d** 无远程源：*Can’t update automatically* + hint；**无**假 Update | [ ] | [ ] |
| 3.4.5 | **1e** 手动失败：短 toast 2–3s + 可重试 Update | [ ] | [ ] |
| 3.4.6 | **Rename** 轻交互（名旁铅笔 → sheet；非主 CTA） | [ ] | [ ] |
| 3.4.7 | Settings 深链同一套 UI（非第二 CRUD） | [ ] | [ ] |

详见 [`features/subscription-refresh-ui-states.md`](./features/subscription-refresh-ui-states.md)。

### 3.5 Settings（`05` · ADR 0021–0034 · 0045 · 0051 · 0015）

| # | 项 | iOS | Android |
|---|---|---|---|
| 3.5.1 | 根页仅 **Connection · App**；**无** History/Activity/Snapshots | [ ] | [ ] |
| 3.5.2 | Connection 三行 + 释义副文：Mode · DNS · Overrides | [ ] | [ ] |
| 3.5.3 | App：Auto-update Toggle 默认开 · Subscriptions › · About › | [ ] | [ ] |
| 3.5.4 | Mode / DNS picker 三档 | [ ] | [ ] |
| 3.5.5 | Overrides O3：Domain only；Add exception sheet；空态/列表边界文案 | [ ] | [ ] |
| 3.5.6 | About：承诺 · **iOS** iCloud 句 · Links · **MT 披露** · Export | [ ] | [ ] |
| 3.5.7 | Privacy/Terms/Support **外链** website；非应用内长文 | [ ] | [ ] |
| 3.5.8 | **无** Appearance / Advanced / 根页 Cloud AI / 根页 Privacy 行 | [ ] | [ ] |

### 3.6–3.7 Help / Agent / Diagnostic / Repair

**Post-MVP（ADR 0063）** — 不进本 checklist 完成定义。稿：`design/hi-fi/_explore/2026-08-07-help-agent-post-mvp/`。

### 3.7 Diagnostic · Repair（`07` · ADR 0008 / 0010 / 0044）

| # | 项 | iOS | Android |
|---|---|---|---|
| 3.7.1 | **Help 内**诊断结果；四桶白话 + Why/Impact/Next + 置信度（**非**连接失败自动 sheet） | [ ] | [ ] |
| 3.7.2 | App can fix：*Approve and repair* + Ask Help + Not now | [ ] | [ ] |
| 3.7.3 | Provider / Network / Not sure：无假 Repair；CTA 矩阵正确 | [ ] | [ ] |
| 3.7.4 | Repairing：快照提示 · 动态步 · Cancel | [ ] | [ ] |
| 3.7.5 | Success 绿场 + 结果；Rolled back + Ask Help | [ ] | [ ] |
| 3.7.6 | **无** 双实心主 CTA；**无** 内部桶名上屏 | [ ] | [ ] |

---

## 4 · Activity（能力 P0 记录 · MVP 无 UI）

| # | 项 | iOS | Android | 权威 |
|---|---|---|---|---|
| 4.1 | 事件落盘（连接/Failover/模式/Override 等） | [ ] | [ ] | 0013 · 0063 |
| 4.2 | **无**用户可见列表 / Help 摘要（MVP） | [ ] | [ ] | 0063 |
| 4.3 | **不**进顶栏 / Settings | [ ] | [ ] | 0051 |

---

## 5 · 平台差异（Realization / Gap）

| # | 项 | 说明 | 勾选 |
|---|---|---|---|
| 5.1 | iOS VPN | Network Extension + 系统弹窗 | [ ] |
| 5.2 | Android VPN | VpnService + 系统权限流 | [ ] |
| 5.3 | iOS Override iCloud | ADR 0054 | [ ] |
| 5.4 | Android Override | 本机-only；About **无** iCloud 句 | [ ] |
| 5.5 | 商店 / 计费 | Beta **不**做 IAP；日后 StoreKit / Play Billing | N/A Beta |
| 5.6 | minSdk / 权限清单 / 隐私营养标签 · Play 数据安全 | 上架前 | [ ] iOS [ ] Android |

---

## 6 · 质量与合规门槛（PRD §7 摘要）

| # | 项 | iOS | Android |
|---|---|---|---|
| 6.1 | P0 协议真连 CI/手工清单全绿 | [ ] | [ ] |
| 6.2 | Probe 失败不得标成功（自动化断言） | [ ] | [ ] |
| 6.3 | 非 Allowlist 不可 Repair（测试） | [ ] | [ ] |
| 6.4 | 无 Consent 不修（测试） | [ ] | [ ] |
| 6.5 | Token/原始订阅不上分析通道 | [ ] | [ ] |
| 6.6 | Export 报告脱敏 | [ ] | [ ] |
| 6.7 | 崩溃率 / VPN 异常退出可接受 | [ ] | [ ] |
| 6.8 | Beta **无**付费墙 | [ ] | [ ] |
| 6.9 | 官网 Legal 可访问；App About 外链正确 | [ ] | [ ] |

---

## 7 · 建议实现顺序（双端并行）

```
A 工程 + 文案 catalog + 安全存储
        ↓
B 订阅导入/解析 + Active 模型 + 本机持久化
        ↓
C VPN 隧道 + Probe + 连接状态机（Home 黑/绿）
        ↓
D Node Selection 预评分 + Location Preferred + Failover
        ↓
E Diagnostic Engine + 四桶 UI + Repair 全链路
        ↓
F Settings 策略（Mode/DNS/Override）+ Snapshot
        ↓
G Subscriptions UI + Refresh 总闸 + 1d/1e
        ↓
H Activity 本机记录（无 UI）
# Post-MVP: Help / Diagnostic / Repair
        ↓
I 双端联调 · 伪本地化 · 卸载清理 · 上架材料
```

**Craft 提示：** B–E 可先功能后像素；Home/诊断/Repair **优先**对齐 hi-fi。

---

## 8 · 明确不做（MVP / Beta）

- 卖节点 / 推荐机场  
- 底 Tab；Settings Advanced 坟场；根页 History  
- MITM / 完整规则编辑器 / 规则市场  
- 默认云端全 app 大脑；首次 Cloud 授权墙  
- 硬 Pin 禁 Failover；列表客户端 *Auto* 行  
- 付费墙 / IAP（Beta）  
- Mac / TV / 跨端 UI 壳主实现  

---

## 9 · 相关路径

| 文档 | 路径 |
|---|---|
| PRD | [`PRD.md`](./PRD.md) |
| 术语 | [`../../CONTEXT.md`](../../CONTEXT.md) |
| ADR | [`../adr/`](../adr/) |
| 文案 | [`../copy/en.yaml`](../copy/en.yaml) · [`acceptance-by-screen.md`](../copy/acceptance-by-screen.md) |
| 订阅 1d/1e | [`features/subscription-refresh-ui-states.md`](./features/subscription-refresh-ui-states.md) |
| hi-fi | [`../../design/hi-fi/current/craft-p0/`](../../design/hi-fi/current/craft-p0/) |
| IA | [`../../design/wireframes/current/craft-p0/00-ia.md`](../../design/wireframes/current/craft-p0/00-ia.md) |

---

## 完成定义（本 checklist）

- [ ] **§0–1** 双端内核与闸门完成  
- [ ] **§3** P0 屏幕可演示（Welcome → 连上 → 失败 toast → 再连；**无** Help）  
- [ ] **§2 · §6** 文案绑定 + 门槛测试通过  
- [ ] **§4** Activity **已记录**（无用户 UI）  
- [ ] **§5** Platform Gap 已标注、无静默假能力  
- [ ] Beta 构建可分发（TestFlight / 内测轨）且 **无** 付费墙  
