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
**产品能力 Dual-Native 单源**（iOS + Android）；**实现与 Beta 验证默认 iOS 先**（ADR **0061**）。  
- **iOS：** 同一 App；**iPhone 为设计与验收主设备**；iPad 可装可用，布局/多任务不优先。**最低系统：iOS 17+**。实现主轨与首版 Beta 真机验收默认在此。  
- **Android：** **同一产品能力表**；**手机为主验收**；平板/折叠基础可用。minSdk 实现期锁定。可不与 iOS 同日齐功，未交付项记 **Platform Gap**。  
Mac / Apple TV / 桌面端首发不做。
_Avoid_: iPad-first；仅一端静默砍能力；为 iOS 16 及以下扩测试矩阵；把两端当两个 Product；把「能力单源」误读成「双端必须同 sprint 并行证明」

**Dual-Native Layout**：
Application Source 为 `app/ios/` 与 `app/android/` 两棵独立树，互不 compile/import。产品语义在 `PRODUCT.md` / PRD / `design/**/current/` / 本文件单源。见 ADR **0049**。
_Avoid_: 根目录 `ios/`+`android/`；默认 Flutter/RN 主壳；第三套 `app/shared` 业务实现

**Implementation Track（Beta）**：
**设计 / 文档 / copy 单源**；**编码与 Self-Healing 真机证明默认先 iOS**（TestFlight / iPhone）。Android 工程可骨架并行，但 **不以 Android 阻塞 iOS Beta**。见 ADR **0061**。  
_Avoid_: 未验证主价值前强行双端同日齐发；静默从 MVP 删 Android 而不改文档

**Platform Realization**：
同一用户可见能力在各平台用原生 API 落地（如 StoreKit vs Play Billing；Network Extension vs VpnService）。**不是**第二条 PRODUCT 能力。
_Avoid_: 「iOS 支付」「Android 支付」拆成两条核心能力

**Platform Gap**：
共享能力列表中一端尚未交付的项。允许暂时领先/落后，须在 PRD 或 status **显式**标注目标版本；禁止静默漂移。iOS-first 节奏下，Android 落后为**预期**，仍须写明 Gap。
_Avoid_: 永久单端功能伪装成 Gap；用 Gap 默默把 Android 移出产品

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
- **GTM 语言（与 App 脱钩计数）：** 见 **GTM Language Set**。商店截图像素套见 **Store Screenshot Locale Set**。  
_Avoid_: 全 UI 含诊断/同意无人审机翻；运行时 LLM 译 UI 字符串；Settings 语言双轨；每屏 Machine translated 条

**GTM Language Set**：
Go-to-market **精做**语言与 App locale **不同步强绑**。  
- **P0：** **English** 全套（美区 App Store 描述/关键词/预览、主隐私叙事、英文社区）。  
- **P1：** **zh-Hans** 商店文案与按需中文运营物料（可后于 en 上架）。  
- **P2：** 按安装/投放 ROI 再开 **es** 或 **ja** 等 **listing 文案**。  
截图像素套另见 **Store Screenshot Locale Set**（可与 listing 长文不同步）。闭集外 GTM 语言不做。机翻可用于非 en listing 草稿，**功效/隐私承诺不以无人审机翻为最终口径**。  
_Avoid_: 商店多语言徽章当虚荣指标；用 8 套无人审描述长文冒充精做

**Store Screenshot Locale Set**：
商店截图像素套的语言闭集，与 **MVP Locale Set** 对齐：**en** · **zh-Hans** · **zh-Hant** · **es** · **pt-BR** · **ja** · **ko** · **de**。每语沿用同一 **Store Screenshot Spine**。  
_Avoid_: 闭集外再开 ru/ar 截图套；Hans/Hant 共用一张图；App 8 语只出 en 图却宣称多语言截图齐套

**Store Screenshot Copy Surface**：
每张商店截图上随 locale 改写的文字：框外 **Listing 标题** + 手机内壳层 UI。lock-en 与演示节点名不随 locale 改。  
_Avoid_: 只译标题装多语言；为截图另造一套与 App catalog 不同的 UI 口语

**Store Screenshot String Source**：
手机壳层 UI 取与二进制相同的 locale catalog。Listing 标题按 Spine 每语人工两行，不机翻品牌句。  
_Avoid_: 截图另写一套 UI 口语；无人审机翻当 Listing 标题终稿

**Store Screenshot Display Type**：
Listing 标题按文种：en / es / pt-BR / de 用 Newsreader；zh-Hans / zh-Hant / ja / ko 用系统黑体。两行格、底线、字号与 en 相同。  
_Avoid_: 用 Newsreader 假覆盖汉字；八语全改成 SF 丢掉 Jobs 衬线

**Store Screenshot Listing Titles**：
八语框外标题已按 Spine 人工锁两行（en 金句不改）。正文表在 `docs/sessions/2026-08-14-app-store-screenshots.md`。  
_Avoid_: 用机翻覆盖已锁标题

**GTM Phase（grill 2026-08-07 · A）：**  
**当前阶段 = Brand Presence only**（官网主职 + Legal Pages · ADR **0052**）。**不**要求现在填满 App Store / Play listing 长文、关键词矩阵、像素截图或预告片。商店物料默认等 **iOS 真机可截**（或明确开 listing 里程碑）再开；禁止用过期 hi-fi 冒充商店截图上架。icon 等已有资产可保留。  
_Avoid_: 编码前完整 GTM 套件并行；假截图冲审；Waitlist/下载假 CTA 冲淡 Brand Presence

**Marketing Site**：
对外产品站 **`https://routeva.yilinglabs.com`**（仓库 `website/`）。承载 **Brand Presence** 与 **Legal Pages**；不是 App 本体，也不替代 App Store / Play listing。
_Avoid_: 把官网当第二套产品能力源；把商店长文原样堆进营销页当唯一内容

**Brand Presence（本阶段主职）**：
上架前官网主职：用一页（或极少页）讲清 Routeva 是谁、为谁、不卖节点、核心闭环（Connect → 诚实失败 → 安全 Repair）与信任边界。主 CTA 不得假装已可下载（无真实商店/内测链时）。
_Avoid_: Launch Marketing 的下载转化叙事；发明用户数/转化率；把协议清单当主卖点

