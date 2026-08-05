# Routeva

**Routeva** 是最终产品名（仓库、工程与 App Store 主品牌一致；商店显示名仅允许大小写或轻量后缀微调）。面向已有代理订阅的普通用户的 **智能代理客户端**：默认把配置藏起来，用「能连上 → 说清失败原因 → 安全修好」形成闭环。不提供、不销售节点。品类描述（如 “smart proxy client”）只作副文案，不替代品牌名。

## Language

**Routeva**：
本产品的正式名称与主品牌。
_Avoid_: AI 智能代理客户端（品类句当产品名）；未定代号

**Primary Market**：
首发以 **美国 App Store** 为主；用户可以是全球持有代理订阅的人，但商店叙事、合规与首发运营按美区优先。
_Avoid_: 未验证就默认全球多商店同步首发

**Device Scope（MVP）**：
同一 iOS App：**iPhone 为设计与验收主设备**；**iPad 可安装使用**，但布局/多任务/键鼠等不优先打磨（基础可用即可，非 iPad 优化产品）。Mac / Apple TV / 桌面端首发不做。**最低系统：iOS 17+**。
_Avoid_: iPad-first；通用 Apple 全家桶首发；为 iOS 16 及以下扩测试矩阵

**Product Language (Source)**：
面向用户的 UI、Onboarding、诊断可读文案、付费墙、商店材料与 Agent 首发质量以 **English** 为源语言（source of truth）并优先做 Craft 打磨。Agent 跟随系统/App 语言；中文等本地化可后续加，但不以中文 UI 作为美区首发验收标准。内部文档可用中文。
_Avoid_: 中文 UI 当美区首发唯一验收；中英半套上架

**Product Bet (MVP)**：
MVP 要证明的是 **自愈闭环**（诊断准、修复可验证可回滚）。**自动导入并连上**是入场必要条件。**Craft** 为交付质量要求。首发选择 **Thick Agent** 作为主交互面之一（开放自然语言 + 分流意图 + 云端可选），但 **Agent 不得取代 Diagnostic Engine 成为故障裁判**；无模型时核心连接/诊断/修复仍须可用。北极星仍是修复成功率与连接稳定性，不是对话次数。
_Avoid_: 把 AI 对话次数、协议支持数量当作北极星

**Self-Healing Loop**：
识别订阅 → 自动连接 → 发现问题 → 清楚解释 → 安全执行修复 → 验证；失败则回滚。这是产品的主价值闭环。
_Avoid_: 一键魔法、智能修复（含糊说法）

**Table Stakes Connect**：
粘贴/导入订阅后，用户无需理解协议与路由即可完成首次连接与日常可用。自愈闭环的前提，不是独立卖点叙事的全部。
_Avoid_: 仅「简单客户端」作为唯一故事而弱化诊断

**Connection Success**：
一次连接（含首次自动连接与 Repair 后验证）判定为成功，当且仅当：**系统 VPN/隧道已就绪**，且经当前节点完成至少一次 **Connectivity Probe** 成功。仅隧道亮起、探针失败 → 不得宣称连接成功，应进入诊断分桶。
_Avoid_: 只看 VPN 图标；把「某个流媒体能播」当默认成功标准

**Connectivity Probe**：
客户端内置的出网连通性检测（如经当前节点 HTTPS 访问固定探针目标）。用于 Node Selection 加权、首次连接验收与 Repair 验证；**不**等同于流媒体/特定站点解锁检测，也不对解锁做 SLA。
_Avoid_: 解锁检测、流媒体测试（当默认成功标准时）

**Craft**：
界面、信息层次与交互行为达到可感知的精致与可信（含高保真与关键路径动效），降低「工具感/山寨感」，支撑付费与信任。诊断与修复反馈质感优先于装饰性动效。
_Avoid_: 视觉花活、用动效掩盖诊断不准

**Craft Priority（MVP）**：
- **P0 Craft：** Onboarding→导入→首次连上（系统 VPN 弹窗，无自建说明页）；Home 连接态；诊断结果卡（四桶）；Repair 确认/进度/成功或回滚；（商业化后）付费墙  
- **P0 能力 / P1 Craft：** **Activity** 事件可查（Settings 二级；连接、Failover、诊断、Repair、回滚、模式切换等）——Beta 须有清晰列表，动效与视觉可后打磨；Agent 工具过程与可撤销；**Subscriptions** 一级面（单列表 + Active 态）
- **P2：** 高级模式与深层设置  
用户可见文案以 English 源打磨（见 Product Language）。

