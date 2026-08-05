# craft-p0 · current

**当前优先级：只打磨 Home。** 其它屏高保真暂缓。

| 文件 | 说明 |
|---|---|
| **[02-home.html](./02-home.html)** | **权威** Home 故事板 + Interactive |
| **[03-setup.html](./03-setup.html)** | **首次安装（ADR 0019）** Welcome → Home Empty → Add Sub（paste-first） |
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
| [CONTEXT.md](../../../CONTEXT.md) | Home Surface / Mid Copy / Connect Gesture |
| [ADR 0018](../../../docs/adr/0018-home-surface-minimal.md) | 决策摘要 |

更新：2026-08-05（连接故事板与 Cover Flow 定稿同步）
