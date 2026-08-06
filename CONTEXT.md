# Routeva

**Routeva** 是最终产品名（仓库、工程与 App Store 主品牌一致；商店显示名仅允许大小写或轻量后缀微调）。面向已有代理订阅的普通用户的 **智能代理客户端**：默认把配置藏起来，用「能连上 → 说清失败原因 → 安全修好」形成闭环。不提供、不销售节点。品类描述（如 “smart proxy client”）只作副文案，不替代品牌名。

## Language

**Routeva**：
本产品的正式名称与主品牌。
_Avoid_: AI 智能代理客户端（品类句当产品名）；未定代号

**Primary Market**：
商店叙事与合规可按区优先（美区 App Store / Play 常见）；用户可以是全球持有代理订阅的人。**产品能力单源**，不以「某商店首发」拆成两个产品。
_Avoid_: 未验证就默认全球多商店同步上架日；把商店节奏当成能力分叉

**Device Scope（MVP）**：
**双端原生同时开发**（iOS + Android）。  
- **iOS：** 同一 App；**iPhone 为设计与验收主设备**；iPad 可装可用，布局/多任务不优先。**最低系统：iOS 17+**。  
- **Android：** 同一产品能力；**手机为主验收**；平板/折叠基础可用。minSdk 实现期锁定。  
Mac / Apple TV / 桌面端首发不做。
_Avoid_: iPad-first；仅一端静默砍能力；为 iOS 16 及以下扩测试矩阵；把两端当两个 Product

**Dual-Native Layout**：
Application Source 为 `app/ios/` 与 `app/android/` 两棵独立树，互不 compile/import。产品语义在 `PRODUCT.md` / PRD / `design/**/current/` / 本文件单源。见 ADR **0049**。
_Avoid_: 根目录 `ios/`+`android/`；默认 Flutter/RN 主壳；第三套 `app/shared` 业务实现

**Platform Realization**：
同一用户可见能力在各平台用原生 API 落地（如 StoreKit vs Play Billing；Network Extension vs VpnService）。**不是**第二条 PRODUCT 能力。
_Avoid_: 「iOS 支付」「Android 支付」拆成两条核心能力

**Platform Gap**：
共享能力列表中一端尚未交付的项。允许暂时领先/落后，须在 PRD 或 status **显式**标注目标版本；禁止静默漂移。
_Avoid_: 永久单端功能伪装成 Gap

**Product Language (Source)**：
面向用户的 UI、Onboarding、诊断可读文案、付费墙、商店材料与 Agent 首发质量以 **English** 为源语言（source of truth）并优先做 Craft 打磨。内部文档可用中文。布局与 i18n 工程须按 **MVP Locale Set** + 伪本地化验收。详见 ADR **0047**（策略）/ **0048**（闭集 M）。  
_Avoid_: 中文 UI 当美区首发唯一验收；中英半套上架；用语言数量当完成度；App locale 与 GTM 精做套数强行 1:1

**Product Copy Source**：
App 用户可见串的 **English 键值工程源** 在 `docs/copy/en.yaml`（治理见同目录 README）。范围：**P0 闭集 + 壳层骨架**；每条 `key`（`surface.slot`）· `en` · `tier: shell | lock-en`。**不**预译 8 语；机翻仅上架前对 shell、且服从 **Localization Policy**。权威分轨：`lock-en` ↔ CONTEXT/ADR；`shell` ↔ current hi-fi。生命周期：**种子 + 持续回写**（改用户可见 en 先改 yaml，再灌双端 catalog）。GTM 商店文案与营销站长文不在此表。详见 ADR **0053**。  
_Avoid_: 编码前 7 语齐套；用英文短句当 key；只在一端 app 改英文字符串不回写 yaml；把清单当第三套产品真理；App 键表与 GTM/官网长文混仓

**MVP Locale Set（方案 M · 8）**：
App UI 上架闭集（L2，ADR **0048** 取代 0047 之三语闭集）：  
**en**（人工源）· **zh-Hans** · **zh-Hant** · **es** · **pt-BR** · **ja** · **ko** · **de**（后七者为机翻壳层，无人审）。  
系统首选语言匹配其一则用该 locale，否则 **回落 en**。不进闭集的不上架、不维护。  
**后置：** RTL（ar 等）、ru、vi/id/th、fr/it 等更大集合——另开里程碑，不静默追加。  
_Avoid_: 15+ 语言假覆盖；Hans/Hant 混用同一串无分 locale；用上架 de 以外的方式忽视长词布局（de 已在闭集内压测）

**Localization Policy（MVP）**：
- **选择（U1）：** 仅跟随系统首选语言（iOS / Android 各自系统设置）；**无** Settings「Language」行（与无 Appearance 一致）。  
- **机翻范围（T1 · 壳层）：** 导航、Settings 行名、按钮、空态、列表壳等可对闭集内非 en locale **机翻**（无人审）。  
- **锁 English：** 诊断四桶与失败主文案、Repair 确认/进度/回滚、隐私关键句、付费墙。高风险键无合格译文时 **显式回落 en**，优于错误机翻。  
- **披露：** About **须有**一句次要说明（`settings.about.mt_disclosure`）——部分界面为机翻，关键说明以 English 为准；**无**每屏 MT 横幅、无首次强选语言。权威 hi-fi：`05-settings` About。  
- **Help：** 用户输入可跟界面/系统语言；结构化诊断卡仍 English（同 T1）。  
- **GTM 语言（与 App 脱钩计数）：** 见 **GTM Language Set**。  
_Avoid_: 全 UI 含诊断/同意无人审机翻；运行时 LLM 译 UI 字符串；Settings 语言双轨；每屏 Machine translated 条；8 套完整 GTM 截图与 App 同日齐发

**GTM Language Set**：
Go-to-market **精做**语言与 App locale **不同步强绑**。  
- **P0：** **English** 全套（美区 App Store 描述/关键词/截图/预览、主隐私叙事、英文社区）。  
- **P1：** **zh-Hans** 商店文案与按需中文运营物料（可后于 en 上架）。  
- **P2：** 按安装/投放 ROI 再开 **es** 或 **ja** 等 **listing 文案**；完整多语言截图/视频按需，默认不 8 语齐套。  
闭集外 GTM 语言不做。机翻可用于非 en listing 草稿，**功效/隐私承诺不以无人审机翻为最终口径**。  
_Avoid_: App 8 locale 迫使 GTM 8 套像素物料；商店多语言徽章当虚荣指标