**Home Surface**：
完成前置配置后，Home 根画布服务「选节点 → 连接手势 → 连接真值」；**无底部 Tab**；顶栏为**纯离开 Home 的出口**（不做状态红点、不做主任务捷径）。有 Active 时：`[ Agent ] [ Subscriptions ] …… [ Settings ]`；无订阅（Empty）：`[ Agent ] …… [ Settings ]`（**不**显示 Subscriptions）。中部闭集见 **Home Mid Copy**；连接动效见 **Connect Gesture**。权威 hi-fi：`design/hi-fi/current/craft-p0/02-home.html`。全 app 视觉从 Home 提取：`design/hi-fi/current/craft-p0/visual-system.md`。详见 ADR 0018 / **0020**。  
_Avoid_: 三栏底 Tab；顶栏常驻 Activity；顶栏诊断/刷新捷径；在 Home 常驻规则说明、定位口号、默认展示 Auto；二级页另起无关视觉风格

**Home Chrome（顶栏出口）**：
- **Agent** — Thick Agent（NL + Tool Allowlist）；故障裁判仍是 Diagnostic Engine  
- **Subscriptions** — 仅当已有至少一份订阅（通常已有 Active）时显示；进入 **Subscriptions Surface**  
- **Settings** — 进入 **Settings Surface**（非订阅配置与可解释历史；非日常连接台）  
- **Activity** — **不进顶栏**；经 Settings 二级（及 Agent 只读摘要）可查  
_Avoid_: Empty 用 + 替换 Settings；顶栏四钮塞回 Activity

**Settings Surface**：
从 Home 顶栏进入的一级配置面。**根页主职 = Connection Policy 优先**（ADR 0021）。**根页一级分组闭集（三段，自上而下）：**
1. **Connection** — 根页固定三行（均为 › 进二级，非 Home 内联控件）：**Routing mode** · **DNS** · **Overrides**（User Override 列表/编辑，≤20）。**DNS 预设闭集（三选一，默认 Automatic）：** **Automatic**（系统/隧道默认）· **Privacy**（加密 DNS 优先；具体解析器为实现常数，UI 不堆公共 DNS 品牌列表）· **Compatibility**（偏可达/兼容解析路径）。**禁止**自定义 DNS IP/主机名表单。Repair 切换 DNS 必须落在同一闭集。**不**在此段放节点列表、订阅 Refresh、自动 Failover 总闸（钉节点/选节点主路径在 Home/Location）、任意配置全文、per-App/规则市场。  
2. **History** — 根页固定两行：**Activity ›**（时间序事件，能力 P0）· **Snapshots ›**（保留期内 Config Snapshot 列表与回滚确认）。**Export 脱敏报告**不占 History 根行（可落在 Activity/诊断详情/About 次要动作，细项另议）。根页**不**内嵌事件摘要列表。  
3. **App** — 根页固定三行：**Privacy ›** · **Subscriptions ›**（深链同一套 UI，含 Empty 时无顶栏入口的补偿）· **About ›**。**无 Appearance 行：** UI 光暗 **仅跟随系统**；**连接绿场仍仅 Connection Success**，不提供主题皮肤或「永远绿」。**Beta 不**在根页放 Restore Purchases / 付费墙 / 账号。  
   - **Privacy › 闭集：** Data on device（本机、无账号）· What we don’t collect by default（短列表）· Cloud AI **只读**说明（管理在 Agent，无第二开关）· Diagnostics/analytics 明示（无则不强行假开关）· 外链 Privacy Policy。  
   - **About › 闭集：** 名+版本 · 政策/条款/支持链 · **Export diagnostic report**（脱敏，次要）· 一句不卖节点。**无** 连点 Advanced、无 Rate/Share 必达。  