**Crafted Connect**：
Brand Presence 与商店 listing 共用的主叙事：卖连接体验（Paste → 精致路径 → 诚实 Connection Success），不卖协议军备或已上线自愈。金句 *Connect without the maze.*
_Avoid_: 订阅句当 H1；把未交付的诊断/Repair 写成已上线；协议墙当主卖点

**Listing Hook**：
App Store 截图第 1 张。转化任务 = **结果先行**：展示 **Connection Success** 绿场，标题继承 Crafted Connect（*Connect without the maze.*）。订阅边界与「不卖节点」不占首图主句。
_Avoid_: 首图边界声明；首图功能清单；首图竞品对比拼贴

**Store Screenshot Set**：
App Store 精做截图闭集：**4** 张 · **Store Screenshot Locale Set** 八语 · iPhone 主图。现行视觉 = **A · Jobs**。HTML 源 `design/hi-fi/current/store-screenshots/`；渠道成品 `gtm/stores/app_store/screenshots/`。每语两档：6.5" **1284×2778**、6.7" **1290×2796**。第 1 张为 **Listing Hook**。无 Connecting 收束张。
_Avoid_: 闭集外再开尺寸档；用过期 hi-fi 冒充真机上架；从 `_explore/` 导出上架图

**Store Screenshot Spine**：
闭集四张与产品 UI：① Listing Hook — Home · **Connection Success**（*Connect without / the maze.*）；② Gesture — Home · **Idle**（*Swipe once / to go online.*）；③ Setup — **Add Subscription**（*Paste a link / to set up.*）；④ Control — **Location**（*Pick the / fastest one.*）。标题统一两行，共用一条底线和标题–手机留白。
_Avoid_: 地图或国家墙；Welcome / Settings 当主图；用 Latency Test 冒充 Probe

**Listing Copy Voice**：
选定套 **A · Jobs**：一句一事、强制两行 Newsreader、**无副文**。能力/结果 ≤6 词。
_Avoid_: 首图功能清单；否定堆叠；商业 VPN 话术（Our servers / 90+ cities）；把 *VPN* 当品类主词

**Store Screenshot Candidate**：
按 iPhone 6.7" 画幅探索的视觉方向，**不是**已提交上架素材。终稿必须沿用同一 **Store Screenshot Spine**，并用与二进制一致的产品 UI。
_Avoid_: 把 candidate 当已上传素材；用过期 hi-fi 冲审

**Store Screenshot Directions**：
同一 Spine 上的三车道探索；**已选定 A → 收口为 A · Jobs**（current）。B Instrument Quiet 与 C Capability Nouns 不进 listing。  
_Avoid_: 用竞品的 MitM / Clash / 流媒体解锁话术；纯换底色冒充分叉；把未选定车道当现行套

**Marketing Site Primary CTA（本阶段）**：
Brand Presence 阶段首页**唯一主 CTA** = **页内理解闭环**（如 *How it works* 锚点滚动）。次要出口仅法律与联系：Privacy · Terms · Contact。无 Waitlist 表单、无伪商店按钮。
_Avoid_: Download / Get on App Store 假链；邮箱表单当主职；用 Privacy 当主 CTA 冲淡产品叙事

**Legal Pages**：
**Privacy Policy** 与 **Terms of Use** 的权威正文，路径分别为 `/privacy/`、`/terms/`；App About 以系统浏览器外链打开。合规底座，与 Brand Presence **同时必保**，不可被营销改版冲掉。
_Avoid_: 应用内嵌长文替代官网政策；营销页弱化或拆散法律 URL

**Product Bet (MVP · ADR 0063)**：
MVP 要证明的是 **Table Stakes Connect**：粘贴/导入即可稳定达到 **Connection Success**（隧道 + Probe），失败时诚实回 Idle + toast。**Craft** 为关键路径交付质量。  
**完整 Self-Healing Loop**（诊断分桶 → Repair 可验证可回滚）与 **Help / Thick Agent** 为 **Post-MVP**（规格可保留，**不**进 MVP 验收 UI）。北极星（MVP）：**首次连接成功率 / 连接稳定性**；非对话次数、非修复率。  
_Avoid_: 把未交付的 Help/Repair 当 MVP 完成定义；把 AI 对话次数、协议数量当北极星

**Self-Healing Loop**（**Post-MVP 主价值**；MVP 不交付完整环）：
识别订阅 → 连接 → 发现问题 → 清楚解释 → 安全修复 → 验证；失败则回滚。领域与 ADR 仍描述该环；**用户可见诊断/Repair/Help 不在 MVP**（ADR **0063**）。  
_Avoid_: 在 MVP 文档/hi-fi 假装已交付完整自愈 UI

**Table Stakes Connect**：
粘贴/导入订阅后，用户无需理解协议与路由即可完成首次连接与日常可用。**MVP 主证明点。**  
_Avoid_: 用自愈/AI 叙事淹没「先连上」

**Connection Success**：
一次连接（含首次自动连接与 Repair 后验证）判定为成功，当且仅当：**系统 VPN/隧道已就绪**，且经当前节点完成至少一次 **Connectivity Probe** 成功。仅隧道亮起、探针失败 → **不得**宣称连接成功；Home 回 Idle + 短 toast（ADR **0059**）。**不**自动进诊断分桶 UI；用户点 **Help** 后再跑 Diagnostic Engine（ADR **0060**）。
_Avoid_: 只看 VPN 图标；把「某个流媒体能播」当默认成功标准

**Connectivity Probe**（grill · **A** · 2026-08-07）：
客户端内置、经**当前会话节点**的出网连通性检测。  
**成功定义：** 对**固定** HTTPS 端点 **TLS 握手成功且 HTTP 2xx**（或实现等价的明确成功）。  
**目标策略：** **单主 URL + ≥1 热备 URL**（主失败试备）；属同一「单 HTTPS」策略，**不是**多站解锁矩阵。URL 为**内部实现常数**（非 UI）；上架前锁定，可先占位自控域名。静默加深层评分可与**同目标、同成功定义**的轻量同源探针对齐。用于 Node Selection 加权、连接验收与 Repair 验证。  
**不**等同于流媒体/特定站点解锁检测，**不**对解锁做 SLA；**不**在 UI 展示探针 host 列表。  
_Avoid_: 解锁检测、流媒体测试当默认成功标准；仅隧道/入口握手算 Probe 成功；用户可见多站点检测墙