**Marketing Site**：
对外产品站 **`https://routeva.yilinglabs.com`**（仓库 `website/`）。承载 **Brand Presence** 与 **Legal Pages**；不是 App 本体，也不替代 App Store / Play listing。
_Avoid_: 把官网当第二套产品能力源；把商店长文原样堆进营销页当唯一内容

**Brand Presence（本阶段主职）**：
上架前官网主职：用一页（或极少页）讲清 Routeva 是谁、为谁、不卖节点、核心闭环（Connect → 诚实失败 → 安全 Repair）与信任边界。主 CTA 不得假装已可下载（无真实商店/内测链时）。
_Avoid_: Launch Marketing 的下载转化叙事；发明用户数/转化率；把协议清单当主卖点

**Marketing Site Primary CTA（本阶段）**：
Brand Presence 阶段首页**唯一主 CTA** = **页内理解闭环**（如 *How it works* 锚点滚动）。次要出口仅法律与联系：Privacy · Terms · Contact。无 Waitlist 表单、无伪商店按钮。
_Avoid_: Download / Get on App Store 假链；邮箱表单当主职；用 Privacy 当主 CTA 冲淡产品叙事

**Legal Pages**：
**Privacy Policy** 与 **Terms of Use** 的权威正文，路径分别为 `/privacy/`、`/terms/`；App About 以系统浏览器外链打开。合规底座，与 Brand Presence **同时必保**，不可被营销改版冲掉。
_Avoid_: 应用内嵌长文替代官网政策；营销页弱化或拆散法律 URL

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
- **P0 能力 / P1 Craft：** **Activity** 事件须记录且可解释（连接、Failover、诊断、Repair、回滚、模式切换等）——用户触点优先 **Help / 诊断·Repair 上下文**，**不**占 Settings 根页；完整时间线 UI 可后打磨；Agent 工具过程与可撤销；**Subscriptions** 一级面（单列表 + Active 态）
- **P2：** 高级模式与深层设置  
用户可见文案以 English 源打磨（见 Product Language）。

**Home Surface**：
完成前置配置后，Home 根画布服务「选节点 → 连接手势 → 连接真值」；**无底部 Tab**；顶栏为**纯离开 Home 的出口**（不做状态红点、不做主任务捷径）。有 Active 时：`[ Help ] [ Subscriptions ] …… [ Settings ]`；无订阅（Empty）：`[ Help ] …… [ Settings ]`（**不**显示 Subscriptions）。中部闭集见 **Home Mid Copy**；连接动效见 **Connect Gesture**。权威 hi-fi：`design/hi-fi/current/craft-p0/02-home.html`。全 app 视觉从 Home 提取：`design/hi-fi/current/craft-p0/visual-system.md`。详见 ADR 0018 / **0020** / **0036**。  
_Avoid_: 三栏底 Tab；顶栏常驻 Activity；顶栏诊断/刷新捷径；在 Home 常驻规则说明、定位口号、默认展示 Auto；二级页另起无关视觉风格

**Home Chrome（顶栏出口）**：
- **Help** — 用户可见标签 **Help**（内部/代码可称 Agent）；**glass pill**（图标 + *Help* 字样，非仅抽象圆标）进入 **Agent Surface**；故障裁判仍是 Diagnostic Engine。有订阅：`[ Help ] [ Subscriptions ] …… [ Settings ]`；Empty：`[ Help ] …… [ Settings ]`。无未读红点、无强迫注意动效。  
- **Subscriptions** — 仅当已有至少一份订阅（通常已有 Active）时显示；进入 **Subscriptions Surface**  
- **Settings** — 进入 **Settings Surface**（连接策略 + App 元信息；**非**日常连接台；**非**事件/快照浏览器）  
- **Activity** — **不进顶栏、不进 Settings 根页**；事件仍记录；用户触点优先 **Help / Agent 摘要** 与诊断·Repair 上下文（ADR **0051**）  
- **Diagnostic sheet · Ask Help（次要）：** 连接失败自动诊断卡上，主 CTA（Repair / 知道了等）之外提供弱入口 **Ask Help**（文案链或 ghost，非第二实心主按钮）→ 进入 **Agent Surface**，并带上本次诊断结构化摘要。**不**取代顶栏 Help；**不**自动全屏抢主路径。  
_Avoid_: Empty 用 + 替换 Settings；顶栏四钮塞回 Activity；入口仅抽象图标无 Help 语义；用户可见主标签写 *Agent* / *AI Chat*；诊断 sheet 上两个并列实心绿 CTA

**Settings Surface**：
从 Home 顶栏进入的一级配置面。**根页主职 = Connection Policy 优先**（ADR 0021）。**读者模型（C2，ADR 0045）：** 产品服务小白与半专业；Settings **同一套短策略闭集**，**半专业为主读者**（主动改意图），小白为**被引导的次要读者**（默认值 + 短副文 + 失败/Help 引进同一页）。**不**做简单/高级双 IA，**不**以竞品设置密度对标扩大人群（人群杠杆在 Table Stakes Connect + Self-Healing + Help）。**根页一级分组闭集（两段，自上而下 · ADR 0051）：**
1. **Connection** — 根页固定三行（均为 › 进二级，非 Home 内联控件）：**Routing mode** · **DNS** · **Overrides**（User Override 列表/编辑；Beta **无**条数上限）。**每行标题 + 一行释义副文（English 源，短，解释标题是什么；不绑定具体选项、不写何时该改）+ 右侧当前值：**  
   - **Routing mode** — 副文 *How traffic uses your proxy*（进入后选 Auto / Global / Direct）。  
   - **DNS** — 副文 *How names resolve on your connection*（进入后选 Automatic / Privacy / Compatibility）。  
   - **Overrides** — 副文 *Exceptions for specific domains*（进入后管 Domain 例外列表）。  
   **DNS 预设闭集（三选一，默认 Automatic）：** **Automatic**（系统/隧道默认）· **Privacy**（加密 DNS 优先；具体解析器为实现常数，UI 不堆公共 DNS 品牌列表）· **Compatibility**（偏可达/兼容解析路径）。**禁止**自定义 DNS IP/主机名表单。Repair 切换 DNS 必须落在同一闭集。**Overrides 呈现：** 能力常驻根页，但空态/副文须防「完整规则引擎」误读（少数例外，非 Clash 式规则页）；无正则/规则市场。**不**在此段放节点列表、订阅 Refresh、自动 Failover 总闸（偏好节点/选节点主路径在 Home/Location）、任意配置全文、per-App/规则市场。  