**Cloud AI 不进 Settings 根页：** 授权与开关在 **Agent** 内、用户首次需要云端增强时触发（见 **Cloud AI**）；Settings 不预开/预关。根页**无**独立 Assistant 段（避免空壳）。  
**不上根页：** Appearance/主题包、Cloud AI 开关、订阅 CRUD 副本、Run Diagnostic 主 CTA、协议/内核/规则编辑平铺、Beta 付费墙/Restore Purchases、账号/登录、整屏 Activity 日志、**Advanced / 高级模式入口**（Beta 正式 Settings 不露；内核/日志级别/实验项无用户入口）。Export 等残留挂 Activity/诊断/About **次要动作**；订阅 Refresh 仅 Subscriptions Surface。日常连/断/选节点仍在 Home。Craft 整体属 P2（Activity 能力仍为 P0）。  
_Avoid_: Settings 当第二连接台；Trust/History 占满根页主视觉；两套订阅管理；五段常驻 Advanced 坟场；无分组的一长串开关；Connection 段塞进节点管理或自由 DNS 编辑器；仅从 Repair 流程才能找到快照列表；Settings 再挂一套 Cloud AI 开关与 Agent 双源；Beta 根页死挂 Restore Purchases；用 Advanced 再镜像一遍 Mode/DNS/Override/Activity；Appearance 劫持连接绿场

**Subscriptions Surface**：
一级面（非 Settings 内嵌第二套管理）。**单列表**：一屏列出全部 Subscription；**Active** 行高亮（徽章 + 可选到期/流量 + **Update**）；非 Active 行可 **Set active**；底 **Add subscription**。**无**独立「All subscriptions」第二层。**可选 Rename**（非导入阻断）。**无**教学脚注。与 Empty/Add 流共用添加路径。Settings 最多 *Subscriptions ›* **深链到同一套 UI**，不复制 CRUD。权威 hi-fi：`design/hi-fi/current/craft-p0/04-subscriptions.html`。详见 **Subscription Display Name** / ADR **0033**。  
_Avoid_: Settings 与顶栏两套订阅管理；Active 详情页与 All 列表双页重复；假设每家都有流量仪表盘；无数据时伪造仪表或写 *Not reported* 解释句

**Home Mid Copy（闭集）**：
- **无订阅（Home Empty）：** 顶栏 **仅 Agent + Settings**（无 Subscriptions）；主状态与 CTA 统一 **Add subscription** + 副文 *Paste a link you already have*；START **弱化不可连**；导入只走中部 CTA（及同一 Add 流）
- **Idle / 手势中（黑场）：** 上部 **国旗 Cover Flow**（选中项下为 **节点名** + 弱协议）；中部 **Not Connected** + **Location ›**；**Idle 无点阵**  
- **Connecting（黑场）：** Cover Flow 可保留；**Connecting…**；三圈点全亮（未染绿场）  
- **Connection Success（绿场）：** 会话时长 + ↓/↑ Mb/s；地区 · Connected · 节点+弱协议；三圈绿点  
- 失败/弱连接：**Can’t connect** + Location；原因在诊断 sheet  
- **仅当** 模式 ≠ Auto：弱提示 Global / Direct  
**明确不出现：** provider rules、编号步骤墙、VERIFIED/probe 叠词、Active 订阅 chip、Auto 字样、模式三选一、协议彩色大徽章。  
_Avoid_: Needs attention（主状态优先 Can’t connect）；Cover Flow 下用国家名撞名

**First-Run Setup（闭集）**：
首次安装：**Welcome（仅一次）→ Home Empty →（用户点 + / Add subscription）→ Add Subscription**。欢迎仅 **headline + 一句副文**（自备订阅 / 不卖节点）；**无** 1·2·3 列表，**无** 诊断/修复说教句。**无** 应用内 VPN 说明页：首次连接手势时出 **iOS 系统弹窗**；拒绝 → Home 回 Idle（*Swipe down to connect*）；同意 → 连接至 Connection Success。权威 hi-fi：`design/hi-fi/current/craft-p0/03-setup.html`。详见 ADR 0019。  
_Avoid_: Welcome→Import→VPN 三连轰炸；自建「Allow VPN」页；欢迎页编号卡片；欢迎页堆叠第三段能力说明

**Add Subscription（交互）**：
主路径 **Paste from Clipboard**；次要 **Scan QR**、**Import file**（剪贴板与扫码本质相同：取内容 → 解析）。顶部 **一句** 引导去服务商取链接/二维码。**无** 手填大输入框；**无** 独立「剪贴板已发现」确认页。点 Paste/扫码后在 **Add Subscription 上弹出 Parsing 模态**（*Reading clipboard…* / *Reading QR code…*；**非**独立全屏）。成功：直接回 **Home Idle（同一壳）** + 短 toast（**Subscription Display Name · 节点数**；**2–3s 自动消失**）；设 Active；**不**自动连；**不**打断命名。失败：回 Add 页失败态——短句 *Couldn’t add this* + *Copy a fresh link or QR…*；主 CTA Paste again；次要 Scan/File；**不**列协议/格式清单；**不覆盖**已有配置。  
_Avoid_: 手填 URL 主 UI；Found clipboard 独立屏；成功页与 Home 壳不一致；失败文案堆 Clash/YAML 等格式科普