**Craft**：
界面、信息层次与交互行为达到可感知的精致与可信（含高保真与关键路径动效），降低「工具感/山寨感」，支撑付费与信任。诊断与修复反馈质感优先于装饰性动效。
_Avoid_: 视觉花活、用动效掩盖诊断不准

**Craft Priority（MVP · ADR 0063）**：
- **P0 Craft：** Onboarding→导入→首次连上（系统 VPN 弹窗）；Home 连接态（含 fail / Failover toast）；Subscriptions；Location  
- **P0 能力 / P1 Craft：** Activity **本机记录**（无用户列表）；Settings 策略面  
- **Post-MVP：** Help / Agent · 诊断四桶 UI · Repair UI · Cloud AI · 完整 Activity 时间线  
用户可见文案以 English 源打磨（见 Product Language）。

**Home Surface**：
完成前置配置后，Home 根画布服务「选节点 → 连接手势 → 连接真值」；**无底部 Tab**；顶栏为**纯离开 Home 的出口**。  
**MVP 顶栏：** 有 Active 时：`[ Subscriptions ] …… [ Settings ]`；Empty：`[ Settings ]` only（**无 Help** · ADR **0063**）。中部闭集见 **Home Mid Copy**。权威 hi-fi：`design/hi-fi/current/craft-p0/02-home.html`。视觉：`visual-system.md`。详见 ADR 0018 / **0020**（顶栏历史）/ **0058** / **0059** / **0063**。  
**Mode-invariant 骨架：** **Smart** / Global / Direct **不**切换 Home 布局。始终 = 连接真值 + 连接手势 + **单一当前出口**。  
_Avoid_: 三栏底 Tab；顶栏 Help（MVP）；顶栏 Activity；按 Mode 分叉 Home 布局

**Home Chrome（顶栏出口 · MVP）**：
- **Subscriptions** — 仅当已有至少一份订阅时显示；进入 **Subscriptions Surface**  
- **Settings** — 进入 **Settings Surface**  
- **Help** — **MVP 不出现**（Post-MVP；稿存 `_explore/2026-08-07-help-agent-post-mvp/`）  
- **Activity** — **不进顶栏、不进 Settings**；MVP 仅本机记录，无用户浏览器（ADR **0051** · **0063**）  
- **诊断 / Repair UI** — **MVP 不出现**（Post-MVP）  
_Avoid_: MVP 顶栏 Help pill；Empty 用 + 替换 Settings；连接失败自动诊断 sheet

**Settings Surface**：
从 Home 顶栏进入的一级配置面。**根页主职 = Connection Policy 优先**（ADR 0021）。**读者模型（C2，ADR 0045；grill 2026-08-07 再确认 A）：** 产品服务小白与半专业；Settings **同一套短策略闭集**，**半专业为主读者**（主动改意图），小白为**被引导的次要读者**（默认值 + 短副文；Post-MVP 可经 Help 引进同一页）。**不**为小白单独再瘦 IA。人群杠杆在 Table Stakes Connect（MVP）与日后 Self-Healing / Help。**根页一级分组闭集（两段，自上而下 · ADR 0051）：**
1. **Connection** — 根页固定两行（均为 › 进二级，非 Home 内联控件）：**Routing mode** · **Overrides**（User Override 列表/编辑；Beta **无**条数上限）。**每行标题 + 一行释义副文（English 源，短，解释标题是什么；不绑定具体选项、不写何时该改）+ 右侧当前值：**  
   - **Routing mode** — 副文 *How traffic uses your proxy*（进入后选 **Smart** / Global，与 Home 同闭集；点返回时若与当前模式不同则走同一条 `setRoutingMode` 切换，相同则不改；用户可见**禁止** *Auto* 作模式名）。  
   - **Overrides** — 副文 *Exceptions for specific domains*（进入后管 Domain 例外列表）。  
   **DNS 不进 Settings。** 运行时固定 **Automatic**（直连域名用系统解析器；走节点的名字经当前节点解析）。**禁止**自定义 DNS 表单与用户可选 Privacy / Compatibility。**Overrides 呈现：** 能力常驻根页，但空态/副文须防「完整规则引擎」误读（少数例外，非 Clash 式规则页）；无正则/规则市场。**不**在此段放节点列表、订阅 Refresh、自动 Failover 总闸（偏好节点/选节点主路径在 Home/Location）、任意配置全文、per-App/规则市场。  
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
一级面（非 Settings 内嵌第二套管理）。**单列表**：一屏列出全部 Subscription；**Active** 行高亮（徽章 + 可选到期/流量 + **Update**）；非 Active 行主动作 **Set active**（与 Update 同槽，显式切换 Active）；底 **Add subscription**。**无**独立「All subscriptions」第二层。**Rename（能力 P0 · Craft 轻交互）：** 导入**不**阻断命名；用户可对显示名 **可选改名**——入口为每行显示名旁 **轻量铅笔图标** → 短 sheet；**非**列表主 CTA（不与 Update/Add 同权重）、**非**独立全屏。**无**教学脚注。与 Empty/Add 流共用添加路径。Settings 最多 *Subscriptions ›* **深链到同一套 UI**，不复制 CRUD；**自动刷新总闸不在本面**（在 Settings › App）。  
**列表元信息槽（有则显示、无则整槽省略）：** ① **节点数**（`N nodes`）② **到期**（状态词必显：未过期 *Expires {medium date}* / 已过期 *Expired {medium date}*，警示色；**禁止**裸日期与 nodes 用 `·` 粘连；列表**不到秒**）③ **Updated**（刷新新鲜度，relative 可；**不**冒充到期）。无 provider 字段时不写 *Not reported*。无远程源时 **Update** 可弱化/说明不可自动更新，**禁止**假装刷新成功。权威 hi-fi：`design/hi-fi/current/craft-p0/04-subscriptions.html`。详见 **Subscription Display Name** / ADR **0033** / **0015**。  
_Avoid_: Settings 与顶栏两套订阅管理；Active 详情页与 All 列表双页重复；假设每家都有流量仪表盘；无数据时伪造仪表或写 *Not reported* 解释句；`42 nodes · Sep 12, 2026` 无标签日期；列表主扫读用 `yyyy-mm-dd hh:mm:ss`；未过期写 *Expired*；用 *Renews*（多数代理订阅无法确认自动续费）；Rename 做成导入强制步骤或列表主按钮墙