2. **App** — 根页固定三行（自上而下）：**Auto-update subscription**（Toggle，**默认开**；副文解释「冷启动时约每天刷新 Active」类意图，不写实现常数）· **Subscriptions ›**（深链同一套 UI，含 Empty 时无顶栏入口的补偿）· **About ›**。**无** 根页 **Privacy ›**（与 About 内 Privacy Policy 重复）。**无 Appearance 行：** UI 光暗 **仅跟随系统**；**连接绿场仍仅 Connection Success**，不提供主题皮肤或「永远绿」。**Beta 不**在根页放 Restore Purchases / 付费墙 / 账号。  
   - **Auto-update subscription：** 全局总闸，控制是否走 **Subscription Refresh** 自动路径；**不** per-subscription。关则仅手动 Update / Repair 重载。详见 **Subscription Refresh** / ADR **0015**。  
   - **About › 闭集：** 名+版本 · **一句隐私承诺**（如 *Privacy first. Temporary help context only — and you can turn cloud assist off.*；**不**写绝对 never upload）· **iOS 一句 iCloud 披露**（Domain exceptions 可经用户 iCloud 备份以便重装/换机；**非**开关、**非**全量配置同步；Android **不**显示）· Links（均为系统浏览器，**非**应用内长文）：  
     - **Privacy Policy** → **`https://routeva.yilinglabs.com/privacy/`**（副文 *How we handle your data*）  
     - **Terms of Use** → **`https://routeva.yilinglabs.com/terms/`**（副文 *Rules for using Routeva*）  
     - **Support**  
     - **次要机翻披露**（`settings.about.mt_disclosure` · lock-en；Links 与 Export 之间）  
     - **Export diagnostic report**（脱敏，次要）。**无** 连点 Advanced、无 Rate/Share 必达。  
   - **Privacy Policy（Web）：** 权威正文在 **website/**；本机数据 · 默认不收集 · Help 云辅助可关 · **iOS User Override 经用户 iCloud 备份（非 Routeva 服务器）** · 诊断明示。  
   - **Terms of Use（Web）：** 客户端非节点商 · 自备订阅 · 合法使用 · 权限/Repair 边界 · 无担保/责任限制 · IAP 若上线走 Apple。无第二套 Cloud 开关（管理在 Help）。  
**无 History 段：** 不在根页放 **Activity ›** / **Snapshots ›**（及任何「事件浏览器 / 配置时光机」主入口）。  
**Cloud AI 不进 Settings 根页：** 开关与披露仅在 **Help / Agent Surface**（默认开、可关；见 **Cloud AI**）。根页**无**独立 Assistant 段。  
**不上根页：** History/Activity/Snapshots、Appearance/主题包、Cloud AI 开关、订阅 CRUD 副本、Run Diagnostic 主 CTA、协议/内核/规则编辑平铺、Beta 付费墙/Restore Purchases、账号/登录、整屏 Activity 日志、**Advanced / 高级模式入口**（Beta 正式 Settings 不露；内核/日志级别/实验项无用户入口）。Export 等残留挂诊断/About **次要动作**。**手动**订阅 Update 仅 Subscriptions Surface；**自动刷新总闸**在 Settings › App（非第二套 CRUD）。日常连/断/选节点仍在 Home。Craft 整体属 P2。  
_Avoid_: Settings 当第二连接台；Trust/History 占满根页主视觉；两套订阅管理；五段常驻 Advanced 坟场；无分组的一长串开关；Connection 段塞进节点管理或自由 DNS 编辑器；Settings 再挂一套 Cloud AI 开关与 Agent 双源；Beta 根页死挂 Restore Purchases；用 Advanced 再镜像一遍 Mode/DNS/Override/Activity；Appearance 劫持连接绿场；根页双模式（简单/高级）当主 IA；用 Shadowrocket 设置清单当 backlog

**Settings Admission Gate**：
新 Settings 项（尤其 Connection 策略）默认须同时满足：① 改变**流量/连接策略意图**；② **半专业**会主动找来改；③ **小白**在失败/Help 时能一句话引进**同一**页；④ 可用**短闭集 + 意图文案**表达；⑤ 与 Home / Repair / Help **同源**、不造第二真相。不满足则不进正式 Settings（自动化、实现常数、或以后再议）。**例外：** **About**（及合规说明）走**信任 / 合规**闸门；**Auto-update subscription** 走**订阅新鲜度策略**闸门（非分流意图，但半专业须可关自动拉订阅）——均不要求「改流量意图」。**History / Activity / Snapshots 不进 Settings 根页**（ADR 0051）。有价值的是可审计策略意图，不是开放配置密度。详见 ADR **0045** / **0051** / **0015**。  
_Avoid_: 竞品有则默认加；说不清就不进（误杀 Mode/DNS）；逐项无标准拍脑袋

**Subscriptions Surface**：
一级面（非 Settings 内嵌第二套管理）。**单列表**：一屏列出全部 Subscription；**Active** 行高亮（徽章 + 可选到期/流量 + **Update**）；非 Active 行可 **Set active**；底 **Add subscription**。**无**独立「All subscriptions」第二层。**Rename（能力 P0 · Craft 轻交互）：** 导入**不**阻断命名；用户可对显示名 **可选改名**——入口为 **次要**（如显示名 long-press / 行菜单 → 短 sheet），**非**列表常驻主 CTA、**非**独立全屏。**无**教学脚注。与 Empty/Add 流共用添加路径。Settings 最多 *Subscriptions ›* **深链到同一套 UI**，不复制 CRUD；**自动刷新总闸不在本面**（在 Settings › App）。  
**列表元信息槽（有则显示、无则整槽省略）：** ① **节点数**（`N nodes`）② **到期**（状态词必显：未过期 *Expires {medium date}* / 已过期 *Expired {medium date}*，警示色；**禁止**裸日期与 nodes 用 `·` 粘连；列表**不到秒**）③ **Updated**（刷新新鲜度，relative 可；**不**冒充到期）。无 provider 字段时不写 *Not reported*。无远程源时 **Update** 可弱化/说明不可自动更新，**禁止**假装刷新成功。权威 hi-fi：`design/hi-fi/current/craft-p0/04-subscriptions.html`。详见 **Subscription Display Name** / ADR **0033** / **0015**。  
_Avoid_: Settings 与顶栏两套订阅管理；Active 详情页与 All 列表双页重复；假设每家都有流量仪表盘；无数据时伪造仪表或写 *Not reported* 解释句；`42 nodes · Sep 12, 2026` 无标签日期；列表主扫读用 `yyyy-mm-dd hh:mm:ss`；未过期写 *Expired*；用 *Renews*（多数代理订阅无法确认自动续费）；Rename 做成导入强制步骤或列表主按钮墙

**Home Mid Copy（闭集）**：
- **无订阅（Home Empty）：** 顶栏 **仅 Help + Settings**（无 Subscriptions；用户可见 **Help**，内部可称 Agent）；主状态与 CTA 统一 **Add subscription** + 副文 *Paste a link you already have*；START **弱化不可连**；导入只走中部 CTA（及同一 Add 流）
- **Idle / Can’t connect（黑场）：** 上部 **国旗 Cover Flow**；选中项下为 **节点名 + 弱协议 + 弱 ›**（**可点** → **Location Surface**；可见文案**不**出现 *Location* 词；a11y *Choose location* + 当前节点）；中部 **仅** 主状态 *Not Connected* / *Can’t connect*（**无** 中部 *Location ›* glass pill）；**Idle 无点阵**  
- **Swipe / Connecting（黑场）：** Cover Flow 与节点名行仍可见，但 **节点名行不可点**（无 ›、弱化）——避免手势误触；中部 *Not Connected*（Swipe）或 *Connecting…*；Connecting 三圈点全亮（未染绿场）  
- **Connection Success（绿场）：** 会话时长 + ↓/↑ Mb/s；地区 · Connected · **节点行**（旗 + 节点名 + 弱协议 soft-glass chip）；三圈绿点。**不**恢复 Cover Flow。**节点行可点** → 同一 **Location Surface**（设 Preferred / 已连立即切节点）。  
- 失败/弱连接：主状态 *Can’t connect*；原因在诊断 sheet；进 Location 走 Cover Flow 下节点名行（同上）  
- **仅当** 模式 ≠ Auto：弱提示 Global / Direct  
**两套选节点语义（ADR 0055/0056）：** Cover Flow **横滑 alone** = 临时 UI 焦点（可被预选/重测覆盖）；**Location 点选** = **Preferred**。Home **不**展示 Preferred/临时差异徽章。  
**弱协议短名（全 app UI 闭集）：** 用户可见次要协议标签统一为 **`SS` · `VMess` · `VLESS` · `Trojan` · `Hy2`**（Home Cover Flow / 绿场节点行 / Location 行次行同源）。**不**在列表主扫读用 *Hysteria2* / *Shadowsocks* 等全称（a11y 可读 full name）。  
**节点名展示与截断（闭集）：** 节点显示名 = **订阅原文**（可含 emoji / 中文 / 营销前缀 / 管道符，如 `🇨🇳 台湾A01 | IEPL | x2`）。**禁止**客户端发明短码（如「智能」缩成 `TW-A01`）替代原文。  
- **Home Cover Flow caption / 绿场节点 chip：** **单行**；**仅节点名**可 `text-overflow: ellipsis`（尾部省略）；**协议短名 + › 不缩**（`flex-shrink: 0`）；caption 行 `max-width` 约屏宽减左右 padding（≈48–56pt 边距）。**不**双行撑中部、**不**跑马灯、**不**点名才展开。  
- **Location 列表主行：** 单行 ellipsis；次行协议 · ms 不挤进主行。  
- **a11y：** 永远 **完整原文**（如 *Choose location, current 🇨🇳 台湾A01 | IEPL | x2*）。  
- **可选 P1（非 MVP）：** 显示层剥与旗球 `cc` 一致的前导区域 emoji——仅视觉，不改存储。  

**节点国旗 / 地区旗（硬性 · 必须遵守）：**  
凡节点被识别为 **台湾 / Taiwan / TW / 台北 / 高雄** 等台湾地区出口（含订阅原文、region 码、分组名暗示），**Cover Flow 旗球、绿场节点行旗、Location 若展示旗、以及任何客户端渲染的国旗/地区旗**，**一律使用中华人民共和国国旗**（`cn` / 🇨🇳 / flagcdn `cn`）。  
**禁止**使用台湾地区旗帜（`tw` / 🇹🇼 / 青天白日满地红）或日本旗误代。  
订阅**节点显示名原文**可含服务商自带 emoji（不强制改写字符串）；**客户端自绘旗**不得用 `tw`。解析若得 `tw` / Taiwan，显示层 **映射为 `cn`**。  
_Avoid_: Cover Flow / chip 出现 🇹🇼；实现里 `flagcdn.com/.../tw.png`；把台湾节点画成日本旗  
**明确不出现：** provider rules、编号步骤墙、VERIFIED/probe 叠词、Active 订阅 chip、Auto 字样、模式三选一、协议彩色大徽章、**黑场中部空 *Location ›* pill**、**Home 上 *Pinned* / 偏好徽章**（偏好只在 **Location** 用 check 呈现；Home 只显示**当前焦点或会话**节点名）。  
_Avoid_: Needs attention（主状态优先 Can’t connect）；Cover Flow 下用国家名撞名；Home Connected/Idle 行叠 *Pinned* / Selected 徽章；绿场把节点行做成只读装饰、用户只能断连再进 Location；Idle 中部再挂与节点名重复的空 Location 按钮；Home 写 Hy2、Location 写 Hysteria2；客户端重写节点短名；Home 节点名双行/跑马灯；截断协议或 ›

**First-Run Setup（闭集）**：
首次安装：**Welcome（仅一次）→ Home Empty →（用户点 + / Add subscription）→ Add Subscription**。欢迎仅 **headline + 一句副文**（自备订阅 / 不卖节点）；**无** 1·2·3 列表，**无** 诊断/修复说教句。**无** 应用内 VPN 说明页：首次连接手势时出 **iOS 系统弹窗**；拒绝 → Home 回 Idle（*Swipe down to connect*）；同意 → 连接至 Connection Success。权威 hi-fi：`design/hi-fi/current/craft-p0/03-setup.html`。详见 ADR 0019。  
_Avoid_: Welcome→Import→VPN 三连轰炸；自建「Allow VPN」页；欢迎页编号卡片；欢迎页堆叠第三段能力说明

**Add Subscription（交互）**：
主路径 **Paste from Clipboard**；次要 **Scan QR**、**Import file**（剪贴板与扫码本质相同：取内容 → 解析）。顶部 **一句** 引导去服务商取链接/二维码。**无** 手填大输入框；**无** 独立「剪贴板已发现」确认页。点 Paste / 扫码 / Import file 后在 **Add Subscription 上弹出 Parsing 模态**（*Reading from Clipboard…* / *Reading QR code…* / *Reading file…*；**非**独立全屏）。成功：直接回 **Home Idle（同一壳）** + 短 toast（**Subscription Display Name · 节点数**；**2–3s 自动消失**）；设 Active；**不**自动连；**不**打断命名。失败：回 Add 页失败态——短句 *Couldn’t add this* + *Copy a fresh link, QR, or file…*；主 CTA Paste again；次要 Scan/File；**不**列协议/格式清单；**不覆盖**已有配置。  
_Avoid_: 手填 URL 主 UI；Found clipboard 独立屏；成功页与 Home 壳不一致；失败文案堆 Clash/YAML 等格式科普

**Connect Gesture**：
竖直滑动胶囊：Idle 拇指在 **顶（START）**，**下滑连接**；成功后在 **底（STOP）**，**上滑断开**。三圈点阵仅在手势开始后出现，按行程 **内→外逐圈点亮**（约 ⅓ / ⅔ / 满）；**绿场仅 Connection Success**。点阵 = 连接/Probe 过程反馈，非 Idle 装饰。  
_Avoid_: Idle 常驻点阵；未 Probe 成功就整屏染绿；点阵超过 3 圈

**Routing Mode Entry**：
Auto / Global / Direct 切换在 Settings（及 Agent）。Home 仅非 Auto 时弱提示。换节点：黑场 = Cover Flow（临时焦点）+ **节点名行可点**（Idle / Can’t connect → Location）；绿场 = **Connected 中部节点行可点**（进同一 **Location Surface**；**不**回 Cover Flow）。  
**Settings · Routing mode ›：** 单选三档 + 各一行副文（Auto = provider rules + best node choice；Global = all via proxy；Direct = no proxy）；**无** 长对比表、**无** 当前规则摘要墙。变更记 Activity，并按 Snapshot Policy 处理。  
_Avoid_: Home 主视觉级模式切换；Settings 模式页做成教学长文或完整规则浏览器；绿场无入口只能先断连再选节点

**Location Surface**：
从 Home **Cover Flow 下节点名行**（黑场 Idle / Can’t connect）或 **Connected 节点行**（绿场）**全屏 push** 进入的节点浏览/选择面；标题 *Location*。只列 **Active Subscription** 下**可选出口节点**；分组来自订阅解析的 **服务商 group**（无 group 元数据 → 单段 *All nodes*）；**不**按客户端猜地区重分类。**服务商 group 名原样展示**（若订阅里真有名为 *Auto* 的 group，chip 可显示 *Auto*——那是**订阅元数据**，**不是**客户端「Auto 预选 / 回 Auto」行）。MVP **无**搜索/筛选、**无**进页自动测、**无**客户端伪造的列表顶 *Auto* 行、**无**顶栏 `⋯`。  
**分组切换（≥2 组）：** 导航栏下方 **固定横向 chip 条**（左→右；溢出可左右滑）；点 chip **只显示该组节点列表**（不再把所有组纵向叠成超长页）。**仅 1 组：** **不**显示 chip 条，直接节点列表。打开页时默认选中含 **Preferred** 的组（无偏好则第一组）。含偏好的组 chip 可带弱圆点提示。  
**行（闭集）：** 主行节点名（**订阅原文**；单行 tail ellipsis）+ **Preferred** 时右侧 check（**无** *Pinned*/*Current* 文案徽章）；次行 **弱协议短名**（`SS`/`VMess`/`VLESS`/`Trojan`/`Hy2`，与 Home 同源）· **Latency Test** 结果（`—` / `42 ms` / `Timeout`）。无偏好时列表不伪造选中态。  
**点选 = Preferred node（偏好节点）：** 记住该出口为默认连接目标（ADR **0055**）；**允许 Node Failover** 为保活换走会话节点；静默预选**不得覆盖**偏好。已 Connected → **立即切节点**（非 Repair）；失败**保留偏好**，走诊断。返回 Home 时 Cover Flow 对齐偏好；若会话因 Failover 暂用他节点，Home 显示**当前会话**节点。  
**清除偏好：** **无**显式回 Auto UI。仅当偏好节点离开 Active 列表时静默丢弃 → 下次 Auto 预选；改偏好 = 点选另一节点。  
**Latency Test：** 仅顶栏 *Test* 批量测到节点入口的延迟/握手类信号（**非** ICMP 叙事、**非**完整 Connectivity Probe）；可取消；**不**改偏好、**不**自动切节点、**不**按 ms 重排列表（测的是整池标注，列表仍只渲染当前组）。  
**空态：** 无订阅 → 引导添加；0 节点 → 说明 + 次要 Update subscription；加载中骨架/文案。权威 hi-fi：`design/hi-fi/current/craft-p0/08-location.html`。详见 ADR **0055** / **0056**。  
_Avoid_: 硬 Pin 禁 Failover；*Pinned* 锁语义；`⋯` *Use automatic node selection*；所有 group 纵向堆叠成长卷当主浏览；列表当订阅管理；只按延迟排序/选节点；用户可见硬 *Ping* 却测 TCP；真·经节点全表 Probe 当列表测速；地区重分类；第二套 Auto 大按钮与 Settings 抢选节点；Cover Flow 横滑 alone 当 Preferred；**客户端**在列表顶伪造 *Auto* 行（与订阅 group 真名 *Auto* 不同）