**Connect Gesture**：
竖直滑动胶囊：Idle 拇指在 **顶（START）**，**下滑连接**；成功后在 **底（STOP）**，**上滑断开**。三圈点阵仅在手势开始后出现，按行程 **内→外逐圈点亮**（约 ⅓ / ⅔ / 满）；**绿场仅 Connection Success**。点阵 = 连接/Probe 过程反馈，非 Idle 装饰。  
_Avoid_: Idle 常驻点阵；未 Probe 成功就整屏染绿；点阵超过 3 圈

**Routing Mode Entry**：
Auto / Global / Direct 切换在 Settings（及 Agent）。Home 仅非 Auto 时弱提示。换节点：Cover Flow + Location 入口；Connected 节点行可点。  
**Settings · Routing mode ›：** 单选三档 + 各一行副文（Auto = provider rules + smart nodes；Global = all via proxy；Direct = no proxy）；**无** 长对比表、**无** 当前规则摘要墙。变更记 Activity，并按 Snapshot Policy 处理。  
_Avoid_: Home 主视觉级模式切换；Settings 模式页做成教学长文或完整规则浏览器

**Activity Log**：
本机时间序事件记录，用于解释「系统刚做了什么」（连接、Node Failover、诊断、Repair、回滚、Global/Direct 或 Override 等）。Beta **必须可查看**（能力 P0）；呈现精致度属 Craft P1。**入口：** Settings 二级（及 Agent 工具摘要），**非** Home 顶栏常驻。不上传原始订阅/Token。  
_Avoid_: Beta 无任何事件可查；把 Activity 当成可后做的纯装饰；Home 顶栏常驻 Activity

**Proxy Client**：
本产品是代理**客户端**：导入、解析、连接、诊断与配置；用户须自备订阅或节点来源。
_Avoid_: VPN 服务商、机场、节点商城

**Subscription**：
用户自有的代理订阅或等价导入物（链接、单节点 URI、二维码、Clash/Mihomo/sing-box 等配置）。产品不销售 Subscription。
_Avoid_: 套餐、会员订阅（与 App 内购「永久解锁」混淆时需写全称）

**Subscription Display Name**：
该 Subscription 在 UI 中的显示名（列表/Active 标题/成功 toast）。**不承诺**协议能提供服务商品牌名。导入时**静默自动取名**，优先级：① 配置内明确 profile/`name` 等 → ② 拉取时可用的响应元数据/文件名（若有）→ ③ 由订阅 URL host 派生的弱名 → ④ 中性默认（如 *Subscription* / *Subscription 2*）。**禁止**导入流程强制用户命名。用户可在 Subscriptions Surface **可选 Rename**；节点备注名 ≠ 订阅显示名。  
_Avoid_: 粘贴后必填机场名；把单节点 URI 备注当成服务商品牌；伪造「官方店名」

**Active Subscription**：
同一时间参与连接、Node Selection、Connectivity Probe、诊断、Repair 与 Failover 的**唯一** Subscription。用户可保存多份 Subscription，但必须显式选择其一为 Active；切换 Active 为显式动作（记 Activity，必要时按 Snapshot Policy 建快照）。不默认合并多订阅节点池，不双栈并行多隧道。  
_Avoid_: 默认同池合并多机场；同时连多个订阅隧道

**Subscription Refresh**：
在用户打开 App（冷启动）或发起连接时，若 Active Subscription 距上次**成功**更新已超过间隔 **T**（默认 6h，实现常数），则尝试拉取更新。成功则安静刷新节点/规则并记 Activity（不弹打扰式成功提示）；失败则**不覆盖**已有可用配置，仅在影响连接或用户查看时说明。允许用户手动更新；Repair Allowlist #2 为失败路径上的重载。  
**禁止**固定后台周期拉订阅（耗电、体验差、iOS 后台不可靠）。非 Active 订阅不自动刷，除非被切为 Active 或用户手动。  
_Avoid_: 后台定时轮询订阅；失败覆盖旧配置；成功也 Toast 刷屏