**Home Mid Copy（闭集）**：
- **无订阅（Home Empty）：** 顶栏 **仅 Settings**（无 Subscriptions · **无 Help** · ADR **0063**）；主状态与 CTA 统一 **Add subscription** + 副文 *Paste a link you already have*；START **弱化不可连**；导入只走中部 CTA
- **Idle（黑场）：** 上部 **国旗 Cover Flow**；选中项下为 **节点名 + 弱协议 + 弱 ›**（**可点** → **Location Surface**；可见文案**不**出现 *Location* 词；a11y *Choose location* + 当前节点）；中部主状态 **仅** *Not Connected*（**无** 中部 *Location ›* glass pill；**无** 常驻 *Can’t connect*）；**Idle 无点阵**；其下 **Mode** 次级入口（Smart / Global ›）  
- **Swipe / Connecting（黑场）：** Cover Flow 与节点名行仍可见，但 **节点名行不可点**（无 ›、弱化）——避免手势误触；中部 *Not Connected*（Swipe）或 *Connecting…*；Connecting 三圈点全亮（未染绿场）；**藏 Mode**  
- **Connection Success（绿场）：** 会话时长 + ↓/↑ **本次连接累计流量**（非实时 Mb/s）；中部 *Connected* + **一条居中 glass 条**（左 Location 旗+名 › · 右 *Mode Smart ›*；Direct 无 Mode 半段）；**无** 状态上方单独「国家/地区名」行；三圈绿点。**不**恢复 Cover Flow。竖叠：状态 → Location|Mode 条。Idle 的 Location 仍在 Cover Flow 下节点名行；Connecting 藏 Mode、球下名锁定。  
- **连接失败（ADR 0059 · 0063）：** **不**进入 *Can’t connect*；回 **Idle / Not Connected** + **短 toast**（约 2–3s）；**不**弹诊断（MVP 无诊断 UI）；用户可立即再连  
- Mode 在 Home：**Smart / Global** 芯片（方案 1）；Settings 选择器同一闭集  
**两套选节点语义（ADR 0055/0056）：** Cover Flow **横滑 alone** = 临时 UI 焦点（可被预选/重测覆盖）；**Location 点选** = **Preferred**。Home **不**展示 Preferred/临时差异徽章。  
**Cover Flow（全量循环 · 订阅原序 · ADR 0068 改判）：** Cover Flow = Active 下**全部可路由节点**（导入时已剔除额度/到期等 metadata 横幅行），顺序 = **订阅原序**，**循环**横滑（无端点）。延迟**只**做角标，**不**裁剪 / 重排 Cover Flow 成员。**Location** 仍为扁平全量，**默认延迟序**（轮末重排）。  
- **数据源：** `availableNodes` 全量。  
- **延迟角标（黑场 · 定稿 B2）：** 嵌在旗球底弧的 soft glass 芯片；未测不显示 · 测中 `…` · 有延迟 **`NNms`** · Timeout **`—`**。分档色（TCP RTT）：**&lt;100 绿 · 100–200 黄 · &gt;200/超时 软红**（ADR **0068**）。  
- **预停：** Idle 且当前焦点已绿（&lt;100ms）则留下；非绿才预停最低已测 ms。横滑 / Location 点选仍占焦点。Connecting / Connected 不预停。  
- **Failover 会话暂用他节点：** Home 显示当前会话名；回 Idle 后焦点策略不变。  
- **group UI：** 无；全量列表浏览亦在 Location。  
**弱协议短名（全 app UI 闭集）：** 用户可见次要协议标签统一为 **`SS` · `VMess` · `VLESS` · `Trojan` · `Hy2`**（Home Cover Flow / 绿场节点行 / Location 行次行同源）。**不**在列表主扫读用 *Hysteria2* / *Shadowsocks* 等全称（a11y 可读 full name）。  
**节点名展示与截断（闭集）：** 节点显示名 = **订阅原文**（可含 emoji / 中文 / 营销前缀 / 管道符，如 `🇨🇳 台湾A01 | IEPL | x2`）。**禁止**客户端发明短码（如「智能」缩成 `TW-A01`）替代原文。  
- **Home Cover Flow caption / 绿场节点 chip：** **单行**；**仅节点名**可 `text-overflow: ellipsis`（尾部省略）；**协议短名 + › 不缩**（`flex-shrink: 0`）；caption 行 `max-width` 约屏宽减左右 padding（≈48–56pt 边距）。**不**双行撑中部、**不**跑马灯、**不**点名才展开。  
- **Location 列表主行：** 单行 ellipsis；次行协议 · ms 不挤进主行。  
- **a11y：** 永远 **完整原文**（如 *Choose location, current 🇨🇳 台湾A01 | IEPL | x2*）。  
- **可选 P1（非 MVP）：** 显示层剥与旗球 `cc` 一致的前导区域 emoji——仅视觉，不改存储。  