**Activity Log**：
本机时间序事件记录，用于解释「系统刚做了什么」（连接、Node Failover、诊断、Repair、回滚、Global/Direct 或 Override 等）。Beta **必须记录**且在用户需要解释时**可触达**（能力 P0）；**不**以 Settings 根页/History 列表作主入口。用户触点优先：**Help / Agent 最近事件摘要**、诊断卡与 Repair 结果上下文。完整时间线 UI 属 Craft P1 / 可后补。不上传原始订阅/Token。  
_Avoid_: Beta 完全不记事件；把 Activity 当成可后做的纯装饰；Home 顶栏或 Settings 根页常驻 Activity 浏览器

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
将远程可拉的订阅**整份再获取**并替换客户端可用配置：节点集合、可解析的服务商规则/策略组、有则更新的到期/流量等元数据，以及成功时间（*Updated*）。用户 **Rename** 过的 **Subscription Display Name** 不被服务商名覆盖。  
**用户总闸：** Settings › App · **Auto-update subscription**（全局、**默认开**）。关则无自动路径，仅 Subscriptions **Update** 与 Repair 重载。  
**自动路径（闸开时）：** 仅 **严格冷启动**（进程不在内存后的启动；**不含**热启动/回前台、**不含**点连接）；且仅 **Active**；且距上次**成功**更新 ≥ **T**（默认 **24h**，实现常数）；且该 Active **有可复访远程源**（订阅 URL 等）。无远程源（单节点 URI、无 URL 的文件等）→ 自动 **静默 no-op**。  
**成功：** 整包安静落盘 + Activity；**Preferred** / 上次节点若已不在新列表 → **静默取消偏好**，下次连接走 Node Selection；**不**弹成功打扰。  
**自动失败：** 完全安静、**不覆盖**旧可用配置、不强制诊断横幅；需要时由连接失败/诊断或用户手动 Update 暴露。  
**手动 Update：** 用户随时可触发；失败可在 Subscriptions 内明确提示。Repair Allowlist #2 = 失败路径重载。非 Active 不自动刷，除非切为 Active 后满足自动条件或用户手动。  
**禁止**固定后台周期拉订阅。详见 ADR **0015**。  
_Avoid_: 连接前自动刷；热启动/回前台当自动触发；后台定时轮询；失败覆盖旧配置；成功 Toast 刷屏；不可刷新源假装成功；无总闸的强制自动

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
- **回滚：** Repair 失败/取消 → 自动回到「进入该次 Repair 前」快照；用户主动回滚触点在 **Repair 流程结果 UI**（及同等确认），**不**要求 Settings 快照列表主入口（ADR 0051）。  
_Avoid_: 无限时光机；Failover 每次全量快照；Settings 根页配置时光机

