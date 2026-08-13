# Routeva App Icon · Shelf Pass

**Date:** 2026-08-13  
**Status:** Explore — 5 新方向，对照现行 Via Up  
**展板:** [`01-icon-board.html`](./01-icon-board.html)

## 为什么再开一轮

现行选定是 **Via Up · 双 chevron**（2026-08-06）。几何清楚、29pt 可读，但：

- 评审已写过：chevron 是 OS UI 符号，品牌独占弱
- Home 在 08-12 / 08-13 已长出更强的产品签名：**Cover Flow 玻璃国旗 orb、选中双环、连接胶囊、顶开口三圈点阵**
- 本轮按 **受众 + 竞品货架 + 现行 visual-system** 重开，不重做 08-06 的 10 概念

## Assumptions

1. 交付 = **App Store / 弹簧板主图标**（1024 正方形，系统再套 squircle）。不是 in-app glyph。
2. 画满幅正方形，**不预烘焙圆角**（08-06 部分生成稿把圆角画进图了）。
3. 无字、无国旗、无协议名。台湾节点旗规则与图标无关——图标里不出现任何旗。
4. 色与材质锁 [`visual-system.md`](../../current/craft-p0/visual-system.md)：Field Black `#2e343a → #0b0e11` · mint `#7fd9b0 / #b6f0d4` · soft glass。
5. 工艺对齐现行 `AppIcon.svg`：**精确矢量 + 克制 glow**。用户上次从 3D 渲染里选了干净几何。
6. 硬约束：**60pt 一眼、29pt 剪影仍成立**。叙事层不超过一个主 mark。
7. 不进品牌真源、不覆盖 `design/brand/app-icon/`，除非用户选定。

## 受众（图标要帮谁做决定）

| 人群 | 他们在货架上找什么 | 图标不该像什么 |
|---|---|---|
| **核心** 已有订阅、会复制链接、不懂协议 | 「给我一个能连上的客户端」· 看起来不像黑客工具 | Surge/QX 那种专业仪器密度 |
| **次级** 会用但不想维护配置 | 精致、可信、少吓人 | 玩具、表情包、土豆人 |
| **不做** 规则玩家 / 买节点新手 / 企业 VPN | — | 盾、锁、地球、速度线 |

弹簧板邻座往往是 ChatGPT、YouTube、Telegram、相机、钱包——不是 Clash 猫。图标要能和消费级 App 站在一起。

## 竞品货架（色 + 隐喻，不复刻商标）

| 产品 | 货架印象 | 他们占住的槽 |
|---|---|---|
| Shadowrocket | 橙底 + 火箭 | 「走 / 快 / 就是这个客户端」· $2.99 品类默认 |
| Surge | 蓝 / 浪 | 贵、专业、开发者 |
| Quantumult X | 暗底抽象 Q | 密度、规则玩家 |
| Stash | 金 / 盒 | Craft 但面向高玩 |
| Loon | 热气球 | 稍轻松 |
| 通用 VPN | 绿/蓝盾、地球、锁 | 卖节点的安全海报 |

**空槽：** 炭黑场 + 薄荷绿 + 玻璃物，既不是橙火箭，也不是蓝专业器，也不是盾。Routeva 的 Home 已经住在这个槽里。

## 禁区（沿用 + 本轮加严）

- 盾 / 锁 / 钥匙 / 线框地球 / 火箭 / 速度线
- 全绿成功场当主底（易读成健康/理财 · 08-06 已否）
- SF chevron 再做一版（现行已是）
- 左右开口的「Wi‑Fi」弧（08-06 Probe Rings 白底版）
- 两点加连线（易成眼镜）
- 预烘焙圆角、字、emoji、彩虹 AI 光

## 五枚（本轮只做这些）

| # | 代号 | 从哪长出来 | 货架主张 |
|---|---|---|---|
| 01 | **Glass Orb** | Cover Flow 选中国旗 orb（双环 + 玻璃高光），去旗 | 消费级物件；和火箭/盾完全不像 |
| 02 | **Considered Path** | 品牌句 *Connect without the maze.* · 名 = route | 一条路，一次转弯；29pt 最稳 |
| 03 | **Nest Rings** | Home 连接点阵：顶开口三圈（图标用 270°，比 Home 的 240° 更不像笑脸） | 产品独有过程签名 |
| 04 | **Capsule** | START/STOP 滑动胶囊，无电源符、无字 | 手能碰到的控件；小白能认 |
| 05 | **Flow Orbs** | 08-12 之后的 Cover Flow 浅弧三盘 | 最新 Home 签名；中心亮、两侧退 |

## 工艺

- 源：`assets/*.svg`（真源）
- 导出：`assets/*.png` 1024 RGB 无 alpha
- 与现行并排：`assets/current-via-up.png`

## 选定后

1. `direction-approved.md`（写用户原话）
2. 晋升到 `design/brand/app-icon/` + `gtm/stores/app_store/icon/`
3. Android adaptive 安全区另出
