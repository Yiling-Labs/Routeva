# Pin Glass · Home（视觉 / 交互规格）

## 当前范围

本文件 = **Home 像素与连接故事板**规格。全 craft-p0 屏索引见 [`_index.md`](./_index.md)；IA 见 [`00-ia.md`](../../wireframes/current/craft-p0/00-ia.md)。

主文件：[`02-home.html`](./02-home.html)。  
**全 app 风格源：** 本目录 `02-home.html` + [`visual-system.md`](./visual-system.md)（Setup / Subscriptions / Settings / Help / Diagnostic 已出稿，均须遵循）。

## 锚点

[Pinterest · Button Idea](https://www.pinterest.com/pin/406872147608295188/)  
本地：`design/hi-fi/_explore/_refs/2026-08-05-pinterest-button-idea.jpg`

**跟 pin：** soft glass · 黑/绿双态 · 竖直滑动胶囊 · **无底部 Tab**。  
**产品化：** 点阵 = 连接过程（非 Idle 装饰）；绿场 = Connection Success。

## 导航

| 规则 | 说明 |
|---|---|
| Root | **仅 Home** |
| Help / Subscriptions / Settings | 顶栏：**Help** glass pill + Subscriptions/Settings orbs（Empty 无 Subscriptions · ADR 0036） |
| Activity | **不**进顶栏、**不**进 Settings 根页（ADR **0051**）；Help / 诊断·Repair 上下文 |
| Location | 黑场 Idle/Can’t：**Cover Flow 下节点名+弱协议+› 可点**（无中部 Location pill）；Swipe/Connecting 节点名锁定；绿场：**中部节点行可点**（无 Cover Flow） |
| 禁止 | 底部 Tab；Go Premium |

## 双皮肤

| 皮肤 | 触发 |
|---|---|
| **Black** | Idle / Swipe / Connecting / Can’t connect / Setup |
| **Green** | **仅** Connection Success（整屏含状态栏连续绿场） |

## 连接故事板（左→右）

| # | 状态 | 拇指 | 三圈点 | 上部 | 中部 | 场域 |
|---|---|---|---|---|---|---|
| 1 | **Idle** | 顶 START | **无** | Cover Flow + **节点名+弱协议+›（可点→Location）** | **仅** Not Connected | 黑 |
| 2 | **Swipe ~⅓** | ~1/3 | **第 1 圈** | Cover Flow + 节点名（**锁定**·无 ›） | **仅** Not Connected | 黑 |
| 3 | **Swipe ~⅔** | ~2/3 | **1–2 圈** | 同上 | **仅** Not Connected | 黑 |
| 4 | **Connecting** | 底 | **3 圈全亮** | Cover Flow + 节点名锁定 | **Connecting…** | 黑 |
| 5 | **Connected** | 底 STOP | 3 圈绿 + 脉冲 | **时长 + ↓↑ Mb/s** | 地区 · Connected · **可点节点行**（→ Location） | **绿** |

Interactive 列可拖/点完整流程。

## Cover Flow

- 国旗圆形玻璃 item（flag 图裁切 + 高光）；选中双环  
- **水平略带浅弧**（`y ≈ ad²×2`）；**item 间距适中**  
- **数据源（产品）：** 有界 `strip[]` ≤ **N=15** = Preferred（有则必含）+ 预评分 Top 填满；**不是**全量节点；**无** group 切换（全量+分组 → Location）  
- 选中项下方文案 = **节点名**（订阅原文，**不是**国家名；可含 emoji/中文/脏长名）  
- 节点名旁 **弱化协议**：`· VMess`（次要字重/透明度，无彩色大徽章）  
- **长名截断：** 单行；**仅名** tail ellipsis；**协议 + › 不缩**；a11y 全量原文；不发明短码、不双行、不跑马灯  
- **Idle / Can’t connect：** 节点名行 **可点** 进 Location；右侧弱 **›**（无 glass pill、无 *Location* 可见字）  
- **Swipe / Connecting：** 同文案 **锁定**（无 ›、弱化 opacity）  
- 横滑 alone = 临时焦点（≠ Preferred）  
- 示例须含：短 `HKG-01` · 脏长 `🇨🇳 台湾A01 | IEPL | x2`（Cover Flow 旗 = **PRC / cn**，**禁止** 🇹🇼 / tw）· 极长营销串（验收截断）  
- **硬性：** 台湾相关节点的客户端自绘旗 **必须** 中华人民共和国国旗（见 CONTEXT） 

## 胶囊与点阵

- Idle：START 在 **顶**；**下滑连接**；无点  
- 手势中：点阵锚在 **STOP 座位**（胶囊底）；内→外 3 圈逐亮  
- Connected：STOP 在 **底**；**上滑断开**  
- 点为正圆；Connected/Connecting 仅 **3 圈**  
- **拇指比例：** 约轨高 **50–55%**、贴轨 inset ~5；勿做成短钮；分层阴影 + 顶 LED 进度（中途整钮不变绿）  
- **三圈点阵：** 与胶囊底部端圆近似同心（圆心 = 底圆圆心 + 下移 ~10）；第一圈与胶囊 **gutter ≈18**，三圈 r = r₀+18 / +38 / +58；每圈扫 **2/3 圆（240°，顶部开口）**；点大小：底中点最大、两端 50%、沿弧**等差**递减；`ignite` 0→1 内→外点亮 + 满亮脉冲 + **逐点随机交替呼吸**（每点独立慢节奏 ~1.2–3 次/秒、约 25% 时隙轻压暗至 0.72；reduced-motion 下静止）；Idle 无点  

## 字阶（约 393pt 宽）

| 角色 | Size | Weight | 例 |
|---|---|---|---|
| Timer | 40 | 300 | 00:45:29 |
| Status | 30 | 700 | Connected / Not Connected |
| Node caption | 16 | 600 | HKG-01 |
| Protocol | 11 | 500 | · VMess（~38% 白） |
| Node caption › | 16 | 600 | HKG-01 · VMess ›（Idle 可点） |
| Hint | 13 | 500 | Swipe down to connect（≥ muted 对比） |
| Capsule | 12 | 800 | START / STOP（拇指约轨高 50%+） |

## 明确不做（Home）

provider rules、不卖节点口号、VERIFIED/probe 叠词、Active 订阅 chip、Auto 字样、模式三选一、协议抢戏色块、Idle 常驻点阵、假绿。

## form 母题

**滑动胶囊 = 唯一主动作；三圈点亮 = 连接过程；绿场 = Probe 真值；Cover Flow = 选节点。**