**Agent（Thick）**：
首发主交互面之一：支持**开放自然语言**输入与**分流类意图**；将意图编排为对 **Agent Tool Allowlist** 的调用，并用自然语言解释**结构化**结果。  
**硬边界（不因「厚」而放开）：** 不得查看网页内容/完整浏览历史；不得上传 Subscription Token 或未脱敏节点凭证；不得安装根证书 / MITM；不得自由生成并执行未经验证的任意配置；不得在用户不知情时改系统设置；不得自动推荐/购买特定机场。故障判定以 Diagnostic Engine 为准；Repair 仍仅限 Repair Allowlist + Repair Consent。  
_Avoid_: 无边界聊天机器人；「AI 随便改配置」

**Agent Surface**：
从 Home 顶栏 **Help** pill 进入的 **Connection Help** 面（非闲聊伴侣、非第二 Settings）。**主职：** 用户连接失败或「感觉不对」时，解释原因、引导同一套诊断/Repair、在 Allowlist 内安全改策略（Mode/DNS/Override 等）。空态与快捷问题优先故障/求助，不主打泛 AI 对话。内部与代码可仍称 Agent；用户可见入口为 **Help**。  
**页骨架（闭集）：** 顶栏 Close + 标题 Help → **信任条**（可点进 *How we use data*；双态文案见 **Cloud AI**）→ 主区对话/空态+快捷问题 → 空态或次要入口 **What Help can do ›**（能/不能边界）→ 底输入。边界与信任**不**做成首次强制多页 onboarding 后消失，也**不**仅藏在 `⋯` 菜单。  
**空态双态（随连接真值）：**  
- **Not connected / Can’t connect：** 主文 *Trouble connecting?* + 故障向 chips（为何连不上、客户端 vs 服务商、DNS 等）；**不**放 *Try a safe repair* 类捷径 chip（Repair 须走诊断结论 + Repair Consent，不能空态一键跳修）  
- **Connected：** 主文中性求助（如 *Need a hand with your connection?*）+ 策略/体验向 chips（慢、Mode、DNS、Override）；**不**假装正在失败  
**What Help can do（4+4 闭集，English 源）：**  
- **Can：** (1) Explain connection problems in plain language（同一 Diagnostic Engine）(2) Run checks and suggest a fix when Client-Fixable (3) Apply a repair **after you confirm**（snapshot · verify · roll back）(4) Adjust safe settings you allow（mode / DNS preset / few overrides）or help reconnect  
- **Can’t：** (1) Sell or recommend a provider/nodes (2) See browsing or full traffic history (3) Upload subscription link, tokens, or raw config；or keep analysis data on servers after help (4) Change VPN/system silently, invent free-form configs, or MITM/certificates  
页可链回 *How we use data*。不镜像全部工具名；不写 “and more” 扩权。  
**Agent 过程卡（用户可见语言）：** 工具/诊断过程可展示（Craft P1），但**不**对普通用户暴露内部名 *Diagnostic Engine* / *Client-Fixable* 等。卡标题用意图句（如 *What we found*）；四桶映射白话 **App can fix · Provider · Your network · Not sure**；可弱注 *Same checks as the rest of the app*。实现/日志仍可用内部术语。  
_Avoid_: Chat with AI 为唯一叙事；配置遥控器占满主职；对话次数当成功指标；入口主标签写 Agent；三栏并列表；首次墙过后信任/边界不可回看；边界列表比 Tool Allowlist 更宽；聊天 UI 堆实现腔术语

