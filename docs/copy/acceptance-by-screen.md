# App UI 文案 · 按屏验收表

对照 **craft-p0 hi-fi 帧** 与 [`en.yaml`](./en.yaml) keys，用于设计收口 / 实现前走查 / 伪本地化前冻结检查。

| 权威 | 路径 |
|---|---|
| 键值源 | [`en.yaml`](./en.yaml) |
| 治理 | [`README.md`](./README.md) · ADR **0053** |
| hi-fi 索引 | [`design/hi-fi/current/craft-p0/_index.md`](../../design/hi-fi/current/craft-p0/_index.md) |

**用法**

1. 打开对应 HTML 故事板帧。  
2. 核对画面可见文案 = 下列 key 的 `en`（`lock-en` 须与 CONTEXT/ADR 一致）。  
3. 勾选 `[ ]` → `[x]`；缺 key 先补 `en.yaml` 再实现。  
4. 样例句（`*.example.*`）只验「该场景演示句」存在且 tier 正确，不要求覆盖所有失败变体。

**图例：** `S` = shell · `L` = lock-en · 共用 chrome 见文末。

---

## 1 · Home · [`02-home.html`](../../design/hi-fi/current/craft-p0/02-home.html)

> **唯一权威**（已合并 ADR **0058** mode-invariant + **0059** fail toast；`02-home-new` 已删除）。  
> 含：demo / interactive · 连接序列 1–5 · Mode 行 A · Edges 行 C。

| 帧 | 验收焦点 | Keys | ☑ |
|---|---|---|---|
| **1 Idle** | Cover Flow 节点名+› 可点 · 中部 *Not Connected* + **Smart ›** · START · 顶栏 · **无**中部 Location pill · **长名 ellipsis** | `home.idle.status` S · `home.mode.chip.auto` S · `.a11y.auto` S · `home.location.a11y` S（`{node}` **全量**）· `home.gesture.start` S · `home.gesture.swipe_label` S · `home.gesture.connect_hint` S · `home.chrome.subscriptions` S · `home.chrome.settings` S · **无** `home.chrome.help`（MVP · 0063） | [x] |
| **2 Swipe ~⅓** | 仍 Idle 状态；节点名**锁定**；**无** Mode chip；SWIPE | 同上（无 location a11y 可点）+ `home.gesture.swipe_label` | [x] |
| **3 Swipe ~⅔** | 同上 | 同上 | [x] |
| **4 Connecting** | Connecting… · 节点名锁定 · **无** Mode chip | `home.connecting.status` S · `home.gesture.a11y.connecting` S · 胶囊下 hint 亦为 *Connecting…* | [x] |
| **5 Connected** | Connected · STOP · Mb/s · **竖叠** 节点 glass → Mode · **无**国家名行 · 禁横排双 pill | `home.connected.status` S · `home.mode.chip.auto` S · `home.gesture.stop` S · `home.gesture.disconnect_hint` S · `home.gesture.a11y.disconnect` S · `home.speed.unit_mbs` S · `home.location.a11y` S | [x] |
| **A2 Global Idle** | 同骨架 · 文案 *Global ›* | `home.mode.chip.global` S · `.a11y.global` S | [ ] |
| **A3–A4 Mode sheet** | 标题 *Mode* · Smart/Global · 勾选 · 脚注 | `home.mode.sheet.*` S | [ ] |
| **A5 Connected Global** | 节点 → *Global ›* | chip global + `home.connected.*` | [ ] |
| **C1 Connect failed** | Idle + *Couldn’t connect. Try again.* toast · **无** *Can’t connect* 中部 | `home.idle.status` S · `home.connect.failed.toast` S | [ ] |
| **Failover toast** | 成功换节点一次 toast · **无**常驻离偏好 · 仍显示会话节点名 | `home.failover.toast` S | [ ] |
| **C2 Global mode sheet** | 绿场 + Mode sheet | sheet + `home.connected.*` | [ ] |
| **C3 Empty** | 无订阅 · **无** Mode chip · **无** Help | `home.empty.cta` S · `home.empty.subtitle` S · 顶栏仅 Settings | [x] |
| **Interactive / Demo** | 手势 a11y；Idle/Connected 显 Mode | `home.gesture.a11y.connect` S · disconnect · connecting | [x] |

**不应出现：** 常驻 *Can’t connect* · 顶栏 **Help**（MVP · 0063）· 自动诊断 sheet · 策略组树 · Mode/节点横排双 glass。

