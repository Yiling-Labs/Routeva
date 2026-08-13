# Home 四控件探索 · Settings / Location / Mode / Connect

**日期：** 2026-08-13  
**状态：** explore（只做高保真，不进开发）  
**范围：** 只改这四个控件的形态或相对位置。Cover Flow、时长、累计流量、场域、Subscriptions、状态大字 **不动**。

| 控件 | 现网 |
|---|---|
| **Settings** | 顶栏右 glass orb |
| **Location** | Idle = Cover Flow 下节点名+›；Connected = 中部玻璃行 |
| **Mode** | 状态字下 *Mode Smart ›* 文本 |
| **Connect** | 纵向 START/STOP 下滑胶囊 |

## 方案

| ID | 名 | 改什么 |
|---|---|---|
| **0** | Current | 对照 |
| **A** | Twin chips | Location + Mode 做成一对同族玻璃 chip；Settings 同材质 44pt |
| **B** | Flanks | Location / Mode 分列胶囊左右；Settings 略放大 |
| **C** | Orb family | Settings / Location / Mode 统一 44pt orb + 底注；Connect 收细 |
| **D** | Split bar | 状态下一条玻璃条：节点 \| Smart；Settings 同高 chip |
| **E** | Jewel | 胶囊更「仪表」；Location/Mode 加大热区的静默文本 |

## 精修定稿（评审后合成）

[`refine.html`](./refine.html) = **0 的 Idle Location + D 的绿场条 + E 的 Jewel 胶囊**；Settings 保持 orb。

| 态 | Settings | Location | Mode | Connect |
|---|---|---|---|---|
| Idle | 顶栏右 orb | Cover Flow 下节点名+›（加大热区） | 状态下弱文本（44pt 热区） | Jewel 纵向胶囊 |
| Connected | 同 orb | 与 Mode 合成一条 `节点 › \| Mode Smart ›` | 同上条右侧 | Jewel STOP |
| Connecting | orb | 球下名锁定（不可点） | 隐藏 | Jewel |

```bash
python3 -m http.server 4321 --directory design/hi-fi/_explore/2026-08-13-home-controls
# 探索：http://127.0.0.1:4321/
# 定稿：http://127.0.0.1:4321/refine.html
# 过渡：http://127.0.0.1:4321/motion.html
```