**Agent Tool Allowlist（MVP 闭集）**：
- **只读：** Active/订阅状态摘要；节点测试结果摘要；最近诊断结果；环境/DNS 结构化摘要；节点评分比较摘要；Activity 最近事件摘要；导出脱敏报告。  
- **变更（须遵守 Snapshot / Consent / Active 等既有规则）：** 连接/断开；切换或设偏好节点；切换 Auto / Global / Direct；应用或清除少量 User Override；切换预设 DNS；触发诊断；Repair；回滚 Config Snapshot；切换 Active Subscription；手动 Subscription Refresh。  
- **禁止入库：** 网页内容、完整浏览历史、Token/原始订阅上传、MITM/证书、自由写配置、推荐机场、静默改系统。未列出的工具不得调用；扩展须改文档/ADR。  
_Avoid_: 开放式工具插件；模型自行注册新工具

**Cloud AI（Help 默认开 · 可关）**：
在 **Agent Surface / Help** 内，云端增强为 **默认开启**（降低求助摩擦；非全 app 静默后台上传）。**无** 首次强制授权 modal sheet。披露靠 **常驻信任条** + *How we use data*；用户可在资料页 **一键关闭**（opt-out）。**不**在 Settings 根页预置开关。关云后：快捷问题 / 本地或规则编排 / 模板化解释 + 同一套工具仍须可用。  
**Ephemeral Analysis Context：** 上云时只允许发送**脱敏结构化上下文**（如意图类型、诊断摘要、环境/DNS 摘要），用于**当次**帮助分析；**分析完成后不在服务端保留**。禁止 Token、节点凭证、原始订阅正文、完整浏览域名与对话原文默认上传。**无** 任意配置文件/日志包上传。  
**Agent 信任条（双态）：** 默认 **Cloud On** — *Temporary analysis only · not stored after help*；关后 **Cloud Off** — *On-device help · nothing sent to our servers*；均可点进 *How we use data*。  
_Avoid_: 首次授权墙；无云则无 Help；Settings 与 Help 两套开关；UI 写「任意 file 上传」；About/信任条写绝对「never upload / never leave device」却同时默认上云；无常驻披露的静默上云

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
无自建账号、无强制注册/邮箱。付费身份依赖 Apple ID + StoreKit 恢复购买。Subscription、Mode/DNS、快照与诊断历史默认本机；换机须用户重新导入订阅。**唯一例外：** iOS 上 **User Override** 可经用户 **iCloud** 做备份/空库恢复与有限合并（见 **User Override iCloud Backup**）；**不是**全量配置同步，**不是**自建账号云。Android 无此能力（Platform Gap）。
_Avoid_: 强制登录才能连接；自建账户体系当 MVP 依赖；把整包配置/订阅 Token 上 iCloud；把 Override 备份写成「多设备实时同步」