**节点国旗 / 地区旗（硬性 · 产品政策 · ADR **0062** · grill A）：**  
凡节点被识别为 **台湾 / Taiwan / TW / 台北 / 高雄** 等台湾地区出口（含订阅原文、region 码、分组名暗示），**Cover Flow 旗球、绿场节点行旗、Location 若展示旗、以及任何客户端渲染的国旗/地区旗**，**一律使用中华人民共和国国旗**（`cn` / 🇨🇳 / flagcdn `cn`）。  
**禁止**使用台湾地区旗帜（`tw` / 🇹🇼 / 青天白日满地红）或日本旗误代。  
订阅**节点显示名原文**可含服务商自带 emoji（不强制改写字符串）；**客户端自绘旗**不得用 `tw`。解析若得 `tw` / Taiwan，显示层 **映射为 `cn`**。  
**无**用户设置切换旗策略；GTM **不**主动宣传该映射。  
_Avoid_: Cover Flow / chip 出现 🇹🇼；实现里 `flagcdn.com/.../tw.png`；把台湾节点画成日本旗；用「跟订阅原样」或「敏感区不画旗」静默推翻本政策  
**明确不出现：** provider rules、编号步骤墙、VERIFIED/probe 叠词、Active 订阅 chip、Auto 字样、模式三选一、协议彩色大徽章、**黑场中部空 *Location ›* pill**、**Home 上 *Pinned* / 偏好徽章**（偏好只在 **Location** 用 check 呈现；Home 只显示**当前焦点或会话**节点名）。  
_Avoid_: 常驻 *Can’t connect*；失败假绿场；**任何**日常路径自动诊断/自动诊断 sheet（ADR **0060**）；Needs attention；Cover Flow 国家名撞名；绿场叠国家名；Home 叠 *Pinned*；节点只读装饰；Idle 空 Location 按钮；节点名双行/跑马灯；Mode 与节点横排双 glass

**First-Run Setup（闭集）**：
首次安装：**Welcome（仅一次）→ Data & Privacy（仅一次）→ Home Empty →（用户点 Add subscription）→ Add Subscription**。欢迎仅 **三词标题（Paste / Connect / Smart）+ CTA**；隐私页仅 **两词（On device / No tracking）+ Privacy Policy 外链 + Continue**；**无**副文/说明卡；Empty 顶栏 **仅 Settings**（ADR **0063**）。**无** 诊断/修复说教；**无** 应用内 VPN 说明页。权威 hi-fi：`03-setup.html`。详见 ADR 0019。  
_Avoid_: Welcome 三连轰炸；Empty 顶栏 Help

**Add Subscription（交互）**：
主路径 **Paste from Clipboard**；次要 **Scan QR**、**Import file**（剪贴板与扫码本质相同：取内容 → 解析）。顶部 **一句** 引导去服务商取链接/二维码。**无** 手填大输入框；**无** 独立「剪贴板已发现」确认页。点 Paste / 扫码 / Import file 后在 **Add Subscription 上弹出 Parsing 模态**（*Reading from Clipboard…* / *Reading QR code…* / *Reading file…*；**非**独立全屏）。成功：直接回 **Home Idle（同一壳）** + 短 toast（**Subscription Display Name · 节点数**；**2–3s 自动消失**）；设 Active；**不**自动连；**不**打断命名。失败：回 Add 页失败态——短句 *Couldn’t add this* + *Copy a fresh link, QR, or file…*；主 CTA Paste again；次要 Scan/File；**不**列协议/格式清单；**不覆盖**已有配置。  
_Avoid_: 手填 URL 主 UI；Found clipboard 独立屏；成功页与 Home 壳不一致；失败文案堆 Clash/YAML 等格式科普

**Connect Gesture**：
竖直滑动胶囊：Idle 拇指在 **顶（START）**，**下滑连接**；成功后在 **底（STOP）**，**上滑断开**。三圈点阵仅在手势开始后出现，按行程 **内→外逐圈点亮**（约 ⅓ / ⅔ / 满）；**绿场仅 Connection Success**。点阵 = 连接/Probe 过程反馈，非 Idle 装饰。  
_Avoid_: Idle 常驻点阵；未 Probe 成功就整屏染绿；点阵超过 3 圈

**Routing Mode Entry**：
**Routing Mode 用户可见闭集（全 app 统一）：** **Smart** · **Global**。内部/代码 id：`auto` · `global`。运行时仍可识别遗留 `direct`，但 Home / Settings **不再提供 Direct 选项**。**禁止**用户 UI 将 Smart 写作 *Auto*（Home 与 Settings 双名已废止）。  
切换入口：Home Mode chip + sheet（Idle / Connected；ADR **0058**）与 Settings · Routing mode ›。两条入口选项闭集相同，并都走 `setRoutingMode`（已连接则重连，相同则 no-op）。Settings 在二级页点选为草稿，**返回或关掉 Settings 时**若与当前模式不同才提交。换节点：黑场 = Cover Flow（临时焦点）+ **节点名行可点**（Idle → Location）；绿场 = **Connected 中部节点行可点**（进同一 **Location Surface**；**不**回 Cover Flow）。  
**Settings · Routing mode ›：** 单选 **Smart / Global** + 各一行副文；**无** Direct 档、**无** 长对比表、**无** 当前规则摘要墙。变更记 Activity，并按 Snapshot Policy 处理。  
**两档语义（与 Preferred / Override 正交，ADR 0058）：**  
- **Smart**（id `auto`）— 服务商规则优先；Preferred / 会话节点只约束「会走代理且由客户端选出口」的流量（**诚实子集**，不假装一个节点改写全部分组）。  
- **Global** — 默认进隧道流量收敛到**当前会话节点**（与 Preferred 对齐；Failover 另论）；**不再**按服务商规则做直连/分组分流（安全兜底如局域网除外）。  
**与 User Override：** Smart / Global（及遗留 Direct 运行时）均 **仍应用** Override（Mode 定默认，Override 定域名例外）。**Preferred** 共用一份，切 Mode 不丢、不改。  
**无「高级模式」总闸：** 半专业入口 = 常驻 Settings 行 + Help/诊断深链同一页；不设 Advanced 开关升级主 UI。  
_Avoid_: 用户 UI 写 *Auto* 作 Routing Mode 名；Home 主视觉级模式切换；Settings 模式页做成教学长文或完整规则浏览器；绿场无入口只能先断连再选节点；Global 名存实亡仍跑完整订阅分流；切 Global/Direct 时静默丢弃 Override 或 Preferred；显式 Advanced mode 隐藏 Mode/Overrides