**走查附注（Home）**

| 项 | 结论 |
|---|---|
| 主故事板 1–5 + Mode/Fail | **单文件** `02-home.html`；0058/0059 已并入 |
| 顶栏 Subscriptions / Settings | hi-fi 为 **图标 + aria-label**；**无** Help pill（0063） |
| Fail / Empty / Mode | 帧 C1 fail toast · C3 Empty · 行 A Mode 均在同一 HTML |
| 禁止项 | 未见 provider rules 墙 / VERIFIED / *Needs attention* / 顶栏 Activity / 策略组树 |

**不应出现：** provider rules 教学墙 · VERIFIED/probe 叠词 · 主状态 *Needs attention* · 顶栏 Activity · Home 上 *Pinned* / 偏好徽章（偏好仅 Location check）· 黑场中部空 *Location ›* pill · 绿场 Cover Flow（进 Location = 绿场中部可点节点行 / 黑场 Cover Flow 下节点名行）· **台湾节点出现 🇹🇼 / tw 旗**（须 PRC / cn）。

---

## 1b · Location · [`08-location.html`](../../design/hi-fi/current/craft-p0/08-location.html)

> ADR **0055** / **0056** · **Preferred node** · **Latency Test**  
> **扁平列表：** 全部节点 · **订阅原序** · **无** group chip