**Diagnostic Engine**：
确定性的分层故障判定（订阅 / 网络环境 / 节点 / 目标服务），产出结构化结果（原因、置信度、是否可自动修复、建议动作）。AI 只解释结构化结果，不凭空判定故障。
_Avoid_: AI 诊断（把模型当故障裁判）

**Diagnostic Trigger**：
Engine **在失败路径自动运行**，不在每次成功连接后强制「健康体检」。自动触发至少包括：导入无法完成、未能达到 Connection Success（含仅隧道就绪但 Connectivity Probe 失败）、连接中断且自动恢复失败。用户与 Agent 可手动重跑；Agent 必须调用同一 Engine，不得另设判定。成功连接路径保持安静（Home 状态即可）。  
_Avoid_: 每次连上后强制完整四层体检；仅手动诊断、失败时无自动解释

**Failure Bucket**：
每次诊断必须归入且展示其一：**Client-Fixable**（客户端可修）、**Provider-Side**（订阅/服务商）、**Environment**（当前网络/设备环境）、**Unknown**（已查仍不确定）。禁止用单一 Error Code 糊弄；不确定必须显式表达不确定。
_Avoid_: 统一失败、网络错误（含糊桶）

**Client-Fixable**：
通过改客户端侧状态即可改善的问题（如切换可用节点、重载订阅、重建系统 VPN 配置、切换预设 DNS、在可行时调整 IPv4/IPv6 或 TCP/UDP 兼容节点、回滚到 Config Snapshot 等）。**唯一允许自动 Repair 的桶。**

**Provider-Side**：
订阅过期、Token 失效、流量耗尽、服务商返回空/登录页/无效配置、节点侧全不可用等。系统说明原因与下一步（通常去服务商处理），可导出脱敏报告；**不得**假装一键修好。

**Environment**：
需门户登录的 Wi‑Fi、网络禁 UDP、系统 VPN 冲突等环境限制。解释限制并给出客户端内可行退路（如换节点类型/换网络）；**不承诺**修好用户的路由器或运营商。

**Unknown**：
各层检查未形成高置信结论。展示已做步骤、不确定性与导出报告；**禁止编造原因**或循环空 Repair。

**Repair**：
仅对 **Client-Fixable**、在用户知情下执行 **Repair Allowlist** 内动作，先 Config Snapshot，再修改、以 Connection Success（含 Connectivity Probe）验证；失败回滚。禁止自由生成/写入未经验证的任意配置；单次修复候选有上限，禁止死循环。
_Avoid_: 自动搞定、根治、智能修复（未分桶时）

**Repair Consent**：
Client-Fixable 诊断之后，**默认不静默执行 Repair**。须用户对诊断卡主按钮（或 Agent 中等价的明确「执行修复」意图）**确认一次**后，才进入该次 Repair 流程。一次确认可覆盖该流程内多个 Allowlist 候选（有上限）；过程可取消；整次失败回滚到进入前 Snapshot。不得在 Onboarding 用总开关默认打开「永远自动修」作为 MVP 默认。  
_Avoid_: 静默自动修；聊天暗示即改 VPN

**Repair Allowlist（MVP 闭集）**：
仅下列动作可被自动/一键 Repair 执行；未列出的动作不得作为 Repair（可作手动高级操作另议，但不算 Self-Healing Repair）：  
1. 切换到评分更高的可用节点（Node Selection）  
2. 重载/更新当前 Subscription  
3. 重建系统 VPN 配置/隧道  
4. 切换到客户端预设 DNS 之一  
5. 在节点能力允许时，优先更兼容的出口参数（如 IPv4 / TCP 偏好——仍属选节点或连接参数，非改无关系统设置）  
6. 回滚到 Config Snapshot  
**禁止：** 写入未校验的任意配置全文、证书/MITM、静默改系统、对非 Client-Fixable 假装 Repair、无快照修改。新增动作须改文档/ADR，不得由模型自行扩展。  
_Avoid_: 开放式「智能修复」动作列表；示例当作可无限追加

**Config Snapshot**：
执行修复或重要配置变更前保存的可恢复客户端状态；Repair 失败或用户选择回滚时必须能回到对应快照。
_Avoid_: 备份（过于笼统）；把节点 Failover 每次都当完整快照