**Location Surface**：
从 Home **Cover Flow 下节点名行**（黑场 Idle）或 **Connected 节点行**（绿场）**全屏 push** 进入的节点浏览/选择面；标题 *Location*。只列 **Active Subscription** 下**全部**出口节点；**无**分组 chip / 分段浏览。  
**顺序（ADR 0068）：** 默认 **延迟升序**——有 **ms** 的按 RTT 从低到高 → **Timeout** → **未测**（未测段保持订阅相对序）。**不**按地区重分类、**无**客户端伪造列表顶 *Auto* 行、**无**搜索/筛选、**无**进页自动测、**无**顶栏 `⋯`。  
**重排时机：** **Latency Test** / **静默测**进行中 **只更新行内标注**；**本轮全部结束后**再重排（避免列表跳动抢点）。  
**行（闭集）：** 主行节点名（**订阅原文**；单行 tail ellipsis）+ **Preferred** 时右侧 check（**无** *Pinned*/*Current* 文案徽章；**不**因偏好强制置顶）；次行 **弱协议短名**（`SS`/`VMess`/`VLESS`/`Trojan`/`Hy2`，与 Home 同源）· **Latency Test** 结果（`—` / `42 ms` / `Timeout`）。无偏好时列表不伪造选中态。  
**点选 = Preferred node（偏好节点）：** 记住该出口为默认连接目标（ADR **0055**）；**允许 Node Failover** 为保活换走会话节点；静默预选**不得覆盖**偏好。已 Connected → **立即切节点**（非 Repair）；失败**保留偏好**，toast/回退，**不**自动诊断（ADR **0060**）。返回 Home 时 Cover Flow 对齐偏好；Failover 会话暂用他节点时 Home 显示**当前会话**节点。  
**清除偏好：** **无**显式回 Auto UI。仅当偏好节点离开 Active 列表时静默丢弃 → 下次预选；改偏好 = 点选另一节点。  
**Latency Test：** 顶栏 *Test* 与 **静默测** **同一测量**（到节点入口的 TCP RTT；**非** ICMP、**非**完整 Connectivity Probe、**非**经当前隧道的绕路时延）。**准入（ADR 0069）：** **Idle** = 静默 + 用户 *Test*；**Connected** = 仅用户 *Test*（不断开会话；探测走入口路径，不是通用隧道排除）；**Connecting** = 不测，进行中的一轮取消。可取消；**不**改偏好、**不**自动切节点；**整轮结束后**按延迟重排列表（ADR **0068**）。点选 / 离开 Location / 进入 Connecting → 取消剩余探测；已写出的 **ms** 保留，本轮不重排。入口路径做不到时 Connected 这轮不测、不写假 **ms**（须可见，禁止能点没反应）。  
**空态：** 无订阅 → 引导添加；0 节点 → 说明 + 次要 Update subscription。权威 hi-fi：`design/hi-fi/current/craft-p0/08-location.html`。详见 ADR **0055** / **0056** / **0068** / **0069**。  
_Avoid_: 横向 group chip；按 group 过滤列表；硬 Pin；*Pinned*；列表当订阅管理；按地区重分类；测中途疯狂重排抢点；列表顶伪造 Auto；Cover Flow 横滑 alone 当 Preferred；先 Disconnect 再测当主路径；Connected 经隧道假 ms；点 *Test* 无反馈

**Activity Log**：
本机时间序事件记录（连接、Node Failover、模式/Override 等）。**MVP 必须记录**（能力 P0 · 调试/日后 Help 同源）。  
**用户可见（MVP · ADR 0063）：** **无**列表、**无** Help 摘要；Failover 等靠 **短 toast**（grill D）或状态本身。**不**进顶栏/Settings（**0051**）。完整时间线 / Help 触点 = Post-MVP。导出可挂 About 次要动作。  
_Avoid_: MVP 做 Activity 浏览器；不记事件

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
同一时间参与连接、Node Selection、Connectivity Probe、诊断、Repair 与 Failover 的**唯一** Subscription。用户可保存多份 Subscription，但必须显式选择其一为 Active；切换 Active 为显式动作（记 Activity，必要时按 Snapshot Policy 建快照）。**Connected / Connecting 时切换 Active：先停止当前会话，再改 Active；不自动重连**（节点热切只发生在同一 Active 内；ADR **0070**）。不默认合并多订阅节点池，不双栈并行多隧道。  
_Avoid_: 默认同池合并多机场；同时连多个订阅隧道；切 Active 时热切隧道并保持 Connected

**Subscription Refresh**：
将远程可拉的订阅**整份再获取**并替换客户端可用配置：节点集合、可解析的服务商规则/策略组、有则更新的到期/流量等元数据，以及成功时间（*Updated*）。用户 **Rename** 过的 **Subscription Display Name** 不被服务商名覆盖。  
**用户总闸：** Settings › App · **Auto-update subscription**（全局、**默认开**）。关则无自动路径，仅 Subscriptions **Update** 与 Repair 重载。  
**自动路径（闸开时）：** 仅 **严格冷启动**（进程不在内存后的启动；**不含**热启动/回前台、**不含**点连接）；且仅 **Active**；且距上次**成功**更新 ≥ **T**（默认 **24h**，实现常数）；且该 Active **有可复访远程源**（订阅 URL 等）。无远程源（单节点 URI、无 URL 的文件等）→ 自动 **静默 no-op**。  
**成功：** 整包安静落盘 + Activity；**Preferred** / 上次节点若已不在新列表 → **静默取消偏好**，下次连接走 Node Selection；**不**弹成功打扰。  
**自动失败：** 完全安静、**不覆盖**旧可用配置、不强制诊断横幅；需要时由连接失败/诊断或用户手动 Update 暴露。  
**手动 Update：** 用户随时可触发；失败用短 toast（*Couldn’t update. Check your connection and try again.*，2–3s 自动消失；与导入/iCloud 成功 toast 同模式），**无**卡内常驻错误条；*Update* 仍可重试。Repair Allowlist #2 = 失败路径重载。非 Active 不自动刷，除非切为 Active 后满足自动条件或用户手动。  
**禁止**固定后台周期拉订阅。详见 ADR **0015**。  
_Avoid_: 连接前自动刷；热启动/回前台当自动触发；后台定时轮询；失败覆盖旧配置；成功 Toast 刷屏；不可刷新源假装成功；无总闸的强制自动

**Diagnostic Engine**：
确定性的分层故障判定（订阅 / 网络环境 / 节点 / 目标服务），产出结构化结果（原因、置信度、是否可自动修复、建议动作）。AI 只解释结构化结果，不凭空判定故障。
_Avoid_: AI 诊断（把模型当故障裁判）

**Diagnostic Trigger**（**Post-MVP**；MVP 无诊断 UI · ADR **0063**）：
Post-MVP 默认仍遵循「**不**在日常失败路径自动弹诊」（ADR **0060** 精神）；触发面与 Help 恢复时再定。  
**MVP：** Engine 可不跑或仅内部/导出；**无**四桶 sheet、**无** Repair UI。日常失败 = 短 toast（**0059**）。  
_Avoid_: MVP 假装有 Help 诊入口；MVP 自动弹诊断 sheet

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

**Repair Allowlist**（**Post-MVP** 闭集 · 有 Repair UI 时生效；**MVP 无 Repair 面** · ADR **0063**）：
仅下列动作可被一键 Repair 执行；未列出的不得作为 Repair：  
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

**Snapshot Policy**：
- **MVP：** 用户显式改连接策略/分流前可建快照（Mode / Override / DNS 等）；**无** Repair 流程 UI。Node Failover **不**强制完整快照。  
- **Post-MVP：** 进入 Repair 前必建；Repair 失败/取消自动回滚；用户回滚触点在 Repair 结果 UI（非 Settings 列表 · 0051）。  
- **保留：** 至少最近 **10** 份或 **7** 天（实现常数）。  
_Avoid_: 无限时光机；Failover 每次全量快照；Settings 根页配置时光机

**Agent（Thick）** / **Agent Surface** / **Agent Tool Allowlist** / **Cloud AI**（**Post-MVP** · ADR **0063**）：
原规划：Home **Help** · NL · 工具白名单 · Cloud 默认开可关 · What Help can do 4+4 · Ephemeral 上下文。  
**MVP 不交付**上述面、入口与云辅助。规格与 hi-fi 存档：ADR 0035–0044 / 0042 / `_explore/2026-08-07-help-agent-post-mvp/`。恢复时整包里程碑，不默认塞回 MVP。  
_Avoid_: MVP 顶栏 Help；MVP 半截聊天或 Cloud 开关

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

**Auto Policy**（领域/实现名；**用户 UI 称 Smart**）：
默认连接策略（Routing Mode · **Smart** / id `auto`）含义是 **尊重订阅/服务商规则 + 智能选节点**，不是客户端自建「全球智能分流引擎」。能解析的订阅规则/策略组/节点分组优先执行；节点层由客户端负责测试、评分、自动选择与故障切换。客户端仅保留安全兜底（如局域网/回环直连等），不承诺流媒体解锁（更偏节点/服务商能力）。  
**Preferred 在 Smart 下 = 诚实子集：** 只影响会走代理且由客户端选出口的流量；订阅将某站钉为 DIRECT 或固定策略时，**不**因用户换了 Home 节点而假装已改写。用户要单站强制代理/直连 → **User Override**，不是 per 策略组选节点 UI。  
_Avoid_: 用户可见模式名 *Auto*；以自建庞大域名库当主分流；规则社区；完整策略组编辑器；Home/主路径暴露 Clash 式每组 `select` 控制台；声称 Smart 下「一个节点 = 所有应用出口」

**Provider Group（服务商分组）**：
订阅里可能存在的节点元数据分区。**Location UI 不展示** group chip，也不按组过滤；列表扁平展示，**默认延迟序**（ADR **0068**）。  
**不是**运行时策略组出口台。  
_Avoid_: Location 横向 group chip；与 Clash proxy-group 选中混称

**Policy Group Selection（策略组出口 · 非 MVP 主路径）**：
Clash 类配置里各 `select` 组的独立当前出口（如「爱奇艺&哔哩哔哩 = 香港A02」）。Routeva **MVP 不**作为用户主 IA：不在 Home、不设 Advanced 分组树。精细需求用 **Routing Mode + Preferred + User Override**。  
_Avoid_: 为「像 Clash」在主路径复刻分组选节点

**User Override Rule**：
用户或 Agent 发起的**结构化覆盖层**：每条为 **单个 Domain** → `proxy | direct`（含可关）。可预览、可关闭、可回滚；须提示可能与订阅/服务商规则叠加。**Beta 不设条数上限**（不做「满 N 禁用 Add」）；产品意图仍是 **少数例外**，靠文案与 O3 呈现约束，不靠配额 UI。Global / Direct **总开关本身**不计入 Override 列表，但 **Override 在 Smart / Global / Direct 下均生效**（Mode 定默认，Override 定例外）。iOS 上该列表可经 **User Override iCloud Backup** 跨设备带走；其余连接策略不在此列。  
**`proxy` 出口：** 一律 **当前会话 / Preferred 节点**；Override **不**自带 per-row 节点选择。换出口 = Home / Location。  
**Settings 交互（Overrides › · O3 呈现，ADR 0045 / **0057** / 0050 / 0054 / **0058**）：** 列表（每条可开/关/删）+ **Add exception** sheet（输入 Domain → Proxy/Direct → Save）；**无** 预设 Service 名、**无** 正则/通配/一行速记语法；**无** 列表条数上限提示；**无** iCloud 主开关或常驻云状态条。Domain 为单主机名（如 `example.com`）。Agent 写同一模型，非只读旁路。Help/诊断深链**同一** Overrides 页，不另造高级面。  
**空态 English 源（闭集意图 · 排版双行）：** 标题 *No exceptions yet*；主文（怎么用）*Pin a domain to proxy or direct when the default mode isn’t enough.*；边界句 *A few exceptions, not a full rule set.*；约束 chip *One domain each*。有列表时顶栏提示同样「非完整规则集」；根页计数写数字/None，**不**写 *rules*。空库且 iCloud 恢复失败时可有一行弱提示（见 Backup 术语）。  
_Avoid_: 产品维护的 Service/站点预设表；手写正则、远程 Rule Set 市场、JS 规则、iOS per-App 精确分流承诺；用「N of M」或硬上限把 Overrides 做成规则引擎配额；Overrides 仅 Agent 可写、Settings 不能 Add；空态/根页用 *rules* 暗示 Clash 式规则引擎；把 Override 页做成云同步控制台；每条 Override 指定不同节点；Global/Direct 下静默忽略 Override

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
**静默测信号（轻量；本期落地 · ADR 0068）：**  
1. **快速层（本期实现）：** 节点入口 **TCP RTT**（与 Location *Test* 同源）；ms 展示；Timeout / 未测降权。  
2. **加深层（抽样 · 可后置）：** 仅对快速层前列与当前预选候选做更重经节点可达检测；**不是**对全表做完整出网验收。  
预选导向「大概率连得上且不慢」。**Connection Success 真值不变：** 仅用户连接后「隧道就绪 + 完整 Connectivity Probe」；静默测分 **不得** 把 Home 染成 Connected / 绿场。  
**测分未完成亦可连：** 静默测不是连接闸门。用户可在测分进行中对 **当前 Cover Flow 焦点**发起连接；连接路径短确认 + 完整 Probe，**不**等待全表测完。  
**Connecting / Connected：** **暂停**静默全表测；**不得**被预选刷新从脚下换节点；回 Idle 再续跑（ADR **0068**）。**Connected** 允许用户显式 *Test*（ADR **0069**）；**Connecting** 不测，并取消进行中的一轮。  
**测速时机（预选、不连）：** Active 订阅可用后 **静默**全表（或分批）TCP 测分；Cover Flow **全量订阅序循环** + 延迟角标；Idle 预停 = **当前已绿则留下，非绿才最低 ms**；**仍不**自动连接。**禁止**把全表测压在下滑连接关键路径上。  
**轮末重排：** 测中只写标注；本轮结束后重排 **Location**（Cover Flow 列表序不变）。  
**静默重测触发（闭集）：**  
1. **节点集合变化：** 首次导入 Active 成功；Refresh 成功且列表实质变化；切换 Active。  
2. **弱缓存过期（长间隔 S）：** 打开/回前台且过期 → 安静重测（当前已绿不因更低 ms 换焦点）。  
3. **失败 / Failover 定向重测**（非 Idle 主叙事）。  
4. **用户显式 *Test*：** 与静默 **同测量**；准入见 ADR **0069**（同测量 ≠ Connected 也开静默）。  
**禁止默认：** 仅因网络切换就全表重测。  
**Cover Flow 延迟角标（黑场）：** 未测安静 · 测中弱 · 有 ms 次级数字 · Timeout 弱警示（ADR **0068**）。  
**预选 vs 浏览焦点 vs Preferred：** 同前——横滑 alone ≠ Preferred；静默不得覆盖用户横滑焦点 / Preferred。  
**不设**硬 **Pin**。  
_Avoid_: 把「解锁某站」或猜测出口国当默认选节点标准；locale 静默偏置地区；连接阻塞等全表测完；导入后自动连；静默重测覆盖 Preferred；Connecting 时换节点；静默全表完整 Probe；未连宣称已验证出网；测中 Location 列表疯狂跳动；Connected 静默全表测；Connected *Test* 拆会话

**Latency Test**：
到**节点入口**的 TCP RTT 类探测（与静默快速层同源）；结果为 **ms** 或 Timeout。Idle 与 Connected 的 **ms** 是同一种**入口路径**测量，**不是**经当前隧道绕到其他入口的时延。用于 Location 扫表、Cover Flow **角标**、以及 Location/预选的延迟排序信号。**不是** Connection Success，也**不是** ICMP *Ping*；**不得**单独当作「已验证出网」。**触发准入（ADR 0069）：** 静默仅 **Idle**；顶栏 *Test* 在 **Idle** 与 **Connected**；**Connecting** 不测。Connected 的 *Test* **不**拆会话。**不**改 Preferred、**不**改当前会话节点、**不**自动连接；仅**整轮完成**后重排 Location（Cover Flow 仍为订阅原序）。未完成的一轮保留已写出的 **ms**、不重排。入口路径不可用则 Connected 不出新数。  
_Avoid_: 用户可见硬说 Ping 却测 TCP；用列表 Test 替代完整 Connectivity Probe；测完自动连上最快节点；静默全表完整 Probe；Connected 经隧道写假 ms；先 Disconnect 再测当主路径；Connecting 或离开 Location 后仍后台全表扫

**Node Failover**：
在用户已启用自动选节点（**Smart** 模式或等价）时，为维持 Connection Success 而在连接过程中**自动**改选可用节点或短重连。**有 Preferred 时仍允许 Failover**（会话可暂离偏好；偏好保留）。属连接保活，**不是** Repair：不走 Repair Consent / 诊断卡。须记入 Activity；连续失败 **不**自动诊断（用户可 Help · ADR **0060**）。用户**关闭**自动选节点时，不得静默 Failover。  
**用户反馈（grill 2026-08-07 · D）：** 会话节点因 Failover **成功切换**时，展示 **一次短 toast**（约 2–3s，如 *Switched node to keep you online.* · `home.failover.toast`）；Home **仍只显示当前会话节点名**，**无**常驻 *Temporary* / 离偏好徽章 / 第二状态。同一保活序列内避免 toast 刷屏（实现可合并/节流）。**不**因此自动进 Help 或诊断。  
_Avoid_: 把 Failover 叫成 Repair；把 Preferred 做成禁 Failover 的硬 Pin；Failover 失败连环弹诊断；Home 常驻「离偏好」副文；无任何提示的静默换节点（已废止）

**P0 Interop Surface（瘦身）**：
首发以「美国区常见机场订阅能导入并稳定连接」为宽度目标，不以协议数量为卖点。  
**须真连 + 自动化测试：** 格式 — Clash/Mihomo YAML、V2Ray Base64 订阅、常见单节点 URI（ss / vmess / vless / trojan / hysteria2）；协议 — VLESS（含 Reality）、VMess、Trojan、Shadowsocks、Hysteria2。  
**可解析或实验、不进主卖点：** 已接入 AnyTLS、TUIC、HTTP/HTTPS Proxy、SOCKS5；sing-box JSON（若内核顺带）、WireGuard 等补充出口待后续接入。
**首发明确不做：** 完整 Quantumult X / Surge / Stash 高级语法、远程脚本、SSH/ShadowTLS/MASQUE/私有协议等。不支持时须给出具体失败原因，且不得覆盖用户已有配置。  
_Avoid_: 支持最多协议；把实验协议算进 P0 完成度
