# Pin Glass · Home（优先）

## 当前范围

**只打磨 Home。** Diagnostic / Repair / Activity / Agent / Onboarding 高保真 **暂缓**，但**一旦开做**必须遵循 [visual-system.md](./visual-system.md)（从 Home 提取）。

主文件：[`02-home.html`](./02-home.html)。  
**全 app 风格源：** 本目录 `02-home.html` + `visual-system.md`。

## 锚点

[Pinterest · Button Idea](https://www.pinterest.com/pin/406872147608295188/)  
本地：`design/hi-fi/_explore/_refs/2026-08-05-pinterest-button-idea.jpg`

**跟 pin：** soft glass · 黑/绿双态 · 竖直滑动胶囊 · **无底部 Tab**。  
**产品化：** 点阵 = 连接过程（非 Idle 装饰）；绿场 = Connection Success。

## 导航

| 规则 | 说明 |
|---|---|
| Root | **仅 Home** |
| Help / Subscriptions / Settings | 顶栏：**Help** glass pill + Subscriptions/Settings orbs（Empty 无 Subscriptions；Activity 在 Settings 内 · ADR 0036） |
| Location | Not Connected 下 **图标 + Location ›** |
| 禁止 | 底部 Tab；Go Premium |

## 双皮肤

| 皮肤 | 触发 |
|---|---|
| **Black** | Idle / Swipe / Connecting / Can’t connect / Setup |
| **Green** | **仅** Connection Success（整屏含状态栏连续绿场） |

## 连接故事板（左→右）

| # | 状态 | 拇指 | 三圈点 | 上部 | 中部 | 场域 |
|---|---|---|---|---|---|---|
| 1 | **Idle** | 顶 START | **无** | Cover Flow + **节点名** + 弱协议 | Not Connected + **Location ›** | 黑 |
| 2 | **Swipe ~⅓** | ~1/3 | **第 1 圈** | 同上 | Not Connected + Location | 黑 |
| 3 | **Swipe ~⅔** | ~2/3 | **1–2 圈** | 同上 | Not Connected + Location | 黑 |
| 4 | **Connecting** | 底 | **3 圈全亮** | Cover Flow | **Connecting…** | 黑 |
| 5 | **Connected** | 底 STOP | 3 圈绿 + 脉冲 | **时长 + ↓↑ Mb/s** | 地区 · Connected · 节点+弱协议 | **绿** |

Interactive 列可拖/点完整流程。

## Cover Flow

- 国旗圆形玻璃 item（flag 图裁切 + 高光）；选中双环  
- **水平略带浅弧**（`y ≈ ad²×2`）；**item 间距适中**  
- 选中项下方文案 = **节点名**（如 `HKG-01`），**不是**国家名  
- 节点名旁 **弱化协议**：`· VMess`（次要字重/透明度，无彩色大徽章）  
- 默认示例节点：香港 `HKG-01` · VMess  

## 胶囊与点阵

- Idle：START 在 **顶**；**下滑连接**；无点  
- 手势中：点阵锚在 **STOP 座位**（胶囊底）；内→外 3 圈逐亮  
- Connected：STOP 在 **底**；**上滑断开**  
- 点为正圆；Connected/Connecting 仅 **3 圈**  

## 字阶（约 393pt 宽）

| 角色 | Size | Weight | 例 |
|---|---|---|---|
| Timer | 40 | 300 | 00:45:29 |
| Status | 30 | 700 | Connected / Not Connected |
| Node caption | 16 | 600 | HKG-01 |
| Protocol | 11 | 500 | · VMess（~38% 白） |
| Location pill | 14 | 600 | Location |
| Hint | 13 | 500 | Swipe down to connect（≥ muted 对比） |
| Capsule | 11 | 800 | START / STOP |

## 明确不做（Home）

provider rules、不卖节点口号、VERIFIED/probe 叠词、Active 订阅 chip、Auto 字样、模式三选一、协议抢戏色块、Idle 常驻点阵、假绿。

## form 母题

**滑动胶囊 = 唯一主动作；三圈点亮 = 连接过程；绿场 = Probe 真值；Cover Flow = 选节点。**