**Snapshot Policy（MVP）**：
- **必建：** 进入 Repair 流程前；用户/Agent 执行会改变连接策略或分流的显式动作前（如切换 Global/Direct、应用 User Override、手动切换预设 DNS 等）。  
- **不强制完整快照：** Node Failover 自动换节点（避免高频刷爆存储）。  
- **保留（Beta）：** 至少最近 **10** 份或 **7** 天内（实现取两者中更严的上限策略，须可配置常数）。  
- **回滚：** Repair 失败/取消 → 自动回到「进入该次 Repair 前」快照；用户可从列表回滚到保留期内某份。  
_Avoid_: 仅 1 份且无法看历史；无限时光机；Failover 每次全量快照

**Agent（Thick）**：
首发主交互面之一：支持**开放自然语言**输入与**分流类意图**；将意图编排为对 **Agent Tool Allowlist** 的调用，并用自然语言解释**结构化**结果。  
**硬边界（不因「厚」而放开）：** 不得查看网页内容/完整浏览历史；不得上传 Subscription Token 或未脱敏节点凭证；不得安装根证书 / MITM；不得自由生成并执行未经验证的任意配置；不得在用户不知情时改系统设置；不得自动推荐/购买特定机场。故障判定以 Diagnostic Engine 为准；Repair 仍仅限 Repair Allowlist + Repair Consent。  
_Avoid_: 无边界聊天机器人；「AI 随便改配置」

**Agent Tool Allowlist（MVP 闭集）**：
- **只读：** Active/订阅状态摘要；节点测试结果摘要；最近诊断结果；环境/DNS 结构化摘要；节点评分比较摘要；Activity 最近事件摘要；导出脱敏报告。  
- **变更（须遵守 Snapshot / Consent / Active 等既有规则）：** 连接/断开；切换或钉节点；切换 Auto / Global / Direct；应用或清除少量 User Override；切换预设 DNS；触发诊断；Repair；回滚 Config Snapshot；切换 Active Subscription；手动 Subscription Refresh。  
- **禁止入库：** 网页内容、完整浏览历史、Token/原始订阅上传、MITM/证书、自由写配置、推荐机场、静默改系统。未列出的工具不得调用；扩展须改文档/ADR。  
_Avoid_: 开放式工具插件；模型自行注册新工具

**Cloud AI（Optional）**：
云端模型是 **Opt-in 增强**，不是 Agent 默认大脑。默认路径：快捷问题 / 本地或规则编排 / 模板化解释 + 同一套工具。**授权入口在 Agent 面**：用户首次需要云端增强时再知情同意；开启后须有可见指示，且在 Agent 内可一键关闭。**不**在 Settings 根页预置开关（避免与 Agent 双源）。只允许发送脱敏后的结构化上下文（如意图类型、诊断摘要），禁止 Token、节点凭证、原始订阅正文、完整浏览域名与对话原文默认上传。无云/拒云时，连接、Diagnostic Engine 与白名单 Repair 仍须可用。
_Avoid_: 云端默认大脑；无云则无 Agent；Settings 与 Agent 两套 Cloud AI 开关

**Beta Access**：
**Beta 阶段（直至宣布进入商业化）产品行为：MVP 范围内能力全部可用，不限额、不展示付费墙。** Free Experience / Pro Unlock / Paywall Timing 仅为**日后收费规划的目标草稿**，不是 Beta 验收或出门条件。主证明点仍是 Self-Healing Loop 与连接稳定性。详见 ADR 0006。  
_Avoid_: 在 Beta 用配额挡诊断样本；把 $2.99 转化当 Beta 北极星

**Free Experience**（目标商业草稿，Beta 不生效）：
完整「首次成功体验」试用，限额按**本机安装**计（非按天重置，除非日后改 ADR）：  
- ✅ 导入 **1** 个 Subscription、P0 协议、测节点、手动选节点  
- ✅ **首次**自动选节点并连接（不含此后持续后台自动故障切换）  
- ✅ 完整诊断 **3** 次；用尽后可看历史摘要，再诊断需 Pro  
- ✅ 一键 Repair **1** 次演示；用尽后仅建议 + 付费墙  
- Agent 可进入，但诊断走同一 **3 次**池；Repair 单独 **1** 次  
- ❌ 后台自动故障切换、多订阅、流量/到期提醒、无限快照（最多保留/展示有限快照如最近 1 次，细节实现可定）  
不靠阉割协议转化。  
_Avoid_: 半残导入；把本草稿当成 Beta 已上线行为

