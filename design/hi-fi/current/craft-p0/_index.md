# craft-p0 · current

**当前优先级：** Home / Setup / Subscriptions / **Settings** 已有高保真稿。

| 文件 | 说明 |
|---|---|
| **[02-home.html](./02-home.html)** | **权威** Home 故事板 + Interactive（顶栏 Agent · Subscriptions · Settings） |
| **[03-setup.html](./03-setup.html)** | **首次安装（ADR 0019）** Welcome → Empty（无 Subscriptions 钮）→ Add |
| **[04-subscriptions.html](./04-subscriptions.html)** | **Subscriptions** 单列表 + Active 态 |
| **[05-settings.html](./05-settings.html)** | **Settings** 根页 + Mode/DNS/Overrides/Activity/About + Interactive（ADR 0021–0032） |
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
| [CONTEXT.md](../../../CONTEXT.md) | Home Surface / **Home Chrome** / Subscriptions Surface |
| [ADR 0018](../../../docs/adr/0018-home-surface-minimal.md) | Home 中部极简 |
| [ADR 0020](../../../docs/adr/0020-home-chrome-agent-subscriptions-settings.md) | 顶栏 Agent · Subscriptions · Settings |

## Subscriptions 故事板

| # | 状态 | 备注 |
|---|---|---|
| 1 | List · Active rich | 全部在一屏；Active 行流量 + Update |
| 1b | List · sparse Active | 未知流量/到期则不显示 |
| 1c | Updating | Active 卡上 Update busy |
| 2 | Settings deep link | 单门（权威 Settings 见 05） |

## Settings 故事板

| # | 状态 | 备注 |
|---|---|---|
| Interactive | 全导航 | 改 Mode/DNS；Overrides Add sheet |
| 1 | Root | Connection · History · App 闭集 |
| 2 | Routing mode | Auto / Global / Direct |
| 3 | DNS | Automatic / Privacy / Compatibility |
| 4 | Overrides | 列表 + toggle + Add |
| 5 | Activity | 时间序（能力 P0） |
| 6 | About | Export 次要；不卖节点一句 |

更新：2026-08-05（Settings 高保真；ADR 0021–0032）