| 帧 | 验收焦点 | Keys | ☑ |
|---|---|---|---|
| **Interactive** | 全量列表 · 点选 Preferred · Test | `location.title` S · `location.test` S · `location.testing` S · `location.latency.*` S | [ ] |
| **1 Preferred** | 行 check · 列表含全部节点 | 仅偏好行 check · 无 *Pinned*/*Current* | [ ] |
| **2 After Test** | ms 标注 · **顺序不变** | `location.latency.*` | [ ] |
| **3 Testing…** | 顶栏 busy | `location.testing` | [ ] |
| **4 Testing** | 顶栏 busy | `location.testing` S | [ ] |
| **5 Empty** | 0 节点 · 无 strip | `location.empty.title` S · `.body` S · `.update` S | [ ] |

**不应出现：** 横向 group chip · 按组过滤 · 搜索框 · 列表顶伪造 *Auto* · *Pinned* / *Current* · 顶栏 `⋯` · 按延迟/地区重排 · 硬 *Ping* · 订阅 CRUD 主路径 · 协议全称 *Hysteria2*/*Shadowsocks*（短名 **Hy2**/**SS**）。  
**Demo 约定：** craft-p0 示例组名避免用 *Auto*，降低误读（政策仍允许真实订阅）。

---

## 2 · Setup · [`03-setup.html`](../../design/hi-fi/current/craft-p0/03-setup.html)

> **走查 2026-08-06：** Welcome → Empty → Add → Parsing 4/4b/4c → fail → toast。结果 **pass（附注）**。

| 帧 | 验收焦点 | Keys | ☑ |
|---|---|---|---|
| **1 Welcome** | 三词标题 Paste / Connect / Smart · CTA · **无**副文 · **无**左上品牌字 | `setup.welcome.word_paste` S · `setup.welcome.word_connect` S · `setup.welcome.word_smart` S · `setup.welcome.cta` S（`setup.welcome.brand` 不上屏） | [ ] |
| **1b Data & Privacy** | 两词 On device / No tracking · Privacy Policy 外链 · Continue · **无**说明卡 | `setup.privacy.word_on_device` S · `setup.privacy.word_no_tracking` S · `setup.privacy.policy` S · `setup.privacy.cta` S | [ ] |
| **2 Home Empty** | 与 Home Empty 同源 | `home.empty.*` · `home.chrome.settings` · **无** Help | [x] |
| **3 Add subscription** | 引导（含 file）· Paste / QR / File · no-sell 脚 | `setup.add.title` S · `setup.add.lead` S · `setup.add.paste` S · `setup.add.scan_qr` S · `setup.add.import_file` S · `setup.add.footer_no_sell` **L** | [x] |
| **4 Parsing** | 模态（clipboard / QR / file） | `setup.add.parsing.clipboard` S · `setup.add.parsing.qr` S · `setup.add.parsing.file` S（*Reading file…*） | [x] |
| **5 Couldn’t add** | 失败态（body 含 file） | `setup.add.fail.title` S · `setup.add.fail.body` S · `setup.add.fail.footer` **L** · `setup.add.paste_again` S | [x] |
| **6 Success toast** | 导入成功 | `setup.add.success_title` S · `setup.add.success_toast` S (`{displayName}` · `{count}`) | [x] |

**走查附注（Setup）**

| 项 | 结论 |
|---|---|
| Welcome 标题 | 仅三词 *Paste / Connect / Smart*（2026-08-13 A Stack）；**无**副文；**不**拼 no-sell；no-sell 仅 `setup.add.footer_no_sell` |
| Data & Privacy | 仅两词 *On device / No tracking* + *Privacy Policy* 外链（2026-08-13 A Stack）；**无**说明卡；iCloud 例外只在政策页 |
| Parsing 4c | *Reading file…* 已挂 |
| Success toast | 演示实例 *Apex Transit · 42 nodes* 符合 `setup.add.success_toast` 模板 |
| 禁止项 | 无 1·2·3 · 无 VPN 说明页 · 失败无协议格式清单 |

**不应出现：** 欢迎页 1·2·3 列表 · 自建 VPN 说明页 · 失败文案堆协议格式清单。

---

## 3 · Subscriptions · [`04-subscriptions.html`](../../design/hi-fi/current/craft-p0/04-subscriptions.html)

> **走查 2026-08-06：** 1–1e · 1f Rename · 2 深链。**文案/hi-fi pass**；1d/1e **实现**仍 open。Rename 入口：**铅笔图标**（非 long-press-only）。

| 帧 | 验收焦点 | Keys | ☑ |
|---|---|---|---|
| **1 List · Active rich** | 标题 · **铅笔 Rename** · Active · meta · Update · Add | `subs.title` S · `subs.active.badge` S · `subs.meta.nodes` S · `subs.meta.expires` S · `subs.meta.updated` S · `subs.update` S · `subs.add` S · `subs.data_label` S（有流量时）· `subs.rename` S（a11y） | [x] |
| **1b List · sparse** | 无到期/流量整槽省略 · 铅笔仍在 | 同上；**不**出现 *Not reported* | [x] |
| **1c Updating** | busy · 铅笔仍在 | `subs.updating` S | [x] |
| **1d Not remote-refreshable** | 无 URL 的 Active：无主 Update CTA；说明 · 铅笔仍在 | `subs.update.unavailable` S（*Can’t update automatically*）· `subs.update.unavailable.hint` S；**不**出现可点 *Update* 假装成功 | [x] hi-fi · **实现** [IMPL-SUB-1d](../prd/features/subscription-refresh-ui-states.md#impl-sub-1d--not-remote-refreshable无远程源) |
| **1e Manual Update failed** | 短 toast 2–3s（仅手动）· 无卡内错误条 · 铅笔仍在 | `subs.update.failed` S · `subs.update` S 可重试 | [x] hi-fi · **实现** [IMPL-SUB-1e](../prd/features/subscription-refresh-ui-states.md#impl-sub-1e--manual-update-failed仅手动失败) |
| **非 Active 行** | Set active · 铅笔 | `subs.set_active` S | [x] |
| **Expired** | 警示标签 | `subs.meta.expired` S | [x] |
| **1f Rename / 默认名** | 铅笔 → 短 sheet；非主 CTA；无 long-press-only / 无教学脚注 | `subs.rename` S · `subs.rename.hint` S · `chrome.cancel` S · `chrome.save` S · `subs.default_name` S · `subs.default_name_n` S | [x] 1 + 1f |
| **2 Settings deep link** | 同一套 UI 标题；App 含 Auto-update | `subs.title`（门：`settings.app.subscriptions`）；深链示意应含 `settings.app.auto_update.*` | [x] |

**不应出现：** 裸日期贴 nodes · *Renews* · All subscriptions 第二层 · 自动刷新失败 Toast · 手动失败卡内错误条 · 无远程源却 *Update* 成功 · Rename 仅靠 long-press 无可见入口 · 列表主按钮墙级 Rename。

**实现任务（1d / 1e）：** 编码 DoD 见  
[`docs/prd/features/subscription-refresh-ui-states.md`](../prd/features/subscription-refresh-ui-states.md)。  
hi-fi 文案已对齐；**产品代码实现**另勾。

---

## 4 · Settings · [`05-settings.html`](../../design/hi-fi/current/craft-p0/05-settings.html)

> **走查 2026-08-06：** Root · Mode · DNS · Overrides 空/列表/Add · About（含 MT）。结果 **pass（附注）**。DNS 行已撤；运行时固定 Automatic。

| 帧 | 验收焦点 | Keys | ☑ |
|---|---|---|---|
| **1 Root** | 段 · Connection 两行+副文 · App 三行（Auto-update Toggle 默认开 · Subscriptions · About）· Close | `settings.title` S · `settings.section.connection` S · `settings.section.app` S · `settings.routing.title`+`.subtitle` S · `settings.overrides.title`+`.subtitle` S · `settings.app.auto_update.title`+`.subtitle` S · `settings.app.subscriptions` S · `settings.app.about` S · `chrome.close` S · 计数 `chrome.none` / 数字 | [x] |
| **2 Routing mode** | Smart / Global；返回时若变更则切换 | `settings.routing.{auto,global}.{title,sub}` S · `chrome.back` S | [x] |
| **4 Overrides empty** | O3 空态 | `settings.overrides.empty.title` S · `.howto` S · `.boundary` **L** · `.chip` S · `settings.overrides.add` S | [x] |
| **4d iCloud restore fail** | 空库恢复失败弱提示（iOS） | `settings.overrides.icloud.restore_failed` S · 帧 **4d** 空态弱行；非常驻云状态 | [x] |
| **4e iCloud restore ok** | 成功恢复 toast（iOS） | `settings.overrides.icloud.restored_one` S · `restored_other` S（`{count}`）· 帧 **4e** 短 toast | [x] |
| **4b Overrides list** | 列表 · 动作标签 | `settings.overrides.list.hint` **L** · `settings.overrides.action.proxy` S · `.direct` S · `chrome.remove` S · `settings.overrides.add` S | [x] |
| **4c Add exception** | sheet 全套 | `settings.overrides.field.domain` S · `.domain_placeholder` S · `.domain_hint` S · `.domain_error` S · `.constraint` S · `.domain_error_format` S · `.action` S · `settings.overrides.action.proxy_option` S · `.direct` S · `settings.overrides.consequence.{proxy,direct,proxy_compact,direct_compact}` S · `settings.overrides.save` S · `chrome.cancel` S | [x] |
| **5 About** | 承诺 · iCloud 披露 · Links · **MT 次要行** · Export | `settings.about.title` S · `settings.about.privacy_promise` **L** · `settings.about.icloud_exceptions` **L**（iOS；Android 省略） · `settings.about.links` S · `settings.about.privacy_policy`+`.sub` S · `settings.about.terms`+`.sub` S · `settings.about.support` S · `settings.about.mt_disclosure` **L** · `settings.about.export_report` S | [x] |

**走查附注（Settings）**

| 项 | 结论 |
|---|---|
| Root | Connection 三行释义副文 + App 含 Auto-update · **无** History |
| About | MT 行 *Some interface text may be machine-translated…* 在 Links 与 Export 之间 |
| iCloud restore | **4d** 空库失败弱行 · **4e** 成功 toast（演示 *Restored 2 exceptions*）；无常驻 *Backed up with iCloud* |
| 禁止项 | 无 History/Appearance/根页 Cloud / 规则引擎暗示 |

**不应出现：** History/Activity/Snapshots 根行 · Appearance · 根页 Cloud AI · *rules* 暗示规则引擎 · Overrides 常驻 *Backed up with iCloud* 状态条 · Settings iCloud 开关。

---

## 5 · Help · **Post-MVP** · [`_explore/.../06-agent.html`](../../design/hi-fi/_explore/2026-08-07-help-agent-post-mvp/06-agent.html)

> **ADR 0063：** 非 MVP 验收。键可保留于 en.yaml 供日后。

> **走查 2026-08-06：** 空态双态 · Chat · Cloud off · Bounds · How we use data。结果 **pass**。

| 帧 | 验收焦点 | Keys | ☑ |
|---|---|---|---|
| **0a/0b Home pill** | 用户标签 Help | `home.chrome.help` S（= `help.title` 语义） | [x] |
| **1a Empty · down** | 故障空态 | `help.title` S · `help.empty.down.headline` S · `.sub` S · chips: `help.chip.why_cant_connect` · `provider_or_app` · `switch_dns` S · `help.bounds.link` S · 信任条 on：`help.trust.eyebrow.cloud_on` **L** · `help.trust.cloud_on` **L** · `help.input.placeholder` S | [x] |
| **1b Empty · up** | 已连空态 | `help.empty.up.headline` S · `.sub` S · chips: `why_slow` · `try_global` · `switch_dns` · `what_can_help` S | [x] |
| **2 Chat + tool** | 过程卡 · 同意修 | `help.process.what_we_found` **L** · `help.process.same_checks` **L** · `diag.bucket.app_can_fix` **L** · `diag.confidence.high` **L** · `diag.cta.repair` **L** · `diag.example.fix.why` **L**（chat 气泡复用） · `help.chat.example.next` **L**（样例） · `help.bounds.link` S | [x] |
| **3 Cloud off strip** | opt-out 后 | `help.trust.eyebrow.cloud_off` **L** · `help.trust.cloud_off` **L** | [x] |
| **4 What Help can do** | 4+4 | `help.bounds.can_heading` **L** · `cant_heading` **L** · `help.bounds.can.1–4` **L** · `help.bounds.cant.1–4` **L** | [x] |
| **5 How we use data** | 四段 + 开关 | `help.trust.how_we_use_data` **L** · `help.privacy.default_on.{title,body}` **L** · `what_we_may_send.{title,body}` **L** · `not_kept.{title,body}` **L** · `no_files.{title,body}` **L** · `help.cloud_assist.title` S · `.sub` **L** · `chrome.back` S | [x] |
| **Composer a11y** | | `help.input.a11y` S · `chrome.send` S | [x] |

**不应出现：** 空态 *Try a safe repair* 捷径 chip · 用户主标签 *Agent* · 内部名 Diagnostic Engine / Client-Fixable。

---

## 6 · Diagnostic + Repair · **Post-MVP** · [`_explore/.../07-diagnostic.html`](../../design/hi-fi/_explore/2026-08-07-help-agent-post-mvp/07-diagnostic.html)

> **ADR 0063：** 非 MVP 验收。

> **触发 ADR 0060：** 仅 **Help / Agent** 路径展示；**不**在连接失败时自动弹出。  
> **走查 2026-08-06：** CASES 四桶 + RepairProgress + 壳字段。**2026-08-06 续：** 补帧 **6 Success · 7 Rolled back**。

| 帧 | 验收焦点 | Keys | ☑ |
|---|---|---|---|
| **壳（各桶共用）** | 眉题 · 标题 · 段标 · 次要 · **非** Home 失败自动层 | `diag.sheet.eyebrow` **L** · `diag.sheet.title` S · `diag.section.{why,impact,next}` **L** · `diag.meta.confidence_line` **L** · `diag.cta.ask_help` S | [x] |
| **1 App can fix** | 桶 · 同意修 · Not now | `diag.bucket.app_can_fix` **L** · `diag.confidence.high` **L** · `diag.example.fix.{why,impact,next}` **L** · `diag.cta.repair` **L** · `diag.cta.not_now` S · `diag.cta.ask_help` S | [x] |
| **2 Provider** | 无假修 | `diag.bucket.provider` **L** · `diag.example.provider.*` **L** · `diag.cta.got_it` S · `diag.cta.ask_help` S · **无** Repair CTA | [x] |
| **3 Your network** | | `diag.bucket.your_network` **L** · `diag.confidence.medium` **L** · `diag.example.network.*` **L** · `diag.cta.try_again` S · `diag.cta.not_now` S · `diag.cta.ask_help` S | [x] |
| **4 Not sure** | 主 CTA = Ask Help | `diag.bucket.not_sure` **L** · `diag.confidence.low` **L** · `diag.example.unsure.*` **L** · `diag.cta.ask_help` S（主） · **无** 编造修复 | [x] |
| **5 Repairing** | 进度卡 | `repair.progress.title` **L** · `repair.progress.step_example` **L**（样例步） · `repair.cancel` S | [x] |
| **6 Success** | 绿场 + 结果卡 | `repair.success.title` S · `repair.success.body` **L** · `repair.success.cta` S（Done）· Home 绿场 *Connected* 可与 `home.connected.status` 同源 | [x] |
| **7 Rolled back** | 黑场 + 恢复卡 | `repair.rolled_back.title` **L** · `repair.rolled_back.body` **L** · `repair.rolled_back.cta` S · 次要 `diag.cta.ask_help` S | [x] |

**走查附注（Diagnostic）**

| 项 | 结论 |
|---|---|
| 四桶 badge / confidence / why / impact / next / primary | 与 `diag.example.*` / `diag.bucket.*` / CTA **逐字一致** |
| 壳 | *What we found* · *Can't connect* · Why/Impact/Next · `{confidence} · Same checks as the rest of the app` 合成行匹配 `diag.meta.confidence_line` |
| CTA 矩阵 | fix→Repair+Ask Help+Not now；provider→Got it+Ask Help（**无** Repair）；network→Try again+Not now+Ask Help；unsure→**主** Ask Help |
| Repairing | *Repairing…* · 样例步 · Cancel 一致 |
| 结果态 | **6** 绿场 + *Repair verified. You’re connected again.* + Done；**7** *Rolled back* + 恢复 body + Done + Ask Help |
| 禁止项 | 未见内部桶名 Client-Fixable 等 · 非 fix 桶无 Repair 主钮 · 无双实心主 CTA |

**不应出现：** 非 Client-Fixable 上的 Repair 主按钮 · 内部桶名 · 双实心主 CTA。

---

## 7 · 跨屏 chrome（无独立 hi-fi 帧）

| 用途 | Keys | ☑ |
|---|---|---|
| 通用按钮 | `chrome.cancel` · `done` · `close` · `back` · `ok` · `save` · `delete` · `edit` · `try_again` · `not_now` · `continue` · `send` · `remove` · `none` S | [ ] |
| 通用反馈 | `chrome.error_title` · `chrome.loading` S | [ ] |

实现时出现即绑 key；无独立故事板帧，跟宿主屏一起勾。

---

## 8 · Paywall（无 craft-p0 帧 · Beta 不展示）

| 状态 | Keys | ☑ |
|---|---|---|
| 草稿占位 only | `paywall.title` · `subtitle` · `cta` **L** · ADR 0006 | [ ] N/A until commercialization |

---

## 走查记录

| 日期 | 范围 | 结果 | 备注 |
|---|---|---|---|
| 2026-08-06 | **§1 Home** + **§6 Diagnostic** | **pass（附注）** | 结果态曾 `[~]`；同日补 **6/7** 后结果键可勾 |
| 2026-08-06 | **§6 续 · Repair 结果帧** | **pass** | hi-fi 6 Success · 7 Rolled back |
| 2026-08-06 | **§2 Setup · §3 Subs · §4 Settings · §5 Help** | **pass（附注）** | 1d/1e 实现仍 open |
| 2026-08-06 | **hi-fi polish** | — | 绿场节点行 glass chip；Rename sheet；Settings **4d/4e** iCloud |

### 本轮 gap / follow-up（非 blocker）

| ID | 说明 | 建议 |
|---|---|---|
| H-1 | 02-home 故事板未挂 `cant` / `setup` 静态帧 | **决议：** 跨屏验收即可 |
| H-2 | `modeHint` 故事板未演示 Global/Direct | key 已齐；可选加帧非 blocker |
| B-1 | Auto-update 副文 vs 严格冷启动 | 保留现副文；真源 ADR 0015 |
| D-2 | `repair.progress.step_example` 演示步 | 实现用动态步文案 |
| M-1 / M-2 | 官网 diagnostic / home-connected | 已重导对齐 |
| S-1 | ~~Overrides iCloud restore 无 hi-fi 帧~~ | **已补** 4d fail 弱行 · 4e success toast（2026-08-06） |
| S-2 | 1d/1e | hi-fi 文案 pass；**实现**仍见 IMPL-SUB |

**已知样例/草稿（不算实现 blocker）：**

- `diag.example.*` · `help.chat.example.*` · `repair.progress.step_example` — hi-fi 演示句  
- `paywall.*` — 商业化前草稿  
- `repair.rolled_back.*` — 产品意图句，可随 Craft 微调  

---

## 完成定义（本表）

- [x] §1 Home 帧勾完（2026-08-06）  
- [x] §6 Diagnostic 帧勾完（含 **6 Success · 7 Rolled back**）  
- [x] §2–§5 文案/hi-fi 勾完（2026-08-06；含 Settings **4d/4e** iCloud restore）  
- [ ] §7 chrome 跟宿主实现时勾  
- [x] 本轮 **L** 键抽检：诊断 / Repair CTA / About MT / Welcome 三词 Paste/Connect/Smart / Add no-sell 与 CONTEXT/ADR 一致  
- [ ] 实现绑定 key 名与本表一致（Android：`.` → `_`）——**编码阶段**  