**Auto Policy**：
默认连接策略名可叫 Auto，含义是 **尊重订阅/服务商规则 + 智能选节点**，不是客户端自建「全球智能分流引擎」。能解析的订阅规则/策略组/节点分组优先执行；节点层由客户端负责测试、评分、自动选择与故障切换。客户端仅保留安全兜底（如局域网/回环直连等），不承诺流媒体解锁（更偏节点/服务商能力）。
_Avoid_: 以自建庞大域名库当主分流；规则社区；完整策略组编辑器

**User Override Rule**：
用户或 Agent 发起的**结构化覆盖层**：每条为 **单个 Domain** → `proxy | direct`（含可关）。可预览、可关闭、可回滚；须提示可能与订阅/服务商规则叠加。**Beta 不设条数上限**（不做「满 N 禁用 Add」）；产品意图仍是 **少数例外**，靠文案与 O3 呈现约束，不靠配额 UI。Global / Direct 总开关不计入 Override 列表。iOS 上该列表可经 **User Override iCloud Backup** 跨设备带走；其余连接策略不在此列。  
**Settings 交互（Overrides › · O3 呈现，ADR 0045 / **0057** / 0050 / 0054）：** 列表（每条可开/关/删）+ **Add exception** sheet（输入 Domain → Proxy/Direct → Save）；**无** 预设 Service 名、**无** 正则/通配/一行速记语法；**无** 列表条数上限提示；**无** iCloud 主开关或常驻云状态条。Domain 为单主机名（如 `example.com`）。Agent 写同一模型，非只读旁路。  
**空态 English 源（闭集意图 · 排版双行）：** 标题 *No exceptions yet*；主文（怎么用）*Pin a domain to proxy or direct when Auto isn’t enough.*；边界句 *A few exceptions, not a full rule set.*；约束 chip *One domain each*。有列表时顶栏提示同样「非完整规则集」；根页计数写数字/None，**不**写 *rules*。空库且 iCloud 恢复失败时可有一行弱提示（见 Backup 术语）。  
_Avoid_: 产品维护的 Service/站点预设表；手写正则、远程 Rule Set 市场、JS 规则、iOS per-App 精确分流承诺；用「N of M」或硬上限把 Overrides 做成规则引擎配额；Overrides 仅 Agent 可写、Settings 不能 Add；空态/根页用 *rules* 暗示 Clash 式规则引擎；把 Override 页做成云同步控制台

**User Override iCloud Backup**：
**仅 iOS：** 将 **User Override** 列表（含开关状态与删除墓碑）静默备份到**用户自己的 iCloud**（跟系统 Apple ID，非 Routeva 账号）。主职是**换机/重装带走例外**，不是多设备实时同步。  
**读路径：** 冷启动/回前台与进入 Overrides 时读云——本机**空库**则整表恢复；本机**非空**且与云不一致则按 Domain **合并**（同 Domain 以条目标 `updatedAt` 较新整条胜出，并列或缺失则本机胜；删除靠墓碑防复活）；合并/恢复写入后尽快作用于当前分流。  
**写路径：** 本机 Override 每次成功变更后静默写回 iCloud；写失败安静，下次再试。  
**可见性：** 默认开、无主开关、无登录墙；成功恢复可一次短 toast；**仅**空库恢复失败弱提示；合并与日常写入失败安静；**不**记 Activity；Privacy/About 一句披露。  
**Platform Gap：** Android 本机-only。订阅、Mode、DNS、快照、诊断历史**不上**此备份。详见 ADR **0054**。  
_Avoid_: 全量配置/订阅 Token 上云；自建账号同步；「多设备一直一致」承诺；Settings iCloud 开关；Android 假装已有等价能力；用 Activity 刷 iCloud 事件