**Pro Unlock**（目标商业草稿，Beta 不生效）：
App 内购 **Non-Consumable** 一次性永久解锁；美区首发价草稿 **$2.99 USD**（商业化时再确认）。目标解锁：不限诊断与 Repair、持续自动选节点与后台故障切换、Thick Agent 全量工具、User Override / 模式切换能力、到期与流量提醒、Config Snapshot 与回滚、多订阅等。对用户文案用 **Pro** / *Lifetime unlock*，避免与代理 **Subscription** 混淆。  
_Avoid_: 在 Beta 实现并强推 IAP；把 IAP 叫成「订阅」

**Paywall Timing**（目标商业草稿，Beta 不生效）：
商业化后：不在首次启动强塞付费墙；用户应先完成导入并真实连上后再在高价值动作处触发。Beta 阶段无付费墙。  
_Avoid_: Beta 展示付费墙；启动即墙

**Identity（MVP）**：
无自建账号、无强制注册/邮箱。付费身份依赖 Apple ID + StoreKit 恢复购买；Subscription、配置、快照与诊断历史默认本机。换机需用户重新导入订阅（多设备/iCloud 同步不在 MVP）。
_Avoid_: 强制登录才能连接；自建账户体系当 MVP 依赖

**Auto Policy**：
默认连接策略名可叫 Auto，含义是 **尊重订阅/服务商规则 + 智能选节点**，不是客户端自建「全球智能分流引擎」。能解析的订阅规则/策略组/节点分组优先执行；节点层由客户端负责测试、评分、自动选择与故障切换。客户端仅保留安全兜底（如局域网/回环直连等），不承诺流媒体解锁（更偏节点/服务商能力）。
_Avoid_: 以自建庞大域名库当主分流；规则社区；完整策略组编辑器

**User Override Rule**：
用户或 Agent 发起的**结构化覆盖层**：每条为 `目标`（预设 **Service** 名 **或** 单个 **Domain**）→ `proxy | direct`。可预览、可关闭、可回滚；须提示可能与订阅/服务商规则叠加。Beta 最多 **20** 条。Global / Direct 总开关不计入这 20 条。  
**Settings 交互（Overrides ›）：** 列表（每条可开/关/删）+ **Add** sheet（选 Service 或 Domain → Proxy/Direct → Save）；**无** 正则/通配/一行速记语法；满 20 禁用 Add。Service 预设表由产品维护（实现期定名单）；Domain 为单域名。Agent 写同一模型，非只读旁路。  
_Avoid_: 手写正则、远程 Rule Set 市场、JS 规则、iOS per-App 精确分流承诺；无限条迷你规则编辑器；Overrides 仅 Agent 可写、Settings 不能 Add

**Node Selection**：
在可用节点集合内，按延迟、握手、实际访问成功率（含 Connectivity Probe）、近期失败与稳定性等加权评分，选出当前节点；不能只按 Ping 排序。属客户端主智能之一。
_Avoid_: 只按延迟排序；把「解锁某站」当选节点的唯一标准（除非诊断如此表明）

**Node Failover**：
在用户已启用自动选节点（Auto 或等价）且**未钉死节点**时，为维持 Connection Success 而在连接过程中**自动**改选可用节点或短重连。属连接保活，**不是** Repair：不走 Repair Consent / 诊断卡确认。须记入 Activity；连续失败仍按 Diagnostic Trigger 自动诊断。用户关闭自动选节点或手动钉节点时，不得静默 Failover。  
_Avoid_: 把 Failover 叫成 Repair；钉节点后仍偷偷换节点

**P0 Interop Surface（瘦身）**：
首发以「美国区常见机场订阅能导入并稳定连接」为宽度目标，不以协议数量为卖点。  
**须真连 + 自动化测试：** 格式 — Clash/Mihomo YAML、V2Ray Base64 订阅、常见单节点 URI（ss / vmess / vless / trojan / hysteria2）；协议 — VLESS（含 Reality）、VMess、Trojan、Shadowsocks、Hysteria2。  
**可解析或实验、不进主卖点：** sing-box JSON（若内核顺带）、TUIC、WireGuard、HTTP/SOCKS5 等补充出口。  
**首发明确不做：** 完整 Quantumult X / Surge / Stash 高级语法、远程脚本、SSH/ShadowTLS/MASQUE/私有协议等。不支持时须给出具体失败原因，且不得覆盖用户已有配置。  
_Avoid_: 支持最多协议；把实验协议算进 P0 完成度
