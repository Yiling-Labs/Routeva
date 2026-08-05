# craft-p0 · current

**当前优先级：** Home / Setup / Subscriptions / Settings / Help / **Diagnostic** 已有高保真稿。

| 文件 | 说明 |
|---|---|
| **[02-home.html](./02-home.html)** | **权威** Home；顶栏 **Help** pill · Subscriptions · Settings（ADR 0036） |
| **[03-setup.html](./03-setup.html)** | **首次安装（ADR 0019）** Welcome → Empty（Help + Settings）→ Add |
| **[04-subscriptions.html](./04-subscriptions.html)** | **Subscriptions** 单列表 + Active 态 |
| **[05-settings.html](./05-settings.html)** | **Settings** 根页 + 二级（ADR 0021–0034 · **0045** O3 Overrides） |
| **[06-agent.html](./06-agent.html)** | **Help / Agent Surface**（ADR 0035–0043） |
| **[07-diagnostic.html](./07-diagnostic.html)** | **诊断 sheet** 四桶 + Repair / Ask Help（ADR 0041 / 0044） |
| **[visual-system.md](./visual-system.md)** | **全 app 风格约束**（从 Home 提取；后续屏必读） |
| [design-spec.md](./design-spec.md) | Home 视觉 / 交互规格 |

## 连接故事板（左→右）

| # | 状态 | 点阵 | 拇指 | 备注 |
|---|---|---|---|---|
| 1 | Idle | 无 | START 顶 | Cover Flow + 节点名+弱协议 + Location |
| 2 | Swipe ~⅓ | 1 圈 | ~1/3 | |
| 3 | Swipe ~⅔ | 2 圈 | ~2/3 | |
| 4 | Connecting | 3 圈 | 底 | Connecting…；仍黑场 |
| 5 | Connected | 3 圈绿 | STOP 底 | 绿场 + 时长/速率 |
| — | Interactive | 全流程 | 可拖 | |

## 文档同步

| 文档 | 内容 |
|---|---|
| [00-ia.md](../../wireframes/current/craft-p0/00-ia.md) | IA + 故事板 |
| [CONTEXT.md](../../../CONTEXT.md) | Home Surface / **Home Chrome** / Settings Surface / Subscriptions / Agent |
| [PRD §4.10](../../../docs/prd/PRD.md) | 信息架构（与本目录对齐） |
| [ADR 0018](../../../docs/adr/0018-home-surface-minimal.md) | Home 中部极简 |
| [ADR 0020](../../../docs/adr/0020-home-chrome-agent-subscriptions-settings.md) | 顶栏 Help · Subscriptions · Settings |
| [ADR 0042](../../../docs/adr/0042-help-cloud-default-on.md) | Help Cloud 默认开 |
| [ADR 0051](../../../docs/adr/0051-settings-no-history-section.md) | Settings 无 History 段 |

## Subscriptions 故事板

| # | 状态 | 备注 |
|---|---|---|
| 1 | List · Active rich | 全部在一屏；*Expires* 有标签；Orbit *Expired* 警示 |
| 1b | List · sparse Active | 未知流量/到期整槽省略 |
| 1c | Updating | Active 卡上 Update busy |
| 2 | Settings deep link | 单门（权威 Settings 见 05） |

## Settings 故事板

| # | 状态 | 备注 |
|---|---|---|
| Interactive | 全导航 | 改 Mode/DNS；Overrides Add sheet |
| 1 | Root | **Connection · App**；Connection 三行各带**释义副文**（非场景/非选项）；**无** History（ADR **0051**） |
| 2 | Routing mode | Auto / Global / Direct |
| 3 | DNS | Automatic / Privacy / Compatibility |
| 4 | Overrides empty | O3：*No exceptions yet* · not a full rule set |
| 4b | Overrides list | 顶提示 + toggle + remove + *Add exception* |
| 4c | Add exception | **键盘打开态**：单 Domain 输入 + 压缩 sheet；Domain only（ADR 0049） |
| 5 | About | 隐私承诺 · Privacy / Terms 外链 · Export（`/privacy/` · `/terms/`） |

## Help / Agent 故事板

| # | 状态 | 备注 |
|---|---|---|
| Interactive | 全流程 | chips → chat；信任条 → How we use data；边界 |
| 0a/0b | Home Help pill | 有订阅 / Empty |
| 1a | Empty · down | Trouble connecting? + fault chips |
| 1b | Empty · up | Need a hand? + strategy chips（ADR 0040） |
| 2 | Chat + tool | *What we found* 用户语言 · Repair consent（ADR 0041） |
| 3 | Cloud off strip | 用户 opt-out 后本机条（默认 On · ADR 0042） |
| 4 | What Help can do | 4+4 Can / Can’t |
| 5 | How we use data | Ephemeral context · no arbitrary files |

## Diagnostic 故事板

| # | 状态 | 备注 |
|---|---|---|
| Interactive | 四桶切换 | Repair demo · Ask Help toast |
| 1 | App can fix | 主 CTA *Repair with my OK* · 次要 *Ask Help* |
| 2 | Provider | *Got it* · 无假 Repair · Ask Help |
| 3 | Your network | *Try again* · Ask Help |
| 4 | Not sure | 主 CTA 即为 *Ask Help* |
| 5 | Repairing | 快照 · 步骤 · Cancel |

更新：2026-08-06（docs sync · IA/Cloud/0051 · PRD §4.10）