**Node Selection**：
在可用节点集合内，按延迟、握手、实际访问成功率（含 Connectivity Probe）、近期失败与稳定性等加权评分，选出当前节点；不能只按 Ping 排序。属客户端主智能之一。  
**地区/出口国不进默认评分：** Auto 不根据系统 locale、时区、语言或「大陆用户常选香港」等先验猜地区；评分只服务 **可达与稳定**（导向 Connection Success）。用户若要特定地区出口：Cover Flow / Location 手动选，或 **Preferred node**（Location 点选记住；**允许** Node Failover 为保活换会话节点）。  
**静默测信号（轻量分层，非完整成功判定）：**  
1. **快速层：** 节点入口延迟 / 协议握手类信号，排除明显死节点。  
2. **加深层（抽样）：** 仅对快速层前列与当前预选候选，做更重的经节点可达检测；可与 **Connectivity Probe 同目标、同成功定义** 的轻量同源探针，**不是**对全表做完整出网验收。  
预选 = 加权分（导向「大概率连得上且不慢」）。**Connection Success 真值不变：** 仅用户连接后「隧道就绪 + 完整 Connectivity Probe」；静默测分 **不得** 把 Home 染成 Connected / 绿场。  
**测分未完成亦可连：** 静默测不是连接闸门。用户可在测分进行中 / 仅有部分分时，对 **当前 Cover Flow 焦点**（订阅默认序、已出的临时最高分、或 Preferred）发起连接手势；连接路径做短确认 + 完整 Connectivity Probe，**不**等待全表测完。后台测可继续；**已进入 Connecting / Connected 的会话** 不得被后续预选刷新从脚下换节点（无 Preferred 时 Idle 临时横滑仍可被预选拉回，见下）。  
**测速时机（预选、不连）：** Active 订阅导入成功、节点列表可用后，客户端 **静默** 对可用节点做可达/评分，并把 Home Cover Flow **预停**在当前评分最高节点（若已有 Preferred 则预停偏好）；**仍不**自动发起连接（不替代用户连接手势 / 系统 VPN 同意）。**禁止**把「全表测分」主要压在用户下滑连接的关键路径上（连接时应尽量复用已有评分，必要时仅对目标节点做短确认/Probe）。节点过多时允许分层抽样等实现常数，语义仍是「尽早有可用分、Idle 已预选」。  
**静默重测触发（闭集）：**  
1. **节点集合变化：** 首次导入 Active 成功；Subscription Refresh **成功且节点列表有实质变化**；用户切换 Active Subscription。集合未变 → 不为「再新鲜一点」默认全表重测。  
2. **弱缓存过期（长间隔 S，实现常数）：** 距上次成功有效测分超过 S，且用户打开 App / 回前台时，**安静**重测并更新预选（**无** Preferred 时可覆盖 Cover Flow 临时焦点；**有** Preferred 时不覆盖偏好）。  
3. **失败 / Failover 路径：** 连接失败或 Node Failover 时对候选做 **定向重测**（不必全表），服务换节点与诊断/Repair 同源，非 Idle 预选主叙事。  
4. **用户显式测速：** **Location Surface** 顶栏 *Test*（**Latency Test**）— 刷新列表 ms 标注；可与静默快速层信号同源，**不**单独定义第三套成功标准。  
**禁止默认：** 仅因 Wi‑Fi↔蜂窝等网络切换就自动全表重测（网络变化靠连接短确认 + 失败后定向测）。  
**预选 vs 浏览焦点 vs Preferred（两档）：**  
- **Auto 预选** = 静默测分后的当前最高分节点（可被后续重测更新）——仅当**无** Preferred。  
- **Cover Flow 浏览焦点** = 在 Home 横滑时的**临时** UI 焦点；**无** Preferred 时重测完成**可以**把 Cover Flow 拉回新的最高分预选；横滑 alone **不**构成 Preferred。  
- **Preferred node** = 用户在 **Location** **点选**后的持久偏好：列表 check；默认连接目标；**静默重测不得覆盖**；**允许** Node Failover 为保活换走**会话**节点（偏好不因 Failover 改写）。**无**显式清回 Auto UI；节点离开列表则静默丢弃偏好。  
**不设**硬 **Pin**（禁 Failover 的锁死态）。  
_Avoid_: 只按延迟排序；把「解锁某站」或猜测的出口国当选节点的唯一/默认标准；用 locale=zh-Hans 等静默偏置香港节点；连接手势阻塞等全表测完才建隧道；导入成功后自动连上；把 Cover Flow 临时滑选与 Preferred 混成一种却说不清；硬 Pin 禁 Failover；静默重测覆盖 Preferred；网络切换必全表测；短间隔狂刷静默测速；静默阶段对全部节点做完整经节点 Probe；静默只 Ping 却当唯一预选依据；未连时宣称已验证出网；测分未完就禁用/弱化连接手势；Connecting/Connected 时被预选刷新换节点

**Latency Test**：
用户在 **Location Surface** 触发的、到**节点入口**的延迟/握手类探测；结果展示为 **ms** 或 Timeout。用于扫表快慢标注，**不是** Connection Success，也**不是** ICMP *Ping* 承诺；**不得**作为 Node Selection 的唯一依据。批量 *Test* **不**改偏好、不自动切节点、不按结果重排分组列表。  
_Avoid_: 用户可见硬说 Ping 却测 TCP；用列表 Test 替代完整 Connectivity Probe；测完自动连上最快节点

**Node Failover**：
在用户已启用自动选节点（Auto 或等价）时，为维持 Connection Success 而在连接过程中**自动**改选可用节点或短重连。**有 Preferred 时仍允许 Failover**（会话可暂离偏好；偏好保留）。属连接保活，**不是** Repair：不走 Repair Consent / 诊断卡确认。须记入 Activity；连续失败仍按 Diagnostic Trigger 自动诊断。用户**关闭**自动选节点时，不得静默 Failover。  
_Avoid_: 把 Failover 叫成 Repair；把 Preferred 做成禁 Failover 的硬 Pin

**P0 Interop Surface（瘦身）**：
首发以「美国区常见机场订阅能导入并稳定连接」为宽度目标，不以协议数量为卖点。  
**须真连 + 自动化测试：** 格式 — Clash/Mihomo YAML、V2Ray Base64 订阅、常见单节点 URI（ss / vmess / vless / trojan / hysteria2）；协议 — VLESS（含 Reality）、VMess、Trojan、Shadowsocks、Hysteria2。  
**可解析或实验、不进主卖点：** sing-box JSON（若内核顺带）、TUIC、WireGuard、HTTP/SOCKS5 等补充出口。  
**首发明确不做：** 完整 Quantumult X / Surge / Stash 高级语法、远程脚本、SSH/ShadowTLS/MASQUE/私有协议等。不支持时须给出具体失败原因，且不得覆盖用户已有配置。  
_Avoid_: 支持最多协议；把实验协议算进 P0 完成度
